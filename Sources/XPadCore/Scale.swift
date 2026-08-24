import Foundation

public enum ScaleType: String, CaseIterable, Identifiable, Codable, Sendable {
    case major = "Major (Ionian)"
    case naturalMinor = "Natural Minor (Aeolian)"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case pentatonicMajor = "Major Pentatonic"
    case pentatonicMinor = "Minor Pentatonic"
    case blues = "Blues"
    case chromatic = "Chromatic"

    public var id: String { rawValue }

    public var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor: return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .chromatic: return Array(0...11)
        }
    }

    public var shortName: String {
        switch self {
        case .major: return "Major"
        case .naturalMinor: return "Minor"
        case .harmonicMinor: return "Harm. Minor"
        case .melodicMinor: return "Mel. Minor"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .locrian: return "Locrian"
        case .pentatonicMajor: return "Maj Pent"
        case .pentatonicMinor: return "Min Pent"
        case .blues: return "Blues"
        case .chromatic: return "Chromatic"
        }
    }

    public var isMinor: Bool {
        switch self {
        case .naturalMinor, .harmonicMinor, .melodicMinor, .dorian, .phrygian, .locrian, .pentatonicMinor, .blues:
            return true
        case .major, .lydian, .mixolydian, .pentatonicMajor, .chromatic:
            return false
        }
    }
}

/// Represents a musical scale/mode with its root and interval pattern.
public struct Scale: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let root: PitchClass
    public let type: ScaleType
    public let intervals: [Int]

    public init(root: PitchClass = .c, type: ScaleType = .major) {
        self.root = root
        self.type = type
        self.id = "\(root.standardName)_\(type.rawValue)"
        self.name = "\(root.standardName) \(type.rawValue)"
        self.intervals = type.intervals
    }

    public init(id: String, name: String, intervals: [Int], root: PitchClass = .c, type: ScaleType = .major) {
        self.id = id
        self.name = name
        self.intervals = intervals
        self.root = root
        self.type = type
    }

    public var pitchClasses: [PitchClass] {
        intervals.map { root.transposed(by: $0) }
    }

    public var displayName: String {
        type.rawValue
    }

    public var shortDisplayName: String {
        type.shortName
    }

    public var isMinor: Bool {
        type.isMinor || intervals.contains(3)
    }

    public func pitchClasses(root: PitchClass) -> [PitchClass] {
        intervals.map { root.transposed(by: $0) }
    }

    public func notes(fromOctave: Int = 3, toOctave: Int = 5) -> [Note] {
        var result: [Note] = []
        for octave in fromOctave...toOctave {
            for interval in intervals {
                let pc = root.transposed(by: interval)
                let note = Note(pitchClass: pc, octave: octave)
                if note.midiNumber <= 127 {
                    result.append(note)
                }
            }
        }
        return result.sorted()
    }

    public func contains(_ pitchClass: PitchClass) -> Bool {
        pitchClasses.contains(pitchClass)
    }

    public func contains(_ note: Note) -> Bool {
        pitchClasses.contains(note.pitchClass)
    }

    public func degree(of pitchClass: PitchClass) -> Int? {
        let pcs = pitchClasses
        guard let idx = pcs.firstIndex(of: pitchClass) else { return nil }
        return idx + 1
    }

    public func degree(of pitchClass: PitchClass, root: PitchClass) -> Int? {
        let pcs = pitchClasses(root: root)
        guard let idx = pcs.firstIndex(of: pitchClass) else { return nil }
        return idx + 1
    }

    public var noteCount: Int { intervals.count }

    // MARK: - Common Scales
    public static let cMajor = Scale(root: .c, type: .major)
    public static let aMinor = Scale(root: .a, type: .naturalMinor)
    public static let major = Scale(root: .c, type: .major)
    public static let naturalMinor = Scale(root: .c, type: .naturalMinor)
    public static let harmonicMinor = Scale(root: .c, type: .harmonicMinor)
    public static let melodicMinor = Scale(root: .c, type: .melodicMinor)
    public static let dorian = Scale(root: .c, type: .dorian)
    public static let phrygian = Scale(root: .c, type: .phrygian)
    public static let lydian = Scale(root: .c, type: .lydian)
    public static let mixolydian = Scale(root: .c, type: .mixolydian)
    public static let locrian = Scale(root: .c, type: .locrian)
    public static let pentatonicMajor = Scale(root: .c, type: .pentatonicMajor)
    public static let pentatonicMinor = Scale(root: .c, type: .pentatonicMinor)
    public static let blues = Scale(root: .c, type: .blues)
    public static let chromatic = Scale(root: .c, type: .chromatic)

    public static let allScales: [Scale] = [
        .major, .naturalMinor, .harmonicMinor, .melodicMinor,
        .dorian, .phrygian, .lydian, .mixolydian, .locrian,
        .pentatonicMajor, .pentatonicMinor, .blues, .chromatic
    ]
}
