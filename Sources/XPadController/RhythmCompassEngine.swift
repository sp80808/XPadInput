import Foundation
import XPadCore

public enum RhythmicSubdivision: String, CaseIterable, Identifiable, Codable, Sendable {
    case quarter = "1/4"
    case eighth = "1/8"
    case eighthTriplet = "1/8T"
    case sixteenth = "1/16"
    case sixteenthTriplet = "1/16T"
    case thirtySecond = "1/32"
    case quarterSwing = "1/4 Swing"
    case rollFlam = "Roll / Ratchet"

    public var id: String { rawValue }

    public var ticksPerStep: UInt64 {
        switch self {
        case .quarter: return 960
        case .eighth: return 480
        case .eighthTriplet: return 320
        case .sixteenth: return 240
        case .sixteenthTriplet: return 160
        case .thirtySecond: return 120
        case .quarterSwing: return 960
        case .rollFlam: return 60
        }
    }
}

public struct RhythmCompassEngine: Sendable {
    public init() {}

    /// Evaluates the active rhythmic subdivision and intensity from thumbstick coordinates.
    public func evaluate(stick: StickCoordinates) -> (subdivision: RhythmicSubdivision, intensity: Double, isPlaying: Bool) {
        guard stick.isActive else {
            return (.sixteenth, 0.0, false)
        }

        // Map angle to clockwise compass sectors (North = 0, East = pi/2, South = pi, West = 3pi/2)
        var angle = (.pi / 2.0) - stick.angle
        if angle < 0 { angle += 2.0 * .pi }
        if angle >= 2.0 * .pi { angle -= 2.0 * .pi }

        let sectorIndex = Int((angle + (.pi / 8.0)) / (.pi / 4.0)) % 8
        let subdivision: RhythmicSubdivision

        switch sectorIndex {
        case 0: subdivision = .quarter
        case 1: subdivision = .eighth
        case 2: subdivision = .eighthTriplet
        case 3: subdivision = .sixteenth
        case 4: subdivision = .sixteenthTriplet
        case 5: subdivision = .thirtySecond
        case 6: subdivision = .quarterSwing
        default: subdivision = .rollFlam
        }

        return (subdivision, stick.radius, true)
    }
}
