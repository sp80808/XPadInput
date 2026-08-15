import Foundation

/// Tracks continuous positional changes to calculate gesture speeds.
public struct GestureVelocityTracker: Sendable {
    public var lastX: Float = 0
    public var lastY: Float = 0
    public var lastRadius: Float = 0
    public var lastAngle: Float = 0
    public var lastTimestamp: TimeInterval = 0
    
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
        if lastTimestamp == 0 {
            lastX = x
            lastY = y
            lastRadius = sqrt(x * x + y * y)
            lastAngle = atan2(y, x)
            lastTimestamp = timestamp
            return (0, 0, 0, 0, 0)
        }
        
        let dt = Float(max(0.001, timestamp - lastTimestamp))
        
        let currentRadius = sqrt(x * x + y * y)
        let currentAngle = atan2(y, x)
        
        let dx = x - lastX
        let dy = y - lastY
        
        let dist = sqrt(dx * dx + dy * dy)
        let movementVelocity = dist / dt
        let xVelocity = dx / dt
        let yVelocity = dy / dt
        
        let radialVelocity = (currentRadius - lastRadius) / dt
        
        // Handle angular wrap-around
        var dAngle = currentAngle - lastAngle
        if dAngle > .pi { dAngle -= 2 * .pi }
        if dAngle < -.pi { dAngle += 2 * .pi }
        let angularVelocity = dAngle / dt
        
        lastX = x
        lastY = y
        lastRadius = currentRadius
        lastAngle = currentAngle
        lastTimestamp = timestamp
        
        return (movementVelocity, xVelocity, yVelocity, radialVelocity, angularVelocity)
    }
}

/// Tracks 1D continuous positional changes to calculate gesture speeds.
public struct LinearVelocityTracker: Sendable {
    public var lastValue: Float = 0
    public var lastTimestamp: TimeInterval = 0
    
    public init() {}
    
    public mutating func update(value: Float, timestamp: TimeInterval) -> (
        velocity: Float,
        acceleration: Float
    ) {
        if lastTimestamp == 0 {
            lastValue = value
            lastTimestamp = timestamp
            return (0, 0)
        }
        
        let dt = Float(max(0.001, timestamp - lastTimestamp))
        let dx = value - lastValue
        let velocity = dx / dt
        
        // Approximation of acceleration requires storing previous velocity, but this works for basic bounds tracking
        // (will enhance if needed)
        
        lastValue = value
        lastTimestamp = timestamp
        
        return (velocity, 0)
    }
}
