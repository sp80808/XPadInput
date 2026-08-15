import Foundation

/// Reusable transfer functions for analog inputs.
/// A response curve transforms a normalized magnitude [0.0, 1.0] while preserving direction.
public enum ResponseCurve: Sendable {
    case linear
    case soft
    case precision
    case aggressive
    case exponential(Float)
    case sCurve

    /// Applies the curve to a normalized input magnitude.
    /// - Parameter magnitude: Input magnitude in range [0.0, 1.0].
    /// - Returns: Processed magnitude in range [0.0, 1.0].
    public func process(magnitude: Float) -> Float {
        let m = max(0.0, min(1.0, magnitude))
        switch self {
        case .linear:
            return m
        case .soft:
            // A gentle curve providing slightly more precision near the center
            return pow(m, 1.5)
        case .precision:
            // More precision near center, steeper at the end
            return pow(m, 2.2)
        case .aggressive:
            // Quick response near the center
            return pow(m, 0.6)
        case .exponential(let exponent):
            return pow(m, exponent)
        case .sCurve:
            // Smoothstep-like S-curve
            return m * m * (3.0 - 2.0 * m)
        }
    }
}
