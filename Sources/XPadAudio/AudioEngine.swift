import Foundation
import AVFAudio
import XPadCore

public enum OscillatorType: String, CaseIterable, Codable, Sendable {
    case sine = "Sine"
    case triangle = "Triangle"
    case saw = "Sawtooth"
    case square = "Square"
}

public struct SynthPreset: Identifiable, Codable, Sendable {
    public let id: String
    public var name: String
    public var osc1Type: OscillatorType
    public var osc2Type: OscillatorType
    public var osc2DetuneCents: Double
    public var filterCutoffHz: Double
    public var filterResonance: Double
    public var attackSeconds: Double
    public var decaySeconds: Double
    public var sustainLevel: Double
    public var releaseSeconds: Double

    public static let polyLead = SynthPreset(
        id: "poly_lead",
        name: "Poly Lead & Synth",
        osc1Type: .saw,
        osc2Type: .square,
        osc2DetuneCents: 8.0,
        filterCutoffHz: 2800.0,
        filterResonance: 0.3,
        attackSeconds: 0.01,
        decaySeconds: 0.2,
        sustainLevel: 0.7,
        releaseSeconds: 0.35
    )

    public static let rhodesEP = SynthPreset(
        id: "rhodes_ep",
        name: "Electric Piano (Rhodes)",
        osc1Type: .sine,
        osc2Type: .triangle,
        osc2DetuneCents: 4.0,
        filterCutoffHz: 3200.0,
        filterResonance: 0.1,
        attackSeconds: 0.005,
        decaySeconds: 0.6,
        sustainLevel: 0.4,
        releaseSeconds: 0.4
    )

    public static let warmPad = SynthPreset(
        id: "warm_pad",
        name: "Lush Ambient Pad",
        osc1Type: .saw,
        osc2Type: .saw,
        osc2DetuneCents: 12.0,
        filterCutoffHz: 1200.0,
        filterResonance: 0.25,
        attackSeconds: 0.35,
        decaySeconds: 0.5,
        sustainLevel: 0.85,
        releaseSeconds: 0.9
    )

    public static let pluck = SynthPreset(
        id: "pluck",
        name: "Acoustic Pluck",
        osc1Type: .triangle,
        osc2Type: .square,
        osc2DetuneCents: 3.0,
        filterCutoffHz: 4500.0,
        filterResonance: 0.4,
        attackSeconds: 0.002,
        decaySeconds: 0.18,
        sustainLevel: 0.1,
        releaseSeconds: 0.15
    )

    public static let subBass = SynthPreset(
        id: "sub_bass",
        name: "Sub Bass",
        osc1Type: .sine,
        osc2Type: .triangle,
        osc2DetuneCents: 0.0,
        filterCutoffHz: 600.0,
        filterResonance: 0.1,
        attackSeconds: 0.01,
        decaySeconds: 0.3,
        sustainLevel: 0.8,
        releaseSeconds: 0.2
    )

    public static let allPresets: [SynthPreset] = [polyLead, rhodesEP, warmPad, pluck, subBass]
}

public final class VoiceDSP: @unchecked Sendable {
    public var note: UInt8 = 0
    public var velocity: Float = 0.0
    public var isKeyOn: Bool = false
    public var phase1: Double = 0.0
    public var phase2: Double = 0.0
    public var envStage: Int = 0 // 0=idle, 1=attack, 2=decay, 3=sustain, 4=release
    public var envLevel: Float = 0.0
    public var filterState1: Float = 0.0
    public var filterState2: Float = 0.0
    public var currentPitchBendSemitones: Double = 0.0

    public init() {}

    public func noteOn(note: UInt8, velocity: UInt8) {
        self.note = note
        self.velocity = Float(velocity) / 127.0
        self.isKeyOn = true
        self.envStage = 1
        self.phase1 = 0.0
        self.phase2 = 0.0
    }

    public func noteOff() {
        self.isKeyOn = false
        self.envStage = 4
    }

    public var isActive: Bool {
        envStage != 0
    }
}

public final class AudioEngine: @unchecked Sendable {
    public static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44100.0
    private let voiceCount: Int = 16
    private var voices: [VoiceDSP] = []
    private var currentPreset: SynthPreset = .polyLead
    private let lock = NSLock()
    private var isEngineRunning: Bool = false

    public init() {
        for _ in 0..<voiceCount {
            voices.append(VoiceDSP())
        }
        setupAudioGraph()
    }

    private func setupAudioGraph() {
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        sourceNode = AVAudioSourceNode(format: outputFormat) { [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let leftBuffer = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightBuffer = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            self.renderAudio(left: leftBuffer, right: rightBuffer, frameCount: Int(frameCount))
            return noErr
        }

        if let sourceNode = sourceNode {
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: outputFormat)
        }

        startEngine()
    }

    public func startEngine() {
        guard !isEngineRunning else { return }
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }

    public func setPreset(_ preset: SynthPreset) {
        lock.lock()
        defer { lock.unlock() }
        self.currentPreset = preset
    }

    public func noteOn(note: UInt8, velocity: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        // Find inactive voice or steal oldest
        let voice = voices.first(where: { !$0.isActive }) ?? voices[0]
        voice.noteOn(note: note, velocity: velocity)
    }

    public func noteOff(note: UInt8) {
        lock.lock()
        defer { lock.unlock() }

        for voice in voices where voice.note == note && voice.isKeyOn {
            voice.noteOff()
        }
    }

    public func setPitchBend(for note: UInt8, semitones: Double) {
        lock.lock()
        defer { lock.unlock() }
        for voice in voices where voice.note == note {
            voice.currentPitchBendSemitones = semitones
        }
    }

    public func panic() {
        lock.lock()
        defer { lock.unlock() }
        for voice in voices {
            voice.envStage = 0
            voice.envLevel = 0.0
            voice.isKeyOn = false
        }
    }

    private func renderAudio(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int) {
        lock.lock()
        let preset = self.currentPreset
        lock.unlock()

        let dt = 1.0 / sampleRate
        let attackRate = Float(dt / max(0.001, preset.attackSeconds))
        let decayRate = Float(dt / max(0.001, preset.decaySeconds))
        let releaseRate = Float(dt / max(0.001, preset.releaseSeconds))
        let sustain = Float(preset.sustainLevel)

        for frame in 0..<frameCount {
            var mix: Float = 0.0

            for voice in voices where voice.isActive {
                // Envelope computation
                switch voice.envStage {
                case 1: // Attack
                    voice.envLevel += attackRate
                    if voice.envLevel >= 1.0 {
                        voice.envLevel = 1.0
                        voice.envStage = 2
                    }
                case 2: // Decay
                    voice.envLevel -= decayRate
                    if voice.envLevel <= sustain {
                        voice.envLevel = sustain
                        voice.envStage = 3
                    }
                case 3: // Sustain
                    voice.envLevel = sustain
                case 4: // Release
                    voice.envLevel -= releaseRate
                    if voice.envLevel <= 0.001 {
                        voice.envLevel = 0.0
                        voice.envStage = 0
                    }
                default:
                    voice.envLevel = 0.0
                }

                guard voice.envLevel > 0.0 else { continue }

                // Frequency calculation
                let freq = 440.0 * pow(2.0, (Double(voice.note) + voice.currentPitchBendSemitones - 69.0) / 12.0)
                let freq2 = freq * pow(2.0, preset.osc2DetuneCents / 1200.0)

                let osc1Sample = renderOsc(type: preset.osc1Type, phase: voice.phase1)
                let osc2Sample = renderOsc(type: preset.osc2Type, phase: voice.phase2)
                let oscMix = (osc1Sample * 0.6) + (osc2Sample * 0.4)
                let gain = voice.envLevel * voice.velocity
                let sample = Float(oscMix) * gain

                voice.phase1 += freq * dt
                if voice.phase1 >= 1.0 { voice.phase1 -= 1.0 }

                voice.phase2 += freq2 * dt
                if voice.phase2 >= 1.0 { voice.phase2 -= 1.0 }

                mix += sample
            }

            // Simple soft-clipping limiter
            let output = tanh(mix * 0.4)
            left[frame] = output
            right[frame] = output
        }
    }

    private func renderOsc(type: OscillatorType, phase: Double) -> Double {
        switch type {
        case .sine:
            return sin(phase * 2.0 * .pi)
        case .triangle:
            return 2.0 * abs(2.0 * (phase - floor(phase + 0.5))) - 1.0
        case .saw:
            return 2.0 * (phase - floor(phase + 0.5))
        case .square:
            return phase < 0.5 ? 1.0 : -1.0
        }
    }
}
