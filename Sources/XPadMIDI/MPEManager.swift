import Foundation
import XPadCore

public struct MPEVoice: Sendable {
    public let note: UInt8
    public let channel: UInt8
    public let timestamp: TimeInterval
    public var currentPitchBend: Double
    public var currentPressure: UInt8
    public var currentTimbre: UInt8
}

public final class MPEManager: @unchecked Sendable {
    private let midiEngine: MIDIEngine
    private let memberChannels: [UInt8] = Array(2...15)
    private var activeVoices: [UInt8: MPEVoice] = [:] // Keyed by MIDI Note
    private var nextChannelIndex: Int = 0
    private let lock = NSLock()

    public init(midiEngine: MIDIEngine = MIDIEngine()) {
        self.midiEngine = midiEngine
    }

    /// Initializes MPE Zone Configuration (Lower Zone, Master = Ch 1, 14 Member Channels).
    public func sendMPEZoneConfiguration() {
        midiEngine.sendCC(controller: 101, value: 0, channel: 0)
        midiEngine.sendCC(controller: 100, value: 6, channel: 0)
        midiEngine.sendCC(controller: 6, value: 14, channel: 0)
        midiEngine.sendCC(controller: 101, value: 127, channel: 0)
        midiEngine.sendCC(controller: 100, value: 127, channel: 0)
    }

    /// Starts an MPE note on an allocated member channel.
    public func noteOn(note: UInt8, velocity: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        let channel = memberChannels[nextChannelIndex % memberChannels.count]
        nextChannelIndex += 1

        let voice = MPEVoice(
            note: note,
            channel: channel,
            timestamp: ProcessInfo.processInfo.systemUptime,
            currentPitchBend: 0.0,
            currentPressure: velocity,
            currentTimbre: 64
        )
        activeVoices[note] = voice

        midiEngine.sendPitchBend(value: 8192, channel: channel - 1)
        midiEngine.sendNoteOn(note: note, velocity: velocity, channel: channel - 1)
    }

    /// Releases an MPE note and frees its channel.
    public func noteOff(note: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices[note] else { return }
        midiEngine.sendNoteOff(note: note, channel: voice.channel - 1)
        activeVoices.removeValue(forKey: note)
    }

    /// Modulates pitch bend for a specific active note.
    public func setPitchBend(for note: UInt8, semitones: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices[note] else { return }
        let normalized = max(-1.0, min(1.0, semitones / 48.0))
        let value = UInt16(8192.0 + normalized * 8191.0)
        midiEngine.sendPitchBend(value: value, channel: voice.channel - 1)
    }

    /// Modulates polyphonic pressure (Z-axis / aftertouch) for a specific note.
    public func setPressure(for note: UInt8, pressure: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices[note] else { return }
        midiEngine.sendCC(controller: 11, value: pressure, channel: voice.channel - 1)
    }

    /// Modulates CC74 Timbre (Y-axis / brightness) for a specific note.
    public func setTimbre(for note: UInt8, value: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices[note] else { return }
        midiEngine.sendCC(controller: 74, value: value, channel: voice.channel - 1)
    }

    /// Stops all notes and clears voice tracking.
    public func stopAllNotes() {
        lock.lock()
        defer { lock.unlock() }

        for (note, voice) in activeVoices {
            midiEngine.sendNoteOff(note: note, channel: voice.channel - 1)
        }
        activeVoices.removeAll()
        midiEngine.panic()
    }
}
