import Foundation
import GameController

/// Manages controller discovery and input handling.
@Observable
public final class ControllerManager: @unchecked Sendable {
    public var connectedController: GCController?
    public var controllerState = ControllerState()
    public var capabilityProfile: ControllerCapabilityProfile?
    public var isConnected: Bool = false
    public var controllerName: String = "No Controller"
    
    // Input Processors
    public var leftStickProcessor = StickProcessor(profile: .expressive)
    public var rightStickProcessor = StickProcessor(profile: .expressive)
    public var leftTriggerProcessor = TriggerProcessor()
    public var rightTriggerProcessor = TriggerProcessor()
    
    // Input callbacks
    public var onStateChanged: ((ControllerState) -> Void)?
    
    private var observers: [Any] = []
    
    public init() {
        setupNotifications()
        scanForControllers()
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    private func setupNotifications() {
        let connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.controllerConnected(controller)
        }
        
        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            if self?.connectedController === controller {
                self?.controllerDisconnected()
            }
        }
        
        observers = [connectObserver, disconnectObserver]
    }
    
    public func scanForControllers() {
        GCController.startWirelessControllerDiscovery {
            // Discovery completed
        }
        
        // Check already-connected controllers
        if let controller = GCController.controllers().first {
            controllerConnected(controller)
        }
    }
    
    private func controllerConnected(_ controller: GCController) {
        connectedController = controller
        isConnected = true
        controllerName = controller.vendorName ?? controller.productCategory ?? "Controller"
        capabilityProfile = ControllerCapabilityProfile.from(controller)
        
        setupInputHandlers(controller)
        
        // Enable motion if available
        if let motion = controller.motion {
            motion.sensorsActive = true
        }
    }
    
    private func controllerDisconnected() {
        connectedController = nil
        isConnected = false
        controllerName = "No Controller"
        capabilityProfile = nil
        controllerState = ControllerState()
    }
    
    // applyDeadzone removed in favor of input processors
    
    private func setupInputHandlers(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        gamepad.valueChangedHandler = { [weak self] (gamepad, element) in
            guard let self = self else { return }
            
            // Update state on main thread for UI, but capture values immediately
            let state = self.controllerState
            
            let timestamp = ProcessInfo.processInfo.systemUptime
            
            // Left stick
            state.leftStick = self.leftStickProcessor.process(
                rawX: gamepad.leftThumbstick.xAxis.value,
                rawY: gamepad.leftThumbstick.yAxis.value,
                timestamp: timestamp
            )
            
            // Right stick
            state.rightStick = self.rightStickProcessor.process(
                rawX: gamepad.rightThumbstick.xAxis.value,
                rawY: gamepad.rightThumbstick.yAxis.value,
                timestamp: timestamp
            )
            
            // Triggers
            state.leftTrigger = self.leftTriggerProcessor.process(
                rawValue: gamepad.leftTrigger.value,
                timestamp: timestamp
            )
            state.rightTrigger = self.rightTriggerProcessor.process(
                rawValue: gamepad.rightTrigger.value,
                timestamp: timestamp
            )
            
            // Shoulders
            state.leftShoulder = gamepad.leftShoulder.isPressed
            state.rightShoulder = gamepad.rightShoulder.isPressed
            
            // Face buttons
            state.buttonA = gamepad.buttonA.isPressed
            state.buttonB = gamepad.buttonB.isPressed
            state.buttonX = gamepad.buttonX.isPressed
            state.buttonY = gamepad.buttonY.isPressed
            
            // D-pad
            state.dpadUp = gamepad.dpad.up.isPressed
            state.dpadDown = gamepad.dpad.down.isPressed
            state.dpadLeft = gamepad.dpad.left.isPressed
            state.dpadRight = gamepad.dpad.right.isPressed
            
            // Stick buttons
            state.leftStickButton = gamepad.leftThumbstickButton?.isPressed ?? false
            state.rightStickButton = gamepad.rightThumbstickButton?.isPressed ?? false
            
            // Menu
            state.menuButton = gamepad.buttonMenu.isPressed
            state.optionsButton = gamepad.buttonOptions?.isPressed ?? false
            
            self.onStateChanged?(state)
        }
        
        // Motion handling
        if let motion = controller.motion {
            motion.valueChangedHandler = { [weak self] (motion) in
                guard let self = self else { return }
                let state = self.controllerState
                
                state.gyroX = motion.rotationRate.x
                state.gyroY = motion.rotationRate.y
                state.gyroZ = motion.rotationRate.z
                state.accelX = motion.userAcceleration.x
                state.accelY = motion.userAcceleration.y
                state.accelZ = motion.userAcceleration.z
                state.hasMotion = true
            }
        }
    }
}
