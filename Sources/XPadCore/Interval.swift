import Foundation

/// Musical intervals measured in semitones.
public enum Interval: Int, CaseIterable, Codable, Hashable, Sendable {
    case unison = 0
    case minorSecond = 1
    case majorSecond = 2
    case minorThird = 3
    case majorThird = 4
    case perfectFourth = 5
    case tritone = 6
    case perfectFifth = 7
    case minorSixth = 8
    case majorSixth = 9
    case minorSeventh = 10
    case majorSeventh = 11
    
    public var name: String {
        switch self {
        case .unison: return "P1"
        case .minorSecond: return "m2"
        case .majorSecond: return "M2"
        case .minorThird: return "m3"
        case .majorThird: return "M3"
        case .perfectFourth: return "P4"
        case .tritone: return "TT"
        case .perfectFifth: return "P5"
        case .minorSixth: return "m6"
        case .majorSixth: return "M6"
        case .minorSeventh: return "m7"
        case .majorSeventh: return "M7"
        }
    }
    
    public var longName: String {
        switch self {
        case .unison: return "Unison"
        case .minorSecond: return "Minor 2nd"
        case .majorSecond: return "Major 2nd"
        case .minorThird: return "Minor 3rd"
        case .majorThird: return "Major 3rd"
        case .perfectFourth: return "Perfect 4th"
        case .tritone: return "Tritone"
        case .perfectFifth: return "Perfect 5th"
        case .minorSixth: return "Minor 6th"
        case .majorSixth: return "Major 6th"
        case .minorSeventh: return "Minor 7th"
        case .majorSeventh: return "Major 7th"
        }
    }
    
    /// Consonance rating (higher = more consonant)
    public var consonance: Double {
        switch self {
        case .unison: return 1.0
        case .perfectFifth: return 0.95
        case .perfectFourth: return 0.9
        case .majorThird: return 0.8
        case .minorThird: return 0.75
        case .majorSixth: return 0.7
        case .minorSixth: return 0.6
        case .majorSecond: return 0.4
        case .minorSeventh: return 0.35
        case .majorSeventh: return 0.3
        case .minorSecond: return 0.2
        case .tritone: return 0.15
        }
    }
}
