import Foundation
import XPadCore

/// Maps Game Controller physical names through user remapping onto XPI inputs and glyphs.
public struct ControllerRemapSnapshot: Sendable, Equatable {
    public var hasRemappedElements: Bool
    /// Logical alias (e.g. `Button A`) → physical input name currently producing it.
    public var physicalNameByAlias: [String: String]
    public var analogByInput: [PhysicalControlInput: Float]

    public init(
        hasRemappedElements: Bool = false,
        physicalNameByAlias: [String: String] = [:],
        analogByInput: [PhysicalControlInput: Float] = [:]
    ) {
        self.hasRemappedElements = hasRemappedElements
        self.physicalNameByAlias = physicalNameByAlias
        self.analogByInput = analogByInput
    }
}

public enum ControllerRemapResolver {
    public static let southAlias = "Button A"
    public static let eastAlias = "Button B"
    public static let westAlias = "Button X"
    public static let northAlias = "Button Y"

    public static func physicalInput(named name: String) -> PhysicalControlInput? {
        let folded = name.lowercased()
        if folded.contains("button a") || folded.contains("cross") { return .buttonSouth }
        if folded.contains("button b") || folded.contains("circle") { return .buttonEast }
        if folded.contains("button x") || folded.contains("square") { return .buttonWest }
        if folded.contains("button y") || folded.contains("triangle") { return .buttonNorth }
        if folded.contains("left shoulder") || folded.contains("l1") || folded.contains("lb") { return .leftShoulder }
        if folded.contains("right shoulder") || folded.contains("r1") || folded.contains("rb") { return .rightShoulder }
        if folded.contains("left trigger") || folded.contains("l2") || folded.contains("lt") { return .leftTrigger }
        if folded.contains("right trigger") || folded.contains("r2") || folded.contains("rt") { return .rightTrigger }
        return nil
    }

    /// The physical control the player must actually press for a logical XPI face button.
    public static func displayedInput(
        for logical: PhysicalControlInput,
        snapshot: ControllerRemapSnapshot
    ) -> PhysicalControlInput {
        let alias: String
        switch logical {
        case .buttonSouth: alias = southAlias
        case .buttonEast: alias = eastAlias
        case .buttonWest: alias = westAlias
        case .buttonNorth: alias = northAlias
        default: return logical
        }
        guard let physicalName = snapshot.physicalNameByAlias[alias],
              let mapped = physicalInput(named: physicalName) else {
            return logical
        }
        return mapped
    }

    public static func analogValue(
        for input: PhysicalControlInput,
        snapshot: ControllerRemapSnapshot,
        digitalPressed: Bool
    ) -> Float {
        if let analog = snapshot.analogByInput[input] { return analog }
        return digitalPressed ? 1 : 0
    }
}
