import Foundation
import GameController

/// Describes the capabilities of a connected controller.
public struct ControllerCapabilityProfile: Sendable {
    public let name: String
    public let vendorName: String?
    public let productCategory: String?
    
    public var hasLeftStick: Bool = false
    public var hasRightStick: Bool = false
    public var hasDpad: Bool = false
    public var hasFaceButtons: Bool = false
    public var hasShoulders: Bool = false
    public var hasTriggers: Bool = false
    public var hasStickButtons: Bool = false
    public var hasTouchpad: Bool = false
    public var hasGyroscope: Bool = false
    public var hasAccelerometer: Bool = false
    public var hasHaptics: Bool = false
    public var hasAdaptiveTriggers: Bool = false
    
    public init(name: String, vendorName: String? = nil, productCategory: String? = nil) {
        self.name = name
        self.vendorName = vendorName
        self.productCategory = productCategory
    }
    
    /// Identify controller type for display purposes
    public var controllerType: ControllerType {
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
    public static func from(_ controller: GCController) -> ControllerCapabilityProfile {
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
        }
        
        return profile
    }
    
    public var hasMotion: Bool {
        hasGyroscope || hasAccelerometer
    }
    
    public var capabilitySummary: String {
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
public enum ControllerType: String, Sendable {
    case dualSense = "DualSense"
    case dualShock4 = "DualShock 4"
    case xbox = "Xbox"
    case switchPro = "Switch Pro"
    case generic = "Gamepad"
    
    public var sfSymbol: String {
        switch self {
        case .dualSense, .dualShock4: return "gamecontroller.fill"
        case .xbox: return "gamecontroller.fill"
        case .switchPro: return "gamecontroller.fill"
        case .generic: return "gamecontroller"
        }
    }
}
