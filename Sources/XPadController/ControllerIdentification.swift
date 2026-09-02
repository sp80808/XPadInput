import Foundation
import GameController

public extension ControllerKind {
    /// Classifies a connected controller from its advertised vendor and category.
    static func identify(_ controller: GCController) -> ControllerKind {
        identify(vendorName: controller.vendorName, productCategory: controller.productCategory)
    }

    static func identify(vendorName: String?, productCategory: String) -> ControllerKind {
        let identity = "\(vendorName ?? "") \(productCategory)".lowercased()
        if identity.contains("dualsense") || identity.contains("ps5") { return .dualSense }
        if identity.contains("dualshock") || identity.contains("ps4") { return .dualShock4 }
        if identity.contains("xbox") || identity.contains("microsoft") || identity.contains("xinput") || identity.contains("series x") || identity.contains("series s") || identity.contains("elite") { return .xbox }
        if identity.contains("switch") || identity.contains("pro controller") || identity.contains("joy-con") { return .switchPro }
        if identity.contains("steam") { return .steamDeck }
        return ControllerVendorDatabase.classify(vendorName: vendorName, productCategory: productCategory)
    }
}
