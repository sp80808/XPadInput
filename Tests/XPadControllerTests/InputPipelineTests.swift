import XCTest
@testable import XPadController

final class InputPipelineTests: XCTestCase {
    func testDeadzoneStrategiesCircularlyClampDiagonalInput() {
        let strategies: [DeadzoneStrategy] = [
            .none,
            .scaledRadial(0.12),
            .hybridRadialSloped(inner: 0.12, axial: 0.1),
            .directionalSnap(0.1)
        ]

        for strategy in strategies {
            let output = strategy.process(x: 1, y: 1)
            let magnitude = hypot(output.x, output.y)

            XCTAssertLessThanOrEqual(magnitude, 1.000_001)
            XCTAssertEqual(output.x, output.y, accuracy: 0.000_001)
        }
    }

    func testDeadzoneStrategiesSanitizeInvalidConfigurationAndInput() {
        let invalidInput = DeadzoneStrategy.scaledRadial(0.12).process(x: .nan, y: 0.5)
        XCTAssertEqual(invalidInput.x, 0)
        XCTAssertEqual(invalidInput.y, 0)

        let negativeDeadzone = DeadzoneStrategy.scaledRadial(-1).process(x: 0.5, y: 0)
        XCTAssertEqual(negativeDeadzone.x, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(negativeDeadzone.y, 0)

        let fullDeadzone = DeadzoneStrategy.scaledRadial(1).process(x: 1, y: 0)
        XCTAssertTrue(fullDeadzone.x.isFinite)
        XCTAssertEqual(fullDeadzone.x, 1, accuracy: 0.000_001)
    }

    func testGestureVelocityTrackerAcceptsZeroAsFirstTimestamp() {
        var tracker = GestureVelocityTracker()

        let first = tracker.update(x: 0, y: 0, timestamp: 0)
        let second = tracker.update(x: 1, y: 0, timestamp: 0.01)

        XCTAssertEqual(first.movementVelocity, 0)
        XCTAssertEqual(second.movementVelocity, 100, accuracy: 0.001)
        XCTAssertEqual(second.xVelocity, 100, accuracy: 0.001)
    }

    func testGestureVelocityTrackerIgnoresDuplicateAndReorderedTimestamps() {
        var tracker = GestureVelocityTracker()
        _ = tracker.update(x: 0, y: 0, timestamp: 1)

        let duplicate = tracker.update(x: 0.5, y: 0, timestamp: 1)
        let reordered = tracker.update(x: 0.75, y: 0, timestamp: 0.5)
        let recovered = tracker.update(x: 1, y: 0, timestamp: 1.1)

        XCTAssertEqual(duplicate.movementVelocity, 0)
        XCTAssertEqual(reordered.movementVelocity, 0)
        XCTAssertEqual(recovered.movementVelocity, 10, accuracy: 0.001)
        XCTAssertEqual(recovered.xVelocity, 10, accuracy: 0.001)
    }

    func testGestureVelocityTrackerSuppressesUndefinedRotationAtCentre() {
        var tracker = GestureVelocityTracker()
        _ = tracker.update(x: 0, y: 0, timestamp: 1)

        let leavingCentre = tracker.update(x: 0, y: 1, timestamp: 1.1)
        let rotating = tracker.update(x: -1, y: 0, timestamp: 1.2)

        XCTAssertEqual(leavingCentre.angularVelocity, 0)
        // (0, 1) → (-1, 0) is a quarter turn (π/2) over 0.1 seconds.
        XCTAssertEqual(rotating.angularVelocity, (Float.pi / 2) / 0.1, accuracy: 0.001)
    }

    func testLinearVelocityTrackerRejectsInvalidTimeWithoutLosingHistory() {
        var tracker = LinearVelocityTracker()
        _ = tracker.update(value: 0, timestamp: 0)

        let duplicate = tracker.update(value: 0.5, timestamp: 0)
        let recovered = tracker.update(value: 1, timestamp: 0.1)

        XCTAssertEqual(duplicate.velocity, 0)
        XCTAssertEqual(recovered.velocity, 10, accuracy: 0.001)
    }

    func testStickSmoothingIsInvariantAcrossCallbackRates() {
        func finalValue(sampleRate: Double) -> Float {
            let profile = InputProcessingProfile(
                id: "test",
                name: "Test",
                deadzone: .none,
                responseCurve: .linear,
                smoothingFactor: 0.5
            )
            var processor = StickProcessor(profile: profile)
            _ = processor.process(rawX: 0, rawY: 0, timestamp: 0)

            var state = ProcessedStickState()
            let steps = Int(0.1 * sampleRate)
            for step in 1...steps {
                state = processor.process(
                    rawX: 1,
                    rawY: 0,
                    timestamp: Double(step) / sampleRate
                )
            }
            return state.x
        }

        let at60Hz = finalValue(sampleRate: 60)
        let at240Hz = finalValue(sampleRate: 240)

        XCTAssertEqual(at60Hz, at240Hz, accuracy: 0.000_01)
    }

    func testStickSmoothingDoesNotAdvanceForDuplicateTimestamp() {
        let profile = InputProcessingProfile(
            id: "test",
            name: "Test",
            deadzone: .none,
            responseCurve: .linear,
            smoothingFactor: 0.5
        )
        var processor = StickProcessor(profile: profile)
        _ = processor.process(rawX: 0, rawY: 0, timestamp: 0)

        let first = processor.process(rawX: 1, rawY: 0, timestamp: 1.0 / 120.0)
        let duplicate = processor.process(rawX: 1, rawY: 0, timestamp: 1.0 / 120.0)

        XCTAssertEqual(first.x, duplicate.x, accuracy: 0.000_001)
        XCTAssertEqual(duplicate.movementVelocity, 0, accuracy: 0.000_001)
    }

    func testTriggerSmoothingIsInvariantAcrossCallbackRates() {
        func finalValue(sampleRate: Double) -> Float {
            var processor = TriggerProcessor(
                deadzone: 0,
                responseCurve: .linear,
                smoothingFactor: 0.5
            )
            _ = processor.process(rawValue: 0, timestamp: 0)

            var state = ProcessedTriggerState()
            let steps = Int(0.1 * sampleRate)
            for step in 1...steps {
                state = processor.process(
                    rawValue: 1,
                    timestamp: Double(step) / sampleRate
                )
            }
            return state.value
        }

        let at60Hz = finalValue(sampleRate: 60)
        let at240Hz = finalValue(sampleRate: 240)

        XCTAssertEqual(at60Hz, at240Hz, accuracy: 0.000_01)
    }
}
