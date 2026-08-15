import Foundation

/// Represents a musical interval in semitones.
public struct Interval: Hashable, Codable, Sendable, Comparable {
    public let semitones: Int

    public init(semitones: Int) {
        self.semitones = semitones
    }

    public static let unison = Interval(semitones: 0)
    public static let minorSecond = Interval(semitones: 1)
    public static let majorSecond = Interval(semitones: 2)
    public static let minorThird = Interval(semitones: 3)
    public static let majorThird = Interval(semitones: 4)
    public static let perfectFourth = Interval(semitones: 5)
    public static let tritone = Interval(semitones: 6)
    public static let perfectFifth = Interval(semitones: 7)
    public static let minorSixth = Interval(semitones: 8)
    public static let majorSixth = Interval(semitones: 9)
    public static let minorSeventh = Interval(semitones: 10)
    public static let majorSeventh = Interval(semitones: 11)
    public static let octave = Interval(semitones: 12)
    public static let minorNinth = Interval(semitones: 13)
    public static let majorNinth = Interval(semitones: 14)
    public static let perfectEleventh = Interval(semitones: 17)
    public static let augmentedEleventh = Interval(semitones: 18)
    public static let majorThirteenth = Interval(semitones: 21)

    public var shortName: String {
        switch semitones {
        case 0: return "P1"
        case 1: return "m2"
        case 2: return "M2"
        case 3: return "m3"
        case 4: return "M3"
        case 5: return "P4"
        case 6: return "TT"
        case 7: return "P5"
        case 8: return "m6"
        case 9: return "M6"
        case 10: return "m7"
        case 11: return "M7"
        case 12: return "P8"
        case 13: return "m9"
        case 14: return "M9"
        case 17: return "P11"
        case 18: return "♯11"
        case 21: return "M13"
        default: return "\(semitones)st"
        }
    }

    public static func < (lhs: Interval, rhs: Interval) -> Bool {
        lhs.semitones < rhs.semitones
    }
}
