import Foundation

/// The single source of truth for the app version string embedded in exported
/// files and MIDI-CI device info. Keep in sync with `scripts/package-macos.sh`.
public enum XPadVersion {
    public static let current = "0.0.05"
}
