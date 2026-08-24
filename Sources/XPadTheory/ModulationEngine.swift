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
    public let sourceRoot: PitchClass
    public let sourceScale: Scale
    public let targetRoot: PitchClass
    public let targetScale: Scale
    public let type: ModulationType
    public let intermediateChords: [Chord]
    public let explanation: String

    public init(
        id: UUID = UUID(),
        sourceRoot: PitchClass,
        sourceScale: Scale,
        targetRoot: PitchClass,
        targetScale: Scale,
        type: ModulationType,
        intermediateChords: [Chord],
        explanation: String
    ) {
        self.id = id
        self.sourceRoot = sourceRoot
        self.sourceScale = sourceScale
        self.targetRoot = targetRoot
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
        pathways(from: source.root, sourceScale: source, to: target.root, targetScale: target)
    }

    /// Finds smooth modulation pathways from source scale to target scale.
    public func pathways(
        from sourceRoot: PitchClass,
        sourceScale: Scale,
        to targetRoot: PitchClass,
        targetScale: Scale
    ) -> [ModulationPath] {
        var paths: [ModulationPath] = []

        // 1. Dominant Cycle (ii - V of target key)
        let targetDominant = targetRoot.transposed(by: 7)
        let targetSupertonic = targetRoot.transposed(by: 2)

        let isMinor = targetScale.isMinor
        let iiVPath = ModulationPath(
            sourceRoot: sourceRoot,
            sourceScale: sourceScale,
            targetRoot: targetRoot,
            targetScale: targetScale,
            type: .dominantCycle,
            intermediateChords: [
                Chord(root: targetSupertonic, quality: .minor7),
                Chord(root: targetDominant, quality: .dominant7),
                Chord(root: targetRoot, quality: isMinor ? .minor7 : .major7)
            ],
            explanation: "Classic ii–V–I approach into new key center \(targetRoot.displayName)"
        )
        paths.append(iiVPath)

        // 2. Pivot Chord: Find chords that exist in both source and target scales
        let sourcePcs = Set(sourceScale.pitchClasses(root: sourceRoot))
        let targetPcs = Set(targetScale.pitchClasses(root: targetRoot))
        let common = sourcePcs.intersection(targetPcs)

        if let pivotRoot = common.first {
            let pivotChord = Chord(root: pivotRoot, quality: .minor)
            let pivotPath = ModulationPath(
                sourceRoot: sourceRoot,
                sourceScale: sourceScale,
                targetRoot: targetRoot,
                targetScale: targetScale,
                type: .pivotChord,
                intermediateChords: [
                    pivotChord,
                    Chord(root: targetDominant, quality: .dominant7),
                    Chord(root: targetRoot, quality: isMinor ? .minor : .major)
                ],
                explanation: "\(pivotChord.displayName) serves as pivot chord shared across both keys"
            )
            paths.append(pivotPath)
        }

        // 3. Chromatic Mediant Jump
        let semitones = sourceRoot.interval(to: targetRoot)
        if semitones == 3 || semitones == 4 || semitones == 8 || semitones == 9 {
            let directMediant = ModulationPath(
                sourceRoot: sourceRoot,
                sourceScale: sourceScale,
                targetRoot: targetRoot,
                targetScale: targetScale,
                type: .chromaticMediant,
                intermediateChords: [
                    Chord(root: targetRoot, quality: .major)
                ],
                explanation: "Direct chromatic mediant leap (\(semitones) semitones) for dramatic film-score shift"
            )
            paths.append(directMediant)
        }

        // 4. Tritone Bridge
        let tritoneDominant = targetRoot.transposed(by: 1)
        let tritonePath = ModulationPath(
            sourceRoot: sourceRoot,
            sourceScale: sourceScale,
            targetRoot: targetRoot,
            targetScale: targetScale,
            type: .tritoneBridge,
            intermediateChords: [
                Chord(root: tritoneDominant, quality: .dominant7),
                Chord(root: targetRoot, quality: .major)
            ],
            explanation: "Tritone sub \(tritoneDominant.displayName)7 slides down a half-step into \(targetRoot.displayName)"
        )
        paths.append(tritonePath)

        return paths
    }
}
