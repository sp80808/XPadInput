import Foundation
import XPadCore

public struct PressureEnvelopeState: Sendable, Equatable {
    public var attackPressure: Double
    public var sustainedPressure: Double
    public var pressureDelta: Double
    public var releasePressure: Double
    public var pressureVelocity: Double
    public var smoothed: Double
    public var midiValue: UInt8
    public var isActive: Bool

    public init(
        attackPressure: Double = 0,
        sustainedPressure: Double = 0,
        pressureDelta: Double = 0,
        releasePressure: Double = 0,
        pressureVelocity: Double = 0,
        smoothed: Double = 0,
        midiValue: UInt8 = 0,
        isActive: Bool = false
    ) {
        self.attackPressure = attackPressure
        self.sustainedPressure = sustainedPressure
        self.pressureDelta = pressureDelta
        self.releasePressure = releasePressure
        self.pressureVelocity = pressureVelocity
        self.smoothed = smoothed
        self.midiValue = midiValue
        self.isActive = isActive
    }
}

/// Attack velocity is independent of sustained pressure.
public struct PressureEnvelopeEngine: Sendable {
    public var curve: PressureCurve
    public var smoothingTau: Double

    private var smoothed: Double = 0
    private var previousRaw: Double = 0
    private var attackPressure: Double = 0
    private var hasAttacked: Bool = false
    private var releasePressure: Double = 0

    public init(curve: PressureCurve = .expressive, smoothingTau: Double = 0.018) {
        self.curve = curve
        self.smoothingTau = smoothingTau
    }

    public mutating func reset() {
        smoothed = 0
        previousRaw = 0
        attackPressure = 0
        hasAttacked = false
        releasePressure = 0
    }

    public mutating func process(raw: Double, noteHeld: Bool, dt: TimeInterval) -> PressureEnvelopeState {
        let safeDt = max(0.0005, min(0.05, dt))
        let clamped = max(0.0, min(1.0, raw))
        let shaped = curve.apply(clamped)
        let alpha = 1.0 - exp(-safeDt / max(0.001, smoothingTau))
        let previous = smoothed
        smoothed += (shaped - smoothed) * alpha
        let velocity = (smoothed - previous) / safeDt

        if noteHeld && !hasAttacked && smoothed > 0.04 {
            hasAttacked = true
            attackPressure = smoothed
        }
        if !noteHeld {
            if hasAttacked {
                releasePressure = previousRaw
            }
            hasAttacked = false
            attackPressure = 0
        }

        previousRaw = smoothed
        let midi = UInt8(max(0, min(127, Int((smoothed * 127.0).rounded()))))
        return PressureEnvelopeState(
            attackPressure: attackPressure,
            sustainedPressure: noteHeld ? smoothed : 0,
            pressureDelta: smoothed - previous,
            releasePressure: releasePressure,
            pressureVelocity: velocity,
            smoothed: smoothed,
            midiValue: midi,
            isActive: smoothed > 0.02 && noteHeld
        )
    }
}

public struct VibratoState: Sendable, Equatable {
    public var depth: Double
    public var rate: Double
    public var offsetSemitones: Double
    public var regularity: Double
    public var isActive: Bool
}

/// Separates musical vibrato from broad pitch bend. Depth follows periodic intent,
/// not raw motion energy — a gyro flick must not start a sustained synthetic LFO.
public struct VibratoEngine: Sendable {
    public var maxDepthSemitones: Double
    public var defaultRateHz: Double
    public var lastIntent: VibratoIntent

    private var detector = VibratoIntentDetector()
    private var phase: Double = 0
    private var depthSmoothed: Double = 0
    private var rateSmoothed: Double = 5.2

    public init(maxDepthSemitones: Double = 0.18, defaultRateHz: Double = 5.2) {
        self.maxDepthSemitones = maxDepthSemitones
        self.defaultRateHz = defaultRateHz
        self.lastIntent = VibratoIntent()
    }

    public mutating func configure(profile: InstrumentProfile) {
        maxDepthSemitones = profile.vibratoDepthSemitones
        defaultRateHz = profile.vibratoRateHz
    }

    public mutating func reset() {
        detector.reset()
        phase = 0
        depthSmoothed = 0
        rateSmoothed = defaultRateHz
        lastIntent = VibratoIntent()
    }

    public mutating func process(
        stickX: Double,
        stickY: Double,
        gyroPitch: Double,
        gyroYaw: Double,
        triggerMicro: Double,
        noteHeld: Bool,
        dedicatedBend: Bool,
        motionEnabled: Bool,
        dt: TimeInterval
    ) -> VibratoState {
        let safeDt = max(0.0005, min(0.05, dt))
        let allowStick = !dedicatedBend
        let allowGyro = motionEnabled

        let intent = detector.process(
            stickX: stickX,
            gyroPitch: gyroPitch,
            gyroYaw: gyroYaw,
            triggerMicro: triggerMicro,
            allowStick: allowStick,
            allowGyro: allowGyro,
            dt: safeDt
        )
        lastIntent = intent

        guard noteHeld else {
            depthSmoothed *= 0.65
            return VibratoState(depth: 0, rate: defaultRateHz, offsetSemitones: 0, regularity: 0, isActive: false)
        }

        let periodic = intent.isPeriodic && intent.confidence >= 0.42
        let targetDepth: Double
        if periodic {
            targetDepth = min(maxDepthSemitones, intent.confidence * max(0.04, intent.amplitude) * maxDepthSemitones * 4)
        } else {
            // Impulse / broadband motion: decay any existing vibrato, never start an LFO.
            targetDepth = 0
        }

        depthSmoothed += (targetDepth - depthSmoothed) * min(1.0, safeDt / (periodic ? 0.05 : 0.03))
        if periodic {
            rateSmoothed += (intent.rateHz - rateSmoothed) * min(1.0, safeDt / 0.08)
            phase += rateSmoothed * safeDt
            if phase > 1 { phase -= floor(phase) }
        }

        let offset = periodic ? sin(phase * 2.0 * .pi) * depthSmoothed : 0
        return VibratoState(
            depth: depthSmoothed,
            rate: rateSmoothed,
            offsetSemitones: offset,
            regularity: intent.confidence,
            isActive: periodic && depthSmoothed > 0.012
        )
    }
}
