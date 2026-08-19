import Foundation
import AVFoundation

/// Stem and live performance audio recorder writing uncompressed 24-bit / 32-bit float WAV audio from the virtual loopback stream.
public final class LoopbackAudioRecorder: @unchecked Sendable {
    public private(set) var isRecording: Bool = false
    public private(set) var recordedFrames: UInt64 = 0
    public private(set) var currentOutputFileURL: URL?

    /// Human-readable description of the write failure that aborted the
    /// current capture, if any. `nil` while the capture is healthy.
    public var lastWriteErrorDescription: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastWriteErrorDescription
    }

    private var _lastWriteErrorDescription: String?
    private var audioFile: AVAudioFile?
    private let lock = NSLock()
    
    public init() {}
    
    /// Begins recording the virtual loopback stream to a specified destination URL.
    /// If no URL is provided, generates a timestamped WAV file in the temporary directory.
    public func startRecording(
        outputURL: URL? = nil,
        sampleRate: Double = 44100.0,
        channels: UInt32 = 2
    ) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isRecording else {
            return currentOutputFileURL ?? URL(fileURLWithPath: "/dev/null")
        }
        
        let destinationURL: URL
        if let url = outputURL {
            destinationURL = url
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())
            let tempDir = FileManager.default.temporaryDirectory
            destinationURL = tempDir.appendingPathComponent("XPI_Capture_\(timestamp).wav")
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let file = try AVAudioFile(
            forWriting: destinationURL,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        
        self.audioFile = file
        self.currentOutputFileURL = destinationURL
        self.recordedFrames = 0
        self._lastWriteErrorDescription = nil
        self.isRecording = true
        
        return destinationURL
    }
    
    /// Writes a stereo audio buffer into the open recording file.
    public func recordBuffer(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        
        guard isRecording, let file = audioFile else { return }
        
        do {
            try file.write(from: buffer)
            recordedFrames &+= UInt64(buffer.frameLength)
        } catch {
            _lastWriteErrorDescription = error.localizedDescription
            audioFile = nil
            isRecording = false
            print("⚠️ Failed to write audio buffer to loopback file; capture aborted: \(error)")
        }
    }
    
    /// Stops recording and finalizes the audio file header.
    @discardableResult
    public func stopRecording() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        
        guard isRecording else { return nil }
        
        let url = currentOutputFileURL
        audioFile = nil
        isRecording = false
        return url
    }
}

/// Coordinates real-time virtual audio loopback capture from AudioEngine, feeding the driver and stem recorder.
@Observable
public final class VirtualAudioLoopbackEngine: @unchecked Sendable {
    public static let shared = VirtualAudioLoopbackEngine()
    
    public let driver: VirtualAudioDriver
    public let recorder: LoopbackAudioRecorder
    
    public private(set) var isTapInstalled: Bool = false
    private let lock = NSLock()
    
    public init(driver: VirtualAudioDriver = .shared) {
        self.driver = driver
        self.recorder = LoopbackAudioRecorder()
    }
    
    /// Installs a real-time tap on an AVAudioNode to stream audio into the virtual driver and recorder.
    public func installTap(on node: AVAudioNode, bus: AVAudioNodeBus = 0, bufferSize: AVAudioFrameCount = 512) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isTapInstalled else { return }
        
        let format = node.outputFormat(forBus: bus)
        guard format.channelCount > 0 && format.sampleRate > 0 else { return }
        
        node.installTap(onBus: bus, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }
            
            if let floatData = buffer.floatChannelData {
                let left = floatData[0]
                let right = buffer.format.channelCount > 1 ? floatData[1] : nil
                
                self.driver.ingestAudio(left: left, right: right, frameCount: frameCount)
            }
            
            if self.recorder.isRecording {
                self.recorder.recordBuffer(buffer)
            }
        }
        
        isTapInstalled = true
    }
    
    /// Removes tap from the specified AVAudioNode.
    public func removeTap(from node: AVAudioNode, bus: AVAudioNodeBus = 0) {
        lock.lock()
        defer { lock.unlock() }
        
        guard isTapInstalled else { return }
        node.removeTap(onBus: bus)
        isTapInstalled = false
    }
    
    /// Starts recording stem/session capture.
    public func startCapture(outputURL: URL? = nil) throws -> URL {
        try recorder.startRecording(
            outputURL: outputURL,
            sampleRate: driver.sampleRate.rawValue,
            channels: 2
        )
    }
    
    /// Stops recording stem capture.
    @discardableResult
    public func stopCapture() -> URL? {
        recorder.stopRecording()
    }
}
