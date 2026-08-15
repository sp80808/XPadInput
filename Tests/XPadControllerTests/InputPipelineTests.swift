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
        XCTAssertEqual(rotating.angularVelocity, Float.pi / 0.1, accuracy: 0.001)
    }

    func testLinearVelocityTrackerRejectsInvalidTimeWithoutLosingHistory() {
        var tracker = LinearVelocityTracker()
        _ = tracker.update(value: 0, timestamp: 0)

        let duplicate = tracker.update(value: 0.5, timestamp: 0)
        let recovered = tracker.update(value: 1, timestamp: 0.1)

        XCTAssertEqual(duplicate.velocity, 0)
        XCTAssertEqual(recovered.velocity, 10, accuracy: 0.001)
    }
}
