import XCTest
@testable import XPadController

final class ControllerCalibrationTests: XCTestCase {
    func testStickCalibrationSubtractsCenterAndSuppressesDrift() {
        let calibration = StickCalibration(restCenterX: 0.12, restCenterY: -0.08, driftRadius: 0.05)

        let centered = calibration.calibrate(rawX: 0.12, rawY: -0.08)
        XCTAssertEqual(centered.x, 0, accuracy: 0.0001)
        XCTAssertEqual(centered.y, 0, accuracy: 0.0001)

        let drifting = calibration.calibrate(rawX: 0.15, rawY: -0.08)
        XCTAssertEqual(drifting.x, 0, accuracy: 0.0001)
        XCTAssertEqual(drifting.y, 0, accuracy: 0.0001)
    }

    func testStickCalibrationRescalesDeflectionPreservesDirectionAndInvertsAxes() {
        let calibration = StickCalibration(driftRadius: 0, maxRadius: 0.8)
        let diagonal = calibration.calibrate(rawX: 0.6, rawY: 0.8)

        XCTAssertEqual(diagonal.x, 0.6, accuracy: 0.0001)
        XCTAssertEqual(diagonal.y, 0.8, accuracy: 0.0001)
        XCTAssertEqual(atan2(diagonal.y, diagonal.x), atan2(0.8, 0.6), accuracy: 0.0001)
        XCTAssertEqual(sqrt(diagonal.x * diagonal.x + diagonal.y * diagonal.y), 1.0, accuracy: 0.0001)

        let inverted = StickCalibration(
            driftRadius: 0,
            invertX: true,
            invertY: true,
            sensitivityX: 2,
            sensitivityY: 2
        ).calibrate(rawX: 0.75, rawY: -0.75)
        XCTAssertEqual(inverted.x, -1, accuracy: 0.0001)
        XCTAssertEqual(inverted.y, 1, accuracy: 0.0001)
    }

    func testTriggerCalibrationNormalizesTravelAndHandlesDegenerateWindow() {
        let calibration = TriggerCalibration(restMin: 0.2, travelMax: 0.8)

        XCTAssertEqual(calibration.calibrate(rawValue: 0.2), 0)
        XCTAssertEqual(calibration.calibrate(rawValue: 0.1), 0)
        XCTAssertEqual(calibration.calibrate(rawValue: 0.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(calibration.calibrate(rawValue: 1.0), 1)
        XCTAssertEqual(
            TriggerCalibration(restMin: 0, travelMax: 1, sensitivity: 2).calibrate(rawValue: 0.75),
            1
        )

        let degenerate = TriggerCalibration(restMin: 0.5, travelMax: 0.5)
        XCTAssertEqual(degenerate.calibrate(rawValue: 0.5), 0)
        XCTAssertEqual(degenerate.calibrate(rawValue: 0.6), 1)
    }

    func testCalibrationWizardStateMachineAndRangeTracking() {
        let wizard = CalibrationWizard()
        XCTAssertEqual(wizard.currentStep, .idle)

        wizard.start()
        XCTAssertEqual(wizard.currentStep, .measuringRest(samples: 0))

        for _ in 0..<59 {
            wizard.feed(rawLeftX: 0.10, rawLeftY: 0.20, rawRightX: -0.10, rawRightY: 0.05)
        }
        XCTAssertEqual(wizard.currentStep, .measuringRest(samples: 59))

        wizard.feed(rawLeftX: 0.13, rawLeftY: 0.20, rawRightX: -0.10, rawRightY: 0.05)
        XCTAssertEqual(wizard.currentStep, .measuringRange(maxLeftR: 0, maxRightR: 0))

        wizard.feed(rawLeftX: 0.3, rawLeftY: 0.4, rawRightX: 0.5, rawRightY: 1.2)
        XCTAssertEqual(
            wizard.currentStep,
            .measuringRange(
                maxLeftR: 0.5,
                maxRightR: sqrt(1.69)
            )
        )

        wizard.feed(rawLeftX: 0.1, rawLeftY: 0.1, rawRightX: 0, rawRightY: 0)
        XCTAssertEqual(
            wizard.currentStep,
            .measuringRange(
                maxLeftR: 0.5,
                maxRightR: sqrt(1.69)
            )
        )
    }

    func testCalibrationWizardFinishAveragesRestAndClampsBounds() {
        let wizard = CalibrationWizard()
        wizard.start()
        for _ in 0..<59 {
            wizard.feed(rawLeftX: 0.10, rawLeftY: 0.20, rawRightX: -0.10, rawRightY: 0.05)
        }
        wizard.feed(rawLeftX: 0.13, rawLeftY: 0.20, rawRightX: -0.10, rawRightY: 0.05)
        wizard.feed(rawLeftX: 0.3, rawLeftY: 0.4, rawRightX: 0.5, rawRightY: 1.2)

        let calibration = wizard.finish()
        XCTAssertEqual(calibration.leftStick.restCenterX, 0.1005, accuracy: 0.0001)
        XCTAssertEqual(calibration.leftStick.restCenterY, 0.20, accuracy: 0.0001)
        XCTAssertEqual(calibration.rightStick.restCenterX, -0.10, accuracy: 0.0001)
        XCTAssertEqual(calibration.rightStick.restCenterY, 0.05, accuracy: 0.0001)
        XCTAssertEqual(calibration.leftStick.driftRadius, 0.06, accuracy: 0.0001)
        XCTAssertEqual(calibration.rightStick.driftRadius, 0.06, accuracy: 0.0001)
        XCTAssertEqual(calibration.leftStick.maxRadius, 0.85, accuracy: 0.0001)
        XCTAssertEqual(calibration.rightStick.maxRadius, 1.15, accuracy: 0.0001)
        XCTAssertEqual(wizard.currentStep, .completed)
    }

    func testCalibrationWizardCancelAndIgnoredFeeds() {
        let wizard = CalibrationWizard()
        wizard.feed(rawLeftX: 1, rawLeftY: 1, rawRightX: 1, rawRightY: 1)
        XCTAssertEqual(wizard.currentStep, .idle)

        wizard.start()
        wizard.cancel()
        XCTAssertEqual(wizard.currentStep, .idle)
        wizard.feed(rawLeftX: 1, rawLeftY: 1, rawRightX: 1, rawRightY: 1)
        XCTAssertEqual(wizard.currentStep, .idle)

        let calibration = wizard.finish()
        XCTAssertEqual(wizard.currentStep, .completed)
        wizard.feed(rawLeftX: 0, rawLeftY: 0, rawRightX: 0, rawRightY: 0)
        XCTAssertEqual(wizard.currentStep, .completed)
        XCTAssertEqual(calibration.leftStick.maxRadius, 0.85)
        XCTAssertEqual(calibration.rightStick.maxRadius, 0.85)
    }

    func testControllerHardwareCalibrationCodableRoundTrip() throws {
        let original = ControllerHardwareCalibration(
            controllerIdentifier: "test-controller",
            leftStick: StickCalibration(restCenterX: 0.1, sensitivityY: 1.2),
            rightStick: StickCalibration(invertX: true),
            leftTrigger: TriggerCalibration(restMin: 0.2, travelMax: 0.9),
            rightTrigger: TriggerCalibration(sensitivity: 0.8)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ControllerHardwareCalibration.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}
