import Foundation
import AVFoundation
import AudioToolbox
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
    /// Host-time spent attaching/connecting a voice on the last Note On. Not acoustic latency.
    public private(set) var lastGraphMutationMs: Double = 0
    /// Host-time from Note On return to the first audio render callback. Gated probe; not acoustic latency.
    public private(set) var lastFirstBufferMs: Double = 0

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
    private let lock = NSLock()
    private let sampleRate: Double = 44100
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
        guard let engine = engine, let mixer = mixer else { return }
        
        if !isRunning {
            start()
        }
        
        let mutationStart = ProcessInfo.processInfo.systemUptime
        lock.lock()
        
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
        
        let voice = SynthVoice(
            note: note,
            velocity: velocity,
            sampleRate: sampleRate,
            technique: technique,
            preset: currentPreset,
            velocityCurve: velocityCurve
        )
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(voice.sourceNode)
        engine.connect(voice.sourceNode, to: mixer, format: format)
        
        voice.start()
        voices[note] = voice
        let armedAt = ProcessInfo.processInfo.systemUptime
        voice.firstBufferGate.arm { [weak self] t in
            self?.lastFirstBufferMs = max(0, (t - armedAt) * 1000.0)
        }
        
        lock.unlock()
        lastGraphMutationMs = max(0, (ProcessInfo.processInfo.systemUptime - mutationStart) * 1000.0)
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
        guard engine != nil else { return }
        
        lock.lock()
        if let voice = voices[note] {
            voice.startRelease()

            // Keep release tails owned until detachment so panic can hard-stop them.
            let voiceID = ObjectIdentifier(voice)
            let releaseTime = voice.releaseTime
            voices.removeValue(forKey: note)
            releasingVoices[voiceID] = voice
            lock.unlock()

            DispatchQueue.main.asyncAfter(deadline: .now() + releaseTime) { [weak self] in
                self?.finishRelease(voice)
            }
        } else {
            lock.unlock()
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

private final class VoiceControlState: @unchecked Sendable {
    struct Snapshot {
        let isReleasing: Bool
        let isStopped: Bool
        let pitchOffset: Double
        let pressure: Double
        let timbre: Double
        let damping: Double
        let harmonic: Double
        let pinch: Bool
    }

    private let lock = NSLock()
    private var isReleasing = false
    private var isStopped = false
    private var pitchOffset = 0.0
    private var pressure = 0.0
    private var timbre = 0.5
    private var damping = 0.0
    private var harmonic = 0.0
    private var pinch = false

    func snapshot() -> Snapshot {
        lock.lock()
        let value = Snapshot(
            isReleasing: isReleasing,
            isStopped: isStopped,
            pitchOffset: pitchOffset,
            pressure: pressure,
            timbre: timbre,
            damping: damping,
            harmonic: harmonic,
            pinch: pinch
        )
        lock.unlock()
        return value
    }

    /// Audio render threads never wait for control writers. If a write is in
    /// progress, the voice reuses its last complete snapshot for one buffer.
    func trySnapshot() -> Snapshot? {
        guard lock.try() else { return nil }
        let value = Snapshot(
            isReleasing: isReleasing,
            isStopped: isStopped,
            pitchOffset: pitchOffset,
            pressure: pressure,
            timbre: timbre,
            damping: damping,
            harmonic: harmonic,
            pinch: pinch
        )
        lock.unlock()
        return value
    }

    func startRelease() {
        lock.lock()
        isReleasing = true
        lock.unlock()
    }

    func stop() {
        lock.lock()
        isStopped = true
        lock.unlock()
    }

    func setPitchOffset(_ semitones: Double) {
        lock.lock()
        pitchOffset = semitones
        lock.unlock()
    }

    func setPressure(_ value: Double) {
        lock.lock()
        pressure = max(0, min(1, value))
        lock.unlock()
    }

    func setTimbre(_ value: Double) {
        lock.lock()
        timbre = max(0, min(1, value))
        lock.unlock()
    }

    func setDamping(_ value: Double) {
        lock.lock()
        damping = max(0, min(1, value))
        lock.unlock()
    }

    func setHarmonic(amount: Double, pinch: Bool) {
        lock.lock()
        harmonic = max(0, min(1, amount))
        self.pinch = pinch
        lock.unlock()
    }
}

public final class FirstBufferGate: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = true
    private var alreadyFired = false
    private var firedAt: TimeInterval = 0
    private var work: DispatchWorkItem?

    public init() {}

    public func arm(handler: @escaping (TimeInterval) -> Void) {
        lock.lock()
        work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let t = self.firedAt
            self.lock.unlock()
            handler(t)
        }
        let shouldDispatch = alreadyFired
        let item = work
        lock.unlock()
        if shouldDispatch, let item {
            DispatchQueue.main.async(execute: item)
        }
    }

    public func signalIfNeeded() {
        lock.lock()
        let shouldFire = pending
        if shouldFire {
            pending = false
            alreadyFired = true
            firedAt = ProcessInfo.processInfo.systemUptime
        }
        let item = work
        lock.unlock()
        if shouldFire, let item {
            DispatchQueue.main.async(execute: item)
        }
    }
}

/// Individual synth voice generating a single note.
public final class SynthVoice: @unchecked Sendable {
    public let note: UInt8
    public let sourceNode: AVAudioSourceNode
    public let startTime: Date
    public var releaseTime: Double = 0.4
    public let firstBufferGate = FirstBufferGate()
    
    private let baseFrequency: Double
    private var targetAmplitude: Double
    private let controlState = VoiceControlState()
    private let sampleRate: Double
    
    // Envelope
    private var attackTime: Double = 0.01
    private var decayTime: Double = 0.15
    private var sustainLevel: Double = 0.6
    
    public init(
        note: UInt8,
        velocity: UInt8,
        sampleRate: Double,
        technique: MusicalTechnique = .normal,
        preset: SynthPreset = .polyLead,
        velocityCurve: SynthVelocityCurve = .balanced
    ) {
        self.note = note
        self.sampleRate = sampleRate
        self.baseFrequency = 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
        self.targetAmplitude = velocityCurve.normalizedAmplitude(for: velocity)
        self.startTime = Date()

        attackTime = max(0.0005, preset.attack)
        decayTime = max(0.005, preset.decay)
        sustainLevel = max(0, min(1, preset.sustain))
        releaseTime = max(0.01, preset.release)

        switch technique {
        case .hammerOn, .pullOff, .legato:
            attackTime = min(attackTime, 0.002)
            sustainLevel = min(sustainLevel, 0.55)
        case .palmMute, .ghostNote:
            attackTime = min(attackTime, 0.001)
            decayTime = min(decayTime, 0.06)
            sustainLevel = min(sustainLevel, 0.18)
            releaseTime = min(releaseTime, 0.08)
        case .pinchHarmonic, .harmonic:
            attackTime = min(attackTime, 0.001)
            sustainLevel = min(sustainLevel, 0.45)
        default:
            break
        }

        if technique == .pinchHarmonic {
            controlState.setHarmonic(amount: 1.0, pinch: true)
        } else if technique == .harmonic {
            controlState.setHarmonic(amount: 0.6, pinch: false)
        }
        
        let control = self.controlState
        let gate = self.firstBufferGate
        let baseFrequency = self.baseFrequency
        let attack = self.attackTime
        let decay = self.decayTime
        let sustain = self.sustainLevel
        let target = self.targetAmplitude
        let release = self.releaseTime
        let oscillator1 = preset.osc1Type
        let oscillator2 = preset.osc2Type
        let baseFilterCutoff = max(80, min(sampleRate * 0.42, preset.filterCutoffHz))
        let filterResonance = max(0.0, min(0.95, preset.filterResonance))
        let filterType = preset.filterType
        let osc2Level = max(0.0, min(1.0, preset.osc2Level))
        let osc2DetuneCents = preset.osc2DetuneCents
        let saturationAmount = max(0.0, min(1.0, preset.saturationAmount))
        let oscillator2Detune = pow(2.0, osc2DetuneCents / 1_200.0)
        
        var oscillator1Phase = 0.0
        var oscillator2Phase = 0.0
        var envPhase = 0.0
        var releasePhase = 0.0
        var releaseStartAmp = 0.0
        var filterState1 = 0.0
        var filterState2 = 0.0
        var wasReleasing = false
        var renderFinished = false
        var cachedControlSnapshot = control.snapshot()
        var noiseState: UInt32 = 0x9E37_79B9
        
        self.sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            guard let rawPtr = buffer.mData else { return noErr }
            let ptr = rawPtr.assumingMemoryBound(to: Float.self)

            if renderFinished {
                for frame in 0..<Int(frameCount) {
                    ptr[frame] = 0
                }
                return noErr
            }

            if let latest = control.trySnapshot() {
                cachedControlSnapshot = latest
            }
            gate.signalIfNeeded()
            let controlSnapshot = cachedControlSnapshot
            if controlSnapshot.isStopped {
                for frame in 0..<Int(frameCount) {
                    ptr[frame] = 0
                }
                return noErr
            }

            let releasing = controlSnapshot.isReleasing
            if releasing && !wasReleasing {
                releasePhase = 0
            }
            wasReleasing = releasing

            let pitchMultiplier = pow(2.0, controlSnapshot.pitchOffset / 12.0)
            let frequency = baseFrequency * pitchMultiplier
            let oscillator1Increment = min(frequency / sampleRate, 0.49)
            let oscillator2Increment = min(frequency * oscillator2Detune / sampleRate, 0.49)
            let mute = controlSnapshot.damping
            let expressiveCutoff = baseFilterCutoff
                * (0.52 + controlSnapshot.timbre * 1.15)
                * (1.0 - mute * 0.78)
            let cutoff = max(70, min(sampleRate * 0.42, expressiveCutoff))
            
            // Calculate filter coefficients based on type
            // Using a simpler state-variable filter approach for better stability
            let resonance = max(0.0, min(0.95, filterResonance))
            let cutoffHz = cutoff
            let filterFrequencyRad = 2.0 * .pi * cutoffHz / sampleRate
            
            // State-variable filter coefficients
            let f = sin(filterFrequencyRad) * 0.5
            let q = 1.0 - f * (1.0 - resonance * 0.8)
            
            var reachedReleaseEnd = false

            for frame in 0..<Int(frameCount) {
                // Envelope
                let envValue: Double
                if releasing {
                    let releaseProgress = min(releasePhase / release, 1.0)
                    envValue = releaseStartAmp * (1.0 - releaseProgress)
                    if releaseProgress >= 1.0 {
                        reachedReleaseEnd = true
                    }
                } else if envPhase < attack {
                    envValue = (envPhase / attack) * target
                } else if envPhase < attack + decay {
                    let decayProgress = (envPhase - attack) / decay
                    envValue = target - (target - target * sustain) * decayProgress
                } else {
                    envValue = target * sustain
                }
                
                if !releasing {
                    releaseStartAmp = envValue
                }
                
                let pressureAmp = 0.72 + controlSnapshot.pressure * 0.55
                let h = controlSnapshot.harmonic

                // Generate oscillator samples
                let first = SynthVoice.oscillatorSample(
                    type: oscillator1,
                    phase: oscillator1Phase,
                    increment: oscillator1Increment
                )
                
                let second = SynthVoice.oscillatorSample(
                    type: oscillator2,
                    phase: oscillator2Phase,
                    increment: oscillator2Increment
                )
                
                // Handle noise oscillator
                let noiseSample: Double
                if oscillator2 == .noise {
                    noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
                    let unitNoise = Double(noiseState) / Double(UInt32.max)
                    noiseSample = unitNoise * 2.0 - 1.0
                } else {
                    noiseSample = 0.0
                }
                
                // Mix oscillators with configurable levels
                var sample = first * (1.0 - osc2Level)
                
                if oscillator2 == .noise {
                    sample += noiseSample * osc2Level
                } else {
                    sample += second * osc2Level
                }
                
                // Add harmonic enhancement
                sample += h * 0.18 * sin(oscillator1Phase * 2.0 * .pi * 3.0)
                if controlSnapshot.pinch {
                    sample = sample * 0.58
                        + 0.28 * sin(oscillator1Phase * 2.0 * .pi * 8.0)
                        + 0.14 * sin(oscillator1Phase * 2.0 * .pi * 12.0)
                }

                // Apply saturation (soft clipping) for warmth
                let saturatedSample: Double
                if saturationAmount > 0 {
                    let x = sample * 2.0
                    let softClip = x - (x * x * x) / 3.0
                    saturatedSample = (sample * (1.0 - saturationAmount)) + (softClip * saturationAmount * 0.3)
                } else {
                    saturatedSample = sample
                }

                // Apply state-variable filter
                let lowPass = filterState1 + f * (saturatedSample - filterState1)
                let highPass = saturatedSample - lowPass
                let bandPass = filterState2 + f * (highPass - filterState2)
                filterState2 = bandPass
                filterState1 = lowPass
                
                let filtered: Double
                switch filterType {
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
                renderFinished = true
            }

            return noErr
        }
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
            return (phase * 2.0 - 1.0) - polyBLEP(phase: phase, increment: increment)
        case .square:
            let raw = phase < 0.5 ? 1.0 : -1.0
            let shiftedPhase = phase < 0.5 ? phase + 0.5 : phase - 0.5
            return raw
                + polyBLEP(phase: phase, increment: increment)
                - polyBLEP(phase: shiftedPhase, increment: increment)
        case .triangle:
            return 1.0 - 4.0 * abs(phase - 0.5)
        case .noise:
            return 0.0
        }
    }

    @inline(__always)
    private static func polyBLEP(phase: Double, increment: Double) -> Double {
        guard increment > 0 else { return 0 }
        if phase < increment {
            let t = phase / increment
            return t + t - t * t - 1.0
        }
        if phase > 1.0 - increment {
            let t = (phase - 1.0) / increment
            return t * t + t + t + 1.0
        }
        return 0
    }
    
    public func start() {
        // Voice starts automatically via render callback
    }
    
    public func startRelease() {
        controlState.startRelease()
    }
    
    public func stop() {
        controlState.stop()
    }
    
    public var isReleasing: Bool {
        controlState.snapshot().isReleasing
    }
    
    public var isStopped: Bool {
        controlState.snapshot().isStopped
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

    public func setHarmonic(amount: Double, pinch: Bool) {
        controlState.setHarmonic(amount: amount, pinch: pinch)
    }

    public var currentPitchOffset: Double {
        controlState.snapshot().pitchOffset
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
