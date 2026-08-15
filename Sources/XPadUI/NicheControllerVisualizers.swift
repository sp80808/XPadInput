import SwiftUI
import XPadCore
import XPadController

// MARK: - Guitar Hero Visualizer
public struct GuitarHeroVisualizerView: View {
    public let state: GamepadState
    public var onFretToggled: ((Int) -> Void)?
    public var onStrumTriggered: ((StrumDirection) -> Void)?

    public init(state: GamepadState, onFretToggled: ((Int) -> Void)? = nil, onStrumTriggered: ((StrumDirection) -> Void)? = nil) {
        self.state = state
        self.onFretToggled = onFretToggled
        self.onStrumTriggered = onStrumTriggered
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Guitar Hero / Rock Band Fretboard")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            // 5 Fret Buttons on Guitar Neck
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(white: 0.15), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))

                HStack(spacing: 20) {
                    fretButton(label: "GRN (I)", colorHex: "#2ECC71", isPressed: state.fret1 || state.buttonA, index: 1)
                    fretButton(label: "RED (ii)", colorHex: "#E74C3C", isPressed: state.fret2 || state.buttonB, index: 2)
                    fretButton(label: "YEL (iii)", colorHex: "#F1C40F", isPressed: state.fret3 || state.buttonY, index: 3)
                    fretButton(label: "BLU (IV)", colorHex: "#3498DB", isPressed: state.fret4 || state.buttonX, index: 4)
                    fretButton(label: "ORG (V)", colorHex: "#E67E22", isPressed: state.fret5 || state.leftShoulder, index: 5)
                }
            }

            // Strum Bar & Whammy Gauge
            HStack(spacing: 30) {
                // Strum Bar
                VStack(spacing: 6) {
                    Text("Strum Bar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 2) {
                        Button {
                            onStrumTriggered?(.up)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.caption.bold())
                                .frame(width: 80, height: 20)
                                .background(state.strumUp || state.dpadUp ? Color.green : Color.white.opacity(0.1))
                                .foregroundStyle(state.strumUp || state.dpadUp ? Color.black : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onStrumTriggered?(.down)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .frame(width: 80, height: 20)
                                .background(state.strumDown || state.dpadDown ? Color.green : Color.white.opacity(0.1))
                                .foregroundStyle(state.strumDown || state.dpadDown ? Color.black : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Whammy Bar Gauge
                VStack(alignment: .leading, spacing: 4) {
                    Text("Whammy Pitch Bend: \(Int(state.whammy * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ProgressView(value: state.whammy, total: 1.0)
                        .tint(.purple)
                        .frame(width: 140)
                }

                // Star Power / Tilt
                VStack(alignment: .leading, spacing: 4) {
                    Text("Star Power Tilt: \(Int(state.tiltSensor * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ProgressView(value: state.tiltSensor, total: 1.0)
                        .tint(.cyan)
                        .frame(width: 100)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func fretButton(label: String, colorHex: String, isPressed: Bool, index: Int) -> some View {
        Button {
            onFretToggled?(index)
        } label: {
            VStack(spacing: 3) {
                Circle()
                    .fill(isPressed ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.25))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Color(hex: colorHex), lineWidth: 2))
                    .shadow(color: isPressed ? Color(hex: colorHex) : .clear, radius: 8)

                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isPressed ? Color.white : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sound Voltex (SDVX) Visualizer
public struct SoundVoltexVisualizerView: View {
    public let state: GamepadState

    public init(state: GamepadState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Sound Voltex (SDVX) Arcade Console")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            // Dual Analog Rotary Encoders (VOL-L & VOL-R)
            HStack(spacing: 80) {
                knobVisualizer(label: "VOL-L (Cutoff)", value: state.encoderL, colorHex: "#00E5FF")
                knobVisualizer(label: "VOL-R (Resonance)", value: state.encoderR, colorHex: "#FF007F")
            }

            // 4 BT Buttons
            HStack(spacing: 16) {
                btButton(label: "BT-A", isPressed: state.buttonX)
                btButton(label: "BT-B", isPressed: state.buttonY)
                btButton(label: "BT-C", isPressed: state.buttonB)
                btButton(label: "BT-D", isPressed: state.buttonA)
            }

            // 2 FX Long Buttons
            HStack(spacing: 40) {
                fxButton(label: "FX-L (Sub Bass)", isPressed: state.leftShoulder || state.leftTrigger > 0.5)
                fxButton(label: "FX-R (Echo Swell)", isPressed: state.rightShoulder || state.rightTrigger > 0.5)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func knobVisualizer(label: String, value: Double, colorHex: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(Color(hex: colorHex))

            ZStack {
                Circle()
                    .stroke(Color(hex: colorHex).opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)

                // Pointer needle
                Rectangle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 3, height: 24)
                    .offset(y: -12)
                    .rotationEffect(Angle(degrees: value * 150))
            }
        }
    }

    private func btButton(label: String, isPressed: Bool) -> some View {
        Text(label)
            .font(.caption.bold())
            .frame(width: 50, height: 36)
            .background(isPressed ? Color.white : Color.white.opacity(0.12))
            .foregroundStyle(isPressed ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.4), lineWidth: 1))
            .shadow(color: isPressed ? .white : .clear, radius: 6)
    }

    private func fxButton(label: String, isPressed: Bool) -> some View {
        Text(label)
            .font(.caption2.bold())
            .frame(width: 110, height: 26)
            .background(isPressed ? Color.orange : Color.orange.opacity(0.2))
            .foregroundStyle(isPressed ? Color.black : Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.orange, lineWidth: 1))
    }
}

// MARK: - Beatmania IIDX Visualizer
public struct BeatmaniaVisualizerView: View {
    public let state: GamepadState

    public init(state: GamepadState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 30) {
            // Optical Turntable Platter
            VStack(spacing: 6) {
                Text("DJ Scratch Platter")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                ZStack {
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 110, height: 110)
                        .overlay(Circle().stroke(Color.cyan.opacity(0.5), lineWidth: 2))

                    // Platter Grooves
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        .frame(width: 70, height: 70)

                    // Scratch indicator
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 4, height: 40)
                        .offset(y: -20)
                        .rotationEffect(Angle(degrees: state.turntableVelocity * 360))
                }
            }

            // 7 Keys Keyboard (4 White, 3 Black)
            VStack(spacing: 6) {
                Text("7-Key Deck (1..7)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    keyButton(label: "1", isBlack: false, isPressed: state.buttonA)
                    keyButton(label: "2", isBlack: true, isPressed: state.buttonX)
                    keyButton(label: "3", isBlack: false, isPressed: state.buttonB)
                    keyButton(label: "4", isBlack: true, isPressed: state.buttonY)
                    keyButton(label: "5", isBlack: false, isPressed: state.leftShoulder)
                    keyButton(label: "6", isBlack: true, isPressed: state.rightShoulder)
                    keyButton(label: "7", isBlack: false, isPressed: state.dpadUp)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func keyButton(label: String, isBlack: Bool, isPressed: Bool) -> some View {
        Text(label)
            .font(.caption2.bold())
            .frame(width: 28, height: isBlack ? 45 : 65)
            .background(
                isPressed
                    ? Color.cyan
                    : (isBlack ? Color(white: 0.2) : Color.white.opacity(0.85))
            )
            .foregroundStyle(isPressed ? Color.black : (isBlack ? Color.white : Color.black))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .offset(y: isBlack ? -10 : 0)
    }
}

// MARK: - Taiko Drum Visualizer
public struct TaikoDrumVisualizerView: View {
    public let state: GamepadState

    public init(state: GamepadState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text("Taiko no Tatsujin Drum (Tatacon)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ZStack {
                // Ka (Rim)
                Circle()
                    .stroke(Color.blue, lineWidth: 24)
                    .frame(width: 140, height: 140)

                // Don (Drum Head)
                Circle()
                    .fill(Color.red.opacity(state.buttonA ? 0.9 : 0.4))
                    .frame(width: 100, height: 100)
                    .overlay(Text("DON").font(.headline.bold()).foregroundStyle(.white))
            }
            .shadow(color: state.buttonA ? .red : .clear, radius: 10)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Dance Mat / DDR Visualizer
public struct DanceMatVisualizerView: View {
    public let state: GamepadState

    public init(state: GamepadState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text("Dance Stage 4-Panel Pad")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            danceArrow(direction: "arrowshape.up.fill", colorHex: "#00FF66", isPressed: state.dpadUp)
            HStack(spacing: 30) {
                danceArrow(direction: "arrowshape.left.fill", colorHex: "#FF0099", isPressed: state.dpadLeft)
                danceArrow(direction: "arrowshape.right.fill", colorHex: "#FFCC00", isPressed: state.dpadRight)
            }
            danceArrow(direction: "arrowshape.down.fill", colorHex: "#00E5FF", isPressed: state.dpadDown)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func danceArrow(direction: String, colorHex: String, isPressed: Bool) -> some View {
        Image(systemName: direction)
            .font(.title2)
            .frame(width: 44, height: 44)
            .background(isPressed ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.2))
            .foregroundStyle(isPressed ? Color.black : Color(hex: colorHex))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: colorHex), lineWidth: 1.5))
            .shadow(color: isPressed ? Color(hex: colorHex) : .clear, radius: 8)
    }
}

// MARK: - Flight Sim HOTAS Visualizer
public struct FlightStickVisualizerView: View {
    public let state: GamepadState

    public init(state: GamepadState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 30) {
            // Throttle Quadrant
            VStack(alignment: .leading, spacing: 4) {
                Text("Throttle: \(Int(state.throttle * 100))%")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                ProgressView(value: state.throttle, total: 1.0)
                    .tint(.green)
                    .frame(width: 100)
            }

            // 3D Stick Crosshair
            VStack(spacing: 4) {
                Text("3D Flight Joystick")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 90, height: 90)

                    Circle()
                        .fill(Color.orange)
                        .frame(width: 16, height: 16)
                        .offset(x: CGFloat(state.leftStick.x) * 35, y: -CGFloat(state.leftStick.y) * 35)
                }
            }

            // Rudder Twist
            VStack(alignment: .leading, spacing: 4) {
                Text("Z-Rudder Twist: \(Int(state.rudderTwist * 100))%")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                ProgressView(value: (state.rudderTwist + 1.0) / 2.0, total: 1.0)
                    .tint(.orange)
                    .frame(width: 100)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Racing Wheel Visualizer
public struct RacingWheelVisualizerView: View {
    public let state: GamepadState

    public init(state: GamepadState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 30) {
            // Steering Wheel
            VStack(spacing: 4) {
                Text("900° Steering Angle")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 6)
                        .frame(width: 90, height: 90)

                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 4, height: 30)
                        .offset(y: -30)
                        .rotationEffect(Angle(degrees: state.wheelAngle * 180))
                }
            }

            // 3 Progressive Pedals
            HStack(spacing: 16) {
                pedalGauge(label: "Clutch", value: state.pedalClutch, color: .blue)
                pedalGauge(label: "Brake", value: state.pedalBrake, color: .red)
                pedalGauge(label: "Gas", value: state.pedalGas, color: .green)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func pedalGauge(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 24, height: 60)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 24, height: CGFloat(value) * 60)
            }
        }
    }
}

// MARK: - Fight Stick Visualizer
public struct FightStickVisualizerView: View {
    public let state: GamepadState

    public init(state: GamepadState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 30) {
            // Sanwa Balltop Joystick
            VStack(spacing: 4) {
                Text("Sanwa 8-Way Stick")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 70, height: 70)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 22, height: 22)
                        .offset(x: CGFloat(state.leftStick.x) * 25, y: -CGFloat(state.leftStick.y) * 25)
                }
            }

            // 8 Arcade Buttons
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    arcadeBtn(label: "LP", isPressed: state.buttonX, color: .blue)
                    arcadeBtn(label: "MP", isPressed: state.buttonY, color: .yellow)
                    arcadeBtn(label: "HP", isPressed: state.rightShoulder, color: .red)
                    arcadeBtn(label: "3P", isPressed: state.rightTrigger > 0.5, color: .purple)
                }
                HStack(spacing: 8) {
                    arcadeBtn(label: "LK", isPressed: state.buttonA, color: .blue)
                    arcadeBtn(label: "MK", isPressed: state.buttonB, color: .yellow)
                    arcadeBtn(label: "HK", isPressed: state.leftShoulder, color: .red)
                    arcadeBtn(label: "3K", isPressed: state.leftTrigger > 0.5, color: .purple)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func arcadeBtn(label: String, isPressed: Bool, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .frame(width: 32, height: 32)
            .background(isPressed ? color : color.opacity(0.3))
            .foregroundStyle(isPressed ? Color.black : Color.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(color, lineWidth: 1.5))
    }
}
