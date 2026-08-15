import Foundation
import XPadCore

public enum SuggestionCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case familiar = "Familiar (Pop / Standard)"
    case smooth = "Smooth (Common Tones)"
    case resolution = "Strong Resolution"
    case colourful = "Colourful / Extended"
    case darker = "Darker (Minor / Modal)"
    case brighter = "Brighter (Major / Lydian)"
    case cinematic = "Cinematic / Mediant"
    case outside = "Outside / Adventurous"

    public var id: String { rawValue }
}

public struct ChordSuggestion: Identifiable, Codable, Sendable {
    public var id: String { "\(category.rawValue)_\(chord.displayName)" }
    public let chord: Chord
    public let category: SuggestionCategory
    public let reason: String
    public let score: Double // 0..100
    public let commonToneCount: Int

    public init(
        chord: Chord,
        category: SuggestionCategory,
        reason: String,
        score: Double,
        commonToneCount: Int
    ) {
        self.chord = chord
        self.category = category
        self.reason = reason
        self.score = score
        self.commonToneCount = commonToneCount
    }
}

public struct HarmonicSuggestionEngine: Sendable {
    public init() {}

    /// Generates ranked next chord suggestions given the current chord and the scale.
    public func suggestions(for currentChord: Chord, in scale: Scale) -> [ChordSuggestion] {
        suggestions(for: currentChord, in: scale.root, scale: scale)
    }

    /// Generates ranked next chord suggestions given the current chord, the scale, and voice leading context.
    public func suggestions(for currentChord: Chord, in key: PitchClass, scale: Scale) -> [ChordSuggestion] {
        var results: [ChordSuggestion] = []
        let currentPcs = Set(currentChord.pitchClasses)

        // 1. FAMILIAR: Diatonic standard motions
        let standardNext: [(PitchClass, ChordQuality, String)] = [
            (currentChord.root.transposed(by: 5), .major, "Circle of Fifths motion (Strong root progression)"),
            (currentChord.root.transposed(by: 7), .major, "Dominant movement"),
            (key, (scale.id.contains("minor") ? .minor : .major), "Resolution to Tonic (I)"),
            (key.transposed(by: 5), .major, "Movement to Subdominant (IV)"),
            (key.transposed(by: 9), .minor, "Deceptive resolution to Relative Minor (vi)")
        ]
        for spec in standardNext {
            let chord = Chord(root: spec.0, quality: spec.1)
            let common = currentPcs.intersection(Set(chord.pitchClasses)).count
            results.append(ChordSuggestion(
                chord: chord,
                category: .familiar,
                reason: spec.2,
                score: 85.0 + Double(common * 5),
                commonToneCount: common
            ))
        }

        // 2. SMOOTH: Chords sharing 2+ common tones with minimal voice movement
        for pc in PitchClass.allCases {
            for q in [ChordQuality.major, .minor, .major7, .minor7, .sus4] {
                let candidate = Chord(root: pc, quality: q)
                let common = currentPcs.intersection(Set(candidate.pitchClasses)).count
                if common >= 2 && candidate.displayName != currentChord.displayName {
                    results.append(ChordSuggestion(
                        chord: candidate,
                        category: .smooth,
                        reason: "Shares \(common) notes with \(currentChord.displayName)",
                        score: 75.0 + Double(common * 8),
                        commonToneCount: common
                    ))
                }
            }
        }

        // 3. STRONG RESOLUTION: V7 -> I, subV7 -> I, vii° -> I
        let dominantOfRoot = Chord(root: currentChord.root.transposed(by: 7), quality: .dominant7)
        results.append(ChordSuggestion(
            chord: dominantOfRoot,
            category: .resolution,
            reason: "Dominant 7th preparing resolution back to \(currentChord.root.displayName)",
            score: 95.0,
            commonToneCount: currentPcs.intersection(Set(dominantOfRoot.pitchClasses)).count
        ))

        let tritoneSub = Chord(root: currentChord.root.transposed(by: 1), quality: .dominant7)
        results.append(ChordSuggestion(
            chord: tritoneSub,
            category: .resolution,
            reason: "Tritone substitution (♭II7) resolving by half-step",
            score: 90.0,
            commonToneCount: currentPcs.intersection(Set(tritoneSub.pitchClasses)).count
        ))

        // 4. COLOURFUL: Extended versions of diatonic chords
        for ext in [ChordQuality.major9, .minor9, .dominant9, .sus2, .add9] {
            let candidate = Chord(root: currentChord.root, quality: ext)
            let common = currentPcs.intersection(Set(candidate.pitchClasses)).count
            results.append(ChordSuggestion(
                chord: candidate,
                category: .colourful,
                reason: "Adds lush \(ext.rawValue) color over the same root",
                score: 80.0,
                commonToneCount: common
            ))
        }

        // 5. CINEMATIC: Chromatic Mediants
        let mediants: [(PitchClass, ChordQuality, String)] = [
            (currentChord.root.transposed(by: 3), .major, "Chromatic Mediant (♭III) - Film score wonder"),
            (currentChord.root.transposed(by: 4), .major, "Major Mediant (III) - Emotional lift"),
            (currentChord.root.transposed(by: 8), .major, "Submediant (♭VI) - Heroic cinematic resolution"),
            (currentChord.root.transposed(by: 9), .major, "Major Submediant (VI) - Bright unexpected turn")
        ]
        for med in mediants {
            let chord = Chord(root: med.0, quality: med.1)
            let common = currentPcs.intersection(Set(chord.pitchClasses)).count
            results.append(ChordSuggestion(
                chord: chord,
                category: .cinematic,
                reason: med.2,
                score: 88.0 + Double(common * 4),
                commonToneCount: common
            ))
        }

        // 6. DARKER & BRIGHTER
        let parallelMinorBorrowed = Chord(root: key.transposed(by: 8), quality: .major)
        results.append(ChordSuggestion(
            chord: parallelMinorBorrowed,
            category: .darker,
            reason: "♭VI borrowed from Aeolian (Moody, dramatic)",
            score: 82.0,
            commonToneCount: currentPcs.intersection(Set(parallelMinorBorrowed.pitchClasses)).count
        ))

        let lydianMajor = Chord(root: key.transposed(by: 2), quality: .major)
        results.append(ChordSuggestion(
            chord: lydianMajor,
            category: .brighter,
            reason: "II Major (Lydian brightening chord)",
            score: 78.0,
            commonToneCount: currentPcs.intersection(Set(lydianMajor.pitchClasses)).count
        ))

        // De-duplicate by chord displayName and sort by score descending
        var seen = Set<String>()
        var unique: [ChordSuggestion] = []
        for s in results.sorted(by: { $0.score > $1.score }) {
            if !seen.contains(s.chord.displayName) {
                seen.insert(s.chord.displayName)
                unique.append(s)
            }
        }

        return Array(unique.prefix(20))
    }
}
