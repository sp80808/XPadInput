import Foundation
import CoreMIDI

/// Manages CoreMIDI virtual sources for output to DAWs with full MPE support.
@Observable
final class MIDIEngine: @unchecked Sendable {
    var virtualMIDIEnabled: Bool = false {
        didSet {
            if virtualMIDIEnabled {
                createVirtualSources()
            } else {
                disposeVirtualSources()
            }
        }
    }

    /// MPE mode sends each note on its own channel (2-16)
    var mpeEnabled: Bool = true

    var lastSentNotes: [UInt8] = []
    var midiActivityTimestamp: Date?
    var isMIDIActive: Bool {
        guard let ts = midiActivityTimestamp else { return false }
        return Date().timeIntervalSince(ts) < 0.3
    }

    /// MPE channel manager
    let mpe = MPEChannelManager()

    private var midiClient: MIDIClientRef = 0
    private var mainOutput: MIDIEndpointRef = 0
    private var chordOutput: MIDIEndpointRef = 0
    private var melodyOutput: MIDIEndpointRef = 0
    private var bassOutput: MIDIEndpointRef = 0
    private var expressionOutput: MIDIEndpointRef = 0

    // Track active notes for cleanup
    private var activeNotes: [(channel: UInt8, note: UInt8)] = []
    private let lock = NSLock()

    init() {
        setupMIDIClient()
    }

    deinit {
        panic()
        disposeVirtualSources()
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }

    private func setupMIDIClient() {
        let status = MIDIClientCreateWithBlock("XPadInput" as CFString, &midiClient) { [weak self] notification in
            _ = self
        }
        if status != noErr {
            print("⚠️ Failed to create MIDI client: \(status)")
        }
    }

    private func createVirtualSources() {
        guard midiClient != 0 else { return }

        func createSource(_ name: String, ref: inout MIDIEndpointRef) {
            guard ref == 0 else { return }
            let status = MIDISourceCreateWithProtocol(midiClient, name as CFString, ._1_0, &ref)
            if status != noErr {
                print("⚠️ Failed to create MIDI source '\(name)': \(status)")
            }
        }

        createSource("XPadInput Main",       ref: &mainOutput)
        createSource("XPadInput Chords",     ref: &chordOutput)
        createSource("XPadInput Melody",     ref: &melodyOutput)
        createSource("XPadInput Bass",       ref: &bassOutput)
        createSource("XPadInput Expression", ref: &expressionOutput)

        // Send MPE Configuration Message (MCM) on Master Channel
        if mpeEnabled {
            sendMPEConfiguration()
        }
    }

    private func disposeVirtualSources() {
        panic()

        func dispose(_ ref: inout MIDIEndpointRef) {
            if ref != 0 {
                MIDIEndpointDispose(ref)
                ref = 0
            }
        }

        dispose(&mainOutput)
        dispose(&chordOutput)
        dispose(&melodyOutput)
        dispose(&bassOutput)
        dispose(&expressionOutput)
    }

    /// Sends MPE Configuration Message — RPN 0x0006 value 15 on master channel
    private func sendMPEConfiguration() {
        guard virtualMIDIEnabled, mainOutput != 0 else { return }
        let ch = mpe.masterChannel
        // RPN MSB = 0, RPN LSB = 6, Data Entry = 15 (member channels)
        sendMIDIMessage([0xB0 | ch, 101, 0], endpoint: mainOutput)
        sendMIDIMessage([0xB0 | ch, 100, 6], endpoint: mainOutput)
        sendMIDIMessage([0xB0 | ch, 6, 15],  endpoint: mainOutput)
    }

    // MARK: - Note Output (MPE-aware)

    /// Send NoteOn with automatic MPE channel allocation
    func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8? = nil) {
        let ch: UInt8
        if let explicit = channel {
            ch = explicit
        } else if mpeEnabled {
            ch = mpe.allocate(note: note)
        } else {
            ch = 0
        }

        lock.lock()
        activeNotes.append((channel: ch, note: note))
        lock.unlock()

        lastSentNotes.append(note)
        if lastSentNotes.count > 16 { lastSentNotes.removeFirst() }
        midiActivityTimestamp = Date()

        guard virtualMIDIEnabled else { return }

        let status: UInt8 = 0x90 | (ch & 0x0F)
        let msg = [status, note & 0x7F, velocity & 0x7F]
        sendMIDIMessage(msg, endpoint: mainOutput)
        sendMIDIMessage(msg, endpoint: chordOutput)
    }

    /// Send NoteOff with MPE channel release
    func sendNoteOff(note: UInt8, channel: UInt8? = nil) {
        let ch: UInt8
        if let explicit = channel {
            ch = explicit
        } else if mpeEnabled {
            ch = mpe.release(note: note) ?? 0
        } else {
            ch = 0
        }

        lock.lock()
        activeNotes.removeAll { $0.channel == ch && $0.note == note }
        lock.unlock()

        guard virtualMIDIEnabled else { return }

        let status: UInt8 = 0x80 | (ch & 0x0F)
        let msg = [status, note & 0x7F, UInt8(0)]
        sendMIDIMessage(msg, endpoint: mainOutput)
        sendMIDIMessage(msg, endpoint: chordOutput)
    }

    func sendCC(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        guard virtualMIDIEnabled, mainOutput != 0 else { return }
        midiActivityTimestamp = Date()

        let status: UInt8 = 0xB0 | (channel & 0x0F)
        sendMIDIMessage([status, controller & 0x7F, value & 0x7F], endpoint: mainOutput)
        sendMIDIMessage([status, controller & 0x7F, value & 0x7F], endpoint: expressionOutput)
    }

    /// Per-note pitch bend (MPE) — sends on the note's allocated channel
    func sendPerNotePitchBend(note: UInt8, value: UInt16) {
        guard virtualMIDIEnabled, mainOutput != 0, mpeEnabled else { return }
        midiActivityTimestamp = Date()

        lock.lock()
        let allocation = activeNotes.first { $0.note == note }
        lock.unlock()

        guard let ch = allocation?.channel else { return }

        let status: UInt8 = 0xE0 | (ch & 0x0F)
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        sendMIDIMessage([status, lsb, msb], endpoint: mainOutput)
    }

    /// Global pitch bend (master channel or specific channel)
    func sendPitchBend(value: UInt16, channel: UInt8 = 0) {
        guard virtualMIDIEnabled, mainOutput != 0 else { return }
        midiActivityTimestamp = Date()

        let status: UInt8 = 0xE0 | (channel & 0x0F)
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        sendMIDIMessage([status, lsb, msb], endpoint: mainOutput)
    }

    /// CC74 Timbre / Brightness (MPE per-note)
    func sendTimbre(note: UInt8, value: UInt8) {
        guard virtualMIDIEnabled, mainOutput != 0, mpeEnabled else { return }
        midiActivityTimestamp = Date()

        lock.lock()
        let allocation = activeNotes.first { $0.note == note }
        lock.unlock()

        guard let ch = allocation?.channel else { return }

        let status: UInt8 = 0xB0 | (ch & 0x0F)
        sendMIDIMessage([status, 74, value & 0x7F], endpoint: mainOutput)
    }

    /// Channel Pressure / Aftertouch (MPE per-note)
    func sendPressure(note: UInt8, value: UInt8) {
        guard virtualMIDIEnabled, mainOutput != 0, mpeEnabled else { return }
        midiActivityTimestamp = Date()

        lock.lock()
        let allocation = activeNotes.first { $0.note == note }
        lock.unlock()

        guard let ch = allocation?.channel else { return }

        let status: UInt8 = 0xD0 | (ch & 0x0F)
        sendMIDIMessage([status, value & 0x7F], endpoint: mainOutput)
    }

    /// Send all-notes-off on all channels
    func panic() {
        lock.lock()
        let notesToStop = activeNotes
        activeNotes.removeAll()
        lock.unlock()

        mpe.releaseAll()

        // Send specific note-offs for tracked notes
        for note in notesToStop {
            if virtualMIDIEnabled && mainOutput != 0 {
                let status: UInt8 = 0x80 | (note.channel & 0x0F)
                sendMIDIMessage([status, note.note & 0x7F, 0], endpoint: mainOutput)
                sendMIDIMessage([status, note.note & 0x7F, 0], endpoint: chordOutput)
            }
        }

        // Also send All Notes Off CC on all channels
        for ch: UInt8 in 0..<16 {
            if virtualMIDIEnabled && mainOutput != 0 {
                let status: UInt8 = 0xB0 | ch
                sendMIDIMessage([status, 123, 0], endpoint: mainOutput)
                sendMIDIMessage([status, 123, 0], endpoint: chordOutput)
                sendMIDIMessage([status, 120, 0], endpoint: mainOutput)  // All Sound Off
            }
        }

        lastSentNotes.removeAll()
    }

    // MARK: - Port Info

    var virtualPortNames: [String] {
        var names: [String] = []
        if mainOutput != 0       { names.append("XPadInput Main") }
        if chordOutput != 0      { names.append("XPadInput Chords") }
        if melodyOutput != 0     { names.append("XPadInput Melody") }
        if bassOutput != 0       { names.append("XPadInput Bass") }
        if expressionOutput != 0 { names.append("XPadInput Expression") }
        return names
    }

    // MARK: - Low-level MIDI

    private func sendMIDIMessage(_ bytes: [UInt8], endpoint: MIDIEndpointRef) {
        guard endpoint != 0 else { return }

        var eventList = MIDIEventList()
        var packet = MIDIEventListInit(&eventList, ._1_0)

        var words: [UInt32] = []
        if bytes.count == 3 {
            let word: UInt32 = (0x20 << 24) | (UInt32(bytes[0]) << 16) | (UInt32(bytes[1]) << 8) | UInt32(bytes[2])
            words = [word]
        } else if bytes.count == 2 {
            let word: UInt32 = (0x20 << 24) | (UInt32(bytes[0]) << 16) | (UInt32(bytes[1]) << 8)
            words = [word]
        }

        guard !words.isEmpty else { return }
        packet = MIDIEventListAdd(&eventList, 1024, packet, mach_absolute_time(), words.count, words)
        MIDIReceived(endpoint, &eventList)
    }
}
