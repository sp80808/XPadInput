import Foundation
import GameController
import XPadCore

@MainActor
public final class ControllerManager: ObservableObject {
    @Published public var connectedControllers: [GCController] = []
    @Published public var activeController: GCController?
    @Published public var controllerKind: ControllerKind = .simulated
    @Published public var capabilityProfile: ControllerCapabilityProfile = .generic
    @Published public var currentState: GamepadState = GamepadState()
    @Published public var isHardwareConnected: Bool = false
    
    // Callbacks for musical engine integration
    public var onStateChanged: ((GamepadState) -> Void)?
    public var onButtonDown: ((String) -> Void)?
    public var onButtonUp: ((String) -> Void)?

    private var pollTimer: Timer?

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
            self.controllerKind = .simulated
            self.capabilityProfile = .dualSense
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
                controllerKind = .simulated
                isHardwareConnected = false
            }
        }
    }

    public func activate(controller: GCController) {
        self.activeController = controller
        self.isHardwareConnected = true

        // Identify kind
        let vendor = controller.vendorName ?? ""
        if vendor.localizedCaseInsensitiveContains("dualsense") || vendor.localizedCaseInsensitiveContains("ps5") {
            self.controllerKind = .dualSense
            self.capabilityProfile = .dualSense
        } else if vendor.localizedCaseInsensitiveContains("dualshock") || vendor.localizedCaseInsensitiveContains("ps4") {
            self.controllerKind = .dualShock4
            self.capabilityProfile = .dualSense
        } else if vendor.localizedCaseInsensitiveContains("xbox") {
            self.controllerKind = .xbox
            self.capabilityProfile = .xbox
        } else if vendor.localizedCaseInsensitiveContains("switch") || vendor.localizedCaseInsensitiveContains("pro controller") {
            self.controllerKind = .switchPro
            self.capabilityProfile = .switchPro
        } else {
            self.controllerKind = .generic
            self.capabilityProfile = .generic
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
            motion.sensorsRequireCurrentState = true
            motion.valueChangedHandler = { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.currentState.gyroPitch = motion.attitude.pitch
                    self.currentState.gyroRoll = motion.attitude.roll
                    self.currentState.gyroYaw = motion.attitude.yaw
                    self.onStateChanged?(self.currentState)
                }
            }
        }
    }

    private func updateFromExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        var state = GamepadState()

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
