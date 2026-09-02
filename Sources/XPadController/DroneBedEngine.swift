import Foundation
import XPadCore

// MARK: - Drone Bed Engine

/// Sustained chord-bed lifecycle for Drone Pad play mode.
///
/// Unlike the chord gate (which releases on strum release), the drone bed holds
/// a full chord indefinitely. Note-offs fire only when a voice's notes leave
/// the desired set — i.e. on chord change or panic. The engine is pure: it
/// diffs the desired voice against the sounding bed and returns only the
/// delta events, so the caller forwards them to MIDI/audio.
public struct DroneBedEngine: Sendable {
    public enum Event: Equatable, Sendable {
        case noteOn(Note, velocity: UInt8)
        case noteOff(Note)
    }

    /// Notes currently sustained by the bed.
    public private(set) var activeNotes: [Note] = []
    /// The voice the bed is currently sustaining.
    public private(set) var currentVoice: ChordGateVoice?
    /// Velocity used for the most recent articulation.
    public private(set) var lastVelocity: UInt8 = 84

    public init() {}

    /// Morph the bed toward `voice`. Notes present in both voices keep
    /// sounding untouched; only additions and removals produce events.
    public mutating func setVoice(_ voice: ChordGateVoice?, timestamp: TimeInterval) -> [Event] {
        guard let voice else { return releaseAll() }
        let target = deduplicated(voice.notes)
        let targetIDs = Set(target.map(\.midiNote))
        let activeIDs = Set(activeNotes.map(\.midiNote))

        var events: [Event] = []
        // Release notes that left the chord.
        for note in activeNotes where !targetIDs.contains(note.midiNote) {
            events.append(.noteOff(note))
        }
        // Attack notes that joined the chord.
        for note in target where !activeIDs.contains(note.midiNote) {
            events.append(.noteOn(note, velocity: lastVelocity))
        }

        currentVoice = voice
        activeNotes = target
        return events
    }

    /// Re-attack every sustained note at `velocity` without re-gating
    /// (strum accent). Sounding notes are not interrupted.
    public mutating func rearticulate(velocity: UInt8) -> [Event] {
        lastVelocity = velocity
        return activeNotes.map { .noteOn($0, velocity: velocity) }
    }

    /// Silence the entire bed immediately (panic / mode exit).
    public mutating func releaseAll() -> [Event] {
        let events = activeNotes.map { Event.noteOff($0) }
        activeNotes = []
        currentVoice = nil
        return events
    }

    /// Drop bookkeeping without emitting note-offs. For hosts that already
    /// flushed all sound globally (e.g. MIDI panic).
    public mutating func resetSilently() {
        activeNotes = []
        currentVoice = nil
    }

    private func deduplicated(_ notes: [Note]) -> [Note] {
        var seen = Set<UInt8>()
        return notes.filter { seen.insert($0.midiNote).inserted }
    }
}
