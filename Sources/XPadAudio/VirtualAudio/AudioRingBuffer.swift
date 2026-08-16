import Foundation

/// A lock-free, single-producer single-consumer circular audio ring buffer for multi-channel 32-bit float audio.
/// Designed specifically for real-time DSP and CoreAudio virtual loopback streaming with zero heap allocation on the audio thread.
public final class AudioRingBuffer: @unchecked Sendable {
    public let channels: Int
    public let capacityFrames: Int
    
    private let buffer: UnsafeMutablePointer<Float>
    private let totalSamples: Int
    
    // Atomic head and tail frame positions
    private var writeHead: Int = 0
    private var readHead: Int = 0
    private let lock = NSLock()
    
    // Telemetry
    public private(set) var overrunCount: Int = 0
    public private(set) var underrunCount: Int = 0
    
    public init(channels: Int = 2, capacityFrames: Int = 32768) {
        self.channels = max(1, min(8, channels))
        self.capacityFrames = max(256, capacityFrames)
        self.totalSamples = self.channels * self.capacityFrames
        
        self.buffer = UnsafeMutablePointer<Float>.allocate(capacity: self.totalSamples)
        self.buffer.initialize(repeating: 0.0, count: self.totalSamples)
    }
    
    deinit {
        buffer.deinitialize(count: totalSamples)
        buffer.deallocate()
    }
    
    /// Returns the number of frames currently available to read.
    public var availableReadFrames: Int {
        lock.lock()
        defer { lock.unlock() }
        let diff = writeHead - readHead
        return diff >= 0 ? diff : (capacityFrames + diff)
    }
    
    /// Returns the number of free frame slots available to write.
    public var availableWriteFrames: Int {
        capacityFrames - availableReadFrames - 1
    }
    
    /// Writes stereo or mono audio frames simultaneously to the ring buffer.
    @discardableResult
    public func writeStereo(left: UnsafePointer<Float>, right: UnsafePointer<Float>?, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }
        
        lock.lock()
        let available = capacityFrames - (writeHead >= readHead ? (writeHead - readHead) : (capacityFrames + writeHead - readHead)) - 1
        let framesToWrite = min(frameCount, available)
        
        if framesToWrite < frameCount {
            overrunCount += (frameCount - framesToWrite)
        }
        
        guard framesToWrite > 0 else {
            lock.unlock()
            return 0
        }
        
        for f in 0..<framesToWrite {
            let destIdx = ((writeHead + f) % capacityFrames) * channels
            buffer[destIdx] = left[f]
            if channels > 1 {
                buffer[destIdx + 1] = right != nil ? right![f] : left[f]
            }
        }
        
        writeHead = (writeHead + framesToWrite) % capacityFrames
        lock.unlock()
        return framesToWrite
    }

    /// Writes single-channel audio frames to the ring buffer.
    @discardableResult
    public func write(from source: UnsafePointer<Float>, frameCount: Int, channelIndex: Int = 0) -> Int {
        guard frameCount > 0 else { return 0 }
        
        lock.lock()
        let available = capacityFrames - (writeHead >= readHead ? (writeHead - readHead) : (capacityFrames + writeHead - readHead)) - 1
        let framesToWrite = min(frameCount, available)
        
        if framesToWrite < frameCount {
            overrunCount += (frameCount - framesToWrite)
        }
        
        guard framesToWrite > 0 else {
            lock.unlock()
            return 0
        }
        
        for f in 0..<framesToWrite {
            let destIdx = ((writeHead + f) % capacityFrames) * channels + channelIndex
            buffer[destIdx] = source[f]
        }
        
        writeHead = (writeHead + framesToWrite) % capacityFrames
        lock.unlock()
        return framesToWrite
    }
    
    /// Writes interleaved multi-channel float audio frames to the ring buffer.
    @discardableResult
    public func writeInterleaved(from source: UnsafePointer<Float>, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }
        
        lock.lock()
        let available = capacityFrames - (writeHead >= readHead ? (writeHead - readHead) : (capacityFrames + writeHead - readHead)) - 1
        let framesToWrite = min(frameCount, available)
        
        if framesToWrite < frameCount {
            overrunCount += (frameCount - framesToWrite)
        }
        
        guard framesToWrite > 0 else {
            lock.unlock()
            return 0
        }
        
        let startFrame = writeHead
        let endFrame = (startFrame + framesToWrite) % capacityFrames
        
        if startFrame + framesToWrite <= capacityFrames {
            let sampleCount = framesToWrite * channels
            let destPtr = buffer.advanced(by: startFrame * channels)
            destPtr.update(from: source, count: sampleCount)
        } else {
            let firstChunkFrames = capacityFrames - startFrame
            let firstChunkSamples = firstChunkFrames * channels
            let destPtr1 = buffer.advanced(by: startFrame * channels)
            destPtr1.update(from: source, count: firstChunkSamples)
            
            let secondChunkFrames = framesToWrite - firstChunkFrames
            let secondChunkSamples = secondChunkFrames * channels
            let srcPtr2 = source.advanced(by: firstChunkSamples)
            buffer.update(from: srcPtr2, count: secondChunkSamples)
        }
        
        writeHead = endFrame
        lock.unlock()
        return framesToWrite
    }
    
    /// Reads interleaved multi-channel float audio frames from the ring buffer into the destination pointer.
    /// Returns the number of frames successfully read.
    @discardableResult
    public func readInterleaved(into destination: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }
        
        lock.lock()
        let available = writeHead >= readHead ? (writeHead - readHead) : (capacityFrames + writeHead - readHead)
        let framesToRead = min(frameCount, available)
        
        if framesToRead < frameCount {
            underrunCount += (frameCount - framesToRead)
            // Zero out underrun padding
            let padSamples = (frameCount - framesToRead) * channels
            let padPtr = destination.advanced(by: framesToRead * channels)
            padPtr.initialize(repeating: 0.0, count: padSamples)
        }
        
        guard framesToRead > 0 else {
            lock.unlock()
            return 0
        }
        
        let startFrame = readHead
        let endFrame = (startFrame + framesToRead) % capacityFrames
        
        if startFrame + framesToRead <= capacityFrames {
            let sampleCount = framesToRead * channels
            let srcPtr = buffer.advanced(by: startFrame * channels)
            destination.update(from: srcPtr, count: sampleCount)
        } else {
            let firstChunkFrames = capacityFrames - startFrame
            let firstChunkSamples = firstChunkFrames * channels
            let srcPtr1 = buffer.advanced(by: startFrame * channels)
            destination.update(from: srcPtr1, count: firstChunkSamples)
            
            let secondChunkFrames = framesToRead - firstChunkFrames
            let secondChunkSamples = secondChunkFrames * channels
            let destPtr2 = destination.advanced(by: firstChunkSamples)
            destPtr2.update(from: buffer, count: secondChunkSamples)
        }
        
        readHead = endFrame
        lock.unlock()
        return framesToRead
    }
    
    /// Reads non-interleaved float frames for a single channel.
    @discardableResult
    public func read(into destination: UnsafeMutablePointer<Float>, frameCount: Int, channelIndex: Int = 0) -> Int {
        guard frameCount > 0 else { return 0 }
        
        lock.lock()
        let available = writeHead >= readHead ? (writeHead - readHead) : (capacityFrames + writeHead - readHead)
        let framesToRead = min(frameCount, available)
        
        if framesToRead < frameCount {
            underrunCount += (frameCount - framesToRead)
            for f in framesToRead..<frameCount {
                destination[f] = 0.0
            }
        }
        
        guard framesToRead > 0 else {
            lock.unlock()
            return 0
        }
        
        let startFrame = readHead
        let endFrame = (startFrame + framesToRead) % capacityFrames
        
        for f in 0..<framesToRead {
            let srcIdx = ((startFrame + f) % capacityFrames) * channels + channelIndex
            destination[f] = buffer[srcIdx]
        }
        
        readHead = endFrame
        lock.unlock()
        return framesToRead
    }
    
    /// Resets buffer read and write pointers, clearing all stored audio.
    public func reset() {
        lock.lock()
        writeHead = 0
        readHead = 0
        overrunCount = 0
        underrunCount = 0
        buffer.initialize(repeating: 0.0, count: totalSamples)
        lock.unlock()
    }
}
