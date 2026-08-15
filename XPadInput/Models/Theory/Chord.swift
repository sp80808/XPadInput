import Foundation

/// Chord quality determines the interval structure.
enum ChordQuality: String, CaseIterable, Codable, Sendable {
    case major = "maj"
    case minor = "min"
    case diminished = "dim"
    case augmented = "aug"
    case sus2 = "sus2"
    case sus4 = "sus4"
    case dominant7 = "7"
    case major7 = "maj7"
    case minor7 = "m7"
    case diminished7 = "dim7"
    case halfDiminished7 = "m7♭5"
    case augmented7 = "aug7"
    case minorMajor7 = "mMaj7"
    case add9 = "add9"
    case major9 = "maj9"
    case minor9 = "m9"
    case dominant9 = "9"
    case sixth = "6"
    case minorSixth = "m6"
    case dominant11 = "11"
    case dominant13 = "13"
    
    /// Intervals (in semitones) that define this chord quality
    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        case .dominant7: return [0, 4, 7, 10]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .diminished7: return [0, 3, 6, 9]
        case .halfDiminished7: return [0, 3, 6, 10]
        case .augmented7: return [0, 4, 8, 10]
        case .minorMajor7: return [0, 3, 7, 11]
        case .add9: return [0, 4, 7, 14]
        case .major9: return [0, 4, 7, 11, 14]
        case .minor9: return [0, 3, 7, 10, 14]
        case .dominant9: return [0, 4, 7, 10, 14]
        case .sixth: return [0, 4, 7, 9]
        case .minorSixth: return [0, 3, 7, 9]
        case .dominant11: return [0, 4, 7, 10, 14, 17]
        case .dominant13: return [0, 4, 7, 10, 14, 21]
        }
    }
    
    /// Display symbol for the chord quality
    var symbol: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "°"
        case .augmented: return "+"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .dominant7: return "7"
        case .major7: return "maj7"
        case .minor7: return "m7"
        case .diminished7: return "°7"
        case .halfDiminished7: return "ø7"
        case .augmented7: return "+7"
        case .minorMajor7: return "m(maj7)"
        case .add9: return "add9"
        case .major9: return "maj9"
        case .minor9: return "m9"
        case .dominant9: return "9"
        case .sixth: return "6"
        case .minorSixth: return "m6"
        case .dominant11: return "11"
        case .dominant13: return "13"
        }
    }
    
    /// Whether this is a basic triad
    var isTriad: Bool {
        switch self {
        case .major, .minor, .diminished, .augmented, .sus2, .sus4:
            return true
        default:
            return false
        }
    }
}

/// Represents a chord as root + quality.
struct Chord: Hashable, Codable, Sendable, Identifiable {
    let root: PitchClass
    let quality: ChordQuality
    var inversion: Int = 0  // 0 = root position
    
    var id: String { "\(root.displayName)\(quality.symbol)_inv\(inversion)" }
    
    /// Display name (e.g. "Cm7")
    var displayName: String {
        "\(root.displayName)\(quality.symbol)"
    }
    
    /// Roman numeral in a given key/scale
    func romanNumeral(in key: PitchClass, scale: Scale) -> String? {
        guard let deg = scale.degree(of: root, root: key) else { return nil }
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
        guard deg >= 1 && deg <= numerals.count else { return nil }
        var numeral = numerals[deg - 1]
        
        switch quality {
        case .minor, .minor7, .minor9, .minorSixth, .minorMajor7:
            numeral = numeral.lowercased()
        case .diminished, .diminished7, .halfDiminished7:
            numeral = numeral.lowercased()
        default:
            break
        }
        
        // Add quality markers
        switch quality {
        case .diminished: numeral += "°"
        case .augmented: numeral += "+"
        case .dominant7: numeral += "7"
        case .major7: numeral += "maj7"
        case .minor7: numeral += "7"
        case .halfDiminished7: numeral += "ø7"
        case .diminished7: numeral += "°7"
        default: break
        }
        
        return numeral
    }
    
    /// Pitch classes in this chord
    var pitchClasses: [PitchClass] {
        quality.intervals.map { root.transposed(by: $0 % 12) }
    }
    
    /// Generate concrete voiced notes for this chord
    func voiced(baseOctave: Int = 3) -> [Note] {
        var notes: [Note] = []
        let intervals = quality.intervals
        
        for (i, interval) in intervals.enumerated() {
            let pc = root.transposed(by: interval % 12)
            let octaveOffset = interval / 12
            var noteOctave = baseOctave + octaveOffset
            
            // Apply inversion: move first N notes up an octave
            if i < inversion {
                noteOctave += 1
            }
            
            notes.append(Note(pitchClass: pc, octave: noteOctave))
        }
        
        return notes.sorted()
    }
    
    /// Voice-leading distance to another chord (sum of minimum semitone movements)
    func voiceLeadingDistance(to other: Chord) -> Int {
        let myNotes = voiced()
        let otherNotes = other.voiced()
        
        let maxCount = max(myNotes.count, otherNotes.count)
        var totalDistance = 0
        
        for i in 0..<maxCount {
            let myNote = myNotes[min(i, myNotes.count - 1)]
            let otherNote = otherNotes[min(i, otherNotes.count - 1)]
            totalDistance += abs(myNote.semitones(to: otherNote))
        }
        
        return totalDistance
    }
    
    /// Common tones with another chord
    func commonTones(with other: Chord) -> [PitchClass] {
        PitchClass.commonTones(pitchClasses, other.pitchClasses)
    }
    
    /// Harmonic tension score (0.0 = very stable, 1.0 = very tense)
    func tension(in key: PitchClass, scale: Scale) -> Double {
        let scalePCs = Set(scale.pitchClasses(root: key))
        let chordPCs = Set(pitchClasses)
        
        // Chromaticism penalty
        let nonScaleTones = chordPCs.subtracting(scalePCs).count
        let chromaticTension = Double(nonScaleTones) / Double(chordPCs.count) * 0.5
        
        // Interval tension
        let intervalTension: Double
        if let deg = scale.degree(of: root, root: key) {
            switch deg {
            case 1: intervalTension = 0.0   // Tonic - most stable
            case 5: intervalTension = 0.3   // Dominant
            case 4: intervalTension = 0.2   // Subdominant
            case 6: intervalTension = 0.15  // vi
            case 2: intervalTension = 0.25  // ii
            case 3: intervalTension = 0.2   // iii
            case 7: intervalTension = 0.6   // vii° - very tense
            default: intervalTension = 0.4
            }
        } else {
            intervalTension = 0.7 // Non-diatonic root
        }
        
        // Extension tension
        let extensionTension = quality.isTriad ? 0.0 : 0.1
        
        return min(1.0, chromaticTension + intervalTension + extensionTension)
    }
    
    /// Generate diatonic chords for a scale
    static func diatonicChords(root: PitchClass, scale: Scale) -> [Chord] {
        let pcs = scale.pitchClasses(root: root)
        
        return pcs.enumerated().map { (index, chordRoot) in
            // Determine quality based on intervals from this degree
            let third = pcs[(index + 2) % pcs.count]
            let fifth = pcs[(index + 4) % pcs.count]
            
            let thirdInterval = chordRoot.interval(to: third)
            let fifthInterval = chordRoot.interval(to: fifth)
            
            let quality: ChordQuality
            if thirdInterval == 4 && fifthInterval == 7 {
                quality = .major
            } else if thirdInterval == 3 && fifthInterval == 7 {
                quality = .minor
            } else if thirdInterval == 3 && fifthInterval == 6 {
                quality = .diminished
            } else if thirdInterval == 4 && fifthInterval == 8 {
                quality = .augmented
            } else if thirdInterval == 4 {
                quality = .major
            } else if thirdInterval == 3 {
                quality = .minor
            } else {
                quality = .major
            }
            
            return Chord(root: chordRoot, quality: quality)
        }
    }
}
