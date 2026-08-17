import XCTest
@testable import XPadCore
@testable import XPadTheory

final class HarmonicSelectionStateTests: XCTestCase {
    func testNorthStickSelectsIndexZero() {
        XCTAssertEqual(HarmonicSelectionState.rawIndex(angle: .pi / 2, sectorCount: 7), 0)
        XCTAssertEqual(
            HarmonicSelectionState.rawIndex(
                angle: HarmonicSelectionState.stickAngle(forIndex: 3, sectorCount: 7),
                sectorCount: 7
            ),
            3
        )
    }

    func testBoundaryJitterDoesNotAlternateSectors() {
        var state = HarmonicSelectionState(sectorCount: 7)
        let north = HarmonicSelectionState.stickAngle(forIndex: 0, sectorCount: 7)
        XCTAssertEqual(state.evaluate(angle: north, radius: 0.55).sectorIndex, 0)

        let slice = (2.0 * .pi) / 7.0
        let justIntoNeighbour = north - slice * 0.52
        let first = state.evaluate(angle: justIntoNeighbour, radius: 0.55)
        XCTAssertEqual(first.sectorIndex, 0)
        XCTAssertFalse(first.didCommitSector)

        let jitterBack = north - slice * 0.48
        XCTAssertEqual(state.evaluate(angle: jitterBack, radius: 0.55).sectorIndex, 0)

        let committedNeighbour = HarmonicSelectionState.stickAngle(forIndex: 1, sectorCount: 7)
        let commit = state.evaluate(angle: committedNeighbour, radius: 0.55)
        XCTAssertEqual(commit.sectorIndex, 1)
        XCTAssertTrue(commit.didCommitSector)
    }

    func testWraparoundJitterAtPi() {
        var state = HarmonicSelectionState(sectorCount: 7)
        let zero = HarmonicSelectionState.stickAngle(forIndex: 0, sectorCount: 7)
        _ = state.evaluate(angle: zero, radius: 0.6)

        let last = HarmonicSelectionState.stickAngle(forIndex: 6, sectorCount: 7)
        let slice = (2.0 * .pi) / 7.0
        let barelyTowardLast = zero + slice * 0.52
        XCTAssertEqual(state.evaluate(angle: barelyTowardLast, radius: 0.6).sectorIndex, 0)

        let commitLast = state.evaluate(angle: last, radius: 0.6)
        XCTAssertEqual(commitLast.sectorIndex, 6)
        XCTAssertTrue(commitLast.didCommitSector)
    }

    func testCentreReturnKeepsHarmonicContext() {
        var state = HarmonicSelectionState(sectorCount: 7)
        let four = HarmonicSelectionState.stickAngle(forIndex: 4, sectorCount: 7)
        XCTAssertEqual(state.evaluate(angle: four, radius: 0.6).sectorIndex, 4)

        let rest = state.evaluate(angle: four + 1.2, radius: 0.12)
        XCTAssertEqual(rest.region, .rest)
        XCTAssertEqual(rest.sectorIndex, 4)
        XCTAssertFalse(rest.didCommitSector)
    }

    func testOuterRiskUsesEnterExitHysteresis() {
        var state = HarmonicSelectionState(sectorCount: 7)
        let angle = HarmonicSelectionState.stickAngle(forIndex: 2, sectorCount: 7)
        XCTAssertEqual(state.evaluate(angle: angle, radius: 0.5).region, .ordinary)

        let enter = state.evaluate(angle: angle, radius: 0.86)
        XCTAssertEqual(enter.region, .risk)
        XCTAssertTrue(enter.didEnterRisk)

        let hold = state.evaluate(angle: angle, radius: 0.76)
        XCTAssertEqual(hold.region, .risk)
        XCTAssertFalse(hold.didEnterRisk)

        XCTAssertEqual(state.evaluate(angle: angle, radius: 0.70).region, .ordinary)
    }
}
