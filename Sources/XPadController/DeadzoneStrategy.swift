import Foundation
import XPadCore

/// Represents a strategy for handling analog deadzones.
public enum DeadzoneStrategy: Sendable {
    /// No deadzone applied.
    case none
    /// Applies a radial deadzone and smoothly rescales the remaining range.
    case scaledRadial(Float)
    /// Applies a radial deadzone and creates a flat response on the cardinal axes to make vertical/horizontal movement easier.
    case hybridRadialSloped(inner: Float, axial: Float)
    /// Snaps strongly to cardinal directions near the axes.
    case directionalSnap(Float)

    /// Applies the deadzone strategy to an raw (x, y) input vector.
    /// - Returns: The processed (x, y) vector.
    public func process(x: Float, y: Float) -> (x: Float, y: Float) {
        switch self {
        case .none:
            return (x, y)
            
        case .scaledRadial(let deadzone):
            let magnitude = sqrt(x * x + y * y)
            guard magnitude > deadzone else { return (0, 0) }
            let scaledMagnitude = (magnitude - deadzone) / (1.0 - deadzone)
            let ratio = scaledMagnitude / magnitude
            return (x * ratio, y * ratio)
            
        case .hybridRadialSloped(let inner, let axial):
            let magnitude = sqrt(x * x + y * y)
            guard magnitude > inner else { return (0, 0) }
            
            // First apply scaled radial
            let scaledMagnitude = (magnitude - inner) / (1.0 - inner)
            let ratio = scaledMagnitude / magnitude
            var px = x * ratio
            var py = y * ratio
            
            // Then apply axial flattening
            if abs(px) < axial { px = 0 }
            if abs(py) < axial { py = 0 }
            
            // Re-normalize if needed (simplified axial suppression)
            let pmag = sqrt(px * px + py * py)
            if pmag > 1.0 {
                px /= pmag
                py /= pmag
            }
            return (px, py)
            
        case .directionalSnap(let threshold):
            let magnitude = sqrt(x * x + y * y)
            if magnitude < 0.05 { return (0, 0) } // Tiny inner deadzone
            
            var px = x
            var py = y
            
            if abs(x) < threshold { px = 0 }
            if abs(y) < threshold { py = 0 }
            
            let pmag = sqrt(px * px + py * py)
            if pmag > 0 {
                let ratio = magnitude / pmag
                px *= ratio
                py *= ratio
            }
            return (px, py)
        }
    }
}
