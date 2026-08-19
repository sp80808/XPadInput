import Foundation

/// Lifecycle of a semantic instrument event before MIDI, audio, or export translation.
public enum InstrumentPerformancePhase: String, CaseIterable, Codable, Hashable, Sendable {
    case began
    case changed
    case ended
}

/// Relative melodic roles used by chord-aware face-button layouts and interval memory.
public enum ChordToneRole: String, CaseIterable, Codable, Hashable, Sendable {
    case root
    case third
    case fifth
    case seventh
    case ninth
    case eleventh
    case thirteenth
    case tension
}

/// Normalized expressive dimensions, with pitch retained in musically meaningful semitones.
public struct ExpressionDimensions: Codable, Hashable, Sendable {
    public let attack: Double
    public let pressure: Double
    public let pitchOffsetSemitones: Double
    public let timbre: Double
    public let damping: Double
    public let brightness: Double
    public let position: Double
    public let vibratoDepth: Double
    public let vibratoRate: Double

    public init(
        attack: Double = 0.0,
        pressure: Double = 0.0,
        pitchOffsetSemitones: Double = 0.0,
        timbre: Double = 0.5,
        damping: Double = 0.0,
        brightness: Double = 0.5,
        position: Double = 0.5,
        vibratoDepth: Double = 0.0,
        vibratoRate: Double = 0.0
    ) {
        self.attack = attack.normalizedUnit
        self.pressure = pressure.normalizedUnit
        self.pitchOffsetSemitones = pitchOffsetSemitones.isFinite ? pitchOffsetSemitones : 0.0
        self.timbre = timbre.normalizedUnit
        self.damping = damping.normalizedUnit
        self.brightness = brightness.normalizedUnit
        self.position = position.normalizedUnit
        self.vibratoDepth = vibratoDepth.normalizedUnit
        self.vibratoRate = vibratoRate.normalizedUnit
    }

    public static let neutral = ExpressionDimensions()

    public var midiPressure: UInt8 {
        MIDIValueCodec.midi7(pressure)
    }

    public var midiTimbre: UInt8 {
        MIDIValueCodec.midi7(timbre)
    }
}

/// A technique-level event that can later be translated to MPE, conventional MIDI,
/// the internal synth, recording automation, or another destination.
public struct InstrumentPerformanceEvent: Codable, Hashable, Sendable {
    public let note: Note
    public let previousNote: Note?
    public let targetNote: Note?
    public let phase: InstrumentPerformancePhase
    public let technique: MusicalTechnique
    public let velocity: UInt8
    public let pressure: Double
    public let pitchOffset: Double
    public let timbre: Double
    public let damping: Double
    public let brightness: Double
    public let vibratoDepth: Double
    public let vibratoRate: Double
    public let role: ChordToneRole?
    public let timestamp: TimeInterval

    public var pitchOffsetSemitones: Double { pitchOffset }

    public var expression: ExpressionDimensions {
        ExpressionDimensions(
            attack: Double(velocity) / 127.0,
            pressure: pressure,
            pitchOffsetSemitones: pitchOffset,
            timbre: timbre,
            damping: damping,
            brightness: brightness,
            vibratoDepth: vibratoDepth,
            vibratoRate: vibratoRate
        )
    }

    public init(
        note: Note,
        previousNote: Note? = nil,
        targetNote: Note? = nil,
        phase: InstrumentPerformancePhase = .changed,
        technique: MusicalTechnique = .normal,
        velocity: UInt8 = 80,
        pressure: Double = 0.0,
        pitchOffset: Double = 0.0,
        timbre: Double = 0.5,
        damping: Double = 0.0,
        brightness: Double = 0.5,
        vibratoDepth: Double = 0.0,
        vibratoRate: Double = 0.0,
        role: ChordToneRole? = nil,
        timestamp: TimeInterval = 0.0
    ) {
        let normalized = ExpressionDimensions(
            attack: Double(velocity) / 127.0,
            pressure: pressure,
            pitchOffsetSemitones: pitchOffset,
            timbre: timbre,
            damping: damping,
            brightness: brightness,
            vibratoDepth: vibratoDepth,
            vibratoRate: vibratoRate
        )
        self.note = note
        self.previousNote = previousNote
        self.targetNote = targetNote
        self.phase = phase
        self.technique = technique
        self.velocity = min(127, velocity)
        self.pressure = normalized.pressure
        self.pitchOffset = normalized.pitchOffsetSemitones
        self.timbre = normalized.timbre
        self.damping = normalized.damping
        self.brightness = normalized.brightness
        self.vibratoDepth = normalized.vibratoDepth
        self.vibratoRate = normalized.vibratoRate
        self.role = role
        self.timestamp = timestamp.isFinite ? max(0.0, timestamp) : 0.0
    }

    public init(
        note: Note,
        previousNote: Note? = nil,
        targetNote: Note? = nil,
        phase: InstrumentPerformancePhase,
        technique: MusicalTechnique = .normal,
        expression: ExpressionDimensions,
        role: ChordToneRole? = nil,
        timestamp: TimeInterval = 0.0
    ) {
        self.init(
            note: note,
            previousNote: previousNote,
            targetNote: targetNote,
            phase: phase,
            technique: technique,
            velocity: UInt8((expression.attack * 127.0).rounded()),
            pressure: expression.pressure,
            pitchOffset: expression.pitchOffsetSemitones,
            timbre: expression.timbre,
            damping: expression.damping,
            brightness: expression.brightness,
            vibratoDepth: expression.vibratoDepth,
            vibratoRate: expression.vibratoRate,
            role: role,
            timestamp: timestamp
        )
    }
}

public struct RecordedTechniqueEvent: Codable, Sendable, Equatable {
    public var tick: UInt64
    public var event: InstrumentPerformanceEvent
    public var durationTicks: UInt64

    public init(tick: UInt64, event: InstrumentPerformanceEvent, durationTicks: UInt64 = 0) {
        self.tick = tick
        self.event = event
        self.durationTicks = durationTicks
    }
}
