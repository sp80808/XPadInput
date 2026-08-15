import Foundation

/// Represents one of the 12 pitch classes in equal temperament.
/// Uses integer notation where C = 0, C♯/D♭ = 1, ... B = 11.
public enum PitchClass: Int, CaseIterable, Codable, Hashable, Comparable, Sendable, Identifiable {
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

    public static func < (lhs: PitchClass, rhs: PitchClass) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Sharp name
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

    /// Flat name
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

    /// Display name using common convention (flats for certain keys)
    public var displayName: String {
        switch self {
        case .cSharp, .dSharp, .gSharp, .aSharp:
            return flatName
        default:
            return sharpName
        }
    }

    public var standardName: String {
        displayName
    }

    /// Circle of fifths position (0 = C, 1 = G, 2 = D, ... 11 = F)
    public var circleOfFifthsIndex: Int {
        (rawValue * 7) % 12
    }

    /// Transpose by a number of semitones (can be negative)
    public func transposed(by semitones: Int) -> PitchClass {
        let newRaw = ((rawValue + semitones) % 12 + 12) % 12
        return PitchClass(rawValue: newRaw)!
    }

    /// Interval in semitones to another pitch class (always 0...11)
    public func semitones(to target: PitchClass) -> Int {
        (target.rawValue - rawValue + 12) % 12
    }

    /// Interval in semitones upward to target pitch class
    public func interval(to target: PitchClass) -> Int {
        semitones(to: target)
    }

    /// Common pitch classes between two sets
    public static func commonTones(_ a: [PitchClass], _ b: [PitchClass]) -> [PitchClass] {
        Array(Set(a).intersection(Set(b))).sorted()
    }
}
