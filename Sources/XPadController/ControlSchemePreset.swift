import Foundation
import XPadCore

/// Factory presets for all research-informed and legacy XPI control schemes.
public enum ControlSchemePreset {
    
    // MARK: - 1. XPI Performance (New Recommended Default)
    
    /// The balanced, low-fatigue, research-informed performance layout for dual-analog gamepads.
    public static var xpiPerformance: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        // Left Thumb: Harmonic Navigation
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        
        // Right Thumb: Expressive Strum Excitation & Pitch Bend
        bindings[.primaryExcitation] = .defaultBinding(for: .rightStickY)
        bindings[.pitchExpression] = .defaultBinding(for: .rightStickX)
        
        // Index / Middle Fingers: Damping & Continuous Pressure Swell
        bindings[.dampingExpression] = .defaultBinding(for: .leftTrigger)
        bindings[.pressureExpression] = .defaultBinding(for: .rightTrigger)
        
        // Bumpers: Technique Modifiers & Ringing Sustain
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = .defaultBinding(for: .rightShoulder)
        
        // Face Buttons: Direct Voice Plucks (Root, 3rd, 5th, 7th) & Duo Drum Hits
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        // D-Pad: Octave & Inversion Shifts
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        
        // Stick Clicks: Mode Switches
        bindings[.soloModeToggle] = .defaultBinding(for: .rightStickClick)
        bindings[.duoModeToggle] = .defaultBinding(for: .leftStickClick)
        
        // Motion & System
        bindings[.motionExpression] = .defaultBinding(for: .motionPitch)
        bindings[.timbreExpression] = .defaultBinding(for: .touchpad2D)
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        bindings[.metronomeToggle] = .defaultBinding(for: .buttonShare)
        
        return ControlScheme(
            id: "xpi_performance",
            name: "XPI Performance (Recommended)",
            description: "Balanced two-hand layout with complementary roles: Left thumb steers harmony, Right thumb drives strumming & pitch bends, Triggers shape pressure & damping.",
            isBuiltIn: true,
            version: 2,
            bindings: bindings,
            stickFeel: .balanced,
            triggerFeel: .linear,
            haptics: .normal,
            isMotionEnabled: true,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 2. XPI Classic (100% Backward Compatibility)
    
    /// Preserves the exact original layout and feel for existing users.
    public static var xpiClassic: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        bindings[.primaryExcitation] = .defaultBinding(for: .rightStickY)
        bindings[.pitchExpression] = .defaultBinding(for: .rightStickX)
        bindings[.dampingExpression] = .defaultBinding(for: .leftTrigger)
        bindings[.pressureExpression] = .defaultBinding(for: .rightTrigger)
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = .defaultBinding(for: .rightShoulder)
        
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        bindings[.metronomeToggle] = .defaultBinding(for: .buttonShare)

        return ControlScheme(
            id: "xpi_classic",
            name: "XPI Classic (Compatibility)",
            description: "Original default XPadInput layout with standard trigger damping and right-stick strumming.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .balanced,
            triggerFeel: .linear,
            haptics: .normal,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 3. Low-Fatigue (Accessibility & Long Jam Sessions)
    
    /// Eliminates stick-clicks, reduces prolonged holds with toggle latches, and uses soft triggers.
    public static var lowFatigue: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        bindings[.primaryExcitation] = .defaultBinding(for: .rightStickY)
        bindings[.pitchExpression] = .defaultBinding(for: .rightStickX)
        
        // Soft triggers with low activation travel
        bindings[.dampingExpression] = PhysicalControlBinding(input: .leftTrigger, sensitivity: 1.4)
        bindings[.pressureExpression] = PhysicalControlBinding(input: .rightTrigger, sensitivity: 1.4)
        
        // Bumpers
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = PhysicalControlBinding(input: .rightShoulder, digitalBehavior: .stepped)
        
        // Face Buttons
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        // D-Pad: Octave & Inversion stay musical. Mode switches move off stick-clicks
        // onto the centre pad so long sessions never require L3/R3.
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        
        bindings[.soloModeToggle] = .defaultBinding(for: .buttonCenter)
        bindings[.duoModeToggle] = .defaultBinding(for: .buttonShare)
        
        bindings[.panic] = .defaultBinding(for: .buttonOptions)

        return ControlScheme(
            id: "xpi_low_fatigue",
            name: "Low-Fatigue Ergonomics",
            description: "Minimizes finger strain, eliminates thumbstick clicks, uses soft trigger engagement, keeps voicing on the D-Pad, and replaces long holds with toggles.",
            isBuiltIn: true,
            version: 2,
            bindings: bindings,
            stickFeel: .responsive,
            triggerFeel: .soft,
            haptics: .subtle,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 4. One-Hand — Left (Single Handed Left)
    
    /// Enables complete instrument performance using only the left half of the gamepad.
    public static var oneHandLeft: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        // Left Thumb navigates harmony; trigger flick excites sound
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        bindings[.primaryExcitation] = .defaultBinding(for: .leftTrigger)
        bindings[.dampingExpression] = .defaultBinding(for: .leftShoulder)
        bindings[.pitchExpression] = .defaultBinding(for: .motionPitch)
        bindings[.motionExpression] = .defaultBinding(for: .motionRoll)
        
        // D-Pad handles pitch octave & direct root/third triggers
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voiceDegree1] = .defaultBinding(for: .dpadLeft)
        bindings[.voiceDegree3] = .defaultBinding(for: .dpadRight)
        
        bindings[.sustainLatch] = PhysicalControlBinding(input: .leftStickClick, digitalBehavior: .stepped)
        bindings[.panic] = .defaultBinding(for: .buttonShare)
        
        return ControlScheme(
            id: "xpi_one_hand_left",
            name: "One-Hand (Left)",
            description: "Complete single-handed performance on the left side: stick steers harmony, trigger strums, bumper damps, gyro bends.",
            isBuiltIn: true,
            version: 2,
            bindings: bindings,
            stickFeel: .responsive,
            triggerFeel: .soft,
            haptics: .normal,
            isMotionEnabled: true,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 5. One-Hand — Right (Single Handed Right)
    
    /// Enables complete instrument performance using only the right half of the gamepad.
    public static var oneHandRight: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .rightStick2D)
        bindings[.primaryExcitation] = .defaultBinding(for: .rightTrigger)
        bindings[.pitchExpression] = .defaultBinding(for: .motionPitch)
        bindings[.pressureExpression] = PhysicalControlBinding(input: .rightShoulder, digitalBehavior: .linearRamp)
        bindings[.sustainLatch] = PhysicalControlBinding(input: .rightStickClick, digitalBehavior: .stepped)
        bindings[.motionExpression] = .defaultBinding(for: .motionRoll)
        
        // Face buttons handle direct chord degrees
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        
        return ControlScheme(
            id: "xpi_one_hand_right",
            name: "One-Hand (Right)",
            description: "Complete single-handed performance on the right side: stick steers harmony, trigger strums, face buttons play chord tones, gyro bends.",
            isBuiltIn: true,
            version: 2,
            bindings: bindings,
            stickFeel: .responsive,
            triggerFeel: .soft,
            haptics: .normal,
            isMotionEnabled: true,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 6. Left-Handed Performance
    
    /// Mirrors the recommended two-hand layout so the left thumb strums and the right thumb steers harmony.
    public static var leftHandedPerformance: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .rightStick2D)
        bindings[.primaryExcitation] = .defaultBinding(for: .leftStickY)
        bindings[.pitchExpression] = .defaultBinding(for: .leftStickX)
        
        bindings[.dampingExpression] = .defaultBinding(for: .rightTrigger)
        bindings[.pressureExpression] = .defaultBinding(for: .leftTrigger)
        
        bindings[.techniqueModifier] = .defaultBinding(for: .rightShoulder)
        bindings[.sustainLatch] = .defaultBinding(for: .leftShoulder)
        
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        
        bindings[.soloModeToggle] = .defaultBinding(for: .leftStickClick)
        bindings[.duoModeToggle] = .defaultBinding(for: .rightStickClick)
        
        bindings[.motionExpression] = .defaultBinding(for: .motionPitch)
        bindings[.timbreExpression] = .defaultBinding(for: .touchpad2D)
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        bindings[.metronomeToggle] = .defaultBinding(for: .buttonShare)
        
        return ControlScheme(
            id: "xpi_left_handed",
            name: "Left-Handed Performance",
            description: "Mirrored two-hand layout: Right thumb steers the harmonic wheel, Left thumb strums and bends. Triggers and bumpers are swapped to match.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .balanced,
            triggerFeel: .linear,
            haptics: .normal,
            isMotionEnabled: true,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 7. Arcade Fight Stick

    /// Single-lever arcade cabinet layout for fight-stick style controllers.
    public static var arcadeFightStick: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        // Ball-Top Lever: Harmonic Navigation & Lead Solo Toggle
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        bindings[.soloModeToggle] = .defaultBinding(for: .leftStickClick)
        
        // Face Buttons: Direct Voice Plucks (Root, 3rd, 5th, 7th)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        // Top-Row Buttons: Technique Modifiers & Ringing Sustain
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = .defaultBinding(for: .rightShoulder)
        
        // Front Buttons / Triggers: Strum Excitation & Palm-Mute Damping
        bindings[.primaryExcitation] = .defaultBinding(for: .rightTrigger)
        bindings[.dampingExpression] = .defaultBinding(for: .leftTrigger)
        
        // D-Pad: Octave & Inversion Shifts
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        
        // System
        bindings[.duoModeToggle] = .defaultBinding(for: .buttonShare)
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        
        return ControlScheme(
            id: "xpi_arcade_stick",
            name: "Arcade Fight Stick",
            description: "Classic arcade cabinet layout: the ball-top lever steers the harmonic wheel (clicking it toggles Lead Solo), the four face buttons pluck Root, 3rd, 5th and 7th, top-row buttons arm technique and latch sustain, front triggers damp and swell, and the D-Pad shifts octaves and inversions.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .responsive,
            triggerFeel: .firm,
            haptics: .normal,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 8. Racing Wheel & Pedals

    /// Sim-racing cockpit layout: wheel for bends, pedals for strum & damping, paddles for articulation.
    public static var racingWheelCruise: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        // Steering Wheel Axis (enumerates as Left Stick X): Pitch Bends & Vibrato
        bindings[.pitchExpression] = .defaultBinding(for: .leftStickX)
        
        // Gas Pedal (Right Trigger): Boosted Strum Excitation
        bindings[.primaryExcitation] = PhysicalControlBinding(input: .rightTrigger, sensitivity: 1.2)
        
        // Brake Pedal (Left Trigger): Palm-Mute Damping
        bindings[.dampingExpression] = .defaultBinding(for: .leftTrigger)
        
        // Paddle Shifters: Latched Sustain Rings & Technique Arming
        bindings[.sustainLatch] = PhysicalControlBinding(input: .rightShoulder, digitalBehavior: .stepped)
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        
        // Face Buttons: Direct Voice Plucks (Root, 3rd, 5th, 7th)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        // D-Pad: Octave & Inversion Shifts
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        
        // Stub Right Stick: Harmonic Wheel Navigation (rebindable on wheels without one)
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .rightStick2D)
        
        // System
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        
        return ControlScheme(
            id: "xpi_racing_wheel",
            name: "Racing Wheel & Pedals",
            description: "Sim-racing cockpit mapping: turn the wheel (left-stick X) for pitch bends, floor the gas pedal (right trigger) to strum chords, feather the brake pedal (left trigger) to damp, snap the paddle shifters to latch sustain and arm techniques, pluck chord tones with the face buttons, shift octaves and inversions on the D-Pad, and steer harmony with the rim's stub right stick.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .precise,
            triggerFeel: .linear,
            haptics: .normal,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 9. Flight HOTAS Deck

    /// Flight-stick & throttle quadrant layout: deflection, twist, throttle and split triggers.
    public static var flightDeckHOTAS: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        // Joystick Deflection: Harmonic Wheel Navigation
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        
        // Twist Grip: Pitch Bends & Vibrato
        bindings[.pitchExpression] = .defaultBinding(for: .leftStickX)
        
        // Throttle Lever (Right Stick Y): Smooth Pressure Swells While Held
        bindings[.pressureExpression] = PhysicalControlBinding(input: .rightStickY, digitalBehavior: .linearRamp)
        
        // Primary Trigger: Strum Excitation | Second Trigger Stage: Filter Timbre
        bindings[.primaryExcitation] = .defaultBinding(for: .rightTrigger)
        bindings[.timbreExpression] = .defaultBinding(for: .leftTrigger)
        
        // Base Buttons / Paddles: Technique Modifiers & Ringing Sustain
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = .defaultBinding(for: .rightShoulder)
        
        // Hat / Face Buttons: Direct Voice Plucks (Root, 3rd, 5th, 7th)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        // D-Pad: Octave & Inversion Shifts
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        
        // Stick Clicks: Mode Switches
        bindings[.soloModeToggle] = .defaultBinding(for: .rightStickClick)
        bindings[.duoModeToggle] = .defaultBinding(for: .leftStickClick)
        
        // System
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        
        return ControlScheme(
            id: "xpi_flight_deck",
            name: "Flight HOTAS Deck",
            description: "Flight-sim deck mapping: deflect the joystick to steer the harmonic wheel, twist the grip for pitch bends, push the throttle lever forward for pressure swells, pull the trigger to strum, ride the second trigger stage for filter timbre, flip base paddles for technique and sustain, pluck chord tones on the hat buttons, and click stick or throttle for Solo and Duo modes.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .balanced,
            triggerFeel: .linear,
            haptics: .normal,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 10. Rhythm Pad Compact

    /// Compact drum-pad layout for taiko / pop'n / Guitar-Hero style extended gamepads.
    public static var rhythmPadCompact: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]
        
        // Face Buttons: Direct Voice Plucks (Root, 3rd, 5th, 7th)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)
        
        // Drum Surface (D-Pad): Full Strike, Instant Palm Mute, Inversion Cycling
        bindings[.primaryExcitation] = PhysicalControlBinding(input: .dpadUp, digitalBehavior: .fixedFull)
        bindings[.dampingExpression] = PhysicalControlBinding(input: .dpadDown, digitalBehavior: .fixedFull)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        
        // Shoulder Buttons: Technique Modifiers & Ringing Sustain
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = .defaultBinding(for: .rightShoulder)
        
        // Triggers: Gradual Pressure Swell Ramp
        bindings[.pressureExpression] = PhysicalControlBinding(input: .rightTrigger, digitalBehavior: .linearRamp)
        
        // Compact Stick: Harmonic Navigation, Clicks Shift Register, Center Toggles Solo
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        bindings[.octaveUp] = .defaultBinding(for: .rightStickClick)
        bindings[.octaveDown] = .defaultBinding(for: .leftStickClick)
        bindings[.soloModeToggle] = .defaultBinding(for: .buttonCenter)
        
        // System
        bindings[.metronomeToggle] = .defaultBinding(for: .buttonShare)
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        
        return ControlScheme(
            id: "xpi_rhythm_pad",
            name: "Rhythm Pad Compact",
            description: "Compact drum-pad layout for taiko, pop'n and Guitar-Hero style controllers: the four face buttons ring Root, 3rd, 5th and 7th, tapping D-Pad Up strikes the whole chord while Down palm-mutes instantly and the sides cycle inversions, bumpers arm technique and latch sustain, the right trigger swells pressure gradually, and the small stick steers harmony (clicks shift octaves).",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .responsive,
            triggerFeel: .soft,
            haptics: .subtle,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 11. Finger Drummer

    /// Finger-drumming layout: face buttons fire kit voices, triggers choke and swell.
    public static var fingerDrummer: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]

        // Face Buttons: Four drum-lane voice plucks (Root, 3rd, 5th, 7th)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)

        // D-Pad: Full-kit strike, instant choke, lane cycling
        bindings[.primaryExcitation] = PhysicalControlBinding(input: .dpadUp, digitalBehavior: .fixedFull)
        bindings[.dampingExpression] = PhysicalControlBinding(input: .dpadDown, digitalBehavior: .fixedFull)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)

        // Left Stick: Harmony navigation; click toggles Duo drum lanes
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        bindings[.duoModeToggle] = .defaultBinding(for: .leftStickClick)

        // Right Stick X: Pitch expression for tuned percussion
        bindings[.pitchExpression] = .defaultBinding(for: .rightStickX)

        // Triggers: Choke damping & gradual pressure swell
        bindings[.pressureExpression] = PhysicalControlBinding(input: .rightTrigger, digitalBehavior: .linearRamp)

        // Bumpers: Technique modifiers & ringing sustain
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = .defaultBinding(for: .rightShoulder)

        // System
        bindings[.metronomeToggle] = .defaultBinding(for: .buttonShare)
        bindings[.panic] = .defaultBinding(for: .buttonOptions)

        return ControlScheme(
            id: "xpi_finger_drummer",
            name: "Finger Drummer",
            description: "MPC-style finger drumming: the four face buttons fire Root, 3rd, 5th and 7th lanes, tapping D-Pad Up strikes the full kit while Down chokes it instantly, the right trigger swells pressure and bumpers arm technique or sustain.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .responsive,
            triggerFeel: .firm,
            haptics: .normal,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 12. Bass Groove Lab

    /// Low-register bass performance with punchy plucks and tight damping.
    public static var bassGrooveLab: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]

        // Left Thumb: Harmonic Navigation
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)

        // Right Thumb: Boosted Pluck Excitation & Pitch Expression
        bindings[.primaryExcitation] = PhysicalControlBinding(input: .rightStickY, sensitivity: 1.3)
        bindings[.pitchExpression] = .defaultBinding(for: .rightStickX)

        // Triggers: Tight palm-mute damping & sub pressure swell
        bindings[.dampingExpression] = PhysicalControlBinding(input: .leftTrigger, sensitivity: 1.4)
        bindings[.pressureExpression] = PhysicalControlBinding(input: .rightTrigger, sensitivity: 1.2)

        // Bumpers: Ghost-note technique & stepped sustain
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = PhysicalControlBinding(input: .rightShoulder, digitalBehavior: .stepped)

        // Face Buttons: Direct Voice Plucks (Root, 3rd, 5th, 7th)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)

        // D-Pad: Octave & Inversion Shifts
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)

        // Stick Clicks: Mode Switches
        bindings[.soloModeToggle] = .defaultBinding(for: .rightStickClick)
        bindings[.duoModeToggle] = .defaultBinding(for: .leftStickClick)

        // System
        bindings[.panic] = .defaultBinding(for: .buttonOptions)

        return ControlScheme(
            id: "xpi_bass_groove",
            name: "Bass Groove Lab",
            description: "Low-end focused layout: boosted right-stick plucks with precise pitch bends, tight left-trigger palm muting, stepped sustain latches and ghost-note technique arming on the bumpers.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .precise,
            triggerFeel: .firm,
            haptics: .subtle,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 13. Ambient Drift

    /// Slow evolving pad performance: sustained swells, motion-driven drift and timbre morphing.
    public static var ambientDrift: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]

        // Left Thumb: Harmonic Navigation
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)

        // Right Trigger: Slow swell excitation ramp
        bindings[.primaryExcitation] = PhysicalControlBinding(input: .rightTrigger, digitalBehavior: .linearRamp)

        // Right Stick Y: Continuous pressure morph while held
        bindings[.pressureExpression] = PhysicalControlBinding(input: .rightStickY, digitalBehavior: .linearRamp)

        // Right Stick X: Timbre / filter morphing
        bindings[.timbreExpression] = .defaultBinding(for: .rightStickX)

        // Motion: Tilt drives pitch drift and spatial movement
        bindings[.pitchExpression] = .defaultBinding(for: .motionPitch)
        bindings[.motionExpression] = .defaultBinding(for: .motionRoll)

        // Bumpers: Technique modifiers & stepped infinite sustain
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = PhysicalControlBinding(input: .rightShoulder, digitalBehavior: .stepped)

        // Face Buttons: Direct Voice Plucks (Root, 3rd, 5th, 7th)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)

        // D-Pad: Octave & Inversion Shifts
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)

        // System
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        bindings[.metronomeToggle] = .defaultBinding(for: .buttonShare)

        return ControlScheme(
            id: "xpi_ambient_drift",
            name: "Ambient Drift",
            description: "Evolving soundscape layout: hold the right trigger to swell chords into infinite sustains, tilt the controller to bend pitch and drift space, and morph filter timbre with the right stick.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .precise,
            triggerFeel: .soft,
            haptics: .subtle,
            isMotionEnabled: true,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 14. Gyro Theremin

    /// Motion-first continuous instrument: tilt to play pitch like a theremin.
    public static var gyroTheremin: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]

        // Motion Pitch: Primary continuous pitch control
        bindings[.pitchExpression] = .defaultBinding(for: .motionPitch)

        // Motion Roll: Secondary excitation — tilt past threshold re-triggers
        bindings[.secondaryExcitation] = .defaultBinding(for: .motionRoll)

        // Right Trigger: Firm strum excitation
        bindings[.primaryExcitation] = .defaultBinding(for: .rightTrigger)

        // Left Stick: Harmonic Navigation
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)

        // Touchpad: Timbre shaping
        bindings[.timbreExpression] = .defaultBinding(for: .touchpad2D)

        // Left Trigger: Pressure swell
        bindings[.pressureExpression] = PhysicalControlBinding(input: .leftTrigger, digitalBehavior: .linearRamp)

        // Sustain latch on the bumper
        bindings[.sustainLatch] = PhysicalControlBinding(input: .rightShoulder, digitalBehavior: .stepped)

        // System
        bindings[.panic] = .defaultBinding(for: .buttonOptions)
        bindings[.metronomeToggle] = .defaultBinding(for: .buttonShare)

        return ControlScheme(
            id: "xpi_gyro_theremin",
            name: "Gyro Theremin",
            description: "Contactless motion instrument: tilt forward/back to sweep pitch across ±48 semitones, roll sideways to re-trigger, pull the right trigger to sound notes, and glide the touchpad to shape timbre.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .balanced,
            triggerFeel: .firm,
            haptics: .off,
            isMotionEnabled: true,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 15. Turntablist Chops

    /// DJ-style rhythmic chops: crossfader-style secondary excitation and scratch pitch rides.
    public static var turntablistChops: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]

        // Left Stick Y: Rhythmic chop excitation (fader stabs)
        bindings[.secondaryExcitation] = PhysicalControlBinding(input: .leftStickY, sensitivity: 1.2)

        // Right Trigger: Primary strum excitation
        bindings[.primaryExcitation] = .defaultBinding(for: .rightTrigger)

        // Left Trigger: Crossfader-style damping
        bindings[.dampingExpression] = PhysicalControlBinding(input: .leftTrigger, sensitivity: 1.4)

        // Right Stick X: Scratch pitch rides
        bindings[.pitchExpression] = .defaultBinding(for: .rightStickX)

        // Left Stick: Harmonic wheel navigation
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)

        // Bumpers: Technique modifiers & ringing sustain
        bindings[.techniqueModifier] = .defaultBinding(for: .leftShoulder)
        bindings[.sustainLatch] = .defaultBinding(for: .rightShoulder)

        // Face Buttons: Direct Voice Plucks (Root, 3rd, 5th, 7th)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)
        bindings[.voiceDegree3] = .defaultBinding(for: .buttonWest)
        bindings[.voiceDegree5] = .defaultBinding(for: .buttonNorth)
        bindings[.voiceDegree7] = .defaultBinding(for: .buttonEast)

        // D-Pad: Octave & Inversion Shifts
        bindings[.octaveUp] = .defaultBinding(for: .dpadUp)
        bindings[.octaveDown] = .defaultBinding(for: .dpadDown)
        bindings[.voicingNext] = .defaultBinding(for: .dpadRight)
        bindings[.voicingPrevious] = .defaultBinding(for: .dpadLeft)

        // Centre button toggles Solo mode
        bindings[.soloModeToggle] = .defaultBinding(for: .buttonCenter)

        // System
        bindings[.panic] = .defaultBinding(for: .buttonOptions)

        return ControlScheme(
            id: "xpi_turntablist",
            name: "Turntablist Chops",
            description: "DJ deck mapping: stab the left stick vertically for fader-style chops, ride the right stick horizontally to scratch pitch, cut with the left trigger like a crossfader, and fire the right trigger for full strums.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .responsive,
            triggerFeel: .firm,
            haptics: .normal,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    // MARK: - 16. First Timer

    /// Deliberately minimal starter scheme: three inputs to make music instantly.
    public static var firstTimer: ControlScheme {
        var bindings: [SemanticMusicalAction: PhysicalControlBinding] = [:]

        // The three essentials
        bindings[.harmonyNavigate2D] = .defaultBinding(for: .leftStick2D)
        bindings[.primaryExcitation] = PhysicalControlBinding(input: .rightStickY, digitalBehavior: .fixedFull)
        bindings[.voiceDegree1] = .defaultBinding(for: .buttonSouth)

        // Panic escape hatch
        bindings[.panic] = .defaultBinding(for: .buttonOptions)

        return ControlScheme(
            id: "xpi_first_timer",
            name: "First Timer",
            description: "Three-input starter layout: steer the left stick to choose a chord, sweep the right stick down to strum, and tap ✕ to pluck the root. Everything else is intentionally unmapped until you are ready.",
            isBuiltIn: true,
            version: 1,
            bindings: bindings,
            stickFeel: .responsive,
            triggerFeel: .soft,
            haptics: .subtle,
            isMotionEnabled: false,
            isLeftRightSwapped: false
        )
    }

    /// All factory built-in schemes.
    public static var allBuiltIn: [ControlScheme] {
        [
            xpiPerformance, xpiClassic, lowFatigue, leftHandedPerformance, oneHandLeft, oneHandRight,
            arcadeFightStick, racingWheelCruise, flightDeckHOTAS, rhythmPadCompact,
            fingerDrummer, bassGrooveLab, ambientDrift, gyroTheremin, turntablistChops, firstTimer,
        ]
    }
}
