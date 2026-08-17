import Foundation
import XPadCore

/// Processes raw analog stick input into a rich, expressively useful calibrated state.
public struct StickProcessor: Sendable {
    public var profile: InputProcessingProfile
    public var calibration: StickCalibration

    // Independent Axis Controls
    public var invertX: Bool = false
    public var invertY: Bool = false
    public var sensitivityX: Float = 1.0
    public var sensitivityY: Float = 1.0

    private var velocityTracker = GestureVelocityTracker()

    // Smoothing state
    private var smoothedX: Float = 0
    private var smoothedY: Float = 0
    private var wasInDeadzone: Bool = true
    private var lastSmoothingTimestamp: TimeInterval?

    /// Existing smoothing presets were tuned as per-sample EMA coefficients.
    /// Treat them as coefficients at a 120 Hz reference cadence, then derive
    /// the equivalent alpha from elapsed time so controller callback frequency
    /// does not change the effective response curve.
    private static let smoothingReferenceInterval: TimeInterval = 1.0 / 120.0

    public init(
        profile: InputProcessingProfile = .expressive,
        calibration: StickCalibration = StickCalibration()
    ) {
        self.profile = profile
        self.calibration = calibration
        self.invertX = calibration.invertX
        self.invertY = calibration.invertY
        self.sensitivityX = calibration.sensitivityX
        self.sensitivityY = calibration.sensitivityY
    }

    /// Processes raw coordinates, applying hardware calibration, deadzones, curves, smoothing, and tracking velocity.
    /// - Parameters:
    ///   - rawX: Raw X coordinate from GameController [-1.0, 1.0].
    ///   - rawY: Raw Y coordinate from GameController [-1.0, 1.0].
    ///   - timestamp: Monotonic timestamp for smoothing and velocity tracking.
    /// - Returns: Fully processed and calibrated stick state.
    public mutating func process(rawX: Float, rawY: Float, timestamp: TimeInterval) -> ProcessedStickState {
        // 1. Hardware Calibration (rest center offset & reachable range normalization)
        var (calX, calY) = calibration.calibrate(rawX: rawX, rawY: rawY)

        // 2. Per-Axis Inversion & Sensitivity
        if invertX { calX = -calX }
        if invertY { calY = -calY }
        calX = max(-1.0, min(1.0, calX * sensitivityX))
        calY = max(-1.0, min(1.0, calY * sensitivityY))

        // 3. Deadzone with Hysteresis (prevents rapid flutter near deadzone border)
        let deadzoned = profile.deadzone.process(x: calX, y: calY)
        let rawMagnitude = sqrt(deadzoned.x * deadzoned.x + deadzoned.y * deadzoned.y)

        let isInDeadzone: Bool
        if wasInDeadzone {
            isInDeadzone = rawMagnitude < 0.02
        } else {
            isInDeadzone = rawMagnitude < 0.01
        }
        wasInDeadzone = isInDeadzone

        // 4. Response Curve Mapping
        let processedMagnitude = profile.responseCurve.process(magnitude: rawMagnitude)

        var curvedX: Float = 0
        var curvedY: Float = 0

        if rawMagnitude > 0 && !isInDeadzone {
            let ratio = processedMagnitude / rawMagnitude
            curvedX = deadzoned.x * ratio
            curvedY = deadzoned.y * ratio
        }

        // 5. Performance Smoothing (elapsed-time-normalized EMA)
        let alpha = smoothingAlpha(at: timestamp)
        smoothedX = smoothedX + (curvedX - smoothedX) * alpha
        smoothedY = smoothedY + (curvedY - smoothedY) * alpha

        // 6. Velocity & Gesture Trajectory Tracking
        // Velocity intentionally follows the processed/smoothed musical signal.
        // Attack-specific raw velocity should use a separate tracker rather than
        // changing this established semantic output for every consumer.
        let velocities = velocityTracker.update(x: smoothedX, y: smoothedY, timestamp: timestamp)

        let finalRadius = sqrt(smoothedX * smoothedX + smoothedY * smoothedY)
        let finalAngle = atan2(Double(smoothedY), Double(smoothedX))

        return ProcessedStickState(
            rawX: rawX,
            rawY: rawY,
            calibratedX: calX,
            calibratedY: calY,
            x: smoothedX,
            y: smoothedY,
            radius: finalRadius,
            angle: finalAngle,
            movementVelocity: velocities.movementVelocity,
            xVelocity: velocities.xVelocity,
            yVelocity: velocities.yVelocity,
            radialVelocity: velocities.radialVelocity,
            angularVelocity: Double(velocities.angularVelocity),
            isInDeadzone: isInDeadzone,
            isNearEdge: finalRadius > 0.94
        )
    }

    private mutating func smoothingAlpha(at timestamp: TimeInterval) -> Float {
        let referenceAlpha = max(0, min(1, profile.smoothingFactor))

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

/// Rich state of an analog stick across physical, calibrated, and musically processed domains.
public struct ProcessedStickState: Sendable, Codable, Equatable {
    public let rawX: Float
    public let rawY: Float
    public let calibratedX: Float
    public let calibratedY: Float

    public let x: Float
    public let y: Float
    public let radius: Float
    public let angle: Double

    public let movementVelocity: Float
    public let xVelocity: Float
    public let yVelocity: Float
    public let radialVelocity: Float
    public let angularVelocity: Double

    public let isInDeadzone: Bool
    public let isNearEdge: Bool

    public init(
        rawX: Float = 0, rawY: Float = 0,
        calibratedX: Float = 0, calibratedY: Float = 0,
        x: Float = 0, y: Float = 0,
        radius: Float = 0, angle: Double = 0,
        movementVelocity: Float = 0,
        xVelocity: Float = 0, yVelocity: Float = 0,
        radialVelocity: Float = 0, angularVelocity: Double = 0,
        isInDeadzone: Bool = true, isNearEdge: Bool = false
    ) {
        self.rawX = rawX
        self.rawY = rawY
        self.calibratedX = calibratedX
        self.calibratedY = calibratedY
        self.x = x
        self.y = y
        self.radius = radius
        self.angle = angle
        self.movementVelocity = movementVelocity
        self.xVelocity = xVelocity
        self.yVelocity = yVelocity
        self.radialVelocity = radialVelocity
        self.angularVelocity = angularVelocity
        self.isInDeadzone = isInDeadzone
        self.isNearEdge = isNearEdge
    }

    /// Right-stick Y uses the strum processor; X uses the bend processor.
    public static func composing(strum: ProcessedStickState, bend: ProcessedStickState) -> ProcessedStickState {
        let x = bend.x
        let y = strum.y
        let radius = sqrt(x * x + y * y)
        return ProcessedStickState(
            rawX: bend.rawX,
            rawY: strum.rawY,
            calibratedX: bend.calibratedX,
            calibratedY: strum.calibratedY,
            x: x,
            y: y,
            radius: radius,
            angle: atan2(Double(y), Double(x)),
            movementVelocity: max(strum.movementVelocity, bend.movementVelocity),
            xVelocity: bend.xVelocity,
            yVelocity: strum.yVelocity,
            radialVelocity: strum.radialVelocity,
            angularVelocity: bend.angularVelocity,
            isInDeadzone: strum.isInDeadzone && bend.isInDeadzone,
            isNearEdge: radius > 0.94
        )
    }
}
