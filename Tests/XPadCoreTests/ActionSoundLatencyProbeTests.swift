import XCTest
@testable import XPadCore

final class ActionSoundLatencyProbeTests: XCTestCase {
    func testDisabledProbeRecordsNothing() {
        let probe = ActionSoundLatencyProbe(isEnabled: false)
        probe.beginCycle(at: 1.0)
        probe.markGestureCommitted(at: 1.004)
        probe.markNoteDispatched(at: 1.006)
        probe.complete(synthReturnedAt: 1.010, graphMutationMs: 1.5)
        XCTAssertEqual(probe.snapshot().sampleCount, 0)
    }

    func testPercentilesAndJitterFromCompletedCycles() {
        let probe = ActionSoundLatencyProbe(isEnabled: true)
        for index in 0..<20 {
            let start = Double(index)
            probe.beginCycle(at: start)
            probe.markGestureCommitted(at: start + 0.002)
            probe.markNoteDispatched(at: start + 0.003)
            let extra = index == 19 ? 0.020 : 0.004
            probe.complete(synthReturnedAt: start + extra, graphMutationMs: extra * 1000)
        }

        let snapshot = probe.snapshot()
        XCTAssertEqual(snapshot.sampleCount, 20)
        XCTAssertEqual(snapshot.inputToSynth.p50Ms, 4, accuracy: 0.01)
        XCTAssertGreaterThan(snapshot.inputToSynth.p99Ms, snapshot.inputToSynth.p50Ms)
        XCTAssertGreaterThan(snapshot.inputToSynth.jitterMs, 0)
        XCTAssertTrue(snapshot.summaryLine.contains("n=20"))
    }

    func testDistributionHelpers() {
        let dist = LatencyDistribution.from([1, 2, 3, 4, 100])
        XCTAssertEqual(dist.count, 5)
        XCTAssertEqual(dist.p50Ms, 3, accuracy: 0.001)
        XCTAssertEqual(dist.p99Ms, 100, accuracy: 0.001)
        XCTAssertGreaterThan(dist.jitterMs, 0)
    }
}
