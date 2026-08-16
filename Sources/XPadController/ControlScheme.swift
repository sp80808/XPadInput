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
public enum DigitalExpressionBehavior: String, Codable, Sendable, CaseIterable, Identifiable {
    case fixedFull = "Instant 100% Value"
    case fixedHalf = "Instant 50% Value"
    case linearRamp = "Smooth Ramp While Held"
    case stepped = "Cycle Stepped Levels (25% / 50% / 100%)"

    public var id: String { rawValue }
}

// MARK: - Musician-Facing Stick & Trigger Feel Profiles

public enum StickFeelPreset: String, Codable, Sendable, CaseIterable, Identifiable {
    case precise = "Precise (High resolution at center for vibrato & fine bends)"
    case balanced = "Balanced (Natural linear response)"
    case responsive = "Responsive (Immediate output from small thumb movements)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .precise: return "Precise"
        case .balanced: return "Balanced"
        case .responsive: return "Responsive"
        }
    }

    public var processingProfile: InputProcessingProfile {
        switch self {
        case .precise: return .precision
        case .balanced: return .expressive
        case .responsive: return .fast
        }
    }
}

public enum TriggerFeelPreset: String, Codable, Sendable, CaseIterable, Identifiable {
    case soft = "Soft (Light initial pull with rapid engagement)"
    case linear = "Linear (Proportional travel with predictable swell)"
    case firm = "Firm (Deep travel threshold for heavy expressive pressure)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .soft: return "Soft"
        case .linear: return "Linear"
        case .firm: return "Firm"
        }
    }

    public var activationThreshold: Float {
        switch self {
        case .soft: return 0.04
        case .linear: return 0.08
        case .firm: return 0.16
        }
    }
}

public enum HapticFeedbackIntensity: String, Codable, Sendable, CaseIterable, Identifiable {
    case off = "Off"
    case subtle = "Subtle (Sparse musical landmark pulses only)"
    case normal = "Normal (Full tactile feedback for chords & bends)"

    public var id: String { rawValue }
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
            // Check for mutually exclusive actions mapped to the exact same button/axis
            let hasPrimaryExcite = mappedActions.contains(.primaryExcitation)
            let hasHarmonyNavigate = mappedActions.contains(.harmonyNavigate2D)
            let hasPanic = mappedActions.contains(.panic)

            if hasPrimaryExcite && hasHarmonyNavigate {
                conflicts.append(MappingConflict(
                    severity: .critical,
                    input: input,
                    actions: mappedActions,
                    message: "Strum Excitation and Harmonic Wheel navigation cannot share the same thumbstick."
                ))
            } else if hasPanic && mappedActions.count > 1 {
                conflicts.append(MappingConflict(
                    severity: .critical,
                    input: input,
                    actions: mappedActions,
                    message: "MIDI Panic must have a dedicated button to prevent unintended silencing."
                ))
            } else {
                conflicts.append(MappingConflict(
                    severity: .contextualOverlap,
                    input: input,
                    actions: mappedActions,
                    message: "Multiple actions share this input (\(mappedActions.map(\.displayName).joined(separator: ", "))). Ensure this is intentional."
                ))
            }
        }
        return conflicts
    }
}
