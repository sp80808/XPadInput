import Foundation
import XPadCore

/// Deterministic state machine for momentary, timed, and latched chord release.
public struct ChordGateEngine: Sendable {
    public private(set) var configuration: ChordGateConfiguration
    public private(set) var activeVoice: ChordGateVoice?

    private var previousGestureActive = false
    private var releaseDeadline: TimeInterval?

    public init(configuration: ChordGateConfiguration = ChordGateConfiguration()) {
        self.configuration = configuration
    }

    /// Processes the current gesture level. Only rising/falling edges emit events.
    /// Call this on each controller frame so timed releases can also be delivered.
    public mutating func process(
        voice: ChordGateVoice?,
        isGestureActive: Bool,
        timestamp: TimeInterval
    ) -> [ChordGateEvent] {
        var events = advance(timestamp: timestamp)
        let risingEdge = isGestureActive && !previousGestureActive
        let fallingEdge = !isGestureActive && previousGestureActive
        previousGestureActive = isGestureActive

        switch configuration.mode {
        case .momentary:
            if risingEdge, let voice, !voice.notes.isEmpty {
                replaceActiveVoice(with: voice, events: &events)
            } else if fallingEdge {
                endActiveVoice(events: &events)
            }

        case .timed:
            if risingEdge, let voice, !voice.notes.isEmpty {
                replaceActiveVoice(with: voice, events: &events, retriggerMatchingVoice: true)
                releaseDeadline = timestamp + configuration.timedDuration
            }

        case .latch:
            if risingEdge, let voice, !voice.notes.isEmpty {
                if activeVoice == voice {
                    endActiveVoice(events: &events)
                } else {
                    replaceActiveVoice(with: voice, events: &events)
                }
            }
        }

        return events
    }

    /// Emits an elapsed timed release even when no new controller edge occurred.
    public mutating func advance(timestamp: TimeInterval) -> [ChordGateEvent] {
        guard configuration.mode == .timed,
              let releaseDeadline,
              timestamp >= releaseDeadline else {
            return []
        }

        var events: [ChordGateEvent] = []
        endActiveVoice(events: &events)
        return events
    }

    /// Applies new user settings and safely releases any voice owned by the old mode.
    @discardableResult
    public mutating func updateConfiguration(_ configuration: ChordGateConfiguration) -> [ChordGateEvent] {
        guard self.configuration != configuration else { return [] }
        var events: [ChordGateEvent] = []
        endActiveVoice(events: &events)
        self.configuration = configuration
        previousGestureActive = false
        return events
    }

    /// Ends the currently owned chord and clears gesture-edge state.
    @discardableResult
    public mutating func releaseAll() -> [ChordGateEvent] {
        var events: [ChordGateEvent] = []
        endActiveVoice(events: &events)
        previousGestureActive = false
        return events
    }

    private mutating func replaceActiveVoice(
        with voice: ChordGateVoice,
        events: inout [ChordGateEvent],
        retriggerMatchingVoice: Bool = false
    ) {
        if activeVoice == voice, !retriggerMatchingVoice { return }
        endActiveVoice(events: &events)
        activeVoice = voice
        releaseDeadline = nil
        events.append(.began(voice))
    }

    private mutating func endActiveVoice(events: inout [ChordGateEvent]) {
        if let activeVoice {
            events.append(.ended(activeVoice))
        }
        activeVoice = nil
        releaseDeadline = nil
    }
}

public struct VelocityStabilizerConfiguration: Codable, Hashable, Sendable {
    public private(set) var floor: UInt8
    public private(set) var ceiling: UInt8
    /// Input contribution for the exponential moving average. `1` is immediate.
    public private(set) var smoothing: Double
    /// Maximum MIDI-velocity change allowed between consecutive attacks.
    public private(set) var maximumStep: UInt8

    public init(
        floor: UInt8 = 36,
        ceiling: UInt8 = 120,
        smoothing: Double = 0.45,
        maximumStep: UInt8 = 18
    ) {
        let safeFloor = min(127, max(1, floor))
        self.floor = safeFloor
        self.ceiling = min(127, max(safeFloor, ceiling))
        self.smoothing = smoothing.isFinite ? min(1, max(0.05, smoothing)) : 0.45
        self.maximumStep = min(127, max(1, maximumStep))
    }
}

/// Makes noisy gesture speeds musical without hiding intentional dynamic changes.
public struct VelocityStabilizer: Sendable {
    public private(set) var configuration: VelocityStabilizerConfiguration
    public private(set) var lastVelocity: UInt8?

    public init(configuration: VelocityStabilizerConfiguration = VelocityStabilizerConfiguration()) {
        self.configuration = configuration
    }

    /// Stabilizes a MIDI attack velocity. Zero remains zero and never updates attack history.
    public mutating func process(rawVelocity: UInt8) -> UInt8 {
        guard rawVelocity > 0 else { return 0 }

        let target = min(configuration.ceiling, max(configuration.floor, rawVelocity))
        guard let lastVelocity else {
            self.lastVelocity = target
            return target
        }

        let smoothed = Double(lastVelocity)
            + (Double(target) - Double(lastVelocity)) * configuration.smoothing
        let requestedDelta = Int(smoothed.rounded()) - Int(lastVelocity)
        let maximumStep = Int(configuration.maximumStep)
        let boundedDelta = min(maximumStep, max(-maximumStep, requestedDelta))
        let output = UInt8(clamping: min(
            Int(configuration.ceiling),
            max(Int(configuration.floor), Int(lastVelocity) + boundedDelta)
        ))
        self.lastVelocity = output
        return output
    }

    /// Maps normalized gesture intensity into the configured musical range before smoothing.
    public mutating func process(normalizedIntensity: Double) -> UInt8 {
        guard normalizedIntensity.isFinite, normalizedIntensity > 0 else { return 0 }
        let normalized = min(1, max(0, normalizedIntensity))
        let span = Double(configuration.ceiling - configuration.floor)
        let raw = UInt8(clamping: Int((Double(configuration.floor) + span * normalized).rounded()))
        return process(rawVelocity: raw)
    }

    /// Maps normalized gesture intensity into (7-bit, 16-bit) velocity pair.
    ///
    /// The 7-bit value is produced by the standard stabilizer pipeline (floor/ceiling
    /// clamping, smoothing, step limiting) so MIDI 1 output is unchanged.  The 16-bit
    /// value is derived from the *stabilized* normalized intensity — i.e. from the same
    /// smoothed ratio the 7-bit value encodes — rather than from a 7-bit → 16-bit
    /// bit-shift.  This preserves the sub-step precision that MIDI 2 attack velocity
    /// affords and satisfies issue #15.
    public mutating func process16(normalizedIntensity: Double) -> (velocity7: UInt8, velocity16: UInt16) {
        guard normalizedIntensity.isFinite, normalizedIntensity > 0 else { return (0, 0) }
        let normalized = min(1, max(0, normalizedIntensity))
        let span = Double(configuration.ceiling - configuration.floor)
        let rawDouble = Double(configuration.floor) + span * normalized
        let raw = UInt8(clamping: Int(rawDouble.rounded()))
        let vel7 = process(rawVelocity: raw)

        // Map the stabilized 7-bit back to a normalized ratio within [floor, ceiling]
        // and scale to the full 16-bit range so MIDI 2 attack is not just a bit-shift.
        let stabilizedNorm = span > 0
            ? max(0, min(1, (Double(vel7) - Double(configuration.floor)) / span))
            : Double(vel7) / 127.0
        let vel16 = UInt16(clamping: Int((stabilizedNorm * 65535).rounded()))
        return (vel7, vel16)
    }

    public mutating func reset() {
        lastVelocity = nil
    }

    public mutating func updateConfiguration(_ configuration: VelocityStabilizerConfiguration) {
        self.configuration = configuration
        if let lastVelocity {
            self.lastVelocity = min(configuration.ceiling, max(configuration.floor, lastVelocity))
        }
    }
}

public struct DuoStickGesture: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var magnitude: Double
    public var movementVelocity: Double

    public var isActive: Bool { magnitude > 0.001 }

    init(_ stick: ProcessedStickState) {
        let rawX = Double(stick.x)
        let rawY = Double(stick.y)
        let rawMagnitude = hypot(rawX, rawY)
        let scale = rawMagnitude > 1 ? 1 / rawMagnitude : 1
        x = rawX * scale
        y = rawY * scale
        magnitude = min(1, rawMagnitude)
        movementVelocity = max(0, Double(stick.movementVelocity))
    }
}

public struct DuoDrumHit: Equatable, Sendable {
    public var voice: DuoDrumVoice
    public var velocity: UInt8

    public init(voice: DuoDrumVoice, velocity: UInt8) {
        self.voice = voice
        self.velocity = velocity
    }
}

/// One collision-free frame: sticks remain pitched-instrument controls, face edges are drums.
public struct DuoControlFrame: Equatable, Sendable {
    public var mode: DuoPerformanceMode
    public var chordSelection: DuoStickGesture
    public var instrumentGesture: DuoStickGesture
    public var drumHits: [DuoDrumHit]

    /// AppState should skip face-button note interpretation when this is true.
    public var suppressesInstrumentFaceButtons: Bool {
        mode == .drumsAndInstrument
    }
}

public struct DuoControlEngine: Sendable {
    public private(set) var mode: DuoPerformanceMode
    public private(set) var scheme: DuoControlScheme
    public var drumVelocityStabilizer: VelocityStabilizer

    private var previousButtons: (south: Bool, west: Bool, north: Bool, east: Bool)

    public init(
        mode: DuoPerformanceMode = .instrumentOnly,
        scheme: DuoControlScheme = .standard,
        drumVelocityStabilizer: VelocityStabilizer = VelocityStabilizer()
    ) {
        self.mode = mode
        self.scheme = scheme
        self.drumVelocityStabilizer = drumVelocityStabilizer
        self.previousButtons = (false, false, false, false)
    }

    public mutating func setMode(_ mode: DuoPerformanceMode) {
        self.mode = mode
    }

    public mutating func setScheme(_ scheme: DuoControlScheme) {
        self.scheme = scheme
    }

    /// Processes controller state using geometric face positions:
    /// A/south kick, X/west snare, Y/north closed hat, B/east open hat.
    public mutating func process(
        state: ControllerState,
        drumVelocity: UInt8 = 96
    ) -> DuoControlFrame {
        let buttons = (
            south: state.buttonA,
            west: state.buttonX,
            north: state.buttonY,
            east: state.buttonB
        )

        var hits: [DuoDrumHit] = []
        if mode == .drumsAndInstrument {
            let edges: [(DuoFaceButton, Bool)] = [
                (.south, buttons.south && !previousButtons.south),
                (.west, buttons.west && !previousButtons.west),
                (.north, buttons.north && !previousButtons.north),
                (.east, buttons.east && !previousButtons.east)
            ]
            let risingVoices = edges.compactMap { button, isRising in
                isRising ? scheme.drumVoice(for: button) : nil
            }
            if !risingVoices.isEmpty {
                let stableVelocity = drumVelocityStabilizer.process(rawVelocity: drumVelocity)
                hits = risingVoices.map { DuoDrumHit(voice: $0, velocity: stableVelocity) }
            }
        }

        previousButtons = buttons
        return DuoControlFrame(
            mode: mode,
            chordSelection: DuoStickGesture(state.leftStick),
            instrumentGesture: DuoStickGesture(state.rightStick),
            drumHits: hits
        )
    }
}
