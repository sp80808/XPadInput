import Foundation

/// How an articulation is represented at the MIDI destination.
/// PLAY never exposes these — they live in MAP / destination settings.
public enum ArticulationMIDIStrategy: String, CaseIterable, Codable, Sendable {
    case mpeTimbre = "MPE Timbre"
    case midiNote = "MIDI Note"
    case keyswitch = "Keyswitch"
    case midiCC = "MIDI CC"
    case velocityTimbre = "Velocity / Timbre"

    public var detail: String {
        switch self {
        case .mpeTimbre:
            return "CC74 + pressure + velocity, optional pitch shift"
        case .midiNote:
            return "Trigger the harmonic pitch as a MIDI note"
        case .keyswitch:
            return "Profile-specific articulation keyswitch"
        case .midiCC:
            return "Library articulation via CC"
        case .velocityTimbre:
            return "Approximate with velocity and filter"
        }
    }
}

public enum SlideMIDIStrategy: String, CaseIterable, Codable, Sendable {
    case mpePitch = "MPE Pitch"
    case pitchBend = "Pitch Bend"
    case legatoRetrigger = "Legato Retrigger"
    case ccPortamento = "CC Portamento"
}

public enum PressureMIDIMode: String, CaseIterable, Codable, Sendable {
    case mpePressure = "MPE Pressure"
    case polyPressure = "Poly Pressure"
    case channelPressure = "Channel Pressure"
    case cc11 = "CC11 Expression"
}

/// Capability of the MIDI / synth destination. Used for graceful fallback — never silent broken MIDI.
public struct DestinationCapabilityProfile: Codable, Sendable, Equatable, Identifiable {
    public var name: String
    public var supportsMPE: Bool
    public var supportsChannelPressure: Bool
    public var supportsPolyPressure: Bool
    public var bendRangeSemitones: Double
    public var supportsCC74: Bool
    public var supportsKeyswitchArticulations: Bool
    public var supportsPortamento: Bool
    public var supportsLegatoOverlap: Bool
    public var pressureMode: PressureMIDIMode

    public var id: String { name }

    public init(
        name: String,
        supportsMPE: Bool,
        supportsChannelPressure: Bool,
        supportsPolyPressure: Bool,
        bendRangeSemitones: Double,
        supportsCC74: Bool,
        supportsKeyswitchArticulations: Bool,
        supportsPortamento: Bool,
        supportsLegatoOverlap: Bool,
        pressureMode: PressureMIDIMode
    ) {
        self.name = name
        self.supportsMPE = supportsMPE
        self.supportsChannelPressure = supportsChannelPressure
        self.supportsPolyPressure = supportsPolyPressure
        self.bendRangeSemitones = bendRangeSemitones
        self.supportsCC74 = supportsCC74
        self.supportsKeyswitchArticulations = supportsKeyswitchArticulations
        self.supportsPortamento = supportsPortamento
        self.supportsLegatoOverlap = supportsLegatoOverlap
        self.pressureMode = pressureMode
    }

    public static let genericMIDI = DestinationCapabilityProfile(
        name: "Generic MIDI",
        supportsMPE: false,
        supportsChannelPressure: true,
        supportsPolyPressure: false,
        bendRangeSemitones: 2.0,
        supportsCC74: true,
        supportsKeyswitchArticulations: false,
        supportsPortamento: false,
        supportsLegatoOverlap: true,
        pressureMode: .channelPressure
    )

    public static let genericMPE = DestinationCapabilityProfile(
        name: "Generic MPE",
        supportsMPE: true,
        supportsChannelPressure: true,
        supportsPolyPressure: true,
        bendRangeSemitones: 48.0,
        supportsCC74: true,
        supportsKeyswitchArticulations: false,
        supportsPortamento: true,
        supportsLegatoOverlap: true,
        pressureMode: .mpePressure
    )

    public static let internalSynth = DestinationCapabilityProfile(
        name: "Internal Synth",
        supportsMPE: true,
        supportsChannelPressure: true,
        supportsPolyPressure: true,
        bendRangeSemitones: 48.0,
        supportsCC74: true,
        supportsKeyswitchArticulations: false,
        supportsPortamento: true,
        supportsLegatoOverlap: true,
        pressureMode: .mpePressure
    )

    public static let allProfiles: [DestinationCapabilityProfile] = [
        .internalSynth, .genericMPE, .genericMIDI
    ]

    /// Resolved pressure mode given what the destination actually supports.
    public func resolvedPressureMode(preferred: PressureMIDIMode) -> (mode: PressureMIDIMode, fallback: String?) {
        switch preferred {
        case .mpePressure:
            if supportsMPE { return (.mpePressure, nil) }
            if supportsPolyPressure { return (.polyPressure, "MPE unavailable → Poly Pressure") }
            if supportsChannelPressure { return (.channelPressure, "MPE unavailable → Channel Pressure") }
            return (.cc11, "MPE unavailable → CC11")
        case .polyPressure:
            if supportsPolyPressure { return (.polyPressure, nil) }
            if supportsMPE { return (.mpePressure, "Poly Pressure unavailable → MPE Pressure") }
            if supportsChannelPressure { return (.channelPressure, "Poly Pressure unavailable → Channel Pressure") }
            return (.cc11, "Poly Pressure unavailable → CC11")
        case .channelPressure:
            if supportsChannelPressure { return (.channelPressure, nil) }
            if supportsMPE { return (.mpePressure, "Channel Pressure unavailable → MPE Pressure") }
            return (.cc11, "Channel Pressure unavailable → CC11")
        case .cc11:
            return (.cc11, nil)
        }
    }

    public func resolvedSlideStrategy(preferred: SlideMIDIStrategy) -> (strategy: SlideMIDIStrategy, fallback: String?) {
        switch preferred {
        case .mpePitch:
            if supportsMPE { return (.mpePitch, nil) }
            return (.pitchBend, "MPE unavailable → channel pitch bend")
        case .pitchBend:
            return (.pitchBend, nil)
        case .legatoRetrigger:
            return (.legatoRetrigger, nil)
        case .ccPortamento:
            if supportsPortamento { return (.ccPortamento, nil) }
            if supportsMPE { return (.mpePitch, "Portamento CC unavailable → MPE pitch") }
            return (.legatoRetrigger, "Portamento CC unavailable → legato retrigger")
        }
    }

    public func resolvedArticulationStrategy(preferred: ArticulationMIDIStrategy) -> (strategy: ArticulationMIDIStrategy, fallback: String?) {
        switch preferred {
        case .mpeTimbre:
            if supportsMPE || supportsCC74 { return (.mpeTimbre, nil) }
            return (.velocityTimbre, "Timbre CC unavailable → velocity/filter approximation")
        case .midiNote:
            return (.midiNote, nil)
        case .keyswitch:
            if supportsKeyswitchArticulations { return (.keyswitch, nil) }
            if supportsCC74 { return (.mpeTimbre, "Keyswitch unavailable → timbre") }
            return (.velocityTimbre, "Keyswitch unavailable → velocity/filter approximation")
        case .midiCC:
            return (.midiCC, nil)
        case .velocityTimbre:
            return (.velocityTimbre, nil)
        }
    }

    /// True when per-note pitch bend is safe (MPE or a single sounding voice).
    public func canBendIndependently(activeVoiceCount: Int) -> Bool {
        supportsMPE || activeVoiceCount <= 1
    }
}
