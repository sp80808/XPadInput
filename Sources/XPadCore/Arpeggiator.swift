import Foundation

/// Mathematical and musical patterns for chord note sequencing in the arpeggiator.
public enum ArpeggiatorPattern: String, CaseIterable, Codable, Sendable, Identifiable {
    case up = "Up"
    case down = "Down"
    case upDown = "Up / Down"
    case downUp = "Down / Up"
    case converge = "Converge"
    case diverge = "Diverge"
    case random = "Random"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .upDown: return "arrow.up.and.down"
        case .downUp: return "arrow.down.and.up"
        case .converge: return "arrow.triangle.merge"
        case .diverge: return "arrow.triangle.branch"
        case .random: return "shuffle"
        }
    }
}

/// Transport-synced metric subdivisions for arpeggiator step rate.
public enum ArpeggiatorRate: String, CaseIterable, Codable, Sendable, Identifiable {
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"
    case eighthTriplet = "1/8T"
    case sixteenthTriplet = "1/16T"

    public var id: String { rawValue }

    /// Standard PPQN (960 ticks per quarter note) step duration.
    public var ticksPerStep: UInt64 {
        switch self {
        case .quarter: return 960
        case .eighth: return 480
        case .sixteenth: return 240
        case .thirtySecond: return 120
        case .eighthTriplet: return 320
        case .sixteenthTriplet: return 160
        }
    }

    /// Duration of one step in seconds given a tempo in BPM.
    public func secondsPerStep(tempoBPM: Double) -> TimeInterval {
        let safeBPM = max(20.0, min(300.0, tempoBPM))
        let secondsPerQuarter = 60.0 / safeBPM
        return secondsPerQuarter * (Double(ticksPerStep) / 960.0)
    }
}

/// User-facing arpeggiator settings.
public struct ArpeggiatorConfiguration: Codable, Hashable, Sendable {
    public var pattern: ArpeggiatorPattern
    public var rate: ArpeggiatorRate
    public var octaveRange: Int
    public var gateLength: Double
    public var isLatched: Bool

    public init(
        pattern: ArpeggiatorPattern = .up,
        rate: ArpeggiatorRate = .sixteenth,
        octaveRange: Int = 1,
        gateLength: Double = 0.8,
        isLatched: Bool = false
    ) {
        self.pattern = pattern
        self.rate = rate
        self.octaveRange = max(1, min(4, octaveRange))
        self.gateLength = gateLength.isFinite ? max(0.1, min(1.0, gateLength)) : 0.8
        self.isLatched = isLatched
    }
}

/// Discrete events emitted by the ArpeggiatorEngine.
public enum ArpeggiatorEvent: Equatable, Sendable {
    case noteOn(Note, velocity: UInt8)
    case noteOff(Note)
}
