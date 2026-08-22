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
    public var attackVelocity16: UInt16
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
        attackVelocity16: UInt16? = nil,
        technique: MusicalTechnique = .normal,
        legatoSource: UInt8? = nil
    ) {
        let safePressure = min(127, currentPressure)
        let safeTimbre = min(127, currentTimbre)
        let pressureNormalized = Double(safePressure) / 127.0
        let timbreNormalized = Double(safeTimbre) / 127.0
        let vel7 = min(127, attackVelocity)
        let vel16 = attackVelocity16 ?? MIDI2UMPEncoder.scale7To16(vel7)

        self.note = note
        self.channel = channel
        self.timestamp = timestamp
        self.currentPitchBend = currentPitchBend
        self.currentPressure = safePressure
        self.currentTimbre = safeTimbre
        self.currentPressureNormalized = pressureNormalized
        self.currentTimbreNormalized = timbreNormalized
        self.attackVelocity = vel7
        self.attackVelocity16 = vel16
        self.technique = technique
        self.legatoSource = legatoSource
        self.currentPitchBendValue = 8192
        self.currentMIDI2PitchBendValue = MIDI2UMPEncoder.pitchBendCentre
        self.currentMIDI2PressureValue = MIDI2UMPEncoder.scaleNormalizedTo32(pressureNormalized)
        self.currentMIDI2TimbreValue = MIDI2UMPEncoder.scaleNormalizedTo32(timbreNormalized)
    }
}

/// Deterministic MPE voice allocation and expression lifecycle.
public final class MPEManager: @unchecked Sendable {
    private let midiEngine: MIDIEngine
    private var zoneLayout = MPEZoneLayout.lowerFourteen
    private var memberChannels: [UInt8]
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
        self.memberChannels = zoneLayout.memberChannels
    }

    public var currentZoneLayout: MPEZoneLayout {
        lock.lock()
        let value = zoneLayout
        lock.unlock()
        return value
    }

    /// Rebuilds member-channel allocation to match a DAW host zone. Callers must
    /// silence notes first; this resets the round-robin pointer.
    public func applyZoneLayout(_ layout: MPEZoneLayout, sendConfiguration: Bool = true) {
        lock.lock()
        zoneLayout = layout
        memberChannels = layout.memberChannels
        nextChannelIndex = 0
        lock.unlock()
        if sendConfiguration {
            sendMPEZoneConfiguration()
        }
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

    /// Initializes the active MPE zone (lower: master Ch 1; upper: master Ch 16).
    public func sendMPEZoneConfiguration() {
        lock.lock()
        let layout = zoneLayout
        lock.unlock()

        let master = layout.masterChannel
        let members = UInt8(layout.memberCount)
        midiEngine.sendCC(port: .mpe, channel: master, controller: 101, value: 0)
        midiEngine.sendCC(port: .mpe, channel: master, controller: 100, value: 6)
        midiEngine.sendCC(port: .mpe, channel: master, controller: 6, value: members)
        resetRPN(on: master)
        sendPitchBendRangeConfiguration()
    }

    /// Advertises the exact per-note bend range used by semantic pitch expression.
    public func sendPitchBendRangeConfiguration() {
        lock.lock()
        let range = configuredBendRangeSemitones
        let channels = memberChannels
        lock.unlock()

        let semitones = UInt8(Int(range.rounded(.down)).clamped(to: 1...96))
        let cents = UInt8(Int(((range - floor(range)) * 100).rounded()).clamped(to: 0...99))

        for channel in channels {
            midiEngine.sendCC(port: .mpe, channel: channel, controller: 101, value: 0)
            midiEngine.sendCC(port: .mpe, channel: channel, controller: 100, value: 0)
            midiEngine.sendCC(port: .mpe, channel: channel, controller: 6, value: semitones)
            midiEngine.sendCC(port: .mpe, channel: channel, controller: 38, value: cents)
            resetRPN(on: channel)
        }
    }

    /// Starts an MPE note after resetting expression on its allocated member channel.
    public func noteOn(
        note: UInt8,
        velocity: UInt8,
        velocity16: UInt16? = nil,
        technique: MusicalTechnique = .normal,
        legatoSource: UInt8? = nil
    ) {
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
            velocity: velocity,
            velocity16: velocity16
        )

        activeVoices[note] = MPEVoice(
            note: note,
            channel: channel,
            timestamp: ProcessInfo.processInfo.systemUptime,
            attackVelocity: velocity,
            attackVelocity16: velocity16,
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
        let channels = memberChannels
        activeVoices.removeAll()
        nextChannelIndex = 0
        lock.unlock()

        for voice in voices {
            release(voice)
        }

        // Tracked Note Offs are the musical path; channel mode messages are the
        // safety net for a DAW that attached late or lost an earlier packet.
        for channel in channels {
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
        value.normalizedUnit
    }

    private static func midi7(_ normalized: Double) -> UInt8 {
        MIDIValueCodec.midi7(normalized)
    }
}
