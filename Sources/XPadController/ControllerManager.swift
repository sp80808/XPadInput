import Foundation
import GameController
import CoreHaptics
import XPadCore

/// Manages controller discovery and input handling.
@Observable
public final class ControllerManager: @unchecked Sendable {
    public var connectedController: GCController?
    public var controllerState = ControllerState()
    public var currentState = GamepadState()
    public var controllerKind: ControllerKind = .simulated
    public var capabilityProfile: ControllerCapabilityProfile?
    public var isConnected: Bool = false
    public var controllerName: String = "No Controller"
    
    // Input Processors
    public var leftStickProcessor = StickProcessor(profile: .expressive)
    public var rightStickProcessor = StickProcessor(profile: .expressive)
    public var leftTriggerProcessor = TriggerProcessor()
    public var rightTriggerProcessor = TriggerProcessor()
    public var adaptiveTriggerEngine = AdaptiveTriggerEngine()
    public var smartSoloEngine = SmartSoloEngine()
    
    // Input callbacks
    public var onStateChanged: ((ControllerState) -> Void)?
    public var onDisconnected: (() -> Void)?
    
    private var observers: [Any] = []
    private var hapticEngine: CHHapticEngine?
    
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
        controllerName = controller.vendorName ?? controller.productCategory
        controllerKind = identifyControllerKind(controller)
        capabilityProfile = ControllerCapabilityProfile.from(controller)
        
        setupInputHandlers(controller)
        
        // Enable motion if available
        if let motion = controller.motion {
            motion.sensorsActive = true
        }

        prepareHaptics(for: controller)
    }
    
    private func controllerDisconnected() {
        connectedController = nil
        isConnected = false
        controllerName = "No Controller"
        capabilityProfile = nil
        controllerState = ControllerState()
        currentState = GamepadState()
        controllerKind = .simulated
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        onStateChanged?(controllerState)
        onDisconnected?()
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

            // Adaptive trigger feedback processing
            self.adaptiveTriggerEngine.process(
                leftTrigger: gamepad.leftTrigger.value,
                rightTrigger: gamepad.rightTrigger.value,
                controller: controller,
                timestamp: timestamp
            )

            self.currentState = Self.gamepadState(from: state)
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
                self.currentState = Self.gamepadState(from: state)
                self.onStateChanged?(state)
            }
        }
    }

    public var isHardwareConnected: Bool { isConnected }

    public func configureForInstrumentProfile(_ profile: InstrumentProfile) {
        adaptiveTriggerEngine.configureForInstrumentProfile(profile)
    }

    /// Selects a visual/simulated controller family without requiring hardware.
    public func selectControllerKind(_ kind: ControllerKind) {
        controllerKind = kind
        capabilityProfile = Self.capabilityProfile(for: kind)
        if !isConnected {
            controllerName = kind.rawValue
        }
    }

    /// Allows tests, previews, and keyboard fallbacks to drive the same processed callback path.
    public func injectSimulatedState(_ transform: (inout GamepadState) -> Void) {
        var state = currentState
        transform(&state)
        currentState = state
        controllerState = Self.controllerState(from: state)
        onStateChanged?(controllerState)
    }

    /// Plays a single restrained haptic for a discrete technique landmark.
    public func playTechniqueHaptic(_ kind: TechniqueHaptic) {
        guard let engine = hapticEngine else { return }
        let intensity: Float
        let sharpness: Float
        switch kind {
        case .bendDetent:
            intensity = 0.12; sharpness = 0.65
        case .hammerOn, .pullOff:
            intensity = 0.10; sharpness = 0.40
        case .slideArrival:
            intensity = 0.16; sharpness = 0.35
        case .pinchHarmonic:
            intensity = 0.22; sharpness = 0.90
        case .palmMuteThreshold:
            intensity = 0.08; sharpness = 0.20
        }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

    /// Plays one restrained transient when an exact bend target is crossed.
    public func playBendTargetDetent() {
        playTechniqueHaptic(.bendDetent)
    }

    private func prepareHaptics(for controller: GCController) {
        guard capabilityProfile?.hasHaptics == true,
              let engine = controller.haptics?.createEngine(withLocality: .default) else {
            hapticEngine = nil
            return
        }

        do {
            try engine.start()
            hapticEngine = engine
        } catch {
            hapticEngine = nil
        }
    }

    private func identifyControllerKind(_ controller: GCController) -> ControllerKind {
        let identity = "\(controller.vendorName ?? "") \(controller.productCategory)".lowercased()
        if identity.contains("dualsense") || identity.contains("ps5") { return .dualSense }
        if identity.contains("dualshock") || identity.contains("ps4") { return .dualShock4 }
        if identity.contains("xbox") { return .xbox }
        if identity.contains("switch") || identity.contains("pro controller") { return .switchPro }
        if identity.contains("steam") { return .steamDeck }
        return .generic
    }

    private static func capabilityProfile(for kind: ControllerKind) -> ControllerCapabilityProfile {
        switch kind {
        case .dualSense, .dualShock4: return .dualSense
        case .xbox: return .xbox
        case .switchPro: return .switchPro
        case .steamDeck: return .steamDeck
        case .guitarHero: return .guitarHero
        case .soundVoltex: return .soundVoltex
        case .beatmaniaIIDX: return .beatmaniaIIDX
        case .popnMusic: return .popnMusic
        case .taikoDrum: return .taikoDrum
        case .danceMat: return .danceMat
        case .flightStick: return .flightStick
        case .racingWheel: return .racingWheel
        case .fightStick: return .fightStick
        case .generic, .simulated: return .generic
        }
    }

    private static func gamepadState(from state: ControllerState) -> GamepadState {
        GamepadState(
            leftStick: StickCoordinates(x: Double(state.leftStick.x), y: Double(state.leftStick.y)),
            rightStick: StickCoordinates(x: Double(state.rightStick.x), y: Double(state.rightStick.y)),
            leftTrigger: Double(state.leftTrigger.value),
            rightTrigger: Double(state.rightTrigger.value),
            leftShoulder: state.leftShoulder,
            rightShoulder: state.rightShoulder,
            buttonA: state.buttonA,
            buttonB: state.buttonB,
            buttonX: state.buttonX,
            buttonY: state.buttonY,
            dpadUp: state.dpadUp,
            dpadDown: state.dpadDown,
            dpadLeft: state.dpadLeft,
            dpadRight: state.dpadRight,
            leftStickClick: state.leftStickButton,
            rightStickClick: state.rightStickButton,
            touchX: Double(state.touchpadX),
            touchY: Double(state.touchpadY),
            isTouching: state.touchpadActive,
            gyroPitch: state.gyroX,
            gyroRoll: state.gyroY,
            gyroYaw: state.gyroZ
        )
    }

    private static func controllerState(from state: GamepadState) -> ControllerState {
        let processed = ControllerState()
        processed.leftStick = ProcessedStickState(
            rawX: Float(state.leftStick.x),
            rawY: Float(state.leftStick.y),
            x: Float(state.leftStick.x),
            y: Float(state.leftStick.y),
            radius: Float(state.leftStick.radius),
            angle: state.leftStick.angle,
            isInDeadzone: !state.leftStick.isActive,
            isNearEdge: state.leftStick.radius > 0.95
        )
        processed.rightStick = ProcessedStickState(
            rawX: Float(state.rightStick.x),
            rawY: Float(state.rightStick.y),
            x: Float(state.rightStick.x),
            y: Float(state.rightStick.y),
            radius: Float(state.rightStick.radius),
            angle: state.rightStick.angle,
            isInDeadzone: !state.rightStick.isActive,
            isNearEdge: state.rightStick.radius > 0.95
        )
        processed.leftTrigger = ProcessedTriggerState(
            rawValue: Float(state.leftTrigger),
            value: Float(state.leftTrigger),
            isPressed: state.leftTrigger > 0.1
        )
        processed.rightTrigger = ProcessedTriggerState(
            rawValue: Float(state.rightTrigger),
            value: Float(state.rightTrigger),
            isPressed: state.rightTrigger > 0.1
        )
        processed.leftShoulder = state.leftShoulder
        processed.rightShoulder = state.rightShoulder
        processed.buttonA = state.buttonA
        processed.buttonB = state.buttonB
        processed.buttonX = state.buttonX
        processed.buttonY = state.buttonY
        processed.dpadUp = state.dpadUp
        processed.dpadDown = state.dpadDown
        processed.dpadLeft = state.dpadLeft
        processed.dpadRight = state.dpadRight
        processed.leftStickButton = state.leftStickClick
        processed.rightStickButton = state.rightStickClick
        processed.touchpadX = Float(state.touchX)
        processed.touchpadY = Float(state.touchY)
        processed.touchpadActive = state.isTouching
        processed.gyroX = state.gyroPitch
        processed.gyroY = state.gyroRoll
        processed.gyroZ = state.gyroYaw
        processed.hasMotion = state.gyroPitch != 0 || state.gyroRoll != 0 || state.gyroYaw != 0
        return processed
    }
}
