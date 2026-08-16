import Foundation
import AudioToolbox
import AVFoundation
import XPadCore
import XPadTheory

/// Realtime voice structure for AUv3 instrument rendering (zero heap allocation in render block).
private struct AUPolyVoice {
    var isActive: Bool = false
    var isReleasing: Bool = false
    var note: UInt8 = 60
    var velocity: Float = 0.0
    var targetAmplitude: Float = 0.0
    
    var osc1Phase: Double = 0.0
    var osc2Phase: Double = 0.0
    var envPhase: Double = 0.0
    var releasePhase: Double = 0.0
    var releaseStartAmp: Float = 0.0
    
    var filterState1: Double = 0.0
    var filterState2: Double = 0.0
    
    var pitchBendSemitones: Double = 0.0
    var pressure: Double = 0.0
    var timbreCC74: Double = 0.5
    var channel: UInt8 = 0
}

/// Audio Unit v3 Polyphonic Synthesizer Instrument (Music Device).
public final class XPadAUInstrument: XPadAudioUnitBase, @unchecked Sendable {
    public static let componentType: OSType = kAudioUnitType_MusicDevice // 'aumu'
    public static let componentSubType: OSType = 0x78706969 // 'xpii' (XPI Instrument)
    public static let componentManufacturer: OSType = 0x58504144 // 'XPAD'
    
    private var outputBus: AUAudioUnitBus
    private var _outputBusses: AUAudioUnitBusArray!
    private var _inputBusses: AUAudioUnitBusArray!
    
    private let maxVoices = 16
    private var voices: [AUPolyVoice]
    private var noiseState: UInt32 = 0x9E37_79B9
    
    public override init(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions = []
    ) throws {
        self.voices = Array(repeating: AUPolyVoice(), count: maxVoices)
        
        let defaultFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        self.outputBus = try AUAudioUnitBus(format: defaultFormat)
        self.outputBus.maximumChannelCount = 2
        
        try super.init(componentDescription: componentDescription, options: options)
        
        self._outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [self.outputBus])
        self._inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }
    
    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusses
    }
    
    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        // Reset voices on render start
        for i in 0..<maxVoices {
            voices[i] = AUPolyVoice()
        }
    }
    
    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        for i in 0..<maxVoices {
            voices[i].isActive = false
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
    
    public override var internalRenderBlock: AUInternalRenderBlock {
        let maxV = self.maxVoices
        let outBus = self.outputBus
        
        return { [weak self] actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in
            guard let self = self, outputBusNumber == 0, frameCount > 0 else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
            guard ablPointer.count >= 1, let leftBuffer = ablPointer[0].mData else { return noErr }
            let leftPtr = leftBuffer.assumingMemoryBound(to: Float.self)
            let rightPtr: UnsafeMutablePointer<Float>? = ablPointer.count > 1 && ablPointer[1].mData != nil
                ? ablPointer[1].mData!.assumingMemoryBound(to: Float.self)
                : nil
            
            // Clear output buffers
            for f in 0..<Int(frameCount) {
                leftPtr[f] = 0.0
                rightPtr?[f] = 0.0
            }
            
            let sampleRate = outBus.format.sampleRate > 0 ? outBus.format.sampleRate : 44100.0
            let params = self.parameterSnapshot
            
            // 1. Process MIDI Realtime Events
            var eventPtr = realtimeEventListHead
            while let event = eventPtr {
                if event.pointee.head.eventType == .MIDI {
                    let midiEvent = event.pointee.MIDI
                    let status = midiEvent.data.0 & 0xF0
                    let channel = midiEvent.data.0 & 0x0F
                    let byte1 = midiEvent.data.1
                    let byte2 = midiEvent.data.2
                    
                    switch status {
                    case 0x90: // Note On
                        let note = byte1
                        let velocity = byte2
                        if velocity > 0 {
                            // Find free voice or steal oldest
                            var targetIdx = -1
                            for i in 0..<maxV {
                                if !self.voices[i].isActive {
                                    targetIdx = i
                                    break
                                }
                            }
                            if targetIdx == -1 { targetIdx = 0 } // Steal
                            
                            var v = AUPolyVoice()
                            v.isActive = true
                            v.isReleasing = false
                            v.note = note
                            v.velocity = Float(velocity) / 127.0
                            v.targetAmplitude = 0.07 + 0.93 * pow(Float(velocity) / 127.0, 0.72)
                            v.channel = channel
                            v.timbreCC74 = 0.5
                            v.pitchBendSemitones = 0.0
                            v.pressure = 0.0
                            v.osc1Phase = 0.0
                            v.osc2Phase = 0.0
                            v.envPhase = 0.0
                            self.voices[targetIdx] = v
                        } else {
                            // Note off via velocity 0
                            for i in 0..<maxV {
                                if self.voices[i].isActive && self.voices[i].note == note && (!self.voices[i].isReleasing || self.voices[i].channel == channel) {
                                    self.voices[i].isReleasing = true
                                    self.voices[i].releasePhase = 0.0
                                }
                            }
                        }
                    case 0x80: // Note Off
                        let note = byte1
                        for i in 0..<maxV {
                            if self.voices[i].isActive && self.voices[i].note == note && !self.voices[i].isReleasing {
                                self.voices[i].isReleasing = true
                                self.voices[i].releasePhase = 0.0
                            }
                        }
                    case 0xE0: // Pitch Bend
                        let lsb = Double(byte1)
                        let msb = Double(byte2)
                        let rawBend = (msb * 128.0 + lsb) - 8192.0
                        let bendSemitones = (rawBend / 8192.0) * Double(params.mpeBendRange)
                        for i in 0..<maxV {
                            if self.voices[i].isActive && (self.voices[i].channel == channel || channel == 0) {
                                self.voices[i].pitchBendSemitones = bendSemitones
                            }
                        }
                    case 0xD0: // Channel Pressure
                        let pressure = Double(byte1) / 127.0
                        for i in 0..<maxV {
                            if self.voices[i].isActive && (self.voices[i].channel == channel || channel == 0) {
                                self.voices[i].pressure = pressure
                            }
                        }
                    case 0xB0: // Control Change
                        let cc = byte1
                        let val = byte2
                        if cc == 74 { // Timbre
                            let timbre = Double(val) / 127.0
                            for i in 0..<maxV {
                                if self.voices[i].isActive && (self.voices[i].channel == channel || channel == 0) {
                                    self.voices[i].timbreCC74 = timbre
                                }
                            }
                        } else if cc == 123 || cc == 120 { // All Notes Off / Sound Off
                            for i in 0..<maxV {
                                self.voices[i].isActive = false
                            }
                        }
                    default:
                        break
                    }
                }
                eventPtr = event.pointee.head.next.map { UnsafePointer($0) }
            }
            
            // 2. Synthesize Active Voices
            let attack = max(0.0005, Double(params.attack))
            let decay = max(0.005, Double(params.decay))
            let sustain = max(0.0, min(1.0, Double(params.sustain)))
            let release = max(0.01, Double(params.release))
            let cutoffHz = max(20.0, min(sampleRate * 0.45, Double(params.filterCutoff)))
            let resonance = max(0.0, min(0.95, Double(params.filterResonance)))
            let osc2DetuneRatio = pow(2.0, Double(params.osc2Detune) / 1200.0)
            let osc2Lvl = max(0.0, min(1.0, Double(params.osc2Level)))
            let satAmount = max(0.0, min(1.0, Double(params.saturation)))
            
            let filterFreqRad = 2.0 * .pi * cutoffHz / sampleRate
            let fCoeff = sin(filterFreqRad) * 0.5
            let qCoeff = 1.0 - fCoeff * (1.0 - resonance * 0.8)
            
            for vIdx in 0..<maxV {
                guard self.voices[vIdx].isActive else { continue }
                
                let baseFreq = 440.0 * pow(2.0, (Double(self.voices[vIdx].note) - 69.0) / 12.0)
                let pitchMultiplier = pow(2.0, self.voices[vIdx].pitchBendSemitones / 12.0)
                let freq = baseFreq * pitchMultiplier
                let inc1 = min(freq / sampleRate, 0.49)
                let inc2 = min(freq * osc2DetuneRatio / sampleRate, 0.49)
                let targetAmp = Double(self.voices[vIdx].targetAmplitude)
                
                for f in 0..<Int(frameCount) {
                    // ADSR Envelope
                    let envValue: Double
                    if self.voices[vIdx].isReleasing {
                        let relProg = min(self.voices[vIdx].releasePhase / release, 1.0)
                        envValue = Double(self.voices[vIdx].releaseStartAmp) * (1.0 - relProg)
                        if relProg >= 1.0 {
                            self.voices[vIdx].isActive = false
                            break
                        }
                    } else if self.voices[vIdx].envPhase < attack {
                        envValue = (self.voices[vIdx].envPhase / attack) * targetAmp
                    } else if self.voices[vIdx].envPhase < attack + decay {
                        let decProg = (self.voices[vIdx].envPhase - attack) / decay
                        envValue = targetAmp - (targetAmp - targetAmp * sustain) * decProg
                    } else {
                        envValue = targetAmp * sustain
                    }
                    
                    if !self.voices[vIdx].isReleasing {
                        self.voices[vIdx].releaseStartAmp = Float(envValue)
                    }
                    
                    // Oscillator 1 (Saw default)
                    let p1 = self.voices[vIdx].osc1Phase
                    let s1 = (p1 * 2.0 - 1.0) - XPadAUInstrument.polyBLEP(phase: p1, increment: inc1)
                    
                    // Oscillator 2 (Square default)
                    let p2 = self.voices[vIdx].osc2Phase
                    let raw2 = p2 < 0.5 ? 1.0 : -1.0
                    let shiftedP2 = p2 < 0.5 ? p2 + 0.5 : p2 - 0.5
                    let s2 = raw2 + XPadAUInstrument.polyBLEP(phase: p2, increment: inc2) - XPadAUInstrument.polyBLEP(phase: shiftedP2, increment: inc2)
                    
                    var mixSample = s1 * (1.0 - osc2Lvl) + s2 * osc2Lvl
                    
                    // Saturation
                    if satAmount > 0 {
                        let x = mixSample * 2.0
                        let softClip = x - (x * x * x) / 3.0
                        mixSample = (mixSample * (1.0 - satAmount)) + (softClip * satAmount * 0.3)
                    }
                    
                    // State-variable filter
                    let lowPass = self.voices[vIdx].filterState1 + fCoeff * (mixSample - self.voices[vIdx].filterState1)
                    let highPass = mixSample - lowPass
                    let bandPass = self.voices[vIdx].filterState2 + fCoeff * (highPass - self.voices[vIdx].filterState2)
                    self.voices[vIdx].filterState2 = bandPass
                    self.voices[vIdx].filterState1 = lowPass
                    
                    let filteredSample = lowPass + qCoeff * bandPass
                    let pressureFactor = 0.8 + self.voices[vIdx].pressure * 0.4
                    let outSample = Float(tanh(filteredSample * envValue * pressureFactor * 0.45))
                    
                    leftPtr[f] += outSample
                    rightPtr?[f] += outSample
                    
                    // Advance phases
                    self.voices[vIdx].osc1Phase += inc1
                    if self.voices[vIdx].osc1Phase >= 1.0 { self.voices[vIdx].osc1Phase -= floor(self.voices[vIdx].osc1Phase) }
                    self.voices[vIdx].osc2Phase += inc2
                    if self.voices[vIdx].osc2Phase >= 1.0 { self.voices[vIdx].osc2Phase -= floor(self.voices[vIdx].osc2Phase) }
                    self.voices[vIdx].envPhase += 1.0 / sampleRate
                    if self.voices[vIdx].isReleasing {
                        self.voices[vIdx].releasePhase += 1.0 / sampleRate
                    }
                }
            }
            
            // 3. Master Gain
            let masterGain = params.masterVolume
            for f in 0..<Int(frameCount) {
                leftPtr[f] *= masterGain
                rightPtr?[f] *= masterGain
            }
            
            return noErr
        }
    }
}
