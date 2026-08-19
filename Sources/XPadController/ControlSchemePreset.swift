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

    /// All factory built-in schemes.
    public static var allBuiltIn: [ControlScheme] {
        [xpiPerformance, xpiClassic, lowFatigue, leftHandedPerformance, oneHandLeft, oneHandRight]
    }
}
