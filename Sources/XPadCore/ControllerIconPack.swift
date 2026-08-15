import Foundation

/// Unique identifier for every controller element (face buttons, shoulders, triggers, rhythm inputs, and niche controls).
public enum GlyphKey: String, Codable, CaseIterable, Sendable {
    // MARK: - PlayStation Glyphs
    case psCross = "ps_cross"
    case psCircle = "ps_circle"
    case psSquare = "ps_square"
    case psTriangle = "ps_triangle"
    case psL1 = "ps_l1"
    case psR1 = "ps_r1"
    case psL2 = "ps_l2"
    case psR2 = "ps_r2"
    case psL3 = "ps_l3"
    case psR3 = "ps_r3"
    case psTouchpad = "ps_touchpad"
    case psCreate = "ps_create"
    case psOptions = "ps_options"
    case psHome = "ps_home"
    case psMute = "ps_mute"

    // MARK: - Xbox Glyphs
    case xboxA = "xbox_a"
    case xboxB = "xbox_b"
    case xboxX = "xbox_x"
    case xboxY = "xbox_y"
    case xboxLB = "xbox_lb"
    case xboxRB = "xbox_rb"
    case xboxLT = "xbox_lt"
    case xboxRT = "xbox_rt"
    case xboxLS = "xbox_ls"
    case xboxRS = "xbox_rs"
    case xboxView = "xbox_view"
    case xboxMenu = "xbox_menu"
    case xboxShare = "xbox_share"
    case xboxGuide = "xbox_guide"
    case xboxPaddle1 = "xbox_p1"
    case xboxPaddle2 = "xbox_p2"
    case xboxPaddle3 = "xbox_p3"
    case xboxPaddle4 = "xbox_p4"

    // MARK: - Nintendo Glyphs
    case nintendoA = "nintendo_a"
    case nintendoB = "nintendo_b"
    case nintendoX = "nintendo_x"
    case nintendoY = "nintendo_y"
    case nintendoL = "nintendo_l"
    case nintendoR = "nintendo_r"
    case nintendoZL = "nintendo_zl"
    case nintendoZR = "nintendo_zr"
    case nintendoMinus = "nintendo_minus"
    case nintendoPlus = "nintendo_plus"
    case nintendoHome = "nintendo_home"
    case nintendoCapture = "nintendo_capture"

    // MARK: - Steam Deck Glyphs
    case steamTrackpadL = "steam_trackpad_l"
    case steamTrackpadR = "steam_trackpad_r"
    case steamL4 = "steam_l4"
    case steamL5 = "steam_l5"
    case steamR4 = "steam_r4"
    case steamR5 = "steam_r5"
    case steamQuickAccess = "steam_qam"

    // MARK: - Rhythm: Guitar Hero / Rock Band
    case guitarGreenFret = "guitar_green"
    case guitarRedFret = "guitar_red"
    case guitarYellowFret = "guitar_yellow"
    case guitarBlueFret = "guitar_blue"
    case guitarOrangeFret = "guitar_orange"
    case guitarStrumUp = "guitar_strum_up"
    case guitarStrumDown = "guitar_strum_down"
    case guitarWhammy = "guitar_whammy"
    case guitarTilt = "guitar_tilt"

    // MARK: - Rhythm: Beatmania IIDX / DJ DAO
    case beatmaniaTurntable = "iidx_turntable"
    case beatmaniaKey1 = "iidx_key_1"
    case beatmaniaKey2 = "iidx_key_2"
    case beatmaniaKey3 = "iidx_key_3"
    case beatmaniaKey4 = "iidx_key_4"
    case beatmaniaKey5 = "iidx_key_5"
    case beatmaniaKey6 = "iidx_key_6"
    case beatmaniaKey7 = "iidx_key_7"
    case beatmaniaVEFX = "iidx_vefx"

    // MARK: - Rhythm: Sound Voltex (SDVX)
    case sdvxVolL = "sdvx_vol_l"
    case sdvxVolR = "sdvx_vol_r"
    case sdvxBtA = "sdvx_bt_a"
    case sdvxBtB = "sdvx_bt_b"
    case sdvxBtC = "sdvx_bt_c"
    case sdvxBtD = "sdvx_bt_d"
    case sdvxFxL = "sdvx_fx_l"
    case sdvxFxR = "sdvx_fx_r"

    // MARK: - Rhythm: Pop'n Music
    case popnWhite1 = "popn_w1"
    case popnYellow1 = "popn_y1"
    case popnGreen1 = "popn_g1"
    case popnBlue1 = "popn_b1"
    case popnRed = "popn_red"
    case popnBlue2 = "popn_b2"
    case popnGreen2 = "popn_g2"
    case popnYellow2 = "popn_y2"
    case popnWhite2 = "popn_w2"

    // MARK: - Rhythm: Taiko no Tatsujin
    case taikoDonLeft = "taiko_don_l"
    case taikoDonRight = "taiko_don_r"
    case taikoKaLeft = "taiko_ka_l"
    case taikoKaRight = "taiko_ka_r"

    // MARK: - Rhythm: Dance Mat / DDR
    case danceLeft = "dance_left"
    case danceDown = "dance_down"
    case danceUp = "dance_up"
    case danceRight = "dance_right"

    // MARK: - Flight Sim HOTAS
    case flightStickPitch = "flight_pitch"
    case flightStickRoll = "flight_roll"
    case flightStickTwist = "flight_twist"
    case flightHatSwitch = "flight_hat"
    case flightTrigger = "flight_trigger"
    case flightThrottle = "flight_throttle"
    case flightWeaponRelease = "flight_weapon"

    // MARK: - Racing Wheel & Pedals
    case wheelSteering = "wheel_steer"
    case wheelPaddleL = "wheel_paddle_l"
    case wheelPaddleR = "wheel_paddle_r"
    case pedalThrottle = "pedal_throttle"
    case pedalBrake = "pedal_brake"
    case pedalClutch = "pedal_clutch"
    case handbrake = "handbrake"

    // MARK: - Arcade Fight Stick
    case arcadeStick = "arcade_stick"
    case arcadeLP = "arcade_lp"
    case arcadeMP = "arcade_mp"
    case arcadeHP = "arcade_hp"
    case arcadeLK = "arcade_lk"
    case arcadeMK = "arcade_mk"
    case arcadeHK = "arcade_hk"
    case arcadeThumbJump = "arcade_jump"

    // MARK: - Common Generic D-Pad & Sticks
    case dpadUp = "dpad_up"
    case dpadDown = "dpad_down"
    case dpadLeft = "dpad_left"
    case dpadRight = "dpad_right"
    case leftStick = "left_stick"
    case rightStick = "right_stick"
}

/// Visual styling and metadata for an individual controller glyph.
public struct ControllerGlyphSpec: Codable, Sendable {
    public let key: GlyphKey
    public let shortLabel: String
    public let fullTitle: String
    public let sfSymbol: String
    public let brandColorHex: String
    public let isAnalog: Bool
    public let musicalRoleHint: String

    public init(
        key: GlyphKey,
        shortLabel: String,
        fullTitle: String,
        sfSymbol: String,
        brandColorHex: String,
        isAnalog: Bool = false,
        musicalRoleHint: String = ""
    ) {
        self.key = key
        self.shortLabel = shortLabel
        self.fullTitle = fullTitle
        self.sfSymbol = sfSymbol
        self.brandColorHex = brandColorHex
        self.isAnalog = isAnalog
        self.musicalRoleHint = musicalRoleHint
    }
}

/// Comprehensive icon pack definitions across standard and rhythm/niche controllers.
public struct ControllerIconPack: Sendable {
    public let name: String
    public let brandAccentHex: String
    public let glyphs: [GlyphKey: ControllerGlyphSpec]

    public init(name: String, brandAccentHex: String, specs: [ControllerGlyphSpec]) {
        self.name = name
        self.brandAccentHex = brandAccentHex
        var dict: [GlyphKey: ControllerGlyphSpec] = [:]
        for spec in specs {
            dict[spec.key] = spec
        }
        self.glyphs = dict
    }

    public func glyph(for key: GlyphKey) -> ControllerGlyphSpec {
        glyphs[key] ?? ControllerGlyphSpec(
            key: key,
            shortLabel: key.rawValue,
            fullTitle: key.rawValue,
            sfSymbol: "circle",
            brandColorHex: "#999999",
            musicalRoleHint: "Input"
        )
    }

    // MARK: - Predefined Packs

    public static let playStation = ControllerIconPack(
        name: "PlayStation DualSense",
        brandAccentHex: "#0070D1",
        specs: [
            ControllerGlyphSpec(key: .psCross, shortLabel: "✕", fullTitle: "Cross Button", sfSymbol: "multiply.circle.fill", brandColorHex: "#2E6DB4", musicalRoleHint: "Root / Tonic"),
            ControllerGlyphSpec(key: .psCircle, shortLabel: "○", fullTitle: "Circle Button", sfSymbol: "circle.fill", brandColorHex: "#D9383A", musicalRoleHint: "5th / Tension"),
            ControllerGlyphSpec(key: .psSquare, shortLabel: "□", fullTitle: "Square Button", sfSymbol: "square.fill", brandColorHex: "#CC4398", musicalRoleHint: "3rd / Colour"),
            ControllerGlyphSpec(key: .psTriangle, shortLabel: "△", fullTitle: "Triangle Button", sfSymbol: "triangle.fill", brandColorHex: "#1EB881", musicalRoleHint: "7th / Leading"),
            ControllerGlyphSpec(key: .psL1, shortLabel: "L1", fullTitle: "L1 Shoulder", sfSymbol: "l1.rectangle.roundedbottom.fill", brandColorHex: "#CCCCCC", musicalRoleHint: "Harmonic Layer Down"),
            ControllerGlyphSpec(key: .psR1, shortLabel: "R1", fullTitle: "R1 Shoulder", sfSymbol: "r1.rectangle.roundedbottom.fill", brandColorHex: "#CCCCCC", musicalRoleHint: "Harmonic Layer Up"),
            ControllerGlyphSpec(key: .psL2, shortLabel: "L2", fullTitle: "L2 Trigger", sfSymbol: "l2.rectangle.roundedtop.fill", brandColorHex: "#0070D1", isAnalog: true, musicalRoleHint: "Palm Mute / Decay"),
            ControllerGlyphSpec(key: .psR2, shortLabel: "R2", fullTitle: "R2 Trigger", sfSymbol: "r2.rectangle.roundedtop.fill", brandColorHex: "#0070D1", isAnalog: true, musicalRoleHint: "MPE Expression / Filter"),
            ControllerGlyphSpec(key: .psL3, shortLabel: "L3", fullTitle: "L3 Stick Click", sfSymbol: "l.joystick.press.down.fill", brandColorHex: "#888888", musicalRoleHint: "Inversion Shift"),
            ControllerGlyphSpec(key: .psR3, shortLabel: "R3", fullTitle: "R3 Stick Click", sfSymbol: "r.joystick.press.down.fill", brandColorHex: "#888888", musicalRoleHint: "Arp Ratchet"),
            ControllerGlyphSpec(key: .psTouchpad, shortLabel: "PAD", fullTitle: "Touchpad Surface", sfSymbol: "hand.tap.fill", brandColorHex: "#555555", isAnalog: true, musicalRoleHint: "2D Timbre Sweep (CC74)"),
            ControllerGlyphSpec(key: .dpadUp, shortLabel: "▲", fullTitle: "D-Pad Up", sfSymbol: "dpad.up.fill", brandColorHex: "#777777", musicalRoleHint: "Octave +1"),
            ControllerGlyphSpec(key: .dpadDown, shortLabel: "▼", fullTitle: "D-Pad Down", sfSymbol: "dpad.down.fill", brandColorHex: "#777777", musicalRoleHint: "Octave -1"),
            ControllerGlyphSpec(key: .dpadLeft, shortLabel: "◀", fullTitle: "D-Pad Left", sfSymbol: "dpad.left.fill", brandColorHex: "#777777", musicalRoleHint: "Scale Root Prev"),
            ControllerGlyphSpec(key: .dpadRight, shortLabel: "▶", fullTitle: "D-Pad Right", sfSymbol: "dpad.right.fill", brandColorHex: "#777777", musicalRoleHint: "Scale Root Next"),
            ControllerGlyphSpec(key: .leftStick, shortLabel: "L", fullTitle: "Harmonic Stick", sfSymbol: "l.joystick.tilt.left.fill", brandColorHex: "#00A2FF", isAnalog: true, musicalRoleHint: "Harmonic Wheel Polar Selection"),
            ControllerGlyphSpec(key: .rightStick, shortLabel: "R", fullTitle: "Strum Stick", sfSymbol: "r.joystick.tilt.right.fill", brandColorHex: "#00E5A3", isAnalog: true, musicalRoleHint: "Virtual Guitar Strum")
        ]
    )

    public static let xbox = ControllerIconPack(
        name: "Xbox Wireless Controller",
        brandAccentHex: "#107C10",
        specs: [
            ControllerGlyphSpec(key: .xboxA, shortLabel: "A", fullTitle: "A Button", sfSymbol: "a.circle.fill", brandColorHex: "#107C10", musicalRoleHint: "Root / Tonic"),
            ControllerGlyphSpec(key: .xboxB, shortLabel: "B", fullTitle: "B Button", sfSymbol: "b.circle.fill", brandColorHex: "#E81123", musicalRoleHint: "5th / Dominant"),
            ControllerGlyphSpec(key: .xboxX, shortLabel: "X", fullTitle: "X Button", sfSymbol: "x.circle.fill", brandColorHex: "#0078D7", musicalRoleHint: "3rd / Subdominant"),
            ControllerGlyphSpec(key: .xboxY, shortLabel: "Y", fullTitle: "Y Button", sfSymbol: "y.circle.fill", brandColorHex: "#FFB900", musicalRoleHint: "7th / Leading"),
            ControllerGlyphSpec(key: .xboxLB, shortLabel: "LB", fullTitle: "Left Bumper", sfSymbol: "lb.rectangle.roundedbottom.fill", brandColorHex: "#CCCCCC", musicalRoleHint: "Harmonic Layer Down"),
            ControllerGlyphSpec(key: .xboxRB, shortLabel: "RB", fullTitle: "Right Bumper", sfSymbol: "rb.rectangle.roundedbottom.fill", brandColorHex: "#CCCCCC", musicalRoleHint: "Harmonic Layer Up"),
            ControllerGlyphSpec(key: .xboxLT, shortLabel: "LT", fullTitle: "Left Trigger", sfSymbol: "lt.rectangle.roundedtop.fill", brandColorHex: "#107C10", isAnalog: true, musicalRoleHint: "Palm Mute / Decay"),
            ControllerGlyphSpec(key: .xboxRT, shortLabel: "RT", fullTitle: "Right Trigger", sfSymbol: "rt.rectangle.roundedtop.fill", brandColorHex: "#107C10", isAnalog: true, musicalRoleHint: "MPE Expression"),
            ControllerGlyphSpec(key: .xboxLS, shortLabel: "LS", fullTitle: "Left Stick Click", sfSymbol: "l.joystick.press.down.fill", brandColorHex: "#666666", musicalRoleHint: "Inversion Shift"),
            ControllerGlyphSpec(key: .xboxRS, shortLabel: "RS", fullTitle: "Right Stick Click", sfSymbol: "r.joystick.press.down.fill", brandColorHex: "#666666", musicalRoleHint: "Arp Ratchet"),
            ControllerGlyphSpec(key: .xboxPaddle1, shortLabel: "P1", fullTitle: "Rear Paddle 1", sfSymbol: "p1.button.horizontal.fill", brandColorHex: "#888888", musicalRoleHint: "Sustain Hold"),
            ControllerGlyphSpec(key: .xboxPaddle2, shortLabel: "P2", fullTitle: "Rear Paddle 2", sfSymbol: "p2.button.horizontal.fill", brandColorHex: "#888888", musicalRoleHint: "Glide Portamento"),
            ControllerGlyphSpec(key: .xboxPaddle3, shortLabel: "P3", fullTitle: "Rear Paddle 3", sfSymbol: "p3.button.horizontal.fill", brandColorHex: "#888888", musicalRoleHint: "Bass Stabs"),
            ControllerGlyphSpec(key: .xboxPaddle4, shortLabel: "P4", fullTitle: "Rear Paddle 4", sfSymbol: "p4.button.horizontal.fill", brandColorHex: "#888888", musicalRoleHint: "Panic / Kill")
        ]
    )

    public static let nintendoSwitch = ControllerIconPack(
        name: "Nintendo Switch Pro",
        brandAccentHex: "#E60012",
        specs: [
            ControllerGlyphSpec(key: .nintendoB, shortLabel: "B", fullTitle: "B Button (Bottom)", sfSymbol: "b.circle.fill", brandColorHex: "#E60012", musicalRoleHint: "Root / Tonic"),
            ControllerGlyphSpec(key: .nintendoA, shortLabel: "A", fullTitle: "A Button (Right)", sfSymbol: "a.circle.fill", brandColorHex: "#E60012", musicalRoleHint: "5th / Dominant"),
            ControllerGlyphSpec(key: .nintendoY, shortLabel: "Y", fullTitle: "Y Button (Left)", sfSymbol: "y.circle.fill", brandColorHex: "#E60012", musicalRoleHint: "3rd / Subdominant"),
            ControllerGlyphSpec(key: .nintendoX, shortLabel: "X", fullTitle: "X Button (Top)", sfSymbol: "x.circle.fill", brandColorHex: "#E60012", musicalRoleHint: "7th / Leading"),
            ControllerGlyphSpec(key: .nintendoL, shortLabel: "L", fullTitle: "L Shoulder", sfSymbol: "l.rectangle.roundedbottom.fill", brandColorHex: "#00C3E3", musicalRoleHint: "Layer Down"),
            ControllerGlyphSpec(key: .nintendoR, shortLabel: "R", fullTitle: "R Shoulder", sfSymbol: "r.rectangle.roundedbottom.fill", brandColorHex: "#E60012", musicalRoleHint: "Layer Up"),
            ControllerGlyphSpec(key: .nintendoZL, shortLabel: "ZL", fullTitle: "ZL Trigger", sfSymbol: "zl.rectangle.roundedtop.fill", brandColorHex: "#00C3E3", isAnalog: false, musicalRoleHint: "Mute Toggle"),
            ControllerGlyphSpec(key: .nintendoZR, shortLabel: "ZR", fullTitle: "ZR Trigger", sfSymbol: "zr.rectangle.roundedtop.fill", brandColorHex: "#E60012", isAnalog: false, musicalRoleHint: "Strum Strike")
        ]
    )

    public static let guitarHero = ControllerIconPack(
        name: "Guitar Hero & Rock Band Controller",
        brandAccentHex: "#00E5A3",
        specs: [
            ControllerGlyphSpec(key: .guitarGreenFret, shortLabel: "GRN", fullTitle: "Green Fret (1)", sfSymbol: "circle.fill", brandColorHex: "#2ECC71", musicalRoleHint: "Tonic (I) / Note 1"),
            ControllerGlyphSpec(key: .guitarRedFret, shortLabel: "RED", fullTitle: "Red Fret (2)", sfSymbol: "circle.fill", brandColorHex: "#E74C3C", musicalRoleHint: "Supertonic (ii) / Note 2"),
            ControllerGlyphSpec(key: .guitarYellowFret, shortLabel: "YEL", fullTitle: "Yellow Fret (3)", sfSymbol: "circle.fill", brandColorHex: "#F1C40F", musicalRoleHint: "Mediant (iii) / Note 3"),
            ControllerGlyphSpec(key: .guitarBlueFret, shortLabel: "BLU", fullTitle: "Blue Fret (4)", sfSymbol: "circle.fill", brandColorHex: "#3498DB", musicalRoleHint: "Subdominant (IV) / Note 4"),
            ControllerGlyphSpec(key: .guitarOrangeFret, shortLabel: "ORG", fullTitle: "Orange Fret (5)", sfSymbol: "circle.fill", brandColorHex: "#E67E22", musicalRoleHint: "Dominant (V) / Note 5"),
            ControllerGlyphSpec(key: .guitarStrumUp, shortLabel: "STRUM ▲", fullTitle: "Strum Bar Up", sfSymbol: "arrow.up.and.down.circle.fill", brandColorHex: "#E0E0E0", musicalRoleHint: "Up-Strum Strike"),
            ControllerGlyphSpec(key: .guitarStrumDown, shortLabel: "STRUM ▼", fullTitle: "Strum Bar Down", sfSymbol: "arrow.up.and.down.circle.fill", brandColorHex: "#E0E0E0", musicalRoleHint: "Down-Strum Strike"),
            ControllerGlyphSpec(key: .guitarWhammy, shortLabel: "WHAMMY", fullTitle: "Whammy Bar", sfSymbol: "waveform.path.ecg", brandColorHex: "#9B59B6", isAnalog: true, musicalRoleHint: "MPE Pitch Bend / CC74 Vibrato"),
            ControllerGlyphSpec(key: .guitarTilt, shortLabel: "TILT", fullTitle: "Star Power Tilt Sensor", sfSymbol: "sparkles", brandColorHex: "#00FFFF", musicalRoleHint: "Star Power / Arpeggiator Burst")
        ]
    )

    public static let beatmaniaIIDX = ControllerIconPack(
        name: "Beatmania IIDX / DJ DAO Controller",
        brandAccentHex: "#9B59B6",
        specs: [
            ControllerGlyphSpec(key: .beatmaniaTurntable, shortLabel: "SCRATCH", fullTitle: "Optical Turntable Platter", sfSymbol: "opticaldisc.fill", brandColorHex: "#1ABC9C", isAnalog: true, musicalRoleHint: "Scratch Scrub / Tape Stop / Pitch Bend"),
            ControllerGlyphSpec(key: .beatmaniaKey1, shortLabel: "KEY 1", fullTitle: "Key 1 (White)", sfSymbol: "pianokeys", brandColorHex: "#FFFFFF", musicalRoleHint: "C / Degree 1"),
            ControllerGlyphSpec(key: .beatmaniaKey2, shortLabel: "KEY 2", fullTitle: "Key 2 (Black)", sfSymbol: "pianokeys", brandColorHex: "#333333", musicalRoleHint: "C# / Degree 2b"),
            ControllerGlyphSpec(key: .beatmaniaKey3, shortLabel: "KEY 3", fullTitle: "Key 3 (White)", sfSymbol: "pianokeys", brandColorHex: "#FFFFFF", musicalRoleHint: "D / Degree 2"),
            ControllerGlyphSpec(key: .beatmaniaKey4, shortLabel: "KEY 4", fullTitle: "Key 4 (Black)", sfSymbol: "pianokeys", brandColorHex: "#333333", musicalRoleHint: "D# / Degree 3b"),
            ControllerGlyphSpec(key: .beatmaniaKey5, shortLabel: "KEY 5", fullTitle: "Key 5 (White)", sfSymbol: "pianokeys", brandColorHex: "#FFFFFF", musicalRoleHint: "E / Degree 3"),
            ControllerGlyphSpec(key: .beatmaniaKey6, shortLabel: "KEY 6", fullTitle: "Key 6 (Black)", sfSymbol: "pianokeys", brandColorHex: "#333333", musicalRoleHint: "F# / Degree 4#"),
            ControllerGlyphSpec(key: .beatmaniaKey7, shortLabel: "KEY 7", fullTitle: "Key 7 (White)", sfSymbol: "pianokeys", brandColorHex: "#FFFFFF", musicalRoleHint: "G / Degree 5")
        ]
    )

    public static let soundVoltex = ControllerIconPack(
        name: "Sound Voltex (SDVX) Controller",
        brandAccentHex: "#FF007F",
        specs: [
            ControllerGlyphSpec(key: .sdvxVolL, shortLabel: "VOL-L", fullTitle: "Analog Rotary Knob Left (Cyan)", sfSymbol: "dial.low.fill", brandColorHex: "#00E5FF", isAnalog: true, musicalRoleHint: "Cutoff Filter Sweep (CC74)"),
            ControllerGlyphSpec(key: .sdvxVolR, shortLabel: "VOL-R", fullTitle: "Analog Rotary Knob Right (Magenta)", sfSymbol: "dial.high.fill", brandColorHex: "#FF007F", isAnalog: true, musicalRoleHint: "Resonance / FX Wetness"),
            ControllerGlyphSpec(key: .sdvxBtA, shortLabel: "BT-A", fullTitle: "BT-A Button", sfSymbol: "square.fill", brandColorHex: "#FFFFFF", musicalRoleHint: "Chord Voicing 1"),
            ControllerGlyphSpec(key: .sdvxBtB, shortLabel: "BT-B", fullTitle: "BT-B Button", sfSymbol: "square.fill", brandColorHex: "#FFFFFF", musicalRoleHint: "Chord Voicing 2"),
            ControllerGlyphSpec(key: .sdvxBtC, shortLabel: "BT-C", fullTitle: "BT-C Button", sfSymbol: "square.fill", brandColorHex: "#FFFFFF", musicalRoleHint: "Chord Voicing 3"),
            ControllerGlyphSpec(key: .sdvxBtD, shortLabel: "BT-D", fullTitle: "BT-D Button", sfSymbol: "square.fill", brandColorHex: "#FFFFFF", musicalRoleHint: "Chord Voicing 4"),
            ControllerGlyphSpec(key: .sdvxFxL, shortLabel: "FX-L", fullTitle: "FX-L Long Button (Orange)", sfSymbol: "rectangle.fill", brandColorHex: "#FF8800", musicalRoleHint: "Sub-Bass Drop"),
            ControllerGlyphSpec(key: .sdvxFxR, shortLabel: "FX-R", fullTitle: "FX-R Long Button (Orange)", sfSymbol: "rectangle.fill", brandColorHex: "#FF8800", musicalRoleHint: "Echo Swell / Repeat")
        ]
    )

    public static let taikoDrum = ControllerIconPack(
        name: "Taiko no Tatsujin Drum (Tatacon)",
        brandAccentHex: "#FF4500",
        specs: [
            ControllerGlyphSpec(key: .taikoDonLeft, shortLabel: "DON-L", fullTitle: "Don Left (Center)", sfSymbol: "circle.fill", brandColorHex: "#FF3333", musicalRoleHint: "Bass Drum / Root Note"),
            ControllerGlyphSpec(key: .taikoDonRight, shortLabel: "DON-R", fullTitle: "Don Right (Center)", sfSymbol: "circle.fill", brandColorHex: "#FF3333", musicalRoleHint: "Bass Drum / Chord Strike"),
            ControllerGlyphSpec(key: .taikoKaLeft, shortLabel: "KA-L", fullTitle: "Ka Left (Rim)", sfSymbol: "circle.circle", brandColorHex: "#3399FF", musicalRoleHint: "Snare Accent / Hi-Hat"),
            ControllerGlyphSpec(key: .taikoKaRight, shortLabel: "KA-R", fullTitle: "Ka Right (Rim)", sfSymbol: "circle.circle", brandColorHex: "#3399FF", musicalRoleHint: "Cymbal Crash / Strum Accents")
        ]
    )

    public static let danceMat = ControllerIconPack(
        name: "Dance Dance Revolution / Dance Stage",
        brandAccentHex: "#00FFCC",
        specs: [
            ControllerGlyphSpec(key: .danceLeft, shortLabel: "LEFT", fullTitle: "Left Stage Arrow", sfSymbol: "arrowshape.left.fill", brandColorHex: "#FF0099", musicalRoleHint: "Scale Degree 4 (IV)"),
            ControllerGlyphSpec(key: .danceDown, shortLabel: "DOWN", fullTitle: "Down Stage Arrow", sfSymbol: "arrowshape.down.fill", brandColorHex: "#00E5FF", musicalRoleHint: "Tonic (I)"),
            ControllerGlyphSpec(key: .danceUp, shortLabel: "UP", fullTitle: "Up Stage Arrow", sfSymbol: "arrowshape.up.fill", brandColorHex: "#00FF66", musicalRoleHint: "Dominant (V)"),
            ControllerGlyphSpec(key: .danceRight, shortLabel: "RIGHT", fullTitle: "Right Stage Arrow", sfSymbol: "arrowshape.right.fill", brandColorHex: "#FFCC00", musicalRoleHint: "Relative Minor (vi)")
        ]
    )

    public static let flightStick = ControllerIconPack(
        name: "Flight Sim HOTAS & Flight Stick",
        brandAccentHex: "#FF9900",
        specs: [
            ControllerGlyphSpec(key: .flightStickPitch, shortLabel: "PITCH", fullTitle: "Joystick Pitch (Y-Axis)", sfSymbol: "airplane", brandColorHex: "#3498DB", isAnalog: true, musicalRoleHint: "Harmonic Brightness / Cutoff"),
            ControllerGlyphSpec(key: .flightStickRoll, shortLabel: "ROLL", fullTitle: "Joystick Roll (X-Axis)", sfSymbol: "airplane", brandColorHex: "#3498DB", isAnalog: true, musicalRoleHint: "Stereo Pan / Harmonic Risk"),
            ControllerGlyphSpec(key: .flightStickTwist, shortLabel: "TWIST", fullTitle: "Z-Axis Rudder Twist", sfSymbol: "arrow.triangle.2.circlepath", brandColorHex: "#E67E22", isAnalog: true, musicalRoleHint: "MPE Per-Note Pitch Bend"),
            ControllerGlyphSpec(key: .flightHatSwitch, shortLabel: "POV HAT", fullTitle: "8-Way POV Hat Switch", sfSymbol: "dpad.fill", brandColorHex: "#9B59B6", musicalRoleHint: "Chord Inversion / Mode Switcher"),
            ControllerGlyphSpec(key: .flightTrigger, shortLabel: "TRIGGER", fullTitle: "Dual-Stage Trigger", sfSymbol: "target", brandColorHex: "#E74C3C", musicalRoleHint: "Velocity-Staged Chord Strike"),
            ControllerGlyphSpec(key: .flightThrottle, shortLabel: "THROTTLE", fullTitle: "Throttle Quadrant Lever", sfSymbol: "slider.vertical.3", brandColorHex: "#2ECC71", isAnalog: true, musicalRoleHint: "Master Dynamic Swell (CC11)")
        ]
    )

    public static let racingWheel = ControllerIconPack(
        name: "Racing Wheel & Pedals",
        brandAccentHex: "#E74C3C",
        specs: [
            ControllerGlyphSpec(key: .wheelSteering, shortLabel: "STEER", fullTitle: "900° Wheel Angle", sfSymbol: "steeringwheel", brandColorHex: "#E74C3C", isAnalog: true, musicalRoleHint: "Continuous Circle of Fifths / Wheel"),
            ControllerGlyphSpec(key: .wheelPaddleL, shortLabel: "SHIFT-", fullTitle: "Left Paddle Shifter (Down)", sfSymbol: "arrow.turn.down.left", brandColorHex: "#CCCCCC", musicalRoleHint: "Octave Down / Mode Prev"),
            ControllerGlyphSpec(key: .wheelPaddleR, shortLabel: "SHIFT+", fullTitle: "Right Paddle Shifter (Up)", sfSymbol: "arrow.turn.up.right", brandColorHex: "#CCCCCC", musicalRoleHint: "Octave Up / Mode Next"),
            ControllerGlyphSpec(key: .pedalThrottle, shortLabel: "GAS", fullTitle: "Throttle Pedal", sfSymbol: "gauge.with.dots.needle.100percent", brandColorHex: "#2ECC71", isAnalog: true, musicalRoleHint: "Velocity & Attack Dynamics"),
            ControllerGlyphSpec(key: .pedalBrake, shortLabel: "BRAKE", fullTitle: "Load-Cell Brake Pedal", sfSymbol: "exclamationmark.octagon.fill", brandColorHex: "#E74C3C", isAnalog: true, musicalRoleHint: "Mute / Damping Pressure"),
            ControllerGlyphSpec(key: .pedalClutch, shortLabel: "CLUTCH", fullTitle: "Clutch Pedal", sfSymbol: "slider.vertical.below.square.filled", brandColorHex: "#3498DB", isAnalog: true, musicalRoleHint: "Sustain Pedal Hold")
        ]
    )

    public static let fightStick = ControllerIconPack(
        name: "Arcade Fight Stick & Leverless (Hitbox)",
        brandAccentHex: "#FF0055",
        specs: [
            ControllerGlyphSpec(key: .arcadeStick, shortLabel: "SANWA", fullTitle: "8-Way Sanwa Balltop", sfSymbol: "circle.circle.fill", brandColorHex: "#FF0055", musicalRoleHint: "Octave / Scale Degree Selection"),
            ControllerGlyphSpec(key: .arcadeLP, shortLabel: "LP", fullTitle: "Light Punch (Button 1)", sfSymbol: "1.circle.fill", brandColorHex: "#3498DB", musicalRoleHint: "Pad 1 / Root"),
            ControllerGlyphSpec(key: .arcadeMP, shortLabel: "MP", fullTitle: "Medium Punch (Button 2)", sfSymbol: "2.circle.fill", brandColorHex: "#2ECC71", musicalRoleHint: "Pad 2 / 2nd"),
            ControllerGlyphSpec(key: .arcadeHP, shortLabel: "HP", fullTitle: "Heavy Punch (Button 3)", sfSymbol: "3.circle.fill", brandColorHex: "#E74C3C", musicalRoleHint: "Pad 3 / 3rd"),
            ControllerGlyphSpec(key: .arcadeLK, shortLabel: "LK", fullTitle: "Light Kick (Button 4)", sfSymbol: "4.circle.fill", brandColorHex: "#3498DB", musicalRoleHint: "Pad 4 / 4th"),
            ControllerGlyphSpec(key: .arcadeMK, shortLabel: "MK", fullTitle: "Medium Kick (Button 5)", sfSymbol: "5.circle.fill", brandColorHex: "#2ECC71", musicalRoleHint: "Pad 5 / 5th"),
            ControllerGlyphSpec(key: .arcadeHK, shortLabel: "HK", fullTitle: "Heavy Kick (Button 6)", sfSymbol: "6.circle.fill", brandColorHex: "#E74C3C", musicalRoleHint: "Pad 6 / 6th"),
            ControllerGlyphSpec(key: .arcadeThumbJump, shortLabel: "JUMP", fullTitle: "30mm Leverless Thumb Jump", sfSymbol: "arrow.up.circle.fill", brandColorHex: "#F1C40F", musicalRoleHint: "Bass Kick / Chord Strum Trigger")
        ]
    )

    public static let popnMusic = ControllerIconPack(
        name: "Pop'n Music 9-Button Arcade",
        brandAccentHex: "#FFCC00",
        specs: [
            ControllerGlyphSpec(key: .popnWhite1, shortLabel: "W1", fullTitle: "White 1 (Far Left)", sfSymbol: "circle.fill", brandColorHex: "#FFFFFF", musicalRoleHint: "Note 1 / Degree I"),
            ControllerGlyphSpec(key: .popnYellow1, shortLabel: "Y1", fullTitle: "Yellow 1", sfSymbol: "circle.fill", brandColorHex: "#FFD700", musicalRoleHint: "Note 2 / Degree ii"),
            ControllerGlyphSpec(key: .popnGreen1, shortLabel: "G1", fullTitle: "Green 1", sfSymbol: "circle.fill", brandColorHex: "#2ECC71", musicalRoleHint: "Note 3 / Degree iii"),
            ControllerGlyphSpec(key: .popnBlue1, shortLabel: "B1", fullTitle: "Blue 1", sfSymbol: "circle.fill", brandColorHex: "#00BFFF", musicalRoleHint: "Note 4 / Degree IV"),
            ControllerGlyphSpec(key: .popnRed, shortLabel: "RED", fullTitle: "Red (Center)", sfSymbol: "circle.fill", brandColorHex: "#FF0000", musicalRoleHint: "Center Lead / Dominant (V)"),
            ControllerGlyphSpec(key: .popnBlue2, shortLabel: "B2", fullTitle: "Blue 2", sfSymbol: "circle.fill", brandColorHex: "#00BFFF", musicalRoleHint: "Note 6 / Degree vi"),
            ControllerGlyphSpec(key: .popnGreen2, shortLabel: "G2", fullTitle: "Green 2", sfSymbol: "circle.fill", brandColorHex: "#2ECC71", musicalRoleHint: "Note 7 / Degree vii°"),
            ControllerGlyphSpec(key: .popnYellow2, shortLabel: "Y2", fullTitle: "Yellow 2", sfSymbol: "circle.fill", brandColorHex: "#FFD700", musicalRoleHint: "Note 8 / Octave"),
            ControllerGlyphSpec(key: .popnWhite2, shortLabel: "W2", fullTitle: "White 2 (Far Right)", sfSymbol: "circle.fill", brandColorHex: "#FFFFFF", musicalRoleHint: "Note 9 / Extension")
        ]
    )
}
