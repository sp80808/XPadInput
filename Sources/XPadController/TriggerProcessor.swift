import Foundation

/// Processes raw analog trigger input into a rich state.
public struct TriggerProcessor: Sendable {
    public var deadzone: Float = 0.05
    public var responseCurve: ResponseCurve = .linear
    public var smoothingFactor: Float = 0.8
    
    private var velocityTracker = LinearVelocityTracker()
    private var smoothedValue: Float = 0
    
    // Attack detection
    private var lastAttackVelocity: Float = 0
    private var isHeld: Bool = false
    private var holdStartTime: TimeInterval = 0
    
    public init() {}
    
    public mutating func process(rawValue: Float, timestamp: TimeInterval) -> ProcessedTriggerState {
        // 1. Deadzone
        var processed = rawValue
        if processed < deadzone {
            processed = 0
        } else {
            processed = (processed - deadzone) / (1.0 - deadzone)
        }
        
        // 2. Response Curve
        processed = responseCurve.process(magnitude: processed)
        
        // 3. Smoothing
        if smoothingFactor >= 1.0 {
            smoothedValue = processed
        } else {
            smoothedValue = smoothedValue + (processed - smoothedValue) * smoothingFactor
        }
        
        // 4. Velocity
        let vels = velocityTracker.update(value: smoothedValue, timestamp: timestamp)
        
        // 5. Attack / Hold Logic
        if smoothedValue > 0.1 && !isHeld {
            isHeld = true
            holdStartTime = timestamp
            lastAttackVelocity = max(0, vels.velocity)
        } else if smoothedValue <= 0.05 && isHeld {
            isHeld = false
            holdStartTime = 0
        }
        
        // Attack velocity fades over time to clear the transient
        if isHeld {
            let holdDuration = timestamp - holdStartTime
            if holdDuration > 0.2 {
                lastAttackVelocity *= 0.9 // Fade out
            }
        } else {
            lastAttackVelocity = 0
        }
        
        return ProcessedTriggerState(
            rawValue: rawValue,
            value: smoothedValue,
            velocity: vels.velocity,
            attackVelocity: lastAttackVelocity,
            holdDuration: isHeld ? (timestamp - holdStartTime) : 0,
            isPressed: smoothedValue > 0.1
        )
    }
}

/// Rich state of an analog trigger.
public struct ProcessedTriggerState: Sendable, Codable {
    public let rawValue: Float
    public let value: Float
    public let velocity: Float
    public let attackVelocity: Float
    public let holdDuration: TimeInterval
    public let isPressed: Bool
    
    public init(
        rawValue: Float = 0, value: Float = 0,
        velocity: Float = 0, attackVelocity: Float = 0,
        holdDuration: TimeInterval = 0, isPressed: Bool = false
    ) {
        self.rawValue = rawValue
        self.value = value
        self.velocity = velocity
        self.attackVelocity = attackVelocity
        self.holdDuration = holdDuration
        self.isPressed = isPressed
    }
}
