import SwiftUI
import XPadCore
import XPadController

/// PLAY's glanceable, state-driven controller surface.
struct ControllerPerformanceHUD: View {
    let state: ControllerState
    let controllerKind: ControllerKind
    let isConnected: Bool
    let labels: GestureHUDLabels
    let frame: PerformanceFrame?
    let instrument: InstrumentProfile
    let duoMode: DuoPerformanceMode
    let currentChord: Chord?
    let lastVelocity: UInt8
    let lastStrumDirection: StrumDirection

    private var iconPack: ControllerIconPack {
        switch controllerKind {
        case .dualSense, .dualShock4:
            return .playStation
        case .switchPro:
            return .nintendoSwitch
        default:
            // The live HUD consumes GameController's A/B/X/Y abstraction. Niche
            // packs describe specialist controls and do not carry face keys, so
            // use neutral ABXY glyphs here and keep specialist labels in MAP.
            return .xbox
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ModifierControlGroup(
                    shoulderLabel: shoulderLabels.left,
                    shoulderRole: labels.l1,
                    shoulderPressed: state.leftShoulder,
                    triggerLabel: shoulderLabels.leftTrigger,
                    triggerRole: instrument.supportsPalmMute ? labels.l2 : "Expression",
                    trigger: state.leftTrigger,
                    semanticValue: instrument.supportsPalmMute ? frame?.palmMuteAmount : nil,
                    threshold: 0.55,
                    tint: XTheme.warning
                )

                Spacer(minLength: 8)

                VStack(spacing: 5) {
                    Label(
                        duoMode == .drumsAndInstrument ? "DUO · \(instrument.family.shortName)" : instrument.family.shortName,
                        systemImage: duoMode == .drumsAndInstrument ? "square.grid.2x2.fill" : "waveform.path.ecg"
                    )
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(duoMode == .drumsAndInstrument ? XTheme.warning : XTheme.textSecondary)

                    Text(frame?.activeTechnique.playLabel ?? "READY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(frame == nil ? XTheme.textTertiary : XTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: 108)
                .padding(.top, 5)

                Spacer(minLength: 8)

                ModifierControlGroup(
                    shoulderLabel: shoulderLabels.right,
                    shoulderRole: labels.r1,
                    shoulderPressed: state.rightShoulder,
                    triggerLabel: shoulderLabels.rightTrigger,
                    triggerRole: labels.r2,
                    trigger: state.rightTrigger,
                    semanticValue: frame?.pressure.smoothed,
                    threshold: 0.10,
                    tint: XTheme.expression
                )
            }

            ViewThatFits(in: .horizontal) {
                controllerRow(scale: .expanded, showsDPad: true, spacing: 10)
                controllerRow(scale: .compact, showsDPad: true, spacing: 1)
                controllerRow(scale: .compact, showsDPad: false, spacing: 6)
            }
            .frame(maxWidth: .infinity)

            if !isConnected && !state.hasVisiblePerformanceInput {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller")
                        .foregroundStyle(XTheme.warning)
                    Text("Controller map preview")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(XTheme.textSecondary)
                    Spacer()
                    Text("Connect by USB or Bluetooth to play")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(XTheme.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(XTheme.warning.opacity(0.07), in: Capsule())
                .overlay(Capsule().stroke(XTheme.warning.opacity(0.18), lineWidth: 1))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusLarge)
                .fill(
                    LinearGradient(
                        colors: [XTheme.surfacePressed.opacity(0.94), XTheme.background.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusLarge)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func controllerRow(scale: ControllerHUDScale, showsDPad: Bool, spacing: CGFloat) -> some View {
        HStack(alignment: .center, spacing: spacing) {
            TactileStickView(
                state: state.leftStick,
                label: "L",
                role: labels.leftStick,
                tint: XTheme.primary,
                scale: scale
            )

            if showsDPad {
                TactileDPadView(state: state, scale: scale)
            }

            ExpressionCoreView(
                chordName: currentChord?.displayName ?? "—",
                technique: frame?.activeTechnique.playLabel,
                bendSemitones: frame?.bend.totalSemitones ?? 0,
                bendRange: instrument.preferredPitchBendRange,
                pressure: frame?.pressure.smoothed ?? 0,
                timbre: frame?.timbre ?? 0,
                scale: scale
            )

            TactileFaceButtonsView(
                state: state,
                iconPack: iconPack,
                controllerKind: controllerKind,
                roles: duoMode == .drumsAndInstrument ? .drums : .harmonic,
                scale: scale
            )

            TactileStickView(
                state: state.rightStick,
                label: "R",
                role: labels.rightStick,
                tint: XTheme.expression,
                showsStrings: instrument.supportsStrumming,
                direction: lastStrumDirection,
                velocity: lastVelocity,
                scale: scale
            )
        }
    }

    private var shoulderLabels: (left: String, right: String, leftTrigger: String, rightTrigger: String) {
        switch controllerKind {
        case .xbox:
            return ("LB", "RB", "LT", "RT")
        case .switchPro:
            return ("L", "R", "ZL", "ZR")
        default:
            return ("L1", "R1", "L2", "R2")
        }
    }
}

private enum ControllerHUDScale: Equatable {
    case expanded
    case compact

    var stickDiameter: CGFloat { self == .expanded ? 108 : 74 }
    var stickTravel: CGFloat { self == .expanded ? 37 : 25 }
    var dPadKey: CGFloat { self == .expanded ? 28 : 20 }
    var expressionDiameter: CGFloat { self == .expanded ? 76 : 54 }
    var expressionWidth: CGFloat { self == .expanded ? 92 : 64 }
    var glyphSize: GlyphSize { self == .expanded ? .large : .regular }
    var roleWidth: CGFloat { self == .expanded ? 52 : 38 }
}

struct PerformanceFeedbackStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var attackPulse: Double = 0

    let frame: PerformanceFrame?
    let velocity: UInt8
    let direction: StrumDirection
    let lastStrumTime: Date?
    let gestureLabel: String
    let supportsStrumming: Bool
    let stringCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(XTheme.surfacePressed)
                    .overlay(Circle().stroke(direction == .none ? XTheme.border : XTheme.primary.opacity(0.5), lineWidth: 1))
                Image(systemName: direction == .down ? "arrow.down" : direction == .up ? "arrow.up" : "minus")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(direction == .none ? XTheme.textTertiary : XTheme.primary)
                    .scaleEffect(reduceMotion ? 1 : 1 + attackPulse * 0.16)
            }
            .frame(width: 36, height: 36)

            if supportsStrumming {
                VirtualStringResponse(
                    stringCount: stringCount,
                    velocity: velocity,
                    damping: frame?.palmMuteAmount ?? 0,
                    direction: direction,
                    attackPulse: attackPulse
                )
                .frame(width: 118, height: 38)
            } else {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(XTheme.expression.opacity(0.72))
                    .frame(width: 72)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(velocity == 0 ? gestureLabel.uppercased() : "LAST \(gestureLabel.uppercased())")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(XTheme.textTertiary)
                Text(musicalResult)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(frame == nil ? XTheme.textSecondary : XTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 4)

            Text(frame?.activeTechnique.playLabel ?? attackLanguage)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(frame == nil ? XTheme.textTertiary : XTheme.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(XTheme.controlGradient, in: Capsule())
                .overlay(Capsule().stroke(frame == nil ? XTheme.border : XTheme.accent.opacity(0.30), lineWidth: 1))
        }
        .padding(12)
        .xCard(isActive: frame != nil)
        .onChange(of: lastStrumTime) { _, newValue in
            guard newValue != nil else { return }
            attackPulse = 1
            withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.24)) {
                attackPulse = 0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gesture result, \(gestureLabel)")
        .accessibilityValue("\(musicalResult), \(attackLanguage)")
    }

    private var musicalResult: String {
        if let theory = frame?.theoryExplanation { return theory }
        if let status = frame?.instrumentStatusLabel { return status }
        return supportsStrumming ? "Sweep the right stick across the strings" : "Shape the held note"
    }

    private var attackLanguage: String {
        switch velocity {
        case 0: return "Ready"
        case 1..<48: return "Last soft attack"
        case 48..<92: return "Last firm attack"
        default: return "Last strong attack"
        }
    }
}

private struct VirtualStringResponse: View {
    let stringCount: Int
    let velocity: UInt8
    let damping: Double
    let direction: StrumDirection
    let attackPulse: Double

    private var visibleStringCount: Int { min(6, max(4, stringCount == 0 ? 6 : stringCount)) }
    private var clampedDamping: Double { min(1, max(0, damping)) }
    private var attack: Double { Double(velocity) / 127 }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<visibleStringCount, id: \.self) { index in
                Capsule()
                    .fill(XTheme.primary.opacity(stringOpacity(for: index)))
                    .frame(height: 1 + attack * 1.4)
                    .scaleEffect(x: 1 - clampedDamping * 0.52, anchor: direction == .up ? .trailing : .leading)
            }
        }
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.black.opacity(0.26))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(XTheme.border, lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Virtual strings")
        .accessibilityValue("\(attackLanguage), \(dampingLanguage)")
    }

    private func stringOpacity(for index: Int) -> Double {
        let progress = Double(index) / Double(max(1, visibleStringCount - 1))
        let directional = direction == .up ? 1 - progress : progress
        return min(0.95, 0.20 + attack * 0.42 + attackPulse * (0.18 + directional * 0.22))
    }

    private var attackLanguage: String {
        switch velocity {
        case 0: return "idle"
        case 1..<48: return "last soft attack"
        case 48..<92: return "last firm attack"
        default: return "last strong attack"
        }
    }

    private var dampingLanguage: String {
        switch clampedDamping {
        case ..<0.2: return "open strings"
        case ..<0.65: return "muted strings"
        default: return "strongly damped strings"
        }
    }
}

private struct ModifierControlGroup: View {
    let shoulderLabel: String
    let shoulderRole: String
    let shoulderPressed: Bool
    let triggerLabel: String
    let triggerRole: String
    let trigger: ProcessedTriggerState
    let semanticValue: Double?
    let threshold: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            TactileShoulderControl(
                label: shoulderLabel,
                role: shoulderRole,
                isPressed: shoulderPressed,
                tint: tint
            )
            TactileTriggerControl(
                label: triggerLabel,
                role: triggerRole,
                trigger: trigger,
                semanticValue: semanticValue,
                threshold: threshold,
                tint: tint
            )
        }
        .frame(minWidth: 138, maxWidth: 190)
    }
}

private struct TactileShoulderControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let label: String
    let role: String
    let isPressed: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(isPressed ? Color.white : XTheme.textSecondary)
            Text(role)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isPressed ? Color.white.opacity(0.9) : XTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isPressed ? AnyShapeStyle(tint.opacity(0.66)) : AnyShapeStyle(XTheme.controlGradient))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isPressed ? tint : XTheme.border, lineWidth: isPressed ? 1.5 : 1)
                )
                .shadow(color: isPressed ? tint.opacity(0.30) : Color.black.opacity(0.26), radius: isPressed ? 5 : 3, y: isPressed ? 1 : 3)
        )
        .offset(y: isPressed && !reduceMotion ? 2 : 0)
        .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(role)")
        .accessibilityValue(isPressed ? "Pressed" : "Released")
    }
}

private struct TactileTriggerControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let label: String
    let role: String
    let trigger: ProcessedTriggerState
    let semanticValue: Double?
    let threshold: Double
    let tint: Color

    private var value: Double { min(1, max(0, Double(trigger.value))) }
    private var feedbackValue: Double { min(1, max(0, semanticValue ?? value)) }

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.38))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(XTheme.border, lineWidth: 1))

                Capsule()
                    .fill(Color.white.opacity(value >= threshold ? 0.74 : 0.18))
                    .frame(width: 24, height: 1)
                    .offset(y: CGFloat(8 + threshold * 13))

                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), value > 0.05 ? tint.opacity(0.82) : XTheme.surfaceHover],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(value > 0.05 ? tint : Color.white.opacity(0.12), lineWidth: value > 0.05 ? 1.5 : 1)
                    )
                    .frame(width: 30, height: CGFloat(24 - value * 6))
                    .offset(y: CGFloat(3 + value * 10))
                    .shadow(color: value > 0.05 ? tint.opacity(0.32) : Color.black.opacity(0.28), radius: 4, y: 3)

                Text(label)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(value > 0.42 ? Color.white : XTheme.textSecondary)
                    .offset(y: CGFloat(8 + value * 8))
            }
            .frame(width: 36, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(role)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(value > 0.05 ? tint : XTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(feedbackLanguage)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(XTheme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(XTheme.controlGradient, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(value > 0.1 ? tint.opacity(0.45) : XTheme.border, lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: trigger.isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(role)")
        .accessibilityValue("\(Int(feedbackValue * 100)) percent")
    }

    private var feedbackLanguage: String {
        switch feedbackValue {
        case ..<0.08: return "At rest"
        case ..<0.42: return "Light touch"
        case ..<0.78: return "Engaged"
        default: return "Full travel"
        }
    }
}

private struct TactileStickView: View {
    let state: ProcessedStickState
    let label: String
    let role: String
    let tint: Color
    var showsStrings: Bool = false
    var direction: StrumDirection = .none
    var velocity: UInt8 = 0
    let scale: ControllerHUDScale

    private var diameter: CGFloat { scale.stickDiameter }
    private var travel: CGFloat { scale.stickTravel }
    private var center: CGFloat { diameter / 2 }
    private var radius: Double { min(1, max(0, Double(state.radius))) }
    private var xOffset: CGFloat { CGFloat(cos(state.angle) * radius) * travel }
    private var yOffset: CGFloat { CGFloat(-sin(state.angle) * radius) * travel }
    private var rawOffsets: (x: CGFloat, y: CGFloat) {
        let rawX = Double(state.rawX)
        let rawY = Double(state.rawY)
        let rawMagnitude = hypot(rawX, rawY)
        let scale = rawMagnitude > 1 ? 1 / rawMagnitude : 1
        return (CGFloat(rawX * scale) * travel, CGFloat(-rawY * scale) * travel)
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [XTheme.surfaceElevated, Color.black.opacity(0.72)],
                            center: .center,
                            startRadius: 2,
                            endRadius: diameter / 2
                        )
                    )
                    .overlay(Circle().stroke(state.isNearEdge ? tint.opacity(0.75) : XTheme.border, lineWidth: state.isNearEdge ? 1.5 : 1))

                Circle()
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
                    .frame(width: diameter * 0.30, height: diameter * 0.30)

                if showsStrings {
                    VStack(spacing: scale == .expanded ? 8 : 6) {
                        ForEach(0..<6, id: \.self) { index in
                            Capsule()
                                .fill(index == activeStringIndex && radius > 0.1 ? tint.opacity(0.72) : Color.white.opacity(0.07))
                                .frame(width: diameter * 0.65, height: index == activeStringIndex && radius > 0.1 ? 2 : 1)
                        }
                    }
                } else {
                    Path { path in
                        path.move(to: CGPoint(x: center, y: diameter * 0.14))
                        path.addLine(to: CGPoint(x: center, y: diameter * 0.86))
                        path.move(to: CGPoint(x: diameter * 0.14, y: center))
                        path.addLine(to: CGPoint(x: diameter * 0.86, y: center))
                    }
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
                    .frame(width: diameter, height: diameter)
                }

                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: scale == .expanded ? 13 : 10, height: scale == .expanded ? 13 : 10)
                    .offset(x: rawOffsets.x, y: rawOffsets.y)

                Circle()
                    .trim(from: 0, to: radius)
                    .stroke(tint.opacity(0.48), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.88), tint],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: scale == .expanded ? 19 : 14
                        )
                    )
                    .frame(
                        width: state.isNearEdge ? (scale == .expanded ? 25 : 18) : (scale == .expanded ? 21 : 15),
                        height: state.isNearEdge ? (scale == .expanded ? 25 : 18) : (scale == .expanded ? 21 : 15)
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1))
                    .shadow(color: tint.opacity(radius * 0.55), radius: 7)
                    .offset(x: xOffset, y: yOffset)

                Text(label)
                    .font(.system(size: scale == .expanded ? 11 : 9, weight: .black, design: .rounded))
                    .foregroundStyle(XTheme.textTertiary)
                    .offset(y: diameter * 0.32)
            }
            .frame(width: diameter, height: diameter)

            Text(role)
                .font(.system(size: scale == .expanded ? 11 : 9, weight: .semibold))
                .foregroundStyle(radius > 0.05 ? tint : XTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(width: diameter)

            if label == "R" {
                Text(velocity == 0 ? "Awaiting gesture" : "Last \(direction.rawValue) · \(velocity)")
                    .font(.system(size: scale == .expanded ? 9 : 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(velocity > 0 ? XTheme.textSecondary : XTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) stick, \(role)")
        .accessibilityValue(state.isInDeadzone ? "Centered" : "\(Int(radius * 100)) percent deflection")
    }

    private var activeStringIndex: Int {
        let normalizedY = min(1, max(0, (Double(state.y) + 1) * 0.5))
        return min(5, max(0, Int((1 - normalizedY) * 5.999)))
    }
}

private struct TactileDPadView: View {
    let state: ControllerState
    let scale: ControllerHUDScale

    var body: some View {
        VStack(spacing: 1) {
            DPadKey(symbol: "chevron.up", isPressed: state.dpadUp, dimension: scale.dPadKey)
            HStack(spacing: 1) {
                DPadKey(symbol: "chevron.left", isPressed: state.dpadLeft, dimension: scale.dPadKey)
                RoundedRectangle(cornerRadius: 4)
                    .fill(XTheme.surfacePressed)
                    .frame(width: scale.dPadKey, height: scale.dPadKey)
                DPadKey(symbol: "chevron.right", isPressed: state.dpadRight, dimension: scale.dPadKey)
            }
            DPadKey(symbol: "chevron.down", isPressed: state.dpadDown, dimension: scale.dPadKey)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Directional pad")
        .accessibilityValue(activeDirection)
    }

    private var activeDirection: String {
        var directions: [String] = []
        if state.dpadUp { directions.append("Up") }
        if state.dpadDown { directions.append("Down") }
        if state.dpadLeft { directions.append("Left") }
        if state.dpadRight { directions.append("Right") }
        return directions.isEmpty ? "Centered" : directions.joined(separator: " ")
    }
}

private struct DPadKey: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let symbol: String
    let isPressed: Bool
    let dimension: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: dimension > 20 ? 10 : 8, weight: .black))
            .foregroundStyle(isPressed ? Color.white : XTheme.textTertiary)
            .frame(width: dimension, height: dimension)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        isPressed
                            ? AnyShapeStyle(XTheme.primary.opacity(0.72))
                            : AnyShapeStyle(XTheme.controlGradient)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(isPressed ? XTheme.primary : XTheme.border, lineWidth: 1))
                    .shadow(color: isPressed ? XTheme.primary.opacity(0.28) : Color.black.opacity(0.22), radius: 3, y: isPressed ? 1 : 2)
            )
            .offset(y: isPressed && !reduceMotion ? 1 : 0)
    }
}

private struct ExpressionCoreView: View {
    let chordName: String
    let technique: String?
    let bendSemitones: Double
    let bendRange: Double
    let pressure: Double
    let timbre: Double
    let scale: ControllerHUDScale

    private var bendFraction: Double {
        guard bendRange > 0 else { return 0 }
        return min(1, max(-1, bendSemitones / bendRange))
    }

    private var clampedPressure: Double { min(1, max(0, pressure)) }
    private var clampedTimbre: Double { min(1, max(0, timbre)) }

    var body: some View {
        VStack(spacing: 5) {
            Text(chordName)
                .font(.system(size: scale == .expanded ? 18 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(XTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.38))
                    .overlay(Circle().stroke(XTheme.border, lineWidth: 1))
                Circle()
                    .trim(from: 0, to: clampedTimbre)
                    .stroke(XTheme.expression.opacity(0.72), style: StrokeStyle(lineWidth: scale == .expanded ? 4 : 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)
                Circle()
                    .fill(XTheme.primaryGradient)
                    .frame(
                        width: (scale == .expanded ? 25 : 18) + clampedPressure * (scale == .expanded ? 17 : 12),
                        height: (scale == .expanded ? 25 : 18) + clampedPressure * (scale == .expanded ? 17 : 12)
                    )
                    .shadow(color: XTheme.accent.opacity(clampedPressure * 0.55), radius: 8)
                    .offset(x: CGFloat(bendFraction) * (scale == .expanded ? 18 : 12))
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1, height: scale == .expanded ? 46 : 32)
            }
            .frame(width: scale.expressionDiameter, height: scale.expressionDiameter)

            Text(technique ?? "Expression")
                .font(.system(size: scale == .expanded ? 10 : 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(technique == nil ? XTheme.textTertiary : XTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(width: scale.expressionWidth)
        }
        .frame(width: scale.expressionWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Expression monitor, \(chordName)")
        .accessibilityValue("Bend \(bendSemitones, specifier: "%.1f") semitones, pressure \(Int(clampedPressure * 100)) percent, timbre \(Int(clampedTimbre * 100)) percent")
    }
}

private struct TactileFaceButtonsView: View {
    let state: ControllerState
    let iconPack: ControllerIconPack
    let controllerKind: ControllerKind
    let roles: FaceRoleLabels
    let scale: ControllerHUDScale

    private var glyphs: FaceGlyphSet { FaceGlyphSet(controllerKind: controllerKind) }

    var body: some View {
        VStack(spacing: scale == .expanded ? 4 : 2) {
            FaceRoleButton(key: glyphs.top, role: roles.top, isPressed: state.buttonY, iconPack: iconPack, scale: scale)
            HStack(spacing: scale == .expanded ? 12 : 8) {
                FaceRoleButton(key: glyphs.left, role: roles.left, isPressed: state.buttonX, iconPack: iconPack, scale: scale)
                FaceRoleButton(key: glyphs.right, role: roles.right, isPressed: state.buttonB, iconPack: iconPack, scale: scale)
            }
            FaceRoleButton(key: glyphs.bottom, role: roles.bottom, isPressed: state.buttonA, iconPack: iconPack, scale: scale)
        }
    }
}

private struct FaceRoleLabels {
    let bottom: String
    let right: String
    let left: String
    let top: String

    /// Matches InstrumentPerformanceEngine's current chord-role interpretation.
    static let harmonic = FaceRoleLabels(bottom: "Root", right: "7th", left: "3rd", top: "5th")
    /// Geometry-based Duo mapping; printed glyphs remain native to the controller.
    static let drums = FaceRoleLabels(bottom: "Kick", right: "Open", left: "Snare", top: "Hat")
}

private struct FaceRoleButton: View {
    let key: GlyphKey
    let role: String
    let isPressed: Bool
    let iconPack: ControllerIconPack
    let scale: ControllerHUDScale

    var body: some View {
        VStack(spacing: 1) {
            ControllerGlyphView(key: key, iconPack: iconPack, isPressed: isPressed, size: scale.glyphSize)
                .accessibilityHidden(true)
            Text(role)
                .font(.system(size: scale == .expanded ? 10 : 8.5, weight: .semibold))
                .foregroundStyle(isPressed ? XTheme.textPrimary : XTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: scale.roleWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(iconPack.glyph(for: key).fullTitle), \(role)")
        .accessibilityValue(isPressed ? "Pressed" : "Released")
    }
}

extension ControllerState {
    var hasVisiblePerformanceInput: Bool {
        leftStick.radius > 0.001
            || rightStick.radius > 0.001
            || leftTrigger.value > 0.001
            || rightTrigger.value > 0.001
            || leftShoulder
            || rightShoulder
            || buttonA
            || buttonB
            || buttonX
            || buttonY
            || dpadUp
            || dpadDown
            || dpadLeft
            || dpadRight
            || leftStickButton
            || rightStickButton
            || touchpadActive
            || hasMotion
    }
}

private struct FaceGlyphSet {
    let bottom: GlyphKey
    let right: GlyphKey
    let left: GlyphKey
    let top: GlyphKey

    init(controllerKind: ControllerKind) {
        switch controllerKind {
        case .dualSense, .dualShock4:
            (bottom, right, left, top) = (.psCross, .psCircle, .psSquare, .psTriangle)
        case .switchPro:
            (bottom, right, left, top) = (.nintendoB, .nintendoA, .nintendoY, .nintendoX)
        default:
            (bottom, right, left, top) = (.xboxA, .xboxB, .xboxX, .xboxY)
        }
    }
}
