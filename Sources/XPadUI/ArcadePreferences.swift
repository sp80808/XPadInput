import Foundation

/// User-facing settings for the hidden "Arcade Frets" Guitar Hero-style mode.
///
/// Values are validated at construction: `velocityFloor` is clamped to
/// `1...127` and `velocityCeiling` is clamped to `floor...127`, so a decoded
/// or loaded instance can never hold an inverted or out-of-range pair.
public struct ArcadePreferences: Sendable, Equatable, Codable {
    /// Whether the user has been shown the one-time unlock announcement.
    public var unlockSeen: Bool
    /// Whether the arcade frets lane is currently enabled.
    public var modeEnabled: Bool
    /// Minimum strike MIDI velocity for analog trigger frets.
    public var velocityFloor: Int
    /// Maximum strike MIDI velocity for analog trigger frets.
    public var velocityCeiling: Int

    /// Creates preferences, clamping the velocity range into `1...127` with
    /// the ceiling never below the floor.
    public init(
        unlockSeen: Bool = false,
        modeEnabled: Bool = false,
        velocityFloor: Int = 54,
        velocityCeiling: Int = 127
    ) {
        self.unlockSeen = unlockSeen
        self.modeEnabled = modeEnabled
        self.velocityFloor = min(max(velocityFloor, 1), 127)
        self.velocityCeiling = min(max(velocityCeiling, self.velocityFloor), 127)
    }
}

/// Loads and stores `ArcadePreferences` in an injected `UserDefaults` domain.
///
/// All keys are namespaced under `"xpi.arcade."`. Loading never mutates the
/// defaults database (`registerDefaults` is deliberately not used); absent keys
/// simply fall back to documented defaults, and stored values are re-clamped
/// through the validating initializer.
public struct ArcadePreferencesStore: Sendable {
    private enum Keys {
        static let unlockSeen = "xpi.arcade.unlockSeen"
        static let modeEnabled = "xpi.arcade.modeEnabled"
        static let velocityFloor = "xpi.arcade.velocityFloor"
        static let velocityCeiling = "xpi.arcade.velocityCeiling"
    }

    /// `UserDefaults` is documented as thread-safe; unsafe-annotated to satisfy
    /// `Sendable` without wrapping.
    private nonisolated(unsafe) let defaults: UserDefaults

    /// Creates a store backed by `defaults`; pass a suite-named instance for
    /// test isolation or app-group sharing.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Reads preferences, returning documented defaults for any absent key.
    public func load() -> ArcadePreferences {
        ArcadePreferences(
            unlockSeen: defaults.bool(forKey: Keys.unlockSeen),
            modeEnabled: defaults.bool(forKey: Keys.modeEnabled),
            velocityFloor: defaults.object(forKey: Keys.velocityFloor) as? Int ?? 54,
            velocityCeiling: defaults.object(forKey: Keys.velocityCeiling) as? Int ?? 127
        )
    }

    /// Writes all preference fields to the backing defaults database.
    public func save(_ prefs: ArcadePreferences) {
        defaults.set(prefs.unlockSeen, forKey: Keys.unlockSeen)
        defaults.set(prefs.modeEnabled, forKey: Keys.modeEnabled)
        defaults.set(prefs.velocityFloor, forKey: Keys.velocityFloor)
        defaults.set(prefs.velocityCeiling, forKey: Keys.velocityCeiling)
    }
}
