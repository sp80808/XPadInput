import XCTest
@testable import XPadController

final class AngularHysteresisTests: XCTestCase {
    func testFirstEvaluationAndTwelveSectorDivision() {
        var hysteresis = AngularHysteresis(sectorCount: 12)

        XCTAssertEqual(hysteresis.evaluate(angle: 0), 0)
        hysteresis.reset()
        XCTAssertEqual(hysteresis.evaluate(angle: 2 * .pi / 12), 1)
        hysteresis.reset()
        XCTAssertEqual(hysteresis.evaluate(angle: 2 * .pi / 12 * 5.5), 5)
    }

    func testBoundaryJitterSticksAndOvershootAdvancesOneSector() {
        var hysteresis = AngularHysteresis(sectorCount: 12, baseMargin: 0.1)
        _ = hysteresis.evaluate(angle: 0)

        XCTAssertEqual(hysteresis.evaluate(angle: .pi / 6 + 0.05), 0)
        XCTAssertEqual(hysteresis.evaluate(angle: .pi / 6 + 0.11), 1)
        XCTAssertEqual(hysteresis.evaluate(angle: 2 * .pi / 6 + 0.01), 1)
    }

    func testDownwardOvershootAndVelocityDependentMargin() {
        var hysteresis = AngularHysteresis(sectorCount: 12, baseMargin: 0.1)
        _ = hysteresis.evaluate(angle: .pi / 3)

        XCTAssertEqual(hysteresis.evaluate(angle: .pi / 6 - 0.05), 1)
        XCTAssertEqual(hysteresis.evaluate(angle: .pi / 6 - 0.11), 0)

        var fast = AngularHysteresis(sectorCount: 12, baseMargin: 0.1)
        _ = fast.evaluate(angle: 0)
        XCTAssertEqual(fast.evaluate(angle: .pi / 6 + 0.06, angularVelocity: 10), 1)
    }

    func testAnglesNormalizeAndSectorWrapsInBothDirections() {
        var hysteresis = AngularHysteresis(sectorCount: 12, baseMargin: 0.05)
        XCTAssertEqual(hysteresis.evaluate(angle: -0.01), 11)
        XCTAssertEqual(hysteresis.evaluate(angle: 2 * .pi + 0.1), 0)

        var downward = AngularHysteresis(sectorCount: 12, baseMargin: 0.05)
        _ = downward.evaluate(angle: 0.01)
        XCTAssertEqual(downward.evaluate(angle: 2 * .pi - 0.1), 11)
    }

    func testResetClearsStickySector() {
        var hysteresis = AngularHysteresis(sectorCount: 12, baseMargin: 0.1)
        _ = hysteresis.evaluate(angle: 0)
        XCTAssertEqual(hysteresis.evaluate(angle: .pi / 6 + 0.05), 0)

        hysteresis.reset()
        XCTAssertEqual(hysteresis.evaluate(angle: .pi / 6 + 0.05), 1)
    }
}
