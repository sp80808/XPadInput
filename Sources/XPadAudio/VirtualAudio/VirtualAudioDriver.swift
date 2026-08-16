import Foundation
import AVFoundation

/// Supported sample rates for virtual audio driver loopback streaming.
public enum VirtualAudioSampleRate: Double, CaseIterable, Codable, Sendable, Identifiable {
    case rate44k1 = 44100.0
    case rate48k0 = 48000.0
    case rate96k0 = 96000.0
    
    public var id: Double { rawValue }
    
    public var displayLabel: String {
        switch self {
        case .rate44k1: return "44.1 kHz"
        case .rate48k0: return "48.0 kHz (Broadcast)"
        case .rate96k0: return "96.0 kHz (Hi-Res)"
        }
    }
}

/// Buffer size (latency) profiles for the virtual audio stream.
public enum VirtualAudioBufferSize: Int, CaseIterable, Codable, Sendable, Identifiable {
    case lowLatency64 = 64
    case responsive128 = 128
    case standard256 = 256
    case relaxed512 = 512
    case safe1024 = 1024
    
    public var id: Int { rawValue }
    
    public var displayLabel: String {
        switch self {
        case .lowLatency64: return "64 frames (1.4 ms @ 44.1k)"
        case .responsive128: return "128 frames (2.9 ms @ 44.1k)"
        case .standard256: return "256 frames (5.8 ms @ 44.1k)"
        case .relaxed512: return "512 frames (11.6 ms @ 44.1k)"
        case .safe1024: return "1024 frames (23.2 ms @ 44.1k)"
        }
    }
}

/// Tap source routing for the virtual audio loopback engine.
public enum VirtualAudioTapSource: String, CaseIterable, Codable, Sendable, Identifiable {
    case masterMix = "Master Output (Synth + FX + Drums)"
    case synthOnly = "Direct Poly Synth"
    case fxProcessed = "Effects Chain (EQ + Reverb)"
    
    public var id: String { rawValue }
}

/// Telemetry and driver state descriptor.
public struct VirtualAudioDriverState: Sendable, Equatable {
    public var isStreaming: Bool = false
    public var sampleRate: VirtualAudioSampleRate = .rate44k1
    public var bufferSize: VirtualAudioBufferSize = .standard256
    public var tapSource: VirtualAudioTapSource = .masterMix
    public var totalFramesStreamed: UInt64 = 0
    public var activeClients: Int = 0
    public var underrunCount: Int = 0
    public var overrunCount: Int = 0
    
    public init() {}
}

/// Virtual Audio Driver manager providing virtual loopback endpoints and CoreAudio inter-app streaming.
@Observable
public final class VirtualAudioDriver: @unchecked Sendable {
    public static let shared = VirtualAudioDriver()
    
    public private(set) var isEnabled: Bool = false
    public private(set) var sampleRate: VirtualAudioSampleRate = .rate44k1
    public private(set) var bufferSize: VirtualAudioBufferSize = .standard256
    public private(set) var tapSource: VirtualAudioTapSource = .masterMix
    public private(set) var driverState: VirtualAudioDriverState = VirtualAudioDriverState()
    
    public let ringBuffer: AudioRingBuffer
    public let levelMeter: AudioLevelMeter
    
    private let lock = NSLock()
    private var streamTimer: Timer?
    
    public init(ringBufferCapacity: Int = 65536) {
        self.ringBuffer = AudioRingBuffer(channels: 2, capacityFrames: ringBufferCapacity)
        self.levelMeter = AudioLevelMeter()
    }
    
    /// Enables or disables the virtual audio loopback stream.
    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        isEnabled = enabled
        driverState.isStreaming = enabled
        if !enabled {
            ringBuffer.reset()
            levelMeter.reset()
        }
        lock.unlock()
    }
    
    public func setSampleRate(_ rate: VirtualAudioSampleRate) {
        lock.lock()
        sampleRate = rate
        driverState.sampleRate = rate
        lock.unlock()
    }
    
    public func setBufferSize(_ size: VirtualAudioBufferSize) {
        lock.lock()
        bufferSize = size
        driverState.bufferSize = size
        lock.unlock()
    }
    
    public func setTapSource(_ source: VirtualAudioTapSource) {
        lock.lock()
        tapSource = source
        driverState.tapSource = source
        lock.unlock()
    }
    
    /// Ingests real-time stereo audio frames from AudioEngine into the virtual loopback driver.
    public func ingestAudio(left: UnsafePointer<Float>, right: UnsafePointer<Float>?, frameCount: Int) {
        guard isEnabled, frameCount > 0 else { return }
        
        // Push stereo channels synchronously
        ringBuffer.writeStereo(left: left, right: right, frameCount: frameCount)
        
        // Update level meters
        levelMeter.processFrames(left: left, right: right, frameCount: frameCount)
        
        lock.lock()
        driverState.totalFramesStreamed &+= UInt64(frameCount)
        driverState.overrunCount = ringBuffer.overrunCount
        driverState.underrunCount = ringBuffer.underrunCount
        lock.unlock()
    }
    
    /// Virtual loopback consumer pull: reads stereo interleaved audio for virtual audio HAL tap.
    public func pullInterleaved(into destination: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        guard isEnabled else {
            destination.initialize(repeating: 0.0, count: frameCount * 2)
            return frameCount
        }
        return ringBuffer.readInterleaved(into: destination, frameCount: frameCount)
    }
}
