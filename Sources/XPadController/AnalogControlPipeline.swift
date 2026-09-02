import Foundation

/// Hardware analog control that produced a GameController callback.
///
/// Musical left/right roles are applied afterwards so a left/right swap
/// still updates only the processor that owns the changed physical control.
public enum PhysicalAnalogControl: String, Sendable, Hashable, CaseIterable {
    case leftStick
    case rightStick
    case leftTrigger
    case rightTrigger

    /// Maps a physical analog control onto the musical processor role.
    public func musicalRole(swapLeftRight: Bool) -> PhysicalAnalogControl {
        guard swapLeftRight else { return self }
        switch self {
        case .leftStick: return .rightStick
        case .rightStick: return .leftStick
        case .leftTrigger: return .rightTrigger
        case .rightTrigger: return .leftTrigger
        }
    }
}

/// Last-known raw analog values captured from the controller.
public struct RawAnalogSnapshot: Sendable, Equatable {
    public var leftStickX: Float
    public var leftStickY: Float
    public var rightStickX: Float
    public var rightStickY: Float
    public var leftTrigger: Float
    public var rightTrigger: Float

    public init(
        leftStickX: Float = 0,
        leftStickY: Float = 0,
        rightStickX: Float = 0,
        rightStickY: Float = 0,
        leftTrigger: Float = 0,
        rightTrigger: Float = 0
    ) {
        self.leftStickX = leftStickX
        self.leftStickY = leftStickY
        self.rightStickX = rightStickX
        self.rightStickY = rightStickY
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
    }

    public func stickAxes(for musicalRole: PhysicalAnalogControl, swapLeftRight: Bool) -> (x: Float, y: Float) {
        switch musicalRole {
        case .leftStick:
            return swapLeftRight
                ? (rightStickX, rightStickY)
                : (leftStickX, leftStickY)
        case .rightStick:
            return swapLeftRight
                ? (leftStickX, leftStickY)
                : (rightStickX, rightStickY)
        case .leftTrigger, .rightTrigger:
            return (0, 0)
        }
    }

    public func triggerValue(for musicalRole: PhysicalAnalogControl, swapLeftRight: Bool) -> Float {
        switch musicalRole {
        case .leftTrigger:
            return swapLeftRight ? rightTrigger : leftTrigger
        case .rightTrigger:
            return swapLeftRight ? leftTrigger : rightTrigger
        case .leftStick, .rightStick:
            return 0
        }
    }
}

/// Time-based stick/trigger processors that only advance when their own
/// physical control actually changed.
///
/// Face-button and other digital callbacks must not mutate analog smoothing
/// or velocity history. See GitHub #21.
public struct AnalogControlPipeline: Sendable {
    public var leftStickProcessor: StickProcessor
    public var rightStickProcessor: StickProcessor
    public var leftTriggerProcessor: TriggerProcessor
    public var rightTriggerProcessor: TriggerProcessor

    public private(set) var leftStick = ProcessedStickState()
    public private(set) var rightStick = ProcessedStickState()
    public private(set) var leftTrigger = ProcessedTriggerState()
    public private(set) var rightTrigger = ProcessedTriggerState()

    public init(
        leftStickProcessor: StickProcessor = StickProcessor(profile: .expressive),
        rightStickProcessor: StickProcessor = StickProcessor(profile: .expressive),
        leftTriggerProcessor: TriggerProcessor = TriggerProcessor(),
        rightTriggerProcessor: TriggerProcessor = TriggerProcessor()
    ) {
        self.leftStickProcessor = leftStickProcessor
        self.rightStickProcessor = rightStickProcessor
        self.leftTriggerProcessor = leftTriggerProcessor
        self.rightTriggerProcessor = rightTriggerProcessor
    }

    /// Updates only the processors that own `changedPhysicalControls`.
    ///
    /// An empty set is a digital-only event: analog history is left untouched.
    public mutating func process(
        snapshot: RawAnalogSnapshot,
        changedPhysicalControls: Set<PhysicalAnalogControl>,
        swapLeftRight: Bool = false,
        timestamp: TimeInterval
    ) {
        for physical in changedPhysicalControls {
            switch physical.musicalRole(swapLeftRight: swapLeftRight) {
            case .leftStick:
                let axes = snapshot.stickAxes(for: .leftStick, swapLeftRight: swapLeftRight)
                leftStick = leftStickProcessor.process(
                    rawX: axes.x,
                    rawY: axes.y,
                    timestamp: timestamp
                )
            case .rightStick:
                let axes = snapshot.stickAxes(for: .rightStick, swapLeftRight: swapLeftRight)
                rightStick = rightStickProcessor.process(
                    rawX: axes.x,
                    rawY: axes.y,
                    timestamp: timestamp
                )
            case .leftTrigger:
                leftTrigger = leftTriggerProcessor.process(
                    rawValue: snapshot.triggerValue(for: .leftTrigger, swapLeftRight: swapLeftRight),
                    timestamp: timestamp
                )
            case .rightTrigger:
                rightTrigger = rightTriggerProcessor.process(
                    rawValue: snapshot.triggerValue(for: .rightTrigger, swapLeftRight: swapLeftRight),
                    timestamp: timestamp
                )
            }
        }
    }

    public mutating func reset() {
        leftStickProcessor.reset()
        rightStickProcessor.reset()
        leftTriggerProcessor.reset()
        rightTriggerProcessor.reset()
        leftStick = ProcessedStickState()
        rightStick = ProcessedStickState()
        leftTrigger = ProcessedTriggerState()
        rightTrigger = ProcessedTriggerState()
    }
}
