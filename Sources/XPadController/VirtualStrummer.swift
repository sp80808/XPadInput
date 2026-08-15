import Foundation
import XPadCore

public enum StrumDirection: String, Codable, Sendable {
    case down = "Down Strum"
    case up = "Up Strum"
    case muted = "Palm Muted"
    case rake = "Rake"
}

public struct StrummedNote: Sendable {
    public let note: Note
    public let velocity: UInt8
    public let delayMs: Double // Time offset for arpeggiation/spread
    public let stringIndex: Int

    public init(note: Note, velocity: UInt8, delayMs: Double, stringIndex: Int) {
        self.note = note
        self.velocity = velocity
        self.delayMs = delayMs
        self.stringIndex = stringIndex
    }
}

public struct StrumResult: Sendable {
    public let direction: StrumDirection
    public let notes: [StrummedNote]
    public let velocity: UInt8
    public let duration: Double
}

public final class VirtualStrummer: @unchecked Sendable {
    private var previousY: Double = 0.0
    private var previousTimestamp: TimeInterval = 0.0
    private var lastCrossedString: Int = -1
    private var isStrummingActive: Bool = false
    private let numberOfStrings: Int = 6

    public init() {}

    /// Processes a new stick coordinate and emits strum events when virtual string boundaries are crossed.
    public func processStick(
        stick: ProcessedStickState,
        triggerMute: Double,
        chordNotes: [Note],
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> StrumResult? {
        let y = Double(stick.y)
        let dy = y - previousY
        let speed = abs(Double(stick.yVelocity))

        defer {
            previousY = y
            previousTimestamp = timestamp
        }

        // Must exceed threshold motion to initiate strum
        guard abs(dy) > 0.04 && !chordNotes.isEmpty else {
            return nil
        }

        let direction: StrumDirection = dy < 0 ? .down : .up

        // Calculate dynamic velocity from stick speed (40 to 127)
        let rawVelocity = min(127, max(40, Int(speed * 35.0)))
        
        // Palm mute attenuates velocity and tightens decay
        let isMuted = triggerMute > 0.3
        let finalVelocity = isMuted ? UInt8(Double(rawVelocity) * (1.0 - triggerMute * 0.5)) : UInt8(rawVelocity)

        // String spread speed (faster speed = tighter spread, 2ms to 35ms between notes)
        let spreadIntervalMs = max(2.0, min(35.0, 120.0 / max(1.0, speed)))

        var orderedNotes = chordNotes
        if direction == .up {
            orderedNotes.reverse()
        }

        var strummedNotes: [StrummedNote] = []
        for (index, note) in orderedNotes.enumerated() {
            let noteVelocity = UInt8(clamping: Int(finalVelocity) + Int.random(in: -4...4))
            let delay = Double(index) * spreadIntervalMs
            strummedNotes.append(StrummedNote(
                note: note,
                velocity: noteVelocity,
                delayMs: delay,
                stringIndex: index
            ))
        }

        return StrumResult(
            direction: isMuted ? .muted : direction,
            notes: strummedNotes,
            velocity: finalVelocity,
            duration: Double(chordNotes.count) * spreadIntervalMs / 1000.0
        )
    }

    public func processStrum(stick: ProcessedStickState, notes: [Note]) -> [StrummedNote] {
        guard let result = processStick(stick: stick, triggerMute: 0.0, chordNotes: notes) else {
            return notes.enumerated().map { StrummedNote(note: $0.element, velocity: 80, delayMs: Double($0.offset * 10), stringIndex: $0.offset) }
        }
        return result.notes
    }
}
