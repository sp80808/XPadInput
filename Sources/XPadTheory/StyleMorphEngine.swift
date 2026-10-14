import Foundation
import XPadCore

/// Generates progressions from a `HarmonicStyleDNA` fingerprint, and morphs
/// continuously between two styles.
///
/// The engine is deliberately deterministic: given the same style, key, scale,
/// bar count, and seed it always produces the same progression. That is what
/// makes a generated idea reproducible on stage, exportable to MIDI, and
/// testable — a generative feature that changes every time it is inspected is
/// unusable in a session.
///
/// Musical behaviour comes from three layers, applied in order:
/// 1. **Degree motion** — a style-weighted walk with functional pull, so chords
///    move by fourths, fifths, and steps rather than jumping at random.
/// 2. **Substitutions** — modal interchange, secondary dominants, tritone
///    substitution, and chromatic planing, each gated by its own style rate.
/// 3. **Colour** — extensions and suspensions chosen from the style's richness
///    and suspended-colour axes.
public struct StyleMorphEngine: Sendable {

    public init() {}

    // MARK: - Morphing

    /// Blends two styles.
    ///
    /// - Parameter amount: `0` keeps `start`, `1` lands on `end`, and values in
    ///   between interpolate every axis, so a 50% blend is genuinely halfway
    ///   between the two harmonic dialects.
    public func blend(
        _ start: HarmonicStyleDNA,
        _ end: HarmonicStyleDNA,
        amount: Double
    ) -> HarmonicStyleDNA {
        HarmonicStyleDNA.blend(start, end, amount: amount)
    }

    /// Blends a style toward another by `amount`, for `morph` sliders that
    /// always keep the current style as the origin.
    public func morphing(_ style: HarmonicStyleDNA, toward target: HarmonicStyleDNA, amount: Double) -> HarmonicStyleDNA {
        blend(style, target, amount: amount)
    }

    // MARK: - Generation

    /// Generates a progression in the given style.
    ///
    /// - Parameters:
    ///   - style: Harmonic fingerprint, normalised internally.
    ///   - key: Tonic pitch class.
    ///   - scale: Optional harmony source. When omitted, the style's own
    ///     major/minor lean chooses the mode.
    ///   - bars: Length in 4/4 bars.
    ///   - seed: Reproducibility seed. Same inputs, same progression.
    ///   - startDegree: Optional opening degree index (0 = tonic).
    public func generate(
        style: HarmonicStyleDNA,
        key: PitchClass = .c,
        scale: Scale? = nil,
        bars: Int = 4,
        seed: UInt64 = 0,
        startDegree: Int? = nil,
        chordCount: Int? = nil
    ) -> Progression {
        let dna = style.normalised()
        let resolvedScale = scale ?? Scale(root: key, type: dna.preferredScaleType)
        let palette = Chord.diatonicChords(root: key, scale: resolvedScale)
        let barCount = max(1, bars)

        guard !palette.isEmpty else {
            return Progression(name: dna.name, root: key, scale: resolvedScale)
        }

        let degreeCount = palette.count
        let chordCount = max(2, chordCount ?? Int((dna.chordsPerBar * Double(barCount)).rounded()))
        // Realised harmonic rhythm: fill exactly the requested bars, staying as
        // close to the style's chords-per-bar as the grid allows.
        let beatsPerChord = (Double(barCount) * 4.0) / Double(chordCount)

        var random = DeterministicRandom(seed: seed)
        let degrees = degreeSequence(
            count: chordCount,
            degreeCount: degreeCount,
            dna: dna,
            startDegree: startDegree,
            random: &random
        )

        var blocks: [ChordBlock] = []
        for (index, degree) in degrees.enumerated() {
            let base = palette[degree % degreeCount]
            let nextDegree = index + 1 < degrees.count ? degrees[index + 1] % degreeCount : nil
            let coloured = colour(
                chord: base,
                nextDegree: nextDegree,
                palette: palette,
                dna: dna,
                key: key,
                scale: resolvedScale,
                random: &random
            )
            let velocity = UInt8(
                max(1, min(127, Int(random.nextDouble(in: 88, 112).rounded())))
            )
            blocks.append(
                ChordBlock(
                    chord: coloured.chord,
                    durationBeats: beatsPerChord,
                    romanNumeral: coloured.roman,
                    humanizedVelocity: velocity
                )
            )
        }

        return Progression(
            name: "\(dna.name) \(key.displayName)",
            root: key,
            scale: resolvedScale,
            blocks: blocks
        )
    }

    /// Generates and immediately blends: the escape hatch for "give me something
    /// 40% of the way from what I have to something else".
    public func generate(
        from start: HarmonicStyleDNA,
        toward end: HarmonicStyleDNA,
        amount: Double,
        key: PitchClass = .c,
        scale: Scale? = nil,
        bars: Int = 4,
        seed: UInt64 = 0
    ) -> Progression {
        generate(
            style: blend(start, end, amount: amount),
            key: key,
            scale: scale,
            bars: bars,
            seed: seed
        )
    }

    /// Re-colours an existing progression in a new style.
    ///
    /// Rhythm, block count, and block durations are preserved — only the harmony
    /// changes — which is how a verse the player already likes can be heard
    /// through a different genre without losing its phrasing.
    public func reharmonise(
        _ progression: Progression,
        style: HarmonicStyleDNA,
        seed: UInt64 = 0
    ) -> Progression {
        guard !progression.blocks.isEmpty else { return progression }
        let totalBeats = progression.totalBeats
        let bars = max(1, Int((totalBeats / 4.0).rounded(.up)))

        let generated = generate(
            style: style,
            key: progression.root,
            scale: progression.scale,
            bars: bars,
            seed: seed,
            chordCount: progression.blocks.count
        )
        guard generated.blocks.count == progression.blocks.count else { return progression }

        let blocks = zip(progression.blocks, generated.blocks).map { original, replacement in
            ChordBlock(
                chord: replacement.chord,
                durationBeats: original.durationBeats,
                romanNumeral: replacement.romanNumeral,
                humanizedVelocity: replacement.humanizedVelocity
            )
        }

        return Progression(
            name: "\(progression.name) · \(style.name)",
            root: progression.root,
            scale: progression.scale,
            blocks: blocks
        )
    }

    // MARK: - Layer 1: degree motion

    /// Weighted walk over scale degrees with functional voice-leading pull.
    private func degreeSequence(
        count: Int,
        degreeCount: Int,
        dna: HarmonicStyleDNA,
        startDegree: Int?,
        random: inout DeterministicRandom
    ) -> [Int] {
        var degrees: [Int] = []
        let opening = startDegree.map { ((($0 % degreeCount) + degreeCount) % degreeCount) }

        for slot in 0..<count {
            // An explicit start degree is honoured exactly: "begin on the IV" is a
            // musical instruction, not a suggestion.
            if slot == 0, let opening {
                degrees.append(opening)
                continue
            }

            let previous = degrees.last
            let isFinal = slot == count - 1
            var weights: [Double] = []

            for candidate in 0..<degreeCount {
                let styleWeight = dna.weight(forDegree: candidate) + 0.02
                var motion = transitionWeight(
                    from: previous,
                    to: candidate,
                    degreeCount: degreeCount,
                    cadenceStrength: dna.cadenceStrength
                )
                if isFinal {
                    // Phrases land on the tonic unless the style deliberately avoids it.
                    motion *= candidate == 0 ? (1.2 + dna.cadenceStrength) : 0.6
                }
                weights.append(styleWeight * motion)
            }

            degrees.append(random.pickWeightedIndex(weights: weights) ?? 0)
        }
        return degrees
    }

    /// Functional pull between two degree indices, scale-agnostic.
    private func transitionWeight(
        from previous: Int?,
        to candidate: Int,
        degreeCount: Int,
        cadenceStrength: Double
    ) -> Double {
        guard let previous else { return 1.0 }
        if degreeCount <= 1 { return 1.0 }
        if candidate == previous { return 0.15 } // repeat only as a deliberate vamp

        // Heptatonic motion scaled onto whatever scale is in play.
        let fourthUp = max(1, Int((Double(degreeCount) * 3.0 / 7.0).rounded()))
        let fifthUp = max(1, Int((Double(degreeCount) * 4.0 / 7.0).rounded()))
        let relative = ((candidate - previous) % degreeCount + degreeCount) % degreeCount

        var weight: Double
        if relative == fourthUp {
            weight = 1.70 // strongest functional move: up a fourth / down a fifth
        } else if relative == fifthUp {
            weight = 1.45 // up a fifth
        } else if relative == 1 || relative == degreeCount - 1 {
            weight = 1.30 // stepwise
        } else if relative == 2 || relative == degreeCount - 2 {
            weight = 1.10 // third
        } else {
            weight = 0.75
        }

        // Cadential reinforcement: V → I and ii → V are the two moves that make
        // a phrase sound finished.
        if candidate == 0 && previous == fifthUp {
            weight *= 1.0 + 1.4 * cadenceStrength
        }
        if candidate == fifthUp && previous == 1 {
            weight *= 1.0 + 0.8 * cadenceStrength
        }
        return weight
    }

    // MARK: - Layers 2 & 3: substitutions and colour

    private struct Coloured {
        let chord: Chord
        let roman: String
    }

    private func colour(
        chord: Chord,
        nextDegree: Int?,
        palette: [Chord],
        dna: HarmonicStyleDNA,
        key: PitchClass,
        scale: Scale,
        random: inout DeterministicRandom
    ) -> Coloured {
        var root = chord.root
        var quality = chord.quality
        // Labels that are already complete, such as "V7/V" or "subV7".
        var explicitRoman: String?
        var isSubstituted = false

        // Chromatic planing: same shape, re-rooted by a third.
        if random.chance(dna.mediantShiftRate) {
            let shift = random.chance(0.5) ? 3 : 4
            let direction = random.chance(0.5) ? shift : -shift
            root = root.transposed(by: direction)
            quality = .major
            isSubstituted = true
        }

        // Modal interchange.
        if !isSubstituted, random.chance(dna.borrowing) {
            if let borrowed = random.pick(borrowedChords(key: key, isMinor: scale.type.isMinor)) {
                root = borrowed.root
                quality = borrowed.quality
                isSubstituted = true
            }
        }

        // Secondary dominant targeting the following chord.
        if !isSubstituted,
           let nextDegree,
           nextDegree < palette.count,
           random.chance(dna.secondaryDominantRate) {
            let target = palette[nextDegree]
            root = target.root.transposed(by: 7)
            quality = .dominant7
            explicitRoman = "V7/\(romanBase(for: target.root, quality: target.quality, in: key))"
            isSubstituted = true
        }

        // Tritone substitution of a dominant.
        if random.chance(dna.tritoneSubstitutionRate), isDominantQuality(quality) {
            root = root.transposed(by: 6)
            quality = .dominant7
            explicitRoman = "subV7"
        }

        let coloured = extended(quality, dna: dna, random: &random)
        let roman = explicitRoman
            ?? romanBase(for: root, quality: coloured, in: key) + markerOnlySuffix(for: coloured)

        return Coloured(chord: Chord(root: root, quality: coloured), roman: roman)
    }

    /// Modal-interchange chords relative to the key: I (Picardy), IV (Dorian),
    /// V (harmonic), ♭II (Neapolitan), ♭III, iv, ♭VI, ♭VII.
    private func borrowedChords(key: PitchClass, isMinor: Bool) -> [Chord] {
        if isMinor {
            return [
                Chord(root: key, quality: .major),
                Chord(root: key.transposed(by: 5), quality: .major),
                Chord(root: key.transposed(by: 7), quality: .major),
                Chord(root: key.transposed(by: 1), quality: .major),
                Chord(root: key.transposed(by: 3), quality: .major)
            ]
        }
        return [
            Chord(root: key.transposed(by: 3), quality: .major),
            Chord(root: key.transposed(by: 5), quality: .minor),
            Chord(root: key.transposed(by: 8), quality: .major),
            Chord(root: key.transposed(by: 10), quality: .major),
            Chord(root: key.transposed(by: 1), quality: .major)
        ]
    }

    private static let chromaticRomans = [
        "I", "♭II", "II", "♭III", "III", "IV", "♭V", "V", "♭VI", "VI", "♭VII", "VII"
    ]

    /// Roman numeral base for any root, diatonic or borrowed, with the case the
    /// quality asks for — the table covers all twelve chromatic degrees, so
    /// borrowed chords label themselves ("♭VI", "iv") without special cases.
    private func romanBase(for pitchClass: PitchClass, quality: ChordQuality, in key: PitchClass) -> String {
        let interval = key.interval(to: pitchClass)
        guard interval >= 0, interval < Self.chromaticRomans.count else { return "?" }
        let numeral = Self.chromaticRomans[interval]
        switch quality {
        case .minor, .minor7, .minor9, .minorSixth, .minorMajor7, .diminished, .diminished7, .halfDiminished7:
            return numeral.lowercased()
        default:
            return numeral
        }
    }

    /// Quality marker for a chord that already carries its own roman numeral case.
    private func markerOnlySuffix(for quality: ChordQuality) -> String {
        switch quality {
        case .major, .minor: return ""
        case .diminished: return "°"
        case .augmented: return "+"
        case .major7: return "maj7"
        case .minor7: return "7"
        case .dominant7: return "7"
        case .halfDiminished7: return "ø7"
        case .diminished7: return "°7"
        case .augmented7: return "+7"
        case .minorMajor7: return "(maj7)"
        case .major9: return "maj9"
        case .minor9: return "9"
        case .dominant9: return "9"
        case .dominant11: return "11"
        case .dominant13: return "13"
        case .add9: return "add9"
        case .sixth: return "6"
        case .minorSixth: return "m6"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        }
    }

    private func isDominantQuality(_ quality: ChordQuality) -> Bool {
        switch quality {
        case .dominant7, .dominant9, .dominant11, .dominant13:
            return true
        default:
            return false
        }
    }

    // MARK: - Extension palette

    private func extended(
        _ quality: ChordQuality,
        dna: HarmonicStyleDNA,
        random: inout DeterministicRandom
    ) -> ChordQuality {
        switch quality {
        case .diminished:
            return dna.extensionRichness > 0.5 ? .halfDiminished7 : quality
        case .augmented:
            return dna.extensionRichness > 0.5 ? .augmented7 : quality
        default:
            break
        }

        if random.chance(dna.suspendedColour * 0.55) {
            switch quality {
            case .major, .major7, .major9:
                return .add9
            case .minor, .minor7, .minor9:
                return .minor9
            case .dominant7, .dominant9:
                return .sus4
            default:
                break
            }
        }

        let level = (dna.extensionRichness + random.nextDouble(in: -0.08, 0.08)).normalizedUnit
        if level < 0.30 { return quality }
        if level < 0.55 { return seventh(for: quality) }
        if level < 0.82 { return ninth(for: quality) }
        return richest(for: quality)
    }

    private func seventh(for quality: ChordQuality) -> ChordQuality {
        switch quality {
        case .major: return .major7
        case .minor: return .minor7
        case .diminished: return .halfDiminished7
        case .sus2, .sus4: return .dominant7
        default: return quality
        }
    }

    private func ninth(for quality: ChordQuality) -> ChordQuality {
        switch quality {
        case .major, .major7: return .major9
        case .minor, .minor7: return .minor9
        case .dominant7, .dominant9: return .dominant9
        case .halfDiminished7: return .minor9
        case .sus2, .sus4, .add9: return .add9
        default: return quality
        }
    }

    private func richest(for quality: ChordQuality) -> ChordQuality {
        switch quality {
        case .major, .major7, .major9: return .major9
        case .minor, .minor7, .minor9: return .minor9
        case .dominant7, .dominant9: return .dominant13
        case .halfDiminished7: return .halfDiminished7
        case .sus2, .sus4, .add9: return .add9
        default: return quality
        }
    }
}
