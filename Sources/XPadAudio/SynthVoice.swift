import AVFoundation
import Foundation
import XPadCore

private final class VoiceControlState: @unchecked Sendable {
    struct Snapshot {
        let generation: UInt64
        let isReleasing: Bool
        let isStopped: Bool
        let pitchOffset: Double
        let pressure: Double
        let timbre: Double
        let damping: Double
        let harmonic: Double
        let pinch: Bool
        let baseFrequency: Double
        let targetAmplitude: Double
        let velocityNorm: Double
        let attack: Double
        let decay: Double
        let sustain: Double
        let release: Double
        let oscillator1: OscillatorType
        let oscillator2: OscillatorType
        let osc2Level: Double
        let oscillator2Detune: Double
        let baseFilterCutoff: Double
        let filterResonance: Double
        let filterType: FilterType
        let saturationAmount: Double
        let filterEnvelopeAmount: Double
        let velocityToFilter: Double
    }

    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var isReleasing = false
    private var isStopped = true
    private var pitchOffset = 0.0
    private var pressure = 0.0
    private var timbre = 0.5
    private var damping = 0.0
    private var harmonic = 0.0
    private var pinch = false
    private var baseFrequency = 440.0
    private var targetAmplitude = 0.0
    private var velocityNorm = 0.0
    private var attack = 0.01
    private var decay = 0.15
    private var sustain = 0.6
    private var release = 0.4
    private var oscillator1: OscillatorType = .saw
    private var oscillator2: OscillatorType = .square
    private var osc2Level = 0.36
    private var oscillator2Detune = 1.0
    private var baseFilterCutoff = 2_400.0
    private var filterResonance = 0.0
    private var filterType: FilterType = .lowPass
    private var saturationAmount = 0.0
    private var filterEnvelopeAmount = 0.0
    private var velocityToFilter = 0.0

    func snapshot() -> Snapshot {
        lock.lock()
        let value = makeSnapshotLocked()
        lock.unlock()
        return value
    }

    /// Audio render threads never wait for control writers. If a write is in
    /// progress, the voice reuses its last complete snapshot for one buffer.
    func trySnapshot() -> Snapshot? {
        guard lock.try() else { return nil }
        let value = makeSnapshotLocked()
        lock.unlock()
        return value
    }

    func trigger(
        baseFrequency: Double,
        targetAmplitude: Double,
        velocityNorm: Double,
        attack: Double,
        decay: Double,
        sustain: Double,
        release: Double,
        oscillator1: OscillatorType,
        oscillator2: OscillatorType,
        osc2Level: Double,
        oscillator2Detune: Double,
        baseFilterCutoff: Double,
        filterResonance: Double,
        filterType: FilterType,
        saturationAmount: Double,
        filterEnvelopeAmount: Double,
        velocityToFilter: Double
    ) {
        lock.lock()
        generation &+= 1
        isReleasing = false
        isStopped = false
        pitchOffset = 0
        pressure = 0
        timbre = 0.5
        damping = 0
        harmonic = 0
        pinch = false
        self.baseFrequency = baseFrequency
        self.targetAmplitude = targetAmplitude
        self.velocityNorm = velocityNorm
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.oscillator1 = oscillator1
        self.oscillator2 = oscillator2
        self.osc2Level = osc2Level
        self.oscillator2Detune = oscillator2Detune
        self.baseFilterCutoff = baseFilterCutoff
        self.filterResonance = filterResonance
        self.filterType = filterType
        self.saturationAmount = saturationAmount
        self.filterEnvelopeAmount = filterEnvelopeAmount
        self.velocityToFilter = velocityToFilter
        lock.unlock()
    }

    func startRelease() {
        lock.lock()
        isReleasing = true
        lock.unlock()
    }

    func stop() {
        lock.lock()
        isStopped = true
        isReleasing = false
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

    private func makeSnapshotLocked() -> Snapshot {
        Snapshot(
            generation: generation,
            isReleasing: isReleasing,
            isStopped: isStopped,
            pitchOffset: pitchOffset,
            pressure: pressure,
            timbre: timbre,
            damping: damping,
            harmonic: harmonic,
            pinch: pinch,
            baseFrequency: baseFrequency,
            targetAmplitude: targetAmplitude,
            velocityNorm: velocityNorm,
            attack: attack,
            decay: decay,
            sustain: sustain,
            release: release,
            oscillator1: oscillator1,
            oscillator2: oscillator2,
            osc2Level: osc2Level,
            oscillator2Detune: oscillator2Detune,
            baseFilterCutoff: baseFilterCutoff,
            filterResonance: filterResonance,
            filterType: filterType,
            saturationAmount: saturationAmount,
            filterEnvelopeAmount: filterEnvelopeAmount,
            velocityToFilter: velocityToFilter
        )
    }
}

/// Individual synth voice generating a single note from a persistent source node.
public final class SynthVoice: @unchecked Sendable {
    public private(set) var note: UInt8?
    public let sourceNode: AVAudioSourceNode
    public private(set) var startTime: Date
    public var releaseTime: Double = 0.4

    var assignedNote: UInt8? { note }
    var isIdle: Bool { note == nil }

    private let controlState = VoiceControlState()
    private let sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.note = nil
        self.startTime = Date()
        let control = controlState
        var lastControl = control.snapshot()
        var appliedGeneration: UInt64 = 0
        var oscillator1Phase = 0.0
        var oscillator2Phase = 0.0
        var envPhase = 0.0
        var releasePhase = 0.0
        var releaseStartAmp = 0.0
        var filterState1 = 0.0
        var filterState2 = 0.0
        var wasReleasing = false
        var renderFinished = false
        var noiseState: UInt32 = 0x9E37_79B9

        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            guard let rawPtr = buffer.mData else { return noErr }
            let ptr = rawPtr.assumingMemoryBound(to: Float.self)

            if let latest = control.trySnapshot() {
                lastControl = latest
            }
            let snapshot = lastControl

            if snapshot.isStopped || (renderFinished && snapshot.generation == appliedGeneration) {
                for frame in 0..<Int(frameCount) {
                    ptr[frame] = 0
                }
                return noErr
            }

            if snapshot.generation != appliedGeneration {
                appliedGeneration = snapshot.generation
                oscillator1Phase = 0
                oscillator2Phase = 0
                envPhase = 0
                releasePhase = 0
                releaseStartAmp = 0
                filterState1 = 0
                filterState2 = 0
                wasReleasing = false
                renderFinished = false
                noiseState = 0x9E37_79B9
            }

            let osc2Gain = sqrt(max(0, min(1, snapshot.osc2Level)))
            let osc1Gain = sqrt(max(0, 1 - max(0, min(1, snapshot.osc2Level))))
            let pitchMultiplier = pow(2.0, snapshot.pitchOffset / 12.0)
            let frequency = snapshot.baseFrequency * pitchMultiplier
            let oscillator1Increment = min(frequency / sampleRate, 0.49)
            let oscillator2Increment = min(frequency * snapshot.oscillator2Detune / sampleRate, 0.49)
            let mute = snapshot.damping
            let envelopeCutoff = pow(2.0, snapshot.filterEnvelopeAmount * 3.5)
            let velocityCutoff = pow(2.0, snapshot.velocityToFilter * snapshot.velocityNorm * 2.0)

            let releasing = snapshot.isReleasing
            if releasing && !wasReleasing {
                releasePhase = 0
            }
            wasReleasing = releasing

            var reachedReleaseEnd = false

            for frame in 0..<Int(frameCount) {
                let ampEnv: Double
                if releasing {
                    let releaseProgress = min(releasePhase / snapshot.release, 1.0)
                    ampEnv = releaseStartAmp * (1.0 - releaseProgress)
                    if releaseProgress >= 1.0 {
                        reachedReleaseEnd = true
                    }
                } else if envPhase < snapshot.attack {
                    ampEnv = envPhase / snapshot.attack
                } else if envPhase < snapshot.attack + snapshot.decay {
                    let decayProgress = (envPhase - snapshot.attack) / snapshot.decay
                    ampEnv = 1.0 - (1.0 - snapshot.sustain) * decayProgress
                } else {
                    ampEnv = snapshot.sustain
                }

                if !releasing {
                    releaseStartAmp = ampEnv
                }

                let envValue = ampEnv * snapshot.targetAmplitude
                let pressureAmp = 0.72 + snapshot.pressure * 0.55
                let h = snapshot.harmonic

                let first = SynthVoice.oscillatorSample(
                    type: snapshot.oscillator1,
                    phase: oscillator1Phase,
                    increment: oscillator1Increment
                )
                let second = SynthVoice.oscillatorSample(
                    type: snapshot.oscillator2,
                    phase: oscillator2Phase,
                    increment: oscillator2Increment
                )

                let noiseSample: Double
                if snapshot.oscillator2 == .noise {
                    noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
                    let unitNoise = Double(noiseState) / Double(UInt32.max)
                    noiseSample = unitNoise * 2.0 - 1.0
                } else {
                    noiseSample = 0.0
                }

                var sample = first * osc1Gain
                if snapshot.oscillator2 == .noise {
                    sample += noiseSample * osc2Gain
                } else {
                    sample += second * osc2Gain
                }

                sample += h * 0.18 * sin(oscillator1Phase * 2.0 * .pi * 3.0)
                if snapshot.pinch {
                    sample = sample * 0.58
                        + 0.28 * sin(oscillator1Phase * 2.0 * .pi * 8.0)
                        + 0.14 * sin(oscillator1Phase * 2.0 * .pi * 12.0)
                }

                let openEnv = max(ampEnv, 0)
                let expressiveCutoff = snapshot.baseFilterCutoff
                    * (0.52 + snapshot.timbre * 1.15)
                    * (1.0 - mute * 0.78)
                    * (1.0 + (envelopeCutoff - 1.0) * openEnv)
                    * velocityCutoff
                let cutoffHz = max(70, min(sampleRate * 0.42, expressiveCutoff))
                let filterFrequencyRad = 2.0 * .pi * cutoffHz / sampleRate
                let f = sin(filterFrequencyRad) * 0.5
                let resonance = max(0.0, min(0.95, snapshot.filterResonance))
                let q = 1.0 - f * (1.0 - resonance * 0.8)

                let lowPass = filterState1 + f * (sample - filterState1)
                let highPass = sample - lowPass
                let bandPass = filterState2 + f * (highPass - filterState2)
                filterState2 = bandPass
                filterState1 = lowPass

                let filtered: Double
                switch snapshot.filterType {
                case .lowPass:
                    filtered = lowPass + q * bandPass
                case .highPass:
                    filtered = highPass + q * bandPass
                case .bandPass:
                    filtered = bandPass
                }

                let saturatedSample: Double
                if snapshot.saturationAmount > 0 {
                    let x = filtered * 2.0
                    let softClip = x - (x * x * x) / 3.0
                    saturatedSample = (filtered * (1.0 - snapshot.saturationAmount))
                        + (softClip * snapshot.saturationAmount * 0.3)
                } else {
                    saturatedSample = filtered
                }

                let dampedEnv = envValue * (1.0 - mute * 0.55)
                let finalSample = saturatedSample * pressureAmp * (1.0 - mute * 0.45)
                ptr[frame] = Float(tanh(finalSample * dampedEnv * 0.4))

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

    func trigger(
        note: UInt8,
        velocity: UInt8,
        technique: MusicalTechnique,
        preset: SynthPreset,
        velocityCurve: SynthVelocityCurve
    ) {
        self.note = note
        startTime = Date()

        var attack = max(0.0005, preset.attack)
        var decay = max(0.005, preset.decay)
        var sustain = max(0, min(1, preset.sustain))
        var release = max(0.01, preset.release)

        switch technique {
        case .hammerOn, .pullOff, .legato:
            attack = min(attack, 0.002)
            sustain = min(sustain, 0.55)
        case .palmMute, .ghostNote:
            attack = min(attack, 0.001)
            decay = min(decay, 0.06)
            sustain = min(sustain, 0.18)
            release = min(release, 0.08)
        case .pinchHarmonic, .harmonic:
            attack = min(attack, 0.001)
            sustain = min(sustain, 0.45)
        default:
            break
        }

        releaseTime = release
        controlState.trigger(
            baseFrequency: 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0),
            targetAmplitude: velocityCurve.normalizedAmplitude(for: velocity),
            velocityNorm: Double(velocity) / 127.0,
            attack: attack,
            decay: decay,
            sustain: sustain,
            release: release,
            oscillator1: preset.osc1Type,
            oscillator2: preset.osc2Type,
            osc2Level: max(0, min(1, preset.osc2Level)),
            oscillator2Detune: pow(2.0, preset.osc2DetuneCents / 1_200.0),
            baseFilterCutoff: max(80, min(sampleRate * 0.42, preset.filterCutoffHz)),
            filterResonance: max(0.0, min(0.95, preset.filterResonance)),
            filterType: preset.filterType,
            saturationAmount: max(0.0, min(1.0, preset.saturationAmount)),
            filterEnvelopeAmount: max(0, min(1, preset.filterEnvelopeAmount)),
            velocityToFilter: max(0, min(1, preset.velocityToFilter))
        )

        if technique == .pinchHarmonic {
            controlState.setHarmonic(amount: 1.0, pinch: true)
        } else if technique == .harmonic {
            controlState.setHarmonic(amount: 0.6, pinch: false)
        }
    }

    public func start() {
        // Voice starts automatically via render callback.
    }

    public func startRelease() {
        controlState.startRelease()
    }

    public func stop() {
        controlState.stop()
    }

    func hardStop() {
        controlState.stop()
        note = nil
    }

    func markIdleIfReleased() {
        controlState.stop()
        note = nil
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
}
