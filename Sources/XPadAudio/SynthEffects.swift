import AVFoundation
import Foundation

/// A predictable velocity response for the built-in synth and drum voices.
///
/// `balanced` is the default: it lifts quiet controller gestures enough to be
/// audible without flattening the upper half of the player's dynamic range.
public enum SynthVelocityCurve: String, CaseIterable, Codable, Sendable, Identifiable {
    case balanced = "Balanced"
    case expressive = "Expressive"
    case even = "Even"

    public var id: String { rawValue }

    public func normalizedAmplitude(for velocity: UInt8) -> Double {
        let value = Double(velocity) / 127.0
        guard value > 0 else { return 0 }

        switch self {
        case .balanced:
            return 0.07 + 0.93 * pow(value, 0.72)
        case .expressive:
            return value
        case .even:
            return 0.14 + 0.86 * pow(value, 0.55)
        }
    }
}

public struct SynthEqualizerSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var lowGainDB: Float
    public var midGainDB: Float
    public var highGainDB: Float

    public init(
        isEnabled: Bool = true,
        lowGainDB: Float = 1.0,
        midGainDB: Float = -1.0,
        highGainDB: Float = 0.75
    ) {
        self.isEnabled = isEnabled
        self.lowGainDB = lowGainDB
        self.midGainDB = midGainDB
        self.highGainDB = highGainDB
    }

    public var normalized: Self {
        var value = self
        value.lowGainDB = value.lowGainDB.clamped(to: -12...12)
        value.midGainDB = value.midGainDB.clamped(to: -12...12)
        value.highGainDB = value.highGainDB.clamped(to: -12...12)
        return value
    }
}

public struct SynthCompressorSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var thresholdDB: Float
    public var headroomDB: Float
    public var attackMilliseconds: Float
    public var releaseMilliseconds: Float
    public var makeupGainDB: Float

    public init(
        isEnabled: Bool = true,
        thresholdDB: Float = -18,
        headroomDB: Float = 5,
        attackMilliseconds: Float = 8,
        releaseMilliseconds: Float = 120,
        makeupGainDB: Float = 1.5
    ) {
        self.isEnabled = isEnabled
        self.thresholdDB = thresholdDB
        self.headroomDB = headroomDB
        self.attackMilliseconds = attackMilliseconds
        self.releaseMilliseconds = releaseMilliseconds
        self.makeupGainDB = makeupGainDB
    }

    public var normalized: Self {
        var value = self
        value.thresholdDB = value.thresholdDB.clamped(to: -40 ... -1)
        value.headroomDB = value.headroomDB.clamped(to: 0.1...20)
        value.attackMilliseconds = value.attackMilliseconds.clamped(to: 0.1...100)
        value.releaseMilliseconds = value.releaseMilliseconds.clamped(to: 20...500)
        value.makeupGainDB = value.makeupGainDB.clamped(to: -6...12)
        return value
    }
}

public enum SynthReverbStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case studio = "Studio"
    case room = "Room"
    case plate = "Plate"

    public var id: String { rawValue }

    var factoryPreset: AVAudioUnitReverbPreset {
        switch self {
        case .studio: .mediumRoom
        case .room: .smallRoom
        case .plate: .plate
        }
    }
}

public struct SynthReverbSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var style: SynthReverbStyle
    /// Wet signal percentage. Kept deliberately light for live playing.
    public var mixPercent: Float

    public init(
        isEnabled: Bool = true,
        style: SynthReverbStyle = .studio,
        mixPercent: Float = 10
    ) {
        self.isEnabled = isEnabled
        self.style = style
        self.mixPercent = mixPercent
    }

    public var normalized: Self {
        var value = self
        value.mixPercent = value.mixPercent.clamped(to: 0...35)
        return value
    }
}

/// UI-facing state for the built-in master effects popover.
public struct SynthEffectsSettings: Codable, Equatable, Sendable {
    public var equalizer: SynthEqualizerSettings
    public var compressor: SynthCompressorSettings
    public var reverb: SynthReverbSettings

    public init(
        equalizer: SynthEqualizerSettings = .init(),
        compressor: SynthCompressorSettings = .init(),
        reverb: SynthReverbSettings = .init()
    ) {
        self.equalizer = equalizer
        self.compressor = compressor
        self.reverb = reverb
    }

    public static let polished = SynthEffectsSettings()

    public var normalized: Self {
        SynthEffectsSettings(
            equalizer: equalizer.normalized,
            compressor: compressor.normalized,
            reverb: reverb.normalized
        )
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
