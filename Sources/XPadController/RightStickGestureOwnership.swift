import Foundation
import XPadCore

/// Semantic owner of the right analog stick. Exclusive for guitar-like instruments;
/// lead/MPE may report the dominant axis while both bend and timbre remain active.
public enum RightStickOwnedGesture: String, Sendable, Equatable {
    case idle
    case strum
    case sustain
    case bend
    case timbre
    case bow

    /// HUD copy. `nil` keeps the mapping label so idle does not add layout motion.
    public var hudRole: String? {
        switch self {
        case .idle: return nil
        case .strum: return "Strum"
        case .sustain: return "Sustain"
        case .bend: return "Bend"
        case .timbre: return "Timbre"
        case .bow: return "Bow"
        }
    }
}

public struct RightStickOwnershipPolicy: Sendable, Equatable {
    public var allowsStrum: Bool
    public var allowsBend: Bool
    public var allowsTimbre: Bool
    public var allowsBow: Bool
    /// When true, X can bend while Y shapes timbre after a note is held.
    public var independentAxes: Bool

    public init(
        allowsStrum: Bool,
        allowsBend: Bool,
        allowsTimbre: Bool,
        allowsBow: Bool,
        independentAxes: Bool
    ) {
        self.allowsStrum = allowsStrum
        self.allowsBend = allowsBend
        self.allowsTimbre = allowsTimbre
        self.allowsBow = allowsBow
        self.independentAxes = independentAxes
    }

    public static func policy(for profile: InstrumentProfile) -> RightStickOwnershipPolicy {
        if profile.supportsBowing {
            return RightStickOwnershipPolicy(
                allowsStrum: false,
                allowsBend: profile.supportsPitchBend,
                allowsTimbre: false,
                allowsBow: true,
                independentAxes: false
            )
        }
        if profile.family == .synthLead || profile.family == .genericMPE {
            return RightStickOwnershipPolicy(
                allowsStrum: false,
                allowsBend: profile.supportsPitchBend,
                allowsTimbre: true,
                allowsBow: false,
                independentAxes: true
            )
        }
        return RightStickOwnershipPolicy(
            allowsStrum: profile.supportsStrumming,
            allowsBend: profile.supportsPitchBend,
            allowsTimbre: false,
            allowsBow: false,
            independentAxes: false
        )
    }
}

/// Right-stick gesture ownership with entry/exit hysteresis.
///
/// Guitar: `idle → strum → sustain → bend → sustain/idle`.
/// A committed vertical sweep cannot become a bend until that attack ends.
public struct RightStickGestureOwnership: Sendable, Equatable {
    public var owned: RightStickOwnedGesture
    public var policy: RightStickOwnershipPolicy

    public var strumEnterY: Double
    public var strumExitRadius: Double
    public var bendEnterX: Double
    public var bendExitX: Double
    public var bowEnterY: Double
    public var holdDominance: Double

    public init(
        owned: RightStickOwnedGesture = .idle,
        policy: RightStickOwnershipPolicy = .policy(for: .guitar),
        strumEnterY: Double = 0.28,
        strumExitRadius: Double = 0.16,
        bendEnterX: Double = 0.22,
        bendExitX: Double = 0.10,
        bowEnterY: Double = 0.28,
        holdDominance: Double = 0.55
    ) {
        self.owned = owned
        self.policy = policy
        self.strumEnterY = strumEnterY
        self.strumExitRadius = strumExitRadius
        self.bendEnterX = bendEnterX
        self.bendExitX = min(bendEnterX, bendExitX)
        self.bowEnterY = bowEnterY
        self.holdDominance = holdDominance
    }

    public var suppressesStrum: Bool {
        switch owned {
        case .strum, .sustain, .idle:
            return !policy.allowsStrum
        case .bend, .timbre, .bow:
            return true
        }
    }

    public var isBending: Bool {
        owned == .bend
    }

    public mutating func configure(profile: InstrumentProfile) {
        policy = .policy(for: profile)
        if !isTransitionAllowed(owned) {
            owned = .idle
        }
    }

    public mutating func reset() {
        owned = .idle
    }

    @discardableResult
    public mutating func evaluate(
        x: Double,
        y: Double,
        notesHeld: Bool
    ) -> RightStickOwnedGesture {
        let x = x.isFinite ? x : 0
        let y = y.isFinite ? y : 0
        let radius = hypot(x, y)
        let absX = abs(x)
        let absY = abs(y)

        if policy.independentAxes {
            owned = evaluateIndependentAxes(absX: absX, absY: absY, notesHeld: notesHeld)
            return owned
        }

        switch owned {
        case .idle:
            owned = acquireFromIdle(absX: absX, absY: absY, radius: radius, notesHeld: notesHeld)
        case .strum:
            if radius < strumExitRadius {
                owned = notesHeld && policy.allowsBend ? .sustain : .idle
            } else if absY < absX * holdDominance {
                // Still the same attack until the stick recentres; ignore X wobble.
                owned = .strum
            }
        case .sustain:
            if !notesHeld && radius < strumExitRadius {
                owned = .idle
            } else if policy.allowsStrum && absY >= strumEnterY && absY >= absX {
                owned = .strum
            } else if shouldAcquireBend(absX: absX, absY: absY, notesHeld: notesHeld) {
                owned = .bend
            } else if policy.allowsBow && absY >= bowEnterY && absY >= absX {
                owned = .bow
            }
        case .bend:
            if absX < bendExitX {
                owned = notesHeld ? .sustain : .idle
            }
        case .bow:
            if radius < strumExitRadius {
                owned = notesHeld && policy.allowsBend ? .sustain : .idle
            }
        case .timbre:
            owned = .idle
        }

        if !isTransitionAllowed(owned) {
            owned = .idle
        }
        return owned
    }

    private func evaluateIndependentAxes(absX: Double, absY: Double, notesHeld: Bool) -> RightStickOwnedGesture {
        guard notesHeld else { return .idle }
        let bending = policy.allowsBend && absX >= bendExitX
        let timbre = policy.allowsTimbre && absY >= 0.12
        if bending && timbre {
            return absX >= absY ? .bend : .timbre
        }
        if bending { return .bend }
        if timbre { return .timbre }
        return .sustain
    }

    private func acquireFromIdle(absX: Double, absY: Double, radius: Double, notesHeld: Bool) -> RightStickOwnedGesture {
        if policy.allowsBow && absY >= bowEnterY && absY >= absX {
            return .bow
        }
        if policy.allowsStrum && absY >= strumEnterY && absY >= absX {
            return .strum
        }
        if shouldAcquireBend(absX: absX, absY: absY, notesHeld: notesHeld) && absX > absY {
            return .bend
        }
        if notesHeld && radius >= strumExitRadius && (policy.allowsBend || policy.allowsTimbre || policy.allowsBow) {
            return .sustain
        }
        return .idle
    }

    private func shouldAcquireBend(absX: Double, absY: Double, notesHeld: Bool) -> Bool {
        policy.allowsBend && notesHeld && absX >= bendEnterX && absX >= absY * 1.10
    }

    private func isTransitionAllowed(_ gesture: RightStickOwnedGesture) -> Bool {
        switch gesture {
        case .idle, .sustain: return true
        case .strum: return policy.allowsStrum
        case .bend: return policy.allowsBend
        case .timbre: return policy.allowsTimbre
        case .bow: return policy.allowsBow
        }
    }
}
