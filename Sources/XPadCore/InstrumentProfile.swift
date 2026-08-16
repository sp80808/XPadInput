import Foundation

/// Broad instrument families whose physical techniques and expression defaults differ.
public enum InstrumentFamily: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case guitar = "Guitar"
    case bass = "Bass"
    case keys = "Keys"
    case synthLead = "Synth Lead"
    case synthPoly = "Synth Poly"
    case strings = "Strings"
    case brass = "Brass"
    case woodwind = "Woodwind"
    case plucked = "Plucked"
    case percussion = "Percussion"
    case genericMPE = "Generic MPE"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .synthLead: return "Lead"
        case .synthPoly: return "Poly"
        case .genericMPE: return "MPE"
        default: return rawValue
        }
    }
}

public enum InstrumentPolyphonyMode: String, CaseIterable, Codable, Hashable, Sendable {
    case monophonic
    case polyphonic
    case mpe
}

public enum PitchBendCurve: String, CaseIterable, Codable, Hashable, Sendable {
    case precision
    case linear
    case expressive
    case aggressive

    public func apply(_ input: Double) -> Double {
        let value = input.isFinite ? min(1.0, max(-1.0, input)) : 0.0
        let sign = value < 0.0 ? -1.0 : 1.0
        let magnitude = abs(value)
        switch self {
        case .precision: return sign * pow(magnitude, 2.0)
        case .linear: return value
        case .expressive: return sign * pow(magnitude, 1.5)
        case .aggressive: return sign * pow(magnitude, 0.72)
        }
    }
}

public enum PressureCurve: String, CaseIterable, Codable, Hashable, Sendable {
    case soft
    case linear
    case expressive
    case aggressive

    public func apply(_ input: Double) -> Double {
        let value = input.isFinite ? min(1.0, max(0.0, input)) : 0.0
        switch self {
        case .soft: return sqrt(value)
        case .linear: return value
        case .expressive: return value * value * (3.0 - 2.0 * value)
        case .aggressive: return pow(value, 0.62)
        }
    }
}

/// Musician-facing labels for the active physical grammar. Raw CC details stay in MAP.
public struct GestureHUDLabels: Codable, Hashable, Sendable {
    public let leftStick: String
    public let rightStick: String
    public let l1: String
    public let r1: String
    public let l2: String
    public let r2: String
    public let gyro: String
    public let faceA: String
    public let faceX: String
    public let faceY: String
    public let faceB: String

    public init(
        leftStick: String,
        rightStick: String,
        l1: String,
        r1: String,
        l2: String,
        r2: String,
        gyro: String,
        faceA: String,
        faceX: String,
        faceY: String,
        faceB: String
    ) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.l1 = l1
        self.r1 = r1
        self.l2 = l2
        self.r2 = r2
        self.gyro = gyro
        self.faceA = faceA
        self.faceX = faceX
        self.faceY = faceY
        self.faceB = faceB
    }

    public static let guitar = GestureHUDLabels(
        leftStick: "Chord / Note",
        rightStick: "Strum / Bend",
        l1: "Colour",
        r1: "Techniques",
        l2: "Mute",
        r2: "Pressure",
        gyro: "Vibrato",
        faceA: "Root",
        faceX: "3rd",
        faceY: "5th",
        faceB: "7th"
    )

    public static let keys = GestureHUDLabels(
        leftStick: "Voicing",
        rightStick: "Strum",
        l1: "Extensions",
        r1: "Grace / Trill",
        l2: "Sustain",
        r2: "Aftertouch",
        gyro: "Expression",
        faceA: "Root",
        faceX: "3rd",
        faceY: "5th",
        faceB: "7th"
    )

    public static let synthLead = GestureHUDLabels(
        leftStick: "Scale Notes",
        rightStick: "Bend / Timbre",
        l1: "Octave",
        r1: "Legato",
        l2: "Glide",
        r2: "Pressure",
        gyro: "Vibrato",
        faceA: "Root",
        faceX: "Next",
        faceY: "5th",
        faceB: "Octave"
    )

    public static let bass = GestureHUDLabels(
        leftStick: "Note",
        rightStick: "Slide / Bend",
        l1: "Octave",
        r1: "Ghost",
        l2: "Mute",
        r2: "Pressure",
        gyro: "Vibrato",
        faceA: "Root",
        faceX: "3rd",
        faceY: "5th",
        faceB: "7th"
    )

    public static let strings = GestureHUDLabels(
        leftStick: "Pitch",
        rightStick: "Bow",
        l1: "Position",
        r1: "Articulation",
        l2: "Mute",
        r2: "Bow Pressure",
        gyro: "Vibrato",
        faceA: "Root",
        faceX: "3rd",
        faceY: "5th",
        faceB: "7th"
    )

    public static let genericMPE = GestureHUDLabels(
        leftStick: "Note",
        rightStick: "Bend / Timbre",
        l1: "Layer",
        r1: "Alt",
        l2: "Glide",
        r2: "Pressure",
        gyro: "Vibrato",
        faceA: "Root",
        faceX: "3rd",
        faceY: "5th",
        faceB: "7th"
    )
}

/// Family-level playing behavior. It deliberately contains musical capabilities rather
/// than controller button assignments or MIDI packet values.
public struct InstrumentProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let family: InstrumentFamily
    public let name: String
    public let polyphonyMode: InstrumentPolyphonyMode
    public var preferredPitchBendRange: Double
    public var allowDownwardBend: Bool
    public var defaultBendCurve: PitchBendCurve
    public var defaultPressureCurve: PressureCurve
    public var defaultPitchAssist: PitchAssistMode
    public var pressureMode: PressureMIDIMode
    public var midiArticulationStrategy: ArticulationMIDIStrategy
    public var slideMIDIStrategy: SlideMIDIStrategy
    public var defaultGestureMapping: GestureHUDLabels
    public var supportedTechniques: Set<MusicalTechnique>

    public var supportsAftertouch: Bool
    public var supportsBowing: Bool
    public var supportsGhostNotes: Bool
    public var supportsPalmMute: Bool
    public var supportsPinchHarmonics: Bool
    public var supportsPitchBend: Bool
    public var supportsSlides: Bool
    public var supportsStrumming: Bool
    public var supportsHammerOns: Bool
    public var supportsPullOffs: Bool
    public var supportsLegato: Bool

    public var hammerOnMaxGapMs: Double
    public var hammerOnMaxInterval: Int
    public var pullOffMaxGapMs: Double
    public var vibratoDepthSemitones: Double
    public var vibratoRateHz: Double
    public var stringCount: Int

    public init(
        id: String,
        family: InstrumentFamily,
        name: String,
        polyphonyMode: InstrumentPolyphonyMode,
        preferredPitchBendRange: Double,
        allowDownwardBend: Bool = true,
        defaultBendCurve: PitchBendCurve = .expressive,
        defaultPressureCurve: PressureCurve = .expressive,
        defaultPitchAssist: PitchAssistMode = .light,
        pressureMode: PressureMIDIMode = .channelPressure,
        midiArticulationStrategy: ArticulationMIDIStrategy = .mpeTimbre,
        slideMIDIStrategy: SlideMIDIStrategy = .pitchBend,
        defaultGestureMapping: GestureHUDLabels = .guitar,
        supportedTechniques: Set<MusicalTechnique> = [.normal],
        supportsAftertouch: Bool = false,
        supportsBowing: Bool = false,
        supportsGhostNotes: Bool = false,
        supportsPalmMute: Bool = false,
        supportsPinchHarmonics: Bool = false,
        supportsPitchBend: Bool = false,
        supportsSlides: Bool = false,
        supportsStrumming: Bool = false,
        supportsHammerOns: Bool = false,
        supportsPullOffs: Bool = false,
        supportsLegato: Bool = false,
        hammerOnMaxGapMs: Double = 180.0,
        hammerOnMaxInterval: Int = 5,
        pullOffMaxGapMs: Double = 210.0,
        vibratoDepthSemitones: Double = 0.18,
        vibratoRateHz: Double = 5.2,
        stringCount: Int = 0
    ) {
        var techniques = supportedTechniques
        techniques.insert(.normal)
        self.id = id
        self.family = family
        self.name = name
        self.polyphonyMode = polyphonyMode
        self.preferredPitchBendRange = Self.nonNegative(preferredPitchBendRange)
        self.allowDownwardBend = allowDownwardBend
        self.defaultBendCurve = defaultBendCurve
        self.defaultPressureCurve = defaultPressureCurve
        self.defaultPitchAssist = defaultPitchAssist
        self.pressureMode = pressureMode
        self.midiArticulationStrategy = midiArticulationStrategy
        self.slideMIDIStrategy = slideMIDIStrategy
        self.defaultGestureMapping = defaultGestureMapping
        self.supportedTechniques = techniques
        self.supportsAftertouch = supportsAftertouch
        self.supportsBowing = supportsBowing
        self.supportsGhostNotes = supportsGhostNotes
        self.supportsPalmMute = supportsPalmMute
        self.supportsPinchHarmonics = supportsPinchHarmonics
        self.supportsPitchBend = supportsPitchBend && self.preferredPitchBendRange > 0.0
        self.supportsSlides = supportsSlides
        self.supportsStrumming = supportsStrumming
        self.supportsHammerOns = supportsHammerOns
        self.supportsPullOffs = supportsPullOffs
        self.supportsLegato = supportsLegato
        self.hammerOnMaxGapMs = Self.nonNegative(hammerOnMaxGapMs)
        self.hammerOnMaxInterval = max(0, hammerOnMaxInterval)
        self.pullOffMaxGapMs = Self.nonNegative(pullOffMaxGapMs)
        self.vibratoDepthSemitones = Self.nonNegative(vibratoDepthSemitones)
        self.vibratoRateHz = Self.nonNegative(vibratoRateHz)
        self.stringCount = max(0, stringCount)
    }

    public var pitchBendRangeSemitones: Double { preferredPitchBendRange }
    public var allowsDownwardPitchBend: Bool { allowDownwardBend }

    public func supports(_ technique: MusicalTechnique) -> Bool {
        supportedTechniques.contains(technique)
    }

    private static func nonNegative(_ value: Double) -> Double {
        value.isFinite ? max(0.0, value) : 0.0
    }

    public static let guitar = InstrumentProfile(
        id: "guitar.expressive",
        family: .guitar,
        name: "Guitar",
        polyphonyMode: .mpe,
        preferredPitchBendRange: 2.0,
        allowDownwardBend: true,
        defaultBendCurve: .expressive,
        defaultPressureCurve: .expressive,
        defaultPitchAssist: .light,
        pressureMode: .mpePressure,
        midiArticulationStrategy: .mpeTimbre,
        slideMIDIStrategy: .mpePitch,
        defaultGestureMapping: .guitar,
        supportedTechniques: [
            .normal, .accent, .legato, .hammerOn, .pullOff, .slideUp, .slideDown,
            .bend, .preBend, .releaseBend, .vibrato, .palmMute, .harmonic,
            .pinchHarmonic, .aftertouch, .graceNote, .trill
        ],
        supportsAftertouch: true,
        supportsPalmMute: true,
        supportsPinchHarmonics: true,
        supportsPitchBend: true,
        supportsSlides: true,
        supportsStrumming: true,
        supportsHammerOns: true,
        supportsPullOffs: true,
        supportsLegato: true,
        vibratoDepthSemitones: 0.22,
        vibratoRateHz: 5.3,
        stringCount: 6
    )

    public static let keys = InstrumentProfile(
        id: "keys.expressive",
        family: .keys,
        name: "Keys",
        polyphonyMode: .polyphonic,
        preferredPitchBendRange: 0.0,
        allowDownwardBend: false,
        defaultPressureCurve: .linear,
        pressureMode: .channelPressure,
        midiArticulationStrategy: .velocityTimbre,
        slideMIDIStrategy: .legatoRetrigger,
        defaultGestureMapping: .keys,
        supportedTechniques: [
            .normal, .accent, .aftertouch, .polyPressure, .staccato, .sustain,
            .tremolo, .trill, .graceNote
        ],
        supportsAftertouch: true,
        supportsPitchBend: false,
        supportsSlides: false,
        supportsStrumming: true,
        supportsLegato: true,
        vibratoDepthSemitones: 0.0,
        vibratoRateHz: 0.0
    )

    public static let synthLead = InstrumentProfile(
        id: "synth.mpe-lead",
        family: .synthLead,
        name: "Synth Lead",
        polyphonyMode: .mpe,
        preferredPitchBendRange: 12.0,
        allowDownwardBend: true,
        defaultBendCurve: .precision,
        defaultPressureCurve: .expressive,
        defaultPitchAssist: .light,
        pressureMode: .mpePressure,
        midiArticulationStrategy: .mpeTimbre,
        slideMIDIStrategy: .mpePitch,
        defaultGestureMapping: .synthLead,
        supportedTechniques: [
            .normal, .accent, .legato, .portamento, .bend, .preBend,
            .releaseBend, .vibrato, .aftertouch, .polyPressure, .sustain
        ],
        supportsAftertouch: true,
        supportsPitchBend: true,
        supportsSlides: true,
        supportsLegato: true,
        vibratoDepthSemitones: 0.45,
        vibratoRateHz: 5.5
    )

    public static let bass = InstrumentProfile(
        id: "bass.fingerstyle",
        family: .bass,
        name: "Bass",
        polyphonyMode: .mpe,
        preferredPitchBendRange: 2.0,
        defaultBendCurve: .precision,
        defaultPressureCurve: .aggressive,
        pressureMode: .mpePressure,
        midiArticulationStrategy: .mpeTimbre,
        slideMIDIStrategy: .mpePitch,
        defaultGestureMapping: .bass,
        supportedTechniques: [
            .normal, .accent, .legato, .hammerOn, .pullOff, .slideUp, .slideDown,
            .bend, .vibrato, .palmMute, .aftertouch, .ghostNote, .staccato
        ],
        supportsAftertouch: true,
        supportsGhostNotes: true,
        supportsPalmMute: true,
        supportsPitchBend: true,
        supportsSlides: true,
        supportsHammerOns: true,
        supportsPullOffs: true,
        supportsLegato: true,
        hammerOnMaxInterval: 7,
        vibratoDepthSemitones: 0.12,
        vibratoRateHz: 4.8,
        stringCount: 4
    )

    public static let strings = InstrumentProfile(
        id: "strings.expressive",
        family: .strings,
        name: "Strings",
        polyphonyMode: .mpe,
        preferredPitchBendRange: 2.0,
        defaultBendCurve: .precision,
        defaultPressureCurve: .soft,
        pressureMode: .mpePressure,
        midiArticulationStrategy: .mpeTimbre,
        slideMIDIStrategy: .mpePitch,
        defaultGestureMapping: .strings,
        supportedTechniques: [
            .normal, .legato, .portamento, .bend, .vibrato, .aftertouch, .staccato, .tremolo
        ],
        supportsAftertouch: true,
        supportsBowing: true,
        supportsPitchBend: true,
        supportsSlides: true,
        supportsLegato: true,
        vibratoDepthSemitones: 0.10,
        vibratoRateHz: 5.4
    )

    public static let genericMPE = InstrumentProfile(
        id: "mpe.generic",
        family: .genericMPE,
        name: "Generic MPE",
        polyphonyMode: .mpe,
        preferredPitchBendRange: 48.0,
        defaultBendCurve: .linear,
        pressureMode: .mpePressure,
        midiArticulationStrategy: .mpeTimbre,
        slideMIDIStrategy: .mpePitch,
        defaultGestureMapping: .genericMPE,
        supportedTechniques: [
            .normal, .legato, .portamento, .bend, .vibrato, .aftertouch, .polyPressure
        ],
        supportsAftertouch: true,
        supportsPitchBend: true,
        supportsSlides: true,
        supportsLegato: true,
        vibratoDepthSemitones: 0.4,
        vibratoRateHz: 5.5
    )

    public static let allProfiles: [InstrumentProfile] = [.guitar, .bass, .keys, .synthLead, .strings, .genericMPE]
    public static let playableProfiles: [InstrumentProfile] = allProfiles

    public static func profile(for family: InstrumentFamily) -> InstrumentProfile {
        playableProfiles.first(where: { $0.family == family }) ?? .genericMPE
    }
}

public enum PerformancePreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case guitarCleanExpressive = "Guitar — Clean Expressive"
    case guitarDrivenLead = "Guitar — Driven Lead"
    case bassFingerstyle = "Bass — Fingerstyle"
    case synthMPELead = "Synth — MPE Lead"
    case stringsExpressive = "Strings — Expressive"

    public var id: String { rawValue }

    public var family: InstrumentFamily {
        switch self {
        case .guitarCleanExpressive, .guitarDrivenLead: return .guitar
        case .bassFingerstyle: return .bass
        case .synthMPELead: return .synthLead
        case .stringsExpressive: return .strings
        }
    }

    public func applied(to base: InstrumentProfile) -> InstrumentProfile {
        var profile = InstrumentProfile.profile(for: family)
        switch self {
        case .guitarCleanExpressive:
            profile.preferredPitchBendRange = 2.0
            profile.vibratoDepthSemitones = 0.16
            profile.defaultPressureCurve = .expressive
        case .guitarDrivenLead:
            profile.preferredPitchBendRange = 2.0
            profile.vibratoDepthSemitones = 0.28
            profile.defaultPressureCurve = .aggressive
            profile.hammerOnMaxGapMs = 220
        case .bassFingerstyle:
            profile.preferredPitchBendRange = 2.0
            profile.defaultPressureCurve = .aggressive
            profile.vibratoDepthSemitones = 0.10
        case .synthMPELead:
            profile.preferredPitchBendRange = 12.0
            profile.vibratoDepthSemitones = 0.4
        case .stringsExpressive:
            profile.vibratoDepthSemitones = 0.12
            profile.defaultPressureCurve = .soft
        }
        _ = base
        return profile
    }
}
