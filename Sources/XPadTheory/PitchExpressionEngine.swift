import Foundation
import XPadCore

/// Harmonic context used to rank discrete landmarks without constraining the
/// continuous pitch path between them.
public struct PitchTargetContext: Sendable, Equatable {
    public let sourceNote: Note
    public let key: PitchClass
    public let scale: Scale
    public let chord: Chord?
    public let bendRangeSemitones: Double
    public let allowsDownwardBend: Bool
    public let assistMode: PitchAssistMode
    public let chromaticOverride: Bool

    public init(
        sourceNote: Note,
        key: PitchClass? = nil,
        scale: Scale,
        chord: Chord? = nil,
        bendRangeSemitones: Double,
        allowsDownwardBend: Bool = true,
        assistMode: PitchAssistMode = .light,
        chromaticOverride: Bool = false
    ) {
        self.sourceNote = sourceNote
        self.key = key ?? scale.root
        self.scale = scale
        self.chord = chord
        self.bendRangeSemitones = bendRangeSemitones.isFinite
            ? max(0.0, bendRangeSemitones)
            : 0.0
        self.allowsDownwardBend = allowsDownwardBend
        self.assistMode = assistMode
        self.chromaticOverride = chromaticOverride
    }

    public init(
        sourceNote: Note,
        key: PitchClass? = nil,
        scale: Scale,
        chord: Chord? = nil,
        profile: InstrumentProfile,
        assistMode: PitchAssistMode? = nil,
        chromaticOverride: Bool = false
    ) {
        self.init(
            sourceNote: sourceNote,
            key: key,
            scale: scale,
            chord: chord,
            bendRangeSemitones: profile.preferredPitchBendRange,
            allowsDownwardBend: profile.allowDownwardBend,
            assistMode: assistMode ?? profile.defaultPitchAssist,
            chromaticOverride: chromaticOverride
        )
    }

    fileprivate var musicalContext: MusicalContext {
        MusicalContext(
            key: key,
            scale: scale,
            chord: chord,
            currentNote: sourceNote,
            chromaticMode: chromaticOverride,
            pitchAssist: assistMode,
            registerOctave: sourceNote.octave
        )
    }
}

/// Stateless result for downstream MIDI translation or restrained target feedback.
public struct ContextualPitchExpression: Sendable, Equatable {
    public let rawOffsetSemitones: Double
    public let assistedOffsetSemitones: Double
    public let direction: MelodicDirection
    public let target: PitchTarget?
    public let targetProximity: Double

    public init(
        rawOffsetSemitones: Double,
        assistedOffsetSemitones: Double,
        direction: MelodicDirection,
        target: PitchTarget? = nil,
        targetProximity: Double = 0.0
    ) {
        self.rawOffsetSemitones = rawOffsetSemitones.isFinite ? rawOffsetSemitones : 0.0
        self.assistedOffsetSemitones = assistedOffsetSemitones.isFinite ? assistedOffsetSemitones : 0.0
        self.direction = direction
        self.target = target
        self.targetProximity = targetProximity.isFinite
            ? min(1.0, max(0.0, targetProximity))
            : 0.0
    }

    public var pitchOffsetSemitones: Double { assistedOffsetSemitones }
    public var isActive: Bool { abs(assistedOffsetSemitones) > 0.000_001 }

    public static let centered = ContextualPitchExpression(
        rawOffsetSemitones: 0.0,
        assistedOffsetSemitones: 0.0,
        direction: .stationary
    )
}

/// Maps normalized pitch input with high precision near zero and optional soft
/// attraction toward deterministic targets ranked by chord, scale, then chromatic fit.
public struct ContextualPitchExpressionEngine: Sendable {
    private let targeter = ContextualPitchTargeter()

    public init() {}

    public func rankedTargets(
        in context: PitchTargetContext,
        direction: MelodicDirection
    ) -> [PitchTarget] {
        guard direction != .stationary, context.bendRangeSemitones > 0.0 else { return [] }
        if direction == .descending && !context.allowsDownwardBend { return [] }

        return targeter.bendTargets(
            from: context.sourceNote,
            rangeSemitones: context.bendRangeSemitones,
            context: context.musicalContext,
            allowDownward: context.allowsDownwardBend
        )
        .filter { target in
            guard abs(target.semitones) <= context.bendRangeSemitones + 0.000_001 else {
                return false
            }
            switch direction {
            case .ascending: return target.semitones > 0.0
            case .descending: return target.semitones < 0.0
            case .stationary: return false
            }
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if abs(lhs.semitones) != abs(rhs.semitones) {
                return abs(lhs.semitones) < abs(rhs.semitones)
            }
            return lhs.semitones < rhs.semitones
        }
    }

    public func evaluate(
        normalizedInput: Double,
        in context: PitchTargetContext,
        responseExponent: Double = 1.5
    ) -> ContextualPitchExpression {
        guard context.bendRangeSemitones > 0.0 else { return .centered }

        let finiteInput = normalizedInput.isFinite ? normalizedInput : 0.0
        let clampedInput = min(1.0, max(-1.0, finiteInput))
        guard abs(clampedInput) > 0.000_001 else { return .centered }
        if clampedInput < 0.0 && !context.allowsDownwardBend { return .centered }

        let direction: MelodicDirection = clampedInput > 0.0 ? .ascending : .descending
        let exponent = responseExponent.isFinite ? max(0.1, responseExponent) : 1.5
        let curvedMagnitude = pow(abs(clampedInput), exponent)
        let rawOffset = (clampedInput < 0.0 ? -curvedMagnitude : curvedMagnitude)
            * context.bendRangeSemitones

        guard context.assistMode != .off else {
            return ContextualPitchExpression(
                rawOffsetSemitones: rawOffset,
                assistedOffsetSemitones: rawOffset,
                direction: direction
            )
        }

        let settings = assistSettings(for: context.assistMode)
        let targets = rankedTargets(in: context, direction: direction)
        guard let target = nearestTarget(
            to: rawOffset,
            targets: targets,
            captureRadius: settings.captureRadius
        ) else {
            return ContextualPitchExpression(
                rawOffsetSemitones: rawOffset,
                assistedOffsetSemitones: rawOffset,
                direction: direction
            )
        }

        let distance = abs(target.semitones - rawOffset)
        let proximity = max(0.0, 1.0 - distance / settings.captureRadius)
        let eased = proximity * proximity * (3.0 - 2.0 * proximity)
        let assisted = rawOffset + (target.semitones - rawOffset) * settings.strength * eased
        let clamped = min(
            context.bendRangeSemitones,
            max(-context.bendRangeSemitones, assisted)
        )

        return ContextualPitchExpression(
            rawOffsetSemitones: rawOffset,
            assistedOffsetSemitones: clamped,
            direction: direction,
            target: target,
            targetProximity: proximity
        )
    }

    private func nearestTarget(
        to offset: Double,
        targets: [PitchTarget],
        captureRadius: Double
    ) -> PitchTarget? {
        targets
            .filter { abs($0.semitones - offset) <= captureRadius }
            .min { lhs, rhs in
                let lhsDistance = abs(lhs.semitones - offset)
                let rhsDistance = abs(rhs.semitones - offset)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                return lhs.score > rhs.score
            }
    }

    private func assistSettings(for mode: PitchAssistMode) -> (captureRadius: Double, strength: Double) {
        switch mode {
        case .off: return (0.0, 0.0)
        case .light: return (0.35, mode.attractionStrength)
        case .strong: return (0.65, mode.attractionStrength)
        }
    }
}
