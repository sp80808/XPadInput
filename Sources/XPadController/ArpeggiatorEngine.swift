import Foundation
import XPadCore

/// Pure, deterministic Arpeggiator engine that turns held chord voices into expressive,
/// tempo-synced note sequences across customizable patterns and octave registers.
public struct ArpeggiatorEngine: Sendable {
    public var configuration: ArpeggiatorConfiguration
    public private(set) var activeVoice: ChordGateVoice?
    public private(set) var sequence: [Note] = []
    public private(set) var currentStepIndex: Int = 0
    public private(set) var activeSoundingNote: Note?
    
    private var lastTick: UInt64?
    private var noteOffTick: UInt64?
    private var lastAdvanceTime: TimeInterval = 0
    private var nextStepTime: TimeInterval?
    private var noteOffTime: TimeInterval?
    private var rngSeed: UInt64

    public init(
        configuration: ArpeggiatorConfiguration = ArpeggiatorConfiguration(),
        seed: UInt64 = 0x1234_5678
    ) {
        self.configuration = configuration
        self.rngSeed = seed
    }

    // MARK: - Sequence Generation

    /// Builds a deterministic arpeggio sequence from base chord notes.
    public static func generateSequence(
        from baseNotes: [Note],
        pattern: ArpeggiatorPattern,
        octaveRange: Int,
        rngSeed: inout UInt64
    ) -> [Note] {
        guard !baseNotes.isEmpty else { return [] }

        let sorted = baseNotes.sorted()
        let octaves = max(1, min(4, octaveRange))

        // Expand across octaves
        var expanded: [Note] = []
        for oct in 0..<octaves {
            for note in sorted {
                expanded.append(note.transposed(by: oct * 12))
            }
        }

        guard !expanded.isEmpty else { return [] }

        switch pattern {
        case .up:
            return expanded

        case .down:
            return expanded.reversed()

        case .upDown:
            if expanded.count <= 2 { return expanded }
            var result = expanded
            let descendingMiddle = expanded.dropFirst().dropLast().reversed()
            result.append(contentsOf: descendingMiddle)
            return result

        case .downUp:
            if expanded.count <= 2 { return expanded.reversed() }
            let reversed = Array(expanded.reversed())
            var result = reversed
            let ascendingMiddle = reversed.dropFirst().dropLast().reversed()
            result.append(contentsOf: ascendingMiddle)
            return result

        case .converge:
            var result: [Note] = []
            var low = 0
            var high = expanded.count - 1
            while low <= high {
                result.append(expanded[low])
                if low != high {
                    result.append(expanded[high])
                }
                low += 1
                high -= 1
            }
            return result

        case .diverge:
            let converged = generateSequence(from: baseNotes, pattern: .converge, octaveRange: octaveRange, rngSeed: &rngSeed)
            return Array(converged.reversed())

        case .random:
            // Deterministic LCG shuffle
            var pool = expanded
            var result: [Note] = []
            for _ in 0..<pool.count {
                rngSeed = rngSeed &* 6364136223846793005 &+ 1442695040888963407
                let idx = Int(rngSeed % UInt64(pool.count))
                result.append(pool.remove(at: idx))
            }
            return result
        }
    }

    // MARK: - Voice Lifecycle

    /// Updates the active chord voice, recalculating the sequence and resetting or retaining position.
    public mutating func setVoice(_ voice: ChordGateVoice?) -> [ArpeggiatorEvent] {
        if voice == activeVoice { return [] }
        
        var events: [ArpeggiatorEvent] = []
        if let current = activeSoundingNote {
            events.append(.noteOff(current))
            activeSoundingNote = nil
        }

        activeVoice = voice
        currentStepIndex = 0
        noteOffTick = nil
        nextStepTime = nil
        noteOffTime = nil

        if let voice, !voice.notes.isEmpty {
            sequence = Self.generateSequence(
                from: voice.notes,
                pattern: configuration.pattern,
                octaveRange: configuration.octaveRange,
                rngSeed: &rngSeed
            )
        } else {
            sequence = []
        }

        return events
    }

    /// Re-evaluates configuration (e.g. pattern, rate, octaves) while active.
    public mutating func updateConfiguration(_ config: ArpeggiatorConfiguration) -> [ArpeggiatorEvent] {
        self.configuration = config
        if let voice = activeVoice, !voice.notes.isEmpty {
            sequence = Self.generateSequence(
                from: voice.notes,
                pattern: config.pattern,
                octaveRange: config.octaveRange,
                rngSeed: &rngSeed
            )
            if currentStepIndex >= sequence.count {
                currentStepIndex = 0
            }
        }
        return []
    }

    /// Steps tick-based transport (e.g. from 960 PPQN clock).
    public mutating func processTick(
        currentTick: UInt64,
        velocity: UInt8 = 100
    ) -> [ArpeggiatorEvent] {
        guard !sequence.isEmpty else { return releaseAll() }

        var events: [ArpeggiatorEvent] = []
        let stepTicks = configuration.rate.ticksPerStep
        let gateTicks = UInt64(Double(stepTicks) * configuration.gateLength)

        // Handle note off when gate expires
        if let targetOff = noteOffTick, currentTick >= targetOff {
            if let active = activeSoundingNote {
                events.append(.noteOff(active))
                activeSoundingNote = nil
            }
            noteOffTick = nil
        }

        // Trigger on step boundary
        if lastTick == nil || (currentTick / stepTicks) != (lastTick! / stepTicks) {
            if let active = activeSoundingNote {
                events.append(.noteOff(active))
                activeSoundingNote = nil
            }

            let nextNote = sequence[currentStepIndex % sequence.count]
            events.append(.noteOn(nextNote, velocity: velocity))
            activeSoundingNote = nextNote
            noteOffTick = currentTick + gateTicks
            currentStepIndex = (currentStepIndex + 1) % sequence.count
        }

        lastTick = currentTick
        return events
    }

    /// Advances the engine using continuous real-time timestamps and tempo in BPM.
    public mutating func advance(
        timestamp: TimeInterval,
        tempoBPM: Double,
        velocity: UInt8 = 100
    ) -> [ArpeggiatorEvent] {
        guard !sequence.isEmpty else { return releaseAll() }

        var events: [ArpeggiatorEvent] = []
        let stepSeconds = configuration.rate.secondsPerStep(tempoBPM: tempoBPM)
        let gateSeconds = stepSeconds * configuration.gateLength

        // Check note-off
        if let offTime = noteOffTime, timestamp >= offTime {
            if let active = activeSoundingNote {
                events.append(.noteOff(active))
                activeSoundingNote = nil
            }
            noteOffTime = nil
        }

        // Check next step
        if nextStepTime == nil || timestamp >= nextStepTime! {
            if let active = activeSoundingNote {
                events.append(.noteOff(active))
                activeSoundingNote = nil
            }

            let nextNote = sequence[currentStepIndex % sequence.count]
            events.append(.noteOn(nextNote, velocity: velocity))
            activeSoundingNote = nextNote

            noteOffTime = timestamp + gateSeconds
            nextStepTime = (nextStepTime != nil) ? (nextStepTime! + stepSeconds) : (timestamp + stepSeconds)
            if nextStepTime! < timestamp {
                nextStepTime = timestamp + stepSeconds
            }
            currentStepIndex = (currentStepIndex + 1) % sequence.count
        }

        lastAdvanceTime = timestamp
        return events
    }

    /// Releases all active notes and clears state.
    public mutating func releaseAll() -> [ArpeggiatorEvent] {
        var events: [ArpeggiatorEvent] = []
        if let active = activeSoundingNote {
            events.append(.noteOff(active))
            activeSoundingNote = nil
        }
        noteOffTick = nil
        nextStepTime = nil
        noteOffTime = nil
        lastTick = nil
        return events
    }
}
