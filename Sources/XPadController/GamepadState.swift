import Foundation
import GameController
import XPadCore

/// Real-time state of a connected controller
@Observable
public final class ControllerState: @unchecked Sendable {
    // Sticks (values from -1.0 to 1.0)
    public var leftStickX: Float = 0
    public var leftStickY: Float = 0
    public var rightStickX: Float = 0
    public var rightStickY: Float = 0
    
    // Triggers (0.0 to 1.0)
    public var leftTrigger: Float = 0
    public var rightTrigger: Float = 0
    
    // Shoulders
    public var leftShoulder: Bool = false
    public var rightShoulder: Bool = false
    
    // Face buttons
    public var buttonA: Bool = false  // Cross / A
    public var buttonB: Bool = false  // Circle / B
    public var buttonX: Bool = false  // Square / X
    public var buttonY: Bool = false  // Triangle / Y
    
    // D-pad
    public var dpadUp: Bool = false
    public var dpadDown: Bool = false
    public var dpadLeft: Bool = false
    public var dpadRight: Bool = false
    
    // Stick buttons
    public var leftStickButton: Bool = false
    public var rightStickButton: Bool = false
    
    // Menu buttons
    public var menuButton: Bool = false
    public var optionsButton: Bool = false
    
    // Touchpad (if available)
    public var touchpadX: Float = 0
    public var touchpadY: Float = 0
    public var touchpadActive: Bool = false
    
    // Motion (if available)
    public var gyroX: Double = 0
    public var gyroY: Double = 0
    public var gyroZ: Double = 0
    public var accelX: Double = 0
    public var accelY: Double = 0
    public var accelZ: Double = 0
    public var hasMotion: Bool = false
    
    public init() {}
    
    // Computed properties
    public var leftStickAngle: Double {
        atan2(Double(leftStickY), Double(leftStickX))
    }
    
    public var leftStickMagnitude: Double {
        let mag = sqrt(Double(leftStickX * leftStickX + leftStickY * leftStickY))
        return min(mag, 1.0)
    }
    
    public var rightStickAngle: Double {
        atan2(Double(rightStickY), Double(rightStickX))
    }
    
    public var rightStickMagnitude: Double {
        let mag = sqrt(Double(rightStickX * rightStickX + rightStickY * rightStickY))
        return min(mag, 1.0)
    }
    
    /// Check if any modifier button is held
    public var activeModifier: ControllerModifier {
        if leftShoulder && rightShoulder { return .bothShoulders }
        if leftShoulder { return .leftShoulder }
        if rightShoulder { return .rightShoulder }
        if leftTrigger > 0.5 { return .leftTrigger }
        if rightTrigger > 0.5 { return .rightTrigger }
        return .none
    }
}

/// Controller modifier layers
public enum ControllerModifier: String, CaseIterable, Sendable {
    case none = "Normal"
    case leftShoulder = "L1 — Colour"
    case rightShoulder = "R1 — Rhythm"
    case leftTrigger = "L2 — Expression"
    case rightTrigger = "R2 — Variation"
    case bothShoulders = "L1+R1 — Arrange"
}
