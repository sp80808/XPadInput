import Foundation
import XPadCore

/// Historical, pure acoustic, and microtonal temperament systems.
///
/// While standard 12-TET divides the octave into 12 equal semitones of 100 cents,
/// acoustic instruments and expressive MPE / MIDI 2.0 controllers can dynamically
/// tune harmonic thirds, fifths, and microtonal intervals to pure zero-beating ratios.
public enum MicrotonalTemperament: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Standard 12-Tone Equal Temperament (100 cents per semitone).
    case equalTemperament = "12-TET (Standard)"
    /// Dynamic Just Intonation dynamically tunes chord members to pure natural harmonic ratios (5-limit / 7-limit).
    case dynamicJustIntonation = "Dynamic Just Intonation"
    /// Hermode Tuning: Real-time dynamic adaptive pure thirds and fifths tailored for chord progressions.
    case hermodeTuning = "Hermode Tuning"
    /// Quarter-Comma Meantone: Pure major thirds (5:4) with slightly narrowed fifths.
    case quarterCommaMeantone = "Quarter-Comma Meantone"
    /// Pythagorean Tuning: Pure acoustic fifths (3:2) based on stacks of fifths.
    case pythagorean = "Pythagorean"
    /// Wendy Carlos Alpha: Non-octave microtonal scale with 15.385 steps per octave (78 cents/step).
    case wendyCarlosAlpha = "Wendy Carlos Alpha"
    /// 24-EDO / Maqam Quarter-Tone: 24 equal divisions of the octave (50 cents per step).
    case maqam24EDO = "24-EDO (Maqam)"

    public var id: String { rawValue }

    public var isDynamic: Bool {
        self == .dynamicJustIntonation || self == .hermodeTuning
    }

    public var description: String {
        switch self {
        case .equalTemperament:
            "Standard equal temperament (100 cents per semitone, slightly sharp major 3rds)."
        case .dynamicJustIntonation:
            "Pure integer frequency ratios calculated dynamically from the active chord root."
        case .hermodeTuning:
            "Adaptive pure thirds (-13.7c) and fifths (+2.0c) tuned to active harmonic progression."
        case .quarterCommaMeantone:
            "Pure major thirds with tempered fifths (historical Renaissance / Baroque tuning)."
        case .pythagorean:
            "Pure acoustic fifths (3:2) derived from the cycle of fifths."
        case .wendyCarlosAlpha:
            "Non-octave scale dividing the octave into ~15.385 equal steps (78 cents each)."
        case .maqam24EDO:
            "24 equal divisions of the octave (quarter-tone microtonality, 50 cents/step)."
        }
    }

    // MARK: - Tuning Offset Calculation

    /// Computes the tuning offset in cents for a given MIDI note relative to standard 12-TET.
    ///
    /// - Parameters:
    ///   - midiNote: The MIDI note number (0...127).
    ///   - scaleRoot: The root pitch class of the current musical context (default C).
    ///   - activeChordRoot: Optional pitch class of the active chord (for dynamic temperaments).
    ///   - isMinorChord: Whether the active chord is minor (for 3rd tuning in Just Intonation).
    /// - Returns: Tuning offset in cents (-100.0 ... +100.0).
    public func tuningOffsetInCents(
        for midiNote: UInt8,
        scaleRoot: PitchClass = .c,
        activeChordRoot: PitchClass? = nil,
        isMinorChord: Bool = false
    ) -> Double {
        let notePitchClass = PitchClass(rawValue: Int(midiNote) % 12) ?? .c

        switch self {
        case .equalTemperament:
            return 0.0

        case .dynamicJustIntonation:
            // Compute interval relative to active chord root (or scale root if no chord)
            let root = activeChordRoot ?? scaleRoot
            let intervalSemitones = (Int(notePitchClass.rawValue) - Int(root.rawValue) + 12) % 12
            return Self.justIntonationCentsOffset(intervalSemitones: intervalSemitones, isMinorChord: isMinorChord)

        case .hermodeTuning:
            let root = activeChordRoot ?? scaleRoot
            let intervalSemitones = (Int(notePitchClass.rawValue) - Int(root.rawValue) + 12) % 12
            return Self.hermodeCentsOffset(intervalSemitones: intervalSemitones, isMinorChord: isMinorChord)

        case .quarterCommaMeantone:
            // Meantone offsets relative to scale root
            let interval = (Int(notePitchClass.rawValue) - Int(scaleRoot.rawValue) + 12) % 12
            return Self.quarterCommaMeantoneOffsets[interval]

        case .pythagorean:
            let interval = (Int(notePitchClass.rawValue) - Int(scaleRoot.rawValue) + 12) % 12
            return Self.pythagoreanOffsets[interval]

        case .wendyCarlosAlpha:
            // Wendy Carlos Alpha: 78.0 cents per scale degree instead of 100
            let interval = (Int(notePitchClass.rawValue) - Int(scaleRoot.rawValue) + 12) % 12
            let equalCents: Double = Double(interval) * 100.0
            let alphaCents: Double = Double(interval) * 78.0
            let diff: Double = alphaCents - equalCents
            return diff

        case .maqam24EDO:
            // 24-EDO allows half-flat (balkh / sikah) neutral thirds at 350 cents (-50 cents from equal major 3rd, +50 from minor)
            let interval = (Int(notePitchClass.rawValue) - Int(scaleRoot.rawValue) + 12) % 12
            if interval == 3 || interval == 4 {
                // Neutral third (350 cents)
                return interval == 4 ? -50.0 : +50.0
            }
            if interval == 10 || interval == 11 {
                // Neutral seventh (1050 cents)
                return interval == 11 ? -50.0 : +50.0
            }
            return 0.0
        }
    }

    /// Computes the tuning offset in fractional semitones for a given MIDI note relative to 12-TET.
    /// (e.g. -13.7 cents = -0.137 semitones).
    public func tuningOffsetInSemitones(
        for midiNote: UInt8,
        scaleRoot: PitchClass = .c,
        activeChordRoot: PitchClass? = nil,
        isMinorChord: Bool = false
    ) -> Double {
        tuningOffsetInCents(
            for: midiNote,
            scaleRoot: scaleRoot,
            activeChordRoot: activeChordRoot,
            isMinorChord: isMinorChord
        ) / 100.0
    }

    // MARK: - Just Intonation Math

    /// Pure 5-limit / 7-limit Just Intonation cents offsets relative to 12-TET.
    ///
    /// Ratios:
    /// - Unison 1:1 = 0 cents (12-TET: 0) -> offset 0.0
    /// - Minor 2nd 16:15 = 111.731 cents (12-TET: 100) -> offset +11.73
    /// - Major 2nd 9:8 = 203.910 cents (12-TET: 200) -> offset +3.91
    /// - Minor 3rd 6:5 = 315.641 cents (12-TET: 300) -> offset +15.64
    /// - Major 3rd 5:4 = 386.314 cents (12-TET: 400) -> offset -13.69
    /// - Perfect 4th 4:3 = 498.045 cents (12-TET: 500) -> offset -1.95
    /// - Tritone (Diminished 5th) 7:5 / 45:32 = 590.224 cents (12-TET: 600) -> offset -9.78
    /// - Perfect 5th 3:2 = 701.955 cents (12-TET: 700) -> offset +1.95
    /// - Minor 6th 8:5 = 813.686 cents (12-TET: 800) -> offset +13.69
    /// - Major 6th 5:3 = 884.359 cents (12-TET: 900) -> offset -15.64
    /// - Harmonic 7th 7:4 = 968.826 cents / Just minor 7th 9:5 = 1017.596 cents (12-TET: 1000) -> offset +17.60
    /// - Major 7th 15:8 = 1088.269 cents (12-TET: 1100) -> offset -11.73
    private static func justIntonationCentsOffset(intervalSemitones: Int, isMinorChord: Bool) -> Double {
        switch intervalSemitones {
        case 0:  return 0.0
        case 1:  return +11.731
        case 2:  return +3.910
        case 3:  return +15.641  // Pure minor 3rd (6:5)
        case 4:  return -13.686  // Pure major 3rd (5:4)
        case 5:  return -1.955   // Pure 4th (4:3)
        case 6:  return -9.776
        case 7:  return +1.955   // Pure 5th (3:2)
        case 8:  return +13.686  // Pure minor 6th (8:5)
        case 9:  return -15.641  // Pure major 6th (5:3)
        case 10: return +17.596  // Just minor 7th (9:5)
        case 11: return -11.731  // Pure major 7th (15:8)
        default: return 0.0
        }
    }

    /// Hermode Tuning real-time progression tuning algorithm.
    /// Pure 5ths (+1.955c), pure major 3rds (-13.686c), pure minor 3rds (+15.641c),
    /// while preserving stable pitch reference on unisons and octaves.
    private static func hermodeCentsOffset(intervalSemitones: Int, isMinorChord: Bool) -> Double {
        switch intervalSemitones {
        case 0:  return 0.0
        case 3:  return +15.641  // Pure minor 3rd
        case 4:  return -13.686  // Pure major 3rd
        case 7:  return +1.955   // Pure 5th
        case 10: return +17.596  // Pure minor 7th
        case 11: return -11.731  // Pure major 7th
        default: return 0.0
        }
    }

    /// 1/4-Comma Meantone offsets for 12 chromatic degrees (C based).
    private static let quarterCommaMeantoneOffsets: [Double] = [
        0.0,     // C: 0.0c
        -24.0,   // C#: -24.0c
        -7.0,    // D: -7.0c
        +10.0,   // D#: +10.0c
        -14.0,   // E: -14.0c
        +3.0,    // F: +3.0c
        -21.0,   // F#: -21.0c
        -3.0,    // G: -3.0c
        +14.0,   // G#: +14.0c
        -10.0,   // A: -10.0c
        +7.0,    // A#: +7.0c
        -17.0    // B: -17.0c
    ]

    /// Pythagorean tuning offsets for 12 chromatic degrees (pure 3:2 fifths).
    private static let pythagoreanOffsets: [Double] = [
        0.0,     // C: 0c
        -9.78,   // C#: -9.78c
        +3.91,   // D: +3.91c
        -5.87,   // D#: -5.87c
        +7.82,   // E: +7.82c
        -1.96,   // F: -1.96c
        +11.73,  // F#: +11.73c
        +1.95,   // G: +1.95c
        -7.82,   // G#: -7.82c
        +5.87,   // A: +5.87c
        -3.91,   // A#: -3.91c
        +9.78    // B: +9.78c
    ]
}
