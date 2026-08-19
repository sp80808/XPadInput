import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio
import XPadCore

public enum OscillatorType: String, CaseIterable, Codable, Sendable {
    case sine = "Sine"
    case saw = "Sawtooth"
    case square = "Square"
    case triangle = "Triangle"
    case noise = "Noise"
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
    /// How far the amplitude envelope opens the filter on attack (0 = static cutoff).
    public var filterEnvelopeAmount: Double
    /// How much velocity brightens the filter (0 = amplitude only).
    public var velocityToFilter: Double

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
        saturationAmount: Double = 0.0,
        filterEnvelopeAmount: Double = 0.35,
        velocityToFilter: Double = 0.28
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
        self.filterEnvelopeAmount = filterEnvelopeAmount
        self.velocityToFilter = velocityToFilter
    }

    public static let polyLead = SynthPreset(
        id: "polyLead",
        name: "Poly Lead",
        osc1Type: .saw,
        osc2Type: .square,
        attack: 0.006,
        decay: 0.16,
        sustain: 0.62,
        release: 0.18,
        filterCutoffHz: 2400,
        filterResonance: 0.32,
        filterType: .lowPass,
        osc2Level: 0.38,
        osc2DetuneCents: 8.0,
        saturationAmount: 0.14,
        filterEnvelopeAmount: 0.62,
        velocityToFilter: 0.4
    )
    
    public static let rhodesEP = SynthPreset(
        id: "rhodesEP",
        name: "Rhodes EP",
        osc1Type: .sine,
        osc2Type: .triangle,
        attack: 0.003,
        decay: 0.55,
        sustain: 0.42,
        release: 0.28,
        filterCutoffHz: 2100,
        filterResonance: 0.12,
        filterType: .lowPass,
        osc2Level: 0.28,
        osc2DetuneCents: 6.0,
        saturationAmount: 0.1,
        filterEnvelopeAmount: 0.38,
        velocityToFilter: 0.22
    )
    
    public static let ambientPad = SynthPreset(
        id: "ambientPad",
        name: "Ambient Pad",
        osc1Type: .saw,
        osc2Type: .sine,
        attack: 0.28,
        decay: 0.55,
        sustain: 0.88,
        release: 1.35,
        filterCutoffHz: 1500,
        filterResonance: 0.18,
        filterType: .lowPass,
        osc2Level: 0.34,
        osc2DetuneCents: 11.0,
        saturationAmount: 0.12,
        filterEnvelopeAmount: 0.28,
        velocityToFilter: 0.18
    )
    
    public static let warmPad = SynthPreset(
        id: "warmPad",
        name: "Warm Pad",
        osc1Type: .triangle,
        osc2Type: .sine,
        attack: 0.22,
        decay: 0.65,
        sustain: 0.84,
        release: 1.1,
        filterCutoffHz: 1200,
        filterResonance: 0.16,
        filterType: .lowPass,
        osc2Level: 0.4,
        osc2DetuneCents: 7.0,
        saturationAmount: 0.08,
        filterEnvelopeAmount: 0.22,
        velocityToFilter: 0.15
    )
    
    public static let pluck = SynthPreset(
        id: "pluck",
        name: "Acoustic Pluck",
        osc1Type: .triangle,
        osc2Type: .saw,
        attack: 0.001,
        decay: 0.16,
        sustain: 0.12,
        release: 0.09,
        filterCutoffHz: 3200,
        filterResonance: 0.28,
        filterType: .lowPass,
        osc2Level: 0.22,
        osc2DetuneCents: 4.0,
        saturationAmount: 0.06,
        filterEnvelopeAmount: 0.78,
        velocityToFilter: 0.45
    )
    
    public static let subBass = SynthPreset(
        id: "subBass",
        name: "Sub Bass",
        osc1Type: .sine,
        osc2Type: .sine,
        attack: 0.006,
        decay: 0.12,
        sustain: 0.9,
        release: 0.18,
        filterCutoffHz: 420,
        filterResonance: 0.08,
        filterType: .lowPass,
        osc2Level: 0.12,
        osc2DetuneCents: 3.0,
        saturationAmount: 0.16,
        filterEnvelopeAmount: 0.35,
        velocityToFilter: 0.12
    )
    
    public static let analogBrass = SynthPreset(
        id: "analogBrass",
        name: "Analog Brass",
        osc1Type: .saw,
        osc2Type: .square,
        attack: 0.035,
        decay: 0.28,
        sustain: 0.68,
        release: 0.22,
        filterCutoffHz: 1600,
        filterResonance: 0.42,
        filterType: .lowPass,
        osc2Level: 0.46,
        osc2DetuneCents: 4.0,
        saturationAmount: 0.14,
        filterEnvelopeAmount: 0.55,
        velocityToFilter: 0.32
    )
    
    public static let digitalBell = SynthPreset(
        id: "digitalBell",
        name: "Digital Bell",
        osc1Type: .sine,
        osc2Type: .sine,
        attack: 0.001,
        decay: 0.62,
        sustain: 0.22,
        release: 0.45,
        filterCutoffHz: 3800,
        filterResonance: 0.48,
        filterType: .lowPass,
        osc2Level: 0.46,
        osc2DetuneCents: 19.0,
        saturationAmount: 0.04,
        filterEnvelopeAmount: 0.42,
        velocityToFilter: 0.2
    )

    public static let allPresets: [SynthPreset] = [
        .polyLead, .rhodesEP, .ambientPad, .warmPad, .pluck, .subBass, 
        .analogBrass, .digitalBell
    ]
}

/// Simple polyphonic synthesizer using AVAudioEngine.
@Observable
public final class AudioEngine: @unchecked Sendable {
    public static let shared = AudioEngine()
    
    public var isRunning: Bool = false
    public var volume: Float = 0.7
    public var currentPreset: SynthPreset = .polyLead
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
    
    private var engine: AVAudioEngine?
    private var mixer: AVAudioMixerNode?
    private var equalizer: AVAudioUnitEQ?
    private var compressor: AVAudioUnitEffect?
    private var reverb: AVAudioUnitReverb?
    private var limiter: AVAudioUnitEffect?
    private var voices: [UInt8: SynthVoice] = [:]
    private var releasingVoices: [ObjectIdentifier: SynthVoice] = [:]
    private var percussionVoices: [ObjectIdentifier: PercussionVoice] = [:]
    private var voicePool: [SynthVoice] = []
    private let lock = NSLock()
    private var sampleRate: Double = 44_100
    private let maxVoices = 16
    private let maxPercussionVoices = 24
    /// Target hardware I/O buffer. 128 frames is 2.7 ms at 48 kHz / 2.9 ms at 44.1 kHz.
    public static let preferredIOBufferFrames: UInt32 = 128
    
    public init() {
        setupEngine()
    }
    
    deinit {
        stop()
    }
    
    private func setupEngine() {
        let engine = AVAudioEngine()
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

        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        sampleRate = hardwareRate > 0 ? hardwareRate : 44_100
        configureLowLatencyIO(engine)
        allocateVoicePool(engine: engine, mixer: mixer)

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

    private func configureLowLatencyIO(_ engine: AVAudioEngine) {
        engine.outputNode.auAudioUnit.maximumFramesToRender = Self.preferredIOBufferFrames
        guard let audioUnit = engine.outputNode.audioUnit else { return }
        var frames = Self.preferredIOBufferFrames
        AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_MaximumFramesPerSlice,
            kAudioUnitScope_Global,
            0,
            &frames,
            UInt32(MemoryLayout<UInt32>.size)
        )

        var deviceID = AudioDeviceID(0)
        var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let deviceStatus = AudioUnitGetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            &deviceSize
        )
        guard deviceStatus == noErr, deviceID != 0 else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &frames
        )
    }

    private func allocateVoicePool(engine: AVAudioEngine, mixer: AVAudioMixerNode) {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        voicePool.reserveCapacity(maxVoices)
        for _ in 0..<maxVoices {
            let voice = SynthVoice(sampleRate: sampleRate)
            engine.attach(voice.sourceNode)
            engine.connect(voice.sourceNode, to: mixer, format: format)
            voicePool.append(voice)
        }
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

        configureLowLatencyIO(engine)
        do {
            try engine.start()
            isRunning = true
            configureLowLatencyIO(engine)
            attachLoopback()
        } catch {
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

        if !isRunning {
            start()
        }

        lock.lock()
        if let existing = voices[note] {
            releasingVoices.removeValue(forKey: ObjectIdentifier(existing))
            existing.trigger(
                note: note,
                velocity: velocity,
                technique: technique,
                preset: currentPreset,
                velocityCurve: velocityCurve
            )
            lock.unlock()
            return
        }

        if let releasing = releasingVoices.first(where: { $0.value.assignedNote == note }) {
            releasingVoices.removeValue(forKey: releasing.key)
            releasing.value.trigger(
                note: note,
                velocity: velocity,
                technique: technique,
                preset: currentPreset,
                velocityCurve: velocityCurve
            )
            voices[note] = releasing.value
            lock.unlock()
            return
        }

        let voice = acquirePooledVoiceLocked()
        if let previousNote = voice.assignedNote, previousNote != note {
            voices.removeValue(forKey: previousNote)
        }
        releasingVoices.removeValue(forKey: ObjectIdentifier(voice))
        voice.trigger(
            note: note,
            velocity: velocity,
            technique: technique,
            preset: currentPreset,
            velocityCurve: velocityCurve
        )
        voices[note] = voice
        lock.unlock()
    }

    private func acquirePooledVoiceLocked() -> SynthVoice {
        if let idle = voicePool.first(where: { $0.isIdle }) {
            return idle
        }

        if let releasing = releasingVoices.values.min(by: { $0.startTime < $1.startTime }) {
            releasingVoices.removeValue(forKey: ObjectIdentifier(releasing))
            releasing.hardStop()
            return releasing
        }

        if let oldest = voices.min(by: { $0.value.startTime < $1.value.startTime }) {
            voices.removeValue(forKey: oldest.key)
            oldest.value.hardStop()
            return oldest.value
        }

        return voicePool[0]
    }

    /// Plays a short one-shot through the same EQ, compressor, reverb and
    /// limiter as the melodic synth. The matching General MIDI note is exposed
    /// on `BuiltInDrumSound` so Duo mode can mirror the hit to a DAW.
    public func triggerDrum(_ sound: BuiltInDrumSound, velocity: UInt8) {
        guard velocity > 0, let engine, let mixer else { return }

        if !isRunning {
            start()
        }

        let voice = PercussionVoice(
            sound: sound,
            velocity: velocity,
            velocityCurve: velocityCurve,
            sampleRate: sampleRate
        )
        let voiceID = ObjectIdentifier(voice)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

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

        DispatchQueue.main.asyncAfter(deadline: .now() + voice.duration + 0.03) { [weak self] in
            self?.finishPercussionVoice(voice)
        }
    }
    
    public func noteOff(note: UInt8) {
        lock.lock()
        if let voice = voices.removeValue(forKey: note) {
            voice.startRelease()
            releasingVoices[ObjectIdentifier(voice)] = voice
            let releaseTime = voice.releaseTime
            lock.unlock()

            DispatchQueue.main.asyncAfter(deadline: .now() + releaseTime) { [weak self] in
                self?.finishRelease(voice)
            }
        } else {
            lock.unlock()
        }
    }
    
    public func allNotesOff() {
        lock.lock()
        let voicesToStop = Array(voices.values) + Array(releasingVoices.values)
        let percussionToStop = Array(percussionVoices.values)
        voices.removeAll()
        releasingVoices.removeAll()
        percussionVoices.removeAll()
        lock.unlock()

        for voice in voicesToStop {
            voice.hardStop()
        }
        for voice in percussionToStop {
            voice.stop()
            engine?.detach(voice.sourceNode)
        }
    }

    /// Includes active voices and envelope tails still connected to the mixer.
    public var trackedVoiceCount: Int {
        lock.lock()
        let count = voices.count + releasingVoices.count
        lock.unlock()
        return count
    }

    public var trackedDrumVoiceCount: Int {
        lock.lock()
        let count = percussionVoices.count
        lock.unlock()
        return count
    }

    /// Preallocated source nodes attached for the life of the engine. Attack
    /// never grows this set; stealing reuses an existing node in place.
    public var pooledVoiceCount: Int {
        lock.lock()
        let count = voicePool.count
        lock.unlock()
        return count
    }

    private func finishRelease(_ voice: SynthVoice) {
        lock.lock()
        let wasTracked = releasingVoices.removeValue(forKey: ObjectIdentifier(voice)) != nil
        lock.unlock()

        guard wasTracked else { return }
        voice.markIdleIfReleased()
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
        voices[note]?.setPitchOffset(semitones)
        lock.unlock()
    }

    public func currentPitchBend(for note: UInt8) -> Double? {
        lock.lock()
        let bend = voices[note]?.currentPitchOffset
        lock.unlock()
        return bend
    }

    public func setPressure(for note: UInt8, pressure: Double) {
        lock.lock()
        voices[note]?.setPressure(pressure)
        lock.unlock()
    }

    public func setTimbre(for note: UInt8, timbre: Double) {
        lock.lock()
        voices[note]?.setTimbre(timbre)
        lock.unlock()
    }

    public func setDamping(for note: UInt8, damping: Double) {
        lock.lock()
        voices[note]?.setDamping(damping)
        lock.unlock()
    }

    public func setHarmonicEmphasis(for note: UInt8, amount: Double, pinch: Bool) {
        lock.lock()
        voices[note]?.setHarmonic(amount: amount, pinch: pinch)
        lock.unlock()
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
        mixer?.outputVolume = volume
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
