import Foundation
import GameController
import XPadCore

public enum ControllerKind: String, Codable, CaseIterable, Sendable, Identifiable {
    public var id: String { rawValue }

    // Standard Gamepads
    case dualSense = "Sony DualSense (PS5)"
    case dualShock4 = "Sony DualShock 4 (PS4)"
    case xbox = "Xbox Wireless Controller"
    case switchPro = "Nintendo Switch Pro"
    case steamDeck = "Steam Deck / Steam Controller"
    case generic = "Extended Gamepad"
    case simulated = "Virtual / Keyboard Controller"

    // Rhythm Game Controllers
    case guitarHero = "Guitar Hero / Rock Band Guitar"
    case soundVoltex = "Sound Voltex (SDVX) Controller"
    case beatmaniaIIDX = "Beatmania IIDX / DJ DAO Controller"
    case popnMusic = "Pop'n Music 9-Button Arcade"
    case taikoDrum = "Taiko no Tatsujin Drum (Tatacon)"
    case danceMat = "Dance Mat / DDR Stage Pad"

    // Semi-Niche Control Inputs
    case flightStick = "Flight Sim HOTAS & Flight Stick"
    case racingWheel = "Racing Wheel & Pedals"
    case fightStick = "Arcade Fight Stick / Leverless"

    public var category: ControllerCategory {
        switch self {
        case .dualSense, .dualShock4, .xbox, .switchPro, .steamDeck, .generic, .simulated:
            return .standard
        case .guitarHero, .soundVoltex, .beatmaniaIIDX, .popnMusic, .taikoDrum, .danceMat:
            return .rhythm
        case .flightStick, .racingWheel, .fightStick:
            return .niche
        }
    }

    public var iconPack: ControllerIconPack {
        switch self {
        case .dualSense, .dualShock4:
            return .playStation
        case .xbox:
            return .xbox
        case .switchPro:
            return .nintendoSwitch
        case .guitarHero:
            return .guitarHero
        case .beatmaniaIIDX:
            return .beatmaniaIIDX
        case .soundVoltex:
            return .soundVoltex
        case .popnMusic:
            return .popnMusic
        case .taikoDrum:
            return .taikoDrum
        case .danceMat:
            return .danceMat
        case .flightStick:
            return .flightStick
        case .racingWheel:
            return .racingWheel
        case .fightStick:
            return .fightStick
        default:
            return .playStation
        }
    }
}

public enum ControllerCategory: String, Codable, CaseIterable, Sendable {
    case standard = "Standard Gamepads"
    case rhythm = "Rhythm Game Controllers"
    case niche = "Flight & Racing & Arcade"
}

public struct ControllerCapabilityProfile: Codable, Sendable {
    public var hasTouchpad: Bool
    public var hasMotionIMU: Bool
    public var hasHaptics: Bool
    public var hasAnalogTriggers: Bool
    public var hasThumbstickClicks: Bool
    public var hasRotaryEncoders: Bool
    public var hasTurntable: Bool
    public var hasFrets: Bool
    public var hasThrottle: Bool
    public var hasRudderPedals: Bool
    public var hasArcadeButtons: Bool
    public var hasDancePads: Bool
    public var buttonLabels: [String]

    public init(
        hasTouchpad: Bool = false,
        hasMotionIMU: Bool = false,
        hasHaptics: Bool = false,
        hasAnalogTriggers: Bool = false,
        hasThumbstickClicks: Bool = false,
        hasRotaryEncoders: Bool = false,
        hasTurntable: Bool = false,
        hasFrets: Bool = false,
        hasThrottle: Bool = false,
        hasRudderPedals: Bool = false,
        hasArcadeButtons: Bool = false,
        hasDancePads: Bool = false,
        buttonLabels: [String] = []
    ) {
        self.hasTouchpad = hasTouchpad
        self.hasMotionIMU = hasMotionIMU
        self.hasHaptics = hasHaptics
        self.hasAnalogTriggers = hasAnalogTriggers
        self.hasThumbstickClicks = hasThumbstickClicks
        self.hasRotaryEncoders = hasRotaryEncoders
        self.hasTurntable = hasTurntable
        self.hasFrets = hasFrets
        self.hasThrottle = hasThrottle
        self.hasRudderPedals = hasRudderPedals
        self.hasArcadeButtons = hasArcadeButtons
        self.hasDancePads = hasDancePads
        self.buttonLabels = buttonLabels
    }

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

    public static let steamDeck = ControllerCapabilityProfile(
        hasTouchpad: true,
        hasMotionIMU: true,
        hasHaptics: true,
        hasAnalogTriggers: true,
        hasThumbstickClicks: true,
        buttonLabels: ["A", "B", "X", "Y", "L4", "L5", "R4", "R5"]
    )

    public static let guitarHero = ControllerCapabilityProfile(
        hasAnalogTriggers: true,
        hasFrets: true,
        buttonLabels: ["Green Fret", "Red Fret", "Yellow Fret", "Blue Fret", "Orange Fret", "Strum Up", "Strum Down", "Whammy"]
    )

    public static let soundVoltex = ControllerCapabilityProfile(
        hasRotaryEncoders: true,
        hasArcadeButtons: true,
        buttonLabels: ["VOL-L (Cyan)", "VOL-R (Pink)", "BT-A", "BT-B", "BT-C", "BT-D", "FX-L", "FX-R"]
    )

    public static let beatmaniaIIDX = ControllerCapabilityProfile(
        hasTurntable: true,
        hasArcadeButtons: true,
        buttonLabels: ["Turntable Scratch", "Key 1", "Key 2", "Key 3", "Key 4", "Key 5", "Key 6", "Key 7"]
    )

    public static let popnMusic = ControllerCapabilityProfile(
        hasArcadeButtons: true,
        buttonLabels: ["W1", "Y1", "G1", "B1", "Red", "B2", "G2", "Y2", "W2"]
    )

    public static let taikoDrum = ControllerCapabilityProfile(
        buttonLabels: ["Don Left", "Don Right", "Ka Left", "Ka Right"]
    )

    public static let danceMat = ControllerCapabilityProfile(
        hasDancePads: true,
        buttonLabels: ["Left Arrow", "Down Arrow", "Up Arrow", "Right Arrow"]
    )

    public static let flightStick = ControllerCapabilityProfile(
        hasAnalogTriggers: true,
        hasThrottle: true,
        hasRudderPedals: true,
        buttonLabels: ["Pitch", "Roll", "Z-Twist", "POV Hat", "Trigger", "Throttle Lever"]
    )

    public static let racingWheel = ControllerCapabilityProfile(
        hasAnalogTriggers: true,
        hasRudderPedals: true,
        buttonLabels: ["900° Wheel Angle", "Paddle Left", "Paddle Right", "Gas Pedal", "Brake Pedal", "Clutch"]
    )

    public static let fightStick = ControllerCapabilityProfile(
        hasArcadeButtons: true,
        buttonLabels: ["Sanwa Stick", "LP", "MP", "HP", "LK", "MK", "HK", "Jump"]
    )

    public static let generic = ControllerCapabilityProfile(
        hasTouchpad: false,
        hasMotionIMU: false,
        hasHaptics: false,
        hasAnalogTriggers: true,
        hasThumbstickClicks: true,
        buttonLabels: ["A", "B", "X", "Y"]
    )

    public static func from(_ controller: GCController) -> ControllerCapabilityProfile {
        let name = controller.vendorName?.lowercased() ?? controller.productCategory.lowercased()
        if name.contains("dualsense") || name.contains("ps5") {
            return .dualSense
        } else if name.contains("dualshock") || name.contains("ps4") {
            return .dualSense
        } else if name.contains("xbox") {
            return .xbox
        } else if name.contains("switch") || name.contains("pro controller") {
            return .switchPro
        } else if name.contains("steam") {
            return .steamDeck
        }
        return .generic
    }
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
    public var leftStick: ProcessedStickState
    public var rightStick: ProcessedStickState

    // Triggers (0.0 to 1.0)
    public var leftTrigger: ProcessedTriggerState
    public var rightTrigger: ProcessedTriggerState

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

    // Rhythm & Niche Specific Continuous & Discrete Inputs
    public var encoderL: Double // SDVX Left Knob (-1.0 to 1.0 or angle)
    public var encoderR: Double // SDVX Right Knob (-1.0 to 1.0 or angle)
    public var turntableVelocity: Double // Beatmania DJ scratch velocity (-1.0 to 1.0)
    public var whammy: Double // Guitar Hero Whammy (0.0 to 1.0)
    public var tiltSensor: Double // Guitar Hero Star Power tilt (0.0 to 1.0)
    public var throttle: Double // Flight Sim Throttle (0.0 to 1.0)
    public var rudderTwist: Double // Flight Sim Z-Twist (-1.0 to 1.0)
    public var wheelAngle: Double // Racing Wheel Angle (-1.0 to 1.0)
    public var pedalBrake: Double // Brake (0.0 to 1.0)
    public var pedalGas: Double // Gas (0.0 to 1.0)
    public var pedalClutch: Double // Clutch (0.0 to 1.0)

    // Extra arcade & rhythm button states
    public var fret1: Bool // Green
    public var fret2: Bool // Red
    public var fret3: Bool // Yellow
    public var fret4: Bool // Blue
    public var fret5: Bool // Orange
    public var strumUp: Bool
    public var strumDown: Bool

    public var extraButtons: [String: Bool]

    public init(
        leftStick: ProcessedStickState = ProcessedStickState(),
        rightStick: ProcessedStickState = ProcessedStickState(),
        leftTrigger: ProcessedTriggerState = ProcessedTriggerState(),
        rightTrigger: ProcessedTriggerState = ProcessedTriggerState(),
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
        gyroYaw: Double = 0.0,
        encoderL: Double = 0.0,
        encoderR: Double = 0.0,
        turntableVelocity: Double = 0.0,
        whammy: Double = 0.0,
        tiltSensor: Double = 0.0,
        throttle: Double = 0.0,
        rudderTwist: Double = 0.0,
        wheelAngle: Double = 0.0,
        pedalBrake: Double = 0.0,
        pedalGas: Double = 0.0,
        pedalClutch: Double = 0.0,
        fret1: Bool = false,
        fret2: Bool = false,
        fret3: Bool = false,
        fret4: Bool = false,
        fret5: Bool = false,
        strumUp: Bool = false,
        strumDown: Bool = false,
        extraButtons: [String: Bool] = [:]
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
        self.encoderL = encoderL
        self.encoderR = encoderR
        self.turntableVelocity = turntableVelocity
        self.whammy = whammy
        self.tiltSensor = tiltSensor
        self.throttle = throttle
        self.rudderTwist = rudderTwist
        self.wheelAngle = wheelAngle
        self.pedalBrake = pedalBrake
        self.pedalGas = pedalGas
        self.pedalClutch = pedalClutch
        self.fret1 = fret1
        self.fret2 = fret2
        self.fret3 = fret3
        self.fret4 = fret4
        self.fret5 = fret5
        self.strumUp = strumUp
        self.strumDown = strumDown
        self.extraButtons = extraButtons
    }

    /// Check if any modifier button is held
    public var activeModifier: ControllerModifier {
        if leftShoulder && rightShoulder { return .bothShoulders }
        if leftShoulder { return .leftShoulder }
        if rightShoulder { return .rightShoulder }
        if leftTrigger.value > 0.5 { return .leftTrigger }
        if rightTrigger.value > 0.5 { return .rightTrigger }
        return .none
    }
}

public enum ControllerModifier: String, CaseIterable, Codable, Sendable {
    case none = "Normal"
    case leftShoulder = "L1 — Colour"
    case rightShoulder = "R1 — Rhythm"
    case leftTrigger = "L2 — Expression"
    case rightTrigger = "R2 — Variation"
    case bothShoulders = "L1+R1 — Arrange"
}

/// Real-time observable state of a connected controller
@Observable
public final class ControllerState: @unchecked Sendable {
    public var leftStick: ProcessedStickState = ProcessedStickState()
    public var rightStick: ProcessedStickState = ProcessedStickState()
    
    public var leftTrigger: ProcessedTriggerState = ProcessedTriggerState()
    public var rightTrigger: ProcessedTriggerState = ProcessedTriggerState()
    
    public var leftShoulder: Bool = false
    public var rightShoulder: Bool = false
    
    public var buttonA: Bool = false
    public var buttonB: Bool = false
    public var buttonX: Bool = false
    public var buttonY: Bool = false
    
    public var dpadUp: Bool = false
    public var dpadDown: Bool = false
    public var dpadLeft: Bool = false
    public var dpadRight: Bool = false
    
    public var leftStickButton: Bool = false
    public var rightStickButton: Bool = false
    
    public var menuButton: Bool = false
    public var optionsButton: Bool = false
    
    public var touchpadX: Float = 0
    public var touchpadY: Float = 0
    public var touchpadActive: Bool = false
    
    public var gyroX: Double = 0
    public var gyroY: Double = 0
    public var gyroZ: Double = 0
    public var accelX: Double = 0
    public var accelY: Double = 0
    public var accelZ: Double = 0
    public var hasMotion: Bool = false
    
    public init() {}
    
    public var leftStickAngle: Double {
        leftStick.angle
    }
    
    public var leftStickMagnitude: Double {
        Double(leftStick.radius)
    }
    
    public var rightStickAngle: Double {
        rightStick.angle
    }
    
    public var rightStickMagnitude: Double {
        Double(rightStick.radius)
    }
    
    public var activeModifier: ControllerModifier {
        if leftShoulder && rightShoulder { return .bothShoulders }
        if leftShoulder { return .leftShoulder }
        if rightShoulder { return .rightShoulder }
        if leftTrigger.value > 0.5 { return .leftTrigger }
        if rightTrigger.value > 0.5 { return .rightTrigger }
        return .none
    }
}
