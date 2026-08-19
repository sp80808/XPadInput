import Foundation
import XPadCore

// MARK: - Semantic Musical Action Definition

/// A high-level musical intention mapped from physical controller hardware.
/// Separates the physical control ("which button/axis") from musical semantics ("what does it do in XPI?").
public enum SemanticMusicalAction: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    // Excitation & Sound Generation
    case primaryExcitation = "Primary Excitation (Strum / Pluck)"
    case secondaryExcitation = "Secondary Excitation (Duo Drums / Percussion)"
    
    // Continuous Expressive Dimensions
    case pitchExpression = "Pitch Expression (Bend / Vibrato / Slide)"
    case pressureExpression = "Pressure Expression (Dynamic Swell / Aftertouch)"
    case dampingExpression = "Damping Expression (Palm Mute / Decay Cut)"
    case timbreExpression = "Timbre Expression (Filter Sweep / Brightness)"
    case motionExpression = "Motion Tilt Expression (6-Axis IMU Modulation)"
    
    // Harmonic Navigation & Voicing
    case harmonyNavigate2D = "Harmonic Wheel 2D (Polar Sector & Risk)"
    case octaveUp = "Octave Shift Up"
    case octaveDown = "Octave Shift Down"
    case voicingNext = "Next Inversion / Open Voicing"
    case voicingPrevious = "Previous Inversion / Close Voicing"
    
    // Articulation & Modifiers
    case techniqueModifier = "Technique Modifier (Hammer / Pull / Slide Hold)"
    case sustainLatch = "Sustain Latch (Pedal Hold / Toggle)"
    case soloModeToggle = "Lead Solo Mode Toggle"
    case duoModeToggle = "Duo Performance Mode Toggle"
    
    // Discrete Voice / Degree Triggers
    case voiceDegree1 = "Chord Root / Degree 1 Voice"
    case voiceDegree3 = "Chord Third / Degree 3 Voice"
    case voiceDegree5 = "Chord Fifth / Degree 5 Voice"
    case voiceDegree7 = "Chord Seventh / Degree 7 Voice"
    
    // Utility & Safety
    case panic = "MIDI Panic (All Notes Off)"
    case metronomeToggle = "Metronome Audio Click Toggle"

    public var id: String { rawValue }

    /// Musician-friendly display title.
    public var displayName: String {
        switch self {
        case .primaryExcitation: return "Strum / Excite"
        case .secondaryExcitation: return "Duo Drums / Accent"
        case .pitchExpression: return "Pitch Bend / Vibrato"
        case .pressureExpression: return "Pressure / Swell"
        case .dampingExpression: return "Palm Mute / Damp"
        case .timbreExpression: return "Timbre (CC74)"
        case .motionExpression: return "Motion Tilt"
        case .harmonyNavigate2D: return "Harmonic Wheel"
        case .octaveUp: return "Octave Up"
        case .octaveDown: return "Octave Down"
        case .voicingNext: return "Voicing Next"
        case .voicingPrevious: return "Voicing Prev"
        case .techniqueModifier: return "Technique Mod"
        case .sustainLatch: return "Sustain Latch"
        case .soloModeToggle: return "Solo Mode"
        case .duoModeToggle: return "Duo Drums"
        case .voiceDegree1: return "Voice 1 (Root)"
        case .voiceDegree3: return "Voice 2 (3rd)"
        case .voiceDegree5: return "Voice 3 (5th)"
        case .voiceDegree7: return "Voice 4 (7th)"
        case .panic: return "MIDI Panic"
        case .metronomeToggle: return "Metronome"
        }
    }

    /// Concise functional description for musician onboarding and tooltips.
    public var description: String {
        switch self {
        case .primaryExcitation:
            return "Strikes or strums the active chord, plucks single voices, or initiates smart solo strokes."
        case .secondaryExcitation:
            return "Triggers rhythmic drum hits (Kick/Snare/Hats) without moving thumbs away from melodic play."
        case .pitchExpression:
            return "Applies continuous microtonal pitch bends, expressive vibrato, or fret slides up to ±48 semitones."
        case .pressureExpression:
            return "Drives dynamic volume swells, polyphonic aftertouch, or bowed string bow weight."
        case .dampingExpression:
            return "Applies acoustic palm muting, acoustic damping, or filter envelope decay clamping."
        case .timbreExpression:
            return "Modulates high-pass/low-pass filter resonance and MPE CC74 timbre."
        case .motionExpression:
            return "Maps 6-axis controller tilt, roll, and pitch to expressive stereo soundscapes."
        case .harmonyNavigate2D:
            return "Continuously steers the Circle of Fifths harmonic degree wheel (Angle = Degree, Radius = Tension)."
        case .octaveUp:
            return "Shifts active playing register up by one octave (+12 semitones)."
        case .octaveDown:
            return "Shifts active playing register down by one octave (-12 semitones)."
        case .voicingNext:
            return "Cycles to the next higher inversion or drop-2 open chord voicing."
        case .voicingPrevious:
            return "Cycles to the next lower inversion or close-triad voicing."
        case .techniqueModifier:
            return "Prepares legato hammer-ons, pull-offs, or fretboard slides on subsequent notes."
        case .sustainLatch:
            return "Latches ringing chords or sustained synth drones (Pedal hold or toggle)."
        case .soloModeToggle:
            return "Converts the right thumbstick between chord strumming and Voice-Led smart lead soloing."
        case .duoModeToggle:
            return "Enables simultaneous 4-piece drum groove triggers on the face buttons."
        case .voiceDegree1, .voiceDegree3, .voiceDegree5, .voiceDegree7:
            return "Directly articulates an individual chord tone voice independently of the strum bar."
        case .panic:
            return "Instantly terminates all sounding voices, clears MPE channel queues, and silences DSP."
        case .metronomeToggle:
            return "Toggles the built-in tempo reference click on or off."
        }
    }

    /// Category for organizing remapping tables and settings UI.
    public var category: ActionCategory {
        switch self {
        case .primaryExcitation, .secondaryExcitation:
            return .excitation
        case .pitchExpression, .pressureExpression, .dampingExpression, .timbreExpression, .motionExpression:
            return .expression
        case .harmonyNavigate2D, .octaveUp, .octaveDown, .voicingNext, .voicingPrevious:
            return .harmony
        case .techniqueModifier, .sustainLatch, .soloModeToggle, .duoModeToggle:
            return .articulation
        case .voiceDegree1, .voiceDegree3, .voiceDegree5, .voiceDegree7:
            return .directVoices
        case .panic, .metronomeToggle:
            return .utility
        }
    }

    /// Required input hardware capability archetype.
    public var compatibilityType: InputCompatibilityType {
        switch self {
        case .harmonyNavigate2D:
            return .continuous2D
        case .primaryExcitation, .pitchExpression, .pressureExpression, .dampingExpression, .timbreExpression, .motionExpression:
            return .continuous1DOr2D
        case .octaveUp, .octaveDown, .voicingNext, .voicingPrevious:
            return .digitalOrDirectional
        case .techniqueModifier, .secondaryExcitation, .voiceDegree1, .voiceDegree3, .voiceDegree5, .voiceDegree7:
            return .digitalMomentary
        case .sustainLatch, .soloModeToggle, .duoModeToggle, .panic, .metronomeToggle:
            return .digitalToggleOrButton
        }
    }

    public enum ActionCategory: String, CaseIterable, Sendable, Identifiable {
        case excitation = "Excitation & Strum"
        case expression = "Continuous Expression"
        case harmony = "Harmony & Navigation"
        case articulation = "Articulation & Modes"
        case directVoices = "Individual Voices"
        case utility = "System & Utility"

        public var id: String { rawValue }
    }

    public enum InputCompatibilityType: String, Sendable {
        case continuous2D = "2D Continuous Thumbstick"
        case continuous1DOr2D = "Analog Axis, Trigger or Stick"
        case digitalOrDirectional = "Digital Button or D-Pad Direction"
        case digitalMomentary = "Momentary Face / Shoulder Button"
        case digitalToggleOrButton = "Button or Toggle Latch"
    }
}

// MARK: - Physical Control Input Identification

/// Enumerates every physical hardware element on a modern GameController.
public enum PhysicalControlInput: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    // 2D & 1D Analog Thumbsticks
    case leftStick2D = "Left Stick (2D)"
    case rightStick2D = "Right Stick (2D)"
    case leftStickX = "Left Stick X"
    case leftStickY = "Left Stick Y"
    case rightStickX = "Right Stick X"
    case rightStickY = "Right Stick Y"
    
    // Analog Triggers
    case leftTrigger = "Left Trigger (L2 / LT)"
    case rightTrigger = "Right Trigger (R2 / RT)"
    
    // Digital Shoulder Bumpers & Stick Clicks
    case leftShoulder = "Left Bumper (L1 / LB)"
    case rightShoulder = "Right Bumper (R1 / RB)"
    case leftStickClick = "Left Stick Click (L3 / LSB)"
    case rightStickClick = "Right Stick Click (R3 / RSB)"
    
    // Face Buttons (Cross/A, Circle/B, Square/X, Triangle/Y)
    case buttonSouth = "South Button (A / Cross)"
    case buttonEast = "East Button (B / Circle)"
    case buttonWest = "West Button (X / Square)"
    case buttonNorth = "North Button (Y / Triangle)"
    
    // Directional Pad (D-Pad)
    case dpadUp = "D-Pad Up"
    case dpadDown = "D-Pad Down"
    case dpadLeft = "D-Pad Left"
    case dpadRight = "D-Pad Right"
    
    // System & Center Controls
    case buttonOptions = "Options / Menu / Start"
    case buttonShare = "Share / View / Select"
    case buttonCenter = "Touchpad Click / Guide Button"
    
    // Motion & Touchpad Surfaces
    case motionPitch = "IMU Motion Pitch"
    case motionRoll = "IMU Motion Roll"
    case motionYaw = "IMU Motion Yaw"
    case touchpad2D = "Touchpad Surface (2D)"
    
    // Unassigned fallback
    case unassigned = "Unassigned"

    public var id: String { rawValue }

    /// Returns standard vector glyph key for rendering high-fidelity controller buttons.
    public var defaultGlyphKey: GlyphKey {
        switch self {
        case .leftStick2D, .leftStickX, .leftStickY: return .leftStick
        case .rightStick2D, .rightStickX, .rightStickY: return .rightStick
        case .leftTrigger: return .psL2
        case .rightTrigger: return .psR2
        case .leftShoulder: return .psL1
        case .rightShoulder: return .psR1
        case .leftStickClick: return .psL3
        case .rightStickClick: return .psR3
        case .buttonSouth: return .psCross
        case .buttonEast: return .psCircle
        case .buttonWest: return .psSquare
        case .buttonNorth: return .psTriangle
        case .dpadUp: return .dpadUp
        case .dpadDown: return .dpadDown
        case .dpadLeft: return .dpadLeft
        case .dpadRight: return .dpadRight
        case .buttonOptions: return .psOptions
        case .buttonShare: return .psCreate
        case .buttonCenter, .touchpad2D: return .psTouchpad
        case .motionPitch, .motionRoll, .motionYaw: return .guitarTilt
        case .unassigned: return .leftStick
        }
    }

    /// Whether this hardware element produces continuous analog values or discrete boolean states.
    public var isContinuous: Bool {
        switch self {
        case .leftStick2D, .rightStick2D, .leftStickX, .leftStickY, .rightStickX, .rightStickY,
             .leftTrigger, .rightTrigger, .motionPitch, .motionRoll, .motionYaw, .touchpad2D:
            return true
        default:
            return false
        }
    }

    /// Whether the analog domain is bipolar \([-1, 1]\) rather than unipolar \([0, 1]\).
    public var isBipolar: Bool {
        switch self {
        case .leftStick2D, .rightStick2D, .leftStickX, .leftStickY, .rightStickX, .rightStickY,
             .motionPitch, .motionRoll, .motionYaw, .touchpad2D:
            return true
        default:
            return false
        }
    }

    /// Shared hardware family used for overlap detection (e.g. right-stick 2D vs Y axis).
    public var hardwareFamily: PhysicalControlFamily {
        switch self {
        case .leftStick2D, .leftStickX, .leftStickY: return .leftStick
        case .rightStick2D, .rightStickX, .rightStickY: return .rightStick
        case .leftTrigger: return .leftTrigger
        case .rightTrigger: return .rightTrigger
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftStickClick: return .leftStickClick
        case .rightStickClick: return .rightStickClick
        case .buttonSouth: return .faceSouth
        case .buttonEast: return .faceEast
        case .buttonWest: return .faceWest
        case .buttonNorth: return .faceNorth
        case .dpadUp: return .dpadUp
        case .dpadDown: return .dpadDown
        case .dpadLeft: return .dpadLeft
        case .dpadRight: return .dpadRight
        case .buttonOptions: return .options
        case .buttonShare: return .share
        case .buttonCenter: return .center
        case .motionPitch, .motionRoll, .motionYaw: return .motion
        case .touchpad2D: return .touchpad
        case .unassigned: return .none
        }
    }

    /// Axis component within a thumbstick family.
    public var stickAxis: StickAxisComponent? {
        switch self {
        case .leftStick2D, .rightStick2D: return .radial
        case .leftStickX, .rightStickX: return .x
        case .leftStickY, .rightStickY: return .y
        default: return nil
        }
    }

    /// True when two bindings occupy overlapping hardware, including 2D vs axis on the same stick.
    public func overlapsHardware(with other: PhysicalControlInput) -> Bool {
        if self == other { return true }
        if self == .unassigned || other == .unassigned { return false }
        guard hardwareFamily == other.hardwareFamily else { return false }
        switch hardwareFamily {
        case .leftStick, .rightStick:
            let a = stickAxis
            let b = other.stickAxis
            if a == .radial || b == .radial { return true }
            return a == b
        case .motion:
            return self == other
        default:
            return true
        }
    }

    /// Orthogonal stick axes (X + Y) may share a thumbstick without fighting.
    public func isOrthogonalStickPair(with other: PhysicalControlInput) -> Bool {
        guard hardwareFamily == other.hardwareFamily,
              hardwareFamily == .leftStick || hardwareFamily == .rightStick else {
            return false
        }
        let a = stickAxis
        let b = other.stickAxis
        return (a == .x && b == .y) || (a == .y && b == .x)
    }

    /// Returns a short capability name when this input cannot be delivered by the profile.
    public func unavailableReason(given capabilities: ControllerCapabilityProfile) -> String? {
        switch self {
        case .motionPitch, .motionRoll, .motionYaw:
            return capabilities.hasMotionIMU ? nil : "motion IMU"
        case .touchpad2D, .buttonCenter:
            return capabilities.hasTouchpad ? nil : "touchpad"
        case .leftStickClick, .rightStickClick:
            return capabilities.hasThumbstickClicks ? nil : "stick clicks"
        case .leftTrigger, .rightTrigger:
            return capabilities.hasAnalogTriggers ? nil : "analog triggers"
        default:
            return nil
        }
    }
}

/// Hardware grouping for conflict detection and capability fallbacks.
public enum PhysicalControlFamily: String, Sendable, Equatable {
    case leftStick, rightStick
    case leftTrigger, rightTrigger
    case leftShoulder, rightShoulder
    case leftStickClick, rightStickClick
    case faceSouth, faceEast, faceWest, faceNorth
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case options, share, center
    case motion, touchpad
    case none
}

public enum StickAxisComponent: String, Sendable, Equatable {
    case x, y, radial
}
