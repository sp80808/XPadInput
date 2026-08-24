import Foundation
import XPadCore

// MARK: - Tutorial Gesture Model

/// Observable controller gesture that completes a tutorial step.
/// Gestures resolve against the active `ControlScheme` so hints and detection
/// always reference the physical control the musician actually mapped.
public enum TutorialGesture: Sendable, Equatable {
    /// Sweep strum excitation with at least the given stick velocity.
    case strumSweep(minVelocity: Float)
    /// Hold the control bound to `action` above `threshold` for `duration` seconds.
    case pressureHold(action: SemanticMusicalAction, threshold: Float, duration: TimeInterval)
    /// Press the face button bound to a chord-tone voice degree.
    case pluckVoice(degree: VoiceDegreeSlot)
    /// Deflect the harmonic navigation stick beyond `radius`.
    case navigateHarmony(radius: Float)
    /// Tap an octave shift control.
    case shiftOctave(direction: OctaveShiftDirection)
    /// Press the control bound to `action` (momentary press, rising edge).
    case pressControl(action: SemanticMusicalAction)
    /// Tilt the controller beyond `degrees` on the given axis.
    case tiltMotion(axis: MotionAxis, degrees: Double)

    public enum VoiceDegreeSlot: String, Sendable, CaseIterable {
        case root
        case third
        case fifth
        case seventh

        public var action: SemanticMusicalAction {
            switch self {
            case .root: return .voiceDegree1
            case .third: return .voiceDegree3
            case .fifth: return .voiceDegree5
            case .seventh: return .voiceDegree7
            }
        }
    }

    public enum OctaveShiftDirection: String, Sendable {
        case up
        case down
        case any
    }

    public enum MotionAxis: String, Sendable {
        case pitch
        case roll
    }
}

// MARK: - Step & Mission Models

public struct TutorialStep: Identifiable, Sendable, Equatable {
    public let id: String
    /// Human instruction. `%@` (if present) is replaced by the scheme-resolved control name.
    public let instruction: String
    public let gesture: TutorialGesture

    public init(id: String, instruction: String, gesture: TutorialGesture) {
        self.id = id
        self.instruction = instruction
        self.gesture = gesture
    }
}

public struct TutorialMission: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let summary: String
    public let steps: [TutorialStep]

    public init(id: String, title: String, summary: String, steps: [TutorialStep]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.steps = steps
    }
}

// MARK: - Progress Reporting

public struct TutorialProgress: Sendable, Equatable {
    public let missionID: String?
    public let currentStepIndex: Int
    public let totalSteps: Int
    public let completedSteps: [CompletedStep]
    public let isMissionComplete: Bool
    /// True on the exact frame a step was completed.
    public let stepJustCompleted: Bool
    /// Scheme-resolved hint for the active step (names the physical control).
    public let activeStepHint: String?

    public struct CompletedStep: Sendable, Equatable {
        public let stepID: String
        public let completedAt: TimeInterval
    }

    /// Fraction of steps completed (0…1).
    public var fractionCompleted: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps.count) / Double(totalSteps)
    }

    public static let empty = TutorialProgress(
        missionID: nil,
        currentStepIndex: 0,
        totalSteps: 0,
        completedSteps: [],
        isMissionComplete: false,
        stepJustCompleted: false,
        activeStepHint: nil
    )
}

// MARK: - Engine

/// Input-driven interactive tutorial engine.
///
/// Consumes processed `ControllerState` frames from the same pipeline as
/// `AppState.handleControllerInput`, validates gesture predicates sequentially,
/// and reports per-step completion with timestamps. Thread-safe via `NSLock`;
/// contains no UI or audio dependencies.
public final class TutorialEngine: @unchecked Sendable {

    private let lock = NSLock()
    private var scheme: ControlScheme
    private var mission: TutorialMission?
    private var currentStepIndex: Int = 0
    private var completedSteps: [TutorialProgress.CompletedStep] = []
    private var missionComplete: Bool = false

    // Per-frame gesture accumulators
    private var pressureHoldElapsed: TimeInterval = 0
    private var lastTimestamp: TimeInterval = 0
    private var previousDigitalStates: [PhysicalControlInput: Bool] = [:]

    /// Fired once when the loaded mission's final step completes.
    public var onMissionComplete: (() -> Void)?

    public init(scheme: ControlScheme = ControlSchemePreset.xpiPerformance) {
        self.scheme = scheme
    }

    // MARK: Configuration

    public func updateScheme(_ newScheme: ControlScheme) {
        lock.lock()
        defer { lock.unlock() }
        scheme = newScheme
    }

    public func load(mission newMission: TutorialMission) {
        lock.lock()
        defer { lock.unlock() }
        mission = newMission
        resetAccumulatorsLocked()
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        resetAccumulatorsLocked()
    }

    // MARK: Frame Processing

    /// Feed one processed controller frame. Returns current progress; inspect
    /// `stepJustCompleted` / `isMissionComplete` for transitions.
    @discardableResult
    public func process(state: ControllerState, timestamp: TimeInterval) -> TutorialProgress {
        lock.lock()
        defer { lock.unlock() }

        guard let activeMission = mission, !missionComplete,
              currentStepIndex < activeMission.steps.count else {
            return snapshotLocked(stepJustCompleted: false)
        }

        let delta = max(0, timestamp - lastTimestamp)
        lastTimestamp = timestamp

        let step = activeMission.steps[currentStepIndex]
        if evaluate(step.gesture, state: state, delta: delta) {
            completedSteps.append(.init(stepID: step.id, completedAt: timestamp))
            currentStepIndex += 1
            pressureHoldElapsed = 0

            if currentStepIndex >= activeMission.steps.count {
                missionComplete = true
                let handler = onMissionComplete
                DispatchQueue.main.async { handler?() }
            }
            return snapshotLocked(stepJustCompleted: true)
        }
        return snapshotLocked(stepJustCompleted: false)
    }

    // MARK: Gesture Evaluation (lock held)

    private func evaluate(_ gesture: TutorialGesture, state: ControllerState, delta: TimeInterval) -> Bool {
        switch gesture {
        case .strumSweep(let minVelocity):
            return evaluateStrumSweep(minVelocity: minVelocity, state: state)

        case .pressureHold(let action, let threshold, let duration):
            guard let input = scheme.binding(for: action)?.input, input != .unassigned else { return false }
            let value = abs(analogValue(for: input, in: state))
            if value >= threshold {
                pressureHoldElapsed += delta
            } else {
                pressureHoldElapsed = 0
            }
            return pressureHoldElapsed >= duration

        case .pluckVoice(let slot):
            guard let input = scheme.binding(for: slot.action)?.input, input != .unassigned else { return false }
            return roseEdge(input, state: state)

        case .navigateHarmony(let radius):
            guard let input = scheme.binding(for: .harmonyNavigate2D)?.input, input != .unassigned else { return false }
            return stickRadius(for: input, in: state) >= radius

        case .shiftOctave(let direction):
            let inputs: [(SemanticMusicalAction, TutorialGesture.OctaveShiftDirection)] = [
                (.octaveUp, .up), (.octaveDown, .down)
            ]
            for (action, dir) in inputs where direction == .any || direction == dir {
                if let input = scheme.binding(for: action)?.input, input != .unassigned,
                   roseEdge(input, state: state) {
                    return true
                }
            }
            return false

        case .pressControl(let action):
            guard let input = scheme.binding(for: action)?.input, input != .unassigned else { return false }
            return roseEdge(input, state: state)

        case .tiltMotion(let axis, let degrees):
            guard scheme.isMotionEnabled else { return false }
            switch axis {
            case .pitch: return abs(state.pitchTilt) >= degrees && state.hasMotion
            case .roll: return abs(state.rollTilt) >= degrees && state.hasMotion
            }
        }
    }

    private func evaluateStrumSweep(minVelocity: Float, state: ControllerState) -> Bool {
        // Prefer the excitation-bound stick axis; fall back to right stick Y.
        var candidates: [PhysicalControlInput] = []
        if let bound = scheme.binding(for: .primaryExcitation)?.input, bound != .unassigned {
            candidates.append(bound)
        }
        candidates.append(.rightStickY)

        for input in candidates {
            switch input {
            case .rightStickY:
                if abs(state.rightStick.yVelocity) >= minVelocity { return true }
            case .leftStickY:
                if abs(state.leftStick.yVelocity) >= minVelocity { return true }
            case .rightStickX:
                if abs(state.rightStick.xVelocity) >= minVelocity { return true }
            case .leftStickX:
                if abs(state.leftStick.xVelocity) >= minVelocity { return true }
            case .rightTrigger, .leftTrigger:
                // Trigger-strum schemes complete via attack velocity of the pull.
                let trigger = input == .rightTrigger ? state.rightTrigger : state.leftTrigger
                if trigger.attackVelocity >= minVelocity { return true }
            default:
                break
            }
        }
        return false
    }

    // MARK: Input Reading Helpers (mirror ControlSurfaceResolver mapping)

    private func analogValue(for input: PhysicalControlInput, in state: ControllerState) -> Float {
        switch input {
        case .leftStickX: return state.leftStick.x
        case .leftStickY: return state.leftStick.y
        case .rightStickX: return state.rightStick.x
        case .rightStickY: return state.rightStick.y
        case .leftStick2D: return Float(state.leftStickMagnitude)
        case .rightStick2D: return Float(state.rightStickMagnitude)
        case .leftTrigger: return state.leftTrigger.value
        case .rightTrigger: return state.rightTrigger.value
        case .motionPitch: return Float(state.pitchTilt / 90.0)
        case .motionRoll: return Float(state.rollTilt / 90.0)
        case .touchpad2D: return state.touchpadX
        default: return isDigitalPressed(input, state: state) ? 1 : 0
        }
    }

    private func stickRadius(for input: PhysicalControlInput, in state: ControllerState) -> Float {
        switch input {
        case .leftStick2D, .leftStickX, .leftStickY:
            return state.leftStick.radius
        case .rightStick2D, .rightStickX, .rightStickY:
            return state.rightStick.radius
        default:
            return abs(analogValue(for: input, in: state))
        }
    }

    private func isDigitalPressed(_ input: PhysicalControlInput, state: ControllerState) -> Bool {
        switch input {
        case .buttonSouth: return state.buttonA
        case .buttonEast: return state.buttonB
        case .buttonWest: return state.buttonX
        case .buttonNorth: return state.buttonY
        case .dpadUp: return state.dpadUp
        case .dpadDown: return state.dpadDown
        case .dpadLeft: return state.dpadLeft
        case .dpadRight: return state.dpadRight
        case .leftShoulder: return state.leftShoulder
        case .rightShoulder: return state.rightShoulder
        case .leftStickClick: return state.leftStickButton
        case .rightStickClick: return state.rightStickButton
        case .buttonOptions: return state.optionsButton
        case .buttonShare: return state.menuButton
        case .buttonCenter: return state.touchpadActive
        default:
            return abs(analogValue(for: input, in: state)) > 0.5
        }
    }

    /// Rising-edge detection for digital controls.
    private func roseEdge(_ input: PhysicalControlInput, state: ControllerState) -> Bool {
        let pressed = isDigitalPressed(input, state: state)
        let previous = previousDigitalStates[input] ?? false
        previousDigitalStates[input] = pressed
        return pressed && !previous
    }

    // MARK: Hints & Snapshot

    /// Scheme-aware copy naming the physical control for a gesture.
    public static func hint(for gesture: TutorialGesture, scheme: ControlScheme) -> String {
        TutorialEngine(scheme: scheme).resolvedHint(for: gesture)
    }

    /// Scheme-aware copy naming the physical control for a gesture.
    public func resolvedHint(for gesture: TutorialGesture) -> String {
        lock.lock()
        defer { lock.unlock() }
        return hintLocked(for: gesture)
    }

    private func hintLocked(for gesture: TutorialGesture) -> String {
        func controlName(for action: SemanticMusicalAction) -> String {
            guard let binding = scheme.binding(for: action), binding.input != .unassigned else {
                return "unmapped"
            }
            if let role = scheme.roleLabel(for: binding.input) {
                return "\(binding.input.rawValue) — \(role)"
            }
            return binding.input.rawValue
        }

        switch gesture {
        case .strumSweep:
            return controlName(for: .primaryExcitation)
        case .pressureHold(let action, _, _):
            return controlName(for: action)
        case .pluckVoice(let slot):
            return controlName(for: slot.action)
        case .navigateHarmony:
            return controlName(for: .harmonyNavigate2D)
        case .shiftOctave(let direction):
            switch direction {
            case .up: return controlName(for: .octaveUp)
            case .down: return controlName(for: .octaveDown)
            case .any: return "\(controlName(for: .octaveUp)) / \(controlName(for: .octaveDown))"
            }
        case .pressControl(let action):
            return controlName(for: action)
        case .tiltMotion(let axis, _):
            return axis == .pitch ? "Controller tilt (pitch axis)" : "Controller tilt (roll axis)"
        }
    }

    private func snapshotLocked(stepJustCompleted: Bool) -> TutorialProgress {
        let hint: String?
        if let activeMission = mission, !missionComplete, currentStepIndex < activeMission.steps.count {
            hint = hintLocked(for: activeMission.steps[currentStepIndex].gesture)
        } else {
            hint = nil
        }
        return TutorialProgress(
            missionID: mission?.id,
            currentStepIndex: currentStepIndex,
            totalSteps: mission?.steps.count ?? 0,
            completedSteps: completedSteps,
            isMissionComplete: missionComplete,
            stepJustCompleted: stepJustCompleted,
            activeStepHint: hint
        )
    }

    private func resetAccumulatorsLocked() {
        currentStepIndex = 0
        completedSteps = []
        missionComplete = false
        pressureHoldElapsed = 0
        lastTimestamp = 0
        previousDigitalStates = [:]
    }

    public var currentProgress: TutorialProgress {
        lock.lock()
        defer { lock.unlock() }
        return snapshotLocked(stepJustCompleted: false)
    }
}

// MARK: - Factory Missions

extension TutorialMission {
    /// Guided missions covering the core XPI playing techniques. Every step is
    /// validated against real controller input through `TutorialEngine`.
    public static func factoryPresets() -> [TutorialMission] {
        [
            TutorialMission(
                id: "first_strum",
                title: "First Strum",
                summary: "Pick a chord and play it — the essential three-step loop.",
                steps: [
                    TutorialStep(
                        id: "fs_navigate",
                        instruction: "Push %@ to choose a chord",
                        gesture: .navigateHarmony(radius: 0.45)
                    ),
                    TutorialStep(
                        id: "fs_strum",
                        instruction: "Flick %@ to strum the chord",
                        gesture: .strumSweep(minVelocity: 1.2)
                    ),
                    TutorialStep(
                        id: "fs_pluck",
                        instruction: "Tap %@ to pluck the root note",
                        gesture: .pluckVoice(degree: .root)
                    )
                ]
            ),
            TutorialMission(
                id: "mpe_expression",
                title: "MPE Expression",
                summary: "Bring notes to life with per-note pressure and motion.",
                steps: [
                    TutorialStep(
                        id: "mpe_pressure",
                        instruction: "Hold %@ past halfway to swell note pressure",
                        gesture: .pressureHold(action: .pressureExpression, threshold: 0.55, duration: 0.6)
                    ),
                    TutorialStep(
                        id: "mpe_tilt",
                        instruction: "Tilt the controller forward to bend pitch",
                        gesture: .tiltMotion(axis: .pitch, degrees: 12)
                    ),
                    TutorialStep(
                        id: "mpe_damp",
                        instruction: "Ease %@ to damp and release cleanly",
                        gesture: .pressureHold(action: .dampingExpression, threshold: 0.3, duration: 0.4)
                    )
                ]
            ),
            TutorialMission(
                id: "harmony_navigation",
                title: "Harmony Navigation",
                summary: "Steer the harmonic wheel and shift registers.",
                steps: [
                    TutorialStep(
                        id: "hn_navigate",
                        instruction: "Circle %@ around its rim to browse chords",
                        gesture: .navigateHarmony(radius: 0.7)
                    ),
                    TutorialStep(
                        id: "hn_octave_up",
                        instruction: "Tap %@ to shift up an octave",
                        gesture: .shiftOctave(direction: .up)
                    ),
                    TutorialStep(
                        id: "hn_octave_down",
                        instruction: "Now tap %@ to come back down",
                        gesture: .shiftOctave(direction: .down)
                    )
                ]
            ),
            TutorialMission(
                id: "drum_fingers",
                title: "Drum Fingers",
                summary: "Finger-drumming: fire chord tones as percussion lanes.",
                steps: [
                    TutorialStep(
                        id: "df_kick",
                        instruction: "Hit %@ like a kick drum",
                        gesture: .pluckVoice(degree: .root)
                    ),
                    TutorialStep(
                        id: "df_snare",
                        instruction: "Answer with %@ on the offbeat",
                        gesture: .pluckVoice(degree: .third)
                    ),
                    TutorialStep(
                        id: "df_choke",
                        instruction: "Grab %@ briefly to choke the ring",
                        gesture: .pressureHold(action: .dampingExpression, threshold: 0.4, duration: 0.25)
                    )
                ]
            ),
            TutorialMission(
                id: "sustain_technique",
                title: "Sustain & Technique",
                summary: "Latch sustains and arm technique modifiers.",
                steps: [
                    TutorialStep(
                        id: "st_strum",
                        instruction: "Strum once with %@",
                        gesture: .strumSweep(minVelocity: 1.0)
                    ),
                    TutorialStep(
                        id: "st_sustain",
                        instruction: "Latch %@ to let it ring",
                        gesture: .pressControl(action: .sustainLatch)
                    ),
                    TutorialStep(
                        id: "st_pluck_high",
                        instruction: "Sparkle on top with %@",
                        gesture: .pluckVoice(degree: .fifth)
                    )
                ]
            )
        ]
    }
}
