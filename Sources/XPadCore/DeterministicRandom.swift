import Foundation

/// Deterministic, seedable random source for musical generation.
///
/// Generative harmony has to be reproducible: the same seed, style blend, and
/// key must produce the same progression in the app, in an exported MIDI file,
/// and in a test run on someone else's machine. `DeterministicRandom` implements
/// SplitMix64, which is small, fast, and has no dependency on platform
/// randomness (`SystemRandomNumberGenerator` deliberately cannot be seeded).
public struct DeterministicRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    /// - Parameter seed: Any value. The same seed always yields the same stream.
    public init(seed: UInt64) {
        self.state = seed
    }

    /// Seeds from text, e.g. a progression name, so sharing a name shares a result.
    public init(seed: String) {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325 // FNV-1a 64-bit offset basis
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        self.init(seed: hash)
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<1`.
    public mutating func nextDouble() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// Uniform value in `lower...upper`, tolerating an inverted range.
    public mutating func nextDouble(in lower: Double, _ upper: Double) -> Double {
        guard lower.isFinite, upper.isFinite else { return lower }
        let lo = min(lower, upper)
        let hi = max(lower, upper)
        return lo + nextDouble() * (hi - lo)
    }

    /// `true` with the given probability, clamped to `0...1`.
    public mutating func chance(_ probability: Double) -> Bool {
        nextDouble() < probability.clamped(to: 0...1)
    }

    /// Uniform integer in `0..<count`, or `nil` when `count` is not positive.
    public mutating func index(count: Int) -> Int? {
        guard count > 0 else { return nil }
        return Int(next() % UInt64(count))
    }

    /// Uniform element, or `nil` for an empty collection.
    public mutating func pick<T>(_ values: [T]) -> T? {
        guard let index = index(count: values.count) else { return nil }
        return values[index]
    }

    /// Weighted element index. Non-finite and negative weights count as zero.
    public mutating func pickWeightedIndex(weights: [Double]) -> Int? {
        let sanitised = weights.map { $0.isFinite && $0 > 0 ? $0 : 0 }
        let total = sanitised.reduce(0, +)
        guard total > 0 else { return index(count: weights.count) }
        var threshold = nextDouble() * total
        for (index, weight) in sanitised.enumerated() {
            threshold -= weight
            if threshold < 0 { return index }
        }
        return sanitised.lastIndex(where: { $0 > 0 })
    }

    /// Weighted element, or `nil` when the collection is empty.
    public mutating func pickWeighted<T>(_ values: [T], weights: [Double]) -> T? {
        guard let index = pickWeightedIndex(weights: weights), index < values.count else { return nil }
        return values[index]
    }
}
