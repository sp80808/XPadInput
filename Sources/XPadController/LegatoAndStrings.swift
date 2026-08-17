import Foundation
import XPadCore
import XPadTheory

public enum LegatoTransition: String, Codable, Sendable, Equatable {
    case normalRetrigger
    case hammerOn
    case pullOff
    case slide
    case graceNote
    case trill
}

public struct LegatoInterpretation: Sendable, Equatable {
    public var transition: LegatoTransition
    public var technique: MusicalTechnique
    public var source: Note
    public var destination: Note
    public var velocity: UInt8
    public var reason: String
    public var confidence: Double
    public var evidence: [String]

    public init(
        transition: LegatoTransition,
        technique: MusicalTechnique,
        source: Note,
        destination: Note,
        velocity: UInt8,
        reason: String,
        confidence: Double = 1,
        evidence: [String] = []
    ) {
        self.transition = transition
        self.technique = technique
        self.source = source
        self.destination = destination
        self.velocity = velocity
        self.reason = reason
        self.confidence = confidence
        self.evidence = evidence
    }
}

public struct TechniqueInference: Sendable, Equatable {
    public var candidate: MusicalTechnique
    public var committed: MusicalTechnique
    public var confidence: Double
    public var evidence: [String]
    public var accepted: Bool

    public init(
        candidate: MusicalTechnique,
        committed: MusicalTechnique,
        confidence: Double,
        evidence: [String],
        accepted: Bool
    ) {
        self.candidate = candidate
        self.committed = committed
        self.confidence = confidence
        self.evidence = evidence
        self.accepted = accepted
    }

    public static func accept(
        _ technique: MusicalTechnique,
        confidence: Double,
        evidence: [String],
        realism: RealismMode
    ) -> TechniqueInference {
        let accepted = technique == .normal || confidence >= realism.acceptanceThreshold
        return TechniqueInference(
            candidate: technique,
            committed: accepted ? technique : .normal,
            confidence: min(1, max(0, confidence)),
            evidence: evidence,
            accepted: accepted
        )
    }
}

/// Deterministic classification of note-to-note transitions.
public struct LegatoGestureInterpreter: Sendable {
    public init() {}

    public func interpret(
        previous: Note?,
        current: Note,
        overlap: Bool,
        intervalMs: Double,
        hasPickAttack: Bool,
        slideModifier: Bool,
        profile: InstrumentProfile,
        realism: RealismMode,
        sameString: Bool,
        preparedLowerNote: Bool
    ) -> LegatoInterpretation? {
        let result = infer(
            previous: previous,
            current: current,
            overlap: overlap,
            intervalMs: intervalMs,
            hasPickAttack: hasPickAttack,
            slideModifier: slideModifier,
            profile: profile,
            realism: realism,
            sameString: sameString,
            preparedLowerNote: preparedLowerNote
        )
        return result.interpretation
    }

    public func infer(
        previous: Note?,
        current: Note,
        overlap: Bool,
        intervalMs: Double,
        hasPickAttack: Bool,
        slideModifier: Bool,
        profile: InstrumentProfile,
        realism: RealismMode,
        sameString: Bool,
        preparedLowerNote: Bool
    ) -> (interpretation: LegatoInterpretation, inference: TechniqueInference) {
        func pack(
            transition: LegatoTransition,
            technique: MusicalTechnique,
            source: Note,
            dest: Note,
            velocity: UInt8,
            reason: String,
            confidence: Double,
            evidence: [String]
        ) -> (LegatoInterpretation, TechniqueInference) {
            let inference = TechniqueInference.accept(
                technique,
                confidence: confidence,
                evidence: evidence,
                realism: realism
            )
            let committedTechnique = inference.committed
            let committedTransition: LegatoTransition = inference.accepted ? transition : .normalRetrigger
            let committedReason = inference.accepted
                ? reason
                : "Uncertain \(technique.rawValue) (\(String(format: "%.2f", inference.confidence)) < \(realism.rawValue) \(String(format: "%.2f", realism.acceptanceThreshold)))"
            return (
                LegatoInterpretation(
                    transition: committedTransition,
                    technique: committedTechnique,
                    source: source,
                    destination: dest,
                    velocity: inference.accepted ? velocity : 80,
                    reason: committedReason,
                    confidence: inference.confidence,
                    evidence: evidence
                ),
                inference
            )
        }

        guard let previous else {
            return pack(
                transition: .normalRetrigger,
                technique: .normal,
                source: current,
                dest: current,
                velocity: 80,
                reason: "No source note",
                confidence: 1,
                evidence: ["no-source"]
            )
        }

        let interval = previous.semitones(to: current)
        let absInterval = abs(interval)

        if slideModifier && profile.supportsSlides && overlap {
            return pack(
                transition: .slide,
                technique: interval >= 0 ? .slideUp : .slideDown,
                source: previous,
                dest: current,
                velocity: 70,
                reason: "Explicit slide modifier",
                confidence: 1,
                evidence: ["explicit-slide", "overlap"]
            )
        }

        if absInterval == 0 {
            return pack(
                transition: .normalRetrigger,
                technique: .normal,
                source: previous,
                dest: current,
                velocity: 80,
                reason: "Unison retrigger",
                confidence: 1,
                evidence: ["unison"]
            )
        }

        if hasPickAttack && intervalMs < 45 && absInterval <= 3 {
            return pack(
                transition: .graceNote,
                technique: .graceNote,
                source: previous,
                dest: current,
                velocity: 72,
                reason: "Grace ornament before attack",
                confidence: 0.82,
                evidence: ["pick-attack", "fast-gap", "neighbour"]
            )
        }

        if profile.supportsHammerOns && overlap && !hasPickAttack && interval > 0 {
            let withinInterval = absInterval <= profile.hammerOnMaxInterval
            let withinTime = intervalMs <= profile.hammerOnMaxGapMs
            var evidence = ["overlap", "no-pick", "upward"]
            var confidence = 0.22
            if withinInterval {
                confidence += 0.18
                evidence.append("interval-\(absInterval)")
            }
            if withinTime {
                let tightness = max(0, 1 - intervalMs / max(1, profile.hammerOnMaxGapMs))
                confidence += 0.18 + 0.12 * tightness
                evidence.append("gap-\(Int(intervalMs))ms")
            }
            if sameString {
                confidence += 0.22
                evidence.append("same-string")
            } else if absInterval <= 5 {
                confidence += 0.08
                evidence.append("nearby-string")
            }
            switch realism {
            case .relaxed:
                evidence.append("relaxed-string")
            case .natural:
                if !(sameString || absInterval <= 5) {
                    confidence = min(confidence, 0.40)
                    evidence.append("cross-string")
                }
            case .strict:
                if !sameString {
                    confidence = min(confidence, 0.40)
                    evidence.append("strict-requires-same-string")
                }
            }
            if withinInterval && withinTime {
                let hammerVelocity = UInt8(max(40, min(100, Int(110.0 - intervalMs * 0.2))))
                return pack(
                    transition: .hammerOn,
                    technique: .hammerOn,
                    source: previous,
                    dest: current,
                    velocity: hammerVelocity,
                    reason: "Upward legato without pick",
                    confidence: min(1, confidence),
                    evidence: evidence
                )
            }
        }

        if profile.supportsPullOffs && !hasPickAttack && interval < 0 {
            let withinTime = intervalMs <= profile.pullOffMaxGapMs
            var evidence = ["no-pick", "downward"]
            var confidence = 0.20
            if withinTime {
                let tightness = max(0, 1 - intervalMs / max(1, profile.pullOffMaxGapMs))
                confidence += 0.18 + 0.10 * tightness
                evidence.append("gap-\(Int(intervalMs))ms")
            }
            if sameString {
                confidence += 0.22
                evidence.append("same-string")
            } else if absInterval <= 5 {
                confidence += 0.08
                evidence.append("nearby-string")
            }
            if preparedLowerNote {
                confidence += 0.22
                evidence.append("prepared")
            } else if realism == .relaxed {
                confidence += 0.10
                evidence.append("relaxed-unprepared")
            } else {
                confidence = min(confidence, 0.42)
                evidence.append("unprepared")
            }
            switch realism {
            case .relaxed:
                break
            case .natural:
                if !(sameString || absInterval <= 5) {
                    confidence = min(confidence, 0.40)
                    evidence.append("cross-string")
                }
            case .strict:
                if !sameString {
                    confidence = min(confidence, 0.40)
                    evidence.append("strict-requires-same-string")
                }
            }
            if withinTime && (realism == .relaxed || preparedLowerNote || confidence >= realism.acceptanceThreshold) {
                return pack(
                    transition: .pullOff,
                    technique: .pullOff,
                    source: previous,
                    dest: current,
                    velocity: 58,
                    reason: "Downward release to prepared note",
                    confidence: min(1, confidence),
                    evidence: evidence
                )
            }
        }

        if overlap && intervalMs < 90 && absInterval <= 2 && profile.supportsLegato {
            return pack(
                transition: .trill,
                technique: .trill,
                source: previous,
                dest: current,
                velocity: 64,
                reason: "Rapid neighbour alternation",
                confidence: 0.62,
                evidence: ["overlap", "neighbour", "rapid"]
            )
        }

        return pack(
            transition: .normalRetrigger,
            technique: .normal,
            source: previous,
            dest: current,
            velocity: 80,
            reason: "Ordinary retrigger",
            confidence: 1,
            evidence: ["ordinary"]
        )
    }
}

public enum TechniquePriority {
    /// Highest-priority wins when multiple techniques are possible:
    /// 1. pinchHarmonic (R1 + hard single-note attack)
    /// 2. harmonic (R1 + soft attack)
    /// 3. slide (explicit modifier + target)
    /// 4. bend (held note + lateral stick)
    /// 5. hammerOn / pullOff (legato inference)
    /// 6. palmMute (L2)
    /// 7. vibrato (gyro / micro-oscillation)
    /// 8. pressure (R2)
    /// 9. strum (right-stick Y)
    /// 10. normal
    public static let documentedOrder: [MusicalTechnique] = [
        .pinchHarmonic, .harmonic, .slideUp, .slideDown, .portamento,
        .bend, .hammerOn, .pullOff, .palmMute, .vibrato, .aftertouch, .normal
    ]

    public static func resolve(
        candidates: [MusicalTechnique],
        profile: InstrumentProfile
    ) -> MusicalTechnique {
        let allowed = candidates.filter { profile.supports($0) || $0 == .normal }
        for ranked in documentedOrder {
            if allowed.contains(ranked) { return ranked }
        }
        return allowed.first ?? .normal
    }
}

public struct VirtualString: Sendable, Equatable {
    public var index: Int
    public var openPitch: Note
    public var fret: Int

    public var soundingNote: Note { openPitch.transposed(by: fret) }
    public var isOpen: Bool { fret == 0 }
}

public struct VirtualStringModel: Sendable {
    public var strings: [VirtualString]
    public var activeStringIndex: Int

    public init(strings: [VirtualString], activeStringIndex: Int = 0) {
        self.strings = strings
        self.activeStringIndex = min(max(0, activeStringIndex), max(0, strings.count - 1))
    }

    public var activeString: VirtualString? {
        guard strings.indices.contains(activeStringIndex) else { return nil }
        return strings[activeStringIndex]
    }

    public static func guitarStandard(octaveShift: Int = 0) -> VirtualStringModel {
        let opens: [Note] = [
            Note(pitchClass: .e, octave: 2 + octaveShift),
            Note(pitchClass: .a, octave: 2 + octaveShift),
            Note(pitchClass: .d, octave: 3 + octaveShift),
            Note(pitchClass: .g, octave: 3 + octaveShift),
            Note(pitchClass: .b, octave: 3 + octaveShift),
            Note(pitchClass: .e, octave: 4 + octaveShift)
        ]
        return VirtualStringModel(strings: opens.enumerated().map { VirtualString(index: $0.offset, openPitch: $0.element, fret: 0) })
    }

    public static func bassStandard() -> VirtualStringModel {
        let opens: [Note] = [
            Note(pitchClass: .e, octave: 1),
            Note(pitchClass: .a, octave: 1),
            Note(pitchClass: .d, octave: 2),
            Note(pitchClass: .g, octave: 2)
        ]
        return VirtualStringModel(strings: opens.enumerated().map { VirtualString(index: $0.offset, openPitch: $0.element, fret: 0) })
    }

    public mutating func assign(note: Note) -> (stringIndex: Int, sameString: Bool) {
        var bestIndex = 0
        var bestFret = 24
        for (i, string) in strings.enumerated() {
            let fret = Int(note.midiNote) - Int(string.openPitch.midiNote)
            if fret >= 0 && fret <= 19 && fret < bestFret {
                bestFret = fret
                bestIndex = i
            }
        }
        let same = bestIndex == activeStringIndex
        activeStringIndex = bestIndex
        strings[bestIndex].fret = max(0, bestFret)
        return (bestIndex, same)
    }

    public func wouldBeSameString(from: Note, to: Note) -> Bool {
        var copy = self
        let first = copy.assign(note: from)
        let second = copy.assign(note: to)
        return first.stringIndex == second.stringIndex
    }
}

public struct SlideState: Sendable, Equatable {
    public var isSliding: Bool
    public var source: Note?
    public var destination: Note?
    public var progress: Double
    public var pitchOffset: Double
    public var arrived: Bool
}

public struct SlideEngine: Sendable {
    public var duration: TimeInterval
    private var elapsed: TimeInterval = 0
    private var source: Note?
    private var destination: Note?
    private var active = false

    public init(duration: TimeInterval = 0.18) {
        self.duration = duration
    }

    public mutating func begin(from: Note, to: Note, duration: TimeInterval? = nil) {
        source = from
        destination = to
        elapsed = 0
        active = true
        if let duration { self.duration = duration }
    }

    public mutating func cancel() {
        active = false
        elapsed = 0
        source = nil
        destination = nil
    }

    public mutating func advance(dt: TimeInterval) -> SlideState {
        guard active, let source, let destination else {
            return SlideState(isSliding: false, source: nil, destination: nil, progress: 0, pitchOffset: 0, arrived: false)
        }
        elapsed += max(0, dt)
        let progress = min(1.0, elapsed / max(0.03, duration))
        let eased = progress * progress * (3.0 - 2.0 * progress)
        let interval = Double(source.semitones(to: destination))
        let offset = interval * eased
        let arrived = progress >= 1.0
        if arrived { active = false }
        return SlideState(
            isSliding: !arrived,
            source: source,
            destination: destination,
            progress: progress,
            pitchOffset: offset,
            arrived: arrived
        )
    }
}

public struct IntervalMemory: Sendable {
    public var role: ChordToneRole
    public var lastNote: Note?

    public init(role: ChordToneRole = .root, lastNote: Note? = nil) {
        self.role = role
        self.lastNote = lastNote
    }

    public mutating func remember(role: ChordToneRole, note: Note) {
        self.role = role
        lastNote = note
    }
}
