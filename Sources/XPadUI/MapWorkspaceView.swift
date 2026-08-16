import SwiftUI
import XPadCore
import XPadController

public struct MapWorkspaceView: View {
    public var controllerManager: ControllerManager
    @State private var selectedTab: Int = 0

    public init(controllerManager: ControllerManager) {
        self.controllerManager = controllerManager
    }

    private var state: GamepadState {
        controllerManager.currentState
    }

    private var iconPack: ControllerIconPack {
        controllerManager.controllerKind.iconPack
    }

    public var body: some View {
        HSplitView {
            // Left: Controller Visualizer & HUD
            VStack(spacing: 16) {
                // Top Header & Controller Switcher
                HStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title2)
                        .foregroundStyle(Color(hex: iconPack.brandAccentHex))

                    // Controller Kind Picker
                    Picker("Active Hardware Profile", selection: Binding(
                        get: { controllerManager.controllerKind },
                        set: { controllerManager.selectControllerKind($0) }
                    )) {
                        ForEach(ControllerCategory.allCases, id: \.self) { cat in
                            Section(header: Text(cat.rawValue)) {
                                ForEach(ControllerKind.allCases.filter { $0.category == cat }) { kind in
                                    Text(kind.rawValue).tag(kind)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 260)

                    Spacer()

                    Text(controllerManager.isConnected ? "Hardware Connected" : "Interactive Simulation")
                        .font(.caption2.bold())
                        .foregroundStyle(controllerManager.isConnected ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }

                // Dedicated Controller Visualizer based on Kind
                Group {
                    switch controllerManager.controllerKind {
                    case .guitarHero:
                        GuitarHeroVisualizerView(state: state)
                    case .soundVoltex:
                        SoundVoltexVisualizerView(state: state)
                    case .beatmaniaIIDX:
                        BeatmaniaVisualizerView(state: state)
                    case .taikoDrum:
                        TaikoDrumVisualizerView(state: state)
                    case .danceMat:
                        DanceMatVisualizerView(state: state)
                    case .flightStick:
                        FlightStickVisualizerView(state: state)
                    case .racingWheel:
                        RacingWheelVisualizerView(state: state)
                    case .fightStick:
                        FightStickVisualizerView(state: state)
                    default:
                        standardGamepadVisualizerCard
                    }
                }

                // Triggers & Shoulders Gauges (if standard)
                if controllerManager.controllerKind.category == .standard {
                    HStack(spacing: 12) {
                        AdaptiveTriggerVisualizerHUD(
                            feedbackState: controllerManager.adaptiveTriggerEngine.leftState,
                            label: "L2 (Mute / Tension)",
                            accentColor: .green
                        )
                        AdaptiveTriggerVisualizerHUD(
                            feedbackState: controllerManager.adaptiveTriggerEngine.rightState,
                            label: "R2 (Pressure / Drag)",
                            accentColor: .orange
                        )
                    }
                }
            }
            .padding()
            .frame(minWidth: 460)

            // Right: Modulation Matrix, Control Schemes, or OCDS Manager
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Picker("View Mode", selection: $selectedTab) {
                        Text("Modulation Matrix").tag(0)
                        Text("Control Schemes").tag(1)
                        Text("OCDS Profiles").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 380)

                    Spacer()

                    Text(iconPack.name)
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: iconPack.brandAccentHex))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: iconPack.brandAccentHex).opacity(0.15))
                        .clipShape(Capsule())
                }

                if selectedTab == 1 {
                    ControlSchemeSettingsView()
                } else if selectedTab == 2 {
                    OCDSProfileManagerView()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            switch controllerManager.controllerKind {
                            case .guitarHero:
                            modulationRowWithGlyph(glyph: .guitarStrumDown, source: "Strum Bar Down", dest: "Voiced Chord Strum (Down)", amount: "100%")
                            modulationRowWithGlyph(glyph: .guitarStrumUp, source: "Strum Bar Up", dest: "Voiced Chord Strum (Up)", amount: "100%")
                            modulationRowWithGlyph(glyph: .guitarWhammy, source: "Whammy Bar", dest: "MPE Pitch Dive & Timbre Swell", amount: "100%")
                            modulationRowWithGlyph(glyph: .guitarTilt, source: "Tilt Sensor", dest: "Star Power Arpeggiator Burst", amount: "100%")
                            modulationRowWithGlyph(glyph: .guitarGreenFret, source: "Green Fret (1)", dest: "Tonic (I) / Scale Degree 1", amount: "Select")
                            modulationRowWithGlyph(glyph: .guitarRedFret, source: "Red Fret (2)", dest: "Supertonic (ii) / Degree 2", amount: "Select")
                            modulationRowWithGlyph(glyph: .guitarBlueFret, source: "Blue Fret (4)", dest: "Subdominant (IV) / Degree 4", amount: "Select")
                            modulationRowWithGlyph(glyph: .guitarOrangeFret, source: "Orange Fret (5)", dest: "Dominant (V) / Degree 5", amount: "Select")

                        case .soundVoltex:
                            modulationRowWithGlyph(glyph: .sdvxVolL, source: "VOL-L Rotary Knob", dest: "MPE Timbre Filter Cutoff (CC74)", amount: "100%")
                            modulationRowWithGlyph(glyph: .sdvxVolR, source: "VOL-R Rotary Knob", dest: "Pitch Modulation / Resonance", amount: "100%")
                            modulationRowWithGlyph(glyph: .sdvxBtA, source: "BT-A Button", dest: "Progression Chord Voicing 1", amount: "100%")
                            modulationRowWithGlyph(glyph: .sdvxBtB, source: "BT-B Button", dest: "Progression Chord Voicing 2", amount: "100%")
                            modulationRowWithGlyph(glyph: .sdvxFxL, source: "FX-L Long Button", dest: "Sub-Bass Drop (-1 Octave)", amount: "100%")
                            modulationRowWithGlyph(glyph: .sdvxFxR, source: "FX-R Long Button", dest: "Echo / Delay Swell", amount: "100%")

                        case .beatmaniaIIDX:
                            modulationRowWithGlyph(glyph: .beatmaniaTurntable, source: "Optical Turntable", dest: "Scratch Scrub & Tape Stop Pitch", amount: "100%")
                            modulationRowWithGlyph(glyph: .beatmaniaKey1, source: "Key 1 (White)", dest: "Diatonic Degree 1 (C)", amount: "100%")
                            modulationRowWithGlyph(glyph: .beatmaniaKey2, source: "Key 2 (Black)", dest: "Chromatic Degree 2b (C#)", amount: "100%")
                            modulationRowWithGlyph(glyph: .beatmaniaKey3, source: "Key 3 (White)", dest: "Diatonic Degree 2 (D)", amount: "100%")

                        case .flightStick:
                            modulationRowWithGlyph(glyph: .flightThrottle, source: "Throttle Lever", dest: "Master Dynamic Swell (CC11)", amount: "100%")
                            modulationRowWithGlyph(glyph: .flightStickPitch, source: "Stick Pitch (Y)", dest: "Filter Cutoff Brightness", amount: "100%")
                            modulationRowWithGlyph(glyph: .flightStickTwist, source: "Z-Twist Rudder", dest: "MPE Per-Note Pitch Bend", amount: "100%")
                            modulationRowWithGlyph(glyph: .flightTrigger, source: "Dual-Stage Trigger", dest: "Chord Strum Strike", amount: "100%")

                        case .racingWheel:
                            modulationRowWithGlyph(glyph: .wheelSteering, source: "900° Wheel Angle", dest: "Continuous Harmonic Wheel Degree", amount: "100%")
                            modulationRowWithGlyph(glyph: .pedalThrottle, source: "Gas Pedal", dest: "Chord Strum Velocity Dynamics", amount: "100%")
                            modulationRowWithGlyph(glyph: .pedalBrake, source: "Brake Pedal", dest: "Palm Mute Damping & Decay", amount: "100%")
                            modulationRowWithGlyph(glyph: .wheelPaddleL, source: "Left Paddle Shifter", dest: "Octave Down (-1)", amount: "Step")
                            modulationRowWithGlyph(glyph: .wheelPaddleR, source: "Right Paddle Shifter", dest: "Octave Up (+1)", amount: "Step")

                        default:
                            modulationRowWithGlyph(glyph: .leftStick, source: "Left Stick Angle", dest: "Harmonic Wheel Sector", amount: "100%")
                            modulationRowWithGlyph(glyph: .leftStick, source: "Left Stick Radius", dest: "Harmonic Risk / Extensions", amount: "75%")
                            modulationRowWithGlyph(glyph: .rightStick, source: "Right Stick Velocity", dest: "Strum Dynamics & Velocity", amount: "100%")
                            modulationRowWithGlyph(glyph: .psTouchpad, source: "Touchpad Surface", dest: "2D Filter & Resonance Sweep", amount: "80%")
                        }
                    }
                }
                }
            }
            .padding()
            .frame(minWidth: 360)
        }
    }

    // MARK: - Standard Gamepad Visualizer Card
    private var standardGamepadVisualizerCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.35))
                .frame(height: 280)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))

            HStack(spacing: 40) {
                // Left Stick & D-Pad
                VStack(spacing: 16) {
                    stickVisualizer(label: "Left Stick (Harmonic Wheel)", stick: state.leftStick)
                    dpadVisualizer
                }

                // Center Gyro / IMU Status
                VStack(spacing: 10) {
                    Text("6-Axis IMU Motion")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text("Pitch: \(String(format: "%.2f", state.gyroPitch))")
                        .font(.caption.monospaced())
                    Text("Roll: \(String(format: "%.2f", state.gyroRoll))")
                        .font(.caption.monospaced())
                    Text("Yaw: \(String(format: "%.2f", state.gyroYaw))")
                        .font(.caption.monospaced())
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Right Stick & Face Buttons
                VStack(spacing: 16) {
                    faceButtonsVisualizer
                    stickVisualizer(label: "Right Stick (Strum)", stick: state.rightStick)
                }
            }
        }
    }

    private func stickVisualizer(label: String, stick: StickCoordinates) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 70, height: 70)
                Circle()
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    .frame(width: 70 * CGFloat(stick.deadzone), height: 70 * CGFloat(stick.deadzone))
                Circle()
                    .fill(Color(hex: iconPack.brandAccentHex))
                    .frame(width: 18, height: 18)
                    .offset(x: CGFloat(stick.x) * 26, y: -CGFloat(stick.y) * 26)
            }
        }
    }

    private var dpadVisualizer: some View {
        VStack(spacing: 2) {
            ControllerGlyphView(key: .dpadUp, iconPack: iconPack, isPressed: state.dpadUp, size: .mini)
            HStack(spacing: 6) {
                ControllerGlyphView(key: .dpadLeft, iconPack: iconPack, isPressed: state.dpadLeft, size: .mini)
                ControllerGlyphView(key: .dpadRight, iconPack: iconPack, isPressed: state.dpadRight, size: .mini)
            }
            ControllerGlyphView(key: .dpadDown, iconPack: iconPack, isPressed: state.dpadDown, size: .mini)
        }
    }

    private var faceButtonsVisualizer: some View {
        VStack(spacing: 2) {
            ControllerGlyphView(key: .psTriangle, iconPack: iconPack, isPressed: state.buttonY, size: .regular)
            HStack(spacing: 10) {
                ControllerGlyphView(key: .psSquare, iconPack: iconPack, isPressed: state.buttonX, size: .regular)
                ControllerGlyphView(key: .psCircle, iconPack: iconPack, isPressed: state.buttonB, size: .regular)
            }
            ControllerGlyphView(key: .psCross, iconPack: iconPack, isPressed: state.buttonA, size: .regular)
        }
    }

    private func triggerGauge(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label): \(Int(value * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ProgressView(value: value, total: 1.0)
                .tint(Color(hex: iconPack.brandAccentHex))
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func modulationRowWithGlyph(glyph: GlyphKey, source: String, dest: String, amount: String) -> some View {
        HStack(spacing: 12) {
            ControllerGlyphView(key: glyph, iconPack: iconPack, isPressed: false, size: .regular)

            VStack(alignment: .leading, spacing: 2) {
                Text(source)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("→ \(dest)")
                    .font(.caption)
                    .foregroundStyle(Color(hex: iconPack.brandAccentHex))
            }
            Spacer()
            Text(amount)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
