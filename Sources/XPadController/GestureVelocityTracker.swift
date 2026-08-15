import Foundation

/// Tracks continuous positional changes to calculate gesture speeds.
public struct GestureVelocityTracker: Sendable {
    public var lastX: Float = 0
    public var lastY: Float = 0
    public var lastRadius: Float = 0
    public var lastAngle: Float = 0
    public var lastTimestamp: TimeInterval = 0

    private var hasSample = false
    
    public init() {}
    
    /// Tracks velocity metrics for an analog stick input.
    /// - Parameters:
    ///   - x: Processed X coordinate.
    ///   - y: Processed Y coordinate.
    ///   - timestamp: System timestamp of the event.
    /// - Returns: A tuple containing various velocity calculations.
    public mutating func update(x: Float, y: Float, timestamp: TimeInterval) -> (
        movementVelocity: Float,
        xVelocity: Float,
        yVelocity: Float,
        radialVelocity: Float,
        angularVelocity: Float
    ) {
        let zero: (Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0)
        guard x.isFinite, y.isFinite, timestamp.isFinite else { return zero }

        if !hasSample {
            storeSample(x: x, y: y, timestamp: timestamp)
            hasSample = true
            return zero
        }

        let elapsed = timestamp - lastTimestamp
        // Duplicate or reordered callbacks carry no trustworthy time base.
        // Ignore them without moving history so the next valid sample measures
        // the complete gesture instead of reporting a one-millisecond spike.
        guard elapsed > 0 else { return zero }
        
        let dt = Float(max(0.001, elapsed))
        
        let currentRadius = sqrt(x * x + y * y)
        let currentAngle = atan2(y, x)
        
        let dx = x - lastX
        let dy = y - lastY
        
        let dist = sqrt(dx * dx + dy * dy)
        let movementVelocity = dist / dt
        let xVelocity = dx / dt
        let yVelocity = dy / dt
        
        let radialVelocity = (currentRadius - lastRadius) / dt
        
        // Angle is undefined at the centre. Do not turn a fresh gesture leaving
        // the deadzone into a large rotational impulse.
        let angularVelocity: Float
        if lastRadius > 0.0001, currentRadius > 0.0001 {
            var dAngle = currentAngle - lastAngle
            if dAngle > .pi { dAngle -= 2 * .pi }
            if dAngle < -.pi { dAngle += 2 * .pi }
            angularVelocity = dAngle / dt
        } else {
            angularVelocity = 0
        }

        storeSample(x: x, y: y, timestamp: timestamp)
        
        return (movementVelocity, xVelocity, yVelocity, radialVelocity, angularVelocity)
    }

    public mutating func reset() {
        hasSample = false
        lastX = 0
        lastY = 0
        lastRadius = 0
        lastAngle = 0
        lastTimestamp = 0
    }

    private mutating func storeSample(x: Float, y: Float, timestamp: TimeInterval) {
        lastX = x
        lastY = y
        lastRadius = sqrt(x * x + y * y)
        lastAngle = atan2(y, x)
        lastTimestamp = timestamp
    }
}

/// Tracks 1D continuous positional changes to calculate gesture speeds.
public struct LinearVelocityTracker: Sendable {
    public var lastValue: Float = 0
    public var lastTimestamp: TimeInterval = 0

    private var hasSample = false
    
    public init() {}
    
    public mutating func update(value: Float, timestamp: TimeInterval) -> (
        velocity: Float,
        acceleration: Float
    ) {
        guard value.isFinite, timestamp.isFinite else { return (0, 0) }

        if !hasSample {
            lastValue = value
            lastTimestamp = timestamp
            hasSample = true
            return (0, 0)
        }

        let elapsed = timestamp - lastTimestamp
        guard elapsed > 0 else { return (0, 0) }
        
        let dt = Float(max(0.001, elapsed))
        let dx = value - lastValue
        let velocity = dx / dt
        
        // Approximation of acceleration requires storing previous velocity, but this works for basic bounds tracking
        // (will enhance if needed)
        
        lastValue = value
        lastTimestamp = timestamp
        
        return (velocity, 0)
    }

    public mutating func reset() {
        hasSample = false
        lastValue = 0
        lastTimestamp = 0
    }
}
