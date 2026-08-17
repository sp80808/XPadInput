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
    public var currentPressureNormalized: Double
    public var currentTimbreNormalized: Double
    public var attackVelocity: UInt8
    public var technique: MusicalTechnique
    public var legatoSource: UInt8?
    var currentPitchBendValue: UInt16
    var currentMIDI2PitchBendValue: UInt32
    var currentMIDI2PressureValue: UInt32
    var currentMIDI2TimbreValue: UInt32

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
        let safePressure = min(127, currentPressure)
        let safeTimbre = min(127, currentTimbre)
        let pressureNormalized = Double(safePressure) / 127.0
        let timbreNormalized = Double(safeTimbre) / 127.0

        self.note = note
        self.channel = channel
        self.timestamp = timestamp
        self.currentPitchBend = currentPitchBend
        self.currentPressure = safePressure
        self.currentTimbre = safeTimbre
        self.currentPressureNormalized = pressureNormalized
        self.currentTimbreNormalized = timbreNormalized
        self.attackVelocity = min(127, attackVelocity)
        self.technique = technique
        self.legatoSource = legatoSource
        self.currentPitchBendValue = 8192
        self.currentMIDI2PitchBendValue = MIDI2UMPEncoder.pitchBendCentre
        self.currentMIDI2PressureValue = MIDI2UMPEncoder.scaleNormalizedTo32(pressureNormalized)
        self.currentMIDI2TimbreValue = MIDI2UMPEncoder.scaleNormalizedTo32(timbreNormalized)
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
    ///
    /// Zone configuration is advertised when virtual MIDI is enabled (and when
    /// the destination changes), not on this attack path. Dumping 14-channel
    /// RPNs before the first Note On of every idle phrase adds tens of
    /// milliseconds of MIDI pass-through jitter. Member-channel expression is
    /// still reset immediately before Note On.
    public func noteOn(note: UInt8, velocity: UInt8, technique: MusicalTechnique = .normal, legatoSource: UInt8? = nil) {
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
            min(configuredBendRangeSemitones, semitones.isFinite ? semitones : 0)
        )
        let bendValue = MIDIEngine.pitchBendValue(
            semitoneOffset: clamped,
            bendRangeSemitones: configuredBendRangeSemitones
        )
        let midi2BendValue = MIDI2UMPEncoder.pitchBend32(
            semitoneOffset: clamped,
            bendRangeSemitones: configuredBendRangeSemitones
        )

        let wireValueUnchanged: Bool
        switch midiEngine.transportProtocol {
        case .midi1:
            wireValueUnchanged = voice.currentPitchBendValue == bendValue
        case .midi2:
            wireValueUnchanged = voice.currentMIDI2PitchBendValue == midi2BendValue
        }

        voice.currentPitchBend = clamped
        voice.currentPitchBendValue = bendValue
        voice.currentMIDI2PitchBendValue = midi2BendValue
        activeVoices[note] = voice
        guard !wireValueUnchanged else { return }

        midiEngine.sendPitchBend(
            port: .mpe,
            channel: voice.channel,
            semitoneOffset: clamped,
            bendRangeSemitones: configuredBendRangeSemitones
        )
    }

    /// Compatibility API for callers that already resolved pressure to MIDI 1 resolution.
    public func setPressure(for note: UInt8, pressure: UInt8) {
        setPressure(for: note, normalizedPressure: Double(min(127, pressure)) / 127.0)
    }

    /// MPE pressure is member-channel pressure. MIDI 2 keeps the normalized value
    /// at 32-bit resolution while MIDI 1 down-quantizes at the transport boundary.
    public func setPressure(for note: UInt8, normalizedPressure: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard var voice = activeVoices[note] else { return }
        let normalized = Self.normalized(normalizedPressure)
        let pressure7 = Self.midi7(normalized)
        let pressure32 = MIDI2UMPEncoder.scaleNormalizedTo32(normalized)

        let wireValueUnchanged: Bool
        switch midiEngine.transportProtocol {
        case .midi1:
            wireValueUnchanged = voice.currentPressure == pressure7
        case .midi2:
            wireValueUnchanged = voice.currentMIDI2PressureValue == pressure32
        }

        voice.currentPressure = pressure7
        voice.currentPressureNormalized = normalized
        voice.currentMIDI2PressureValue = pressure32
        activeVoices[note] = voice
        guard !wireValueUnchanged else { return }

        midiEngine.sendChannelPressure(
            port: .mpe,
            channel: voice.channel,
            normalizedPressure: normalized
        )
    }

    /// Compatibility API for callers that already resolved timbre to MIDI 1 resolution.
    public func setTimbre(for note: UInt8, value: UInt8) {
        setTimbre(for: note, normalizedValue: Double(min(127, value)) / 127.0)
    }

    /// Per-note MPE timbre remains CC74 on the member channel. MIDI 2 sends the
    /// normalized value directly into the 32-bit Control Change field.
    public func setTimbre(for note: UInt8, normalizedValue: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard var voice = activeVoices[note] else { return }
        let normalized = Self.normalized(normalizedValue)
        let timbre7 = Self.midi7(normalized)
        let timbre32 = MIDI2UMPEncoder.scaleNormalizedTo32(normalized)

        let wireValueUnchanged: Bool
        switch midiEngine.transportProtocol {
        case .midi1:
            wireValueUnchanged = voice.currentTimbre == timbre7
        case .midi2:
            wireValueUnchanged = voice.currentMIDI2TimbreValue == timbre32
        }

        voice.currentTimbre = timbre7
        voice.currentTimbreNormalized = normalized
        voice.currentMIDI2TimbreValue = timbre32
        activeVoices[note] = voice
        guard !wireValueUnchanged else { return }

        midiEngine.sendTimbreCC74(
            port: .mpe,
            channel: voice.channel,
            normalizedValue: normalized
        )
    }

    public func setPolyPressure(for note: UInt8, pressure: UInt8) {
        setPolyPressure(for: note, normalizedPressure: Double(min(127, pressure)) / 127.0)
    }

    public func setPolyPressure(for note: UInt8, normalizedPressure: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard var voice = activeVoices[note] else { return }
        let normalized = Self.normalized(normalizedPressure)
        let pressure7 = Self.midi7(normalized)
        let pressure32 = MIDI2UMPEncoder.scaleNormalizedTo32(normalized)

        let wireValueUnchanged: Bool
        switch midiEngine.transportProtocol {
        case .midi1:
            wireValueUnchanged = voice.currentPressure == pressure7
        case .midi2:
            wireValueUnchanged = voice.currentMIDI2PressureValue == pressure32
        }

        voice.currentPressure = pressure7
        voice.currentPressureNormalized = normalized
        voice.currentMIDI2PressureValue = pressure32
        activeVoices[note] = voice
        guard !wireValueUnchanged else { return }

        midiEngine.sendPolyPressure(
            port: .mpe,
            channel: voice.channel,
            note: note,
            normalizedPressure: normalized
        )
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

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    private static func midi7(_ normalized: Double) -> UInt8 {
        UInt8((normalized * 127.0).rounded())
    }
}
