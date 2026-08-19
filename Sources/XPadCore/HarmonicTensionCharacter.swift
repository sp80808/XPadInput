import Foundation

/// Named harmonic character for PLAY badges, compass nodes, and VoiceOver.
///
/// Colour is a *secondary* encoding. Callers must also surface `label` and
/// `symbolName` so character remains legible without hue.
public enum HarmonicTensionCharacter: String, Sendable, Equatable, CaseIterable {
    case stable = "Stable"
    case natural = "Natural"
    case colourful = "Colourful"
    case adventurous = "Adventurous"
    case outside = "Outside"

    public init(tension: Double) {
        switch tension {
        case ..<0.15: self = .stable
        case ..<0.30: self = .natural
        case ..<0.50: self = .colourful
        case ..<0.70: self = .adventurous
        default: self = .outside
        }
    }

    public var label: String { rawValue }

    /// SF Symbol used so character is readable without colour.
    public var symbolName: String {
        switch self {
        case .stable: return "checkmark.circle.fill"
        case .natural: return "leaf.fill"
        case .colourful: return "sparkles"
        case .adventurous: return "bolt.fill"
        case .outside: return "exclamationmark.triangle.fill"
        }
    }

    /// Relative outline weight (1...3) as a non-colour cue.
    public var ringWeight: Int {
        switch self {
        case .stable, .natural: return 1
        case .colourful, .adventurous: return 2
        case .outside: return 3
        }
    }
}
