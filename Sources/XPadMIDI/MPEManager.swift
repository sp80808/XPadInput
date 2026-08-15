import Foundation
import XPadCore

/// One active MPE member-channel voice. Channel is zero-indexed (1...14 = MIDI Ch 2...15).
public struct MPEVoice: Equatable, Sendable {
    public let note: UInt8
    public let channel: UInt8
    public let timestamp: TimeInterval
    public var currentPitchBend: Double
    public var currentPressure: UInt8
    public var currentTimbre: UInt8
    public var attackVelocity: UInt8
    public var technique: MusicalTechnique
    public var legatoSource: UInt8?
    var currentPitchBendValue: UInt16

    public init(
        note: UInt8,
        channel: UInt8,
        timestamp: TimeInterval,
        currentPitchBend: Double = 0,
        currentPressure: UInt8 = 0,
        currentTimbre: UInt8 = 64,
        attackVelocity: UInt8 = 80,
        technique: MusicalTechnique = .normal,
        legatoSource: UInt8? = nil
    ) {
        self.note = note
        self.channel = channel
        self.timestamp = timestamp
        self.currentPitchBend = currentPitchBend
        self.currentPressure = currentPressure
        self.currentTimbre = currentTimbre
        self.attackVelocity = min(127, attackVelocity)
        self.technique = technique
        self.legatoSource = legatoSource
        self.currentPitchBendValue = 8192
    }
}

/// Deterministic lower-zone MPE voice allocation and expression lifecycle.
public final class MPEManager: @unchecked Sendable {
    private let midiEngine: MIDIEngine
    private let memberChannels: [UInt8] = Array(1...14)
    private var activeVoices: [UInt8: MPEVoice] = [:]
    private var nextChannelIndex = 0
    private var configuredBendRangeSemitones: Double
    private let lock = NSLock()

    public init(
        midiEngine: MIDIEngine = MIDIEngine(),
        bendRangeSemitones: Double = 48
    ) {
        self.midiEngine = midiEngine
        self.configuredBendRangeSemitones = max(1, bendRangeSemitones)
    }

    public convenience init(
        midiManager: MIDIManager,
        bendRangeSemitones: Double = 48
    ) {
        self.init(
            midiEngine: midiManager,
            bendRangeSemitones: bendRangeSemitones
        )
    }

    public var bendRangeSemitones: Double {
        get {
            lock.lock()
            let value = configuredBendRangeSemitones
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            configuredBendRangeSemitones = max(1, newValue)
            lock.unlock()
            sendPitchBendRangeConfiguration()
        }
    }

    public var activeVoiceCount: Int {
        lock.lock()
        let count = activeVoices.count
        lock.unlock()
        return count
    }

    public func activeVoice(for note: UInt8) -> MPEVoice? {
        lock.lock()
        let voice = activeVoices[note]
        lock.unlock()
        return voice
    }

    public func voice(for note: UInt8) -> MPEVoice? {
        activeVoice(for: note)
    }

    /// Initializes a lower MPE zone (master Ch 1, member Ch 2...15) and bend range.
    public func sendMPEZoneConfiguration() {
        midiEngine.sendCC(port: .mpe, channel: 0, controller: 101, value: 0)
        midiEngine.sendCC(port: .mpe, channel: 0, controller: 100, value: 6)
        midiEngine.sendCC(port: .mpe, channel: 0, controller: 6, value: 14)
        resetRPN(on: 0)
        sendPitchBendRangeConfiguration()
    }

    /// Advertises the exact per-note bend range used by semantic pitch expression.
    public func sendPitchBendRangeConfiguration() {
        lock.lock()
        let range = configuredBendRangeSemitones
        lock.unlock()

        let semitones = UInt8(max(1, min(96, Int(range.rounded(.down)))))
        let cents = UInt8(max(0, min(99, Int(((range - floor(range)) * 100).rounded()))))

        for channel in memberChannels {
            midiEngine.sendCC(port: .mpe, channel: channel, controller: 101, value: 0)
            midiEngine.sendCC(port: .mpe, channel: channel, controller: 100, value: 0)
            midiEngine.sendCC(port: .mpe, channel: channel, controller: 6, value: semitones)
            midiEngine.sendCC(port: .mpe, channel: channel, controller: 38, value: cents)
            resetRPN(on: channel)
        }
    }

    /// Starts an MPE note after resetting expression on its allocated member channel.
    public func noteOn(note: UInt8, velocity: UInt8, technique: MusicalTechnique = .normal, legatoSource: UInt8? = nil) {
        // CoreMIDI sources do not retain setup traffic for clients that attach later.
        // Re-advertise the lower zone and bend range at the start of every idle phrase.
        lock.lock()
        let startsIdlePhrase = activeVoices.isEmpty
        lock.unlock()
        if startsIdlePhrase && midiEngine.virtualMIDIEnabled {
            sendMPEZoneConfiguration()
        }

        lock.lock()
        defer { lock.unlock() }

        let channel: UInt8
        var channelAlreadyReset = false

        if let existing = activeVoices.removeValue(forKey: note) {
            // A retrigger is the same logical pitch voice. Reusing its member
            // channel avoids stealing an unrelated note when all 14 are busy.
            channel = existing.channel
            release(existing)
            channelAlreadyReset = true
        } else {
            channel = memberChannels[nextChannelIndex % memberChannels.count]
            nextChannelIndex = (nextChannelIndex + 1) % memberChannels.count

            if let occupied = activeVoices.first(where: { $0.value.channel == channel }) {
                activeVoices.removeValue(forKey: occupied.key)
                release(occupied.value)
                channelAlreadyReset = true
            }
        }

        if !channelAlreadyReset {
            resetExpression(on: channel)
        }
        midiEngine.sendNoteOn(
            port: .mpe,
            channel: channel,
            note: note,
            velocity: velocity
        )

        activeVoices[note] = MPEVoice(
            note: note,
            channel: channel,
            timestamp: ProcessInfo.processInfo.systemUptime,
            attackVelocity: velocity,
            technique: technique,
            legatoSource: legatoSource
        )
    }

    /// Releases an MPE note and returns its channel expression to neutral.
    public func noteOff(note: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard let voice = activeVoices.removeValue(forKey: note) else { return }
        release(voice)
    }

    public func setPitchBend(for note: UInt8, semitones: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard var voice = activeVoices[note] else { return }
        let clamped = max(
            -configuredBendRangeSemitones,
            min(configuredBendRangeSemitones, semitones)
        )
        let bendValue = MIDIEngine.pitchBendValue(
            semitoneOffset: clamped,
            bendRangeSemitones: configuredBendRangeSemitones
        )
        voice.currentPitchBend = clamped
        guard voice.currentPitchBendValue != bendValue else {
            activeVoices[note] = voice
            return
        }
        voice.currentPitchBendValue = bendValue
        activeVoices[note] = voice
        midiEngine.sendPitchBend(
            port: .mpe,
            channel: voice.channel,
            value: bendValue
        )
    }

    /// MPE pressure is channel pressure on the note's member channel.
    public func setPressure(for note: UInt8, pressure: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard var voice = activeVoices[note] else { return }
        let clamped = min(UInt8(127), pressure)
        guard voice.currentPressure != clamped else { return }
        voice.currentPressure = clamped
        activeVoices[note] = voice
        midiEngine.sendChannelPressure(
            port: .mpe,
            channel: voice.channel,
            pressure: clamped
        )
    }

    public func setTimbre(for note: UInt8, value: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        guard var voice = activeVoices[note] else { return }
        let clamped = min(UInt8(127), value)
        guard voice.currentTimbre != clamped else { return }
        voice.currentTimbre = clamped
        activeVoices[note] = voice
        midiEngine.sendTimbreCC74(
            port: .mpe,
            channel: voice.channel,
            value: clamped
        )
    }

    public func setPolyPressure(for note: UInt8, pressure: UInt8) {
        lock.lock()
        defer { lock.unlock() }
        guard var voice = activeVoices[note] else { return }
        voice.currentPressure = min(127, pressure)
        activeVoices[note] = voice
        midiEngine.sendPolyPressure(port: .mpe, channel: voice.channel, note: note, pressure: voice.currentPressure)
    }

    /// After a completed slide, keep the member channel without leaving the source note stuck.
    public func retarget(from source: UInt8, to destination: UInt8) {
        guard source != destination else { return }
        lock.lock()
        defer { lock.unlock() }
        guard let voice = activeVoices.removeValue(forKey: source) else { return }

        if let occupied = activeVoices.removeValue(forKey: destination) {
            release(occupied)
        }

        midiEngine.sendNoteOff(port: .mpe, channel: voice.channel, note: source)
        resetExpression(on: voice.channel)
        midiEngine.sendNoteOn(
            port: .mpe,
            channel: voice.channel,
            note: destination,
            velocity: voice.attackVelocity
        )

        activeVoices[destination] = MPEVoice(
            note: destination,
            channel: voice.channel,
            timestamp: ProcessInfo.processInfo.systemUptime,
            attackVelocity: voice.attackVelocity,
            technique: destination >= source ? .slideUp : .slideDown,
            legatoSource: source
        )
    }

    public func stopAllNotes() {
        lock.lock()
        let voices = activeVoices.values.sorted { $0.channel < $1.channel }
        activeVoices.removeAll()
        nextChannelIndex = 0
        lock.unlock()

        for voice in voices {
            release(voice)
        }

        // Tracked Note Offs are the musical path; channel mode messages are the
        // safety net for a DAW that attached late or lost an earlier packet.
        for channel in memberChannels {
            midiEngine.sendAllNotesOff(port: .mpe, channel: channel)
        }
    }

    private func release(_ voice: MPEVoice) {
        midiEngine.sendNoteOff(port: .mpe, channel: voice.channel, note: voice.note)
        resetExpression(on: voice.channel)
    }

    private func resetExpression(on channel: UInt8) {
        midiEngine.sendPitchBend(port: .mpe, channel: channel, value: 8192)
        midiEngine.sendChannelPressure(port: .mpe, channel: channel, pressure: 0)
        midiEngine.sendTimbreCC74(port: .mpe, channel: channel, value: 64)
    }

    private func resetRPN(on channel: UInt8) {
        midiEngine.sendCC(port: .mpe, channel: channel, controller: 101, value: 127)
        midiEngine.sendCC(port: .mpe, channel: channel, controller: 100, value: 127)
    }
}
