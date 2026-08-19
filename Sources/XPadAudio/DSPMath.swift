import Foundation

/// Primitives shared by the in-app synthesizer and the AUv3 render blocks.
enum DSPMath {
    /// Two-point polynomial band-limited step used to suppress aliasing at the
    /// discontinuities of saw and square oscillators.
    @inline(__always)
    static func polyBLEP(phase: Double, increment: Double) -> Double {
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
}
