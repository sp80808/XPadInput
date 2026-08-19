import Foundation
import XPadCore

public enum ControlOccupancyGroup: String, Sendable, Equatable {
    case leftThumbPrimary
    case leftThumbAlternate
    case rightThumbPrimary
    case rightThumbAlternate
    case centralThumbReach
    case leftIndexUpper
    case leftIndexLower
    case rightIndexUpper
    case rightIndexLower
    case motion
    case other
}

public enum ErgonomicConflictKind: String, Sendable, Equatable {
    case none = "No conflict"
    case thumbTravel = "Thumb travel"
    case sameDigitSimultaneous = "Same-digit simultaneous conflict"
    case sustainedModifierLoad = "Sustained modifier load"
    case gripDependent = "Grip-profile dependent"
    case intentionalTradeoff = "Intentional tradeoff"
}

public struct ErgonomicWarning: Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: ErgonomicConflictKind
    public var message: String
    public var occupancy: [ControlOccupancyGroup]
    public var blocksSave: Bool

    public init(
        id: String,
        kind: ErgonomicConflictKind,
        message: String,
        occupancy: [ControlOccupancyGroup],
        blocksSave: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.occupancy = occupancy
        self.blocksSave = blocksSave
    }
}

public enum ErgonomicMappingAnalyzer {
    public static func occupancy(for input: PhysicalControlInput) -> ControlOccupancyGroup {
        switch input {
        case .leftStick2D, .leftStickX, .leftStickY, .leftStickClick:
            return .leftThumbPrimary
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight:
            return .leftThumbAlternate
        case .rightStick2D, .rightStickX, .rightStickY, .rightStickClick:
            return .rightThumbPrimary
        case .buttonSouth, .buttonEast, .buttonWest, .buttonNorth:
            return .rightThumbAlternate
        case .touchpad2D, .buttonCenter:
            return .centralThumbReach
        case .leftShoulder:
            return .leftIndexUpper
        case .leftTrigger:
            return .leftIndexLower
        case .rightShoulder:
            return .rightIndexUpper
        case .rightTrigger:
            return .rightIndexLower
        case .motionPitch, .motionRoll, .motionYaw:
            return .motion
        default:
            return .other
        }
    }

    public static func analyze(
        scheme: ControlScheme,
        grip: GripProfile,
        hasTouchpad: Bool
    ) -> [ErgonomicWarning] {
        var warnings: [ErgonomicWarning] = []
        let bound = scheme.bindings.filter { $0.value.input != .unassigned }

        let leftStick = bound.contains { occupancy(for: $0.value.input) == .leftThumbPrimary }
        let dpad = bound.contains { occupancy(for: $0.value.input) == .leftThumbAlternate }
        if leftStick && dpad {
            warnings.append(ErgonomicWarning(
                id: "left-thumb-travel",
                kind: .thumbTravel,
                message: "Left stick harmony and D-pad voicing compete for the left thumb. Sequential use is fine; avoid holding both.",
                occupancy: [.leftThumbPrimary, .leftThumbAlternate]
            ))
        }

        let rightStick = bound.contains { occupancy(for: $0.value.input) == .rightThumbPrimary }
        let face = bound.contains { occupancy(for: $0.value.input) == .rightThumbAlternate }
        if rightStick && face {
            warnings.append(ErgonomicWarning(
                id: "right-thumb-tradeoff",
                kind: scheme.isBuiltIn ? .intentionalTradeoff : .thumbTravel,
                message: scheme.isBuiltIn
                    ? "Factory guitar layout uses the right thumb for strum/bend and face-button voices sequentially, not simultaneously."
                    : "Right-stick expression and face-button voices share the right thumb. Prefer sequential use.",
                occupancy: [.rightThumbPrimary, .rightThumbAlternate]
            ))
        }

        let touch = bound.contains { $0.value.input == .touchpad2D }
        if touch && !hasTouchpad {
            warnings.append(ErgonomicWarning(
                id: "touchpad-missing",
                kind: .gripDependent,
                message: "Touchpad expression is mapped but this controller has no touchpad.",
                occupancy: [.centralThumbReach]
            ))
        } else if touch && rightStick {
            warnings.append(ErgonomicWarning(
                id: "touchpad-right-stick",
                kind: .sameDigitSimultaneous,
                message: "Right-stick precision and central touchpad compete for the same thumb. Keep touchpad as an optional alternate, not a simultaneous default.",
                occupancy: [.rightThumbPrimary, .centralThumbReach]
            ))
        }

        let leftUpper = bound.contains { occupancy(for: $0.value.input) == .leftIndexUpper }
        let leftLower = bound.contains { occupancy(for: $0.value.input) == .leftIndexLower }
        if leftUpper && leftLower && grip == .standardTwoIndex {
            warnings.append(ErgonomicWarning(
                id: "left-index-hold",
                kind: .sustainedModifierLoad,
                message: "L1 and L2 are both mapped. Under a two-index grip, avoid long simultaneous holds.",
                occupancy: [.leftIndexUpper, .leftIndexLower]
            ))
        }

        let rightUpper = bound.contains { occupancy(for: $0.value.input) == .rightIndexUpper }
        let rightLower = bound.contains { occupancy(for: $0.value.input) == .rightIndexLower }
        if rightUpper && rightLower && grip == .standardTwoIndex {
            warnings.append(ErgonomicWarning(
                id: "right-index-hold",
                kind: .sustainedModifierLoad,
                message: "R1 and R2 are both mapped. Under a two-index grip, avoid long simultaneous holds.",
                occupancy: [.rightIndexUpper, .rightIndexLower]
            ))
        }

        if grip == .oneHanded {
            let left = bound.contains { occupancy(for: $0.value.input) == .leftThumbPrimary || occupancy(for: $0.value.input) == .leftIndexUpper }
            let right = bound.contains { occupancy(for: $0.value.input) == .rightThumbPrimary || occupancy(for: $0.value.input) == .rightIndexUpper }
            if left && right {
                warnings.append(ErgonomicWarning(
                    id: "one-hand-opposite",
                    kind: .gripDependent,
                    message: "One-handed / assistive grip cannot comfortably use opposite-side controls at the same time.",
                    occupancy: [.leftThumbPrimary, .rightThumbPrimary]
                ))
            }
        }

        return warnings
    }
}
