import Foundation
import AVFoundation

/// Simple polyphonic synthesizer using AVAudioEngine.
@Observable
final class AudioEngine: @unchecked Sendable {
    var isRunning: Bool = false
    var volume: Float = 0.7
    
    private var engine: AVAudioEngine?
    private var mixer: AVAudioMixerNode?
    private var voices: [UInt8: SynthVoice] = [:]
    private let lock = NSLock()
    private let sampleRate: Double = 44100
    private let maxVoices = 16
    
    init() {
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
    
    func start() {
        guard let engine = engine, !isRunning else { return }
        
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("⚠️ Audio engine failed to start: \(error)")
        }
    }
    
    func stop() {
        engine?.stop()
        isRunning = false
        
        lock.lock()
        voices.values.forEach { $0.stop() }
        voices.removeAll()
        lock.unlock()
    }
    
    func noteOn(note: UInt8, velocity: UInt8) {
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
    
    func noteOff(note: UInt8) {
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
    
    func allNotesOff() {
        guard let engine = engine else { return }
        
        lock.lock()
        for (_, voice) in voices {
            voice.stop()
            engine.detach(voice.sourceNode)
        }
        voices.removeAll()
        lock.unlock()
    }
    
    func setVolume(_ vol: Float) {
        volume = max(0, min(1, vol))
        mixer?.outputVolume = volume
    }
}

/// Individual synth voice generating a single note.
final class SynthVoice: @unchecked Sendable {
    let sourceNode: AVAudioSourceNode
    let startTime: Date
    let releaseTime: Double = 0.4
    
    private var phase: Double = 0
    private var frequency: Double
    private var amplitude: Double
    private var targetAmplitude: Double
    private var isReleasing = false
    private var isStopped = false
    private let sampleRate: Double
    
    // Envelope
    private var attackTime: Double = 0.01
    private var decayTime: Double = 0.15
    private var sustainLevel: Double = 0.6
    private var envelopePhase: Double = 0
    
    init(note: UInt8, velocity: UInt8, sampleRate: Double) {
        self.sampleRate = sampleRate
        self.frequency = 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
        self.amplitude = 0
        self.targetAmplitude = Double(velocity) / 127.0
        self.startTime = Date()
        
        // Create source node with render callback
        var currentPhase = 0.0
        var currentAmplitude = 0.0
        var envPhase = 0.0
        var releasing = false
        var stopped = false
        let freq = self.frequency
        let attack = self.attackTime
        let decay = self.decayTime
        let sustain = self.sustainLevel
        let target = self.targetAmplitude
        let release = self.releaseTime
        var releaseStartAmp = 0.0
        
        self.sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            if stopped { return noErr }
            
            // Check if self has updated releasing/stopped
            if let self = self {
                releasing = self.isReleasing
                stopped = self.isStopped
            }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
            
            for frame in 0..<Int(frameCount) {
                if stopped {
                    ptr[frame] = 0
                    continue
                }
                
                // Envelope
                let envValue: Double
                if releasing {
                    let releaseProgress = min(envPhase / release, 1.0)
                    envValue = releaseStartAmp * (1.0 - releaseProgress)
                    if releaseProgress >= 1.0 {
                        stopped = true
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
                
                currentAmplitude = envValue
                ptr[frame] = Float(sample * currentAmplitude)
                
                currentPhase += freq / sampleRate
                if currentPhase > 1.0 { currentPhase -= 1.0 }
                envPhase += 1.0 / sampleRate
            }
            
            if let self = self {
                self.isStopped = stopped
            }
            
            return noErr
        }
    }
    
    func start() {
        // Voice starts automatically via render callback
    }
    
    func startRelease() {
        isReleasing = true
    }
    
    func stop() {
        isStopped = true
    }
}
