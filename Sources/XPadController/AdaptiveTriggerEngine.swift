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

    /// Width-safe labels for segmented controls inside compact settings popovers.
    public var compactName: String {
        switch self {
        case .light009: return "Light"
        case .regular010: return "Regular"
        case .heavy012: return "Heavy"
        case .bass045: return "Bass"
        }
    }

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

public struct AdaptiveTriggerFeedbackState: Sendable, Codable, Equatable {
    public var triggerPosition: Float
    public var calculatedForce: Float
    public var isInDetent: Bool
    public var activeDetentIndex: Int?
    public var activeMode: AdaptiveTriggerMode
    public var statusDescription: String

    public init(
        triggerPosition: Float = 0.0,
        calculatedForce: Float = 0.0,
        isInDetent: Bool = false,
        activeDetentIndex: Int? = nil,
        activeMode: AdaptiveTriggerMode = .off,
        statusDescription: String = "Inactive"
    ) {
        self.triggerPosition = triggerPosition
        self.calculatedForce = calculatedForce
        self.isInDetent = isInDetent
        self.activeDetentIndex = activeDetentIndex
        self.activeMode = activeMode
        self.statusDescription = statusDescription
    }
}

// MARK: - Adaptive Trigger Engine

public final class AdaptiveTriggerEngine: @unchecked Sendable {
    public var leftConfig: AdaptiveTriggerConfig
    public var rightConfig: AdaptiveTriggerConfig
    public private(set) var isEnabled: Bool = true

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

        leftState = calculateTriggerState(
            position: leftTrigger,
            velocity: leftVelocity,
            config: leftConfig,
            label: "Left Trigger (L2)"
        )

        rightState = calculateTriggerState(
            position: rightTrigger,
            velocity: rightVelocity,
            config: rightConfig,
            label: "Right Trigger (R2)"
        )

        applyToHardware(controller: controller)
    }

    /// Evaluates resistance curve and detents for an individual trigger.
    public func calculateTriggerState(
        position: Float,
        velocity: Float,
        config: AdaptiveTriggerConfig,
        label: String
    ) -> AdaptiveTriggerFeedbackState {
        let pos = max(0.0, min(1.0, position))
        var force: Float = 0.0
        var inDetent = false
        var detentIdx: Int? = nil
        var desc = "Off"

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
            let steps = max(2, config.detentCount)
            let stepSize = 1.0 / Float(steps)
            let nearestStep = roundf(pos / stepSize)
            let targetPos = nearestStep * stepSize
            let distance = abs(pos - targetPos)

            if distance < 0.025 {
                inDetent = true
                detentIdx = Int(nearestStep)
                force = config.resistiveStrength * 0.9
                desc = "\(label): Detent Step #\(Int(nearestStep)) / \(steps)"
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
            statusDescription: desc
        )
    }

    /// Sends motor resistance commands to physical DualSense controller when running on macOS.
    private func applyToHardware(controller: GCController?) {
        guard let controller else { return }

        // Dynamic inspection for DualSense Adaptive Trigger support
        if #available(macOS 12.0, *) {
            if let ds = controller.physicalInputProfile as? GCDualSenseGamepad {
                applyConfig(config: leftConfig, to: ds.leftTrigger)
                applyConfig(config: rightConfig, to: ds.rightTrigger)
            }
        }
    }

    @available(macOS 12.3, *)
    private func applyConfig(config: AdaptiveTriggerConfig, to trigger: GCDualSenseAdaptiveTrigger) {
        switch config.mode {
        case .off:
            trigger.setModeOff()

        case .guitarStringTension:
            let start = Float(config.startPosition)
            let strength = Float(config.resistiveStrength * config.stringGauge.stiffness)
            trigger.setModeSlopeFeedback(startPosition: start, endPosition: 1.0, startStrength: 0.1, endStrength: strength)

        case .bowDragResistance:
            let strength = Float(config.resistiveStrength)
            trigger.setModeSlopeFeedback(startPosition: 0.0, endPosition: 1.0, startStrength: strength * 0.6, endStrength: strength)

        case .modWheelDetents:
            let start = Float(config.startPosition)
            let strength = Float(config.resistiveStrength)
            trigger.setModeSlopeFeedback(startPosition: start, endPosition: 0.9, startStrength: strength, endStrength: strength)

        case .palmMuteShelf:
            let start = Float(config.startPosition)
            let strength = Float(config.resistiveStrength)
            trigger.setModeSlopeFeedback(startPosition: start, endPosition: 1.0, startStrength: strength * 0.8, endStrength: strength)

        case .customSlope:
            trigger.setModeSlopeFeedback(
                startPosition: Float(config.startPosition),
                endPosition: Float(config.endPosition),
                startStrength: 0.0,
                endStrength: Float(config.resistiveStrength)
            )
        }
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
