import Foundation

public struct CalibrationPoint: Codable, Sendable, Equatable {
    public var x: Float
    public var y: Float

    public init(x: Float = 0, y: Float = 0) {
        self.x = x
        self.y = y
    }
}

/// Stores calibration data for analog inputs.
public struct ControllerCalibration: Codable, Sendable, Equatable {
    public var leftStickCenter: CalibrationPoint = CalibrationPoint(x: 0, y: 0)
    public var rightStickCenter: CalibrationPoint = CalibrationPoint(x: 0, y: 0)
    
    // Scale factor to map physical extents to full 1.0 range
    public var leftStickScale: Float = 1.0
    public var rightStickScale: Float = 1.0
    
    public init() {}
    
    /// Applies calibration offsets to raw input.
    public func applyToLeftStick(x: Float, y: Float) -> (Float, Float) {
        let cx = (x - leftStickCenter.x) * leftStickScale
        let cy = (y - leftStickCenter.y) * leftStickScale
        return (max(-1.0, min(1.0, cx)), max(-1.0, min(1.0, cy)))
    }
    
    public func applyToRightStick(x: Float, y: Float) -> (Float, Float) {
        let cx = (x - rightStickCenter.x) * rightStickScale
        let cy = (y - rightStickCenter.y) * rightStickScale
        return (max(-1.0, min(1.0, cx)), max(-1.0, min(1.0, cy)))
    }
}
