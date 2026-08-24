import Foundation
import AVFoundation
import AudioToolbox
import os
import XPadCore
import XPadTheory

public enum OscillatorType: String, CaseIterable, Codable, Sendable {
    case sine = "Sine"
    case saw = "Sawtooth"
    case square = "Square"
    case triangle = "Triangle"
    case noise = "Noise"
    case unison = "Unison Saw"
    case strings = "Strings"
}

public enum FilterType: String, CaseIterable, Codable, Sendable {
    case lowPass = "Low Pass"
    case highPass = "High Pass"
    case bandPass = "Band Pass"
}

public struct SynthPreset: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let osc1Type: OscillatorType
    public let osc2Type: OscillatorType
    public let attack: Double
    public let decay: Double
    public let sustain: Double
    public let release: Double

    public var filterCutoffHz: Double
    public var filterResonance: Double
    public var filterType: FilterType
    public var osc2Level: Double
    public var osc2DetuneCents: Double
    public var saturationAmount: Double

    public init(
        id: String,
        name: String,
        osc1Type: OscillatorType,
        osc2Type: OscillatorType,
        attack: Double = 0.01,
        decay: Double = 0.1,
        sustain: Double = 0.8,
        release: Double = 0.2,
        filterCutoffHz: Double = 2800,
        filterResonance: Double = 0.0,
        filterType: FilterType = .lowPass,
        osc2Level: Double = 0.36,
        osc2DetuneCents: Double = 5.0,
        saturationAmount: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.osc1Type = osc1Type
        self.osc2Type = osc2Type
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.filterCutoffHz = filterCutoffHz
        self.filterResonance = filterResonance
        self.filterType = filterType
        self.osc2Level = osc2Level
        self.osc2DetuneCents = osc2DetuneCents
        self.saturationAmount = saturationAmount
    }

    public static let acousticSine = SynthPreset(
        id: "acousticSine",
        name: "Acoustic Sine (Default)",
        osc1Type: .sine,
        osc2Type: .triangle,
        attack: 0.005,
        decay: 0.38,
        sustain: 0.58,
        release: 0.35,
        filterCutoffHz: 2600,
        filterResonance: 0.18,
        filterType: .lowPass,
        osc2Level: 0.28,
        osc2DetuneCents: 2.0,
        saturationAmount: 0.06
    )

    public static let nylonSine = SynthPreset(
        id: "nylonSine",
        name: "Nylon Sine Guitar",
        osc1Type: .sine,
        osc2Type: .sine,
        attack: 0.008,
        decay: 0.42,
        sustain: 0.52,
        release: 0.40,
        filterCutoffHz: 2100,
        filterResonance: 0.12,
        filterType: .lowPass,
        osc2Level: 0.22,
        osc2DetuneCents: 1.5,
        saturationAmount: 0.04
    )

    public static let cleanElectricSine = SynthPreset(
        id: "cleanElectricSine",
        name: "Clean Electric Sine",
        osc1Type: .sine,
        osc2Type: .triangle,
        attack: 0.004,
        decay: 0.35,
        sustain: 0.62,
        release: 0.30,
        filterCutoffHz: 3100,
        filterResonance: 0.22,
        filterType: .lowPass,
        osc2Level: 0.32,
        osc2DetuneCents: 3.0,
        saturationAmount: 0.08
    )

    public static let polyLead = SynthPreset(
        id: "polyLead",
        name: "Poly Lead",
        osc1Type: .saw,
        osc2Type: .square,
        attack: 0.01,
        decay: 0.1,
        sustain: 0.7,
        release: 0.15,
        filterCutoffHz: 3200,
        filterResonance: 0.35,
        filterType: .lowPass,
        osc2Level: 0.42,
        osc2DetuneCents: 7.0,
        saturationAmount: 0.12
    )
    
    public static let rhodesEP = SynthPreset(
        id: "rhodesEP",
        name: "Rhodes EP",
        osc1Type: .sine,
        osc2Type: .triangle,
        attack: 0.005,
        decay: 0.4,
        sustain: 0.5,
        release: 0.3,
        filterCutoffHz: 2800,
        filterResonance: 0.15,
        filterType: .lowPass,
        osc2Level: 0.32,
        osc2DetuneCents: 2.0,
        saturationAmount: 0.08
    )
    
    public static let ambientPad = SynthPreset(
        id: "ambientPad",
        name: "Ambient Pad",
        osc1Type: .saw,
        osc2Type: .sine,
        attack: 0.3,
        decay: 0.5,
        sustain: 0.9,
        release: 1.2,
        filterCutoffHz: 1800,
        filterResonance: 0.25,
        filterType: .lowPass,
        osc2Level: 0.38,
        osc2DetuneCents: 12.0,
        saturationAmount: 0.15
    )
    
    public static let warmPad = SynthPreset(
        id: "warmPad",
        name: "Warm Pad",
        osc1Type: .triangle,
        osc2Type: .sine,
        attack: 0.25,
        decay: 0.6,
        sustain: 0.85,
        release: 1.0,
        filterCutoffHz: 1400,
        filterResonance: 0.2,
        filterType: .lowPass,
        osc2Level: 0.45,
        osc2DetuneCents: 8.0,
        saturationAmount: 0.1
    )
    
    public static let pluck = SynthPreset(
        id: "pluck",
        name: "Acoustic Pluck",
        osc1Type: .triangle,
        osc2Type: .saw,
        attack: 0.002,
        decay: 0.2,
        sustain: 0.15,
        release: 0.1,
        filterCutoffHz: 3800,
        filterResonance: 0.4,
        filterType: .lowPass,
        osc2Level: 0.28,
        osc2DetuneCents: 5.0,
        saturationAmount: 0.05
    )
    
    public static let subBass = SynthPreset(
        id: "subBass",
        name: "Sub Bass",
        osc1Type: .sine,
        osc2Type: .sine,
        attack: 0.01,
        decay: 0.1,
        sustain: 0.9,
        release: 0.2,
        filterCutoffHz: 800,
        filterResonance: 0.0,
        filterType: .lowPass,
        osc2Level: 0.0,
        osc2DetuneCents: 0.0,
        saturationAmount: 0.18
    )
    
    public static let analogBrass = SynthPreset(
        id: "analogBrass",
        name: "Analog Brass",
        osc1Type: .saw,
        osc2Type: .square,
        attack: 0.02,
        decay: 0.3,
        sustain: 0.7,
        release: 0.25,
        filterCutoffHz: 2000,
        filterResonance: 0.5,
        filterType: .lowPass,
        osc2Level: 0.5,
        osc2DetuneCents: 3.0,
        saturationAmount: 0.12
    )
    
    public static let digitalBell = SynthPreset(
        id: "digitalBell",
        name: "Digital Bell",
        osc1Type: .sine,
        osc2Type: .sine,
        attack: 0.001,
        decay: 0.5,
        sustain: 0.3,
        release: 0.4,
        filterCutoffHz: 4500,
        filterResonance: 0.6,
        filterType: .lowPass,
        osc2Level: 0.5,
        osc2DetuneCents: 19.0,
        saturationAmount: 0.0
    )

    public static let allPresets: [SynthPreset] = [
        .acousticSine, .nylonSine, .cleanElectricSine,
        .polyLead, .rhodesEP, .ambientPad, .warmPad, .pluck, .subBass, 
        .analogBrass, .digitalBell,
        .superSaw, .jungStrings, .glassyBell
    ]

    // MARK: - New quality presets

    /// Seven detuned saws for a thick supersaw sound
    public static let superSaw = SynthPreset(
        id: "superSaw",
        name: "Super Saw",
        osc1Type: .unison,
        osc2Type: .saw,
        attack: 0.01,
        decay: 0.18,
        sustain: 0.78,
        release: 0.32,
        filterCutoffHz: 3600,
        filterResonance: 0.30,
        filterType: .lowPass,
        osc2Level: 0.18,
        osc2DetuneCents: 12.0,
        saturationAmount: 0.10
    )

    /// Slow-attack string ensemble using the strings oscillator
    public static let jungStrings = SynthPreset(
        id: "jungStrings",
        name: "String Ensemble",
        osc1Type: .strings,
        osc2Type: .triangle,
        attack: 0.18,
        decay: 0.55,
        sustain: 0.88,
        release: 0.9,
        filterCutoffHz: 2200,
        filterResonance: 0.15,
        filterType: .lowPass,
        osc2Level: 0.22,
        osc2DetuneCents: 6.0,
        saturationAmount: 0.06
    )

    /// Clean FM-style bell with triangle + detuned sine for inharmonic shimmer
    public static let glassyBell = SynthPreset(
        id: "glassyBell",
        name: "Glassy Bell",
        osc1Type: .triangle,
        osc2Type: .sine,
        attack: 0.001,
        decay: 0.65,
        sustain: 0.22,
        release: 0.55,
        filterCutoffHz: 5500,
        filterResonance: 0.55,
        filterType: .lowPass,
        osc2Level: 0.42,
        osc2DetuneCents: 24.0,
        saturationAmount: 0.0
    )
}

/// Simple polyphonic synthesizer using AVAudioEngine.
@Observable
public final class AudioEngine: @unchecked Sendable {
    public static let shared = AudioEngine()
    
    public var isRunning: Bool = false

    /// Human-readable description of the most recent engine start failure.
    /// `nil` once the engine starts successfully.
    public private(set) var startErrorDescription: String?
    public var volume: Float = 0.7
    public private(set) var isMuted: Bool = false
    public var currentPreset: SynthPreset = .acousticSine
    public private(set) var velocityCurve: SynthVelocityCurve = .balanced
    public private(set) var effectsSettings: SynthEffectsSettings = .polished

    public func setPreset(_ preset: SynthPreset) {
        self.currentPreset = preset
    }

    public func setVelocityCurve(_ curve: SynthVelocityCurve) {
        velocityCurve = curve
    }

    /// Applies the complete master-chain state in one observable update.
    public func setEffectsSettings(_ settings: SynthEffectsSettings) {
        let settings = settings.normalized
        effectsSettings = settings
        configureEqualizer(settings.equalizer)
        configureCompressor(settings.compressor)
        configureReverb(settings.reverb)
    }

    public func setEqualizer(_ settings: SynthEqualizerSettings) {
        let settings = settings.normalized
        effectsSettings.equalizer = settings
        configureEqualizer(settings)
    }

    public func setCompressor(_ settings: SynthCompressorSettings) {
        let settings = settings.normalized
        effectsSettings.compressor = settings
        configureCompressor(settings)
    }

    public func setReverb(_ settings: SynthReverbSettings) {
        let settings = settings.normalized
        let styleChanged = settings.style != effectsSettings.reverb.style
        effectsSettings.reverb = settings
        configureReverb(settings, reloadPreset: styleChanged)
    }
    
    public let spatialEngine = SpatialAudioEngine()

    public func setSpatialCoordinates(azimuth: Float, elevation: Float, distance: Float) {
        spatialEngine.setCoordinates(azimuth: azimuth, elevation: elevation, distance: distance)
    }

    public func updateSpatialFromIMU(gyroPitch: Float, gyroRoll: Float, gyroYaw: Float, accelMagnitude: Float = 1.0) {
        spatialEngine.updateFromIMU(gyroPitch: gyroPitch, gyroRoll: gyroRoll, gyroYaw: gyroYaw, accelMagnitude: accelMagnitude)
    }

    public func setSpatialMode(_ mode: SpatialAudioMode) {
        spatialEngine.mode = mode
    }

    public func setSpatialEnabled(_ enabled: Bool) {
        spatialEngine.isEnabled = enabled
    }

    public var temperament: MicrotonalTemperament = .equalTemperament
    public var scaleRoot: PitchClass = .c
    public var activeChordRoot: PitchClass? = nil
    public var isMinorChord: Bool = false

    private var engine: AVAudioEngine?
    private var mixer: AVAudioMixerNode?
    private var equalizer: AVAudioUnitEQ?
    private var compressor: AVAudioUnitEffect?
    private var reverb: AVAudioUnitReverb?
    private var limiter: AVAudioUnitEffect?
    private var voices: [UInt8: SynthVoice] = [:]
    private var releasingVoices: [ObjectIdentifier: SynthVoice] = [:]
    private var percussionVoices: [ObjectIdentifier: PercussionVoice] = [:]
    private let lock = NSLock()
    /// Resolved once at setup from the hardware output format; never hardcoded.
    private var sampleRate: Double = 44100
    private var monoFormat: AVAudioFormat?
    private let voiceCleanupQueue = DispatchQueue(label: "com.xpadinput.audio.cleanup", qos: .userInitiated)
    private let maxVoices = 16
    private let maxPercussionVoices = 24
    
    public init() {
        setupEngine()
    }
    
    deinit {
        stop()
    }
    
    private func setupEngine() {
        let engine = AVAudioEngine()

        // Resolve the hardware sample rate so oscillator math is always correct
        // regardless of whether the device runs at 44.1 kHz, 48 kHz, 96 kHz, etc.
        let hwSampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        sampleRate = hwSampleRate > 0 ? hwSampleRate : 44100
        monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)

        // Request a small I/O buffer for lower latency (~5 ms at 48 kHz = 256 frames).
        // AVAudioEngine will pick the closest hardware-supported size; this is advisory only.
        #if os(iOS) || os(tvOS) || os(watchOS)
        do {
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
        } catch {
            // Silently ignore if not supported
        }
        #endif

        let mixer = AVAudioMixerNode()
        let equalizer = AVAudioUnitEQ(numberOfBands: 3)
        let compressor = AVAudioUnitEffect(
            audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_DynamicsProcessor,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        )
        let reverb = AVAudioUnitReverb()
        let limiter = AVAudioUnitEffect(
            audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_PeakLimiter,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        )
        
        engine.attach(mixer)
        engine.attach(equalizer)
        engine.attach(compressor)
        engine.attach(reverb)
        engine.attach(limiter)
        engine.connect(mixer, to: equalizer, format: nil)
        engine.connect(equalizer, to: compressor, format: nil)
        engine.connect(compressor, to: reverb, format: nil)
        engine.connect(reverb, to: limiter, format: nil)
        engine.connect(limiter, to: engine.mainMixerNode, format: nil)

        AudioUnitSetParameter(
            limiter.audioUnit,
            kLimiterParam_AttackTime,
            kAudioUnitScope_Global,
            0,
            0.001,
            0
        )
        AudioUnitSetParameter(
            limiter.audioUnit,
            kLimiterParam_DecayTime,
            kAudioUnitScope_Global,
            0,
            0.05,
            0
        )
        AudioUnitSetParameter(
            limiter.audioUnit,
            kLimiterParam_PreGain,
            kAudioUnitScope_Global,
            0,
            -2.0,
            0
        )
        
        mixer.outputVolume = volume
        
        self.engine = engine
        self.mixer = mixer
        self.equalizer = equalizer
        self.compressor = compressor
        self.reverb = reverb
        self.limiter = limiter

        configureEqualizer(effectsSettings.equalizer)
        configureCompressor(effectsSettings.compressor)
        configureReverb(effectsSettings.reverb)
    }

    private func configureEqualizer(_ rawSettings: SynthEqualizerSettings) {
        guard let equalizer, equalizer.bands.count >= 3 else { return }
        let settings = rawSettings.normalized

        let low = equalizer.bands[0]
        low.filterType = .lowShelf
        low.frequency = 120
        low.gain = settings.lowGainDB
        low.bypass = false

        let mid = equalizer.bands[1]
        mid.filterType = .parametric
        mid.frequency = 1_150
        mid.bandwidth = 1.1
        mid.gain = settings.midGainDB
        mid.bypass = false

        let high = equalizer.bands[2]
        high.filterType = .highShelf
        high.frequency = 6_500
        high.gain = settings.highGainDB
        high.bypass = false

        equalizer.bypass = !settings.isEnabled
    }

    private func configureCompressor(_ rawSettings: SynthCompressorSettings) {
        guard let compressor else { return }
        let settings = rawSettings.normalized
        let audioUnit = compressor.audioUnit
        AudioUnitSetParameter(audioUnit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, settings.thresholdDB, 0)
        AudioUnitSetParameter(audioUnit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, settings.headroomDB, 0)
        AudioUnitSetParameter(audioUnit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, settings.attackMilliseconds / 1_000, 0)
        AudioUnitSetParameter(audioUnit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, settings.releaseMilliseconds / 1_000, 0)
        AudioUnitSetParameter(audioUnit, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, 1, 0)
        AudioUnitSetParameter(audioUnit, kDynamicsProcessorParam_ExpansionThreshold, kAudioUnitScope_Global, 0, -80, 0)
        AudioUnitSetParameter(audioUnit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, settings.makeupGainDB, 0)
        compressor.auAudioUnit.shouldBypassEffect = !settings.isEnabled
    }

    private func configureReverb(
        _ rawSettings: SynthReverbSettings,
        reloadPreset: Bool = true
    ) {
        guard let reverb else { return }
        let settings = rawSettings.normalized
        if reloadPreset {
            reverb.loadFactoryPreset(settings.style.factoryPreset)
        }
        reverb.wetDryMix = settings.mixPercent
        reverb.bypass = !settings.isEnabled || settings.mixPercent == 0
    }
    
    public let loopbackEngine = VirtualAudioLoopbackEngine.shared

    public func attachLoopback() {
        guard let limiter = limiter else { return }
        loopbackEngine.installTap(on: limiter)
    }

    public func detachLoopback() {
        guard let limiter = limiter else { return }
        loopbackEngine.removeTap(from: limiter)
    }

    public func start() {
        guard let engine = engine, !isRunning else { return }
        
        do {
            try engine.start()
            isRunning = true
            startErrorDescription = nil
            attachLoopback()
        } catch {
            startErrorDescription = error.localizedDescription
            print("⚠️ Audio engine failed to start: \(error)")
        }
    }
    
    public func stop() {
        detachLoopback()
        allNotesOff()
        engine?.stop()
        isRunning = false
    }
    
    public func noteOn(note: UInt8, velocity: UInt8, technique: MusicalTechnique = .normal) {
        guard velocity > 0 else {
            noteOff(note: note)
            return
        }
        guard !isMuted else { return }
        guard let engine = engine, let mixer = mixer else { return }
        
        if !isRunning {
            start()
        }
        guard isRunning else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        // Stop existing voice on same note
        if let existing = voices[note] {
            existing.stop()
            engine.detach(existing.sourceNode)
            voices.removeValue(forKey: note)
        }
        
        // Steal oldest voice if at max
        if voices.count >= maxVoices {
            if let oldest = voices.min(by: { $0.value.startTime < $1.value.startTime }) {
                oldest.value.stop()
                engine.detach(oldest.value.sourceNode)
                voices.removeValue(forKey: oldest.key)
            }
        }
        
        let tuningOffset = temperament.tuningOffsetInSemitones(
            for: note,
            scaleRoot: scaleRoot,
            activeChordRoot: activeChordRoot,
            isMinorChord: isMinorChord
        )

        let voice = SynthVoice(
            note: note,
            velocity: velocity,
            sampleRate: sampleRate,
            technique: technique,
            preset: currentPreset,
            velocityCurve: velocityCurve,
            tuningOffsetSemitones: tuningOffset
        )
        
        let format = monoFormat ?? AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(voice.sourceNode)
        engine.connect(voice.sourceNode, to: mixer, format: format)
        
        voice.start()
        voices[note] = voice
    }

    /// Plays a short one-shot through the same EQ, compressor, reverb and
    /// limiter as the melodic synth. The matching General MIDI note is exposed
    /// on `BuiltInDrumSound` so Duo mode can mirror the hit to a DAW.
    public func triggerDrum(_ sound: BuiltInDrumSound, velocity: UInt8) {
        guard velocity > 0, !isMuted, let engine, let mixer else { return }

        if !isRunning {
            start()
        }
        guard isRunning else { return }

        let voice = PercussionVoice(
            sound: sound,
            velocity: velocity,
            velocityCurve: velocityCurve,
            sampleRate: sampleRate
        )
        let voiceID = ObjectIdentifier(voice)
        let format = monoFormat ?? AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        lock.lock()
        if percussionVoices.count >= maxPercussionVoices,
           let voiceToSteal = percussionVoices.first {
            voiceToSteal.value.stop()
            engine.detach(voiceToSteal.value.sourceNode)
            percussionVoices.removeValue(forKey: voiceToSteal.key)
        }
        engine.attach(voice.sourceNode)
        engine.connect(voice.sourceNode, to: mixer, format: format)
        percussionVoices[voiceID] = voice
        lock.unlock()

        voiceCleanupQueue.asyncAfter(deadline: .now() + voice.duration + 0.03) { [weak self] in
            self?.finishPercussionVoice(voice)
        }
    }
    
    public func noteOff(note: UInt8) {
        guard engine != nil else { return }
        
        lock.lock()
        guard let voice = voices[note] else {
            lock.unlock()
            return
        }
        voice.startRelease()

        // Keep release tails owned until detachment so panic can hard-stop them.
        let voiceID = ObjectIdentifier(voice)
        let releaseTime = voice.releaseTime
        voices.removeValue(forKey: note)
        releasingVoices[voiceID] = voice
        lock.unlock()

        voiceCleanupQueue.asyncAfter(deadline: .now() + releaseTime) { [weak self] in
            self?.finishRelease(voice)
        }
    }
    
    public func allNotesOff() {
        guard let engine = engine else { return }

        lock.lock()
        let voicesToStop = Array(voices.values) + Array(releasingVoices.values)
        let percussionToStop = Array(percussionVoices.values)
        voices.removeAll()
        releasingVoices.removeAll()
        percussionVoices.removeAll()
        lock.unlock()

        for voice in voicesToStop {
            voice.stop()
            engine.detach(voice.sourceNode)
        }
        for voice in percussionToStop {
            voice.stop()
            engine.detach(voice.sourceNode)
        }
    }

    /// Includes active voices and envelope tails still connected to the mixer.
    public var trackedVoiceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return voices.count + releasingVoices.count
    }

    public var trackedDrumVoiceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return percussionVoices.count
    }

    private func finishRelease(_ voice: SynthVoice) {
        guard let engine = engine else { return }

        lock.lock()
        let wasTracked = releasingVoices.removeValue(forKey: ObjectIdentifier(voice)) != nil
        lock.unlock()

        guard wasTracked else { return }
        voice.stop()
        engine.detach(voice.sourceNode)
    }

    private func finishPercussionVoice(_ voice: PercussionVoice) {
        guard let engine else { return }

        lock.lock()
        let wasTracked = percussionVoices.removeValue(forKey: ObjectIdentifier(voice)) != nil
        lock.unlock()

        guard wasTracked else { return }
        voice.stop()
        engine.detach(voice.sourceNode)
    }

    /// Applies a per-note pitch offset without retriggering the voice.
    public func setPitchBend(for note: UInt8, semitones: Double) {
        lock.lock()
        defer { lock.unlock() }
        voices[note]?.setPitchOffset(semitones)
    }

    public func currentPitchBend(for note: UInt8) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return voices[note]?.currentPitchOffset
    }

    public func setPressure(for note: UInt8, pressure: Double) {
        lock.lock()
        defer { lock.unlock() }
        voices[note]?.setPressure(pressure)
    }

    public func setTimbre(for note: UInt8, timbre: Double) {
        lock.lock()
        defer { lock.unlock() }
        voices[note]?.setTimbre(timbre)
    }

    public func setDamping(for note: UInt8, damping: Double) {
        lock.lock()
        defer { lock.unlock() }
        voices[note]?.setDamping(damping)
    }

    public func setPan(for note: UInt8, pan: Double) {
        lock.lock()
        defer { lock.unlock() }
        voices[note]?.setPan(pan)
    }

    public func setResonance(for note: UInt8, resonance: Double) {
        lock.lock()
        defer { lock.unlock() }
        voices[note]?.setResonanceOffset(resonance)
    }

    public func setRPNC(for note: UInt8, controllerIndex: UInt8, normalizedValue: Double) {
        switch controllerIndex {
        case 74: // Brightness / Timbre
            setTimbre(for: note, timbre: normalizedValue)
        case 10, 8: // Pan
            setPan(for: note, pan: normalizedValue)
        case 71: // Resonance
            setResonance(for: note, resonance: normalizedValue)
        case 1: // Modulation
            setPressure(for: note, pressure: normalizedValue)
        default:
            break
        }
    }

    public func setHarmonicEmphasis(for note: UInt8, amount: Double, pinch: Bool) {
        lock.lock()
        defer { lock.unlock() }
        voices[note]?.setHarmonic(amount: amount, pinch: pinch)
    }

    public func applyExpression(_ event: InstrumentPerformanceEvent) {
        let midi = event.note.midiNote
        setPitchBend(for: midi, semitones: event.pitchOffset)
        setPressure(for: midi, pressure: event.pressure)
        setTimbre(for: midi, timbre: event.timbre)
        setDamping(for: midi, damping: event.damping)
        if event.technique.isHarmonicFamily {
            setHarmonicEmphasis(for: midi, amount: event.technique == .pinchHarmonic ? 1.0 : 0.6, pinch: event.technique == .pinchHarmonic)
        }
    }

    public func panic() {
        allNotesOff()
    }
    
    public func setVolume(_ vol: Float) {
        volume = max(0, min(1, vol))
        if !isMuted {
            mixer?.outputVolume = volume
        }
    }

    public func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            mixer?.outputVolume = 0.0
            allNotesOff()
        } else {
            mixer?.outputVolume = volume
        }
    }

    public func toggleMute() {
        setMuted(!isMuted)
    }
}

private final class VoiceControlState: @unchecked Sendable {
    struct Snapshot {
        var note: UInt8 = 0
        var baseFrequency: Double = 440.0
        var targetAmplitude: Double = 0.8
        var attackTime: Double = 0.01
        var decayTime: Double = 0.15
        var sustainLevel: Double = 0.6
        var releaseTime: Double = 0.4
        var oscillator1: OscillatorType = .sine
        var oscillator2: OscillatorType = .triangle
        var osc2Level: Double = 0.28
        var osc2Detune: Double = 1.0
        var baseFilterCutoff: Double = 2600.0
        var filterResonance: Double = 0.0
        var filterType: FilterType = .lowPass
        var saturationAmount: Double = 0.0
        var velocity: UInt8 = 100
        var generation: UInt32 = 0
        var isIdle: Bool = true
        var isReleasing: Bool = false
        var isStopped: Bool = false
        var pitchOffset: Double = 0.0
        var pressure: Double = 0.0
        var timbre: Double = 0.5
        var damping: Double = 0.0
        var harmonic: Double = 0.0
        var pinch: Bool = false
        var pan: Double = 0.5
        var resonanceOffset: Double = 0.0
        var startTime: Date = Date()
    }

    private let state = OSAllocatedUnfairLock(initialState: Snapshot())

    func snapshot() -> Snapshot {
        state.withLock { $0 }
    }

    func trySnapshot() -> Snapshot? {
        state.withLockIfAvailable { $0 }
    }

    func trigger(
        note: UInt8,
        velocity: UInt8,
        sampleRate: Double,
        technique: MusicalTechnique,
        preset: SynthPreset,
        velocityCurve: SynthVelocityCurve,
        tuningOffsetSemitones: Double
    ) {
        let baseFrequency = 440.0 * pow(2.0, (Double(note) + tuningOffsetSemitones - 69.0) / 12.0)
        let targetAmplitude = velocityCurve.normalizedAmplitude(for: velocity)
        let rawAttack = max(0.0005, preset.attack)
        let rawDecay = max(0.005, preset.decay)
        let rawSustain = max(0, min(1, preset.sustain))
        let rawRelease = max(0.01, preset.release)

        let finalAttackTime: Double
        let finalDecayTime: Double
        let finalSustainLevel: Double
        let finalReleaseTime: Double

        switch technique {
        case .hammerOn, .pullOff, .legato:
            finalAttackTime = min(rawAttack, 0.002)
            finalDecayTime = rawDecay
            finalSustainLevel = min(rawSustain, 0.55)
            finalReleaseTime = rawRelease
        case .palmMute, .ghostNote:
            finalAttackTime = min(rawAttack, 0.001)
            finalDecayTime = min(rawDecay, 0.06)
            finalSustainLevel = min(rawSustain, 0.18)
            finalReleaseTime = min(rawRelease, 0.08)
        case .pinchHarmonic, .harmonic:
            finalAttackTime = min(rawAttack, 0.001)
            finalDecayTime = rawDecay
            finalSustainLevel = min(rawSustain, 0.45)
            finalReleaseTime = rawRelease
        default:
            finalAttackTime = rawAttack
            finalDecayTime = rawDecay
            finalSustainLevel = rawSustain
            finalReleaseTime = rawRelease
        }

        let velocityBrightness = 0.82 + 0.36 * (Double(velocity) / 127.0)
        let baseFilterCutoff = max(80, min(sampleRate * 0.42, preset.filterCutoffHz * velocityBrightness))
        let filterResonance = max(0.0, min(0.95, preset.filterResonance))
        let osc2Level = max(0.0, min(1.0, preset.osc2Level))
        let saturationAmount = max(0.0, min(1.0, preset.saturationAmount))
        let osc2Detune = pow(2.0, preset.osc2DetuneCents / 1_200.0)

        state.withLock {
            $0.note = note
            $0.baseFrequency = baseFrequency
            $0.targetAmplitude = targetAmplitude
            $0.attackTime = finalAttackTime
            $0.decayTime = finalDecayTime
            $0.sustainLevel = finalSustainLevel
            $0.releaseTime = finalReleaseTime
            $0.oscillator1 = preset.osc1Type
            $0.oscillator2 = preset.osc2Type
            $0.osc2Level = osc2Level
            $0.osc2Detune = osc2Detune
            $0.baseFilterCutoff = baseFilterCutoff
            $0.filterResonance = filterResonance
            $0.filterType = preset.filterType
            $0.saturationAmount = saturationAmount
            $0.velocity = velocity
            $0.startTime = Date()
            $0.isIdle = false
            $0.isReleasing = false
            $0.isStopped = false
            $0.generation = $0.generation &+ 1
            if technique == .pinchHarmonic {
                $0.harmonic = 1.0
                $0.pinch = true
            } else if technique == .harmonic {
                $0.harmonic = 0.6
                $0.pinch = false
            } else {
                $0.harmonic = 0.0
                $0.pinch = false
            }
        }
    }

    func startRelease() {
        state.withLock {
            if !$0.isIdle {
                $0.isReleasing = true
            }
        }
    }

    func markIdle() {
        state.withLockIfAvailable {
            $0.isIdle = true
            $0.isReleasing = false
        }
    }

    func stop() {
        state.withLock {
            $0.isStopped = true
            $0.isIdle = true
            $0.isReleasing = false
        }
    }

    func setPitchOffset(_ semitones: Double) {
        state.withLock { $0.pitchOffset = semitones }
    }

    func setPressure(_ value: Double) {
        state.withLock { $0.pressure = max(0, min(1, value)) }
    }

    func setTimbre(_ value: Double) {
        state.withLock { $0.timbre = max(0, min(1, value)) }
    }

    func setDamping(_ value: Double) {
        state.withLock { $0.damping = max(0, min(1, value)) }
    }

    func setPan(_ value: Double) {
        state.withLock { $0.pan = max(0, min(1, value)) }
    }

    func setResonanceOffset(_ value: Double) {
        state.withLock { $0.resonanceOffset = max(0, min(1, value)) }
    }

    func setHarmonic(amount: Double, pinch: Bool) {
        state.withLock {
            $0.harmonic = max(0, min(1, amount))
            $0.pinch = pinch
        }
    }
}

/// Individual synth voice generating a single note.
public final class SynthVoice: @unchecked Sendable {
    public let sourceNode: AVAudioSourceNode
    private let controlState = VoiceControlState()
    private let sampleRate: Double

    public var note: UInt8 {
        controlState.snapshot().note
    }

    public var startTime: Date {
        controlState.snapshot().startTime
    }

    public var releaseTime: Double {
        controlState.snapshot().releaseTime
    }

    public var isIdle: Bool {
        controlState.snapshot().isIdle
    }

    public var isReleasing: Bool {
        let snap = controlState.snapshot()
        return !snap.isIdle && snap.isReleasing
    }

    public var isStopped: Bool {
        controlState.snapshot().isStopped
    }

    public var currentPitchOffset: Double {
        controlState.snapshot().pitchOffset
    }

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        let control = self.controlState

        var oscillator1Phase = 0.0
        var oscillator2Phase = 0.0
        var unisonPhases: [Double] = (0..<7).map { i in Double(i) / 7.0 }
        var stringsPhases: [Double] = (0..<4).map { i in Double(i) / 4.0 }
        var envPhase = 0.0
        var releasePhase = 0.0
        var releaseStartAmp = 0.0
        var filterState1 = 0.0
        var filterState2 = 0.0
        var wasReleasing = false
        var currentGeneration: UInt32 = 0
        var cachedControlSnapshot = control.snapshot()
        var noiseState: UInt32 = 0x9E37_79B9

        self.sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            guard let rawPtr = buffer.mData else { return noErr }
            let ptr = rawPtr.assumingMemoryBound(to: Float.self)

            if let latest = control.trySnapshot() {
                cachedControlSnapshot = latest
            }
            let snap = cachedControlSnapshot

            if snap.isIdle || snap.isStopped {
                for frame in 0..<Int(frameCount) {
                    ptr[frame] = 0
                }
                return noErr
            }

            if snap.generation != currentGeneration {
                currentGeneration = snap.generation
                oscillator1Phase = 0.0
                oscillator2Phase = 0.0
                for i in 0..<7 { unisonPhases[i] = Double(i) / 7.0 }
                for i in 0..<4 { stringsPhases[i] = Double(i) / 4.0 }
                envPhase = 0.0
                releasePhase = 0.0
                releaseStartAmp = 0.0
                filterState1 = 0.0
                filterState2 = 0.0
                wasReleasing = false
                noiseState = 0x9E37_79B9 ^ UInt32(snap.note) ^ UInt32(snap.velocity)
            }

            let releasing = snap.isReleasing
            if releasing && !wasReleasing {
                releasePhase = 0
            }
            wasReleasing = releasing

            let pitchMultiplier = pow(2.0, snap.pitchOffset / 12.0)
            let frequency = snap.baseFrequency * pitchMultiplier
            let oscillator1Increment = min(frequency / sampleRate, 0.49)
            let oscillator2Increment = min(frequency * snap.osc2Detune / sampleRate, 0.49)
            let mute = snap.damping
            let expressiveCutoff = snap.baseFilterCutoff
                * (0.52 + snap.timbre * 1.15)
                * (1.0 - mute * 0.78)
            let cutoff = max(70, min(sampleRate * 0.42, expressiveCutoff))
            
            let resonance = max(0.0, min(0.95, snap.filterResonance))
            let cutoffHz = cutoff
            let filterFrequencyRad = 2.0 * .pi * cutoffHz / sampleRate
            
            let f = sin(filterFrequencyRad) * 0.5
            let q = 1.0 - f * (1.0 - resonance * 0.8)
            
            var reachedReleaseEnd = false

            for frame in 0..<Int(frameCount) {
                // Envelope
                let envValue: Double
                if releasing {
                    let releaseProgress = min(releasePhase / snap.releaseTime, 1.0)
                    envValue = releaseStartAmp * (1.0 - releaseProgress)
                    if releaseProgress >= 1.0 {
                        reachedReleaseEnd = true
                    }
                } else if envPhase < snap.attackTime {
                    envValue = (envPhase / snap.attackTime) * snap.targetAmplitude
                } else if envPhase < snap.attackTime + snap.decayTime {
                    let decayProgress = (envPhase - snap.attackTime) / snap.decayTime
                    envValue = snap.targetAmplitude - (snap.targetAmplitude - snap.targetAmplitude * snap.sustainLevel) * decayProgress
                } else {
                    envValue = snap.targetAmplitude * snap.sustainLevel
                }
                
                if !releasing {
                    releaseStartAmp = envValue
                }
                
                let pressureAmp = 0.72 + snap.pressure * 0.55
                let h = snap.harmonic

                // Generate oscillator samples
                let first: Double
                switch snap.oscillator1 {
                case .unison:
                    let unisonDetunes: [Double] = [-0.35, -0.22, -0.10, 0.0, 0.10, 0.22, 0.35]
                    var unisonMix = 0.0
                    for vi in 0..<7 {
                        let df = frequency * (pow(2.0, unisonDetunes[vi] / 12.0) - 1.0)
                        let inc = min((frequency + df) / sampleRate, 0.49)
                        let s = (unisonPhases[vi] * 2.0 - 1.0)
                            - DSPMath.polyBLEP(phase: unisonPhases[vi], increment: inc)
                        unisonMix += s
                        unisonPhases[vi] += inc
                        if unisonPhases[vi] >= 1.0 { unisonPhases[vi] -= floor(unisonPhases[vi]) }
                    }
                    first = unisonMix * 0.18
                case .strings:
                    let stringDetunes: [Double] = [-0.08, -0.025, 0.025, 0.08]
                    var strMix = 0.0
                    for vi in 0..<4 {
                        let df = frequency * (pow(2.0, stringDetunes[vi] / 12.0) - 1.0)
                        let inc = min((frequency + df) / sampleRate, 0.49)
                        let s = (stringsPhases[vi] * 2.0 - 1.0)
                            - DSPMath.polyBLEP(phase: stringsPhases[vi], increment: inc)
                        strMix += s
                        stringsPhases[vi] += inc
                        if stringsPhases[vi] >= 1.0 { stringsPhases[vi] -= floor(stringsPhases[vi]) }
                    }
                    first = strMix * 0.30
                default:
                    first = SynthVoice.oscillatorSample(
                        type: snap.oscillator1,
                        phase: oscillator1Phase,
                        increment: oscillator1Increment
                    )
                }
                
                let second = SynthVoice.oscillatorSample(
                    type: snap.oscillator2,
                    phase: oscillator2Phase,
                    increment: oscillator2Increment
                )
                
                let noiseSample: Double
                if snap.oscillator2 == .noise {
                    noiseState ^= noiseState << 13
                    noiseState ^= noiseState >> 17
                    noiseState ^= noiseState << 5
                    noiseSample = Double(Int32(bitPattern: noiseState)) / Double(Int32.max)
                } else {
                    noiseSample = 0.0
                }
                
                var sample = first * (1.0 - snap.osc2Level)
                
                if snap.oscillator2 == .noise {
                    sample += noiseSample * snap.osc2Level
                } else {
                    sample += second * snap.osc2Level
                }
                
                if h > 0 {
                    sample += h * (0.22 * sin(oscillator1Phase * 2.0 * .pi * 2.0) + 0.14 * sin(oscillator1Phase * 2.0 * .pi * 3.0))
                }
                if snap.pinch {
                    sample = sample * 0.45
                        + 0.30 * sin(oscillator1Phase * 2.0 * .pi * 3.0)
                        + 0.20 * sin(oscillator1Phase * 2.0 * .pi * 4.0)
                        + 0.12 * sin(oscillator1Phase * 2.0 * .pi * 5.0)
                }

                let saturatedSample: Double
                if snap.saturationAmount > 0 {
                    let drive = 1.0 + snap.saturationAmount * 3.5
                    let x = sample * drive
                    let x2 = x * x
                    let softClip = x * (27.0 + x2) / (27.0 + 9.0 * x2)
                    saturatedSample = softClip / drive
                } else {
                    saturatedSample = sample
                }

                let lowPass = filterState1 + f * (saturatedSample - filterState1)
                let highPass = saturatedSample - lowPass
                let bandPass = filterState2 + f * (highPass - filterState2)
                filterState2 = bandPass
                filterState1 = lowPass
                
                let filtered: Double
                switch snap.filterType {
                case .lowPass:
                    filtered = lowPass + q * bandPass
                case .highPass:
                    filtered = highPass + q * bandPass
                case .bandPass:
                    filtered = bandPass
                }
                
                let dampedEnv = envValue * (1.0 - mute * 0.55)
                let finalSample = filtered * pressureAmp * (1.0 - mute * 0.45)
                ptr[frame] = Float(tanh(finalSample * dampedEnv * 0.45))
                
                oscillator1Phase += oscillator1Increment
                if oscillator1Phase >= 1.0 { oscillator1Phase -= floor(oscillator1Phase) }
                oscillator2Phase += oscillator2Increment
                if oscillator2Phase >= 1.0 { oscillator2Phase -= floor(oscillator2Phase) }
                envPhase += 1.0 / sampleRate
                if releasing { releasePhase += 1.0 / sampleRate }
            }

            if reachedReleaseEnd {
                control.markIdle()
            }

            return noErr
        }
    }

    public convenience init(
        note: UInt8,
        velocity: UInt8,
        sampleRate: Double,
        technique: MusicalTechnique = .normal,
        preset: SynthPreset = .acousticSine,
        velocityCurve: SynthVelocityCurve = .balanced,
        tuningOffsetSemitones: Double = 0.0
    ) {
        self.init(sampleRate: sampleRate)
        trigger(
            note: note,
            velocity: velocity,
            sampleRate: sampleRate,
            technique: technique,
            preset: preset,
            velocityCurve: velocityCurve,
            tuningOffsetSemitones: tuningOffsetSemitones
        )
    }

    public func trigger(
        note: UInt8,
        velocity: UInt8,
        sampleRate: Double,
        technique: MusicalTechnique = .normal,
        preset: SynthPreset = .acousticSine,
        velocityCurve: SynthVelocityCurve = .balanced,
        tuningOffsetSemitones: Double = 0.0
    ) {
        controlState.trigger(
            note: note,
            velocity: velocity,
            sampleRate: sampleRate,
            technique: technique,
            preset: preset,
            velocityCurve: velocityCurve,
            tuningOffsetSemitones: tuningOffsetSemitones
        )
    }

    public func start() {}

    public func startRelease() {
        controlState.startRelease()
    }

    public func stop() {
        controlState.stop()
    }

    public func setPitchOffset(_ semitones: Double) {
        controlState.setPitchOffset(semitones)
    }

    public func setPressure(_ value: Double) {
        controlState.setPressure(value)
    }

    public func setTimbre(_ value: Double) {
        controlState.setTimbre(value)
    }

    public func setDamping(_ value: Double) {
        controlState.setDamping(value)
    }

    public func setPan(_ value: Double) {
        controlState.setPan(value)
    }

    public func setResonanceOffset(_ value: Double) {
        controlState.setResonanceOffset(value)
    }

    public func setHarmonic(amount: Double, pinch: Bool) {
        controlState.setHarmonic(amount: amount, pinch: pinch)
    }

    @inline(__always)
    private static func oscillatorSample(
        type: OscillatorType,
        phase: Double,
        increment: Double
    ) -> Double {
        switch type {
        case .sine:
            return sin(phase * 2.0 * .pi)
        case .saw:
            return (phase * 2.0 - 1.0) - DSPMath.polyBLEP(phase: phase, increment: increment)
        case .square:
            let raw = phase < 0.5 ? 1.0 : -1.0
            let shiftedPhase = phase < 0.5 ? phase + 0.5 : phase - 0.5
            return raw
                + DSPMath.polyBLEP(phase: phase, increment: increment)
                - DSPMath.polyBLEP(phase: shiftedPhase, increment: increment)
        case .triangle:
            return 1.0 - 4.0 * abs(phase - 0.5)
        case .noise:
            return 0.0
        case .unison:
            let saw1 = (phase * 2.0 - 1.0) - DSPMath.polyBLEP(phase: phase, increment: increment)
            let phaseDetuned = (phase * 1.003).truncatingRemainder(dividingBy: 1.0)
            let saw2 = (phaseDetuned * 2.0 - 1.0) - DSPMath.polyBLEP(phase: phaseDetuned, increment: increment)
            return (saw1 + saw2) * 0.5
        case .strings:
            let saw = (phase * 2.0 - 1.0) - DSPMath.polyBLEP(phase: phase, increment: increment)
            let sub = sin(phase * .pi)
            return saw * 0.7 + sub * 0.3
        }
    }
}

/// Lightweight envelope state machine used by audio unit tests.
public final class VoiceDSP: @unchecked Sendable {
    public var isActive = false
    public var isKeyOn = false
    public var envStage: Int = 0
    public var note: UInt8 = 0
    public var velocity: Double = 0

    public init() {}

    public func noteOn(note: UInt8, velocity: UInt8) {
        self.note = note
        self.velocity = Double(velocity) / 127.0
        isActive = true
        isKeyOn = true
        envStage = 1
    }

    public func noteOff() {
        isKeyOn = false
        envStage = 4
    }
}
