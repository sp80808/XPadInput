import Foundation

public enum ChordQuality: String, CaseIterable, Identifiable, Codable, Sendable {
    case major = ""
    case minor = "m"
    case diminished = "dim"
    case augmented = "aug"
    case dominant7 = "7"
    case major7 = "maj7"
    case minor7 = "m7"
    case minMaj7 = "m(maj7)"
    case halfDiminished = "m7♭5"
    case diminished7 = "dim7"
    case sus2 = "sus2"
    case sus4 = "sus4"
    case add9 = "add9"
    case major9 = "maj9"
    case minor9 = "m9"
    case dominant9 = "9"
    case dominant11 = "11"
    case major13 = "maj13"
    case minor11 = "m11"
    case power5 = "5"

    public var id: String { rawValue }

    public var intervals: [Interval] {
        switch self {
        case .major:
            return [0, 4, 7].map { Interval(semitones: $0) }
        case .minor:
            return [0, 3, 7].map { Interval(semitones: $0) }
        case .diminished:
            return [0, 3, 6].map { Interval(semitones: $0) }
        case .augmented:
            return [0, 4, 8].map { Interval(semitones: $0) }
        case .dominant7:
            return [0, 4, 7, 10].map { Interval(semitones: $0) }
        case .major7:
            return [0, 4, 7, 11].map { Interval(semitones: $0) }
        case .minor7:
            return [0, 3, 7, 10].map { Interval(semitones: $0) }
        case .minMaj7:
            return [0, 3, 7, 11].map { Interval(semitones: $0) }
        case .halfDiminished:
            return [0, 3, 6, 10].map { Interval(semitones: $0) }
        case .diminished7:
            return [0, 3, 6, 9].map { Interval(semitones: $0) }
        case .sus2:
            return [0, 2, 7].map { Interval(semitones: $0) }
        case .sus4:
            return [0, 5, 7].map { Interval(semitones: $0) }
        case .add9:
            return [0, 4, 7, 14].map { Interval(semitones: $0) }
        case .major9:
            return [0, 4, 7, 11, 14].map { Interval(semitones: $0) }
        case .minor9:
            return [0, 3, 7, 10, 14].map { Interval(semitones: $0) }
        case .dominant9:
            return [0, 4, 7, 10, 14].map { Interval(semitones: $0) }
        case .dominant11:
            return [0, 4, 7, 10, 14, 17].map { Interval(semitones: $0) }
        case .minor11:
            return [0, 3, 7, 10, 14, 17].map { Interval(semitones: $0) }
        case .major13:
            return [0, 4, 7, 11, 14, 21].map { Interval(semitones: $0) }
        case .power5:
            return [0, 7].map { Interval(semitones: $0) }
        }
    }
}

public enum Inversion: Int, CaseIterable, Identifiable, Codable, Sendable {
    case root = 0
    case first = 1
    case second = 2
    case third = 3

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .root: return "Root Position"
        case .first: return "1st Inversion"
        case .second: return "2nd Inversion"
        case .third: return "3rd Inversion"
        }
    }
}

public enum VoicingStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case close = "Close"
    case drop2 = "Drop 2"
    case openSpread = "Open Spread"
    case guitarAcoustic = "Guitar Acoustic"
    case shellJazz = "Shell (Jazz)"

    public var id: String { rawValue }
}

/// Represents a chord with root, quality, optional slash bass, inversion, and voicing.
public struct Chord: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let root: PitchClass
    public let quality: ChordQuality
    public let bassNote: PitchClass?
    public var inversion: Inversion
    public var voicingStyle: VoicingStyle
    public var customName: String?

    public init(
        id: UUID = UUID(),
        root: PitchClass,
        quality: ChordQuality = .major,
        bassNote: PitchClass? = nil,
        inversion: Inversion = .root,
        voicingStyle: VoicingStyle = .close,
        customName: String? = nil
    ) {
        self.id = id
        self.root = root
        self.quality = quality
        self.bassNote = bassNote
        self.inversion = inversion
        self.voicingStyle = voicingStyle
        self.customName = customName
    }

    public var symbol: String {
        if let custom = customName { return custom }
        let base = "\(root.standardName)\(quality.rawValue)"
        if let bass = bassNote, bass != root {
            return "\(base)/\(bass.standardName)"
        }
        return base
    }

    public var pitchClasses: [PitchClass] {
        quality.intervals.map { root.transposed(by: $0.semitones) }
    }

    /// Computes voiced concrete MIDI notes starting from a base octave (e.g. octave 3 or 4).
    public func voicedNotes(baseOctave: Int = 3) -> [Note] {
        var baseMidiNotes: [Int] = quality.intervals.map { interval in
            let midi = (baseOctave + 1) * 12 + root.rawValue + interval.semitones
            return midi
        }

        // Apply inversion by shifting lower notes up an octave
        let count = baseMidiNotes.count
        if count > 1 && inversion.rawValue > 0 {
            let shiftCount = min(inversion.rawValue, count - 1)
            for i in 0..<shiftCount {
                baseMidiNotes[i] += 12
            }
            baseMidiNotes.sort()
        }

        // Apply Voicing Styles
        switch voicingStyle {
        case .close:
            break
        case .drop2:
            if baseMidiNotes.count >= 4 {
                // Drop the second highest note down an octave
                let secondHighestIndex = baseMidiNotes.count - 2
                baseMidiNotes[secondHighestIndex] -= 12
                baseMidiNotes.sort()
            }
        case .openSpread:
            if baseMidiNotes.count >= 3 {
                // Drop root down octave and lift soprano up
                baseMidiNotes[0] -= 12
                if let last = baseMidiNotes.last {
                    baseMidiNotes[baseMidiNotes.count - 1] = last + 12
                }
                baseMidiNotes.sort()
            }
        case .guitarAcoustic:
            // Standard 5 or 6 voice guitar-like spread: Root, 5th, Root+12, 3rd+12, 5th+12
            let rMidi = (baseOctave) * 12 + root.rawValue
            let fifth = rMidi + 7
            let rOct = rMidi + 12
            let third = rMidi + (quality.intervals.first(where: { $0.semitones == 3 || $0.semitones == 4 })?.semitones ?? 4) + 12
            let topFifth = fifth + 12
            baseMidiNotes = [rMidi, fifth, rOct, third, topFifth]
        case .shellJazz:
            // Root in bass, 3rd and 7th in middle, omit 5th
            let rMidi = (baseOctave) * 12 + root.rawValue
            var shell: [Int] = [rMidi]
            if let thirdInterval = quality.intervals.first(where: { $0.semitones == 3 || $0.semitones == 4 }) {
                shell.append(rMidi + 12 + thirdInterval.semitones)
            }
            if let seventhInterval = quality.intervals.first(where: { $0.semitones == 10 || $0.semitones == 11 || $0.semitones == 9 }) {
                shell.append(rMidi + 12 + seventhInterval.semitones)
            }
            baseMidiNotes = shell.sorted()
        }

        // Add slash bass note if specified
        if let bass = bassNote, bass != root {
            let bassMidi = (baseOctave) * 12 + bass.rawValue
            if !baseMidiNotes.contains(bassMidi) {
                baseMidiNotes.insert(bassMidi, at: 0)
            }
        }

        return baseMidiNotes.map { Note(midiNumber: UInt8(clamping: max(0, min(127, $0)))) }
    }
}
