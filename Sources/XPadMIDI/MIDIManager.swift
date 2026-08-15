import Foundation
import CoreMIDI
import XPadCore

/// Manages CoreMIDI virtual sources for output to DAWs.
@Observable
public final class MIDIEngine: @unchecked Sendable {
    public var virtualMIDIEnabled: Bool = false {
        didSet {
            if virtualMIDIEnabled {
                createVirtualSources()
            } else {
                disposeVirtualSources()
            }
        }
    }
    
    public var lastSentNotes: [UInt8] = []
    public var midiActivityTimestamp: Date?
    public var isMIDIActive: Bool {
        guard let ts = midiActivityTimestamp else { return false }
        return Date().timeIntervalSince(ts) < 0.3
    }
    
    private var midiClient: MIDIClientRef = 0
    private var mainOutput: MIDIEndpointRef = 0
    private var chordOutput: MIDIEndpointRef = 0
    
    // Track active notes for cleanup
    private var activeNotes: [(channel: UInt8, note: UInt8)] = []
    private let lock = NSLock()
    
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
    
    private func setupMIDIClient() {
        let status = MIDIClientCreateWithBlock("XPadInput" as CFString, &midiClient) { [weak self] notification in
            // Handle MIDI system changes
            _ = self
        }
        
        if status != noErr {
            print("⚠️ Failed to create MIDI client: \(status)")
        }
    }
    
    private func createVirtualSources() {
        guard midiClient != 0 else { return }
        
        // Main output
        if mainOutput == 0 {
            let status = MIDISourceCreateWithProtocol(
                midiClient,
                "XPadInput Main" as CFString,
                ._1_0,
                &mainOutput
            )
            if status != noErr {
                print("⚠️ Failed to create main MIDI source: \(status)")
            }
        }
        
        // Chord output
        if chordOutput == 0 {
            let status = MIDISourceCreateWithProtocol(
                midiClient,
                "XPadInput Chords" as CFString,
                ._1_0,
                &chordOutput
            )
            if status != noErr {
                print("⚠️ Failed to create chord MIDI source: \(status)")
            }
        }
    }
    
    private func disposeVirtualSources() {
        panic()
        if mainOutput != 0 {
            MIDIEndpointDispose(mainOutput)
            mainOutput = 0
        }
        if chordOutput != 0 {
            MIDIEndpointDispose(chordOutput)
            chordOutput = 0
        }
    }
    
    // MARK: - Note Output
    
    public func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        lock.lock()
        activeNotes.append((channel: channel, note: note))
        lock.unlock()
        
        lastSentNotes.append(note)
        if lastSentNotes.count > 12 { lastSentNotes.removeFirst() }
        midiActivityTimestamp = Date()
        
        guard virtualMIDIEnabled, mainOutput != 0 else { return }
        
        let status: UInt8 = 0x90 | (channel & 0x0F)
        sendMIDIMessage([status, note & 0x7F, velocity & 0x7F], endpoint: mainOutput)
        sendMIDIMessage([status, note & 0x7F, velocity & 0x7F], endpoint: chordOutput)
    }
    
    public func sendNoteOff(note: UInt8, channel: UInt8 = 0) {
        lock.lock()
        activeNotes.removeAll { $0.channel == channel && $0.note == note }
        lock.unlock()
        
        guard virtualMIDIEnabled, mainOutput != 0 else { return }
        
        let status: UInt8 = 0x80 | (channel & 0x0F)
        sendMIDIMessage([status, note & 0x7F, 0], endpoint: mainOutput)
        sendMIDIMessage([status, note & 0x7F, 0], endpoint: chordOutput)
    }
    
    public func sendCC(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        guard virtualMIDIEnabled, mainOutput != 0 else { return }
        midiActivityTimestamp = Date()
        
        let status: UInt8 = 0xB0 | (channel & 0x0F)
        sendMIDIMessage([status, controller & 0x7F, value & 0x7F], endpoint: mainOutput)
    }
    
    public func sendPitchBend(value: UInt16, channel: UInt8 = 0) {
        guard virtualMIDIEnabled, mainOutput != 0 else { return }
        midiActivityTimestamp = Date()
        
        let status: UInt8 = 0xE0 | (channel & 0x0F)
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        sendMIDIMessage([status, lsb, msb], endpoint: mainOutput)
    }
    
    /// Send all-notes-off on all channels
    public func panic() {
        lock.lock()
        let notesToStop = activeNotes
        activeNotes.removeAll()
        lock.unlock()
        
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
                sendMIDIMessage([status, 123, 0], endpoint: mainOutput) // All Notes Off
                sendMIDIMessage([status, 123, 0], endpoint: chordOutput)
            }
        }
        
        lastSentNotes.removeAll()
    }
    
    // MARK: - Low-level MIDI
    
    private func sendMIDIMessage(_ bytes: [UInt8], endpoint: MIDIEndpointRef) {
        guard endpoint != 0 else { return }
        
        var eventList = MIDIEventList()
        var packet = MIDIEventListInit(&eventList, ._1_0)
        
        // Convert bytes to UInt32 words
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
        
        MIDIReceivedEventList(endpoint, &eventList)
    }
}
