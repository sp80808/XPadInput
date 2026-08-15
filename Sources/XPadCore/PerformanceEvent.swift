import Foundation

/// Real-time expressive performance events produced by Gamepad gestures or Sequencer.
public enum PerformanceEvent: Codable, Equatable, Sendable {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8)
    case pitchBend(channel: UInt8, value: Int16) // -8192 to 8191
    case polyPressure(channel: UInt8, note: UInt8, pressure: UInt8)
    case channelPressure(channel: UInt8, pressure: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case timbreCC74(channel: UInt8, value: UInt8)
    case allNotesOff(channel: UInt8)
}

/// Global transport and tempo state.
public struct TransportState: Codable, Sendable {
    public var isPlaying: Bool
    public var isRecording: Bool
    public var bpm: Double
    public var timeSignatureNumerator: Int
    public var timeSignatureDenominator: Int
    public var currentTick: UInt64
    public var loopEnabled: Bool
    public var loopStartTick: UInt64
    public var loopEndTick: UInt64

    public init(
        isPlaying: Bool = false,
        isRecording: Bool = false,
        bpm: Double = 120.0,
        timeSignatureNumerator: Int = 4,
        timeSignatureDenominator: Int = 4,
        currentTick: UInt64 = 0,
        loopEnabled: Bool = true,
        loopStartTick: UInt64 = 0,
        loopEndTick: UInt64 = 960 * 4 * 4 // 4 bars at 960 PPQN
    ) {
        self.isPlaying = isPlaying
        self.isRecording = isRecording
        self.bpm = bpm
        self.timeSignatureNumerator = timeSignatureNumerator
        self.timeSignatureDenominator = timeSignatureDenominator
        self.currentTick = currentTick
        self.loopEnabled = loopEnabled
        self.loopStartTick = loopStartTick
        self.loopEndTick = loopEndTick
    }

    public var currentBar: Int {
        let ticksPerBar = UInt64(960 * timeSignatureNumerator)
        return Int(currentTick / ticksPerBar) + 1
    }

    public var currentBeat: Double {
        let ticksPerBeat = 960.0
        return Double(currentTick % UInt64(960 * timeSignatureNumerator)) / ticksPerBeat + 1.0
    }
}
