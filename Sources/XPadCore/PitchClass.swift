import Foundation

/// Represents the 12 chromatic pitch classes in 12-TET.
public enum PitchClass: Int, CaseIterable, Identifiable, Codable, Sendable, Comparable {
    case c = 0
    case cSharp = 1
    case d = 2
    case dSharp = 3
    case e = 4
    case f = 5
    case fSharp = 6
    case g = 7
    case gSharp = 8
    case a = 9
    case aSharp = 10
    case b = 11

    public var id: Int { rawValue }

    public var sharpName: String {
        switch self {
        case .c: return "C"
        case .cSharp: return "C♯"
        case .d: return "D"
        case .dSharp: return "D♯"
        case .e: return "E"
        case .f: return "F"
        case .fSharp: return "F♯"
        case .g: return "G"
        case .gSharp: return "G♯"
        case .a: return "A"
        case .aSharp: return "A♯"
        case .b: return "B"
        }
    }

    public var flatName: String {
        switch self {
        case .c: return "C"
        case .cSharp: return "D♭"
        case .d: return "D"
        case .dSharp: return "E♭"
        case .e: return "E"
        case .f: return "F"
        case .fSharp: return "G♭"
        case .g: return "G"
        case .gSharp: return "A♭"
        case .a: return "A"
        case .aSharp: return "B♭"
        case .b: return "B"
        }
    }

    public var standardName: String {
        switch self {
        case .cSharp, .dSharp, .gSharp, .aSharp:
            return flatName // Prefer flats for common keys or context
        default:
            return sharpName
        }
    }

    /// Transposes the pitch class by a given semitone interval.
    public func transposed(by semitones: Int) -> PitchClass {
        let normalized = ((rawValue + semitones) % 12 + 12) % 12
        return PitchClass(rawValue: normalized)!
    }

    /// Semitone distance to another pitch class moving upward.
    public func semitones(to target: PitchClass) -> Int {
        return (target.rawValue - self.rawValue + 12) % 12
    }

    /// Circle of fifths index (0 = C, 1 = G, 2 = D, ..., 11 = F).
    public var circleOfFifthsIndex: Int {
        return (rawValue * 7) % 12
    }

    public static func < (lhs: PitchClass, rhs: PitchClass) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
