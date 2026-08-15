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
        guard let previous else {
            return LegatoInterpretation(
                transition: .normalRetrigger,
                technique: .normal,
                source: current,
                destination: current,
                velocity: 80,
                reason: "No source note"
            )
        }

        let interval = previous.semitones(to: current)
        let absInterval = abs(interval)

        if slideModifier && profile.supportsSlides && overlap {
            return LegatoInterpretation(
                transition: .slide,
                technique: interval >= 0 ? .slideUp : .slideDown,
                source: previous,
                destination: current,
                velocity: 70,
                reason: "Explicit slide modifier"
            )
        }

        if absInterval == 0 {
            return LegatoInterpretation(
                transition: .normalRetrigger,
                technique: .normal,
                source: previous,
                destination: current,
                velocity: 80,
                reason: "Unison retrigger"
            )
        }

        // Grace note: extremely fast extra note before a pick attack.
        if hasPickAttack && intervalMs < 45 && absInterval <= 3 {
            return LegatoInterpretation(
                transition: .graceNote,
                technique: .graceNote,
                source: previous,
                destination: current,
                velocity: 72,
                reason: "Grace ornament before attack"
            )
        }

        let stringOK: Bool
        switch realism {
        case .relaxed:
            stringOK = true
        case .natural:
            stringOK = sameString || absInterval <= 5
        case .strict:
            stringOK = sameString
        }

        if profile.supportsHammerOns && overlap && !hasPickAttack && interval > 0 {
            let withinInterval = absInterval <= profile.hammerOnMaxInterval
            let withinTime = intervalMs <= profile.hammerOnMaxGapMs
            if withinInterval && withinTime && stringOK {
                let hammerVelocity = UInt8(max(40, min(100, Int(110.0 - intervalMs * 0.2))))
                return LegatoInterpretation(
                    transition: .hammerOn,
                    technique: .hammerOn,
                    source: previous,
                    destination: current,
                    velocity: hammerVelocity,
                    reason: "Upward legato without pick"
                )
            }
        }

        if profile.supportsPullOffs && !hasPickAttack && interval < 0 {
            let withinTime = intervalMs <= profile.pullOffMaxGapMs
            let prepared = realism == .relaxed ? true : preparedLowerNote
            if withinTime && stringOK && prepared {
                return LegatoInterpretation(
                    transition: .pullOff,
                    technique: .pullOff,
                    source: previous,
                    destination: current,
                    velocity: 58,
                    reason: "Downward release to prepared note"
                )
            }
        }

        // A single fast neighbour transition is only treated as a trill after
        // the more specific hammer-on and pull-off rules have declined it.
        if overlap && intervalMs < 90 && absInterval <= 2 && profile.supportsLegato {
            return LegatoInterpretation(
                transition: .trill,
                technique: .trill,
                source: previous,
                destination: current,
                velocity: 64,
                reason: "Rapid neighbour alternation"
            )
        }

        return LegatoInterpretation(
            transition: .normalRetrigger,
            technique: .normal,
            source: previous,
            destination: current,
            velocity: 80,
            reason: "Ordinary retrigger"
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
