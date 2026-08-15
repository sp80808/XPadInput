import Foundation

public enum PitchAssistMode: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case off = "Off"
    case light = "Light"
    case strong = "Strong"

    public var id: String { rawValue }

    /// Maximum share of the remaining distance pulled toward a nearby target.
    public var attractionStrength: Double {
        switch self {
        case .off: return 0.0
        case .light: return 0.28
        case .strong: return 0.58
        }
    }
}

public enum MelodicDirection: String, CaseIterable, Codable, Hashable, Sendable {
    case descending
    case stationary
    case ascending
}
