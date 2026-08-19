import Foundation
import XPadCore
import XPadTheory

public struct PitchExpressionState: Sendable, Equatable {
    public var bendSemitones: Double
    public var vibratoSemitones: Double
    public var totalSemitones: Double
    public var nearestTarget: PitchTarget?
    public var targetProximity: Double
    public var isBending: Bool
    public var midiPitchBend: UInt16
    public var crossedDetent: Bool
    public var displayLabel: String?

    public init(
        bendSemitones: Double = 0,
        vibratoSemitones: Double = 0,
        totalSemitones: Double = 0,
        nearestTarget: PitchTarget? = nil,
        targetProximity: Double = 0,
        isBending: Bool = false,
        midiPitchBend: UInt16 = 8192,
        crossedDetent: Bool = false,
        displayLabel: String? = nil
    ) {
        self.bendSemitones = bendSemitones
        self.vibratoSemitones = vibratoSemitones
        self.totalSemitones = totalSemitones
        self.nearestTarget = nearestTarget
        self.targetProximity = targetProximity
        self.isBending = isBending
        self.midiPitchBend = midiPitchBend
        self.crossedDetent = crossedDetent
        self.displayLabel = displayLabel
    }
}

/// Dedicated pitch-bend engine. All bend math lives here — not in views.
public struct PitchExpressionEngine: Sendable {
    public var instrumentRange: Double
    public var destinationRange: Double
    public var curve: PitchBendCurve
    public var assist: PitchAssistMode
    public var allowDownward: Bool
    public var stickDeadzone: Double
    public var springTau: Double
    public var trackingTau: Double

    private var currentBend: Double = 0
    private var latchedAtDetent: Bool = false
    private var lastProximity: Double = 0
    private let targeter = ContextualPitchTargeter()

    public init(
        instrumentRange: Double = 2.0,
        destinationRange: Double = 48.0,
        curve: PitchBendCurve = .expressive,
        assist: PitchAssistMode = .light,
        allowDownward: Bool = true,
        stickDeadzone: Double = 0.10,
        springTau: Double = 0.048,
        trackingTau: Double = 0.008
    ) {
        self.instrumentRange = instrumentRange
        self.destinationRange = destinationRange
        self.curve = curve
        self.assist = assist
        self.allowDownward = allowDownward
        self.stickDeadzone = stickDeadzone
        self.springTau = springTau
        self.trackingTau = trackingTau
    }

    public mutating func configure(profile: InstrumentProfile, destination: DestinationCapabilityProfile, assist: PitchAssistMode) {
        instrumentRange = profile.preferredPitchBendRange
        destinationRange = max(1.0, destination.bendRangeSemitones)
        curve = profile.defaultBendCurve
        allowDownward = profile.allowDownwardBend
        self.assist = assist
    }

    public mutating func reset() {
        currentBend = 0
        latchedAtDetent = false
        lastProximity = 0
    }

    /// Instant mapping used by tests. Applies curve + soft magnets, no temporal smoothing.
    public func mappedSemitones(
        stickX: Double,
        heldNote: Note,
        context: MusicalContext
    ) -> (semitones: Double, targets: [PitchTarget], nearest: PitchTarget?, proximity: Double) {
        let x = applyDeadzone(stickX)
        var unit = curve.apply(x)
        if !allowDownward {
            unit = max(0, unit)
        }
        var semitones = unit * instrumentRange
        let targets = targeter.bendTargets(
            from: heldNote,
            rangeSemitones: instrumentRange,
            context: context,
            allowDownward: allowDownward
        )
        let attracted = Self.attract(
            semitones,
            to: targets.map(\.semitones),
            strength: assist.attractionStrength
        )
        semitones = attracted.value
        let nearest = targets.min(by: { abs($0.semitones - semitones) < abs($1.semitones - semitones) })
        return (semitones, targets, nearest, attracted.proximity)
    }

    public mutating func process(
        stickX: Double,
        heldNote: Note?,
        context: MusicalContext,
        vibratoSemitones: Double,
        dt: TimeInterval
    ) -> PitchExpressionState {
        let safeDt = max(0.0005, min(0.05, dt))
        guard let heldNote else {
            currentBend = spring(currentBend, toward: 0, dt: safeDt, tau: springTau)
            latchedAtDetent = false
            return makeState(vibrato: 0, nearest: nil, proximity: 0, isBending: false, detent: false)
        }

        let x = applyDeadzone(stickX)
        if abs(x) < 0.0001 {
            // Hardware sends one value-changed callback when the sprung stick
            // reaches centre. Reset in that frame so no residual bend can be
            // left sounding while the controller is otherwise idle.
            currentBend = 0
            latchedAtDetent = false
            lastProximity = 0
            return makeState(vibrato: vibratoSemitones, nearest: nil, proximity: 0, isBending: false, detent: false)
        }

        let mapped = mappedSemitones(stickX: stickX, heldNote: heldNote, context: context)
        currentBend = spring(currentBend, toward: mapped.semitones, dt: safeDt, tau: trackingTau)

        var detent = false
        let proximity = mapped.proximity
        if proximity >= 0.92 && lastProximity < 0.92 && !latchedAtDetent {
            detent = true
            latchedAtDetent = true
        } else if proximity < 0.55 {
            latchedAtDetent = false
        }
        lastProximity = proximity

        var label: String?
        if let nearest = mapped.nearest, proximity > 0.35, abs(currentBend) > 0.08 {
            label = nearest.displayLabel
        } else if abs(currentBend) > 0.08 {
            label = String(format: "%@%.1f st", currentBend >= 0 ? "+" : "", currentBend)
        }

        var state = makeState(
            vibrato: vibratoSemitones,
            nearest: mapped.nearest,
            proximity: proximity,
            isBending: true,
            detent: detent
        )
        state.displayLabel = label
        return state
    }

    public static func pitchBendValue(semitones: Double, range: Double) -> UInt16 {
        MIDIValueCodec.pitchBend14(semitones: semitones, range: range)
    }

    public static func semitones(fromPitchBend value: UInt16, range: Double) -> Double {
        MIDIValueCodec.semitones(fromPitchBend14: value, range: range)
    }

    private func makeState(
        vibrato: Double,
        nearest: PitchTarget?,
        proximity: Double,
        isBending: Bool,
        detent: Bool
    ) -> PitchExpressionState {
        let total = abs(currentBend + vibrato) < 0.015 ? 0 : currentBend + vibrato
        return PitchExpressionState(
            bendSemitones: abs(currentBend) < 0.015 ? 0 : currentBend,
            vibratoSemitones: vibrato,
            totalSemitones: total,
            nearestTarget: nearest,
            targetProximity: proximity,
            isBending: isBending,
            midiPitchBend: Self.pitchBendValue(semitones: total, range: destinationRange),
            crossedDetent: detent
        )
    }

    private func applyDeadzone(_ x: Double) -> Double {
        let ax = abs(x)
        if ax <= stickDeadzone { return 0 }
        let sign = x < 0 ? -1.0 : 1.0
        return sign * min(1.0, (ax - stickDeadzone) / (1.0 - stickDeadzone))
    }

    private func spring(_ value: Double, toward target: Double, dt: TimeInterval, tau: Double) -> Double {
        let alpha = 1.0 - exp(-dt / max(0.001, tau))
        return value + (target - value) * alpha
    }

    /// Soft magnetic zones. Never hard-snaps.
    public static func attract(
        _ value: Double,
        to targets: [Double],
        strength: Double,
        zoneWidth: Double = 0.22
    ) -> (value: Double, nearest: Double?, proximity: Double) {
        guard strength > 0, let nearest = targets.min(by: { abs($0 - value) < abs($1 - value) }) else {
            return (value, targets.min(by: { abs($0 - value) < abs($1 - value) }), 0)
        }
        let dist = abs(value - nearest)
        let proximity = max(0.0, 1.0 - dist / zoneWidth)
        if dist > zoneWidth {
            return (value, nearest, max(0, 1.0 - dist / (zoneWidth * 2.5)))
        }
        let t = proximity
        let eased = t * t * (3.0 - 2.0 * t)
        let pulled = value + (nearest - value) * eased * strength
        return (pulled, nearest, t)
    }
}
