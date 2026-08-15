import Foundation
import CoreMIDI

/// MPE Channel Manager — allocates per-note channels (2–15) for polyphonic expression.
/// Zone Master Channel is Channel 1 (0-indexed: 0).
@Observable
final class MPEChannelManager: @unchecked Sendable {
    /// MPE Zone Master channel (0-indexed)
    let masterChannel: UInt8 = 0
    /// Available member channels (1-indexed MIDI channels 2–16 = 0-indexed 1–15)
    private let memberChannels: [UInt8] = Array(1...15)

    /// Maps active MIDI note number → allocated channel
    private(set) var activeAllocations: [UInt8: UInt8] = [:]

    /// Round-robin index
    private var nextChannelIndex: Int = 0

    private let lock = NSLock()

    /// Allocate a member channel for a note. Returns the 0-indexed channel.
    func allocate(note: UInt8) -> UInt8 {
        lock.lock()
        defer { lock.unlock() }

        // If note already active, re-use its channel
        if let existing = activeAllocations[note] {
            return existing
        }

        // Round-robin through member channels, stealing if necessary
        let channel = memberChannels[nextChannelIndex % memberChannels.count]
        nextChannelIndex += 1

        // If this channel is already used by another note, release that note first
        if let conflicting = activeAllocations.first(where: { $0.value == channel }) {
            activeAllocations.removeValue(forKey: conflicting.key)
        }

        activeAllocations[note] = channel
        return channel
    }

    /// Release a note's channel allocation.
    func release(note: UInt8) -> UInt8? {
        lock.lock()
        defer { lock.unlock() }
        return activeAllocations.removeValue(forKey: note)
    }

    /// Release all allocations.
    func releaseAll() {
        lock.lock()
        defer { lock.unlock() }
        activeAllocations.removeAll()
        nextChannelIndex = 0
    }

    /// How many voices are currently active
    var activeVoiceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeAllocations.count
    }
}
