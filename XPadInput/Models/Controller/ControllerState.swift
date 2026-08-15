import Foundation
import GameController
import Combine

/// Real-time state of a connected controller
@Observable
final class ControllerState: @unchecked Sendable {
    // Sticks (values from -1.0 to 1.0)
    var leftStickX: Float = 0
    var leftStickY: Float = 0
    var rightStickX: Float = 0
    var rightStickY: Float = 0
    
    // Triggers (0.0 to 1.0)
    var leftTrigger: Float = 0
    var rightTrigger: Float = 0
    
    // Shoulders
    var leftShoulder: Bool = false
    var rightShoulder: Bool = false
    
    // Face buttons
    var buttonA: Bool = false  // Cross / A
    var buttonB: Bool = false  // Circle / B
    var buttonX: Bool = false  // Square / X
    var buttonY: Bool = false  // Triangle / Y
    
    // D-pad
    var dpadUp: Bool = false
    var dpadDown: Bool = false
    var dpadLeft: Bool = false
    var dpadRight: Bool = false
    
    // Stick buttons
    var leftStickButton: Bool = false
    var rightStickButton: Bool = false
    
    // Menu buttons
    var menuButton: Bool = false
    var optionsButton: Bool = false
    
    // Touchpad (if available)
    var touchpadX: Float = 0
    var touchpadY: Float = 0
    var touchpadActive: Bool = false
    
    // Motion (if available)
    var gyroX: Double = 0
    var gyroY: Double = 0
    var gyroZ: Double = 0
    var accelX: Double = 0
    var accelY: Double = 0
    var accelZ: Double = 0
    var hasMotion: Bool = false
    
    // Computed properties
    var leftStickAngle: Double {
        atan2(Double(leftStickY), Double(leftStickX))
    }
    
    var leftStickMagnitude: Double {
        let mag = sqrt(Double(leftStickX * leftStickX + leftStickY * leftStickY))
        return min(mag, 1.0)
    }
    
    var rightStickAngle: Double {
        atan2(Double(rightStickY), Double(rightStickX))
    }
    
    var rightStickMagnitude: Double {
        let mag = sqrt(Double(rightStickX * rightStickX + rightStickY * rightStickY))
        return min(mag, 1.0)
    }
    
    /// Check if any modifier button is held
    var activeModifier: ControllerModifier {
        if leftShoulder && rightShoulder { return .bothShoulders }
        if leftShoulder { return .leftShoulder }
        if rightShoulder { return .rightShoulder }
        if leftTrigger > 0.5 { return .leftTrigger }
        if rightTrigger > 0.5 { return .rightTrigger }
        return .none
    }
}

/// Controller modifier layers
enum ControllerModifier: String, CaseIterable, Sendable {
    case none = "Normal"
    case leftShoulder = "L1 — Colour"
    case rightShoulder = "R1 — Rhythm"
    case leftTrigger = "L2 — Expression"
    case rightTrigger = "R2 — Variation"
    case bothShoulders = "L1+R1 — Arrange"
}
