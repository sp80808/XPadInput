import Foundation

/// Musician-facing feel for the physical surface, independent of `InstrumentProfile`.
public enum ControlSurfaceFeel: String, Codable, Sendable, CaseIterable, Identifiable {
    case natural = "Natural"
    case precision = "Precision"
    case fastArcade = "Fast"
    case reducedTravel = "Reduced Travel"

    public var id: String { rawValue }

    /// Short enough for a four-segment Feel picker without clipping the sheet chrome.
    public var pickerLabel: String {
        switch self {
        case .natural: return "Natural"
        case .precision: return "Precision"
        case .fastArcade: return "Fast"
        case .reducedTravel: return "Reduced"
        }
    }
}

public enum AdaptiveTriggerForcePolicy: String, Codable, Sendable, CaseIterable, Identifiable {
    case off = "Off"
    case reduced = "Reduced"
    case standard = "Standard"

    public var id: String { rawValue }

    public var strengthScale: Float {
        switch self {
        case .off: return 0
        case .reduced: return 0.45
        case .standard: return 1.0
        }
    }
}

public enum GripProfile: String, Codable, Sendable, CaseIterable, Identifiable {
    case standardTwoIndex = "Standard Two-Index"
    case fourFinger = "Four-Finger"
    case oneHanded = "One-Handed / Assistive"

    public var id: String { rawValue }
}

/// Ergonomic/physical layer between hardware calibration and musical interpretation.
public struct ControlSurfaceProfile: Codable, Sendable, Equatable, Identifiable {
    public var feel: ControlSurfaceFeel
    public var mirrored: Bool
    public var motionEnabled: Bool
    public var touchpadEnabled: Bool
    public var triggerForce: AdaptiveTriggerForcePolicy
    public var grip: GripProfile

    public var id: String { "surface.\(feel.rawValue)" }
    public var name: String { feel.rawValue }

    public init(
        feel: ControlSurfaceFeel = .natural,
        mirrored: Bool = false,
        motionEnabled: Bool = true,
        touchpadEnabled: Bool = true,
        triggerForce: AdaptiveTriggerForcePolicy = .reduced,
        grip: GripProfile = .standardTwoIndex
    ) {
        self.feel = feel
        self.mirrored = mirrored
        self.motionEnabled = motionEnabled
        self.touchpadEnabled = touchpadEnabled
        self.triggerForce = triggerForce
        self.grip = grip
    }

    public var harmonyStick: InputProcessingProfile {
        switch feel {
        case .natural: return .expressive
        case .precision: return .precision
        case .fastArcade: return .fast
        case .reducedTravel: return .reducedTravel
        }
    }

    public var strumStick: InputProcessingProfile {
        switch feel {
        case .natural: return .fast
        case .precision: return .precision
        case .fastArcade: return .fast
        case .reducedTravel: return .reducedTravel
        }
    }

    public var bendStick: InputProcessingProfile {
        switch feel {
        case .natural, .precision: return .precision
        case .fastArcade: return .fast
        case .reducedTravel: return .reducedTravel
        }
    }

    public static let allPresets: [ControlSurfaceProfile] = ControlSurfaceFeel.allCases.map {
        ControlSurfaceProfile(feel: $0)
    }
}

extension InputProcessingProfile {
    public static let reducedTravel = InputProcessingProfile(
        id: "reducedTravel",
        name: "Reduced Travel",
        deadzone: .scaledRadial(0.08),
        responseCurve: .exponential(0.45),
        smoothingFactor: 0.88
    )
}
