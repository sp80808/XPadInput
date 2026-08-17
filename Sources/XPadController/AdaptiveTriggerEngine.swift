import Foundation
import GameController
import XPadCore

// MARK: - Enums & Configurations

public enum AdaptiveTriggerMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case off = "Off / Standard Linear"
    case guitarStringTension = "Guitar String Tension"
    case bowDragResistance = "Bowed String Viscous Drag"
    case modWheelDetents = "Mod-Wheel & Pitch Detents"
    case palmMuteShelf = "Palm-Mute Resistance Shelf"
    case customSlope = "Custom Slope Resistance"

    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

public enum StringGauge: String, Codable, Sendable, CaseIterable, Identifiable {
    case light009 = "Light (.009 - .042)"
    case regular010 = "Regular (.010 - .046)"
    case heavy012 = "Heavy (.012 - .054)"
    case bass045 = "Bass (.045 - .105)"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    public var stiffness: Float {
        switch self {
        case .light009: return 0.45
        case .regular010: return 0.65
        case .heavy012: return 0.85
        case .bass045: return 1.00
        }
    }
}

public struct AdaptiveTriggerConfig: Codable, Sendable, Equatable {
    public var mode: AdaptiveTriggerMode
    public var stringGauge: StringGauge
    public var startPosition: Float // 0.0 ... 1.0
    public var endPosition: Float   // 0.0 ... 1.0
    public var resistiveStrength: Float // 0.0 ... 1.0
    public var detentCount: Int // e.g. 12 for semitones
    public var frequency: Float // For vibration / buzz feedback

    public init(
        mode: AdaptiveTriggerMode = .guitarStringTension,
        stringGauge: StringGauge = .regular010,
        startPosition: Float = 0.0,
        endPosition: Float = 1.0,
        resistiveStrength: Float = 0.7,
        detentCount: Int = 12,
        frequency: Float = 0.0
    ) {
        self.mode = mode
        self.stringGauge = stringGauge
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.resistiveStrength = resistiveStrength
        self.detentCount = detentCount
        self.frequency = frequency
    }
}

public struct DualSenseHardwareCommand: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case off
        case slope(start: Float, end: Float, startStrength: Float, endStrength: Float)
        case feedback(start: Float, strength: Float)
    }

    public var kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public var modeLabel: String {
        switch kind {
        case .off: return "off"
        case .slope: return "slope"
        case .feedback: return "slope-shelf"
        }
    }

    public static func command(
        for config: AdaptiveTriggerConfig,
        forceScale: Float
    ) -> DualSenseHardwareCommand {
        let scale = max(0, min(1, forceScale))
        if scale <= 0.001 || config.mode == .off {
            return DualSenseHardwareCommand(kind: .off)
        }
        let strength = config.resistiveStrength * scale
        switch config.mode {
        case .off:
            return DualSenseHardwareCommand(kind: .off)
        case .guitarStringTension:
            let gauge = config.stringGauge.stiffness
            return DualSenseHardwareCommand(kind: .slope(
                start: config.startPosition,
                end: 1,
                startStrength: 0.1 * scale,
                endStrength: strength * gauge
            ))
        case .bowDragResistance:
            return DualSenseHardwareCommand(kind: .slope(
                start: 0,
                end: 1,
                startStrength: strength * 0.6,
                endStrength: strength
            ))
        case .palmMuteShelf, .modWheelDetents:
            return DualSenseHardwareCommand(kind: .slope(
                start: config.startPosition,
                end: 1,
                startStrength: strength * 0.85,
                endStrength: strength
            ))
        case .customSlope:
            return DualSenseHardwareCommand(kind: .slope(
                start: config.startPosition,
                end: config.endPosition,
                startStrength: 0,
                endStrength: strength
            ))
        }
    }

    public static let maxPhysicalPositions = 10
}

public struct AdaptiveTriggerFeedbackState: Sendable, Equatable {
    public var triggerPosition: Float
    public var calculatedForce: Float
    public var isInDetent: Bool
    public var activeDetentIndex: Int?
    public var activeMode: AdaptiveTriggerMode
    public var statusDescription: String
    public var hardwareMode: String
    public var renderedDetentCount: Int
    public var semanticDetentCount: Int
    public var isHardwareAccurate: Bool
    public var hardwareSupported: Bool

    public init(
        triggerPosition: Float = 0.0,
        calculatedForce: Float = 0.0,
        isInDetent: Bool = false,
        activeDetentIndex: Int? = nil,
        activeMode: AdaptiveTriggerMode = .off,
        statusDescription: String = "Inactive",
        hardwareMode: String = "off",
        renderedDetentCount: Int = 0,
        semanticDetentCount: Int = 0,
        isHardwareAccurate: Bool = true,
        hardwareSupported: Bool = false
    ) {
        self.triggerPosition = triggerPosition
        self.calculatedForce = calculatedForce
        self.isInDetent = isInDetent
        self.activeDetentIndex = activeDetentIndex
        self.activeMode = activeMode
        self.statusDescription = statusDescription
        self.hardwareMode = hardwareMode
        self.renderedDetentCount = renderedDetentCount
        self.semanticDetentCount = semanticDetentCount
        self.isHardwareAccurate = isHardwareAccurate
        self.hardwareSupported = hardwareSupported
    }
}

// MARK: - Adaptive Trigger Engine

public final class AdaptiveTriggerEngine: @unchecked Sendable {
    public var leftConfig: AdaptiveTriggerConfig
    public var rightConfig: AdaptiveTriggerConfig
    public var forcePolicy: AdaptiveTriggerForcePolicy = .reduced
    public private(set) var isEnabled: Bool = true
    private var lastLeftCommand: DualSenseHardwareCommand?
    private var lastRightCommand: DualSenseHardwareCommand?

    public private(set) var leftState = AdaptiveTriggerFeedbackState()
    public private(set) var rightState = AdaptiveTriggerFeedbackState()

    private var previousLeftPos: Float = 0.0
    private var previousRightPos: Float = 0.0
    private var previousTimestamp: TimeInterval = 0.0

    public init(
        leftConfig: AdaptiveTriggerConfig = AdaptiveTriggerConfig(mode: .palmMuteShelf, startPosition: 0.35, resistiveStrength: 0.75),
        rightConfig: AdaptiveTriggerConfig = AdaptiveTriggerConfig(mode: .guitarStringTension, stringGauge: .regular010, resistiveStrength: 0.68)
    ) {
        self.leftConfig = leftConfig
        self.rightConfig = rightConfig
    }

    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }

    /// Updates mathematical trigger resistance and pushes physical commands to DualSense hardware if attached.
    public func process(
        leftTrigger: Float,
        rightTrigger: Float,
        controller: GCController?,
        timestamp: TimeInterval
    ) {
        let dt = previousTimestamp == 0 ? 0.008 : max(0.001, min(0.05, Float(timestamp - previousTimestamp)))
        previousTimestamp = timestamp

        let leftVelocity = (leftTrigger - previousLeftPos) / dt
        let rightVelocity = (rightTrigger - previousRightPos) / dt
        previousLeftPos = leftTrigger
        previousRightPos = rightTrigger

        let forceScale = isEnabled ? forcePolicy.strengthScale : 0
        let hardwareSupported = Self.supportsAdaptiveTriggers(controller)

        leftState = calculateTriggerState(
            position: leftTrigger,
            velocity: leftVelocity,
            config: leftConfig,
            label: "Left Trigger (L2)",
            forceScale: forceScale,
            hardwareSupported: hardwareSupported
        )

        rightState = calculateTriggerState(
            position: rightTrigger,
            velocity: rightVelocity,
            config: rightConfig,
            label: "Right Trigger (R2)",
            forceScale: forceScale,
            hardwareSupported: hardwareSupported
        )

        applyToHardware(controller: controller)
    }

    public static func supportsAdaptiveTriggers(_ controller: GCController?) -> Bool {
        guard let controller else { return false }
        if #available(macOS 12.3, *) {
            return controller.extendedGamepad is GCDualSenseGamepad
        }
        return false
    }

    public func resetHardwareCache() {
        lastLeftCommand = nil
        lastRightCommand = nil
    }

    /// Evaluates resistance curve and detents for an individual trigger.
    public func calculateTriggerState(
        position: Float,
        velocity: Float,
        config: AdaptiveTriggerConfig,
        label: String,
        forceScale: Float = 1,
        hardwareSupported: Bool = true
    ) -> AdaptiveTriggerFeedbackState {
        let pos = max(0.0, min(1.0, position))
        var force: Float = 0.0
        var inDetent = false
        var detentIdx: Int? = nil
        var desc = "Off"
        let hardware = DualSenseHardwareCommand.command(for: config, forceScale: hardwareSupported ? forceScale : 0)
        let semanticDetents = config.mode == .modWheelDetents ? config.detentCount : 0
        let renderedDetents = config.mode == .modWheelDetents
            ? min(config.detentCount, DualSenseHardwareCommand.maxPhysicalPositions)
            : 0
        let accurate = hardwareSupported
            && (config.mode != .modWheelDetents || semanticDetents <= DualSenseHardwareCommand.maxPhysicalPositions)

        switch config.mode {
        case .off:
            force = 0.0
            desc = "\(label): Off"

        case .guitarStringTension:
            let stiffness = config.stringGauge.stiffness
            if pos < 0.90 {
                // Exponential string stretch: F = k * x^1.8
                force = stiffness * powf(pos / 0.90, 1.8) * config.resistiveStrength
                desc = String(format: "%@: String Stretch (%.0f%% tension)", label, force * 100)
            } else {
                // Pluck snap point / release
                let snap = (1.0 - pos) / 0.10
                force = stiffness * snap * config.resistiveStrength * 0.4
                desc = "\(label): Pluck Snap Release"
            }

        case .bowDragResistance:
            // Viscous damping modeling rosin friction: F = staticFriction + damping * |velocity|
            let staticFriction: Float = 0.15 * config.resistiveStrength
            let dynamicDrag: Float = min(0.85, abs(velocity) * 0.25) * config.resistiveStrength
            force = min(1.0, staticFriction + dynamicDrag)
            desc = String(format: "%@: Bow Viscous Drag (%.0f%%)", label, force * 100)

        case .modWheelDetents:
            let steps = max(2, min(config.detentCount, DualSenseHardwareCommand.maxPhysicalPositions))
            let stepSize = 1.0 / Float(steps)
            let nearestStep = roundf(pos / stepSize)
            let targetPos = nearestStep * stepSize
            let distance = abs(pos - targetPos)

            if distance < 0.025 {
                inDetent = true
                detentIdx = Int(nearestStep)
                force = config.resistiveStrength * 0.9
                desc = "\(label): Detent Step #\(Int(nearestStep)) / \(steps) (hardware \(hardware.modeLabel))"
            } else {
                force = config.resistiveStrength * 0.2
                desc = String(format: "%@: Pitch/Mod Glide (%.0f%%)", label, pos * 100)
            }

        case .palmMuteShelf:
            let shelf = config.startPosition
            if pos >= shelf {
                let depth = (pos - shelf) / max(0.01, 1.0 - shelf)
                force = config.resistiveStrength * (0.6 + depth * 0.4)
                desc = String(format: "%@: Palm Mute Active (%.0f%% damp)", label, force * 100)
            } else {
                force = 0.05
                desc = "\(label): Open Strum"
            }

        case .customSlope:
            if pos >= config.startPosition && pos <= config.endPosition {
                let range = max(0.01, config.endPosition - config.startPosition)
                let norm = (pos - config.startPosition) / range
                force = norm * config.resistiveStrength
                desc = String(format: "%@: Custom Slope (%.0f%%)", label, force * 100)
            } else {
                force = 0.0
                desc = "\(label): Outside Slope"
            }
        }

        return AdaptiveTriggerFeedbackState(
            triggerPosition: pos,
            calculatedForce: min(1.0, max(0.0, force)),
            isInDetent: inDetent,
            activeDetentIndex: detentIdx,
            activeMode: config.mode,
            statusDescription: desc,
            hardwareMode: hardware.modeLabel,
            renderedDetentCount: renderedDetents,
            semanticDetentCount: semanticDetents,
            isHardwareAccurate: accurate,
            hardwareSupported: hardwareSupported
        )
    }

    /// Sends motor resistance commands to physical DualSense controller when running on macOS.
    private func applyToHardware(controller: GCController?) {
        guard let controller else { return }

        // Dynamic inspection for DualSense Adaptive Trigger support
        if #available(macOS 12.3, *) {
            if let ds = controller.extendedGamepad as? GCDualSenseGamepad {
                let scale = isEnabled ? forcePolicy.strengthScale : 0
                applyCached(command: DualSenseHardwareCommand.command(for: leftConfig, forceScale: scale),
                            previous: &lastLeftCommand,
                            to: ds.leftTrigger)
                applyCached(command: DualSenseHardwareCommand.command(for: rightConfig, forceScale: scale),
                            previous: &lastRightCommand,
                            to: ds.rightTrigger)
            }
        }
        // Non-DualSense controllers are a no-op: musical trigger values are unchanged.
    }

    @available(macOS 12.3, *)
    private func applyCached(
        command: DualSenseHardwareCommand,
        previous: inout DualSenseHardwareCommand?,
        to trigger: GCDualSenseAdaptiveTrigger
    ) {
        if previous == command { return }
        previous = command
        apply(command: command, to: trigger)
    }

    @available(macOS 12.3, *)
    private func apply(command: DualSenseHardwareCommand, to trigger: GCDualSenseAdaptiveTrigger) {
        switch command.kind {
        case .off:
            trigger.setModeOff()
        case .slope(let start, let end, let startStrength, let endStrength):
            trigger.setModeSlopeFeedback(
                startPosition: start,
                endPosition: end,
                startStrength: startStrength,
                endStrength: endStrength
            )
        case .feedback(let start, let strength):
            trigger.setModeSlopeFeedback(
                startPosition: start,
                endPosition: 1.0,
                startStrength: strength * 0.85,
                endStrength: strength
            )
        }
    }

    @available(macOS 12.3, *)
    private func applyConfig(config: AdaptiveTriggerConfig, to trigger: GCDualSenseAdaptiveTrigger) {
        apply(command: DualSenseHardwareCommand.command(for: config, forceScale: forcePolicy.strengthScale), to: trigger)
    }

    public func configureForInstrumentProfile(_ profile: InstrumentProfile) {
        switch profile.family {
        case .guitar:
            leftConfig = AdaptiveTriggerConfig(mode: .palmMuteShelf, startPosition: 0.35, resistiveStrength: 0.75)
            rightConfig = AdaptiveTriggerConfig(mode: .guitarStringTension, stringGauge: .regular010, resistiveStrength: 0.70)

        case .bass:
            leftConfig = AdaptiveTriggerConfig(mode: .palmMuteShelf, startPosition: 0.30, resistiveStrength: 0.85)
            rightConfig = AdaptiveTriggerConfig(mode: .guitarStringTension, stringGauge: .bass045, resistiveStrength: 0.90)

        case .strings:
            leftConfig = AdaptiveTriggerConfig(mode: .bowDragResistance, resistiveStrength: 0.65)
            rightConfig = AdaptiveTriggerConfig(mode: .bowDragResistance, resistiveStrength: 0.80)

        case .synthLead, .keys, .genericMPE:
            leftConfig = AdaptiveTriggerConfig(mode: .modWheelDetents, resistiveStrength: 0.60, detentCount: 12)
            rightConfig = AdaptiveTriggerConfig(mode: .modWheelDetents, resistiveStrength: 0.60, detentCount: 12)

        default:
            leftConfig = AdaptiveTriggerConfig(mode: .off)
            rightConfig = AdaptiveTriggerConfig(mode: .off)
        }
    }
}
