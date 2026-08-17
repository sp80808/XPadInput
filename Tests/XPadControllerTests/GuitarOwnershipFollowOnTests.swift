import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadController

final class GuitarOwnershipFollowOnTests: XCTestCase {

    // MARK: - #24 Control surface + passive calibration

    func testRoleSpecificStickProfilesDiffer() {
        let surface = ControlSurfaceProfile(feel: .natural)
        XCTAssertEqual(surface.harmonyStick.id, "expressive")
        XCTAssertEqual(surface.strumStick.id, "fast")
        XCTAssertEqual(surface.bendStick.id, "precision")

        let reduced = ControlSurfaceProfile(feel: .reducedTravel)
        XCTAssertEqual(reduced.harmonyStick.id, "reducedTravel")
        XCTAssertEqual(reduced.strumStick.id, "reducedTravel")
        XCTAssertEqual(reduced.bendStick.id, "reducedTravel")

        var harmony = StickProcessor(profile: surface.harmonyStick)
        var strum = StickProcessor(profile: surface.strumStick)
        var bend = StickProcessor(profile: surface.bendStick)
        let h = harmony.process(rawX: 0.4, rawY: 0.0, timestamp: 0.1)
        let s = strum.process(rawX: 0.4, rawY: 0.0, timestamp: 0.1)
        let b = bend.process(rawX: 0.4, rawY: 0.0, timestamp: 0.1)
        XCTAssertGreaterThan(abs(h.x - s.x), 0.001)
        XCTAssertGreaterThan(abs(s.x - b.x), 0.001)
    }

    func testComposedRightStickUsesBendXAndStrumY() {
        let strum = ProcessedStickState(x: 0.11, y: 0.80, radius: 0.81)
        let bend = ProcessedStickState(x: 0.55, y: 0.12, radius: 0.56)
        let composed = ProcessedStickState.composing(strum: strum, bend: bend)
        XCTAssertEqual(composed.x, 0.55, accuracy: 0.0001)
        XCTAssertEqual(composed.y, 0.80, accuracy: 0.0001)
    }

    func testPassiveCalibrationBoundsAndIgnoresActiveGestures() {
        var learner = PassiveCalibrationLearner()
        var cal = StickCalibration()

        for i in 0..<60 {
            cal = learner.observe(rawX: 0.20, rawY: 0.0, processedRadius: 0.55, into: cal)
            _ = i
        }
        XCTAssertEqual(cal.restCenterX, 0, accuracy: 0.0001)

        learner.reset()
        for _ in 0..<50 {
            cal = learner.observe(rawX: 0.04, rawY: -0.03, processedRadius: 0.0, into: cal)
        }
        XCTAssertEqual(cal.restCenterX, 0.04, accuracy: 0.005)
        XCTAssertEqual(cal.restCenterY, -0.03, accuracy: 0.005)
        XCTAssertLessThanOrEqual(abs(cal.restCenterX), 0.12)

        cal = learner.observe(rawX: 0.30, rawY: 0.0, processedRadius: 0.0, into: cal)
        XCTAssertLessThanOrEqual(abs(cal.restCenterX), 0.12)

        cal = learner.observe(rawX: 1.4, rawY: 0.0, processedRadius: 0.95, into: cal)
        XCTAssertLessThanOrEqual(cal.maxRadius, 1.15)
        XCTAssertGreaterThanOrEqual(cal.maxRadius, 0.85)
    }

    func testSurfaceProfileCodableRoundtrip() {
        let original = ControlSurfaceProfile(
            feel: .precision,
            mirrored: true,
            triggerForce: .standard,
            grip: .fourFinger
        )
        let data = try XCTUnwrap(try? JSONEncoder().encode(original))
        let loaded = try XCTUnwrap(try? JSONDecoder().decode(ControlSurfaceProfile.self, from: data))
        XCTAssertEqual(loaded.feel, .precision)
        XCTAssertTrue(loaded.mirrored)
        XCTAssertEqual(loaded.triggerForce, .standard)
        XCTAssertEqual(loaded.grip, .fourFinger)
    }

    func testControllerManagerAppliesRoleSpecificSurfaceFeel() {
        let manager = ControllerManager()
        manager.applySurfaceProfile(ControlSurfaceProfile(feel: .fastArcade), persist: false)
        XCTAssertEqual(manager.leftStickProcessor.profile.id, "fast")
        XCTAssertEqual(manager.rightStickProcessor.profile.id, "fast")
        XCTAssertEqual(manager.rightStickBendProcessor.profile.id, "fast")

        manager.applySurfaceProfile(ControlSurfaceProfile(feel: .natural), persist: false)
        XCTAssertEqual(manager.leftStickProcessor.profile.id, "expressive")
        XCTAssertEqual(manager.rightStickProcessor.profile.id, "fast")
        XCTAssertEqual(manager.rightStickBendProcessor.profile.id, "precision")
    }

    // MARK: - #27 Vibrato intent

    func testPeriodicStickVibratoActivatesAndImpulseDoesNot() {
        var engine = VibratoEngine(maxDepthSemitones: 0.2, defaultRateHz: 5.2)
        let dt = 0.008
        var periodic = VibratoState(depth: 0, rate: 5.2, offsetSemitones: 0, regularity: 0, isActive: false)
        for i in 0..<64 {
            let t = Double(i) * dt
            periodic = engine.process(
                stickX: 0.12 * sin(2 * .pi * 6.0 * t),
                stickY: 0,
                gyroPitch: 0,
                gyroYaw: 0,
                triggerMicro: 0,
                noteHeld: true,
                dedicatedBend: false,
                motionEnabled: false,
                dt: dt
            )
        }
        XCTAssertGreaterThan(engine.lastIntent.confidence, 0.2)
        XCTAssertTrue(engine.lastIntent.source == .stick || engine.lastIntent.isPeriodic || periodic.regularity > 0.2)

        engine.reset()
        var impulse = VibratoState(depth: 0, rate: 5.2, offsetSemitones: 0, regularity: 0, isActive: false)
        for i in 0..<24 {
            let gyro = i == 3 ? 0.9 : 0.0
            impulse = engine.process(
                stickX: 0,
                stickY: 0,
                gyroPitch: gyro,
                gyroYaw: 0,
                triggerMicro: 0,
                noteHeld: true,
                dedicatedBend: false,
                motionEnabled: true,
                dt: dt
            )
        }
        XCTAssertFalse(impulse.isActive)
        XCTAssertFalse(engine.lastIntent.isPeriodic)
    }

    func testDedicatedBendDisablesStickVibratoSource() {
        var engine = VibratoEngine()
        let dt = 0.008
        for i in 0..<48 {
            let t = Double(i) * dt
            _ = engine.process(
                stickX: 0.15 * sin(2 * .pi * 5.2 * t),
                stickY: 0,
                gyroPitch: 0,
                gyroYaw: 0,
                triggerMicro: 0,
                noteHeld: true,
                dedicatedBend: true,
                motionEnabled: true,
                dt: dt
            )
        }
        XCTAssertNotEqual(engine.lastIntent.source, .stick)
        XCTAssertFalse(engine.lastIntent.isPeriodic)
    }

    // MARK: - #28 Technique confidence

    func testHammerOnJustInsideAndOutsideWindow() {
        let interpreter = LegatoGestureInterpreter()
        let inside = interpreter.interpret(
            previous: Note(pitchClass: .e, octave: 4),
            current: Note(pitchClass: .g, octave: 4),
            overlap: true,
            intervalMs: 180,
            hasPickAttack: false,
            slideModifier: false,
            profile: .guitar,
            realism: .natural,
            sameString: true,
            preparedLowerNote: false
        )
        XCTAssertEqual(inside?.technique, .hammerOn)

        let outside = interpreter.interpret(
            previous: Note(pitchClass: .e, octave: 4),
            current: Note(pitchClass: .g, octave: 4),
            overlap: true,
            intervalMs: 181,
            hasPickAttack: false,
            slideModifier: false,
            profile: .guitar,
            realism: .natural,
            sameString: true,
            preparedLowerNote: false
        )
        XCTAssertEqual(outside?.technique, .normal)
    }

    func testRealismModeIsAcceptancePolicy() {
        let interpreter = LegatoGestureInterpreter()
        let relaxed = interpreter.infer(
            previous: Note(pitchClass: .e, octave: 4),
            current: Note(pitchClass: .a, octave: 4),
            overlap: true,
            intervalMs: 80,
            hasPickAttack: false,
            slideModifier: false,
            profile: .guitar,
            realism: .relaxed,
            sameString: false,
            preparedLowerNote: false
        )
        XCTAssertEqual(relaxed.interpretation.technique, .hammerOn)
        XCTAssertTrue(relaxed.inference.accepted)

        let strict = interpreter.infer(
            previous: Note(pitchClass: .e, octave: 4),
            current: Note(pitchClass: .a, octave: 4),
            overlap: true,
            intervalMs: 80,
            hasPickAttack: false,
            slideModifier: false,
            profile: .guitar,
            realism: .strict,
            sameString: false,
            preparedLowerNote: false
        )
        XCTAssertEqual(strict.interpretation.technique, .normal)
        XCTAssertFalse(strict.inference.accepted)
        XCTAssertEqual(strict.inference.candidate, .hammerOn)
    }

    func testNaturalHammerOnStillPassesExistingWindow() {
        let result = LegatoGestureInterpreter().interpret(
            previous: Note(pitchClass: .e, octave: 4),
            current: Note(pitchClass: .g, octave: 4),
            overlap: true,
            intervalMs: 80,
            hasPickAttack: false,
            slideModifier: false,
            profile: .guitar,
            realism: .natural,
            sameString: true,
            preparedLowerNote: false
        )
        XCTAssertEqual(result?.technique, .hammerOn)
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.55)
    }

    // MARK: - #29 Adaptive triggers

    func testTriggerCommandEqualityCacheAndForceScale() {
        let config = AdaptiveTriggerConfig(mode: .guitarStringTension, resistiveStrength: 0.7)
        let a = DualSenseHardwareCommand.command(for: config, forceScale: 0.45)
        let b = DualSenseHardwareCommand.command(for: config, forceScale: 0.45)
        let off = DualSenseHardwareCommand.command(for: config, forceScale: 0)
        XCTAssertEqual(a, b)
        XCTAssertEqual(off.kind, .off)

        let engine = AdaptiveTriggerEngine()
        engine.forcePolicy = .off
        let state = engine.calculateTriggerState(
            position: 0.5,
            velocity: 0,
            config: config,
            label: "R2",
            forceScale: 0,
            hardwareSupported: true
        )
        XCTAssertEqual(state.hardwareMode, "off")
        XCTAssertGreaterThan(state.calculatedForce, 0)

        let unsupported = engine.calculateTriggerState(
            position: 0.5,
            velocity: 0,
            config: config,
            label: "RT",
            forceScale: 1,
            hardwareSupported: false
        )
        XCTAssertFalse(unsupported.hardwareSupported)
        XCTAssertEqual(unsupported.hardwareMode, "off")
        XCTAssertGreaterThan(unsupported.calculatedForce, 0)
    }

    func testDetentCountIsCappedAtHardwarePositions() {
        let config = AdaptiveTriggerConfig(mode: .modWheelDetents, detentCount: 12)
        let engine = AdaptiveTriggerEngine()
        let state = engine.calculateTriggerState(
            position: 0.5,
            velocity: 0,
            config: config,
            label: "R2",
            forceScale: 1,
            hardwareSupported: true
        )
        XCTAssertEqual(state.semanticDetentCount, 12)
        XCTAssertEqual(state.renderedDetentCount, DualSenseHardwareCommand.maxPhysicalPositions)
        XCTAssertFalse(state.isHardwareAccurate)
    }

    // MARK: - #30 Touchpad gating

    func testTouchpadCapabilityGating() {
        XCTAssertTrue(ControllerCapabilityProfile.dualSense.hasTouchpad)
        XCTAssertTrue(ControllerCapabilityProfile.dualShock4.hasTouchpad)
        XCTAssertFalse(ControllerCapabilityProfile.xbox.hasTouchpad)
        XCTAssertFalse(ControllerCapabilityProfile.preset(for: .xbox).hasTouchpad)
        XCTAssertTrue(ControllerCapabilityProfile.dualSense.hasAdaptiveTriggers)
        XCTAssertFalse(ControllerCapabilityProfile.dualShock4.hasAdaptiveTriggers)
        XCTAssertFalse(ControllerCapabilityProfile.xbox.hasAdaptiveTriggers)
    }

    func testTouchpadButtonIsDistinctFromSurfaceAndClearsOnReset() {
        let state = ControllerState()
        state.touchpadX = 0.4
        state.touchpadY = -0.2
        state.touchpadActive = true
        state.touchpadButtonPressed = false
        XCTAssertTrue(state.touchpadActive)
        XCTAssertFalse(state.touchpadButtonPressed)

        let gamepad = ControllerManager.gamepadState(from: state)
        XCTAssertTrue(gamepad.isTouching)
        XCTAssertFalse(gamepad.touchpadButtonPressed)
        XCTAssertEqual(gamepad.touchX, 0.4, accuracy: 0.0001)

        let roundtrip = ControllerManager.controllerState(from: GamepadState())
        XCTAssertFalse(roundtrip.touchpadActive)
        XCTAssertFalse(roundtrip.touchpadButtonPressed)
        XCTAssertEqual(roundtrip.touchpadX, 0)
    }

    // MARK: - #25 Remap resolver

    func testRemapAliasResolutionAndAnalogFallback() {
        var snapshot = ControllerRemapSnapshot(
            hasRemappedElements: true,
            physicalNameByAlias: [ControllerRemapResolver.southAlias: "Button X"]
        )
        let displayed = ControllerRemapResolver.displayedInput(for: .buttonSouth, snapshot: snapshot)
        XCTAssertEqual(displayed, .buttonWest)
        XCTAssertEqual(ControllerRemapResolver.displayedInput(for: .rightStickY, snapshot: snapshot), .rightStickY)

        snapshot.analogByInput[.buttonSouth] = 0.42
        XCTAssertEqual(ControllerRemapResolver.analogValue(for: .buttonSouth, snapshot: snapshot, digitalPressed: true), 0.42, accuracy: 0.0001)
        XCTAssertEqual(ControllerRemapResolver.analogValue(for: .buttonEast, snapshot: snapshot, digitalPressed: true), 1)
        XCTAssertEqual(ControllerRemapResolver.analogValue(for: .buttonEast, snapshot: snapshot, digitalPressed: false), 0)
    }

    func testHUDUsesRemappedPhysicalInput() {
        let manager = ControllerManager()
        manager.remapSnapshot = ControllerRemapSnapshot(
            hasRemappedElements: true,
            physicalNameByAlias: [ControllerRemapResolver.southAlias: "Button Y"]
        )
        XCTAssertEqual(
            ControllerRemapResolver.displayedInput(
                for: .buttonSouth,
                snapshot: manager.remapSnapshot
            ),
            .buttonNorth
        )
    }

    // MARK: - #32 Ergonomic analysis

    func testFactorySchemeMarksRightThumbAsIntentionalTradeoff() {
        let warnings = ErgonomicMappingAnalyzer.analyze(
            scheme: ControlSchemePreset.xpiPerformance,
            grip: .standardTwoIndex,
            hasTouchpad: true
        )
        XCTAssertTrue(warnings.contains { $0.kind == .intentionalTradeoff && $0.id == "right-thumb-tradeoff" })
        XCTAssertTrue(warnings.allSatisfy { !$0.blocksSave })
    }

    func testCustomSchemeTreatsRightThumbAsTravelAndNeverBlocksSave() {
        var scheme = ControlSchemePreset.xpiPerformance.makeCustomCopy()
        let warnings = ErgonomicMappingAnalyzer.analyze(
            scheme: scheme,
            grip: .standardTwoIndex,
            hasTouchpad: true
        )
        XCTAssertTrue(warnings.contains { $0.kind == .thumbTravel && $0.id == "right-thumb-tradeoff" })
        XCTAssertTrue(warnings.allSatisfy { !$0.blocksSave })

        scheme.bindings[.timbreExpression] = .defaultBinding(for: .touchpad2D)
        let xbox = ErgonomicMappingAnalyzer.analyze(scheme: scheme, grip: .oneHanded, hasTouchpad: false)
        XCTAssertTrue(xbox.contains { $0.id == "touchpad-missing" })
        XCTAssertTrue(xbox.contains { $0.id == "one-hand-opposite" })
        XCTAssertTrue(xbox.allSatisfy { !$0.blocksSave })
    }

    func testSameInputConflictDetectorStillFlagsCriticalOverlap() {
        var scheme = ControlSchemePreset.xpiPerformance
        XCTAssertEqual(MappingConflict.detectConflicts(in: scheme).count, 0)
        scheme.bindings[.primaryExcitation] = PhysicalControlBinding(input: .leftStick2D)
        let conflicts = MappingConflict.detectConflicts(in: scheme)
        XCTAssertTrue(conflicts.contains { $0.severity == .critical })
    }
}
