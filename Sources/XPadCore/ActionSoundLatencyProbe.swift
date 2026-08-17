import Foundation

/// Software stages on the action→sound path. These are host-time marks, not
/// acoustic hardware latency.
public enum ActionSoundLatencyStage: String, Sendable, Equatable, CaseIterable {
    case inputReceived
    case gestureCommitted
    case noteDispatched
    case synthNoteOnReturned
}

public struct ActionSoundLatencySample: Sendable, Equatable {
    public var inputToGestureMs: Double
    public var gestureToDispatchMs: Double
    public var dispatchToSynthReturnedMs: Double
    public var inputToSynthReturnedMs: Double
    public var graphMutationMs: Double?

    public init(
        inputToGestureMs: Double,
        gestureToDispatchMs: Double,
        dispatchToSynthReturnedMs: Double,
        inputToSynthReturnedMs: Double,
        graphMutationMs: Double? = nil
    ) {
        self.inputToGestureMs = inputToGestureMs
        self.gestureToDispatchMs = gestureToDispatchMs
        self.dispatchToSynthReturnedMs = dispatchToSynthReturnedMs
        self.inputToSynthReturnedMs = inputToSynthReturnedMs
        self.graphMutationMs = graphMutationMs
    }
}

public struct LatencyDistribution: Sendable, Equatable {
    public var count: Int
    public var p50Ms: Double
    public var p95Ms: Double
    public var p99Ms: Double
    public var jitterMs: Double

    public init(count: Int = 0, p50Ms: Double = 0, p95Ms: Double = 0, p99Ms: Double = 0, jitterMs: Double = 0) {
        self.count = count
        self.p50Ms = p50Ms
        self.p95Ms = p95Ms
        self.p99Ms = p99Ms
        self.jitterMs = jitterMs
    }

    public static func from(_ values: [Double]) -> LatencyDistribution {
        guard !values.isEmpty else { return LatencyDistribution() }
        let sorted = values.sorted()
        let p50 = percentile(sorted, 0.50)
        let p95 = percentile(sorted, 0.95)
        let p99 = percentile(sorted, 0.99)
        return LatencyDistribution(
            count: sorted.count,
            p50Ms: p50,
            p95Ms: p95,
            p99Ms: p99,
            jitterMs: max(0, p95 - p50)
        )
    }

    private static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let clamped = min(1, max(0, fraction))
        let index = Int((Double(sorted.count - 1) * clamped).rounded(.toNearestOrAwayFromZero))
        return sorted[min(sorted.count - 1, max(0, index))]
    }
}

public struct ActionSoundLatencySnapshot: Sendable, Equatable {
    public var sampleCount: Int
    public var inputToSynth: LatencyDistribution
    public var graphMutation: LatencyDistribution

    public init(
        sampleCount: Int = 0,
        inputToSynth: LatencyDistribution = LatencyDistribution(),
        graphMutation: LatencyDistribution = LatencyDistribution()
    ) {
        self.sampleCount = sampleCount
        self.inputToSynth = inputToSynth
        self.graphMutation = graphMutation
    }

    public var summaryLine: String {
        guard sampleCount > 0 else { return "No action→sound samples yet." }
        let graph = graphMutation.count > 0
            ? String(format: "  graph p50 %.2f ms", graphMutation.p50Ms)
            : ""
        return String(
            format: "n=%d  input→synth p50 %.2f  p95 %.2f  p99 %.2f  jitter %.2f ms%@",
            sampleCount,
            inputToSynth.p50Ms,
            inputToSynth.p95Ms,
            inputToSynth.p99Ms,
            inputToSynth.jitterMs,
            graph
        )
    }
}

/// Low-overhead host-time probe. Disabled by default; PLAY must not display this.
public final class ActionSoundLatencyProbe: @unchecked Sendable {
    public var isEnabled: Bool
    public var maxSamples: Int

    private let lock = NSLock()
    private var open: OpenCycle?
    private var samples: [ActionSoundLatencySample] = []

    private struct OpenCycle {
        var input: TimeInterval
        var gesture: TimeInterval?
        var dispatched: TimeInterval?
    }

    public init(isEnabled: Bool = false, maxSamples: Int = 256) {
        self.isEnabled = isEnabled
        self.maxSamples = max(16, maxSamples)
    }

    public func reset() {
        lock.lock()
        open = nil
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    public func beginCycle(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard isEnabled else { return }
        lock.lock()
        open = OpenCycle(input: time, gesture: nil, dispatched: nil)
        lock.unlock()
    }

    public func markGestureCommitted(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard isEnabled else { return }
        lock.lock()
        open?.gesture = time
        lock.unlock()
    }

    public func markNoteDispatched(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard isEnabled else { return }
        lock.lock()
        open?.dispatched = time
        lock.unlock()
    }

    public func complete(
        synthReturnedAt time: TimeInterval = ProcessInfo.processInfo.systemUptime,
        graphMutationMs: Double? = nil
    ) {
        guard isEnabled else { return }
        lock.lock()
        defer { lock.unlock() }
        guard let cycle = open else { return }
        let gesture = cycle.gesture ?? cycle.input
        let dispatched = cycle.dispatched ?? gesture
        let sample = ActionSoundLatencySample(
            inputToGestureMs: ms(cycle.input, gesture),
            gestureToDispatchMs: ms(gesture, dispatched),
            dispatchToSynthReturnedMs: ms(dispatched, time),
            inputToSynthReturnedMs: ms(cycle.input, time),
            graphMutationMs: graphMutationMs
        )
        samples.append(sample)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        open = nil
    }

    public func snapshot() -> ActionSoundLatencySnapshot {
        lock.lock()
        let copy = samples
        lock.unlock()
        let totals = copy.map(\.inputToSynthReturnedMs)
        let graphs = copy.compactMap(\.graphMutationMs)
        return ActionSoundLatencySnapshot(
            sampleCount: copy.count,
            inputToSynth: .from(totals),
            graphMutation: .from(graphs)
        )
    }

    private func ms(_ start: TimeInterval, _ end: TimeInterval) -> Double {
        max(0, (end - start) * 1000.0)
    }
}
