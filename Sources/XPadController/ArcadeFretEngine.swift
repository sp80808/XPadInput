import Foundation
import XPadCore

// MARK: - Arcade Frets Mode (Guitar Hero Style)

/// A chord fret lane on the controller's rear buttons. Each slot fires one diatonic
/// degree instantly on press — no strum gesture required.
public enum ArcadeFretSlot: String, CaseIterable, Codable, Sendable, Identifiable {
    /// L2 / LT — fires diatonic degree I.
    case leftTrigger
    /// L1 / LB — fires diatonic degree IV.
    case leftShoulder
    /// R1 / RB — fires diatonic degree V.
    case rightShoulder
    /// R2 / RT — fires diatonic degree vi.
    case rightTrigger

    public var id: String { rawValue }

    /// Zero-based index into the current key's diatonic chord list.
    public var diatonicDegreeIndex: Int {
        switch self {
        case .leftTrigger: return 0
        case .leftShoulder: return 3
        case .rightShoulder: return 4
        case .rightTrigger: return 5
        }
    }

    /// Guitar-Hero style colour identity used by the lane visualizer and HUD.
    public var laneColorRole: ArcadeLaneColorRole {
        switch self {
        case .leftTrigger: return .green
        case .leftShoulder: return .red
        case .rightShoulder: return .yellow
        case .rightTrigger: return .blue
        }
    }

    /// Short hardware label resolved per connected controller family at the UI layer.
    public var defaultControlLabel: String {
        switch self {
        case .leftTrigger: return "L2"
        case .leftShoulder: return "L1"
        case .rightShoulder: return "R1"
        case .rightTrigger: return "R2"
        }
    }

    public var romanNumeralLabel: String {
        switch self {
        case .leftTrigger: return "I"
        case .leftShoulder: return "IV"
        case .rightShoulder: return "V"
        case .rightTrigger: return "vi"
        }
    }
}

/// Colour roles mirroring classic five-lane rhythm-game frets (orange is reserved
/// for the wheel-selected "pick" accent in the visualizer).
public enum ArcadeLaneColorRole: String, CaseIterable, Sendable {
    case green, red, yellow, blue, orange
}

/// Chord-quality modifiers held on the face buttons while a fret is struck.
/// Mirrors the legacy shoulder/trigger quality remapping but relocated to the
/// face cluster so the rear buttons can act as pure frets.
public enum ArcadeFretModifier: String, CaseIterable, Codable, Sendable, Identifiable {
    /// ✕ / A — extend to a seventh chord.
    case seventh
    /// □ / X — suspend the third (sus4 / sus2).
    case sus
    /// △ / Y — extend to an added-ninth chord.
    case ninth
    /// ○ / B — flatten to a sixth chord colour.
    case sixth

    public var id: String { rawValue }

    /// Deterministic application order when several modifiers are held together.
    public static let priorityOrder: [ArcadeFretModifier] = [.seventh, .ninth, .sixth, .sus]

    public var displayName: String {
        switch self {
        case .seventh: return "7th"
        case .sus: return "Sus"
        case .ninth: return "Add9"
        case .sixth: return "6th"
        }
    }

    public var defaultControlLabel: String {
        switch self {
        case .seventh: return "✕"
        case .sus: return "□"
        case .ninth: return "△"
        case .sixth: return "○"
        }
    }

    /// Applies this colour to a diatonic chord quality, following the same
    /// mapping grammar as the standard performance modifier table.
    public func applied(to chord: Chord) -> Chord {
        switch (self, chord.quality) {
        case (.seventh, .major): return Chord(root: chord.root, quality: .major7)
        case (.seventh, .minor): return Chord(root: chord.root, quality: .minor7)
        case (.seventh, .diminished): return Chord(root: chord.root, quality: .halfDiminished7)
        case (.seventh, .dominant7), (.seventh, .major7), (.seventh, .minor7):
            return chord
        case (.sus, .major): return Chord(root: chord.root, quality: .sus4)
        case (.sus, .minor): return Chord(root: chord.root, quality: .sus2)
        case (.ninth, .major): return Chord(root: chord.root, quality: .add9)
        case (.ninth, .minor): return Chord(root: chord.root, quality: .minor9)
        case (.sixth, .major): return Chord(root: chord.root, quality: .sixth)
        case (.sixth, .minor): return Chord(root: chord.root, quality: .minorSixth)
        default: return chord
        }
    }
}

/// Immutable hardware snapshot consumed by `ArcadeFretEngine`. Plain values keep
/// the engine pure and unit-testable without instantiating observable state.
public struct ArcadeFretInput: Sendable, Equatable {
    public var leftTriggerValue: Float
    public var rightTriggerValue: Float
    public var leftShoulderPressed: Bool
    public var rightShoulderPressed: Bool
    public var southPressed: Bool
    public var westPressed: Bool
    public var northPressed: Bool
    public var eastPressed: Bool

    public init(
        leftTriggerValue: Float = 0,
        rightTriggerValue: Float = 0,
        leftShoulderPressed: Bool = false,
        rightShoulderPressed: Bool = false,
        southPressed: Bool = false,
        westPressed: Bool = false,
        northPressed: Bool = false,
        eastPressed: Bool = false
    ) {
        self.leftTriggerValue = leftTriggerValue
        self.rightTriggerValue = rightTriggerValue
        self.leftShoulderPressed = leftShoulderPressed
        self.rightShoulderPressed = rightShoulderPressed
        self.southPressed = southPressed
        self.westPressed = westPressed
        self.northPressed = northPressed
        self.eastPressed = eastPressed
    }

    public static let neutral = ArcadeFretInput()
}

/// One instant chord strike produced by a rising fret edge.
public struct ArcadeFretStrike: Sendable, Equatable {
    public let slot: ArcadeFretSlot
    public let chord: Chord
    public let velocity: UInt8
    /// Modifiers that actually changed the diatonic chord quality.
    public let appliedModifiers: [ArcadeFretModifier]

    public init(slot: ArcadeFretSlot, chord: Chord, velocity: UInt8, appliedModifiers: [ArcadeFretModifier]) {
        self.slot = slot
        self.chord = chord
        self.velocity = velocity
        self.appliedModifiers = appliedModifiers
    }
}

/// Per-frame output of the arcade fret lane.
public struct ArcadeFretFrame: Sendable, Equatable {
    public var strikes: [ArcadeFretStrike]
    public var releases: [ArcadeFretSlot]
    public var heldSlots: Set<ArcadeFretSlot>
    /// True whenever at least one fret is physically held — drives the chord gate.
    public var isLaneActive: Bool
    public var lastStrike: ArcadeFretStrike?

    public init(
        strikes: [ArcadeFretStrike] = [],
        releases: [ArcadeFretSlot] = [],
        heldSlots: Set<ArcadeFretSlot> = [],
        isLaneActive: Bool = false,
        lastStrike: ArcadeFretStrike? = nil
    ) {
        self.strikes = strikes
        self.releases = releases
        self.heldSlots = heldSlots
        self.isLaneActive = isLaneActive
        self.lastStrike = lastStrike
    }

    public static let empty = ArcadeFretFrame()
}

/// Guitar Hero-style chord lane engine: rear buttons fire diatonic chords the
/// instant they are pressed (no strumming), face buttons colour the quality.
///
/// The engine is a pure edge detector. Voice ownership, MIDI dispatch, and the
/// chord gate remain the host application's responsibility.
public struct ArcadeFretEngine: Sendable {
    /// Analog trigger depth mapped to MIDI velocity range when striking trigger frets.
    public static let velocityFloor: UInt8 = 54
    public static let velocityCeiling: UInt8 = 127
    /// Fixed strike velocity for digital bumper frets.
    public static let bumperVelocity: UInt8 = 100
    /// Trigger travel past which a trigger fret counts as pressed.
    public static let triggerPressThreshold: Float = 0.30
    /// Trigger travel below which a latched fret releases; travel between this
    /// and the press threshold is a hysteresis band that cannot double-fire.
    public static let triggerReleaseThreshold: Float = 0.22

    private var previousPressed: [ArcadeFretSlot: Bool] = [:]
    private var latchedTriggers: Set<ArcadeFretSlot> = []
    private var lastStrike: ArcadeFretStrike?

    public init() {}

    /// Clears all edge history so the next frame treats every control as fresh.
    public mutating func reset() {
        previousPressed.removeAll()
        latchedTriggers.removeAll()
        lastStrike = nil
    }

    public var cachedLastStrike: ArcadeFretStrike? { lastStrike }

    /// Evaluates one controller frame against the current diatonic chord set.
    public mutating func process(
        input: ArcadeFretInput,
        chords: [Chord],
        timestamp: TimeInterval
    ) -> ArcadeFretFrame {
        var strikes: [ArcadeFretStrike] = []
        var releases: [ArcadeFretSlot] = []
        var held: Set<ArcadeFretSlot> = []

        let modifiers = activeModifiers(input: input)

        for slot in ArcadeFretSlot.allCases {
            let pressed = resolvePressed(slot, input: input)
            let wasPressed = previousPressed[slot] ?? false
            previousPressed[slot] = pressed

            if pressed { held.insert(slot) }

            if pressed && !wasPressed {
                if let strike = makeStrike(slot: slot, input: input, chords: chords, modifiers: modifiers) {
                    strikes.append(strike)
                    lastStrike = strike
                }
            } else if !pressed && wasPressed {
                releases.append(slot)
            }
        }

        return ArcadeFretFrame(
            strikes: strikes,
            releases: releases,
            heldSlots: held,
            isLaneActive: !held.isEmpty,
            lastStrike: lastStrike
        )
    }

    // MARK: - Internals

    private mutating func resolvePressed(_ slot: ArcadeFretSlot, input: ArcadeFretInput) -> Bool {
        switch slot {
        case .leftTrigger:
            return updateTriggerLatch(.leftTrigger, value: input.leftTriggerValue)
        case .rightTrigger:
            return updateTriggerLatch(.rightTrigger, value: input.rightTriggerValue)
        case .leftShoulder:
            return input.leftShoulderPressed
        case .rightShoulder:
            return input.rightShoulderPressed
        }
    }

    /// Schmitt trigger per analog fret: crossing the press threshold latches the
    /// slot on, dropping below the release threshold unlatches it, and travel
    /// inside the band leaves the latch untouched so jitter cannot re-edge.
    private mutating func updateTriggerLatch(_ slot: ArcadeFretSlot, value: Float) -> Bool {
        if value >= Self.triggerPressThreshold {
            latchedTriggers.insert(slot)
        } else if value < Self.triggerReleaseThreshold {
            latchedTriggers.remove(slot)
        }
        return latchedTriggers.contains(slot)
    }

    private func activeModifiers(input: ArcadeFretInput) -> [ArcadeFretModifier] {
        var held: [ArcadeFretModifier] = []
        if input.southPressed { held.append(.seventh) }
        if input.westPressed { held.append(.sus) }
        if input.northPressed { held.append(.ninth) }
        if input.eastPressed { held.append(.sixth) }
        return held.sorted {
            Self.modifierPriority($0) < Self.modifierPriority($1)
        }
    }

    private static func modifierPriority(_ modifier: ArcadeFretModifier) -> Int {
        ArcadeFretModifier.priorityOrder.firstIndex(of: modifier) ?? .max
    }

    private func makeStrike(
        slot: ArcadeFretSlot,
        input: ArcadeFretInput,
        chords: [Chord],
        modifiers: [ArcadeFretModifier]
    ) -> ArcadeFretStrike? {
        let index = slot.diatonicDegreeIndex
        guard chords.indices.contains(index) else { return nil }
        let diatonic = chords[index]

        var chord = diatonic
        var applied: [ArcadeFretModifier] = []
        for modifier in modifiers {
            let coloured = modifier.applied(to: chord)
            if coloured != chord {
                chord = coloured
                applied.append(modifier)
            }
        }

        return ArcadeFretStrike(
            slot: slot,
            chord: chord,
            velocity: velocity(for: slot, input: input),
            appliedModifiers: applied
        )
    }

    private func velocity(for slot: ArcadeFretSlot, input: ArcadeFretInput) -> UInt8 {
        switch slot {
        case .leftTrigger:
            return scaledVelocity(input.leftTriggerValue)
        case .rightTrigger:
            return scaledVelocity(input.rightTriggerValue)
        case .leftShoulder, .rightShoulder:
            return Self.bumperVelocity
        }
    }

    private func scaledVelocity(_ depth: Float) -> UInt8 {
        let clamped = max(0, min(1, depth))
        let span = Float(Self.velocityCeiling - Self.velocityFloor)
        return UInt8(clamping: Int(Self.velocityFloor) + Int(clamped * span))
    }
}
