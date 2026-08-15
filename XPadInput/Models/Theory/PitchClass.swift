import Foundation

/// Represents one of the 12 pitch classes in equal temperament.
/// Uses integer notation where C = 0, C♯/D♭ = 1, ... B = 11.
enum PitchClass: Int, CaseIterable, Codable, Hashable, Sendable {
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
    
    /// Sharp name
    var sharpName: String {
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
    var flatName: String {
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
    var displayName: String {
        switch self {
        case .cSharp, .dSharp, .gSharp, .aSharp:
            return flatName
        default:
            return sharpName
        }
    }
    
    /// Transpose by a number of semitones
    func transposed(by semitones: Int) -> PitchClass {
        let newValue = ((rawValue + semitones) % 12 + 12) % 12
        return PitchClass(rawValue: newValue)!
    }
    
    /// Interval (in semitones) to another pitch class
    func interval(to other: PitchClass) -> Int {
        return ((other.rawValue - rawValue) % 12 + 12) % 12
    }
    
    /// Common tones between two sets of pitch classes
    static func commonTones(_ set1: [PitchClass], _ set2: [PitchClass]) -> [PitchClass] {
        let s1 = Set(set1)
        return set2.filter { s1.contains($0) }
    }
}
