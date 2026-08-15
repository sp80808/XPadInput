import Foundation
import XPadCore

public enum ModulationType: String, CaseIterable, Identifiable, Codable, Sendable {
    case pivotChord = "Pivot Chord (Diatonic Shared)"
    case dominantCycle = "Secondary Dominant (V7 / ii-V-I)"
    case commonTone = "Common Tone Modulation"
    case chromaticMediant = "Chromatic Mediant"
    case tritoneBridge = "Tritone Bridge"
    case neoRiemannian = "Neo-Riemannian (P/L/R)"

    public var id: String { rawValue }
}

public struct ModulationPath: Identifiable, Codable, Sendable {
    public let id: UUID
    public let sourceScale: Scale
    public let targetScale: Scale
    public let type: ModulationType
    public let intermediateChords: [Chord]
    public let explanation: String

    public init(
        id: UUID = UUID(),
        sourceScale: Scale,
        targetScale: Scale,
        type: ModulationType,
        intermediateChords: [Chord],
        explanation: String
    ) {
        self.id = id
        self.sourceScale = sourceScale
        self.targetScale = targetScale
        self.type = type
        self.intermediateChords = intermediateChords
        self.explanation = explanation
    }
}

public struct ModulationEngine: Sendable {
    public init() {}

    /// Finds smooth modulation pathways from source scale to target scale.
    public func pathways(from source: Scale, to target: Scale) -> [ModulationPath] {
        var paths: [ModulationPath] = []

        // 1. Dominant Cycle (ii - V of target key)
        let targetTonic = target.root
        let targetDominant = targetTonic.transposed(by: 7)
        let targetSupertonic = targetTonic.transposed(by: 2)

        let iiVPath = ModulationPath(
            sourceScale: source,
            targetScale: target,
            type: .dominantCycle,
            intermediateChords: [
                Chord(root: targetSupertonic, quality: .minor7),
                Chord(root: targetDominant, quality: .dominant7),
                Chord(root: targetTonic, quality: target.type == .major ? .major7 : .minor7)
            ],
            explanation: "Classic ii–V–I approach into new key center \(target.root.standardName)"
        )
        paths.append(iiVPath)

        // 2. Pivot Chord: Find chords that exist in both source and target scales
        let sourcePcs = Set(source.pitchClasses)
        let targetPcs = Set(target.pitchClasses)
        let common = sourcePcs.intersection(targetPcs)

        if let pivotRoot = common.first {
            let pivotChord = Chord(root: pivotRoot, quality: .minor)
            let pivotPath = ModulationPath(
                sourceScale: source,
                targetScale: target,
                type: .pivotChord,
                intermediateChords: [
                    pivotChord,
                    Chord(root: targetDominant, quality: .dominant7),
                    Chord(root: targetTonic, quality: target.type == .major ? .major : .minor)
                ],
                explanation: "\(pivotChord.symbol) serves as pivot chord shared across both keys"
            )
            paths.append(pivotPath)
        }

        // 3. Chromatic Mediant Jump
        let semitones = source.root.semitones(to: target.root)
        if semitones == 3 || semitones == 4 || semitones == 8 || semitones == 9 {
            let directMediant = ModulationPath(
                sourceScale: source,
                targetScale: target,
                type: .chromaticMediant,
                intermediateChords: [
                    Chord(root: target.root, quality: .major)
                ],
                explanation: "Direct chromatic mediant leap (\(semitones) semitones) for dramatic film-score shift"
            )
            paths.append(directMediant)
        }

        // 4. Tritone Bridge
        let tritoneDominant = targetTonic.transposed(by: 1)
        let tritonePath = ModulationPath(
            sourceScale: source,
            targetScale: target,
            type: .tritoneBridge,
            intermediateChords: [
                Chord(root: tritoneDominant, quality: .dominant7),
                Chord(root: targetTonic, quality: .major)
            ],
            explanation: "Tritone sub \(tritoneDominant.standardName)7 slides down a half-step into \(targetTonic.standardName)"
        )
        paths.append(tritonePath)

        return paths
    }
}
