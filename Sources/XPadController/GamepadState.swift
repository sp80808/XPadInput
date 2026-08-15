import Foundation
import GameController
import XPadCore

public enum ControllerKind: String, Codable, Sendable {
    case dualSense = "Sony DualSense (PS5)"
    case dualShock4 = "Sony DualShock 4 (PS4)"
    case xbox = "Xbox Wireless Controller"
    case switchPro = "Nintendo Switch Pro"
    case generic = "Extended Gamepad"
    case simulated = "Virtual / Keyboard Controller"
}

public struct ControllerCapabilityProfile: Codable, Sendable {
    public var hasTouchpad: Bool
    public var hasMotionIMU: Bool
    public var hasHaptics: Bool
    public var hasAnalogTriggers: Bool
    public var hasThumbstickClicks: Bool
    public var buttonLabels: [String] // e.g. ["Cross", "Circle", "Square", "Triangle"] or ["A", "B", "X", "Y"]

    public static let dualSense = ControllerCapabilityProfile(
        hasTouchpad: true,
        hasMotionIMU: true,
        hasHaptics: true,
        hasAnalogTriggers: true,
        hasThumbstickClicks: true,
        buttonLabels: ["Cross (✕)", "Circle (○)", "Square (□)", "Triangle (△)"]
    )

    public static let xbox = ControllerCapabilityProfile(
        hasTouchpad: false,
        hasMotionIMU: false,
        hasHaptics: true,
        hasAnalogTriggers: true,
        hasThumbstickClicks: true,
        buttonLabels: ["A", "B", "X", "Y"]
    )

    public static let switchPro = ControllerCapabilityProfile(
        hasTouchpad: false,
        hasMotionIMU: true,
        hasHaptics: true,
        hasAnalogTriggers: false,
        hasThumbstickClicks: true,
        buttonLabels: ["B", "A", "Y", "X"]
    )

    public static let generic = ControllerCapabilityProfile(
        hasTouchpad: false,
        hasMotionIMU: false,
        hasHaptics: false,
        hasAnalogTriggers: true,
        hasThumbstickClicks: true,
        buttonLabels: ["A", "B", "X", "Y"]
    )
}

public struct StickCoordinates: Codable, Sendable {
    public var x: Double // -1.0 ... 1.0
    public var y: Double // -1.0 ... 1.0
    public var deadzone: Double

    public init(x: Double = 0.0, y: Double = 0.0, deadzone: Double = 0.12) {
        self.x = x
        self.y = y
        self.deadzone = deadzone
    }

    public var radius: Double {
        let rawR = sqrt(x * x + y * y)
        if rawR < deadzone { return 0.0 }
        return min(1.0, (rawR - deadzone) / (1.0 - deadzone))
    }

    public var angle: Double {
        atan2(y, x) // -PI to +PI
    }

    public var isActive: Bool {
        radius > 0.0
    }
}

public struct GamepadState: Codable, Sendable {
    public var leftStick: StickCoordinates
    public var rightStick: StickCoordinates
    
    // Triggers (0.0 to 1.0)
    public var leftTrigger: Double
    public var rightTrigger: Double
    
    // Shoulders
    public var leftShoulder: Bool
    public var rightShoulder: Bool
    
    // Face buttons
    public var buttonA: Bool // Bottom (Cross / A / B)
    public var buttonB: Bool // Right (Circle / B / A)
    public var buttonX: Bool // Left (Square / X / Y)
    public var buttonY: Bool // Top (Triangle / Y / X)
    
    // D-Pad
    public var dpadUp: Bool
    public var dpadDown: Bool
    public var dpadLeft: Bool
    public var dpadRight: Bool
    
    // Stick Clicks
    public var leftStickClick: Bool
    public var rightStickClick: Bool
    
    // Touchpad (if supported, -1.0 to 1.0)
    public var touchX: Double
    public var touchY: Double
    public var isTouching: Bool
    
    // Motion / Gyro
    public var gyroPitch: Double
    public var gyroRoll: Double
    public var gyroYaw: Double

    public init(
        leftStick: StickCoordinates = StickCoordinates(),
        rightStick: StickCoordinates = StickCoordinates(),
        leftTrigger: Double = 0.0,
        rightTrigger: Double = 0.0,
        leftShoulder: Bool = false,
        rightShoulder: Bool = false,
        buttonA: Bool = false,
        buttonB: Bool = false,
        buttonX: Bool = false,
        buttonY: Bool = false,
        dpadUp: Bool = false,
        dpadDown: Bool = false,
        dpadLeft: Bool = false,
        dpadRight: Bool = false,
        leftStickClick: Bool = false,
        rightStickClick: Bool = false,
        touchX: Double = 0.0,
        touchY: Double = 0.0,
        isTouching: Bool = false,
        gyroPitch: Double = 0.0,
        gyroRoll: Double = 0.0,
        gyroYaw: Double = 0.0
    ) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.buttonX = buttonX
        self.buttonY = buttonY
        self.dpadUp = dpadUp
        self.dpadDown = dpadDown
        self.dpadLeft = dpadLeft
        self.dpadRight = dpadRight
        self.leftStickClick = leftStickClick
        self.rightStickClick = rightStickClick
        self.touchX = touchX
        self.touchY = touchY
        self.isTouching = isTouching
        self.gyroPitch = gyroPitch
        self.gyroRoll = gyroRoll
        self.gyroYaw = gyroYaw
    }
}
