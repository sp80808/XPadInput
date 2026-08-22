import Foundation

/// A musician-facing performance technique, independent of its MIDI representation.
public enum MusicalTechnique: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case normal = "Normal"
    case accent = "Accent"
    case legato = "Legato"
    case hammerOn = "Hammer-On"
    case pullOff = "Pull-Off"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case portamento = "Portamento"
    case bend = "Bend"
    case preBend = "Pre-Bend"
    case releaseBend = "Release Bend"
    case vibrato = "Vibrato"
    case palmMute = "Palm Mute"
    case ghostNote = "Ghost Note"
    case harmonic = "Harmonic"
    case pinchHarmonic = "Pinch Harmonic"
    case aftertouch = "Aftertouch"
    case polyPressure = "Poly Pressure"
    case staccato = "Staccato"
    case sustain = "Sustain"
    case tremolo = "Tremolo"
    case trill = "Trill"
    case graceNote = "Grace Note"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    /// Compact language suitable for transient PLAY feedback.
    public var playLabel: String? {
        self == .normal ? nil : rawValue
    }

    public var isLegatoFamily: Bool {
        switch self {
        case .legato, .hammerOn, .pullOff, .slideUp, .slideDown, .portamento, .graceNote, .trill:
            return true
        default:
            return false
        }
    }

    public var isSlideFamily: Bool {
        self == .slideUp || self == .slideDown || self == .portamento
    }

    public var isHarmonicFamily: Bool {
        self == .harmonic || self == .pinchHarmonic
    }
}

public enum RealismMode: String, CaseIterable, Codable, Sendable {
    case relaxed = "Relaxed"
    case natural = "Natural"
    case strict = "Strict"
}

public enum TechniqueHaptic: String, Codable, Sendable, Equatable {
    case bendDetent
    case hammerOn
    case pullOff
    case slideArrival
    case pinchHarmonic
    case palmMuteThreshold
    case buttonConfirm
    case strumPluck
    case chordChange
    case soloGuideTone
    case drumHit
    case octaveShift

    public var intensity: Float {
        switch self {
        case .bendDetent: return 0.5
        case .hammerOn: return 0.4
        case .pullOff: return 0.35
        case .slideArrival: return 0.6
        case .pinchHarmonic: return 0.8
        case .palmMuteThreshold: return 0.45
        case .buttonConfirm: return 0.3
        case .strumPluck: return 0.65
        case .chordChange: return 0.4
        case .soloGuideTone: return 0.55
        case .drumHit: return 0.75
        case .octaveShift: return 0.5
        }
    }

    public var sharpness: Float {
        switch self {
        case .bendDetent: return 0.6
        case .hammerOn: return 0.8
        case .pullOff: return 0.7
        case .slideArrival: return 0.5
        case .pinchHarmonic: return 0.95
        case .palmMuteThreshold: return 0.4
        case .buttonConfirm: return 0.5
        case .strumPluck: return 0.7
        case .chordChange: return 0.45
        case .soloGuideTone: return 0.85
        case .drumHit: return 0.6
        case .octaveShift: return 0.75
        }
    }
}
