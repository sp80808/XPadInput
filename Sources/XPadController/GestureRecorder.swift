import Foundation
import XPadCore

public struct GestureSample: Codable, Sendable {
    public let timestampOffset: Double // Seconds from start
    public let state: GamepadState
}

public struct GestureClip: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var duration: Double
    public var samples: [GestureSample]

    public init(
        id: UUID = UUID(),
        name: String = "Recorded Gesture",
        duration: Double = 0.0,
        samples: [GestureSample] = []
    ) {
        self.id = id
        self.name = name
        self.duration = duration
        self.samples = samples
    }
}

public final class GestureRecorder: @unchecked Sendable {
    private var isRecording: Bool = false
    private var startTime: TimeInterval = 0.0
    private var samples: [GestureSample] = []
    private let lock = NSLock()

    public init() {}

    public func startRecording() {
        lock.lock()
        defer { lock.unlock() }
        isRecording = true
        startTime = ProcessInfo.processInfo.systemUptime
        samples.removeAll()
    }

    public func recordSample(state: GamepadState) {
        lock.lock()
        defer { lock.unlock() }
        guard isRecording else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let offset = now - startTime
        samples.append(GestureSample(timestampOffset: offset, state: state))
    }

    public func stopRecording() -> GestureClip? {
        lock.lock()
        defer { lock.unlock() }
        guard isRecording else { return nil }
        isRecording = false
        let totalDuration = samples.last?.timestampOffset ?? 0.0
        let clip = GestureClip(name: "Gesture \(Date().formatted(date: .omitted, time: .shortened))", duration: totalDuration, samples: samples)
        samples.removeAll()
        return clip
    }
}
