import Foundation

/// Maintains stable sector selections by preventing jitter on boundaries.
public struct AngularHysteresis: Sendable {
    public let sectorCount: Int
    public let baseMargin: Double
    
    private var lastSector: Int?
    
    public init(sectorCount: Int, baseMargin: Double = .pi / 32) {
        self.sectorCount = sectorCount
        self.baseMargin = baseMargin
    }
    
    /// Evaluates the sector for a given angle with hysteresis.
    /// - Parameters:
    ///   - angle: The current angle in radians.
    ///   - velocity: The angular velocity, which can dynamically shrink the hysteresis margin.
    /// - Returns: The stabilized sector index.
    public mutating func evaluate(angle: Double, angularVelocity: Double = 0) -> Int {
        // Adjust margin based on velocity (faster movement = smaller margin to allow quick crossing)
        let dynamicMargin = max(0.001, baseMargin - abs(angularVelocity) * 0.005)
        
        let sliceAngle = (2 * .pi) / Double(sectorCount)
        
        // Normalize angle to [0, 2pi)
        var normAngle = angle
        while normAngle < 0 { normAngle += 2 * .pi }
        while normAngle >= 2 * .pi { normAngle -= 2 * .pi }
        
        let rawSectorDouble = normAngle / sliceAngle
        let rawSector = Int(rawSectorDouble) % sectorCount
        
        guard let last = lastSector else {
            lastSector = rawSector
            return rawSector
        }
        
        // If we are currently in `lastSector`, calculate the boundaries of this sector.
        // The sector `last` covers [last * sliceAngle, (last + 1) * sliceAngle).
        let lowerBound = Double(last) * sliceAngle
        let upperBound = Double(last + 1) * sliceAngle
        
        // Check distance to boundaries to see if we've crossed with enough margin
        // We use modular distance for the lower bound since it might wrap around 0
        var distToLower = normAngle - lowerBound
        if distToLower < -(.pi) { distToLower += 2 * .pi }
        if distToLower > .pi { distToLower -= 2 * .pi }
        
        var distToUpper = normAngle - upperBound
        if distToUpper < -(.pi) { distToUpper += 2 * .pi }
        if distToUpper > .pi { distToUpper -= 2 * .pi }
        
        // If we are outside the expanded sector bounds, change sector
        if distToLower < -dynamicMargin {
            // We crossed the lower bound
            let newSector = (last - 1 + sectorCount) % sectorCount
            lastSector = newSector
            return newSector
        } else if distToUpper > dynamicMargin {
            // We crossed the upper bound
            let newSector = (last + 1) % sectorCount
            lastSector = newSector
            return newSector
        }
        
        return last
    }
    
    public mutating func reset() {
        lastSector = nil
    }
}
