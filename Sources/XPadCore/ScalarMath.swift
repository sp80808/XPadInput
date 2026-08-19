import Foundation

public extension Comparable {
    /// Restricts the value to `range`.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

public extension BinaryFloatingPoint {
    /// The value restricted to `0...1`, treating non-finite input as zero.
    var normalizedUnit: Self {
        isFinite ? clamped(to: 0...1) : 0
    }

    /// The value restricted to `-1...1`, treating non-finite input as zero.
    var normalizedBipolar: Self {
        isFinite ? clamped(to: -1...1) : 0
    }
}
