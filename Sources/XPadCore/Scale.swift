import Foundation

/// Supported musical scale and mode types.
public enum ScaleType: String, CaseIterable, Identifiable, Codable, Sendable {
    case major = "Major (Ionian)"
    case naturalMinor = "Natural Minor (Aeolian)"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case majorPentatonic = "Major Pentatonic"
    case minorPentatonic = "Minor Pentatonic"
    case blues = "Blues"
    case wholeTone = "Whole Tone"
    case diminished = "Diminished (HW)"

    public var id: String { rawValue }

    public var intervals: [Interval] {
        switch self {
        case .major:
            return [0, 2, 4, 5, 7, 9, 11].map { Interval(semitones: $0) }
        case .naturalMinor:
            return [0, 2, 3, 5, 7, 8, 10].map { Interval(semitones: $0) }
        case .dorian:
            return [0, 2, 3, 5, 7, 9, 10].map { Interval(semitones: $0) }
        case .phrygian:
            return [0, 1, 3, 5, 7, 8, 10].map { Interval(semitones: $0) }
        case .lydian:
            return [0, 2, 4, 6, 7, 9, 11].map { Interval(semitones: $0) }
        case .mixolydian:
            return [0, 2, 4, 5, 7, 9, 10].map { Interval(semitones: $0) }
        case .locrian:
            return [0, 1, 3, 5, 6, 8, 10].map { Interval(semitones: $0) }
        case .harmonicMinor:
            return [0, 2, 3, 5, 7, 8, 11].map { Interval(semitones: $0) }
        case .melodicMinor:
            return [0, 2, 3, 5, 7, 9, 11].map { Interval(semitones: $0) }
        case .majorPentatonic:
            return [0, 2, 4, 7, 9].map { Interval(semitones: $0) }
        case .minorPentatonic:
            return [0, 3, 5, 7, 10].map { Interval(semitones: $0) }
        case .blues:
            return [0, 3, 5, 6, 7, 10].map { Interval(semitones: $0) }
        case .wholeTone:
            return [0, 2, 4, 6, 8, 10].map { Interval(semitones: $0) }
        case .diminished:
            return [0, 1, 3, 4, 6, 7, 9, 10].map { Interval(semitones: $0) }
        }
    }
}

/// Represents a specific musical scale with a root pitch class and type.
public struct Scale: Hashable, Codable, Sendable, Identifiable {
    public let root: PitchClass
    public let type: ScaleType

    public var id: String { "\(root.standardName)_\(type.rawValue)" }

    public init(root: PitchClass, type: ScaleType = .major) {
        self.root = root
        self.type = type
    }

    public var pitchClasses: [PitchClass] {
        type.intervals.map { root.transposed(by: $0.semitones) }
    }

    public func contains(_ pitchClass: PitchClass) -> Bool {
        pitchClasses.contains(pitchClass)
    }

    public func contains(_ note: Note) -> Bool {
        contains(note.pitchClass)
    }

    public var name: String {
        "\(root.standardName) \(type.rawValue)"
    }

    /// Returns the closest scale note to a given pitch class, quantizing outside notes.
    public func snapToScale(_ pitch: PitchClass) -> PitchClass {
        if contains(pitch) { return pitch }
        let sorted = pitchClasses.sorted {
            let d1 = min((pitch.rawValue - $0.rawValue + 12) % 12, ($0.rawValue - pitch.rawValue + 12) % 12)
            let d2 = min((pitch.rawValue - $1.rawValue + 12) % 12, ($1.rawValue - pitch.rawValue + 12) % 12)
            return d1 < d2
        }
        return sorted.first ?? root
    }

    public static let cMajor = Scale(root: .c, type: .major)
    public static let aMinor = Scale(root: .a, type: .naturalMinor)
}
