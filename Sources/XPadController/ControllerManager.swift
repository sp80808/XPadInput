import Foundation
import GameController
import CoreHaptics
import XPadCore

/// Manages controller discovery, hardware calibration, input learning, and semantic action mapping.
@Observable
public final class ControllerManager: @unchecked Sendable {
    public var connectedController: GCController?
    public var controllerState = ControllerState()
    public var currentState = GamepadState()
    public var controllerKind: ControllerKind = .simulated
    public var capabilityProfile: ControllerCapabilityProfile?
    public var isConnected: Bool = false
    public var controllerName: String = "No Controller"
    
    // Active Control Scheme & Calibration
    public var activeScheme: ControlScheme = ControlSchemePreset.xpiPerformance
    public var hardwareCalibration = ControllerHardwareCalibration()
    public var calibrationWizard = CalibrationWizard()
    
    // Input Processors
    public var analogPipeline = AnalogControlPipeline()
    public var adaptiveTriggerEngine = AdaptiveTriggerEngine()
    public var smartSoloEngine = SmartSoloEngine()

    public var leftStickProcessor: StickProcessor {
        get { analogPipeline.leftStickProcessor }
        set { analogPipeline.leftStickProcessor = newValue }
    }

    public var rightStickProcessor: StickProcessor {
        get { analogPipeline.rightStickProcessor }
        set { analogPipeline.rightStickProcessor = newValue }
    }

    public var leftTriggerProcessor: TriggerProcessor {
        get { analogPipeline.leftTriggerProcessor }
        set { analogPipeline.leftTriggerProcessor = newValue }
    }

    public var rightTriggerProcessor: TriggerProcessor {
        get { analogPipeline.rightTriggerProcessor }
        set { analogPipeline.rightTriggerProcessor = newValue }
    }
    
    // Input Learn Mode
    public var learningAction: SemanticMusicalAction? = nil
    public var onInputLearned: ((SemanticMusicalAction, PhysicalControlInput) -> Void)?
    
    // Input callbacks
    public var onStateChanged: ((ControllerState) -> Void)?
    public var onDisconnected: (() -> Void)?
    
    private var observers: [Any] = []
    private var hapticEngine: CHHapticEngine?
    
    public init() {
        loadPersistedSchemeAndCalibration()
        setupNotifications()
        scanForControllers()
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    private func loadPersistedSchemeAndCalibration() {
        let store = ControllerSettingsStore.shared
        let activeId = store.loadActiveSchemeId()
        let customSchemes = store.loadCustomSchemes()
        
        if let found = (ControlSchemePreset.allBuiltIn + customSchemes).first(where: { $0.id == activeId }) {
            self.activeScheme = found
        } else {
            self.activeScheme = ControlSchemePreset.xpiPerformance
        }
        
        applySchemeToProcessors(self.activeScheme)
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
        
        // Load controller-specific calibration
        let controllerId = "\(controller.vendorName ?? "generic")_\(controller.productCategory)"
        hardwareCalibration = ControllerSettingsStore.shared.loadCalibration(for: controllerId)
        applyCalibrationToProcessors()
        
        setupInputHandlers(controller)
        
        if let motion = controller.motion, activeScheme.isMotionEnabled {
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
    
    // MARK: - Control Scheme & Calibration Application
    
    public func selectControlScheme(_ scheme: ControlScheme) {
        self.activeScheme = scheme
        ControllerSettingsStore.shared.saveActiveSchemeId(scheme.id)
        applySchemeToProcessors(scheme)
        
        // Motion enable/disable
        if let motion = connectedController?.motion {
            motion.sensorsActive = scheme.isMotionEnabled
        }
    }
    
    public func applyHardwareCalibration(_ cal: ControllerHardwareCalibration) {
        self.hardwareCalibration = cal
        ControllerSettingsStore.shared.saveCalibration(cal)
        applyCalibrationToProcessors()
    }
    
    private func applySchemeToProcessors(_ scheme: ControlScheme) {
        leftStickProcessor.profile = scheme.stickFeel.processingProfile
        rightStickProcessor.profile = scheme.stickFeel.processingProfile
        leftTriggerProcessor.deadzone = scheme.triggerFeel.activationThreshold
        rightTriggerProcessor.deadzone = scheme.triggerFeel.activationThreshold
    }
    
    private func applyCalibrationToProcessors() {
        leftStickProcessor.calibration = hardwareCalibration.leftStick
        rightStickProcessor.calibration = hardwareCalibration.rightStick
        leftTriggerProcessor.calibration = hardwareCalibration.leftTrigger
        rightTriggerProcessor.calibration = hardwareCalibration.rightTrigger
    }
    
    // MARK: - Input Handlers & Input Learn
    
    private func setupInputHandlers(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        gamepad.valueChangedHandler = { [weak self] (gamepad, element) in
            guard let self = self else { return }
            
            let rawLX = gamepad.leftThumbstick.xAxis.value
            let rawLY = gamepad.leftThumbstick.yAxis.value
            let rawRX = gamepad.rightThumbstick.xAxis.value
            let rawRY = gamepad.rightThumbstick.yAxis.value
            let rawLT = gamepad.leftTrigger.value
            let rawRT = gamepad.rightTrigger.value
            
            // Feed calibration wizard if active
            self.calibrationWizard.feed(rawLeftX: rawLX, rawLeftY: rawLY, rawRightX: rawRX, rawRightY: rawRY)
            
            // Check Input Learn
            if let targetAction = self.learningAction {
                if let detected = self.detectDeliberateInput(gamepad: gamepad) {
                    self.learningAction = nil
                    self.onInputLearned?(targetAction, detected)
                    self.playTechniqueHaptic(.buttonConfirm)
                    return
                }
            }
            
            let state = self.controllerState
            let swapRoles = self.activeScheme.isLeftRightSwapped
            let timestamp = Self.analogEventTimestamp(from: gamepad)
            let snapshot = RawAnalogSnapshot(
                leftStickX: rawLX,
                leftStickY: rawLY,
                rightStickX: rawRX,
                rightStickY: rawRY,
                leftTrigger: rawLT,
                rightTrigger: rawRT
            )
            let changedAnalog = Self.physicalAnalogControls(changedBy: element, on: gamepad)
            self.ingestAnalogSnapshot(
                snapshot,
                changedPhysicalControls: changedAnalog,
                timestamp: timestamp
            )
            
            // Shoulders
            state.leftShoulder = swapRoles ? gamepad.rightShoulder.isPressed : gamepad.leftShoulder.isPressed
            state.rightShoulder = swapRoles ? gamepad.leftShoulder.isPressed : gamepad.rightShoulder.isPressed
            
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
            state.leftStickButton = swapRoles ? (gamepad.rightThumbstickButton?.isPressed ?? false) : (gamepad.leftThumbstickButton?.isPressed ?? false)
            state.rightStickButton = swapRoles ? (gamepad.leftThumbstickButton?.isPressed ?? false) : (gamepad.rightThumbstickButton?.isPressed ?? false)
            
            // Menu
            state.menuButton = gamepad.buttonMenu.isPressed
            state.optionsButton = gamepad.buttonOptions?.isPressed ?? false

            // Adaptive trigger feedback processing
            self.adaptiveTriggerEngine.process(
                leftTrigger: rawLT,
                rightTrigger: rawRT,
                controller: controller,
                timestamp: timestamp
            )

            self.currentState = Self.gamepadState(from: self.controllerState)
            self.onStateChanged?(self.controllerState)
        }
        
        // Motion handling
        if let motion = controller.motion {
            motion.valueChangedHandler = { [weak self] (motion) in
                guard let self = self else { return }
                guard self.activeScheme.isMotionEnabled else { return }
                
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
    
    /// Detects a deliberate button press or stick excursion while ignoring resting drift (<0.20).
    private func detectDeliberateInput(gamepad: GCExtendedGamepad) -> PhysicalControlInput? {
        if gamepad.buttonA.isPressed { return .buttonSouth }
        if gamepad.buttonB.isPressed { return .buttonEast }
        if gamepad.buttonX.isPressed { return .buttonWest }
        if gamepad.buttonY.isPressed { return .buttonNorth }
        
        if gamepad.leftShoulder.isPressed { return .leftShoulder }
        if gamepad.rightShoulder.isPressed { return .rightShoulder }
        if gamepad.leftTrigger.value > 0.40 { return .leftTrigger }
        if gamepad.rightTrigger.value > 0.40 { return .rightTrigger }
        
        if gamepad.dpad.up.isPressed { return .dpadUp }
        if gamepad.dpad.down.isPressed { return .dpadDown }
        if gamepad.dpad.left.isPressed { return .dpadLeft }
        if gamepad.dpad.right.isPressed { return .dpadRight }
        
        if gamepad.leftThumbstickButton?.isPressed == true { return .leftStickClick }
        if gamepad.rightThumbstickButton?.isPressed == true { return .rightStickClick }
        
        if abs(gamepad.leftThumbstick.xAxis.value) > 0.55 { return .leftStickX }
        if abs(gamepad.leftThumbstick.yAxis.value) > 0.55 { return .leftStickY }
        if abs(gamepad.rightThumbstick.xAxis.value) > 0.55 { return .rightStickX }
        if abs(gamepad.rightThumbstick.yAxis.value) > 0.55 { return .rightStickY }
        
        if gamepad.buttonOptions?.isPressed == true { return .buttonOptions }
        if gamepad.buttonMenu.isPressed { return .buttonShare }
        
        return nil
    }

    // MARK: - Dynamic Prompt Single-Source-of-Truth
    
    /// Returns the localized, controller-aware label for a musical action (e.g. "R2" on DualSense, "RT" on Xbox, "Right Stick Y").
    public func controlLabel(for action: SemanticMusicalAction) -> String {
        guard let binding = activeScheme.binding(for: action) else {
            return "Unassigned"
        }
        return physicalLabel(for: binding.input)
    }

    /// Returns the high-fidelity controller glyph for rendering on HUD badges and chord cards.
    public func controlGlyph(for action: SemanticMusicalAction) -> GlyphKey {
        guard let binding = activeScheme.binding(for: action) else {
            return .leftStick
        }
        return binding.input.defaultGlyphKey
    }

    /// Formats a physical control name based on the connected controller hardware style.
    public func physicalLabel(for input: PhysicalControlInput) -> String {
        let isXbox = controllerKind == .xbox
        let isNintendo = controllerKind == .switchPro
        
        switch input {
        case .leftStick2D: return "Left Stick"
        case .rightStick2D: return "Right Stick"
        case .leftStickX: return "Left Stick X"
        case .leftStickY: return "Left Stick Y"
        case .rightStickX: return "Right Stick X"
        case .rightStickY: return "Right Stick Y"
        case .leftTrigger: return isXbox ? "LT" : (isNintendo ? "ZL" : "L2")
        case .rightTrigger: return isXbox ? "RT" : (isNintendo ? "ZR" : "R2")
        case .leftShoulder: return isXbox ? "LB" : (isNintendo ? "L" : "L1")
        case .rightShoulder: return isXbox ? "RB" : (isNintendo ? "R" : "R1")
        case .leftStickClick: return isXbox ? "LSB" : (isNintendo ? "L3" : "L3")
        case .rightStickClick: return isXbox ? "RSB" : (isNintendo ? "R3" : "R3")
        case .buttonSouth: return isXbox ? "A" : (isNintendo ? "B" : "✕ Cross")
        case .buttonEast: return isXbox ? "B" : (isNintendo ? "A" : "○ Circle")
        case .buttonWest: return isXbox ? "X" : (isNintendo ? "Y" : "□ Square")
        case .buttonNorth: return isXbox ? "Y" : (isNintendo ? "X" : "△ Triangle")
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .buttonOptions: return isXbox ? "Menu" : (isNintendo ? "+" : "Options")
        case .buttonShare: return isXbox ? "View" : (isNintendo ? "-" : "Share")
        case .buttonCenter: return "Touchpad"
        case .touchpad2D: return "Touchpad"
        case .motionPitch: return "Tilt (Pitch)"
        case .motionRoll: return "Tilt (Roll)"
        case .motionYaw: return "Tilt (Yaw)"
        case .unassigned: return "—"
        }
    }

    public func selectControllerKind(_ kind: ControllerKind) {
        controllerKind = kind
    }

    /// Advances analog processors for the controls that actually changed.
    /// Digital-only events pass an empty set so stick/trigger history is preserved.
    public func ingestAnalogSnapshot(
        _ snapshot: RawAnalogSnapshot,
        changedPhysicalControls: Set<PhysicalAnalogControl>,
        timestamp: TimeInterval
    ) {
        guard !changedPhysicalControls.isEmpty else { return }

        analogPipeline.process(
            snapshot: snapshot,
            changedPhysicalControls: changedPhysicalControls,
            swapLeftRight: activeScheme.isLeftRightSwapped,
            timestamp: timestamp
        )

        let state = controllerState
        let swap = activeScheme.isLeftRightSwapped
        for physical in changedPhysicalControls {
            switch physical.musicalRole(swapLeftRight: swap) {
            case .leftStick:
                state.leftStick = analogPipeline.leftStick
            case .rightStick:
                state.rightStick = analogPipeline.rightStick
            case .leftTrigger:
                state.leftTrigger = analogPipeline.leftTrigger
            case .rightTrigger:
                state.rightTrigger = analogPipeline.rightTrigger
            }
        }
    }

    static func analogEventTimestamp(from gamepad: GCExtendedGamepad) -> TimeInterval {
        let frameworkTimestamp = gamepad.lastEventTimestamp
        if frameworkTimestamp.isFinite, frameworkTimestamp > 0 {
            return frameworkTimestamp
        }
        return ProcessInfo.processInfo.systemUptime
    }

    static func physicalAnalogControls(
        changedBy element: GCControllerElement,
        on gamepad: GCExtendedGamepad
    ) -> Set<PhysicalAnalogControl> {
        if element === gamepad.leftThumbstick
            || element === gamepad.leftThumbstick.xAxis
            || element === gamepad.leftThumbstick.yAxis {
            return [.leftStick]
        }
        if element === gamepad.rightThumbstick
            || element === gamepad.rightThumbstick.xAxis
            || element === gamepad.rightThumbstick.yAxis {
            return [.rightStick]
        }
        if element === gamepad.leftTrigger {
            return [.leftTrigger]
        }
        if element === gamepad.rightTrigger {
            return [.rightTrigger]
        }
        return []
    }

    public func injectSimulatedState(_ mutate: (ControllerState) -> Void) {
        let state = controllerState
        mutate(state)
        currentState = Self.gamepadState(from: state)
        onStateChanged?(state)
    }

    public func configureForInstrumentProfile(_ profile: InstrumentProfile) {
        adaptiveTriggerEngine.configureForInstrumentProfile(profile)
    }

    // MARK: - Haptic Feedback
    
    public func playTechniqueHaptic(_ haptic: TechniqueHaptic) {
        guard activeScheme.haptics != .off else { return }
        guard let engine = hapticEngine else { return }
        
        let multiplier: Float = activeScheme.haptics == .subtle ? 0.45 : 1.0
        let intensity = min(1.0, haptic.intensity * multiplier)
        
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: haptic.sharpness)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

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

    public static func gamepadState(from state: ControllerState) -> GamepadState {
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

    public static func controllerState(from state: GamepadState) -> ControllerState {
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
