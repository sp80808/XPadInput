import Foundation

/// How a played chord is released after its performance gesture begins.
public enum ChordHoldMode: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// Sound only while the source gesture remains active.
    case momentary = "Hold"
    /// Sound for a configured duration after each gesture edge.
    case timed = "Timed"
    /// Toggle the selected chord on and off with successive gesture edges.
    case latch = "Latch"

    public var id: String { rawValue }
}

/// User-facing chord release settings with a safe, bounded timed duration.
public struct ChordGateConfiguration: Codable, Hashable, Sendable {
    public static let minimumTimedDuration: TimeInterval = 0.05
    public static let maximumTimedDuration: TimeInterval = 8.0

    public var mode: ChordHoldMode
    public private(set) var timedDuration: TimeInterval

    public init(mode: ChordHoldMode = .momentary, timedDuration: TimeInterval = 0.8) {
        self.mode = mode
        self.timedDuration = Self.clampedDuration(timedDuration)
    }

    public mutating func setTimedDuration(_ duration: TimeInterval) {
        timedDuration = Self.clampedDuration(duration)
    }

    private static func clampedDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else { return 0.8 }
        return min(maximumTimedDuration, max(minimumTimedDuration, duration))
    }
}

/// The exact voiced notes owned by one chord gesture.
///
/// Keeping the voicing with the chord ensures release events target the same notes that
/// began, even if the harmonic-wheel selection changes before release.
public struct ChordGateVoice: Codable, Hashable, Sendable {
    public var chord: Chord
    public var notes: [Note]

    public init(chord: Chord, notes: [Note]) {
        self.chord = chord
        self.notes = notes
    }
}

public enum ChordGateEvent: Hashable, Sendable {
    case began(ChordGateVoice)
    case ended(ChordGateVoice)
}

/// Top-level performance routing exposed to UI and persistence layers.
public enum DuoPerformanceMode: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case instrumentOnly = "Instrument"
    case drumsAndInstrument = "Drums + Instrument"

    public var id: String { rawValue }
}

/// Geometry-based face-button names, independent of a controller's printed glyphs.
public enum DuoFaceButton: String, CaseIterable, Codable, Hashable, Sendable {
    case south
    case west
    case north
    case east
}

public enum DuoDrumVoice: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case kick = "Kick"
    case snare = "Snare"
    case closedHat = "Closed Hat"
    case openHat = "Open Hat"

    public var id: String { rawValue }

    /// General MIDI percussion note used when routing the duo lane to a DAW.
    public var generalMIDINote: UInt8 {
        switch self {
        case .kick: return 36
        case .snare: return 38
        case .closedHat: return 42
        case .openHat: return 46
        }
    }
}

public enum DuoContinuousControl: String, CaseIterable, Codable, Hashable, Sendable {
    case leftStick
    case rightStick
}

public struct DuoDrumBinding: Codable, Hashable, Sendable {
    public var button: DuoFaceButton
    public var voice: DuoDrumVoice

    public init(button: DuoFaceButton, voice: DuoDrumVoice) {
        self.button = button
        self.voice = voice
    }
}

/// Collision-free split used when drums and a pitched instrument are played together.
///
/// Pitched gestures retain both sticks while the four face-button edges are reserved for
/// drums. Printed A/B/X/Y positions are translated into these geometric button names by
/// the controller layer, so the physical layout remains consistent across controller brands.
public struct DuoControlScheme: Codable, Hashable, Sendable {
    public var chordSelectionControl: DuoContinuousControl
    public var instrumentGestureControl: DuoContinuousControl
    public var drumBindings: [DuoDrumBinding]

    public init(
        chordSelectionControl: DuoContinuousControl,
        instrumentGestureControl: DuoContinuousControl,
        drumBindings: [DuoDrumBinding]
    ) {
        self.chordSelectionControl = chordSelectionControl
        self.instrumentGestureControl = instrumentGestureControl
        self.drumBindings = drumBindings
    }

    public func drumVoice(for button: DuoFaceButton) -> DuoDrumVoice? {
        drumBindings.first(where: { $0.button == button })?.voice
    }

    public static let standard = DuoControlScheme(
        chordSelectionControl: .leftStick,
        instrumentGestureControl: .rightStick,
        drumBindings: [
            DuoDrumBinding(button: .south, voice: .kick),
            DuoDrumBinding(button: .west, voice: .snare),
            DuoDrumBinding(button: .north, voice: .closedHat),
            DuoDrumBinding(button: .east, voice: .openHat)
        ]
    )
}
