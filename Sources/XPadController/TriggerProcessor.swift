import Foundation
import XPadCore

/// Processes raw analog trigger input into a calibrated continuous musical state.
public struct TriggerProcessor: Sendable {
    public var calibration: TriggerCalibration
    public var deadzone: Float = 0.05
    public var responseCurve: ResponseCurve = .linear
    public var smoothingFactor: Float = 0.85

    private var velocityTracker = LinearVelocityTracker()
    private var smoothedValue: Float = 0
    private var lastSmoothingTimestamp: TimeInterval?

    // Attack detection with hysteresis
    private var lastAttackVelocity: Float = 0
    private var isHeld: Bool = false
    private var holdStartTime: TimeInterval = 0

    /// Preserve the feel of existing smoothing presets at a 120 Hz reference
    /// cadence while deriving the actual EMA alpha from elapsed time.
    private static let smoothingReferenceInterval: TimeInterval = 1.0 / 120.0

    public init(
        calibration: TriggerCalibration = TriggerCalibration(),
        deadzone: Float = 0.05,
        responseCurve: ResponseCurve = .linear,
        smoothingFactor: Float = 0.85
    ) {
        self.calibration = calibration
        self.deadzone = deadzone
        self.responseCurve = responseCurve
        self.smoothingFactor = smoothingFactor
    }

    public mutating func process(rawValue: Float, timestamp: TimeInterval) -> ProcessedTriggerState {
        // 1. Hardware Calibration
        let calibrated = calibration.calibrate(rawValue: rawValue)

        // 2. Deadzone
        var processed = calibrated
        if processed < deadzone {
            processed = 0
        } else {
            processed = (processed - deadzone) / max(0.001, (1.0 - deadzone))
        }

        // 3. Response Curve
        processed = responseCurve.process(magnitude: processed)

        // 4. Performance Smoothing (elapsed-time-normalized EMA)
        let alpha = smoothingAlpha(at: timestamp)
        smoothedValue = smoothedValue + (processed - smoothedValue) * alpha

        // 5. Velocity Tracking
        // Trigger velocity intentionally follows the processed musical value so
        // attack/hold behaviour sees the same signal exposed to downstream code.
        let vels = velocityTracker.update(value: smoothedValue, timestamp: timestamp)

        // 6. Attack / Hold Logic with Hysteresis (Engage at >0.10, Release at <0.04)
        if smoothedValue > 0.10 && !isHeld {
            isHeld = true
            holdStartTime = timestamp
            lastAttackVelocity = max(0, vels.velocity)
        } else if smoothedValue <= 0.04 && isHeld {
            isHeld = false
            holdStartTime = 0
        }

        // Attack transient decay
        if isHeld {
            let holdDuration = timestamp - holdStartTime
            if holdDuration > 0.15 {
                lastAttackVelocity *= 0.88 // Smooth transient decay
            }
        } else {
            lastAttackVelocity = 0
        }

        return ProcessedTriggerState(
            rawValue: rawValue,
            calibratedValue: calibrated,
            value: smoothedValue,
            velocity: vels.velocity,
            attackVelocity: lastAttackVelocity,
            holdDuration: isHeld ? (timestamp - holdStartTime) : 0,
            isPressed: isHeld
        )
    }

    private mutating func smoothingAlpha(at timestamp: TimeInterval) -> Float {
        let referenceAlpha = max(0, min(1, smoothingFactor))

        guard timestamp.isFinite else { return 0 }

        guard let previousTimestamp = lastSmoothingTimestamp else {
            lastSmoothingTimestamp = timestamp
            return referenceAlpha
        }

        guard timestamp > previousTimestamp else {
            // Duplicate/reordered callbacks must not advance filter state.
            return 0
        }

        lastSmoothingTimestamp = timestamp

        guard referenceAlpha < 1 else { return 1 }
        guard referenceAlpha > 0 else { return 0 }

        let elapsed = timestamp - previousTimestamp
        let retentionAtReference = 1.0 - Double(referenceAlpha)
        let elapsedReferenceFrames = elapsed / Self.smoothingReferenceInterval
        let elapsedAlpha = 1.0 - pow(retentionAtReference, elapsedReferenceFrames)
        return Float(max(0, min(1, elapsedAlpha)))
    }
}

/// Rich state of an analog trigger across physical, calibrated, and processed domains.
public struct ProcessedTriggerState: Sendable, Codable, Equatable {
    public let rawValue: Float
    public let calibratedValue: Float
    public let value: Float
    public let velocity: Float
    public let attackVelocity: Float
    public let holdDuration: TimeInterval
    public let isPressed: Bool

    public init(
        rawValue: Float = 0,
        calibratedValue: Float = 0,
        value: Float = 0,
        velocity: Float = 0,
        attackVelocity: Float = 0,
        holdDuration: TimeInterval = 0,
        isPressed: Bool = false
    ) {
        self.rawValue = rawValue
        self.calibratedValue = calibratedValue
        self.value = value
        self.velocity = velocity
        self.attackVelocity = attackVelocity
        self.holdDuration = holdDuration
        self.isPressed = isPressed
    }
}
