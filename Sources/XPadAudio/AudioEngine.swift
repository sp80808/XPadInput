import Foundation
import AVFoundation

public enum OscillatorType: String, CaseIterable, Codable, Sendable {
    case sine = "Sine"
    case saw = "Sawtooth"
    case square = "Square"
    case triangle = "Triangle"
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

    public init(id: String, name: String, osc1Type: OscillatorType, osc2Type: OscillatorType, attack: Double = 0.01, decay: Double = 0.1, sustain: Double = 0.8, release: Double = 0.2) {
        self.id = id
        self.name = name
        self.osc1Type = osc1Type
        self.osc2Type = osc2Type
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
    }

    public static let polyLead = SynthPreset(id: "polyLead", name: "Poly Lead", osc1Type: .saw, osc2Type: .square, attack: 0.01, decay: 0.1, sustain: 0.7, release: 0.15)
    public static let rhodesEP = SynthPreset(id: "rhodesEP", name: "Rhodes EP", osc1Type: .sine, osc2Type: .triangle, attack: 0.005, decay: 0.4, sustain: 0.5, release: 0.3)
    public static let ambientPad = SynthPreset(id: "ambientPad", name: "Ambient Pad", osc1Type: .saw, osc2Type: .sine, attack: 0.3, decay: 0.5, sustain: 0.9, release: 0.8)
    public static let pluck = SynthPreset(id: "pluck", name: "Acoustic Pluck", osc1Type: .triangle, osc2Type: .saw, attack: 0.002, decay: 0.2, sustain: 0.2, release: 0.1)
    public static let subBass = SynthPreset(id: "subBass", name: "Sub Bass", osc1Type: .sine, osc2Type: .sine, attack: 0.01, decay: 0.1, sustain: 0.9, release: 0.1)

    public static let allPresets: [SynthPreset] = [.polyLead, .rhodesEP, .ambientPad, .pluck, .subBass]
}

/// Simple polyphonic synthesizer using AVAudioEngine.
@Observable
public final class AudioEngine: @unchecked Sendable {
    public static let shared = AudioEngine()
    
    public var isRunning: Bool = false
    public var volume: Float = 0.7
    public var currentPreset: SynthPreset = .polyLead

    public func setPreset(_ preset: SynthPreset) {
        self.currentPreset = preset
    }
    
    private var engine: AVAudioEngine?
    private var mixer: AVAudioMixerNode?
    private var voices: [UInt8: SynthVoice] = [:]
    private let lock = NSLock()
    private let sampleRate: Double = 44100
    private let maxVoices = 16
    
    public init() {
        setupEngine()
    }
    
    deinit {
        stop()
    }
    
    private func setupEngine() {
        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        
        mixer.outputVolume = volume
        
        self.engine = engine
        self.mixer = mixer
    }
    
    public func start() {
        guard let engine = engine, !isRunning else { return }
        
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("⚠️ Audio engine failed to start: \(error)")
        }
    }
    
    public func stop() {
        engine?.stop()
        isRunning = false
        
        lock.lock()
        voices.values.forEach { $0.stop() }
        voices.removeAll()
        lock.unlock()
    }
    
    public func noteOn(note: UInt8, velocity: UInt8) {
        guard let engine = engine, let mixer = mixer else { return }
        
        if !isRunning {
            start()
        }
        
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
            sampleRate: sampleRate
        )
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(voice.sourceNode)
        engine.connect(voice.sourceNode, to: mixer, format: format)
        
        voice.start()
        voices[note] = voice
        
        lock.unlock()
    }
    
    public func noteOff(note: UInt8) {
        guard let engine = engine else { return }
        
        lock.lock()
        if let voice = voices[note] {
            voice.startRelease()
            
            // Remove after release time
            let sourceNode = voice.sourceNode
            let releaseTime = voice.releaseTime
            voices.removeValue(forKey: note)
            lock.unlock()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + releaseTime) { [weak engine] in
                voice.stop()
                engine?.detach(sourceNode)
            }
        } else {
            lock.unlock()
        }
    }
    
    public func allNotesOff() {
        guard let engine = engine else { return }
        
        lock.lock()
        for (_, voice) in voices {
            voice.stop()
            engine.detach(voice.sourceNode)
        }
        voices.removeAll()
        lock.unlock()
    }
    
    public func setVolume(_ vol: Float) {
        volume = max(0, min(1, vol))
        mixer?.outputVolume = volume
    }
}

private final class VoiceControlState: @unchecked Sendable {
    var isReleasing = false
    var isStopped = false
}

/// Individual synth voice generating a single note.
public final class SynthVoice: @unchecked Sendable {
    public let note: UInt8
    public let sourceNode: AVAudioSourceNode
    public let startTime: Date
    public let releaseTime: Double = 0.4
    
    private var frequency: Double
    private var targetAmplitude: Double
    private let controlState = VoiceControlState()
    private let sampleRate: Double
    
    // Envelope
    private var attackTime: Double = 0.01
    private var decayTime: Double = 0.15
    private var sustainLevel: Double = 0.6
    
    public init(note: UInt8, velocity: UInt8, sampleRate: Double) {
        self.note = note
        self.sampleRate = sampleRate
        self.frequency = 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
        self.targetAmplitude = Double(velocity) / 127.0
        self.startTime = Date()
        
        let control = self.controlState
        let freq = self.frequency
        let attack = self.attackTime
        let decay = self.decayTime
        let sustain = self.sustainLevel
        let target = self.targetAmplitude
        let release = self.releaseTime
        
        var currentPhase = 0.0
        var envPhase = 0.0
        var releaseStartAmp = 0.0
        
        self.sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            if control.isStopped { return noErr }
            
            let releasing = control.isReleasing
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            guard let rawPtr = buffer.mData else { return noErr }
            let ptr = rawPtr.assumingMemoryBound(to: Float.self)
            
            for frame in 0..<Int(frameCount) {
                if control.isStopped {
                    ptr[frame] = 0
                    continue
                }
                
                // Envelope
                let envValue: Double
                if releasing {
                    let releaseProgress = min(envPhase / release, 1.0)
                    envValue = releaseStartAmp * (1.0 - releaseProgress)
                    if releaseProgress >= 1.0 {
                        control.isStopped = true
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
                
                // Generate a warm tone: fundamental + harmonics with rolloff
                var sample = sin(currentPhase * 2.0 * .pi)
                sample += 0.5 * sin(currentPhase * 2.0 * .pi * 2.0)   // 2nd harmonic
                sample += 0.25 * sin(currentPhase * 2.0 * .pi * 3.0)  // 3rd harmonic
                sample += 0.12 * sin(currentPhase * 2.0 * .pi * 4.0)  // 4th harmonic
                sample += 0.06 * sin(currentPhase * 2.0 * .pi * 5.0)  // 5th harmonic
                sample *= 0.3 // Normalize
                
                ptr[frame] = Float(sample * envValue)
                
                currentPhase += freq / sampleRate
                if currentPhase > 1.0 { currentPhase -= 1.0 }
                envPhase += 1.0 / sampleRate
            }
            
            return noErr
        }
        self.sourceNode = source
    }
    
    public func start() {
        // Voice starts automatically via render callback
    }
    
    public func startRelease() {
        controlState.isReleasing = true
    }
    
    public func stop() {
        controlState.isStopped = true
    }
    
    public var isReleasing: Bool {
        controlState.isReleasing
    }
    
    public var isStopped: Bool {
        controlState.isStopped
    }
}
