import Foundation
import GameController
import XPadCore

@MainActor
public final class ControllerManager: ObservableObject {
    @Published public var connectedControllers: [GCController] = []
    @Published public var activeController: GCController?
    @Published public var controllerKind: ControllerKind = .dualSense
    @Published public var capabilityProfile: ControllerCapabilityProfile = .dualSense
    @Published public var currentState: GamepadState = GamepadState()
    @Published public var isHardwareConnected: Bool = false
    
    // Callbacks for musical engine integration
    public var onStateChanged: ((GamepadState) -> Void)?
    public var onButtonDown: ((String) -> Void)?
    public var onButtonUp: ((String) -> Void)?

    public init() {
        setupDiscovery()
    }

    public func setupDiscovery() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerConnected(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDisconnected(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Check already connected controllers
        let current = GCController.controllers()
        self.connectedControllers = current
        if let first = current.first {
            activate(controller: first)
        } else {
            // Simulated fallback active
            selectControllerKind(.dualSense)
            self.isHardwareConnected = false
        }
    }

    @objc private func handleControllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        if !connectedControllers.contains(controller) {
            connectedControllers.append(controller)
        }
        activate(controller: controller)
    }

    @objc private func handleControllerDisconnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        connectedControllers.removeAll { $0 == controller }
        if activeController == controller {
            if let next = connectedControllers.first {
                activate(controller: next)
            } else {
                activeController = nil
                selectControllerKind(.dualSense)
                isHardwareConnected = false
            }
        }
    }

    public func selectControllerKind(_ kind: ControllerKind) {
        self.controllerKind = kind
        switch kind {
        case .dualSense, .dualShock4:
            self.capabilityProfile = .dualSense
        case .xbox:
            self.capabilityProfile = .xbox
        case .switchPro:
            self.capabilityProfile = .switchPro
        case .steamDeck:
            self.capabilityProfile = .steamDeck
        case .guitarHero:
            self.capabilityProfile = .guitarHero
        case .soundVoltex:
            self.capabilityProfile = .soundVoltex
        case .beatmaniaIIDX:
            self.capabilityProfile = .beatmaniaIIDX
        case .popnMusic:
            self.capabilityProfile = .popnMusic
        case .taikoDrum:
            self.capabilityProfile = .taikoDrum
        case .danceMat:
            self.capabilityProfile = .danceMat
        case .flightStick:
            self.capabilityProfile = .flightStick
        case .racingWheel:
            self.capabilityProfile = .racingWheel
        case .fightStick:
            self.capabilityProfile = .fightStick
        case .generic, .simulated:
            self.capabilityProfile = .generic
        }
    }

    public func activate(controller: GCController) {
        self.activeController = controller
        self.isHardwareConnected = true

        // Identify kind with extended rhythm & niche heuristics
        let vendor = (controller.vendorName ?? "").lowercased()
        let product = (controller.productCategory ?? "").lowercased()
        let combined = "\(vendor) \(product)"

        if combined.contains("guitar") || combined.contains("fret") || combined.contains("rock band") || combined.contains("hero") {
            selectControllerKind(.guitarHero)
        } else if combined.contains("sdvx") || combined.contains("voltex") || combined.contains("yuancon") || combined.contains("faucetwo") {
            selectControllerKind(.soundVoltex)
        } else if combined.contains("beatmania") || combined.contains("iidx") || combined.contains("djdao") || combined.contains("phoenixwan") {
            selectControllerKind(.beatmaniaIIDX)
        } else if combined.contains("popn") || combined.contains("pop'n") {
            selectControllerKind(.popnMusic)
        } else if combined.contains("taiko") || combined.contains("tatacon") {
            selectControllerKind(.taikoDrum)
        } else if combined.contains("dance") || combined.contains("ddr") || combined.contains("stepmania") {
            selectControllerKind(.danceMat)
        } else if combined.contains("hotas") || combined.contains("flight") || combined.contains("t.16000m") || combined.contains("warthog") || combined.contains("gladiator") {
            selectControllerKind(.flightStick)
        } else if combined.contains("wheel") || combined.contains("g29") || combined.contains("g923") || combined.contains("fanatec") || combined.contains("thrustmaster t") {
            selectControllerKind(.racingWheel)
        } else if combined.contains("arcade") || combined.contains("fight") || combined.contains("hitbox") || combined.contains("snackbox") || combined.contains("qanba") {
            selectControllerKind(.fightStick)
        } else if combined.contains("dualsense") || combined.contains("ps5") {
            selectControllerKind(.dualSense)
        } else if combined.contains("dualshock") || combined.contains("ps4") {
            selectControllerKind(.dualShock4)
        } else if combined.contains("xbox") {
            selectControllerKind(.xbox)
        } else if combined.contains("switch") || combined.contains("pro controller") {
            selectControllerKind(.switchPro)
        } else if combined.contains("steam") {
            selectControllerKind(.steamDeck)
        } else {
            selectControllerKind(.generic)
        }

        // Attach GameController handlers
        if let gamepad = controller.extendedGamepad {
            gamepad.valueChangedHandler = { [weak self] (_, element) in
                guard let self = self else { return }
                Task { @MainActor in
                    self.updateFromExtendedGamepad(gamepad)
                }
            }
        }

        // Motion / Gyro
        if let motion = controller.motion {
            motion.valueChangedHandler = { [weak self] motion in
                guard let self = self else { return }
                let q = motion.attitude
                let sinp = 2.0 * (q.w * q.y - q.z * q.x)
                let pitch = abs(sinp) >= 1.0 ? copysign(.pi / 2.0, sinp) : asin(sinp)
                let roll = atan2(2.0 * (q.w * q.x + q.y * q.z), 1.0 - 2.0 * (q.x * q.x + q.y * q.y))
                let yaw = atan2(2.0 * (q.w * q.z + q.x * q.y), 1.0 - 2.0 * (q.y * q.y + q.z * q.z))

                Task { @MainActor in
                    self.currentState.gyroPitch = pitch
                    self.currentState.gyroRoll = roll
                    self.currentState.gyroYaw = yaw
                    self.onStateChanged?(self.currentState)
                }
            }
        }
    }

    private func updateFromExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        var state = self.currentState

        state.leftStick = StickCoordinates(
            x: Double(gamepad.leftThumbstick.xAxis.value),
            y: Double(gamepad.leftThumbstick.yAxis.value)
        )
        state.rightStick = StickCoordinates(
            x: Double(gamepad.rightThumbstick.xAxis.value),
            y: Double(gamepad.rightThumbstick.yAxis.value)
        )

        state.leftTrigger = Double(gamepad.leftTrigger.value)
        state.rightTrigger = Double(gamepad.rightTrigger.value)
        state.leftShoulder = gamepad.leftShoulder.isPressed
        state.rightShoulder = gamepad.rightShoulder.isPressed

        state.buttonA = gamepad.buttonA.isPressed
        state.buttonB = gamepad.buttonB.isPressed
        state.buttonX = gamepad.buttonX.isPressed
        state.buttonY = gamepad.buttonY.isPressed

        state.dpadUp = gamepad.dpad.up.isPressed
        state.dpadDown = gamepad.dpad.down.isPressed
        state.dpadLeft = gamepad.dpad.left.isPressed
        state.dpadRight = gamepad.dpad.right.isPressed

        state.leftStickClick = gamepad.leftThumbstickButton?.isPressed ?? false
        state.rightStickClick = gamepad.rightThumbstickButton?.isPressed ?? false

        // Map extended trigger & stick values to rhythm / niche fields
        state.whammy = state.rightTrigger
        state.throttle = state.leftTrigger
        state.encoderL = state.leftStick.x
        state.encoderR = state.rightStick.x
        state.rudderTwist = state.rightStick.x
        state.wheelAngle = state.leftStick.x
        state.pedalGas = state.rightTrigger
        state.pedalBrake = state.leftTrigger

        self.currentState = state
        self.onStateChanged?(state)
    }

    /// Allows simulated state injection from UI or Keyboard controls
    public func injectSimulatedState(_ transform: (inout GamepadState) -> Void) {
        var state = self.currentState
        transform(&state)
        self.currentState = state
        self.onStateChanged?(state)
    }
}
