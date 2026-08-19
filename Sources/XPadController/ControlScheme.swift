import Foundation
import XPadCore

// MARK: - Physical Control Binding

/// Describes how a single physical control is configured to drive a semantic musical action.
public struct PhysicalControlBinding: Codable, Sendable, Equatable, Hashable {
    public var input: PhysicalControlInput
    public var isInverted: Bool
    public var sensitivity: Float // 0.25 to 3.0 (1.0 = neutral)
    public var deadzoneOverride: Float?
    public var digitalBehavior: DigitalExpressionBehavior

    public init(
        input: PhysicalControlInput,
        isInverted: Bool = false,
        sensitivity: Float = 1.0,
        deadzoneOverride: Float? = nil,
        digitalBehavior: DigitalExpressionBehavior = .fixedFull
    ) {
        self.input = input
        self.isInverted = isInverted
        self.sensitivity = max(0.1, min(4.0, sensitivity))
        self.deadzoneOverride = deadzoneOverride
        self.digitalBehavior = digitalBehavior
    }

    public static func defaultBinding(for input: PhysicalControlInput) -> PhysicalControlBinding {
        PhysicalControlBinding(input: input)
    }
}

/// Fallback behavior when a continuous musical expression (e.g. pressure/pitch) is bound to a digital button.
public enum DigitalExpressionBehavior: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    case fixedFull = "Instant 100% Value"
    case fixedHalf = "Instant 50% Value"
    case linearRamp = "Smooth Ramp While Held"
    case stepped = "Cycle Stepped Levels (25% / 50% / 100%)"

    public var id: String { rawValue }
}

// MARK: - Musician-Facing Stick & Trigger Feel Profiles

/// Compact persisted values keep segmented controls width-safe while custom decoding
/// preserves compatibility with schemes saved before the UI-label cleanup.
public enum StickFeelPreset: String, Sendable, CaseIterable, Identifiable, Codable {
    case precise = "Precise"
    case balanced = "Balanced"
    case responsive = "Responsive"

    private static let legacyValues: [String: StickFeelPreset] = [
        "Precise (High resolution at center for vibrato & fine bends)": .precise,
        "Balanced (Natural linear response)": .balanced,
        "Responsive (Immediate output from small thumb movements)": .responsive,
    ]

    public var id: String { rawValue }
    public var shortName: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let preset = Self(rawValue: value) ?? Self.legacyValues[value] {
            self = preset
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unknown stick feel preset: \(value)"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var processingProfile: InputProcessingProfile {
        switch self {
        case .precise: return .precision
        case .balanced: return .expressive
        case .responsive: return .fast
        }
    }
}

/// Uses short stable labels for segmented controls. Legacy verbose values remain
/// decodable so existing custom control schemes are not invalidated by the UI fix.
public enum TriggerFeelPreset: String, Sendable, CaseIterable, Identifiable, Codable {
    case soft = "Soft"
    case linear = "Linear"
    case firm = "Firm"

    private static let legacyValues: [String: TriggerFeelPreset] = [
        "Soft (Light initial pull with rapid engagement)": .soft,
        "Linear (Proportional travel with predictable swell)": .linear,
        "Firm (Deep travel threshold for heavy expressive pressure)": .firm,
    ]

    public var id: String { rawValue }
    public var shortName: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let preset = Self(rawValue: value) ?? Self.legacyValues[value] {
            self = preset
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unknown trigger feel preset: \(value)"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var activationThreshold: Float {
        switch self {
        case .soft: return 0.04
        case .linear: return 0.08
        case .firm: return 0.16
        }
    }

    public var responseCurve: ResponseCurve {
        switch self {
        case .soft: return .aggressive
        case .linear: return .linear
        case .firm: return .precision
        }
    }
}

/// Compact menu labels prevent the haptics control from visually crowding or truncating
/// the settings card. Legacy verbose values remain decodable for saved schemes.
public enum HapticFeedbackIntensity: String, Sendable, CaseIterable, Identifiable, Codable {
    case off = "Off"
    case subtle = "Subtle"
    case normal = "Normal"

    private static let legacyValues: [String: HapticFeedbackIntensity] = [
        "Subtle (Sparse musical landmark pulses only)": .subtle,
        "Normal (Full tactile feedback for chords & bends)": .normal,
    ]

    public var id: String { rawValue }

    public var detail: String {
        switch self {
        case .off: return "No controller haptic feedback."
        case .subtle: return "Sparse pulses at useful musical landmarks."
        case .normal: return "Full tactile feedback for chords, bends and state changes."
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let intensity = Self(rawValue: value) ?? Self.legacyValues[value] {
            self = intensity
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unknown haptic feedback intensity: \(value)"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Control Scheme Model

/// A complete musician control scheme defining how physical gamepad hardware operates XPI.
public struct ControlScheme: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var isBuiltIn: Bool
    public var version: Int
    
    // Core Semantic Bindings
    public var bindings: [SemanticMusicalAction: PhysicalControlBinding]
    
    // Ergonomics & Feel
    public var stickFeel: StickFeelPreset
    public var triggerFeel: TriggerFeelPreset
    public var haptics: HapticFeedbackIntensity
    public var isMotionEnabled: Bool
    public var isLeftRightSwapped: Bool

    public init(
        id: String,
        name: String,
        description: String,
        isBuiltIn: Bool = false,
        version: Int = 1,
        bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:],
        stickFeel: StickFeelPreset = .balanced,
        triggerFeel: TriggerFeelPreset = .linear,
        haptics: HapticFeedbackIntensity = .normal,
        isMotionEnabled: Bool = true,
        isLeftRightSwapped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isBuiltIn = isBuiltIn
        self.version = version
        self.bindings = bindings
        self.stickFeel = stickFeel
        self.triggerFeel = triggerFeel
        self.haptics = haptics
        self.isMotionEnabled = isMotionEnabled
        self.isLeftRightSwapped = isLeftRightSwapped
    }

    /// Resolves the bound physical control for a given semantic action.
    public func binding(for action: SemanticMusicalAction) -> PhysicalControlBinding? {
        bindings[action]
    }

    /// Returns all semantic actions mapped to a specific physical input.
    public func actions(mappedTo input: PhysicalControlInput) -> [SemanticMusicalAction] {
        bindings.compactMap { action, binding in
            binding.input == input ? action : nil
        }
    }

    /// Creates an editable user copy from a built-in preset.
    public func makeCustomCopy(name: String? = nil) -> ControlScheme {
        var copy = self
        copy.id = "custom_" + UUID().uuidString.prefix(8).lowercased()
        copy.name = name ?? "\(self.name) (Custom)"
        copy.isBuiltIn = false
        copy.version = 1
        return copy
    }

    /// Musician-facing role for a physical control, based on the active bindings.
    public func roleLabel(for input: PhysicalControlInput) -> String? {
        let mapped = actions(mappedTo: input)
        let familyMapped = SemanticMusicalAction.allCases.filter { action in
            guard let bound = binding(for: action)?.input, bound != .unassigned else { return false }
            return bound == input || bound.overlapsHardware(with: input)
        }
        let names = (mapped.isEmpty ? familyMapped : mapped).map(\.displayName)
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        return unique.isEmpty ? nil : unique.joined(separator: " + ")
    }

    /// Overlay scheme-aware roles onto an instrument's default HUD copy.
    public func overlayHUDLabels(_ base: GestureHUDLabels) -> GestureHUDLabels {
        GestureHUDLabels(
            leftStick: roleLabel(for: .leftStick2D) ?? base.leftStick,
            rightStick: roleLabel(for: .rightStick2D)
                ?? roleLabel(for: .rightStickY)
                ?? roleLabel(for: .rightStickX)
                ?? base.rightStick,
            l1: roleLabel(for: .leftShoulder) ?? base.l1,
            r1: roleLabel(for: .rightShoulder) ?? base.r1,
            l2: roleLabel(for: .leftTrigger) ?? base.l2,
            r2: roleLabel(for: .rightTrigger) ?? base.r2,
            gyro: roleLabel(for: .motionPitch) ?? roleLabel(for: .motionRoll) ?? base.gyro,
            faceA: roleLabel(for: .buttonSouth) ?? base.faceA,
            faceX: roleLabel(for: .buttonWest) ?? base.faceX,
            faceY: roleLabel(for: .buttonNorth) ?? base.faceY,
            faceB: roleLabel(for: .buttonEast) ?? base.faceB
        )
    }

    public static let criticalActions: [SemanticMusicalAction] = [
        .primaryExcitation, .panic
    ]

    public static let recommendedActions: [SemanticMusicalAction] = [
        .harmonyNavigate2D, .pitchExpression, .dampingExpression, .pressureExpression
    ]

    /// Reports missing critical/recommended bindings and hardware that the current
    /// controller cannot actually deliver.
    public func coverageIssues(
        capabilities: ControllerCapabilityProfile? = nil
    ) -> [SchemeCoverageIssue] {
        var issues: [SchemeCoverageIssue] = []
        for action in Self.criticalActions {
            if binding(for: action)?.input == nil || binding(for: action)?.input == .unassigned {
                issues.append(SchemeCoverageIssue(
                    severity: .critical,
                    action: action,
                    message: "\(action.displayName) is unassigned. This scheme cannot perform or panic-stop safely."
                ))
            }
        }
        for action in Self.recommendedActions {
            if binding(for: action)?.input == nil || binding(for: action)?.input == .unassigned {
                issues.append(SchemeCoverageIssue(
                    severity: .contextualOverlap,
                    action: action,
                    message: "\(action.displayName) is unassigned. Consider mapping it for a complete playing surface."
                ))
            }
        }
        if let capabilities {
            for (action, binding) in bindings where binding.input != .unassigned {
                if let reason = binding.input.unavailableReason(given: capabilities) {
                    issues.append(SchemeCoverageIssue(
                        severity: .contextualOverlap,
                        action: action,
                        message: "\(action.displayName) is bound to \(binding.input.rawValue), but this controller has no \(reason)."
                    ))
                }
            }
        }
        return issues
    }
}

// MARK: - Conflict Detection

public struct MappingConflict: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let severity: Severity
    public let input: PhysicalControlInput
    public let actions: [SemanticMusicalAction]
    public let message: String

    public enum Severity: String, Sendable {
        case critical = "Critical Conflict"
        case contextualOverlap = "Contextual Overlap"
        case validShared = "Valid Shared Mapping"
    }

    public static func detectConflicts(in scheme: ControlScheme) -> [MappingConflict] {
        var inputToActions: [PhysicalControlInput: [SemanticMusicalAction]] = [:]
        for (action, binding) in scheme.bindings {
            guard binding.input != .unassigned else { continue }
            inputToActions[binding.input, default: []].append(action)
        }

        var conflicts: [MappingConflict] = []
        for (input, mappedActions) in inputToActions where mappedActions.count > 1 {
            conflicts.append(conflict(for: input, actions: mappedActions))
        }

        // Cross-binding overlap: 2D stick vs a dedicated axis on the same stick.
        let assigned = scheme.bindings.filter { $0.value.input != .unassigned }
        let actions = Array(assigned.keys)
        for i in 0..<actions.count {
            for j in (i + 1)..<actions.count {
                let a = actions[i]
                let b = actions[j]
                let inputA = assigned[a]!.input
                let inputB = assigned[b]!.input
                if inputA == inputB { continue }
                if inputA.isOrthogonalStickPair(with: inputB) { continue }
                guard inputA.overlapsHardware(with: inputB) else { continue }
                conflicts.append(conflict(for: inputA, actions: [a, b]))
            }
        }

        return conflicts
    }

    private static func conflict(
        for input: PhysicalControlInput,
        actions: [SemanticMusicalAction]
    ) -> MappingConflict {
        let hasPrimaryExcite = actions.contains(.primaryExcitation)
        let hasHarmonyNavigate = actions.contains(.harmonyNavigate2D)
        let hasPanic = actions.contains(.panic)

        if hasPrimaryExcite && hasHarmonyNavigate {
            return MappingConflict(
                severity: .critical,
                input: input,
                actions: actions,
                message: "Strum Excitation and Harmonic Wheel navigation cannot share the same thumbstick."
            )
        }
        if hasPanic && actions.count > 1 {
            return MappingConflict(
                severity: .critical,
                input: input,
                actions: actions,
                message: "MIDI Panic must have a dedicated button to prevent unintended silencing."
            )
        }
        return MappingConflict(
            severity: .contextualOverlap,
            input: input,
            actions: actions,
            message: "Multiple actions share this input (\(actions.map(\.displayName).joined(separator: ", "))). Ensure this is intentional."
        )
    }
}
