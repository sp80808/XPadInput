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
        guard x.isFinite, y.isFinite else { return (0, 0) }

        // A square thumbstick gate can report diagonals whose magnitude exceeds
        // one. Keep every downstream musical mapping in the unit circle while
        // preserving the player's intended direction.
        let rawMagnitude = sqrt(x * x + y * y)
        let inputScale = rawMagnitude > 1 ? 1 / rawMagnitude : 1
        let inputX = x * inputScale
        let inputY = y * inputScale

        switch self {
        case .none:
            return (inputX, inputY)
            
        case .scaledRadial(let deadzone):
            let safeDeadzone = Self.normalizedThreshold(deadzone)
            let magnitude = sqrt(inputX * inputX + inputY * inputY)
            guard magnitude > safeDeadzone else { return (0, 0) }
            let scaledMagnitude = (magnitude - safeDeadzone) / (1.0 - safeDeadzone)
            let ratio = scaledMagnitude / magnitude
            return (inputX * ratio, inputY * ratio)
            
        case .hybridRadialSloped(let inner, let axial):
            let safeInner = Self.normalizedThreshold(inner)
            let safeAxial = Self.normalizedThreshold(axial)
            let magnitude = sqrt(inputX * inputX + inputY * inputY)
            guard magnitude > safeInner else { return (0, 0) }
            
            // First apply scaled radial
            let scaledMagnitude = (magnitude - safeInner) / (1.0 - safeInner)
            let ratio = scaledMagnitude / magnitude
            var px = inputX * ratio
            var py = inputY * ratio
            
            // Then apply axial flattening
            if abs(px) < safeAxial { px = 0 }
            if abs(py) < safeAxial { py = 0 }
            
            // Re-normalize if needed (simplified axial suppression)
            let pmag = sqrt(px * px + py * py)
            if pmag > 1.0 {
                px /= pmag
                py /= pmag
            }
            return (px, py)
            
        case .directionalSnap(let threshold):
            let safeThreshold = Self.normalizedThreshold(threshold)
            let magnitude = sqrt(inputX * inputX + inputY * inputY)
            if magnitude < 0.05 { return (0, 0) } // Tiny inner deadzone
            
            var px = inputX
            var py = inputY
            
            if abs(inputX) < safeThreshold { px = 0 }
            if abs(inputY) < safeThreshold { py = 0 }
            
            let pmag = sqrt(px * px + py * py)
            if pmag > 0 {
                let ratio = magnitude / pmag
                px *= ratio
                py *= ratio
            }
            return (px, py)
        }
    }

    private static func normalizedThreshold(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        // Leaving a small denominator also makes an accidentally configured
        // 100% deadzone deterministic instead of producing NaN at the edge.
        return min(0.999, max(0, value))
    }
}
