import SwiftUI

/// Reusable PLAY-surface motion: hover, press, selection, and musical content changes.
/// Live stick/trigger *position* must stay outside these tokens (see DESIGN.md §9.3).

// MARK: - Hover + press chrome for musical pads

struct XMusicalPadChrome<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var isSelected: Bool
    var isPressed: Bool
    var tint: Color
    var cornerRadius: CGFloat
    @ViewBuilder var content: Content

    init(
        isSelected: Bool,
        isPressed: Bool,
        tint: Color = XTheme.primary,
        cornerRadius: CGFloat = XTheme.radiusSmall,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isPressed = isPressed
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(stroke, lineWidth: isSelected ? XTheme.strokeActive : XTheme.strokeSubtle)
                    )
            )
            .shadow(
                color: isSelected ? tint.opacity(0.24) : Color.black.opacity(isHovering ? 0.22 : 0.10),
                radius: isSelected ? 10 : (isHovering ? 6 : 2),
                y: isPressed ? 1 : (isHovering ? 3 : 1)
            )
            .scaleEffect(scale)
            .offset(y: hoverLift)
            .onHover { isHovering = $0 }
            .animation(reduceMotion ? nil : XTheme.feedbackFast, value: isPressed)
            .animation(reduceMotion ? nil : XTheme.hoverAnimation, value: isHovering)
            .animation(reduceMotion ? nil : XTheme.transitionShort, value: isSelected)
    }

    private var fill: AnyShapeStyle {
        if isPressed {
            return AnyShapeStyle(XTheme.surfacePressed)
        }
        if isSelected {
            return AnyShapeStyle(tint.opacity(0.26))
        }
        if isHovering {
            return AnyShapeStyle(XTheme.surfaceHover)
        }
        return AnyShapeStyle(XTheme.surface)
    }

    private var stroke: Color {
        if isSelected { return tint }
        if isHovering { return tint.opacity(0.45) }
        return XTheme.border
    }

    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }
        if isPressed { return 0.97 }
        if isSelected { return 1.025 }
        return 1
    }

    private var hoverLift: CGFloat {
        isHovering && !isSelected && !isPressed && !reduceMotion ? -1 : 0
    }
}

/// Button style for diatonic pads, progression blocks, and similar musical tiles.
public struct XMusicalPadButtonStyle: ButtonStyle {
    var isSelected: Bool
    var tint: Color
    var cornerRadius: CGFloat

    public init(
        isSelected: Bool,
        tint: Color = XTheme.primary,
        cornerRadius: CGFloat = XTheme.radiusSmall
    ) {
        self.isSelected = isSelected
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        XMusicalPadChrome(
            isSelected: isSelected,
            isPressed: configuration.isPressed,
            tint: tint,
            cornerRadius: cornerRadius
        ) {
            configuration.label
        }
    }
}

// MARK: - Compact hover surface (tabs, chips)

struct XHoverFillModifier: ViewModifier {
    var isSelected: Bool
    var tint: Color
    var cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(isSelected ? tint : (isHovering ? tint.opacity(0.40) : XTheme.border), lineWidth: 1)
                    )
            )
            .onHover { isHovering = $0 }
            .animation(reduceMotion ? nil : XTheme.hoverAnimation, value: isHovering)
            .animation(reduceMotion ? nil : XTheme.transitionShort, value: isSelected)
    }

    private var fill: Color {
        if isSelected { return tint.opacity(0.18) }
        if isHovering { return XTheme.surfaceHover }
        return XTheme.surface.opacity(0.6)
    }
}

struct XMusicalContentModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var value: Value

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .contentTransition(.opacity)
                .animation(XTheme.transitionShort, value: value)
        }
    }
}

/// Restrained status pulse for LIVE / connected cues. Essential position
/// feedback is never gated on this animation.
struct XLivePulseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isActive: Bool
    var color: Color

    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .opacity(pulseOpacity)
            .shadow(color: isActive ? color.opacity(0.45) : .clear, radius: isActive ? 5 : 0)
            .onAppear { phase = true }
            .animation(
                isActive && !reduceMotion
                    ? .easeInOut(duration: 1.15).repeatForever(autoreverses: true)
                    : nil,
                value: phase
            )
    }

    private var pulseOpacity: Double {
        if !isActive || reduceMotion { return 1 }
        return phase ? 0.58 : 1
    }
}

extension View {
    func xHoverFill(
        isSelected: Bool,
        tint: Color = XTheme.primary,
        cornerRadius: CGFloat = XTheme.radiusSmall
    ) -> some View {
        modifier(XHoverFillModifier(isSelected: isSelected, tint: tint, cornerRadius: cornerRadius))
    }

    func xMusicalContent<Value: Equatable>(_ value: Value) -> some View {
        modifier(XMusicalContentModifier(value: value))
    }

    func xLivePulse(isActive: Bool, color: Color = XTheme.controllerConnected) -> some View {
        modifier(XLivePulseModifier(isActive: isActive, color: color))
    }
}
