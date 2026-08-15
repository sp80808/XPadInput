import Foundation
import GameController

/// Describes the capabilities of a connected controller.
struct ControllerCapabilityProfile: Sendable {
    let name: String
    let vendorName: String?
    let productCategory: String?
    
    var hasLeftStick: Bool = false
    var hasRightStick: Bool = false
    var hasDpad: Bool = false
    var hasFaceButtons: Bool = false
    var hasShoulders: Bool = false
    var hasTriggers: Bool = false
    var hasStickButtons: Bool = false
    var hasTouchpad: Bool = false
    var hasGyroscope: Bool = false
    var hasAccelerometer: Bool = false
    var hasHaptics: Bool = false
    var hasAdaptiveTriggers: Bool = false
    
    /// Identify controller type for display purposes
    var controllerType: ControllerType {
        guard let vendorName = vendorName?.lowercased() ?? productCategory?.lowercased() else {
            return .generic
        }
        
        if vendorName.contains("dualsense") || vendorName.contains("ps5") {
            return .dualSense
        } else if vendorName.contains("dualshock") || vendorName.contains("ps4") {
            return .dualShock4
        } else if vendorName.contains("xbox") {
            return .xbox
        } else if vendorName.contains("switch") || vendorName.contains("pro controller") {
            return .switchPro
        }
        
        return .generic
    }
    
    /// Create profile from a connected GCController
    static func from(_ controller: GCController) -> ControllerCapabilityProfile {
        var profile = ControllerCapabilityProfile(
            name: controller.vendorName ?? "Unknown Controller",
            vendorName: controller.vendorName,
            productCategory: controller.productCategory
        )
        
        if let gamepad = controller.extendedGamepad {
            profile.hasLeftStick = true
            profile.hasRightStick = true
            profile.hasDpad = true
            profile.hasFaceButtons = true
            profile.hasShoulders = true
            profile.hasTriggers = true
            profile.hasStickButtons = true
            
            // Check for DualSense/DualShock specific features
            // Touchpad detection
            if controller.physicalInputProfile.buttons["Touchpad Button"] != nil {
                profile.hasTouchpad = true
            }
            
            // Haptics
            if controller.haptics != nil {
                profile.hasHaptics = true
            }
            
            _ = gamepad // Suppress unused warning
        }
        
        // Motion
        if controller.motion != nil {
            profile.hasGyroscope = true
            profile.hasAccelerometer = true
            profile.hasMotion = true
        }
        
        return profile
    }
    
    var hasMotion: Bool {
        hasGyroscope || hasAccelerometer
    }
    
    var capabilitySummary: String {
        var caps: [String] = []
        if hasLeftStick { caps.append("L Stick") }
        if hasRightStick { caps.append("R Stick") }
        if hasDpad { caps.append("D-pad") }
        if hasFaceButtons { caps.append("Buttons") }
        if hasShoulders { caps.append("Shoulders") }
        if hasTriggers { caps.append("Triggers") }
        if hasTouchpad { caps.append("Touchpad") }
        if hasGyroscope { caps.append("Gyro") }
        if hasAccelerometer { caps.append("Accel") }
        if hasHaptics { caps.append("Haptics") }
        return caps.joined(separator: " · ")
    }
}

/// Controller hardware types
enum ControllerType: String, Sendable {
    case dualSense = "DualSense"
    case dualShock4 = "DualShock 4"
    case xbox = "Xbox"
    case switchPro = "Switch Pro"
    case guitarHero = "Guitar Hero"
    case soundVoltex = "Sound Voltex"
    case beatmaniaIIDX = "Beatmania IIDX"
    case taikoDrum = "Taiko Drum"
    case flightStick = "Flight HOTAS"
    case racingWheel = "Racing Wheel"
    case fightStick = "Arcade Fight Stick"
    case generic = "Gamepad"
    
    var sfSymbol: String {
        switch self {
        case .dualSense, .dualShock4, .xbox, .switchPro: return "gamecontroller.fill"
        case .guitarHero: return "guitars.fill"
        case .soundVoltex: return "dial.low.fill"
        case .beatmaniaIIDX: return "opticaldisc.fill"
        case .taikoDrum: return "circle.circle.fill"
        case .flightStick: return "airplane"
        case .racingWheel: return "steeringwheel"
        case .fightStick: return "circle.grid.3x3.fill"
        case .generic: return "gamecontroller"
        }
    }
}
