import Foundation
import XPadCore

// MARK: - Evaluated Control Surface

/// Snapshot of semantic musical controls resolved from a scheme + live hardware state.
public struct ControlSurfaceFrame: Sendable, Equatable {
    public var analog: [SemanticMusicalAction: Float]
    public var digitalHeld: Set<SemanticMusicalAction>
    public var digitalRising: Set<SemanticMusicalAction>
    public var digitalFalling: Set<SemanticMusicalAction>
    public var harmonyStick: ProcessedStickState
    public var expressionStick: ProcessedStickState

    public init(
        analog: [SemanticMusicalAction: Float] = [:],
        digitalHeld: Set<SemanticMusicalAction> = [],
        digitalRising: Set<SemanticMusicalAction> = [],
        digitalFalling: Set<SemanticMusicalAction> = [],
        harmonyStick: ProcessedStickState = ProcessedStickState(),
        expressionStick: ProcessedStickState = ProcessedStickState()
    ) {
        self.analog = analog
        self.digitalHeld = digitalHeld
        self.digitalRising = digitalRising
        self.digitalFalling = digitalFalling
        self.harmonyStick = harmonyStick
        self.expressionStick = expressionStick
    }

    public func analogValue(for action: SemanticMusicalAction) -> Float {
        analog[action] ?? 0
    }

    public func isHeld(_ action: SemanticMusicalAction) -> Bool {
        digitalHeld.contains(action)
    }

    public func didRise(_ action: SemanticMusicalAction) -> Bool {
        digitalRising.contains(action)
    }

    public func didFall(_ action: SemanticMusicalAction) -> Bool {
        digitalFalling.contains(action)
    }
}

/// Missing or hardware-unavailable bindings that musicians should know about
/// before a scheme goes on stage.
public struct SchemeCoverageIssue: Identifiable, Sendable, Equatable {
    public let id: String
    public let severity: MappingConflict.Severity
    public let action: SemanticMusicalAction
    public let message: String

    public init(severity: MappingConflict.Severity, action: SemanticMusicalAction, message: String) {
        self.id = "\(action.rawValue)-\(severity.rawValue)"
        self.severity = severity
        self.action = action
        self.message = message
    }
}

/// Resolves physical controller state through a `ControlScheme` into semantic
/// musical controls, applying inversion, sensitivity, deadzone overrides, and
/// digital-expression behaviours.
public struct ControlSurfaceResolver: Sendable {
    public var scheme: ControlScheme

    private var previousHeld: Set<SemanticMusicalAction> = []
    private var previousPhysicalPressed: Set<SemanticMusicalAction> = []
    private var rampStart: [SemanticMusicalAction: TimeInterval] = [:]
    private var steppedLevel: [SemanticMusicalAction: Int] = [:]
    private var latchedAnalog: [SemanticMusicalAction: Float] = [:]

    public static let rampDuration: TimeInterval = 0.38
    public static let steppedLevels: [Float] = [0.25, 0.50, 1.0]
    public static let digitalPressThreshold: Float = 0.38
    public static let motionScale: Float = 0.85

    public init(scheme: ControlScheme = ControlSchemePreset.xpiPerformance) {
        self.scheme = scheme
    }

    public mutating func reset() {
        previousHeld.removeAll()
        previousPhysicalPressed.removeAll()
        rampStart.removeAll()
        steppedLevel.removeAll()
        latchedAnalog.removeAll()
    }

    /// Evaluates every bound semantic action against the current physical state.
    public mutating func evaluate(
        state: ControllerState,
        timestamp: TimeInterval
    ) -> ControlSurfaceFrame {
        var analog: [SemanticMusicalAction: Float] = [:]
        var held: Set<SemanticMusicalAction> = []
        var physicalPressed: Set<SemanticMusicalAction> = []

        for action in SemanticMusicalAction.allCases {
            guard let binding = scheme.binding(for: action), binding.input != .unassigned else {
                continue
            }
            let sample = sample(
                binding: binding,
                action: action,
                state: state,
                timestamp: timestamp,
                physicalRising: !previousPhysicalPressed.contains(action)
            )
            analog[action] = sample.value
            if sample.isHeld {
                held.insert(action)
            }
            if sample.physicalPressed {
                physicalPressed.insert(action)
            }
        }
        previousPhysicalPressed = physicalPressed

        var rising: Set<SemanticMusicalAction> = []
        var falling: Set<SemanticMusicalAction> = []
        for action in SemanticMusicalAction.allCases {
            let nowHeld = held.contains(action)
            let wasHeld = previousHeld.contains(action)
            if nowHeld && !wasHeld { rising.insert(action) }
            if !nowHeld && wasHeld { falling.insert(action) }
        }
        previousHeld = held

        let harmony = resolveStick(
            for: .harmonyNavigate2D,
            fallbackFamily: .leftStick,
            state: state,
            analog: analog
        )
        let expression = resolveExpressionStick(state: state, analog: analog)

        return ControlSurfaceFrame(
            analog: analog,
            digitalHeld: held,
            digitalRising: rising,
            digitalFalling: falling,
            harmonyStick: harmony,
            expressionStick: expression
        )
    }

    /// Projects semantic controls onto the canonical performance layout used by
    /// existing engines: left stick = harmony, right stick = excite/pitch,
    /// L2 = damping, R2 = pressure, face buttons = chord tones, D-pad = octave/voicing.
    public func project(frame: ControlSurfaceFrame, physical: ControllerState, onto logical: ControllerState) {
        logical.leftStick = frame.harmonyStick
        logical.rightStick = frame.expressionStick

        logical.leftTrigger = makeTrigger(frame.analogValue(for: .dampingExpression))
        logical.rightTrigger = makeTrigger(frame.analogValue(for: .pressureExpression))

        logical.leftShoulder = frame.isHeld(.techniqueModifier)
        logical.rightShoulder = frame.isHeld(.sustainLatch)

        logical.buttonA = frame.isHeld(.voiceDegree1)
        logical.buttonX = frame.isHeld(.voiceDegree3)
        logical.buttonY = frame.isHeld(.voiceDegree5)
        logical.buttonB = frame.isHeld(.voiceDegree7)

        logical.dpadUp = frame.isHeld(.octaveUp)
        logical.dpadDown = frame.isHeld(.octaveDown)
        logical.dpadRight = frame.isHeld(.voicingNext)
        logical.dpadLeft = frame.isHeld(.voicingPrevious)

        logical.rightStickButton = frame.isHeld(.soloModeToggle)
        logical.leftStickButton = frame.isHeld(.duoModeToggle)
        logical.menuButton = frame.isHeld(.panic)
        logical.optionsButton = frame.isHeld(.metronomeToggle)

        logical.touchpadX = frame.analogValue(for: .timbreExpression)
        logical.touchpadActive = abs(logical.touchpadX) > 0.04
        logical.gyroX = Double(frame.analogValue(for: .motionExpression))
        logical.hasMotion = abs(logical.gyroX) > 0.02

        // Preserve unused physical telemetry so visualisers can still show raw hardware
        // when they read `controllerState` directly.
        logical.touchpadY = physical.touchpadY
        logical.gyroY = physical.gyroY
        logical.gyroZ = physical.gyroZ
        logical.accelX = physical.accelX
        logical.accelY = physical.accelY
        logical.accelZ = physical.accelZ
    }

    // MARK: - Sampling

    private mutating func sample(
        binding: PhysicalControlBinding,
        action: SemanticMusicalAction,
        state: ControllerState,
        timestamp: TimeInterval,
        physicalRising: Bool
    ) -> (value: Float, isHeld: Bool, physicalPressed: Bool) {
        let raw = rawValue(for: binding.input, in: state)
        let pressed = isPhysicallyPressed(binding.input, in: state, raw: raw)

        let analog: Float
        if binding.input.isContinuous {
            analog = applyContinuousShaping(raw, binding: binding)
            if pressed { rampStart[action] = nil }
        } else {
            analog = applyDigitalBehavior(
                action: action,
                binding: binding,
                pressed: pressed,
                physicalRising: physicalRising,
                timestamp: timestamp
            )
        }

        let held: Bool
        if binding.digitalBehavior == .stepped && !binding.input.isContinuous {
            held = analog > 0.12
        } else {
            held = pressed || abs(analog) > Self.digitalPressThreshold
        }
        return (analog, held, pressed)
    }

    private func rawValue(for input: PhysicalControlInput, in state: ControllerState) -> Float {
        switch input {
        case .leftStickX: return state.leftStick.x
        case .leftStickY: return state.leftStick.y
        case .rightStickX: return state.rightStick.x
        case .rightStickY: return state.rightStick.y
        case .leftStick2D: return signedRadius(state.leftStick)
        case .rightStick2D: return signedRadius(state.rightStick)
        case .leftTrigger: return state.leftTrigger.value
        case .rightTrigger: return state.rightTrigger.value
        case .leftShoulder: return state.leftShoulder ? 1 : 0
        case .rightShoulder: return state.rightShoulder ? 1 : 0
        case .leftStickClick: return state.leftStickButton ? 1 : 0
        case .rightStickClick: return state.rightStickButton ? 1 : 0
        case .buttonSouth: return state.buttonA ? 1 : 0
        case .buttonEast: return state.buttonB ? 1 : 0
        case .buttonWest: return state.buttonX ? 1 : 0
        case .buttonNorth: return state.buttonY ? 1 : 0
        case .dpadUp: return state.dpadUp ? 1 : 0
        case .dpadDown: return state.dpadDown ? 1 : 0
        case .dpadLeft: return state.dpadLeft ? 1 : 0
        case .dpadRight: return state.dpadRight ? 1 : 0
        case .buttonOptions: return state.menuButton ? 1 : 0
        case .buttonShare: return state.optionsButton ? 1 : 0
        case .buttonCenter: return state.touchpadActive ? 1 : 0
        case .motionPitch: return motionAxis(state.gyroX)
        case .motionRoll: return motionAxis(state.gyroY)
        case .motionYaw: return motionAxis(state.gyroZ)
        case .touchpad2D: return state.touchpadX
        case .unassigned: return 0
        }
    }

    private func isPhysicallyPressed(
        _ input: PhysicalControlInput,
        in state: ControllerState,
        raw: Float
    ) -> Bool {
        if input.isContinuous {
            return abs(raw) > Self.digitalPressThreshold
        }
        return raw > 0.5
    }

    private func applyContinuousShaping(_ raw: Float, binding: PhysicalControlBinding) -> Float {
        var value = raw
        if let deadzone = binding.deadzoneOverride {
            let dz = max(0, min(0.9, deadzone))
            if abs(value) <= dz {
                value = 0
            } else if binding.input.isBipolar {
                let sign: Float = value < 0 ? -1 : 1
                value = sign * (abs(value) - dz) / (1 - dz)
            } else {
                value = (value - dz) / (1 - dz)
            }
        }
        if binding.isInverted {
            value = binding.input.isBipolar ? -value : (1 - value)
        }
        value *= binding.sensitivity
        if binding.input.isBipolar {
            return max(-1, min(1, value))
        }
        return max(0, min(1, value))
    }

    private mutating func applyDigitalBehavior(
        action: SemanticMusicalAction,
        binding: PhysicalControlBinding,
        pressed: Bool,
        physicalRising: Bool,
        timestamp: TimeInterval
    ) -> Float {
        var value: Float
        switch binding.digitalBehavior {
        case .fixedFull:
            value = pressed ? 1 : 0
            rampStart[action] = nil
        case .fixedHalf:
            value = pressed ? 0.5 : 0
            rampStart[action] = nil
        case .linearRamp:
            if pressed {
                if rampStart[action] == nil {
                    rampStart[action] = timestamp
                }
                let elapsed = timestamp - (rampStart[action] ?? timestamp)
                value = Float(min(1, max(0, elapsed / Self.rampDuration)))
            } else {
                rampStart[action] = nil
                value = 0
            }
        case .stepped:
            if physicalRising && pressed {
                let next = ((steppedLevel[action] ?? -1) + 1) % (Self.steppedLevels.count + 1)
                steppedLevel[action] = next
                latchedAnalog[action] = next == Self.steppedLevels.count ? 0 : Self.steppedLevels[next]
            }
            value = latchedAnalog[action] ?? 0
        }

        if binding.isInverted {
            value = 1 - value
        }
        value = max(0, min(1, value * binding.sensitivity))
        return value
    }

    // MARK: - Stick assembly

    private func resolveStick(
        for action: SemanticMusicalAction,
        fallbackFamily: PhysicalControlFamily,
        state: ControllerState,
        analog: [SemanticMusicalAction: Float]
    ) -> ProcessedStickState {
        guard let binding = scheme.binding(for: action), binding.input != .unassigned else {
            return stick(for: fallbackFamily, in: state) ?? ProcessedStickState()
        }
        if let stick = stick(for: binding.input.hardwareFamily, in: state),
           binding.input.hardwareFamily == .leftStick || binding.input.hardwareFamily == .rightStick {
            if binding.input.stickAxis == .radial || binding.input.stickAxis == nil {
                return invertStickIfNeeded(stick, binding: binding)
            }
            return stickFromAxis(binding: binding, analog: analog[action] ?? 0, template: stick)
        }
        let value = analog[action] ?? 0
        return stickFromAxis(binding: binding, analog: value, template: ProcessedStickState())
    }

    private func resolveExpressionStick(
        state: ControllerState,
        analog: [SemanticMusicalAction: Float]
    ) -> ProcessedStickState {
        let exciteBinding = scheme.binding(for: .primaryExcitation)
        let pitchBinding = scheme.binding(for: .pitchExpression)

        if let excite = exciteBinding, let pitch = pitchBinding,
           excite.input.overlapsHardware(with: pitch.input) || excite.input.isOrthogonalStickPair(with: pitch.input),
           let stick = stick(for: excite.input.hardwareFamily, in: state) {
            return invertStickIfNeeded(stick, binding: excite, extra: pitch)
        }

        let pitch = analog[.pitchExpression] ?? 0
        let excite = analog[.primaryExcitation] ?? 0
        let template = stick(for: exciteBinding?.input.hardwareFamily ?? .rightStick, in: state)
            ?? stick(for: pitchBinding?.input.hardwareFamily ?? .rightStick, in: state)
            ?? ProcessedStickState()
        return makeStick(
            x: pitch,
            y: excite,
            xVelocity: template.xVelocity,
            yVelocity: template.yVelocity,
            movementVelocity: max(template.movementVelocity, abs(excite) * 8, abs(pitch) * 8)
        )
    }

    private func stickFromAxis(
        binding: PhysicalControlBinding,
        analog: Float,
        template: ProcessedStickState
    ) -> ProcessedStickState {
        switch binding.input.stickAxis {
        case .x:
            return makeStick(x: analog, y: 0, xVelocity: template.xVelocity, movementVelocity: template.movementVelocity)
        case .y, .radial, nil:
            return makeStick(x: 0, y: analog, yVelocity: template.yVelocity, movementVelocity: template.movementVelocity)
        }
    }

    private func applyAxisInversion(_ binding: PhysicalControlBinding, x: inout Float, y: inout Float) {
        guard binding.isInverted else { return }
        switch binding.input.stickAxis {
        case .x: x = -x
        case .y: y = -y
        case .radial, nil:
            x = -x
            y = -y
        }
    }

    private func invertStickIfNeeded(
        _ stick: ProcessedStickState,
        binding: PhysicalControlBinding,
        extra: PhysicalControlBinding? = nil
    ) -> ProcessedStickState {
        var x = stick.x
        var y = stick.y
        applyAxisInversion(binding, x: &x, y: &y)
        if let extra {
            applyAxisInversion(extra, x: &x, y: &y)
        }
        x = max(-1, min(1, x * binding.sensitivity))
        y = max(-1, min(1, y * binding.sensitivity))
        return makeStick(
            x: x,
            y: y,
            xVelocity: stick.xVelocity,
            yVelocity: stick.yVelocity,
            movementVelocity: stick.movementVelocity,
            rawX: stick.rawX,
            rawY: stick.rawY
        )
    }

    private func stick(for family: PhysicalControlFamily, in state: ControllerState) -> ProcessedStickState? {
        switch family {
        case .leftStick: return state.leftStick
        case .rightStick: return state.rightStick
        default: return nil
        }
    }

    private func signedRadius(_ stick: ProcessedStickState) -> Float {
        let r = stick.radius
        if r <= 0 { return 0 }
        return stick.y >= 0 ? r : -r
    }

    private func motionAxis(_ value: Double) -> Float {
        Float(tanh(value * Double(Self.motionScale)))
    }

    private func makeTrigger(_ value: Float) -> ProcessedTriggerState {
        let clamped = max(0, min(1, value))
        return ProcessedTriggerState(
            rawValue: clamped,
            calibratedValue: clamped,
            value: clamped,
            isPressed: clamped > 0.10
        )
    }

    private func makeStick(
        x: Float,
        y: Float,
        xVelocity: Float = 0,
        yVelocity: Float = 0,
        movementVelocity: Float = 0,
        rawX: Float? = nil,
        rawY: Float? = nil
    ) -> ProcessedStickState {
        let radius = hypot(x, y)
        return ProcessedStickState(
            rawX: rawX ?? x,
            rawY: rawY ?? y,
            calibratedX: x,
            calibratedY: y,
            x: x,
            y: y,
            radius: radius,
            angle: atan2(Double(y), Double(x)),
            movementVelocity: movementVelocity,
            xVelocity: xVelocity,
            yVelocity: yVelocity,
            radialVelocity: 0,
            angularVelocity: 0,
            isInDeadzone: radius < 0.02,
            isNearEdge: radius > 0.94
        )
    }
}

// MARK: - Input Learn

/// Pure detector for Input Learn mode. Ignores resting stick jitter and prefers
/// 2D stick bindings when both axes move together.
public enum InputLearnDetector {
    public static let axisThreshold: Float = 0.55
    public static let twoDRadiusThreshold: Float = 0.48
    public static let twoDAxisFloor: Float = 0.22
    public static let triggerThreshold: Float = 0.40

    public static func detect(
        leftStickX: Float = 0,
        leftStickY: Float = 0,
        rightStickX: Float = 0,
        rightStickY: Float = 0,
        leftTrigger: Float = 0,
        rightTrigger: Float = 0,
        leftShoulder: Bool = false,
        rightShoulder: Bool = false,
        buttonSouth: Bool = false,
        buttonEast: Bool = false,
        buttonWest: Bool = false,
        buttonNorth: Bool = false,
        dpadUp: Bool = false,
        dpadDown: Bool = false,
        dpadLeft: Bool = false,
        dpadRight: Bool = false,
        leftStickClick: Bool = false,
        rightStickClick: Bool = false,
        options: Bool = false,
        share: Bool = false,
        center: Bool = false,
        prefer2D: Bool = false
    ) -> PhysicalControlInput? {
        if buttonSouth { return .buttonSouth }
        if buttonEast { return .buttonEast }
        if buttonWest { return .buttonWest }
        if buttonNorth { return .buttonNorth }

        if leftShoulder { return .leftShoulder }
        if rightShoulder { return .rightShoulder }
        if leftTrigger > triggerThreshold { return .leftTrigger }
        if rightTrigger > triggerThreshold { return .rightTrigger }

        if dpadUp { return .dpadUp }
        if dpadDown { return .dpadDown }
        if dpadLeft { return .dpadLeft }
        if dpadRight { return .dpadRight }

        if leftStickClick { return .leftStickClick }
        if rightStickClick { return .rightStickClick }

        if let stick = detectStick(
            x: leftStickX,
            y: leftStickY,
            twoD: .leftStick2D,
            axisX: .leftStickX,
            axisY: .leftStickY,
            prefer2D: prefer2D
        ) {
            return stick
        }
        if let stick = detectStick(
            x: rightStickX,
            y: rightStickY,
            twoD: .rightStick2D,
            axisX: .rightStickX,
            axisY: .rightStickY,
            prefer2D: prefer2D
        ) {
            return stick
        }

        if options { return .buttonOptions }
        if share { return .buttonShare }
        if center { return .buttonCenter }

        return nil
    }

    private static func detectStick(
        x: Float,
        y: Float,
        twoD: PhysicalControlInput,
        axisX: PhysicalControlInput,
        axisY: PhysicalControlInput,
        prefer2D: Bool
    ) -> PhysicalControlInput? {
        let radius = hypot(x, y)
        let twoDFloor = prefer2D ? twoDRadiusThreshold - 0.08 : twoDRadiusThreshold
        if radius > twoDFloor && abs(x) > twoDAxisFloor && abs(y) > twoDAxisFloor {
            return twoD
        }
        if prefer2D && radius > twoDRadiusThreshold {
            return twoD
        }
        if abs(x) > axisThreshold && abs(x) >= abs(y) { return axisX }
        if abs(y) > axisThreshold { return axisY }
        return nil
    }
}
