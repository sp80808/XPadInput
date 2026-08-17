import Foundation
import GameController
import XPadCore

enum ControllerTouchpadReader {
    static func read(
        from controller: GCController,
        hasTouchpad: Bool,
        enabled: Bool
    ) -> (x: Float, y: Float, surface: Bool, button: Bool) {
        guard hasTouchpad, enabled else {
            return (0, 0, false, false)
        }

        var buttonPressed = false
        if let dualSense = controller.extendedGamepad as? GCDualSenseGamepad {
            buttonPressed = dualSense.touchpadButton.isPressed
        } else if let dualShock = controller.extendedGamepad as? GCDualShockGamepad {
            buttonPressed = dualShock.touchpadButton.isPressed
            let pad = dualShock.touchpadPrimary
            let x = pad.xAxis.value
            let y = pad.yAxis.value
            let surface = hypot(x, y) > 0.02
            return (x, y, surface, buttonPressed)
        }

        if let surface = firstTouchSurface(in: controller.physicalInputProfile) {
            return (surface.x, surface.y, surface.active, buttonPressed)
        }
        return (0, 0, false, buttonPressed)
    }

    private static func firstTouchSurface(in profile: GCPhysicalInputProfile) -> (x: Float, y: Float, active: Bool)? {
        for (name, element) in profile.elements {
            let folded = name.lowercased()
            guard folded.contains("touch") else { continue }
            if let dpad = element as? GCControllerDirectionPad {
                let x = dpad.xAxis.value
                let y = dpad.yAxis.value
                return (x, y, hypot(x, y) > 0.02)
            }
        }
        return nil
    }
}

enum ControllerRemapCapture {
    static let watchedAliases = [
        ControllerRemapResolver.southAlias,
        ControllerRemapResolver.eastAlias,
        ControllerRemapResolver.westAlias,
        ControllerRemapResolver.northAlias,
        "Left Shoulder",
        "Right Shoulder",
        "Left Trigger",
        "Right Trigger"
    ]

    static func snapshot(from controller: GCController) -> ControllerRemapSnapshot {
        let profile = controller.physicalInputProfile
        var names: [String: String] = [:]
        if profile.hasRemappedElements {
            for alias in watchedAliases {
                if let physical = profile.mappedPhysicalInputNames(forElementAlias: alias).first {
                    names[alias] = physical
                }
            }
        }

        var analog: [PhysicalControlInput: Float] = [:]
        if let gamepad = controller.extendedGamepad {
            analog[.buttonSouth] = analogValue(gamepad.buttonA)
            analog[.buttonEast] = analogValue(gamepad.buttonB)
            analog[.buttonWest] = analogValue(gamepad.buttonX)
            analog[.buttonNorth] = analogValue(gamepad.buttonY)
            analog[.leftShoulder] = analogValue(gamepad.leftShoulder)
            analog[.rightShoulder] = analogValue(gamepad.rightShoulder)
            analog[.leftTrigger] = gamepad.leftTrigger.value
            analog[.rightTrigger] = gamepad.rightTrigger.value
        }

        return ControllerRemapSnapshot(
            hasRemappedElements: profile.hasRemappedElements,
            physicalNameByAlias: names,
            analogByInput: analog
        )
    }

    static func analogValue(_ button: GCControllerButtonInput) -> Float {
        button.isAnalog ? button.value : (button.isPressed ? 1 : 0)
    }
}
