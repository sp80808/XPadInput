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
    private let midiManager: MIDIManager
    private let memberChannels: [UInt8] = Array(2...15)
    private var activeVoices: [UInt8: MPEVoice] = [:] // Keyed by MIDI Note
    private var nextChannelIndex: Int = 0
    private let lock = NSLock()

    public init(midiManager: MIDIManager = .shared) {
        self.midiManager = midiManager
    }

    /// Initializes MPE Zone Configuration (Lower Zone, Master = Ch 1, 14 Member Channels).
    public func sendMPEZoneConfiguration() {
        // Master Ch 1: RPN 0x0006 = 14 member channels
        midiManager.sendCC(port: .mpe, channel: 0, controller: 101, value: 0) // RPN MSB
        midiManager.sendCC(port: .mpe, channel: 0, controller: 100, value: 6) // RPN LSB (MPE Config)
        midiManager.sendCC(port: .mpe, channel: 0, controller: 6, value: 14) // Data Entry MSB = 14 member channels
        midiManager.sendCC(port: .mpe, channel: 0, controller: 101, value: 127) // Null RPN
        midiManager.sendCC(port: .mpe, channel: 0, controller: 100, value: 127)
    }

    /// Starts an MPE note on an allocated member channel.
    public func noteOn(note: UInt8, velocity: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        // Find available channel
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

        // Reset bend on this channel before noteOn
        midiManager.sendPitchBend(port: .mpe, channel: channel - 1, semitoneOffset: 0.0)
        midiManager.sendNoteOn(port: .mpe, channel: channel - 1, note: note, velocity: velocity)
    }

    /// Releases an MPE note and frees its channel.
    public func noteOff(note: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices[note] else { return }
        midiManager.sendNoteOff(port: .mpe, channel: voice.channel - 1, note: note)
        activeVoices.removeValue(forKey: note)
    }

    /// Modulates pitch bend for a specific active note.
    public func setPitchBend(for note: UInt8, semitones: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices[note] else { return }
        midiManager.sendPitchBend(port: .mpe, channel: voice.channel - 1, semitoneOffset: semitones)
    }

    /// Modulates polyphonic pressure (Z-axis / aftertouch) for a specific note.
    public func setPressure(for note: UInt8, pressure: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices[note] else { return }
        midiManager.sendPolyPressure(port: .mpe, channel: voice.channel - 1, note: note, pressure: pressure)
    }

    /// Modulates CC74 Timbre (Y-axis / brightness) for a specific note.
    public func setTimbre(for note: UInt8, value: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices[note] else { return }
        midiManager.sendTimbreCC74(port: .mpe, channel: voice.channel - 1, value: value)
    }

    /// Stops all notes and clears voice tracking.
    public func stopAllNotes() {
        lock.lock()
        defer { lock.unlock() }

        for (note, voice) in activeVoices {
            midiManager.sendNoteOff(port: .mpe, channel: voice.channel - 1, note: note)
        }
        activeVoices.removeAll()
        midiManager.panic()
    }
}
