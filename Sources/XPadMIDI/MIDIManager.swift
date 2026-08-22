import Foundation
import CoreMIDI
import XPadCore

/// Public DAW-visible routing destinations. Technical Swift modules retain XPad naming.
public enum VirtualPort: String, CaseIterable, Identifiable, Hashable, Sendable {
    case main = "XPI Main"
    case chords = "XPI Chords"
    case melody = "XPI Melody"
    case bass = "XPI Bass"
    case drums = "XPI Drums"
    case mpe = "XPI Expression (MPE)"

    public var id: String { rawValue }
}

/// A test/diagnostic copy of a MIDI channel message before it reaches CoreMIDI.
///
/// The byte representation intentionally remains MIDI 1-shaped even when the
/// selected wire transport is MIDI 2.0. This keeps diagnostics stable and makes
/// the transport conversion an implementation detail rather than a second
/// musical-event model.
public struct MIDIMessageRecord: Equatable, Sendable {
    public let port: VirtualPort
    public let bytes: [UInt8]

    public init(port: VirtualPort, bytes: [UInt8]) {
        self.port = port
        self.bytes = bytes
    }
}

/// Manages XPI CoreMIDI virtual sources for output to DAWs.
@Observable
public final class MIDIEngine: @unchecked Sendable {
    public static let shared = MIDIEngine()

    public var virtualMIDIEnabled: Bool = false {
        willSet {
            guard newValue != virtualMIDIEnabled else { return }
            if virtualMIDIEnabled && !newValue {
                // Deliver note-offs while the endpoints are still live.
                prepareForVirtualSourceDisposal()
            }
        }
        didSet {
            guard oldValue != virtualMIDIEnabled else { return }
            if virtualMIDIEnabled {
                createVirtualSources()
            } else {
                disposeVirtualSources()
            }
            onVirtualMIDIChanged?(virtualMIDIEnabled)
        }
    }

    /// CoreMIDI wire protocol advertised by the public virtual sources.
    /// MIDI 1.0 remains the compatibility default for the alpha.
    public var transportProtocol: MIDITransportProtocol = .midi1 {
        willSet {
            guard newValue != transportProtocol, virtualMIDIEnabled else { return }
            // Cleanly close all voices before replacing endpoints with a different
            // protocol. This prevents a receiver retaining expression or notes
            // from the source that is about to disappear.
            prepareForVirtualSourceDisposal()
        }
        didSet {
            guard oldValue != transportProtocol, virtualMIDIEnabled else { return }
            disposeVirtualSources()
            createVirtualSources()
        }
    }

    public var onVirtualMIDIChanged: ((Bool) -> Void)?

    /// MIDI Passthru routing policy for messages received at "XPI Input / CI".
    public var passthruMode: MIDIPassthruMode = .full

    /// Invoked when incoming channel voice events are decoded from the input port.
    public var onIncomingEvent: ((PerformanceEvent, [UInt8]) -> Void)?
    /// Invoked when incoming per-note pitch bend events are decoded.
    public var onIncomingPerNotePitchBend: ((UInt8, UInt8, Double) -> Void)?
    /// Invoked when incoming per-note pressure events are decoded.
    public var onIncomingPerNotePressure: ((UInt8, UInt8, Double) -> Void)?
    /// Invoked when incoming per-note registered controllers are decoded.
    public var onIncomingPerNoteController: ((UInt8, UInt8, UInt8, Double) -> Void)?
    /// Invoked when incoming standard MIDI 2.0 Registered Per-Note Controllers are decoded.
    public var onIncomingPerNoteRPNC: ((UInt8, UInt8, MIDI2UMPEncoder.MIDI2RPNC, Double) -> Void)?
    /// Invoked when incoming Note On messages with non-zero attributes are decoded.
    public var onIncomingNoteOnAttribute: ((UInt8, UInt8, UInt16, UInt8, UInt16) -> Void)?
    /// Invoked when incoming SysEx / MIDI-CI payloads are assembled.
    public var onIncomingSysEx: (([UInt8]) -> Void)?

    /// Human-readable description of the most recent CoreMIDI setup failure.
    /// `nil` when the last enable attempt created every endpoint successfully.
    public private(set) var setupErrorDescription: String?

    public private(set) var lastSentNotes: [UInt8] = []
    public private(set) var midiActivityTimestamp: Date?
    public var isMIDIActive: Bool {
        lock.lock()
        let timestamp = midiActivityTimestamp
        lock.unlock()
        guard let timestamp else { return false }
        return Date().timeIntervalSince(timestamp) < 0.3
    }

    public var sentMessages: [MIDIMessageRecord] {
        lock.lock()
        let messages: [MIDIMessageRecord]
        if messageLog.count < Self.messageLogCapacity || messageLogWriteIndex == 0 {
            messages = messageLog
        } else {
            messages = Array(messageLog[messageLogWriteIndex...])
                + Array(messageLog[..<messageLogWriteIndex])
        }
        lock.unlock()
        return messages
    }

    /// Number of unique note/channel/port voices that still require a Note Off.
    public var activeNoteCount: Int {
        lock.lock()
        let count = activeNotes.count
        lock.unlock()
        return count
    }

    /// Sources that CoreMIDI created successfully for the current enabled session.
    public var availableVirtualPorts: Set<VirtualPort> {
        lock.lock()
        let ports = Set(outputs.compactMap { $0.value == 0 ? nil : $0.key })
        lock.unlock()
        return ports
    }

    private var midiClient: MIDIClientRef = 0
    private var outputs: [VirtualPort: MIDIEndpointRef] = [:]
    private var activeNotes: Set<ActiveNote> = []
    private static let messageLogCapacity = 2_048
    private var messageLog: [MIDIMessageRecord] = []
    private var messageLogWriteIndex = 0
    private var inputDestination: MIDIEndpointRef = 0
    private var incomingSysExBuffer: [UInt8] = []
    private let lock = NSLock()

    public let ciSession = MIDICISession.shared

    private struct ActiveNote: Hashable {
        let port: VirtualPort
        let channel: UInt8
        let note: UInt8
    }

    public init() {
        setupMIDIClient()
    }

    deinit {
        prepareForVirtualSourceDisposal()
        disposeVirtualSources()
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }

    public func clearMessageLog() {
        lock.lock()
        messageLog.removeAll(keepingCapacity: true)
        messageLogWriteIndex = 0
        lock.unlock()
    }

    /// Cleans up state before endpoints are disposed. When CoreMIDI never created
    /// an endpoint, emitting a full 16-channel panic cannot reach a receiver and
    /// only adds avoidable startup/teardown work.
    func prepareForVirtualSourceDisposal() {
        lock.lock()
        let hasLiveEndpoint = outputs.values.contains { $0 != 0 }
        if !hasLiveEndpoint {
            activeNotes.removeAll()
            lastSentNotes.removeAll()
        }
        lock.unlock()

        if hasLiveEndpoint {
            panic()
        }
    }

    private func setupMIDIClient() {
        let status = MIDIClientCreateWithBlock("XPI" as CFString, &midiClient) { _ in }
        if status != noErr {
            midiClient = 0
            setupErrorDescription = "Failed to create XPI MIDI client (OSStatus \(status))"
            print("⚠️ Failed to create XPI MIDI client: \(status)")
        }
    }

    private func createVirtualSources() {
        if midiClient == 0 {
            setupMIDIClient()
        }
        guard midiClient != 0 else { return }
        var failures: [String] = []
        let protocolID = transportProtocol.coreMIDIProtocol

        for port in VirtualPort.allCases {
            lock.lock()
            let alreadyExists = outputs[port] != nil
            lock.unlock()
            guard !alreadyExists else { continue }

            var endpoint: MIDIEndpointRef = 0
            let status = MIDISourceCreateWithProtocol(
                midiClient,
                port.rawValue as CFString,
                protocolID,
                &endpoint
            )
            if status == noErr {
                MIDIObjectSetStringProperty(
                    endpoint,
                    kMIDIPropertyManufacturer,
                    "XPI" as CFString
                )
                MIDIObjectSetStringProperty(
                    endpoint,
                    kMIDIPropertyModel,
                    "Game Controller MIDI" as CFString
                )
                lock.lock()
                outputs[port] = endpoint
                lock.unlock()
            } else {
                failures.append("\(port.rawValue) source (OSStatus \(status))")
                print("⚠️ Failed to create \(port.rawValue) MIDI source: \(status)")
            }
        }

        // Create bidirectional virtual destination for MIDI-CI Profile & Discovery and Passthru
        if inputDestination == 0 {
            var destEndpoint: MIDIEndpointRef = 0
            let destName = "XPI Input / CI" as CFString
            let status = MIDIDestinationCreateWithProtocol(
                midiClient,
                destName,
                protocolID,
                &destEndpoint
            ) { [weak self] eventList, _ in
                self?.handleIncomingMIDIEventList(eventList)
            }
            if status == noErr {
                self.inputDestination = destEndpoint
            } else {
                failures.append("XPI Input / CI destination (OSStatus \(status))")
                print("⚠️ Failed to create XPI Input / CI MIDI destination: \(status)")
            }
        }

        setupErrorDescription = failures.isEmpty
            ? nil
            : "Failed to create: " + failures.joined(separator: ", ")
    }

    private func disposeVirtualSources() {
        lock.lock()
        let endpoints = Array(outputs.values)
        outputs.removeAll()
        let dest = inputDestination
        inputDestination = 0
        lock.unlock()

        for endpoint in endpoints where endpoint != 0 {
            MIDIEndpointDispose(endpoint)
        }
        if dest != 0 {
            MIDIEndpointDispose(dest)
        }
    }

    private func handleIncomingMIDIEventList(_ eventList: UnsafePointer<MIDIEventList>) {
        let numPackets = Int(eventList.pointee.numPackets)
        guard numPackets > 0 else { return }

        var forwardedDirectly = false
        lock.lock()
        let shouldForward = passthruMode.routesToOutputs && virtualMIDIEnabled
        let mainEndpoint = shouldForward ? outputs[.main] : nil
        lock.unlock()

        // Zero-copy fast-path: forward raw UMP event list directly to destination virtual output
        if let mainEndpoint, mainEndpoint != 0 {
            MIDIReceivedEventList(mainEndpoint, eventList)
            forwardedDirectly = true
        }

        let wordCapacity = MemoryLayout.size(ofValue: eventList.pointee.packet.words)
            / MemoryLayout<UInt32>.size

        var packetPtr = UnsafeMutablePointer(mutating: eventList)
            .pointer(to: \.packet)!
        for _ in 0..<numPackets {
            let count = Int(packetPtr.pointee.wordCount)
            guard count <= wordCapacity else { return }
            if count > 0 {
                let words = packetPtr.pointer(to: \.words)!.withMemoryRebound(
                    to: UInt32.self,
                    capacity: count
                ) { buf in
                    Array(UnsafeBufferPointer(start: buf, count: count))
                }
                processIncomingUMPWords(words, alreadyForwardedToOutputs: forwardedDirectly)
            }
            packetPtr = MIDIEventPacketNext(packetPtr)
        }
    }

    private func processIncomingUMPWords(_ words: [UInt32], alreadyForwardedToOutputs: Bool = false) {
        let messages = MIDI2UMPDecoder.decodeStream(words: words, sysExBuffer: &incomingSysExBuffer)
        for message in messages {
            switch message {
            case .sysEx(let bytes):
                lock.lock()
                midiActivityTimestamp = Date()
                lock.unlock()
                if !bytes.isEmpty, bytes.first == 0xF0 {
                    if let response = ciSession.processIncomingSysEx(bytes) {
                        sendSysEx(response, to: .main)
                    }
                }
                onIncomingSysEx?(bytes)

            case .channelVoice(let event, let rawBytes):
                // Prioritize DAW output if not already forwarded directly on wire
                if passthruMode.routesToOutputs && !alreadyForwardedToOutputs {
                    emit(rawBytes, to: .main)
                }

                lock.lock()
                midiActivityTimestamp = Date()
                let record = MIDIMessageRecord(port: .main, bytes: rawBytes)
                if messageLog.count < Self.messageLogCapacity {
                    messageLog.append(record)
                } else {
                    messageLog[messageLogWriteIndex] = record
                    messageLogWriteIndex = (messageLogWriteIndex + 1) % Self.messageLogCapacity
                }
                lock.unlock()

                onIncomingEvent?(event, rawBytes)

            case .noteOnAttribute(let channel, let note, let vel16, let attrType, let attrData):
                lock.lock()
                midiActivityTimestamp = Date()
                lock.unlock()
                onIncomingNoteOnAttribute?(channel, note, vel16, attrType, attrData)

            case .perNotePitchBend(let channel, let note, let semitones, _):
                lock.lock()
                midiActivityTimestamp = Date()
                lock.unlock()
                onIncomingPerNotePitchBend?(channel, note, semitones)

            case .perNotePressure(let channel, let note, let pressure):
                lock.lock()
                midiActivityTimestamp = Date()
                lock.unlock()
                onIncomingPerNotePressure?(channel, note, pressure)

            case .perNoteController(let channel, let note, let controller, let value):
                lock.lock()
                midiActivityTimestamp = Date()
                lock.unlock()
                onIncomingPerNoteController?(channel, note, controller, value)

            case .perNoteRPNC(let channel, let note, let rpnc, let value):
                lock.lock()
                midiActivityTimestamp = Date()
                lock.unlock()
                onIncomingPerNoteRPNC?(channel, note, rpnc, value)

            case .perNoteManagement:
                break

            case .systemRealtime:
                lock.lock()
                midiActivityTimestamp = Date()
                lock.unlock()
            }
        }
    }

    // MARK: - Note Output

    public func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        sendNoteOn(port: .main, channel: channel, note: note, velocity: velocity)
    }

    public func sendNoteOn(
        port: VirtualPort,
        channel: UInt8,
        note: UInt8,
        velocity: UInt8,
        velocity16: UInt16? = nil,
        attributeType: MIDI2UMPEncoder.MIDI2NoteAttributeType = .none,
        attributeData: UInt16 = 0
    ) {
        let safeChannel = min(15, channel)
        let safeNote = min(127, note)
        let safeVelocity = min(127, velocity)
        let effective16 = velocity16 ?? MIDI2UMPEncoder.scale7To16(safeVelocity)
        guard safeVelocity > 0 || effective16 > 0 else {
            sendNoteOff(port: port, channel: safeChannel, note: safeNote)
            return
        }

        let activeNote = ActiveNote(
            port: port,
            channel: safeChannel,
            note: safeNote
        )
        lock.lock()
        let wasAlreadyActive = activeNotes.contains(activeNote)
        activeNotes.insert(activeNote)

        lastSentNotes.append(safeNote)
        if lastSentNotes.count > 12 { lastSentNotes.removeFirst() }
        lock.unlock()

        if wasAlreadyActive {
            emit([0x80 | safeChannel, safeNote, 0], to: port)
        }

        let midi2NoteOn = MIDI2UMPEncoder.noteOnMessage(
            channel: safeChannel,
            note: safeNote,
            velocity16: effective16,
            attributeType: attributeType,
            attributeData: attributeData
        )

        emit(
            [0x90 | safeChannel, safeNote, safeVelocity],
            midi2Override: midi2NoteOn,
            to: port
        )
    }

    /// Sends a MIDI 2.0 Note On message with Pitch 7.9-bit microtuning attribute offset.
    public func sendNoteOnWithPitch7_9(
        port: VirtualPort = .main,
        channel: UInt8,
        note: UInt8,
        velocity: UInt8,
        velocity16: UInt16? = nil,
        centOffset: Double
    ) {
        let safeVelocity = min(127, velocity)
        let effective16 = velocity16 ?? MIDI2UMPEncoder.scale7To16(safeVelocity)
        let attrData = MIDI2UMPEncoder.Pitch7_9Codec.encode(note: note, centOffset: centOffset)

        sendNoteOn(
            port: port,
            channel: channel,
            note: note,
            velocity: velocity,
            velocity16: effective16,
            attributeType: .pitch7_9,
            attributeData: attrData
        )
    }

    /// Sends a standard MIDI 2.0 Registered Per-Note Controller (RPNC).
    public func sendPerNoteRegisteredController(
        port: VirtualPort = .mpe,
        channel: UInt8,
        note: UInt8,
        controller: MIDI2UMPEncoder.MIDI2RPNC,
        normalizedValue: Double
    ) {
        let safeChannel = min(15, channel)
        let safeNote = min(127, note)
        let clampedValue = normalizedValue.clamped(to: 0.0...1.0)

        if transportProtocol == .midi2 {
            let rpncUMP = MIDI2UMPEncoder.perNoteRegisteredControllerMessage(
                channel: safeChannel,
                note: safeNote,
                controller: controller,
                normalizedValue: clampedValue
            )
            emitRawMIDI2UMP(rpncUMP, to: port)
        } else {
            // Fallback for MIDI 1 / MPE
            switch controller {
            case .brightness:
                sendTimbreCC74(port: port, channel: safeChannel, normalizedValue: clampedValue)
            case .pan:
                sendCC(port: port, channel: safeChannel, controller: 10, normalizedValue: clampedValue)
            case .modulation:
                sendCC(port: port, channel: safeChannel, controller: 1, normalizedValue: clampedValue)
            case .expression:
                sendCC(port: port, channel: safeChannel, controller: 11, normalizedValue: clampedValue)
            case .resonance:
                sendCC(port: port, channel: safeChannel, controller: 71, normalizedValue: clampedValue)
            default:
                break
            }
        }
    }

    public func sendNoteOff(note: UInt8, channel: UInt8 = 0) {
        sendNoteOff(port: .main, channel: channel, note: note)
    }

    public func sendNoteOff(port: VirtualPort, channel: UInt8, note: UInt8) {
        let safeChannel = min(15, channel)
        let safeNote = min(127, note)
        lock.lock()
        activeNotes.remove(
            ActiveNote(port: port, channel: safeChannel, note: safeNote)
        )
        lock.unlock()

        // Note Off remains safe and intentional even if local tracking was lost.
        emit([0x80 | safeChannel, safeNote, 0], to: port)
    }

    public func sendCC(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        sendCC(port: .main, channel: channel, controller: controller, value: value)
    }

    public func sendCC(
        port: VirtualPort,
        channel: UInt8,
        controller: UInt8,
        value: UInt8
    ) {
        emit(
            [0xB0 | min(15, channel), min(127, controller), min(127, value)],
            to: port
        )
    }

    /// Sends a normalized controller value without discarding precision before
    /// the MIDI 2 boundary. MIDI 1 output and diagnostics still use 7-bit data.
    public func sendCC(
        port: VirtualPort,
        channel: UInt8,
        controller: UInt8,
        normalizedValue: Double
    ) {
        let value7 = Self.midi7(normalizedValue)
        emit(
            [0xB0 | min(15, channel), min(127, controller), value7],
            midi2Override: MIDI2UMPEncoder.controlChangeMessage(
                channel: channel,
                controller: controller,
                normalizedValue: normalizedValue
            ),
            to: port
        )
    }

    public func sendPolyPressure(note: UInt8, pressure: UInt8, channel: UInt8 = 0) {
        sendPolyPressure(port: .mpe, channel: channel, note: note, pressure: pressure)
    }

    public func sendPolyPressure(
        port: VirtualPort,
        channel: UInt8,
        note: UInt8,
        pressure: UInt8
    ) {
        emit(
            [
                0xA0 | min(15, channel),
                min(127, note),
                min(127, pressure)
            ],
            to: port
        )
    }

    public func sendPolyPressure(
        port: VirtualPort,
        channel: UInt8,
        note: UInt8,
        normalizedPressure: Double
    ) {
        let pressure7 = Self.midi7(normalizedPressure)
        emit(
            [0xA0 | min(15, channel), min(127, note), pressure7],
            midi2Override: MIDI2UMPEncoder.polyPressureMessage(
                channel: channel,
                note: note,
                normalizedPressure: normalizedPressure
            ),
            to: port
        )
    }

    public func sendChannelPressure(pressure: UInt8, channel: UInt8 = 0) {
        sendChannelPressure(port: .mpe, channel: channel, pressure: pressure)
    }

    public func sendChannelPressure(
        port: VirtualPort,
        channel: UInt8,
        pressure: UInt8
    ) {
        emit([0xD0 | min(15, channel), min(127, pressure)], to: port)
    }

    public func sendChannelPressure(
        port: VirtualPort,
        channel: UInt8,
        normalizedPressure: Double
    ) {
        let pressure7 = Self.midi7(normalizedPressure)
        emit(
            [0xD0 | min(15, channel), pressure7],
            midi2Override: MIDI2UMPEncoder.channelPressureMessage(
                channel: channel,
                normalizedPressure: normalizedPressure
            ),
            to: port
        )
    }

    public func sendTimbreCC74(port: VirtualPort, channel: UInt8, value: UInt8) {
        sendCC(port: port, channel: channel, controller: 74, value: value)
    }

    public func sendTimbreCC74(
        port: VirtualPort,
        channel: UInt8,
        normalizedValue: Double
    ) {
        sendCC(
            port: port,
            channel: channel,
            controller: 74,
            normalizedValue: normalizedValue
        )
    }

    public func sendPitchBend(value: UInt16, channel: UInt8 = 0) {
        sendPitchBend(port: .main, channel: channel, value: value)
    }

    public func sendPitchBend(port: VirtualPort, channel: UInt8, value: UInt16) {
        let clamped = min(UInt16(16_383), value)
        emit(
            [
                0xE0 | min(15, channel),
                UInt8(clamped & 0x7F),
                UInt8((clamped >> 7) & 0x7F)
            ],
            to: port
        )
    }

    public func sendPitchBend(
        port: VirtualPort,
        channel: UInt8,
        semitoneOffset: Double,
        bendRangeSemitones: Double
    ) {
        let value14 = Self.pitchBendValue(
            semitoneOffset: semitoneOffset,
            bendRangeSemitones: bendRangeSemitones
        )
        let safeChannel = min(15, channel)
        emit(
            [
                0xE0 | safeChannel,
                UInt8(value14 & 0x7F),
                UInt8((value14 >> 7) & 0x7F)
            ],
            midi2Override: MIDI2UMPEncoder.pitchBendMessage(
                channel: safeChannel,
                semitoneOffset: semitoneOffset,
                bendRangeSemitones: bendRangeSemitones
            ),
            to: port
        )
    }

    public static func pitchBendValue(
        semitoneOffset: Double,
        bendRangeSemitones: Double
    ) -> UInt16 {
        MIDIValueCodec.asymmetricPitchBend14(
            semitones: semitoneOffset,
            range: bendRangeSemitones
        )
    }

    // MARK: - Native MIDI 2 Per-Note & SysEx

    /// Sends high-resolution per-note expression (Pitch Bend, Pressure, and Timbre).
    /// When MIDI 2.0 transport is active, generates native 32-bit Per-Note UMPs directly for the note.
    /// When MIDI 1.0 / MPE is active, routes through member channel pitch bend, channel pressure, and CC74.
    public func sendPerNoteExpression(
        port: VirtualPort = .mpe,
        channel: UInt8,
        note: UInt8,
        semitoneOffset: Double,
        normalizedPressure: Double,
        normalizedTimbre: Double,
        bendRangeSemitones: Double = 48.0
    ) {
        let safeChannel = min(15, channel)
        let safeNote = min(127, note)

        if transportProtocol == .midi2 {
            let pbUMP = MIDI2UMPEncoder.perNotePitchBendMessage(
                channel: safeChannel,
                note: safeNote,
                semitoneOffset: semitoneOffset,
                bendRangeSemitones: bendRangeSemitones
            )
            let pressUMP = MIDI2UMPEncoder.perNotePressureMessage(
                channel: safeChannel,
                note: safeNote,
                normalizedPressure: normalizedPressure
            )
            let timbreUMP = MIDI2UMPEncoder.perNoteRegisteredControllerMessage(
                channel: safeChannel,
                note: safeNote,
                controllerIndex: 74,
                normalizedValue: normalizedTimbre
            )
            emitRawMIDI2UMP(pbUMP, to: port)
            emitRawMIDI2UMP(pressUMP, to: port)
            emitRawMIDI2UMP(timbreUMP, to: port)
        } else {
            sendPitchBend(
                port: port,
                channel: safeChannel,
                semitoneOffset: semitoneOffset,
                bendRangeSemitones: bendRangeSemitones
            )
            sendChannelPressure(
                port: port,
                channel: safeChannel,
                normalizedPressure: normalizedPressure
            )
            sendTimbreCC74(
                port: port,
                channel: safeChannel,
                normalizedValue: normalizedTimbre
            )
        }
    }

    /// Dispatches a raw 64-bit MIDI 2.0 UMP message to the selected virtual endpoint.
    public func emitRawMIDI2UMP(_ message: MIDIMessage_64, to port: VirtualPort) {
        lock.lock()
        midiActivityTimestamp = Date()
        let endpoint = virtualMIDIEnabled ? outputs[port] : nil
        lock.unlock()

        guard let endpoint, endpoint != 0 else { return }
        sendMIDI2Message(message, endpoint: endpoint)
    }

    /// Dispatches a Universal SysEx or MIDI-CI byte buffer to the virtual endpoint.
    public func sendSysEx(_ bytes: [UInt8], to port: VirtualPort = .main) {
        lock.lock()
        midiActivityTimestamp = Date()
        let endpoint = virtualMIDIEnabled ? outputs[port] : nil
        let protocolID = transportProtocol
        lock.unlock()

        guard let endpoint, endpoint != 0 else { return }
        sendMIDIMessage(bytes, endpoint: endpoint, protocolID: protocolID)
    }

    private static func midi7(_ normalizedValue: Double) -> UInt8 {
        MIDIValueCodec.midi7(normalizedValue)
    }

    /// Dispatches a semantic channel event to one DAW-visible source.
    public func send(_ event: PerformanceEvent, to port: VirtualPort = .main) {
        switch event {
        case .noteOn(let channel, let note, let velocity):
            sendNoteOn(port: port, channel: channel, note: note, velocity: velocity)
        case .noteOff(let channel, let note):
            sendNoteOff(port: port, channel: channel, note: note)
        case .pitchBend(let channel, let value):
            let unsigned = MIDIValueCodec.unsignedPitchBend14(signed: value)
            sendPitchBend(port: port, channel: channel, value: unsigned)
        case .polyPressure(let channel, let note, let pressure):
            sendPolyPressure(
                port: port,
                channel: channel,
                note: note,
                pressure: pressure
            )
        case .channelPressure(let channel, let pressure):
            sendChannelPressure(port: port, channel: channel, pressure: pressure)
        case .controlChange(let channel, let controller, let value):
            sendCC(
                port: port,
                channel: channel,
                controller: controller,
                value: value
            )
        case .timbreCC74(let channel, let value):
            sendTimbreCC74(port: port, channel: channel, value: value)
        case .allNotesOff(let channel):
            sendAllNotesOff(port: port, channel: channel)
        }
    }

    public func send<S: Sequence>(
        _ events: S,
        to port: VirtualPort = .main
    ) where S.Element == PerformanceEvent {
        for event in events {
            send(event, to: port)
        }
    }

    /// Stops and forgets every tracked note on one source/channel, then neutralizes
    /// the channel so reconnecting a DAW instrument cannot inherit expression state.
    public func sendAllNotesOff(port: VirtualPort, channel: UInt8) {
        let safeChannel = min(15, channel)
        lock.lock()
        let notesToStop = activeNotes
            .filter { $0.port == port && $0.channel == safeChannel }
            .sorted { $0.note < $1.note }
        activeNotes.subtract(notesToStop)
        lock.unlock()

        for activeNote in notesToStop {
            emit([0x80 | safeChannel, activeNote.note, 0], to: port)
        }
        emitChannelCleanup(to: port, channel: safeChannel)
    }

    /// Sends note-offs, neutral expression, and All Notes Off on every public port/channel.
    public func panic() {
        lock.lock()
        let notesToStop = activeNotes.sorted {
            if $0.port.rawValue != $1.port.rawValue {
                return $0.port.rawValue < $1.port.rawValue
            }
            if $0.channel != $1.channel { return $0.channel < $1.channel }
            return $0.note < $1.note
        }
        activeNotes.removeAll()
        lastSentNotes.removeAll()
        lock.unlock()

        for activeNote in notesToStop {
            emit(
                [
                    0x80 | activeNote.channel,
                    activeNote.note,
                    0
                ],
                to: activeNote.port
            )
        }

        for port in VirtualPort.allCases {
            for channel: UInt8 in 0..<16 {
                emitChannelCleanup(to: port, channel: channel)
            }
        }
    }

    // MARK: - Low-level MIDI

    private func emit(_ bytes: [UInt8], to port: VirtualPort) {
        emit(bytes, midi2Override: nil, to: port)
    }

    private func emit(
        _ bytes: [UInt8],
        midi2Override: MIDIMessage_64?,
        to port: VirtualPort
    ) {
        lock.lock()
        let record = MIDIMessageRecord(port: port, bytes: bytes)
        if messageLog.count < Self.messageLogCapacity {
            messageLog.append(record)
        } else {
            messageLog[messageLogWriteIndex] = record
            messageLogWriteIndex = (messageLogWriteIndex + 1) % Self.messageLogCapacity
        }
        midiActivityTimestamp = Date()
        let endpoint = virtualMIDIEnabled ? outputs[port] : nil
        let protocolID = transportProtocol
        lock.unlock()

        guard let endpoint, endpoint != 0 else { return }

        if protocolID == .midi2, let midi2Override {
            sendMIDI2Message(midi2Override, endpoint: endpoint)
        } else {
            sendMIDIMessage(bytes, endpoint: endpoint, protocolID: protocolID)
        }
    }

    private func emitChannelCleanup(to port: VirtualPort, channel: UInt8) {
        let safeChannel = min(15, channel)
        emit([0xE0 | safeChannel, 0, 0x40], to: port) // Pitch Bend centre
        emit([0xD0 | safeChannel, 0], to: port) // Channel Pressure off
        emit([0xB0 | safeChannel, 11, 127], to: port) // Expression neutral
        emit([0xB0 | safeChannel, 64, 0], to: port) // Sustain off
        emit([0xB0 | safeChannel, 65, 0], to: port) // Portamento off
        emit([0xB0 | safeChannel, 66, 0], to: port) // Sostenuto off
        emit([0xB0 | safeChannel, 74, 64], to: port) // Timbre neutral
        emit([0xB0 | safeChannel, 121, 0], to: port) // Reset All Controllers
        emit([0xB0 | safeChannel, 101, 127], to: port) // RPN null
        emit([0xB0 | safeChannel, 100, 127], to: port)
        emit([0xB0 | safeChannel, 123, 0], to: port) // All Notes Off
        emit([0xB0 | safeChannel, 120, 0], to: port) // All Sound Off
    }

    private func sendMIDIMessage(
        _ bytes: [UInt8],
        endpoint: MIDIEndpointRef,
        protocolID: MIDITransportProtocol
    ) {
        guard endpoint != 0 else { return }

        switch protocolID {
        case .midi1:
            sendMIDI1Message(bytes, endpoint: endpoint)
        case .midi2:
            sendMIDI2Message(bytes, endpoint: endpoint)
        }
    }

    private func sendMIDI1Message(_ bytes: [UInt8], endpoint: MIDIEndpointRef) {
        var eventList = MIDIEventList()
        let packet = MIDIEventListInit(&eventList, ._1_0)
        let word: UInt32

        if bytes.count == 3 {
            word = (0x20 << 24)
                | (UInt32(bytes[0]) << 16)
                | (UInt32(bytes[1]) << 8)
                | UInt32(bytes[2])
        } else if bytes.count == 2 {
            word = (0x20 << 24)
                | (UInt32(bytes[0]) << 16)
                | (UInt32(bytes[1]) << 8)
        } else {
            return
        }

        let words = [word]
        _ = MIDIEventListAdd(
            &eventList,
            1024,
            packet,
            mach_absolute_time(),
            words.count,
            words
        )
        MIDIReceivedEventList(endpoint, &eventList)
    }

    private func sendMIDI2Message(_ bytes: [UInt8], endpoint: MIDIEndpointRef) {
        guard let message = MIDI2UMPEncoder.message(from: bytes) else { return }
        sendMIDI2Message(message, endpoint: endpoint)
    }

    private func sendMIDI2Message(_ message: MIDIMessage_64, endpoint: MIDIEndpointRef) {
        var eventList = MIDIEventList()
        let packet = MIDIEventListInit(&eventList, ._2_0)
        let words = [message.word0, message.word1]
        _ = MIDIEventListAdd(
            &eventList,
            1024,
            packet,
            mach_absolute_time(),
            words.count,
            words
        )
        MIDIReceivedEventList(endpoint, &eventList)
    }
}

/// Compatibility name used by the richer workspaces and existing integrations.
public typealias MIDIManager = MIDIEngine
