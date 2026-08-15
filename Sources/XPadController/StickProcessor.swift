import Foundation

/// Processes raw analog stick input into a rich, expressively useful state.
public struct StickProcessor: Sendable {
    public var profile: InputProcessingProfile
    private var velocityTracker = GestureVelocityTracker()
    
    // Smoothing state
    private var smoothedX: Float = 0
    private var smoothedY: Float = 0
    
    public init(profile: InputProcessingProfile = .expressive) {
        self.profile = profile
    }
    
    /// Processes raw coordinates, applying deadzones, curves, smoothing, and tracking velocity.
    /// - Parameters:
    ///   - rawX: Raw X coordinate [-1.0, 1.0].
    ///   - rawY: Raw Y coordinate [-1.0, 1.0].
    ///   - timestamp: System timestamp for velocity tracking.
    /// - Returns: Processed stick state.
    public mutating func process(rawX: Float, rawY: Float, timestamp: TimeInterval) -> ProcessedStickState {
        // 1. Deadzone
        let deadzoned = profile.deadzone.process(x: rawX, y: rawY)
        
        // 2. Response Curve
        let magnitude = sqrt(deadzoned.x * deadzoned.x + deadzoned.y * deadzoned.y)
        let processedMagnitude = profile.responseCurve.process(magnitude: magnitude)
        
        var curvedX: Float = 0
        var curvedY: Float = 0
        
        if magnitude > 0 {
            let ratio = processedMagnitude / magnitude
            curvedX = deadzoned.x * ratio
            curvedY = deadzoned.y * ratio
        }
        
        // 3. Smoothing (Exponential moving average)
        if profile.smoothingFactor >= 1.0 {
            smoothedX = curvedX
            smoothedY = curvedY
        } else {
            smoothedX = smoothedX + (curvedX - smoothedX) * profile.smoothingFactor
            smoothedY = smoothedY + (curvedY - smoothedY) * profile.smoothingFactor
        }
        
        // 4. Velocity Tracking
        let velocities = velocityTracker.update(x: smoothedX, y: smoothedY, timestamp: timestamp)
        
        let finalRadius = sqrt(smoothedX * smoothedX + smoothedY * smoothedY)
        let finalAngle = atan2(Double(smoothedY), Double(smoothedX))
        
        return ProcessedStickState(
            rawX: rawX,
            rawY: rawY,
            x: smoothedX,
            y: smoothedY,
            radius: finalRadius,
            angle: finalAngle,
            movementVelocity: velocities.movementVelocity,
            xVelocity: velocities.xVelocity,
            yVelocity: velocities.yVelocity,
            radialVelocity: velocities.radialVelocity,
            angularVelocity: Double(velocities.angularVelocity),
            isInDeadzone: magnitude == 0,
            isNearEdge: finalRadius > 0.95
        )
    }
}

/// Rich state of an analog stick.
public struct ProcessedStickState: Sendable, Codable {
    public let rawX: Float
    public let rawY: Float
    
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
        x: Float = 0, y: Float = 0,
        radius: Float = 0, angle: Double = 0,
        movementVelocity: Float = 0,
        xVelocity: Float = 0, yVelocity: Float = 0,
        radialVelocity: Float = 0, angularVelocity: Double = 0,
        isInDeadzone: Bool = true, isNearEdge: Bool = false
    ) {
        self.rawX = rawX
        self.rawY = rawY
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
}
