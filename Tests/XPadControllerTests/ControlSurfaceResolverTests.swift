import Foundation
import XCTest
@testable import XPadCore
@testable import XPadController

final class ControlSurfaceResolverTests: XCTestCase {
    func testPerformanceSchemeProjectsIdentityLayout() {
        var resolver = ControlSurfaceResolver(scheme: ControlSchemePreset.xpiPerformance)
        let physical = ControllerState()
        physical.leftStick = ProcessedStickState(x: 0.4, y: 0.6, radius: hypot(Float(0.4), Float(0.6)), angle: atan2(0.6, 0.4))
        physical.rightStick = ProcessedStickState(x: -0.3, y: 0.8, radius: hypot(Float(-0.3), Float(0.8)), angle: atan2(0.8, -0.3))
        physical.leftTrigger = ProcessedTriggerState(value: 0.55, isPressed: true)
        physical.rightTrigger = ProcessedTriggerState(value: 0.2, isPressed: true)

        let frame = resolver.evaluate(state: physical, timestamp: 1)
        let logical = ControllerState()
        resolver.project(frame: frame, physical: physical, onto: logical)

        XCTAssertEqual(logical.leftStick.x, physical.leftStick.x, accuracy: 0.001)
        XCTAssertEqual(logical.leftStick.y, physical.leftStick.y, accuracy: 0.001)
        XCTAssertEqual(logical.rightStick.x, physical.rightStick.x, accuracy: 0.001)
        XCTAssertEqual(logical.rightStick.y, physical.rightStick.y, accuracy: 0.001)
        XCTAssertEqual(logical.leftTrigger.value, 0.55, accuracy: 0.001)
        XCTAssertEqual(logical.rightTrigger.value, 0.2, accuracy: 0.001)
    }

    func testProjectionKeepsTouchpadClickAndAnalogFaceValues() {
        var resolver = ControlSurfaceResolver(scheme: ControlSchemePreset.xpiPerformance)
        let physical = ControllerState()
        physical.touchpadButtonPressed = true
        physical.touchpadActive = true
        physical.touchpadY = -0.25
        physical.buttonAValue = 0.44
        physical.hasMotion = true
        physical.gyroZ = 0.31

        let frame = resolver.evaluate(state: physical, timestamp: 1)
        let logical = ControllerState()
        resolver.project(frame: frame, physical: physical, onto: logical)

        XCTAssertTrue(logical.touchpadButtonPressed)
        XCTAssertEqual(logical.touchpadY, -0.25, accuracy: 0.0001)
        XCTAssertEqual(logical.buttonAValue, 0.44, accuracy: 0.0001)
        XCTAssertEqual(logical.gyroZ, 0.31, accuracy: 0.0001)
        XCTAssertTrue(logical.hasMotion)
    }

    func testOneHandLeftMapsTriggerOntoExcitationAxis() {
        var resolver = ControlSurfaceResolver(scheme: ControlSchemePreset.oneHandLeft)
        let physical = ControllerState()
        physical.leftStick = ProcessedStickState(x: 0.2, y: 0.7, radius: hypot(Float(0.2), Float(0.7)), angle: atan2(0.7, 0.2))
        physical.leftTrigger = ProcessedTriggerState(value: 0.84, isPressed: true)
        physical.leftShoulder = true

        let frame = resolver.evaluate(state: physical, timestamp: 1)
        let logical = ControllerState()
        resolver.project(frame: frame, physical: physical, onto: logical)

        XCTAssertEqual(logical.leftStick.y, 0.7, accuracy: 0.001)
        XCTAssertGreaterThan(logical.rightStick.y, 0.75)
        XCTAssertGreaterThan(logical.leftTrigger.value, 0.9)
    }

    func testLeftHandedSchemePutsHarmonyOnRightStick() {
        var resolver = ControlSurfaceResolver(scheme: ControlSchemePreset.leftHandedPerformance)
        let physical = ControllerState()
        physical.rightStick = ProcessedStickState(x: 0.15, y: 0.9, radius: hypot(Float(0.15), Float(0.9)), angle: atan2(0.9, 0.15))
        physical.leftStick = ProcessedStickState(x: -0.4, y: 0.5, radius: hypot(Float(-0.4), Float(0.5)), angle: atan2(0.5, -0.4))

        let frame = resolver.evaluate(state: physical, timestamp: 1)
        XCTAssertEqual(frame.harmonyStick.y, 0.9, accuracy: 0.001)
        XCTAssertEqual(frame.expressionStick.y, 0.5, accuracy: 0.001)
        XCTAssertEqual(frame.expressionStick.x, -0.4, accuracy: 0.001)
    }

    func testBindingInversionAndSensitivity() {
        var scheme = ControlSchemePreset.xpiPerformance
        scheme.bindings[.dampingExpression] = PhysicalControlBinding(
            input: .leftTrigger,
            isInverted: true,
            sensitivity: 0.5
        )
        var resolver = ControlSurfaceResolver(scheme: scheme)
        let physical = ControllerState()
        physical.leftTrigger = ProcessedTriggerState(value: 0.2, isPressed: true)

        let frame = resolver.evaluate(state: physical, timestamp: 1)
        // inverted unipolar 0.2 → 0.8, then * 0.5 → 0.4
        XCTAssertEqual(frame.analogValue(for: .dampingExpression), 0.4, accuracy: 0.02)
    }

    func testDigitalRampAndSteppedLatch() {
        var scheme = ControlSchemePreset.xpiPerformance
        scheme.bindings[.pressureExpression] = PhysicalControlBinding(
            input: .rightShoulder,
            digitalBehavior: .linearRamp
        )
        scheme.bindings[.sustainLatch] = PhysicalControlBinding(
            input: .leftShoulder,
            digitalBehavior: .stepped
        )
        var resolver = ControlSurfaceResolver(scheme: scheme)
        let physical = ControllerState()

        physical.rightShoulder = true
        var frame = resolver.evaluate(state: physical, timestamp: 1.0)
        XCTAssertEqual(frame.analogValue(for: .pressureExpression), 0, accuracy: 0.001)

        frame = resolver.evaluate(state: physical, timestamp: 1.0 + ControlSurfaceResolver.rampDuration)
        XCTAssertEqual(frame.analogValue(for: .pressureExpression), 1, accuracy: 0.02)

        physical.leftShoulder = true
        frame = resolver.evaluate(state: physical, timestamp: 2.0)
        XCTAssertEqual(frame.analogValue(for: .sustainLatch), 0.25, accuracy: 0.001)

        physical.leftShoulder = false
        frame = resolver.evaluate(state: physical, timestamp: 2.1)
        XCTAssertEqual(frame.analogValue(for: .sustainLatch), 0.25, accuracy: 0.001)

        physical.leftShoulder = true
        frame = resolver.evaluate(state: physical, timestamp: 2.2)
        XCTAssertEqual(frame.analogValue(for: .sustainLatch), 0.50, accuracy: 0.001)
    }

    func testOctaveRisingEdgeFromDpad() {
        var resolver = ControlSurfaceResolver(scheme: ControlSchemePreset.xpiPerformance)
        let physical = ControllerState()
        var frame = resolver.evaluate(state: physical, timestamp: 1)
        XCTAssertFalse(frame.didRise(.octaveUp))

        physical.dpadUp = true
        frame = resolver.evaluate(state: physical, timestamp: 1.1)
        XCTAssertTrue(frame.didRise(.octaveUp))

        frame = resolver.evaluate(state: physical, timestamp: 1.2)
        XCTAssertFalse(frame.didRise(.octaveUp))
        XCTAssertTrue(frame.isHeld(.octaveUp))
    }

    func testInputLearnPrefersTwoDWhenBothAxesMove() {
        let detected = InputLearnDetector.detect(leftStickX: 0.6, leftStickY: 0.55, prefer2D: true)
        XCTAssertEqual(detected, .leftStick2D)

        let axis = InputLearnDetector.detect(rightStickY: 0.8)
        XCTAssertEqual(axis, .rightStickY)
    }

    func testOrthogonalStickAxesAreNotConflicts() {
        let conflicts = MappingConflict.detectConflicts(in: ControlSchemePreset.xpiPerformance)
        XCTAssertTrue(conflicts.filter { $0.severity == .critical }.isEmpty)
    }

    func testTwoDVersusAxisOnSameStickIsCritical() {
        var scheme = ControlSchemePreset.xpiPerformance
        scheme.bindings[.primaryExcitation] = .defaultBinding(for: .leftStickY)
        let conflicts = MappingConflict.detectConflicts(in: scheme)
        XCTAssertTrue(conflicts.contains { $0.severity == .critical })
    }

    func testCoverageFlagsMissingExcitation() {
        var scheme = ControlSchemePreset.xpiPerformance.makeCustomCopy()
        scheme.bindings[.primaryExcitation] = PhysicalControlBinding(input: .unassigned)
        let issues = scheme.coverageIssues()
        XCTAssertTrue(issues.contains { $0.action == .primaryExcitation && $0.severity == .critical })
    }

    func testLowFatigueKeepsVoicingOnDpad() {
        let scheme = ControlSchemePreset.lowFatigue
        XCTAssertEqual(scheme.bindings[.voicingNext]?.input, .dpadRight)
        XCTAssertEqual(scheme.bindings[.voicingPrevious]?.input, .dpadLeft)
        XCTAssertEqual(scheme.bindings[.soloModeToggle]?.input, .buttonCenter)
        XCTAssertNotEqual(scheme.bindings[.soloModeToggle]?.input, .rightStickClick)
    }

    func testOneHandRightUsesTriggerExcitationAndStickHarmony() {
        let scheme = ControlSchemePreset.oneHandRight
        XCTAssertEqual(scheme.bindings[.harmonyNavigate2D]?.input, .rightStick2D)
        XCTAssertEqual(scheme.bindings[.primaryExcitation]?.input, .rightTrigger)
        XCTAssertEqual(scheme.bindings[.panic]?.input, .buttonOptions)
        XCTAssertTrue(MappingConflict.detectConflicts(in: scheme).filter { $0.severity == .critical }.isEmpty)
    }

    func testTriggerFeelExposesResponseCurves() {
        XCTAssertEqual(TriggerFeelPreset.soft.activationThreshold, 0.04, accuracy: 0.0001)
        XCTAssertEqual(
            ControlSchemePreset.lowFatigue.triggerFeel.responseCurve.process(magnitude: 0.25),
            ResponseCurve.aggressive.process(magnitude: 0.25),
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ControlSchemePreset.xpiPerformance.triggerFeel.responseCurve.process(magnitude: 0.5),
            0.5,
            accuracy: 0.0001
        )
    }

    func testHUDOverlayFollowsReboundControls() {
        var scheme = ControlSchemePreset.xpiPerformance.makeCustomCopy()
        scheme.bindings[.dampingExpression] = .defaultBinding(for: .rightTrigger)
        scheme.bindings[.pressureExpression] = .defaultBinding(for: .leftTrigger)
        let labels = scheme.overlayHUDLabels(.guitar)
        XCTAssertEqual(labels.l2, "Pressure / Swell")
        XCTAssertEqual(labels.r2, "Palm Mute / Damp")
    }

    func testManagerProjectsInjectedStateThroughActiveScheme() {
        let manager = ControllerManager()
        manager.selectControlScheme(ControlSchemePreset.oneHandLeft)
        defer { manager.selectControlScheme(ControlSchemePreset.xpiPerformance) }
        manager.injectSimulatedState { state in
            state.leftTrigger = ProcessedTriggerState(rawValue: 0.9, calibratedValue: 0.9, value: 0.9, isPressed: true)
        }
        XCTAssertGreaterThan(manager.performanceState.rightStick.y, 0.8)
        XCTAssertEqual(manager.controllerState.leftTrigger.value, 0.9, accuracy: 0.001)
        XCTAssertEqual(
            manager.leftTriggerProcessor.responseCurve.process(magnitude: 0.25),
            ResponseCurve.aggressive.process(magnitude: 0.25),
            accuracy: 0.0001
        )
    }

    func testAllBuiltInSchemesIncludeLeftHandedLayout() {
        XCTAssertTrue(ControlSchemePreset.allBuiltIn.contains { $0.id == "xpi_left_handed" })
        XCTAssertEqual(ControlSchemePreset.allBuiltIn.count, 6)
    }
}
