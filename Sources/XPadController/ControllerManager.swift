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
    public var leftStickProcessor = StickProcessor(profile: .expressive)
    public var rightStickProcessor = StickProcessor(profile: .fast)
    public var rightStickBendProcessor = StickProcessor(profile: .precision)
    public var leftTriggerProcessor = TriggerProcessor()
    public var rightTriggerProcessor = TriggerProcessor()
    public var adaptiveTriggerEngine = AdaptiveTriggerEngine()
    public var smartSoloEngine = SmartSoloEngine()
    public var surfaceProfile = ControlSurfaceProfile()
    public var remapSnapshot = ControllerRemapSnapshot()
    public var lastErgonomicWarnings: [ErgonomicWarning] = []
    public var surfaceResolver = ControlSurfaceResolver()
    public let performanceState = ControllerState()
    public private(set) var surfaceFrame = ControlSurfaceFrame()
    
    // Input Learn Mode
    public var learningAction: SemanticMusicalAction? = nil
    public var onInputLearned: ((SemanticMusicalAction, PhysicalControlInput) -> Void)?
    
    // Input callbacks
    public var onStateChanged: ((ControllerState) -> Void)?
    public var onDisconnected: (() -> Void)?
    public var onSchemeChanged: ((ControlScheme) -> Void)?
    
    private var observers: [Any] = []
    private var hapticEngine: CHHapticEngine?
    private var leftPassiveLearner = PassiveCalibrationLearner()
    private var rightPassiveLearner = PassiveCalibrationLearner()
    private var lastCalibrationPersist: TimeInterval = 0
    private var connectedControllerId: String?
    
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
        applySurfaceProfile(store.loadSurfaceProfile(), persist: false)
        surfaceResolver.scheme = self.activeScheme
        refreshErgonomicWarnings()
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

        let remapObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerUserCustomizationsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self?.connectedController else { return }
            self?.refreshRemapSnapshot(from: controller)
        }

        observers = [connectObserver, disconnectObserver, remapObserver]
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
        connectedControllerId = controllerId
        hardwareCalibration = ControllerSettingsStore.shared.loadCalibration(for: controllerId)
        applyCalibrationToProcessors()
        refreshRemapSnapshot(from: controller)
        adaptiveTriggerEngine.resetHardwareCache()
        adaptiveTriggerEngine.forcePolicy = surfaceProfile.triggerForce

        setupInputHandlers(controller)
        
        if let motion = controller.motion, activeScheme.isMotionEnabled && surfaceProfile.motionEnabled {
            motion.sensorsActive = true
        }

        prepareHaptics(for: controller)
    }
    
    private func controllerDisconnected() {
        if let id = connectedControllerId {
            var cal = hardwareCalibration
            cal.controllerIdentifier = id
            ControllerSettingsStore.shared.saveCalibration(cal)
        }
        connectedController = nil
        isConnected = false
        controllerName = "No Controller"
        capabilityProfile = nil
        connectedControllerId = nil
        remapSnapshot = ControllerRemapSnapshot()
        controllerState = ControllerState()
        currentState = GamepadState()
        controllerKind = .simulated
        adaptiveTriggerEngine.resetHardwareCache()
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        refreshPerformanceSurface()
        onStateChanged?(performanceState)
        onDisconnected?()
    }
    
    // MARK: - Control Scheme & Calibration Application
    
    public func selectControlScheme(_ scheme: ControlScheme) {
        self.activeScheme = scheme
        ControllerSettingsStore.shared.saveActiveSchemeId(scheme.id)
        applySchemeToProcessors(scheme)
        surfaceResolver.scheme = scheme
        surfaceResolver.reset()
        refreshPerformanceSurface()
        refreshErgonomicWarnings()
        
        // Motion enable/disable
        if let motion = connectedController?.motion {
            motion.sensorsActive = scheme.isMotionEnabled && surfaceProfile.motionEnabled
        }
        onSchemeChanged?(scheme)
    }

    public func applySurfaceProfile(_ profile: ControlSurfaceProfile, persist: Bool = true) {
        surfaceProfile = profile
        if persist {
            ControllerSettingsStore.shared.saveSurfaceProfile(profile)
        }
        applySchemeToProcessors(activeScheme)
        adaptiveTriggerEngine.forcePolicy = profile.triggerForce
        if !profile.motionEnabled, let motion = connectedController?.motion {
            motion.sensorsActive = false
        } else if profile.motionEnabled, let motion = connectedController?.motion {
            motion.sensorsActive = activeScheme.isMotionEnabled
        }
        refreshErgonomicWarnings()
    }
    
    public func applyHardwareCalibration(_ cal: ControllerHardwareCalibration) {
        self.hardwareCalibration = cal
        ControllerSettingsStore.shared.saveCalibration(cal)
        applyCalibrationToProcessors()
    }
    
    private func applySchemeToProcessors(_ scheme: ControlScheme) {
        leftStickProcessor.profile = surfaceProfile.harmonyStick
        rightStickProcessor.profile = surfaceProfile.strumStick
        rightStickBendProcessor.profile = surfaceProfile.bendStick
        leftTriggerProcessor.deadzone = scheme.triggerFeel.activationThreshold
        rightTriggerProcessor.deadzone = scheme.triggerFeel.activationThreshold
        leftTriggerProcessor.responseCurve = scheme.triggerFeel.responseCurve
        rightTriggerProcessor.responseCurve = scheme.triggerFeel.responseCurve
        adaptiveTriggerEngine.forcePolicy = surfaceProfile.triggerForce
    }
    
    private func applyCalibrationToProcessors() {
        leftStickProcessor.calibration = hardwareCalibration.leftStick
        rightStickProcessor.calibration = hardwareCalibration.rightStick
        rightStickBendProcessor.calibration = hardwareCalibration.rightStick
        leftTriggerProcessor.calibration = hardwareCalibration.leftTrigger
        rightTriggerProcessor.calibration = hardwareCalibration.rightTrigger
    }

    public var rolesAreSwapped: Bool {
        activeScheme.isLeftRightSwapped != surfaceProfile.mirrored
    }

    public func refreshErgonomicWarnings() {
        let caps = capabilityProfile ?? ControllerCapabilityProfile.preset(for: controllerKind)
        lastErgonomicWarnings = ErgonomicMappingAnalyzer.analyze(
            scheme: activeScheme,
            grip: surfaceProfile.grip,
            hasTouchpad: caps.hasTouchpad
        )
    }

    public func refreshRemapSnapshot(from controller: GCController) {
        remapSnapshot = ControllerRemapCapture.snapshot(from: controller)
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
            let timestamp = ProcessInfo.processInfo.systemUptime
            
            // Process Left & Right Sticks with Calibration, Deadzones & Inversion
            let swapRoles = self.rolesAreSwapped
            let leftX = swapRoles ? rawRX : rawLX
            let leftY = swapRoles ? rawRY : rawLY
            let rightX = swapRoles ? rawLX : rawRX
            let rightY = swapRoles ? rawLY : rawRY
            
            let leftProcessed = self.leftStickProcessor.process(rawX: leftX, rawY: leftY, timestamp: timestamp)
            let strumProcessed = self.rightStickProcessor.process(rawX: rightX, rawY: rightY, timestamp: timestamp)
            let bendProcessed = self.rightStickBendProcessor.process(rawX: rightX, rawY: rightY, timestamp: timestamp)
            state.leftStick = leftProcessed
            state.rightStick = ProcessedStickState.composing(strum: strumProcessed, bend: bendProcessed)

            self.observePassiveCalibration(
                rawLX: leftX, rawLY: leftY, leftProcessed: leftProcessed,
                rawRX: rightX, rawRY: rightY, rightProcessed: state.rightStick,
                timestamp: timestamp
            )
            
            // Process Triggers with Calibration & Hysteresis
            let triggerL = swapRoles ? rawRT : rawLT
            let triggerR = swapRoles ? rawLT : rawRT
            state.leftTrigger = self.leftTriggerProcessor.process(rawValue: triggerL, timestamp: timestamp)
            state.rightTrigger = self.rightTriggerProcessor.process(rawValue: triggerR, timestamp: timestamp)
            
            // Shoulders
            state.leftShoulder = swapRoles ? gamepad.rightShoulder.isPressed : gamepad.leftShoulder.isPressed
            state.rightShoulder = swapRoles ? gamepad.leftShoulder.isPressed : gamepad.rightShoulder.isPressed
            
            // Face buttons (digital + analog value when the element reports analog)
            state.buttonA = gamepad.buttonA.isPressed
            state.buttonB = gamepad.buttonB.isPressed
            state.buttonX = gamepad.buttonX.isPressed
            state.buttonY = gamepad.buttonY.isPressed
            state.buttonAValue = ControllerRemapCapture.analogValue(gamepad.buttonA)
            state.buttonBValue = ControllerRemapCapture.analogValue(gamepad.buttonB)
            state.buttonXValue = ControllerRemapCapture.analogValue(gamepad.buttonX)
            state.buttonYValue = ControllerRemapCapture.analogValue(gamepad.buttonY)
            
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

            // Touchpad surface vs click — capability gated, cleared when unsupported
            let caps = self.capabilityProfile ?? ControllerCapabilityProfile.preset(for: self.controllerKind)
            let touch = ControllerTouchpadReader.read(
                from: controller,
                hasTouchpad: caps.hasTouchpad,
                enabled: self.surfaceProfile.touchpadEnabled
            )
            state.touchpadX = touch.x
            state.touchpadY = touch.y
            state.touchpadActive = touch.surface
            state.touchpadButtonPressed = touch.button

            var analogSnapshot = self.remapSnapshot
            analogSnapshot.analogByInput[.buttonSouth] = state.buttonAValue
            analogSnapshot.analogByInput[.buttonEast] = state.buttonBValue
            analogSnapshot.analogByInput[.buttonWest] = state.buttonXValue
            analogSnapshot.analogByInput[.buttonNorth] = state.buttonYValue
            analogSnapshot.analogByInput[.leftTrigger] = state.leftTrigger.value
            analogSnapshot.analogByInput[.rightTrigger] = state.rightTrigger.value
            self.remapSnapshot = analogSnapshot

            // Adaptive trigger feedback processing
            self.adaptiveTriggerEngine.forcePolicy = self.surfaceProfile.triggerForce
            self.adaptiveTriggerEngine.process(
                leftTrigger: rawLT,
                rightTrigger: rawRT,
                controller: controller,
                timestamp: timestamp
            )

            self.currentState = Self.gamepadState(from: state)
            self.refreshPerformanceSurface()
            self.onStateChanged?(self.performanceState)
        }
        
        // Motion handling
        if let motion = controller.motion {
            motion.valueChangedHandler = { [weak self] (motion) in
                guard let self = self else { return }
                guard self.activeScheme.isMotionEnabled && self.surfaceProfile.motionEnabled else { return }
                
                let state = self.controllerState
                state.gyroX = motion.rotationRate.x
                state.gyroY = motion.rotationRate.y
                state.gyroZ = motion.rotationRate.z
                state.accelX = motion.userAcceleration.x
                state.accelY = motion.userAcceleration.y
                state.accelZ = motion.userAcceleration.z
                state.hasMotion = true
                self.currentState = Self.gamepadState(from: state)
                self.refreshPerformanceSurface()
                self.onStateChanged?(self.performanceState)
            }
        }
    }
    
    /// Detects a deliberate button press or stick excursion while ignoring resting drift (<0.20).
    private func detectDeliberateInput(gamepad: GCExtendedGamepad) -> PhysicalControlInput? {
        InputLearnDetector.detect(
            leftStickX: gamepad.leftThumbstick.xAxis.value,
            leftStickY: gamepad.leftThumbstick.yAxis.value,
            rightStickX: gamepad.rightThumbstick.xAxis.value,
            rightStickY: gamepad.rightThumbstick.yAxis.value,
            leftTrigger: gamepad.leftTrigger.value,
            rightTrigger: gamepad.rightTrigger.value,
            leftShoulder: gamepad.leftShoulder.isPressed,
            rightShoulder: gamepad.rightShoulder.isPressed,
            buttonSouth: gamepad.buttonA.isPressed,
            buttonEast: gamepad.buttonB.isPressed,
            buttonWest: gamepad.buttonX.isPressed,
            buttonNorth: gamepad.buttonY.isPressed,
            dpadUp: gamepad.dpad.up.isPressed,
            dpadDown: gamepad.dpad.down.isPressed,
            dpadLeft: gamepad.dpad.left.isPressed,
            dpadRight: gamepad.dpad.right.isPressed,
            leftStickClick: gamepad.leftThumbstickButton?.isPressed == true,
            rightStickClick: gamepad.rightThumbstickButton?.isPressed == true,
            options: gamepad.buttonMenu.isPressed,
            share: gamepad.buttonOptions?.isPressed ?? false,
            prefer2D: learningAction?.compatibilityType == .continuous2D
        )
    }

    public func refreshPerformanceSurface(timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        surfaceResolver.scheme = activeScheme
        surfaceFrame = surfaceResolver.evaluate(state: controllerState, timestamp: timestamp)
        surfaceResolver.project(frame: surfaceFrame, physical: controllerState, onto: performanceState)
        currentState = Self.gamepadState(from: performanceState)
    }

    // MARK: - Dynamic Prompt Single-Source-of-Truth
    
    /// Returns the localized, controller-aware label for a musical action (e.g. "R2" on DualSense, "RT" on Xbox, "Right Stick Y").
    public func controlLabel(for action: SemanticMusicalAction) -> String {
        guard let binding = activeScheme.binding(for: action) else {
            return "Unassigned"
        }
        let displayed = ControllerRemapResolver.displayedInput(for: binding.input, snapshot: remapSnapshot)
        return physicalLabel(for: displayed)
    }

    /// Returns the high-fidelity controller glyph for rendering on HUD badges and chord cards.
    public func controlGlyph(for action: SemanticMusicalAction) -> GlyphKey {
        guard let binding = activeScheme.binding(for: action) else {
            return .leftStick
        }
        let displayed = ControllerRemapResolver.displayedInput(for: binding.input, snapshot: remapSnapshot)
        return displayed.defaultGlyphKey
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

    public func injectSimulatedState(_ mutate: (ControllerState) -> Void) {
        let state = controllerState
        mutate(state)
        refreshPerformanceSurface()
        onStateChanged?(performanceState)
    }

    public func configureForInstrumentProfile(_ profile: InstrumentProfile) {
        adaptiveTriggerEngine.configureForInstrumentProfile(profile)
    }

    private func observePassiveCalibration(
        rawLX: Float, rawLY: Float, leftProcessed: ProcessedStickState,
        rawRX: Float, rawRY: Float, rightProcessed: ProcessedStickState,
        timestamp: TimeInterval
    ) {
        let previous = hardwareCalibration
        var next = previous
        next.leftStick = leftPassiveLearner.observe(
            rawX: rawLX,
            rawY: rawLY,
            processedRadius: leftProcessed.radius,
            into: next.leftStick
        )
        next.rightStick = rightPassiveLearner.observe(
            rawX: rawRX,
            rawY: rawRY,
            processedRadius: rightProcessed.radius,
            into: next.rightStick
        )
        guard next != previous else { return }
        hardwareCalibration = next
        applyCalibrationToProcessors()
        if timestamp - lastCalibrationPersist > 2.5, let id = connectedControllerId {
            var persisted = next
            persisted.controllerIdentifier = id
            ControllerSettingsStore.shared.saveCalibration(persisted)
            lastCalibrationPersist = timestamp
        }
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
            touchpadButtonPressed: state.touchpadButtonPressed,
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
        processed.touchpadButtonPressed = state.touchpadButtonPressed
        processed.gyroX = state.gyroPitch
        processed.gyroY = state.gyroRoll
        processed.gyroZ = state.gyroYaw
        processed.hasMotion = state.gyroPitch != 0 || state.gyroRoll != 0 || state.gyroYaw != 0
        return processed
    }
}
