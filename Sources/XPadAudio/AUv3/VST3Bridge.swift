import Foundation
import AudioToolbox

/// VST3 parameter descriptor with normalized 0.0...1.0 conversion and physical unit mapping.
public struct VST3ParameterInfo: Identifiable, Sendable {
    public let id: UInt32
    public let title: String
    public let shortTitle: String
    public let units: String
    public let stepCount: Int
    public let defaultNormalizedValue: Double
    public let minValue: Double
    public let maxValue: Double
    public let auAddress: XPadAUParameterAddress
    
    public init(
        id: UInt32,
        title: String,
        shortTitle: String,
        units: String,
        stepCount: Int = 0,
        defaultNormalizedValue: Double,
        minValue: Double,
        maxValue: Double,
        auAddress: XPadAUParameterAddress
    ) {
        self.id = id
        self.title = title
        self.shortTitle = shortTitle
        self.units = units
        self.stepCount = stepCount
        self.defaultNormalizedValue = defaultNormalizedValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.auAddress = auAddress
    }
    
    /// Converts a normalized 0.0...1.0 VST3 parameter value to plain physical value.
    public func normalizedToPlain(_ normalized: Double) -> Double {
        let clamped = max(0.0, min(1.0, normalized))
        if stepCount > 0 {
            let step = round(clamped * Double(stepCount))
            return minValue + (step / Double(stepCount)) * (maxValue - minValue)
        }
        return minValue + clamped * (maxValue - minValue)
    }
    
    /// Converts a plain physical value to normalized 0.0...1.0 VST3 parameter value.
    public func plainToNormalized(_ plain: Double) -> Double {
        guard maxValue > minValue else { return 0.0 }
        let clamped = max(minValue, min(maxValue, plain))
        return (clamped - minValue) / (maxValue - minValue)
    }
}

/// VST3 compatibility bridge providing standard parameter maps and event routing.
public final class VST3Bridge: @unchecked Sendable {
    public static let shared = VST3Bridge()
    
    public let parameterInfos: [UInt32: VST3ParameterInfo]
    public let auAddressToVstID: [XPadAUParameterAddress: UInt32]
    
    public init() {
        var infos: [UInt32: VST3ParameterInfo] = [:]
        var addressMap: [XPadAUParameterAddress: UInt32] = [:]
        
        let definitions: [VST3ParameterInfo] = [
            VST3ParameterInfo(
                id: 100,
                title: "Master Volume",
                shortTitle: "Vol",
                units: "dB",
                defaultNormalizedValue: 0.7,
                minValue: 0.0,
                maxValue: 1.0,
                auAddress: .masterVolume
            ),
            VST3ParameterInfo(
                id: 200,
                title: "Filter Cutoff",
                shortTitle: "Cutoff",
                units: "Hz",
                defaultNormalizedValue: 0.5,
                minValue: 20.0,
                maxValue: 20000.0,
                auAddress: .filterCutoff
            ),
            VST3ParameterInfo(
                id: 201,
                title: "Filter Resonance",
                shortTitle: "Res",
                units: "%",
                defaultNormalizedValue: 0.25,
                minValue: 0.0,
                maxValue: 0.95,
                auAddress: .filterResonance
            ),
            VST3ParameterInfo(
                id: 300,
                title: "Attack Time",
                shortTitle: "Attack",
                units: "s",
                defaultNormalizedValue: 0.01,
                minValue: 0.0005,
                maxValue: 5.0,
                auAddress: .envAttack
            ),
            VST3ParameterInfo(
                id: 301,
                title: "Decay Time",
                shortTitle: "Decay",
                units: "s",
                defaultNormalizedValue: 0.15,
                minValue: 0.005,
                maxValue: 5.0,
                auAddress: .envDecay
            ),
            VST3ParameterInfo(
                id: 302,
                title: "Sustain Level",
                shortTitle: "Sustain",
                units: "%",
                defaultNormalizedValue: 0.75,
                minValue: 0.0,
                maxValue: 1.0,
                auAddress: .envSustain
            ),
            VST3ParameterInfo(
                id: 303,
                title: "Release Time",
                shortTitle: "Release",
                units: "s",
                defaultNormalizedValue: 0.3,
                minValue: 0.01,
                maxValue: 10.0,
                auAddress: .envRelease
            ),
            VST3ParameterInfo(
                id: 400,
                title: "Saturation Drive",
                shortTitle: "Drive",
                units: "%",
                defaultNormalizedValue: 0.1,
                minValue: 0.0,
                maxValue: 1.0,
                auAddress: .saturation
            ),
            VST3ParameterInfo(
                id: 401,
                title: "Reverb Mix",
                shortTitle: "Reverb",
                units: "%",
                defaultNormalizedValue: 0.1,
                minValue: 0.0,
                maxValue: 100.0,
                auAddress: .reverbMix
            ),
            VST3ParameterInfo(
                id: 500,
                title: "Key Root",
                shortTitle: "Key",
                units: "",
                stepCount: 11,
                defaultNormalizedValue: 2.0 / 11.0,
                minValue: 0.0,
                maxValue: 11.0,
                auAddress: .keyRoot
            ),
            VST3ParameterInfo(
                id: 501,
                title: "Scale Type",
                shortTitle: "Scale",
                units: "",
                stepCount: 6,
                defaultNormalizedValue: 1.0 / 6.0,
                minValue: 0.0,
                maxValue: 6.0,
                auAddress: .scaleType
            ),
            VST3ParameterInfo(
                id: 502,
                title: "Voice Leading",
                shortTitle: "VoiceLead",
                units: "",
                stepCount: 3,
                defaultNormalizedValue: 0.0,
                minValue: 0.0,
                maxValue: 3.0,
                auAddress: .voiceLeadingStrategy
            ),
            VST3ParameterInfo(
                id: 505,
                title: "MPE Bend Range",
                shortTitle: "BendRange",
                units: "st",
                defaultNormalizedValue: 48.0 / 96.0,
                minValue: 1.0,
                maxValue: 96.0,
                auAddress: .mpeBendRange
            )
        ]
        
        for def in definitions {
            infos[def.id] = def
            addressMap[def.auAddress] = def.id
        }
        
        self.parameterInfos = infos
        self.auAddressToVstID = addressMap
    }
}
