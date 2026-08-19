import Foundation

/// Learns rest-centre drift and practical outer travel while the player is idle or fully committed at the rim.
/// Active musical gestures are never treated as neutral drift.
public struct PassiveCalibrationLearner: Sendable, Equatable {
    public var idleRadiusLimit: Float
    public var activeRadiusFloor: Float
    public var maxCentreOffset: Float
    public var minReach: Float
    public var maxReach: Float

    private var idleCount: Int
    private var idleSumX: Float
    private var idleSumY: Float
    private var observedReach: Float

    public init(
        idleRadiusLimit: Float = 0.08,
        activeRadiusFloor: Float = 0.72,
        maxCentreOffset: Float = 0.12,
        minReach: Float = 0.85,
        maxReach: Float = 1.15
    ) {
        self.idleRadiusLimit = idleRadiusLimit
        self.activeRadiusFloor = activeRadiusFloor
        self.maxCentreOffset = maxCentreOffset
        self.minReach = minReach
        self.maxReach = maxReach
        self.idleCount = 0
        self.idleSumX = 0
        self.idleSumY = 0
        self.observedReach = 0
    }

    public mutating func reset() {
        idleCount = 0
        idleSumX = 0
        idleSumY = 0
        observedReach = 0
    }

    /// Returns an updated calibration when enough idle samples exist. `processedRadius` is the
    /// post-deadzone musical radius so a committed strum/bend is never learned as rest.
    public mutating func observe(
        rawX: Float,
        rawY: Float,
        processedRadius: Float,
        into calibration: StickCalibration
    ) -> StickCalibration {
        let rawRadius = sqrt(rawX * rawX + rawY * rawY)
        var next = calibration

        if processedRadius < 0.02 && rawRadius < idleRadiusLimit {
            idleCount += 1
            idleSumX += rawX
            idleSumY += rawY
            if idleCount >= 45 {
                let avgX = idleSumX / Float(idleCount)
                let avgY = idleSumY / Float(idleCount)
                next.restCenterX = clamp(avgX, limit: maxCentreOffset)
                next.restCenterY = clamp(avgY, limit: maxCentreOffset)
                idleCount = 0
                idleSumX = 0
                idleSumY = 0
            }
        } else {
            idleCount = 0
            idleSumX = 0
            idleSumY = 0
        }

        if processedRadius >= activeRadiusFloor {
            observedReach = max(observedReach, rawRadius)
            next.maxRadius = min(maxReach, max(minReach, observedReach))
        }

        next.driftRadius = min(0.08, max(0.02, next.driftRadius))
        return next
    }

    private func clamp(_ value: Float, limit: Float) -> Float {
        max(-limit, min(limit, value))
    }
}
