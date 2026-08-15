import Foundation
import XPadCore

public struct ChordBlock: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var chord: Chord
    public var durationBeats: Double
    public var romanNumeral: String
    public var humanizedVelocity: UInt8

    public init(
        id: UUID = UUID(),
        chord: Chord,
        durationBeats: Double = 4.0,
        romanNumeral: String = "",
        humanizedVelocity: UInt8 = 95
    ) {
        self.id = id
        self.chord = chord
        self.durationBeats = durationBeats
        self.romanNumeral = romanNumeral
        self.humanizedVelocity = humanizedVelocity
    }
}

public struct Progression: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var root: PitchClass
    public var scale: Scale
    public var blocks: [ChordBlock]

    public init(
        id: UUID = UUID(),
        name: String = "Untitled Progression",
        root: PitchClass = .c,
        scale: Scale = .major,
        blocks: [ChordBlock] = []
    ) {
        self.id = id
        self.name = name
        self.root = root
        self.scale = scale
        self.blocks = blocks
    }

    public var totalBeats: Double {
        blocks.reduce(0.0) { $0 + $1.durationBeats }
    }

    /// Mutates the progression while retaining a configurable amount of harmonic identity.
    public func mutated(
        complexity: Double = 0.5,
        preserveRoots: Bool = false
    ) -> Progression {
        var newBlocks: [ChordBlock] = []

        for block in blocks {
            var newChord = block.chord

            if preserveRoots {
                let extOptions: [ChordQuality] = [.major7, .major9, .sus2, .sus4, .add9, .dominant7]
                if let pick = extOptions.randomElement() {
                    newChord = Chord(root: newChord.root, quality: pick)
                }
            } else {
                if Double.random(in: 0...1) < complexity {
                    let shift = [2, 3, 4, 5, 7, 8, 9].randomElement() ?? 7
                    let newRoot = newChord.root.transposed(by: shift)
                    let newQuality: ChordQuality = [ChordQuality.major7, .minor7, .dominant9, .major9].randomElement() ?? .major7
                    newChord = Chord(root: newRoot, quality: newQuality)
                }
            }

            newBlocks.append(ChordBlock(
                chord: newChord,
                durationBeats: block.durationBeats,
                romanNumeral: block.romanNumeral,
                humanizedVelocity: UInt8.random(in: 85...110)
            ))
        }

        return Progression(
            name: "\(name) (Mutated)",
            root: root,
            scale: scale,
            blocks: newBlocks
        )
    }

    /// Factory template progressions across modern genres
    public static func factoryPresets(for scale: Scale) -> [Progression] {
        factoryPresets(root: scale.root, scale: scale)
    }

    /// Factory template progressions across modern genres
    public static func factoryPresets(root: PitchClass, scale: Scale) -> [Progression] {
        let r = root
        let isMinor = scale.id.contains("minor")

        if isMinor {
            return [
                Progression(
                    name: "Neo Soul Groove (i - iv - VII - III)",
                    root: root,
                    scale: scale,
                    blocks: [
                        ChordBlock(chord: Chord(root: r, quality: .minor9), durationBeats: 4.0, romanNumeral: "i9"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 5), quality: .minor7), durationBeats: 4.0, romanNumeral: "iv7"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 10), quality: .dominant9), durationBeats: 4.0, romanNumeral: "VII9"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 3), quality: .major9), durationBeats: 4.0, romanNumeral: "IIImaj9")
                    ]
                ),
                Progression(
                    name: "Dark Minor Cinematic (i - ♭VI - ♭III - ♭VII)",
                    root: root,
                    scale: scale,
                    blocks: [
                        ChordBlock(chord: Chord(root: r, quality: .minor), durationBeats: 4.0, romanNumeral: "i"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 8), quality: .major7), durationBeats: 4.0, romanNumeral: "♭VImaj7"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 3), quality: .major), durationBeats: 4.0, romanNumeral: "♭III"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 10), quality: .major), durationBeats: 4.0, romanNumeral: "♭VII")
                    ]
                )
            ]
        } else {
            return [
                Progression(
                    name: "Pop Anthem (I - V - vi - IV)",
                    root: root,
                    scale: scale,
                    blocks: [
                        ChordBlock(chord: Chord(root: r, quality: .major), durationBeats: 4.0, romanNumeral: "I"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 7), quality: .major), durationBeats: 4.0, romanNumeral: "V"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 9), quality: .minor), durationBeats: 4.0, romanNumeral: "vi"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 5), quality: .major), durationBeats: 4.0, romanNumeral: "IV")
                    ]
                ),
                Progression(
                    name: "House & UK Garage (ii - V - I - vi)",
                    root: root,
                    scale: scale,
                    blocks: [
                        ChordBlock(chord: Chord(root: r.transposed(by: 2), quality: .minor7), durationBeats: 4.0, romanNumeral: "ii7"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 7), quality: .dominant9), durationBeats: 4.0, romanNumeral: "V9"),
                        ChordBlock(chord: Chord(root: r, quality: .major7), durationBeats: 4.0, romanNumeral: "Imaj7"),
                        ChordBlock(chord: Chord(root: r.transposed(by: 9), quality: .minor7), durationBeats: 4.0, romanNumeral: "vi7")
                    ]
                )
            ]
        }
    }
}
