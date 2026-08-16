import Foundation

/// Real-time multi-channel audio level meter calculating RMS and Peak decibels with responsive ballistics.
public final class AudioLevelMeter: @unchecked Sendable {
    public private(set) var peakLeft: Float = 0.0
    public private(set) var peakRight: Float = 0.0
    public private(set) var rmsLeft: Float = 0.0
    public private(set) var rmsRight: Float = 0.0
    
    // Normalized 0.0 to 1.0 linear values for UI meters
    public private(set) var linearLevelLeft: Float = 0.0
    public private(set) var linearLevelRight: Float = 0.0
    
    private let lock = NSLock()
    private let decayCoeff: Float = 0.88
    
    public init() {}
    
    /// Processes a block of stereo or mono audio frames and updates current levels.
    public func processFrames(left: UnsafePointer<Float>, right: UnsafePointer<Float>?, frameCount: Int) {
        guard frameCount > 0 else { return }
        
        var maxLeft: Float = 0.0
        var sumSquaresLeft: Float = 0.0
        var maxRight: Float = 0.0
        var sumSquaresRight: Float = 0.0
        
        for i in 0..<frameCount {
            let sL = abs(left[i])
            if sL > maxLeft { maxLeft = sL }
            sumSquaresLeft += sL * sL
            
            if let rightPtr = right {
                let sR = abs(rightPtr[i])
                if sR > maxRight { maxRight = sR }
                sumSquaresRight += sR * sR
            }
        }
        
        let calculatedRmsL = sqrt(sumSquaresLeft / Float(frameCount))
        let calculatedRmsR = right != nil ? sqrt(sumSquaresRight / Float(frameCount)) : calculatedRmsL
        let calculatedPeakR = right != nil ? maxRight : maxLeft
        
        lock.lock()
        // Instant attack, smooth decay
        peakLeft = max(maxLeft, peakLeft * decayCoeff)
        peakRight = max(calculatedPeakR, peakRight * decayCoeff)
        rmsLeft = max(calculatedRmsL, rmsLeft * decayCoeff)
        rmsRight = max(calculatedRmsR, rmsRight * decayCoeff)
        
        linearLevelLeft = min(1.0, peakLeft)
        linearLevelRight = min(1.0, peakRight)
        lock.unlock()
    }
    
    /// Processes interleaved stereo audio frames.
    public func processInterleaved(frames: UnsafePointer<Float>, frameCount: Int, channels: Int = 2) {
        guard frameCount > 0 else { return }
        
        var maxLeft: Float = 0.0
        var sumSquaresLeft: Float = 0.0
        var maxRight: Float = 0.0
        var sumSquaresRight: Float = 0.0
        
        for i in 0..<frameCount {
            let sL = abs(frames[i * channels])
            if sL > maxLeft { maxLeft = sL }
            sumSquaresLeft += sL * sL
            
            if channels >= 2 {
                let sR = abs(frames[i * channels + 1])
                if sR > maxRight { maxRight = sR }
                sumSquaresRight += sR * sR
            }
        }
        
        let calculatedRmsL = sqrt(sumSquaresLeft / Float(frameCount))
        let calculatedRmsR = channels >= 2 ? sqrt(sumSquaresRight / Float(frameCount)) : calculatedRmsL
        let calculatedPeakR = channels >= 2 ? maxRight : maxLeft
        
        lock.lock()
        peakLeft = max(maxLeft, peakLeft * decayCoeff)
        peakRight = max(calculatedPeakR, peakRight * decayCoeff)
        rmsLeft = max(calculatedRmsL, rmsLeft * decayCoeff)
        rmsRight = max(calculatedRmsR, rmsRight * decayCoeff)
        
        linearLevelLeft = min(1.0, peakLeft)
        linearLevelRight = min(1.0, peakRight)
        lock.unlock()
    }
    
    /// Returns current level in decibels (full-scale dBFS, e.g. -60.0 to 0.0 dB).
    public var peakLeftDB: Float {
        linearToDB(peakLeft)
    }
    
    public var peakRightDB: Float {
        linearToDB(peakRight)
    }
    
    public var rmsLeftDB: Float {
        linearToDB(rmsLeft)
    }
    
    public var rmsRightDB: Float {
        linearToDB(rmsRight)
    }
    
    public func reset() {
        lock.lock()
        peakLeft = 0.0
        peakRight = 0.0
        rmsLeft = 0.0
        rmsRight = 0.0
        linearLevelLeft = 0.0
        linearLevelRight = 0.0
        lock.unlock()
    }
    
    private func linearToDB(_ linear: Float) -> Float {
        guard linear > 0.00001 else { return -100.0 }
        return 20.0 * log10(linear)
    }
}
