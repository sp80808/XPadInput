import Foundation
import AudioToolbox
import AVFoundation

/// Parameter addresses for Audio Unit v3 and VST3 automation.
@objc public enum XPadAUParameterAddress: UInt64, CaseIterable, Sendable {
    // Master & Synth Controls
    case masterVolume = 100
    case osc1Type = 101
    case osc2Type = 102
    case osc2Level = 103
    case osc2Detune = 104
    
    // Filter
    case filterCutoff = 200
    case filterResonance = 201
    case filterType = 202
    
    // ADSR Envelope
    case envAttack = 300
    case envDecay = 301
    case envSustain = 302
    case envRelease = 303
    
    // Effects & Saturation
    case saturation = 400
    case reverbMix = 401
    
    // Theory & Harmony Engine
    case keyRoot = 500
    case scaleType = 501
    case voiceLeadingStrategy = 502
    case harmonicLayer = 503
    case strumSpeed = 504
    case mpeBendRange = 505
}

/// Real-time snapshot of audio unit parameters for lock-free render block access.
public struct XPadAUParameterSnapshot: Sendable {
    public var masterVolume: Float = 0.7
    public var osc1Type: Float = 1.0 // 0: Sine, 1: Saw, 2: Square, 3: Triangle, 4: Noise
    public var osc2Type: Float = 2.0
    public var osc2Level: Float = 0.36
    public var osc2Detune: Float = 5.0
    
    public var filterCutoff: Float = 2800.0
    public var filterResonance: Float = 0.25
    public var filterType: Float = 0.0 // 0: Lowpass, 1: Highpass, 2: Bandpass
    
    public var attack: Float = 0.01
    public var decay: Float = 0.15
    public var sustain: Float = 0.75
    public var release: Float = 0.3
    
    public var saturation: Float = 0.1
    public var reverbMix: Float = 10.0
    
    public var keyRoot: Float = 2.0 // D
    public var scaleType: Float = 1.0 // Natural Minor
    public var voiceLeadingStrategy: Float = 0.0 // Smooth
    public var harmonicLayer: Float = 0.0 // Diatonic
    public var strumSpeed: Float = 40.0 // ms
    public var mpeBendRange: Float = 48.0 // semitones
    
    public init() {}
    
    public mutating func update(address: XPadAUParameterAddress, value: AUValue) {
        switch address {
        case .masterVolume: masterVolume = value
        case .osc1Type: osc1Type = value
        case .osc2Type: osc2Type = value
        case .osc2Level: osc2Level = value
        case .osc2Detune: osc2Detune = value
        case .filterCutoff: filterCutoff = value
        case .filterResonance: filterResonance = value
        case .filterType: filterType = value
        case .envAttack: attack = value
        case .envDecay: decay = value
        case .envSustain: sustain = value
        case .envRelease: release = value
        case .saturation: saturation = value
        case .reverbMix: reverbMix = value
        case .keyRoot: keyRoot = value
        case .scaleType: scaleType = value
        case .voiceLeadingStrategy: voiceLeadingStrategy = value
        case .harmonicLayer: harmonicLayer = value
        case .strumSpeed: strumSpeed = value
        case .mpeBendRange: mpeBendRange = value
        }
    }
}

/// Helper for constructing AUParameterTree with logically organized parameter groups.
public enum XPadAUParameterTreeBuilder {
    public static func createParameterTree() -> AUParameterTree {
        // Synth Oscillator Group
        let masterVol = AUParameterTree.createParameter(
            withIdentifier: "masterVolume",
            name: "Master Volume",
            address: XPadAUParameterAddress.masterVolume.rawValue,
            min: 0.0,
            max: 1.0,
            unit: .linearGain,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        masterVol.value = 0.7
        
        let osc1 = AUParameterTree.createParameter(
            withIdentifier: "osc1Type",
            name: "Osc 1 Waveform",
            address: XPadAUParameterAddress.osc1Type.rawValue,
            min: 0,
            max: 4,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["Sine", "Sawtooth", "Square", "Triangle", "Noise"],
            dependentParameters: nil
        )
        osc1.value = 1.0 // Saw
        
        let osc2 = AUParameterTree.createParameter(
            withIdentifier: "osc2Type",
            name: "Osc 2 Waveform",
            address: XPadAUParameterAddress.osc2Type.rawValue,
            min: 0,
            max: 4,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["Sine", "Sawtooth", "Square", "Triangle", "Noise"],
            dependentParameters: nil
        )
        osc2.value = 2.0 // Square
        
        let osc2Lvl = AUParameterTree.createParameter(
            withIdentifier: "osc2Level",
            name: "Osc 2 Level",
            address: XPadAUParameterAddress.osc2Level.rawValue,
            min: 0.0,
            max: 1.0,
            unit: .linearGain,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        osc2Lvl.value = 0.36
        
        let osc2Det = AUParameterTree.createParameter(
            withIdentifier: "osc2Detune",
            name: "Osc 2 Detune",
            address: XPadAUParameterAddress.osc2Detune.rawValue,
            min: -50.0,
            max: 50.0,
            unit: .cents,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        osc2Det.value = 5.0
        
        // Filter Group
        let cutoff = AUParameterTree.createParameter(
            withIdentifier: "filterCutoff",
            name: "Filter Cutoff",
            address: XPadAUParameterAddress.filterCutoff.rawValue,
            min: 20.0,
            max: 20000.0,
            unit: .hertz,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        cutoff.value = 2800.0
        
        let resonance = AUParameterTree.createParameter(
            withIdentifier: "filterResonance",
            name: "Filter Resonance",
            address: XPadAUParameterAddress.filterResonance.rawValue,
            min: 0.0,
            max: 0.95,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        resonance.value = 0.25
        
        let filterType = AUParameterTree.createParameter(
            withIdentifier: "filterType",
            name: "Filter Type",
            address: XPadAUParameterAddress.filterType.rawValue,
            min: 0,
            max: 2,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["Low Pass", "High Pass", "Band Pass"],
            dependentParameters: nil
        )
        filterType.value = 0.0
        
        // Envelope Group
        let attack = AUParameterTree.createParameter(
            withIdentifier: "envAttack",
            name: "Attack",
            address: XPadAUParameterAddress.envAttack.rawValue,
            min: 0.0005,
            max: 5.0,
            unit: .seconds,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        attack.value = 0.01
        
        let decay = AUParameterTree.createParameter(
            withIdentifier: "envDecay",
            name: "Decay",
            address: XPadAUParameterAddress.envDecay.rawValue,
            min: 0.005,
            max: 5.0,
            unit: .seconds,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        decay.value = 0.15
        
        let sustain = AUParameterTree.createParameter(
            withIdentifier: "envSustain",
            name: "Sustain",
            address: XPadAUParameterAddress.envSustain.rawValue,
            min: 0.0,
            max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        sustain.value = 0.75
        
        let release = AUParameterTree.createParameter(
            withIdentifier: "envRelease",
            name: "Release",
            address: XPadAUParameterAddress.envRelease.rawValue,
            min: 0.01,
            max: 10.0,
            unit: .seconds,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        release.value = 0.3
        
        // Effects Group
        let saturation = AUParameterTree.createParameter(
            withIdentifier: "saturation",
            name: "Saturation",
            address: XPadAUParameterAddress.saturation.rawValue,
            min: 0.0,
            max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        saturation.value = 0.1
        
        let reverb = AUParameterTree.createParameter(
            withIdentifier: "reverbMix",
            name: "Reverb Mix",
            address: XPadAUParameterAddress.reverbMix.rawValue,
            min: 0.0,
            max: 100.0,
            unit: .percent,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        reverb.value = 10.0
        
        // Theory & MPE Group
        let keyRoot = AUParameterTree.createParameter(
            withIdentifier: "keyRoot",
            name: "Key Root",
            address: XPadAUParameterAddress.keyRoot.rawValue,
            min: 0,
            max: 11,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"],
            dependentParameters: nil
        )
        keyRoot.value = 2.0 // D
        
        let scaleType = AUParameterTree.createParameter(
            withIdentifier: "scaleType",
            name: "Scale Type",
            address: XPadAUParameterAddress.scaleType.rawValue,
            min: 0,
            max: 6,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["Major", "Natural Minor", "Harmonic Minor", "Dorian", "Mixolydian", "Pentatonic Major", "Pentatonic Minor"],
            dependentParameters: nil
        )
        scaleType.value = 1.0 // Natural Minor
        
        let voiceLeading = AUParameterTree.createParameter(
            withIdentifier: "voiceLeadingStrategy",
            name: "Voice Leading Strategy",
            address: XPadAUParameterAddress.voiceLeadingStrategy.rawValue,
            min: 0,
            max: 3,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["Smooth", "SATB", "Bass Anchored", "Cinematic Open"],
            dependentParameters: nil
        )
        voiceLeading.value = 0.0
        
        let harmonicLayer = AUParameterTree.createParameter(
            withIdentifier: "harmonicLayer",
            name: "Harmonic Wheel Layer",
            address: XPadAUParameterAddress.harmonicLayer.rawValue,
            min: 0,
            max: 4,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: ["Diatonic", "Colour", "Borrowed", "Tension", "Mediant"],
            dependentParameters: nil
        )
        harmonicLayer.value = 0.0
        
        let strumSpeed = AUParameterTree.createParameter(
            withIdentifier: "strumSpeed",
            name: "Strum Speed",
            address: XPadAUParameterAddress.strumSpeed.rawValue,
            min: 5.0,
            max: 200.0,
            unit: .milliseconds,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        strumSpeed.value = 40.0
        
        let mpeBend = AUParameterTree.createParameter(
            withIdentifier: "mpeBendRange",
            name: "MPE Pitch Bend Range",
            address: XPadAUParameterAddress.mpeBendRange.rawValue,
            min: 1.0,
            max: 96.0,
            unit: .generic,
            unitName: "semitones",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        mpeBend.value = 48.0
        
        // Build groups
        let synthGroup = AUParameterTree.createGroup(
            withIdentifier: "synthGroup",
            name: "Synthesizer",
            children: [masterVol, osc1, osc2, osc2Lvl, osc2Det]
        )
        let filterGroup = AUParameterTree.createGroup(
            withIdentifier: "filterGroup",
            name: "Filter",
            children: [cutoff, resonance, filterType]
        )
        let envGroup = AUParameterTree.createGroup(
            withIdentifier: "envGroup",
            name: "Envelope",
            children: [attack, decay, sustain, release]
        )
        let fxGroup = AUParameterTree.createGroup(
            withIdentifier: "fxGroup",
            name: "Master Effects",
            children: [saturation, reverb]
        )
        let theoryGroup = AUParameterTree.createGroup(
            withIdentifier: "theoryGroup",
            name: "Music Theory & MPE",
            children: [keyRoot, scaleType, voiceLeading, harmonicLayer, strumSpeed, mpeBend]
        )
        
        return AUParameterTree.createTree(withChildren: [
            synthGroup,
            filterGroup,
            envGroup,
            fxGroup,
            theoryGroup
        ])
    }
}
