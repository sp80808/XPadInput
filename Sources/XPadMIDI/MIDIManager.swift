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

/// A test/diagnostic copy of a MIDI 1.0 channel message before it reaches CoreMIDI.
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
                panic()
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
    public var onVirtualMIDIChanged: ((Bool) -> Void)?

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
        let messages = messageLog
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
    private var messageLog: [MIDIMessageRecord] = []
    private let lock = NSLock()

    private struct ActiveNote: Hashable {
        let port: VirtualPort
        let channel: UInt8
        let note: UInt8
    }

    public init() {
        setupMIDIClient()
    }

    deinit {
        panic()
        disposeVirtualSources()
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }

    public func clearMessageLog() {
        lock.lock()
        messageLog.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    private func setupMIDIClient() {
        let status = MIDIClientCreateWithBlock("XPI" as CFString, &midiClient) { _ in }
        if status != noErr {
            print("⚠️ Failed to create XPI MIDI client: \(status)")
        }
    }

    private func createVirtualSources() {
        guard midiClient != 0 else { return }

        for port in VirtualPort.allCases {
            lock.lock()
            let alreadyExists = outputs[port] != nil
            lock.unlock()
            guard !alreadyExists else { continue }

            var endpoint: MIDIEndpointRef = 0
            let status = MIDISourceCreateWithProtocol(
                midiClient,
                port.rawValue as CFString,
                ._1_0,
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
                print("⚠️ Failed to create \(port.rawValue) MIDI source: \(status)")
            }
        }
    }

    private func disposeVirtualSources() {
        lock.lock()
        let endpoints = Array(outputs.values)
        outputs.removeAll()
        lock.unlock()

        for endpoint in endpoints where endpoint != 0 {
            MIDIEndpointDispose(endpoint)
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
        velocity: UInt8
    ) {
        let safeChannel = min(15, channel)
        let safeNote = min(127, note)
        let safeVelocity = min(127, velocity)
        guard safeVelocity > 0 else {
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

        // MIDI 1.0 cannot disambiguate stacked identical notes on one channel.
        // Close an existing voice first so one later Note Off is deterministic.
        if wasAlreadyActive {
            emit([0x80 | safeChannel, safeNote, 0], to: port)
        }

        emit(
            [0x90 | safeChannel, safeNote, safeVelocity],
            to: port
        )
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

    public func sendTimbreCC74(port: VirtualPort, channel: UInt8, value: UInt8) {
        sendCC(port: port, channel: channel, controller: 74, value: value)
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
        sendPitchBend(
            port: port,
            channel: channel,
            value: Self.pitchBendValue(
                semitoneOffset: semitoneOffset,
                bendRangeSemitones: bendRangeSemitones
            )
        )
    }

    public static func pitchBendValue(
        semitoneOffset: Double,
        bendRangeSemitones: Double
    ) -> UInt16 {
        guard bendRangeSemitones > 0 else { return 8192 }
        let normalized = max(-1.0, min(1.0, semitoneOffset / bendRangeSemitones))
        if normalized >= 0 {
            return UInt16((8192.0 + normalized * 8191.0).rounded())
        }
        return UInt16((8192.0 + normalized * 8192.0).rounded())
    }

    /// Dispatches a semantic channel event to one DAW-visible source.
    public func send(_ event: PerformanceEvent, to port: VirtualPort = .main) {
        switch event {
        case .noteOn(let channel, let note, let velocity):
            sendNoteOn(port: port, channel: channel, note: note, velocity: velocity)
        case .noteOff(let channel, let note):
            sendNoteOff(port: port, channel: channel, note: note)
        case .pitchBend(let channel, let value):
            let unsigned = UInt16(max(0, min(16_383, Int(value) + 8_192)))
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
        lock.lock()
        messageLog.append(MIDIMessageRecord(port: port, bytes: bytes))
        if messageLog.count > 2_048 {
            messageLog.removeFirst(messageLog.count - 2_048)
        }
        midiActivityTimestamp = Date()
        let endpoint = virtualMIDIEnabled ? outputs[port] : nil
        lock.unlock()

        guard let endpoint, endpoint != 0 else { return }
        sendMIDIMessage(bytes, endpoint: endpoint)
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

    private func sendMIDIMessage(_ bytes: [UInt8], endpoint: MIDIEndpointRef) {
        guard endpoint != 0 else { return }

        var eventList = MIDIEventList()
        var packet = MIDIEventListInit(&eventList, ._1_0)
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
        packet = MIDIEventListAdd(
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
