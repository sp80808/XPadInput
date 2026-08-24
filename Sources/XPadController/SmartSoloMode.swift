import Foundation
import XPadCore
import XPadTheory

// MARK: - Smart Solo Telemetry & State

public struct SmartSoloTelemetry: Sendable, Equatable {
    public var isActive: Bool
    public var currentTarget: SoloTargetResolution?
    public var activeQuadrant: SoloPolarQuadrant?
    public var lastArticulatedNote: Note?
    public var stickRadius: Double
    public var stickAngle: Double
    public var statusDescription: String

    public init(
        isActive: Bool = false,
        currentTarget: SoloTargetResolution? = nil,
        activeQuadrant: SoloPolarQuadrant? = nil,
        lastArticulatedNote: Note? = nil,
        stickRadius: Double = 0.0,
        stickAngle: Double = 0.0,
        statusDescription: String = "Solo Idle"
    ) {
        self.isActive = isActive
        self.currentTarget = currentTarget
        self.activeQuadrant = activeQuadrant
        self.lastArticulatedNote = lastArticulatedNote
        self.stickRadius = stickRadius
        self.stickAngle = stickAngle
        self.statusDescription = statusDescription
    }
}

// MARK: - Smart Solo Engine Coordinator

public final class SmartSoloEngine: @unchecked Sendable {
    public var soloTheory = VoiceLedSoloEngine()
    public var isSoloModeEnabled: Bool = true

    public private(set) var telemetry = SmartSoloTelemetry()
    private var lastActiveNote: Note?
    private var lastStrikeTimestamp: TimeInterval = 0.0
    private var previousRadius: Double = 0.0
    private var previousAngle: Double = 0.0

    public init() {}

    /// Processes real-time right stick coordinates and determines if a solo note should be articulated or voice-led.
    public func process(
        stick: StickCoordinates,
        movementVelocity: Double,
        context: MusicalContext,
        timestamp: TimeInterval
    ) -> (event: InstrumentPerformanceEvent?, noteOn: Note?, noteOff: Note?) {
        guard isSoloModeEnabled else {
            if let last = lastActiveNote {
                lastActiveNote = nil
                telemetry = SmartSoloTelemetry(statusDescription: "Solo Disabled")
                return (nil, nil, last)
            }
            return (nil, nil, nil)
        }

        let radius = stick.radius
        let angle = stick.angle

        // Check if stick exited deadzone into active solo zone
        if radius > 0.15 {
            let resolution = soloTheory.evaluateStick(
                stickX: stick.x,
                stickY: stick.y,
                radius: radius,
                angle: angle,
                velocity: movementVelocity,
                context: context,
                previousTarget: lastActiveNote
            )

            let quadrant = soloTheory.polarQuadrant(for: angle)
            var deltaAngle = abs(angle - previousAngle)
            if deltaAngle > .pi {
                deltaAngle = (2.0 * .pi) - deltaAngle
            }
            let isNewStrike = previousRadius <= 0.15 || (deltaAngle > 0.45 && timestamp - lastStrikeTimestamp > 0.12)

            telemetry = SmartSoloTelemetry(
                isActive: true,
                currentTarget: resolution,
                activeQuadrant: quadrant,
                lastArticulatedNote: resolution.targetNote,
                stickRadius: radius,
                stickAngle: angle,
                statusDescription: "\(resolution.roleLabel) · \(resolution.theoryExplanation)"
            )

            previousRadius = radius
            previousAngle = angle

            if isNewStrike || lastActiveNote?.midiNote != resolution.targetNote.midiNote {
                let noteOff = lastActiveNote
                lastActiveNote = resolution.targetNote
                lastStrikeTimestamp = timestamp

                let technique: MusicalTechnique
                switch resolution.articulation {
                case .bluesFlourish: technique = .graceNote
                case .graceNote: technique = .hammerOn
                case .screamingBend: technique = .bend
                default: technique = .normal
                }

                let perfEvent = InstrumentPerformanceEvent(
                    note: resolution.targetNote,
                    targetNote: resolution.approachPath.last,
                    technique: technique,
                    velocity: resolution.velocity,
                    pitchOffset: resolution.pitchBendSemitones,
                    timestamp: timestamp
                )

                return (perfEvent, resolution.targetNote, noteOff)
            }

            return (nil, nil, nil)
        } else {
            // Returned to center deadzone
            previousRadius = radius
            let noteOff = lastActiveNote
            lastActiveNote = nil

            telemetry = SmartSoloTelemetry(
                isActive: false,
                currentTarget: nil,
                activeQuadrant: nil,
                lastArticulatedNote: nil,
                stickRadius: 0.0,
                stickAngle: 0.0,
                statusDescription: "Center Deadzone (Rest)"
            )

            return (nil, nil, noteOff)
        }
    }

    /// Handles underlying chord progression movement, voice-leading active notes smoothly.
    public func handleChordChange(
        oldChord: Chord,
        newChord: Chord,
        context: MusicalContext
    ) -> (newTarget: Note, event: InstrumentPerformanceEvent)? {
        guard let active = lastActiveNote else { return nil }

        let resolution = soloTheory.resolveChordTransition(
            from: active,
            oldChord: oldChord,
            newChord: newChord,
            context: context
        )

        lastActiveNote = resolution.targetNote
        telemetry.currentTarget = resolution
        telemetry.statusDescription = resolution.theoryExplanation

        let event = InstrumentPerformanceEvent(
            note: resolution.targetNote,
            technique: .legato,
            velocity: resolution.velocity,
            timestamp: ProcessInfo.processInfo.systemUptime
        )

        return (resolution.targetNote, event)
    }

    public func reset() {
        lastActiveNote = nil
        previousRadius = 0.0
        previousAngle = 0.0
        telemetry = SmartSoloTelemetry()
    }
}
