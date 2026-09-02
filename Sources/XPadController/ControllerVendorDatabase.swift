import Foundation

/// Ordered, case-insensitive substring rule table for identifying third-party,
/// rhythm, and semi-niche controller hardware from advertised vendor/product
/// strings. Scanned top-to-bottom; the first matching rule wins, so more
/// specific entries must precede broader ones. Consulted only after the
/// first-party checks in `ControllerKind.identify` fail to match.
public enum ControllerVendorDatabase {

    private struct VendorRule: Sendable {
        /// Lowercase substrings; the rule matches when the identity contains any of these.
        var keywords: [String]
        /// When non-empty, at least one of these must ALSO match (AND-group).
        var alsoRequired: [String] = []
        var kind: ControllerKind

        func matches(_ identity: String) -> Bool {
            guard keywords.contains(where: { identity.contains($0) }) else { return false }
            if alsoRequired.isEmpty { return true }
            return alsoRequired.contains(where: { identity.contains($0) })
        }
    }

    // MARK: - Ordered Rule Table (most specific first)

    private static let rules: [VendorRule] = [
        // MARK: Rhythm Controllers

        VendorRule(keywords: ["guitar hero", "rock band", "raphnet", "riffmaster", "pdp riff", "guitarpad"],
                   kind: .guitarHero),
        VendorRule(keywords: ["sound voltex", "pocket voltex", "voltex", "sdvx"],
                   kind: .soundVoltex),
        VendorRule(keywords: ["beatmania", "iidx", "dj dao", "djdao"],
                   kind: .beatmaniaIIDX),
        VendorRule(keywords: ["pop'n", "popn music", "popn"],
                   kind: .popnMusic),
        VendorRule(keywords: ["taiko", "tatsujin", "tatacon", "hori tac"],
                   kind: .taikoDrum),
        VendorRule(keywords: ["dance mat", "dancemat", "stage pad", "stagepad", "ddr"],
                   kind: .danceMat),

        // MARK: Niche — Flight

        VendorRule(keywords: ["hotas", "t.flight", "warthog", "extreme 3d", "x52", "x56",
                              "vkb", "vpc", "ch products", "flightstick", "flight stick", "flight", "throttle", "yoke"],
                   kind: .flightStick),

        // MARK: Niche — Racing

        VendorRule(keywords: ["driving force", "g29", "g923", "g920", "t300rs", "t248", "tmx",
                              "fanatec", "moza", "wheel base", "sim racing",
                              "logitech wheel", "thrustmaster wheel"],
                   kind: .racingWheel),

        // MARK: Niche — Arcade / Fight

        VendorRule(keywords: ["fight stick", "fighting stick", "fightstick", "arcade stick", "qanba",
                              "victrix", "mayflash f300", "mayflash f500", "hit box", "hitbox",
                              "leverless", "mixbox", "mad catz te", "razer atrox", "hori rap"],
                   kind: .fightStick),

        // MARK: Standard Third-Party Pads

        VendorRule(keywords: ["8bitdo"], alsoRequired: ["nintendo", "switch"],
                   kind: .switchPro),
        VendorRule(keywords: ["8bitdo"],
                   kind: .generic),
        VendorRule(keywords: ["backbone one", "razer kishi", "gamesir", "flydigi",
                              "steelseries nimbus", "steelseries stratus", "powera", "nacon",
                              "wolverine", "raiju", "onside"],
                   kind: .generic),
    ]

    /// Classifies hardware from its advertised vendor name (optional) and
    /// product category string. Matching is case-insensitive over the
    /// lowercased "vendor + category" concatenation. Returns `.generic` when
    /// no rule matches.
    public static func classify(vendorName: String?, productCategory: String) -> ControllerKind {
        let identity = "\(vendorName ?? "") \(productCategory)".lowercased()
        for rule in rules where rule.matches(identity) {
            return rule.kind
        }
        return .generic
    }
}

public extension ControllerKind {
    /// Recommended built-in scheme id for this hardware family.
    var suggestedSchemeID: String {
        switch self {
        case .dualSense, .dualShock4, .xbox, .switchPro, .steamDeck, .generic, .simulated:
            return "xpi_performance"
        case .guitarHero, .soundVoltex, .beatmaniaIIDX, .popnMusic, .taikoDrum, .danceMat:
            return "xpi_rhythm_pad"
        case .fightStick:
            return "xpi_arcade_stick"
        case .racingWheel:
            return "xpi_racing_wheel"
        case .flightStick:
            return "xpi_flight_deck"
        }
    }
}
