import Foundation
import XPadCore

/// Derives an exponential-moving-average coefficient from elapsed time.
///
/// Smoothing presets throughout the input pipeline were tuned as per-sample EMA
/// coefficients. Treating them as coefficients at a 120 Hz reference cadence and
/// re-deriving alpha from the actual elapsed time keeps the response curve
/// identical regardless of how often the controller delivers callbacks.
public struct TimeNormalizedEMA: Sendable {
    /// Cadence the stored smoothing presets were tuned against.
    public static let referenceInterval: TimeInterval = 1.0 / 120.0

    private var lastTimestamp: TimeInterval?

    public init() {}

    /// - Parameters:
    ///   - referenceFactor: Smoothing coefficient at the reference cadence.
    ///   - timestamp: Monotonic timestamp of the incoming sample.
    /// - Returns: The alpha to apply to this sample, or `0` when the sample
    ///   carries no usable time base.
    public mutating func alpha(referenceFactor: Float, at timestamp: TimeInterval) -> Float {
        let referenceAlpha = referenceFactor.normalizedUnit

        guard timestamp.isFinite else { return 0 }

        guard let previousTimestamp = lastTimestamp else {
            lastTimestamp = timestamp
            return referenceAlpha
        }

        if timestamp < previousTimestamp {
            // Clock restarted or jumped backwards (discontinuity / reconnect)
            lastTimestamp = timestamp
            return referenceAlpha
        }

        guard timestamp > previousTimestamp else {
            // Duplicate/reordered callbacks must not advance filter state.
            return 0
        }

        lastTimestamp = timestamp

        guard referenceAlpha < 1 else { return 1 }
        guard referenceAlpha > 0 else { return 0 }

        let elapsed = timestamp - previousTimestamp
        let retentionAtReference = 1.0 - Double(referenceAlpha)
        let elapsedReferenceFrames = elapsed / Self.referenceInterval
        let elapsedAlpha = 1.0 - pow(retentionAtReference, elapsedReferenceFrames)
        return Float(elapsedAlpha.normalizedUnit)
    }

    public mutating func reset() {
        lastTimestamp = nil
    }
}
