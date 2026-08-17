import Foundation

/// A preset for how analog inputs should be processed.
public struct InputProcessingProfile: Sendable, Equatable {
    public var id: String
    public var name: String
    public var deadzone: DeadzoneStrategy
    public var responseCurve: ResponseCurve
    
    // Smoothing (0.0 to 1.0, where 1.0 is no smoothing/instant)
    public var smoothingFactor: Float = 1.0
    
    public init(id: String, name: String, deadzone: DeadzoneStrategy, responseCurve: ResponseCurve, smoothingFactor: Float = 1.0) {
        self.id = id
        self.name = name
        self.deadzone = deadzone
        self.responseCurve = responseCurve
        self.smoothingFactor = smoothingFactor
    }
    
    // MARK: - Factory Presets
    
    public static let expressive = InputProcessingProfile(
        id: "expressive",
        name: "Expressive",
        deadzone: .scaledRadial(0.12),
        responseCurve: .soft,
        smoothingFactor: 0.85
    )
    
    public static let precision = InputProcessingProfile(
        id: "precision",
        name: "Precision",
        deadzone: .scaledRadial(0.15),
        responseCurve: .precision,
        smoothingFactor: 0.7
    )
    
    public static let fast = InputProcessingProfile(
        id: "fast",
        name: "Fast",
        deadzone: .scaledRadial(0.08),
        responseCurve: .aggressive,
        smoothingFactor: 1.0
    )
    
    public static let stable = InputProcessingProfile(
        id: "stable",
        name: "Stable",
        deadzone: .hybridRadialSloped(inner: 0.18, axial: 0.25),
        responseCurve: .linear,
        smoothingFactor: 0.6
    )
    
    public static let accessible = InputProcessingProfile(
        id: "accessible",
        name: "Accessible",
        deadzone: .scaledRadial(0.1),
        responseCurve: .exponential(0.5), // Rapid output for small movements
        smoothingFactor: 0.9
    )
    
    public static let allPresets: [InputProcessingProfile] = [
        .expressive, .precision, .fast, .stable, .accessible, .reducedTravel
    ]
    
    // Custom equality to allow Picker selection (DeadzoneStrategy/ResponseCurve are not natively Equatable easily with associated values, but we can compare IDs)
    public static func == (lhs: InputProcessingProfile, rhs: InputProcessingProfile) -> Bool {
        return lhs.id == rhs.id
    }
}
