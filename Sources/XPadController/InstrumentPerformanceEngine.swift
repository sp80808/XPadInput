import Foundation
import XPadCore
import XPadTheory

public struct ControllerHUDLabels: Sendable, Equatable {
    public var leftStick: String
    public var rightStick: String
    public var l1: String
    public var r1: String
    public var l2: String
    public var r2: String
    public var gyro: String
    public var faceA: String
    public var faceX: String
    public var faceY: String
    public var faceB: String

    public init(from mapping: GestureHUDLabels) {
        leftStick = mapping.leftStick
        rightStick = mapping.rightStick
        l1 = mapping.l1
        r1 = mapping.r1
        l2 = mapping.l2
        r2 = mapping.r2
        gyro = mapping.gyro
        faceA = mapping.faceA
        faceX = mapping.faceX
        faceY = mapping.faceY
        faceB = mapping.faceB
    }
}

public enum TechniqueVisualKind: String, Sendable {
    case none
    case bend
    case hammerOn
    case pullOff
    case slide
    case palmMute
    case pinchHarmonic
    case pressure
    case vibrato
}

public struct TechniqueVisualHint: Sendable, Equatable {
    public var kind: TechniqueVisualKind
    public var intensity: Double
    public var sourceNote: Note?
    public var targetNote: Note?
    public var bendSemitones: Double
    public var targetProximity: Double

    public init(
        kind: TechniqueVisualKind = .none,
        intensity: Double = 0,
        sourceNote: Note? = nil,
        targetNote: Note? = nil,
        bendSemitones: Double = 0,
        targetProximity: Double = 0
    ) {
        self.kind = kind
        self.intensity = intensity
        self.sourceNote = sourceNote
        self.targetNote = targetNote
        self.bendSemitones = bendSemitones
        self.targetProximity = targetProximity
    }
}

public struct FaceButtonNoteEvent: Sendable, Equatable {
    public var role: ChordToneRole
    public var note: Note
    public var isOn: Bool
    public var technique: MusicalTechnique
    public var velocity: UInt8

    public init(
        role: ChordToneRole,
        note: Note,
        isOn: Bool,
        technique: MusicalTechnique,
        velocity: UInt8
    ) {
        self.role = role
        self.note = note
        self.isOn = isOn
        self.technique = technique
        self.velocity = velocity
    }
}

public struct PerformanceFrame: Sendable {
    public var activeTechnique: MusicalTechnique
    public var instrumentStatusLabel: String
    public var hud: ControllerHUDLabels
    public var bend: PitchExpressionState
    public var pressure: PressureEnvelopeState
    public var vibrato: VibratoState
    public var slide: SlideState
    public var visual: TechniqueVisualHint
    public var hint: String?
    public var theoryExplanation: String?
    public var haptic: TechniqueHaptic?
    public var palmMuteAmount: Double
    public var timbre: Double
    public var bowSpeed: Double
    public var bowDirection: Double
    public var suppressStrum: Bool
    public var ownedGesture: RightStickOwnedGesture
    public var faceEvents: [FaceButtonNoteEvent]
    public var expressionEvents: [InstrumentPerformanceEvent]
}

/// Orchestrates gesture → technique for the active instrument profile.
public struct InstrumentPerformanceEngine: Sendable {
    public var profile: InstrumentProfile
    public var destination: DestinationCapabilityProfile
    public var settings: ExpressionSettings

    public var pitchEngine: PitchExpressionEngine
    public var pressureEngine: PressureEnvelopeEngine
    public var vibratoEngine: VibratoEngine
    public var slideEngine: SlideEngine
    public var stringModel: VirtualStringModel
    public var intervalMemory = IntervalMemory()
    public var stickOwnership = RightStickGestureOwnership()

    private var lastTimestamp: TimeInterval = 0
    private var previousFace: (a: Bool, x: Bool, y: Bool, b: Bool) = (false, false, false, false)
    private var lastMelodicNote: Note?
    private var lastMelodicTime: TimeInterval = 0
    private var preparedLowerNote: Note?
    private var hasUsedBend = false
    private var hasUsedPressure = false
    private var sustainHintShown = false
    private var lastPalmMuted = false
    private var lastPickAttackTime: TimeInterval = 0
    private var previousRightY: Float = 0

    public init(
        profile: InstrumentProfile = .guitar,
        destination: DestinationCapabilityProfile = .internalSynth,
        settings: ExpressionSettings = ExpressionSettings()
    ) {
        self.profile = profile
        self.destination = destination
        self.settings = settings
        self.pitchEngine = PitchExpressionEngine()
        self.pressureEngine = PressureEnvelopeEngine(curve: profile.defaultPressureCurve)
        self.vibratoEngine = VibratoEngine()
        self.slideEngine = SlideEngine()
        self.stringModel = profile.family == .bass ? .bassStandard() : .guitarStandard()
        pitchEngine.configure(profile: profile, destination: destination, assist: settings.pitchAssist)
        vibratoEngine.configure(profile: profile)
        stickOwnership.configure(profile: profile)
    }

    public mutating func setProfile(_ profile: InstrumentProfile) {
        self.profile = profile
        pitchEngine.configure(profile: profile, destination: destination, assist: settings.pitchAssist)
        pressureEngine.curve = profile.defaultPressureCurve
        vibratoEngine.configure(profile: profile)
        stringModel = profile.family == .bass ? .bassStandard() : .guitarStandard()
        stickOwnership.configure(profile: profile)
        stickOwnership.reset()
        pitchEngine.reset()
        pressureEngine.reset()
        vibratoEngine.reset()
        slideEngine.cancel()
    }

    public mutating func setDestination(_ destination: DestinationCapabilityProfile) {
        self.destination = destination
        pitchEngine.configure(profile: profile, destination: destination, assist: settings.pitchAssist)
    }

    public mutating func setAssist(_ assist: PitchAssistMode) {
        settings.pitchAssist = assist
        pitchEngine.assist = assist
    }

    public mutating func process(
        state: ControllerState,
        context: MusicalContext,
        heldNotes: [Note],
        timestamp: TimeInterval
    ) -> PerformanceFrame {
        let dt = lastTimestamp == 0 ? 0.008 : max(0.001, min(0.05, timestamp - lastTimestamp))
        lastTimestamp = timestamp

        let held = heldNotes.max()
        let rightX = Double(state.rightStick.x)
        let rightY = Double(state.rightStick.y)
        let notesHeld = held != nil
        stickOwnership.evaluate(x: rightX, y: rightY, notesHeld: notesHeld)
        let independentAxes = stickOwnership.policy.independentAxes
        let bendingNow = notesHeld && profile.supportsPitchBend && (
            stickOwnership.owned == .bend || independentAxes
        )

        let pickAttack = detectPickAttack(state: state, timestamp: timestamp)
        let palmMute = profile.supportsPalmMute ? Double(state.leftTrigger.value) : 0
        let rawPressure = profile.supportsAftertouch ? Double(state.rightTrigger.value) : 0

        var candidates: [MusicalTechnique] = [.normal]
        if state.rightShoulder && pickAttack && profile.supportsPinchHarmonics && heldNotes.count <= 1 {
            let strong = (heldNotes.isEmpty ? Double(state.rightStick.movementVelocity) : Double(state.rightStick.movementVelocity)) > 4.0
                || Double(state.rightStick.radius) > 0.75
            candidates.append(strong ? .pinchHarmonic : .harmonic)
        }
        if state.leftShoulder && notesHeld && profile.supportsSlides {
            candidates.append(.slideUp)
        }
        if bendingNow { candidates.append(.bend) }
        if palmMute > 0.35 { candidates.append(.palmMute) }

        let gyro = hypot(state.gyroX, hypot(state.gyroY, state.gyroZ))
        let vibrato = vibratoEngine.process(
            stickX: rightX,
            stickY: rightY,
            gyroMagnitude: gyro,
            triggerMicro: Double(state.rightTrigger.velocity),
            noteHeld: notesHeld,
            bending: bendingNow,
            dt: dt
        )
        if vibrato.isActive { candidates.append(.vibrato) }

        let pressure = pressureEngine.process(raw: rawPressure, noteHeld: notesHeld, dt: dt)
        if pressure.isActive { candidates.append(.aftertouch) }

        let slide = slideEngine.advance(dt: dt)

        let faceEvents = interpretFaceButtons(
            state: state,
            context: context,
            heldNotes: heldNotes,
            pickAttack: pickAttack,
            timestamp: timestamp
        )
        for event in faceEvents where event.isOn && event.technique.isLegatoFamily {
            candidates.append(event.technique)
        }

        let technique = TechniquePriority.resolve(candidates: candidates, profile: profile)

        let bendNote = held ?? context.currentNote
        var contextForBend = context
        contextForBend.currentNote = bendNote
        contextForBend.pitchAssist = settings.pitchAssist
        let bend = pitchEngine.process(
            stickX: bendingNow ? rightX : 0,
            heldNote: held,
            context: contextForBend,
            vibratoSemitones: vibrato.offsetSemitones,
            dt: dt
        )

        var haptic: TechniqueHaptic?
        if bend.crossedDetent { haptic = .bendDetent }
        if faceEvents.contains(where: { $0.technique == .hammerOn && $0.isOn }) { haptic = .hammerOn }
        if faceEvents.contains(where: { $0.technique == .pullOff && $0.isOn }) { haptic = .pullOff }
        if slide.arrived { haptic = .slideArrival }
        if technique == .pinchHarmonic { haptic = .pinchHarmonic }
        let palmNow = palmMute > 0.55
        if palmNow && !lastPalmMuted { haptic = .palmMuteThreshold }
        lastPalmMuted = palmNow

        var hint: String?
        if notesHeld && profile.supportsPitchBend && !hasUsedBend && !sustainHintShown {
            hint = "Move R Stick sideways to bend"
            sustainHintShown = true
        }
        if notesHeld && profile.supportsAftertouch && !hasUsedPressure && pressure.smoothed < 0.05 && hint == nil {
            hint = "Press R2 while sustaining for pressure"
        }
        if bend.isBending && abs(bend.bendSemitones) > 0.15 { hasUsedBend = true; hint = nil }
        if pressure.isActive { hasUsedPressure = true; if hint?.contains("R2") == true { hint = nil } }

        var theory: String?
        if settings.theoryAssist, let nearest = bend.nearestTarget, bend.targetProximity > 0.4 {
            let chordBit = nearest.isChordTone ? "chord \(nearest.roleLabel)" : (nearest.isScaleTone ? "scale" : "chromatic")
            theory = "Bend \(nearest.displayLabel) · \(chordBit)"
        }
        if settings.theoryAssist, let hammer = faceEvents.first(where: { $0.technique == .hammerOn && $0.isOn }) {
            theory = "Hammer-on → \(hammer.note.pitchClass.displayName)"
        }

        let status = statusLabel(technique: technique, bend: bend, pressure: pressure, slide: slide)
        let visual = visualHint(technique: technique, bend: bend, pressure: pressure, slide: slide, held: held, faceEvents: faceEvents)

        var expressionEvents: [InstrumentPerformanceEvent] = []
        if let held, (bend.isBending || vibrato.isActive || pressure.isActive || palmMute > 0.05) {
            expressionEvents.append(InstrumentPerformanceEvent(
                note: held,
                targetNote: bend.nearestTarget?.note,
                technique: technique,
                velocity: 80,
                pressure: pressure.smoothed,
                pitchOffset: bend.totalSemitones + (slide.isSliding ? slide.pitchOffset : 0),
                timbre: timbreValue(state: state, pressure: pressure),
                damping: palmMute,
                brightness: 1.0 - palmMute * 0.7,
                vibratoDepth: vibrato.depth,
                vibratoRate: vibrato.rate,
                timestamp: timestamp
            ))
        }
        for face in faceEvents where face.isOn {
            expressionEvents.append(InstrumentPerformanceEvent(
                note: face.note,
                technique: face.technique,
                velocity: face.velocity,
                pressure: pressure.smoothed,
                role: face.role,
                timestamp: timestamp
            ))
        }

        let bowSpeed = profile.supportsBowing ? Double(state.rightStick.movementVelocity) : 0
        let bowDirection = profile.supportsBowing ? rightY : 0
        let timbre = timbreValue(state: state, pressure: pressure)

        previousRightY = state.rightStick.y
        previousFace = (state.buttonA, state.buttonX, state.buttonY, state.buttonB)

        return PerformanceFrame(
            activeTechnique: technique,
            instrumentStatusLabel: status,
            hud: ControllerHUDLabels(from: profile.defaultGestureMapping),
            bend: bend,
            pressure: pressure,
            vibrato: vibrato,
            slide: slide,
            visual: visual,
            hint: hint,
            theoryExplanation: theory,
            haptic: haptic,
            palmMuteAmount: palmMute,
            timbre: timbre,
            bowSpeed: bowSpeed,
            bowDirection: bowDirection,
            suppressStrum: stickOwnership.suppressesStrum || profile.supportsBowing || !profile.supportsStrumming,
            ownedGesture: stickOwnership.owned,
            faceEvents: faceEvents,
            expressionEvents: expressionEvents
        )
    }

    public mutating func beginSlide(from: Note, to: Note) {
        guard profile.supportsSlides else { return }
        slideEngine.begin(from: from, to: to)
    }

    private mutating func detectPickAttack(state: ControllerState, timestamp: TimeInterval) -> Bool {
        let dy = abs(state.rightStick.y - previousRightY)
        if dy > 0.22 && abs(state.rightStick.y) > 0.2 {
            lastPickAttackTime = timestamp
            return true
        }
        return timestamp - lastPickAttackTime < 0.04
    }

    private mutating func interpretFaceButtons(
        state: ControllerState,
        context: MusicalContext,
        heldNotes: [Note],
        pickAttack: Bool,
        timestamp: TimeInterval
    ) -> [FaceButtonNoteEvent] {
        guard let chord = context.chord else { return [] }
        let targeter = ContextualPitchTargeter()
        let pairs: [(pressed: Bool, was: Bool, role: ChordToneRole)] = [
            (state.buttonA, previousFace.a, .root),
            (state.buttonX, previousFace.x, .third),
            (state.buttonY, previousFace.y, .fifth),
            (state.buttonB, previousFace.b, .seventh)
        ]
        var events: [FaceButtonNoteEvent] = []
        for pair in pairs {
            if pair.pressed && !pair.was {
                let note = targeter.note(for: pair.role, chord: chord, previous: intervalMemory.lastNote, baseOctave: context.registerOctave)
                let sameString = stringModel.wouldBeSameString(from: lastMelodicNote ?? note, to: note)
                _ = stringModel.assign(note: note)
                let gapMs = (timestamp - lastMelodicTime) * 1000.0
                let overlap = !heldNotes.isEmpty
                let legato = LegatoGestureInterpreter().interpret(
                    previous: lastMelodicNote,
                    current: note,
                    overlap: overlap,
                    intervalMs: gapMs,
                    hasPickAttack: pickAttack,
                    slideModifier: state.leftShoulder && profile.supportsSlides,
                    profile: profile,
                    realism: settings.realism,
                    sameString: sameString,
                    preparedLowerNote: preparedLowerNote?.pitchClass == note.pitchClass
                )
                var technique = legato?.technique ?? .normal
                if state.rightShoulder && profile.supportsPinchHarmonics {
                    technique = pickAttack ? .pinchHarmonic : .harmonic
                }
                if state.rightShoulder && profile.supportsGhostNotes && profile.family == .bass {
                    technique = .ghostNote
                }
                if technique == .slideUp || technique == .slideDown, let previous = lastMelodicNote {
                    slideEngine.begin(from: previous, to: note)
                }
                intervalMemory.remember(role: pair.role, note: note)
                if note < (lastMelodicNote ?? note) {
                    preparedLowerNote = lastMelodicNote
                }
                lastMelodicNote = note
                lastMelodicTime = timestamp
                events.append(FaceButtonNoteEvent(
                    role: pair.role,
                    note: note,
                    isOn: true,
                    technique: technique,
                    velocity: legato?.velocity ?? 110
                ))
            } else if !pair.pressed && pair.was {
                let note = targeter.note(for: pair.role, chord: chord, previous: intervalMemory.lastNote, baseOctave: context.registerOctave)
                preparedLowerNote = note
                events.append(FaceButtonNoteEvent(
                    role: pair.role,
                    note: note,
                    isOn: false,
                    technique: .normal,
                    velocity: 0
                ))
            }
        }
        return events
    }

    private func timbreValue(state: ControllerState, pressure: PressureEnvelopeState) -> Double {
        if profile.family == .synthLead || profile.family == .genericMPE {
            return max(0, min(1, 0.5 + Double(state.rightStick.y) * 0.5))
        }
        return max(0, min(1, 0.45 + pressure.smoothed * 0.4))
    }

    private func statusLabel(
        technique: MusicalTechnique,
        bend: PitchExpressionState,
        pressure: PressureEnvelopeState,
        slide: SlideState
    ) -> String {
        let name = profile.family.shortName
        if bend.isBending && abs(bend.bendSemitones) > 0.08 {
            if let label = bend.displayLabel {
                return "\(name) · Bend \(label)"
            }
            return String(format: "%@ · Bend %+.1f st", name, bend.bendSemitones)
        }
        if slide.isSliding {
            return "\(name) · Slide"
        }
        if let play = technique.playLabel, technique != .aftertouch && technique != .vibrato {
            return "\(name) · \(play)"
        }
        if pressure.isActive && pressure.smoothed > 0.12 {
            return "\(name) · Pressure"
        }
        if technique == .vibrato {
            return "\(name) · Vibrato"
        }
        return name
    }

    private func visualHint(
        technique: MusicalTechnique,
        bend: PitchExpressionState,
        pressure: PressureEnvelopeState,
        slide: SlideState,
        held: Note?,
        faceEvents: [FaceButtonNoteEvent]
    ) -> TechniqueVisualHint {
        if bend.isBending {
            return TechniqueVisualHint(
                kind: .bend,
                intensity: min(1, abs(bend.bendSemitones) / max(0.5, profile.preferredPitchBendRange)),
                sourceNote: held,
                targetNote: bend.nearestTarget?.note,
                bendSemitones: bend.bendSemitones,
                targetProximity: bend.targetProximity
            )
        }
        if slide.isSliding {
            return TechniqueVisualHint(kind: .slide, intensity: slide.progress, sourceNote: slide.source, targetNote: slide.destination)
        }
        if let hammer = faceEvents.first(where: { $0.technique == .hammerOn && $0.isOn }) {
            return TechniqueVisualHint(kind: .hammerOn, intensity: 1, sourceNote: lastMelodicNote, targetNote: hammer.note)
        }
        if let pull = faceEvents.first(where: { $0.technique == .pullOff && $0.isOn }) {
            return TechniqueVisualHint(kind: .pullOff, intensity: 1, targetNote: pull.note)
        }
        if technique == .pinchHarmonic {
            return TechniqueVisualHint(kind: .pinchHarmonic, intensity: 1, sourceNote: held)
        }
        if technique == .palmMute {
            return TechniqueVisualHint(kind: .palmMute, intensity: 1, sourceNote: held)
        }
        if pressure.isActive {
            return TechniqueVisualHint(kind: .pressure, intensity: pressure.smoothed, sourceNote: held)
        }
        if technique == .vibrato {
            return TechniqueVisualHint(kind: .vibrato, intensity: 1, sourceNote: held)
        }
        return TechniqueVisualHint()
    }
}

public struct ExpressionSettings: Codable, Sendable, Equatable {
    public var pitchAssist: PitchAssistMode
    public var realism: RealismMode
    public var theoryAssist: Bool
    public var chromaticMode: Bool
    public var chordToneLayout: Bool

    public init(
        pitchAssist: PitchAssistMode = .light,
        realism: RealismMode = .natural,
        theoryAssist: Bool = false,
        chromaticMode: Bool = false,
        chordToneLayout: Bool = true
    ) {
        self.pitchAssist = pitchAssist
        self.realism = realism
        self.theoryAssist = theoryAssist
        self.chromaticMode = chromaticMode
        self.chordToneLayout = chordToneLayout
    }
}
