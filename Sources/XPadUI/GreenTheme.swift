import SwiftUI

/// XPadInput green-themed design system.
public struct XTheme {
    // MARK: - Primary Colors
    
    public static let primary = Color(hue: 0.38, saturation: 0.85, brightness: 0.72)
    public static let primaryLight = Color(hue: 0.38, saturation: 0.55, brightness: 0.88)
    public static let primaryDark = Color(hue: 0.38, saturation: 0.90, brightness: 0.45)
    public static let accent = Color(hue: 0.35, saturation: 0.90, brightness: 0.82)
    public static let primaryMuted = Color(hue: 0.38, saturation: 0.20, brightness: 0.25)
    public static let emerald = primary
    
    // MARK: - Surface Colors
    
    public static let background = Color(hue: 0.38, saturation: 0.08, brightness: 0.10)
    public static let surface = Color(hue: 0.38, saturation: 0.06, brightness: 0.14)
    public static let cardBackground = surface
    public static let surfaceElevated = Color(hue: 0.38, saturation: 0.05, brightness: 0.18)
    public static let surfaceHover = Color(hue: 0.38, saturation: 0.10, brightness: 0.22)
    public static let surfacePressed = Color(hue: 0.38, saturation: 0.14, brightness: 0.11)
    
    // MARK: - Text
    
    public static let textPrimary = Color.white.opacity(0.92)
    public static let textSecondary = Color.white.opacity(0.60)
    /// Supporting copy and compact control labels. Kept above small-text contrast
    /// thresholds on every declared dark surface.
    public static let textTertiary = Color.white.opacity(0.52)
    
    // MARK: - Musical State Colors
    
    public static let stable = Color(hue: 0.38, saturation: 0.80, brightness: 0.72)
    public static let natural = Color(hue: 0.48, saturation: 0.65, brightness: 0.70)
    public static let strong = Color(hue: 0.12, saturation: 0.70, brightness: 0.80)
    public static let colourful = Color(hue: 0.75, saturation: 0.55, brightness: 0.75)
    public static let tense = Color(hue: 0.02, saturation: 0.70, brightness: 0.75)
    
    // MARK: - Functional
    
    public static let recording = Color(hue: 0.0, saturation: 0.80, brightness: 0.80)
    public static let midiActivity = Color(hue: 0.38, saturation: 1.0, brightness: 1.0)
    public static let expression = Color(hue: 0.52, saturation: 0.78, brightness: 0.92)
    public static let warning = Color(hue: 0.10, saturation: 0.78, brightness: 0.92)
    public static let controllerConnected = Color(hue: 0.38, saturation: 0.80, brightness: 0.80)
    public static let controllerDisconnected = Color.white.opacity(0.3)
    
    // MARK: - Borders
    
    public static let border = Color.white.opacity(0.08)
    public static let borderActive = Color(hue: 0.38, saturation: 0.70, brightness: 0.60)
    
    // MARK: - Gradient
    
    public static let primaryGradient = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let subtleGradient = LinearGradient(
        colors: [surface, surfaceElevated],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let backgroundGradient = subtleGradient

    public static let cardGradient = LinearGradient(
        colors: [surfaceElevated.opacity(0.82), surface.opacity(0.98)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let controlGradient = LinearGradient(
        colors: [Color.white.opacity(0.055), Color.white.opacity(0.015)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Shadows
    
    public static let glowShadow = Color(hue: 0.38, saturation: 1.0, brightness: 0.7).opacity(0.3)
    public static let ambientShadow = Color.black.opacity(0.32)
    
    // MARK: - Tension Color
    
    public static func tensionColor(_ tension: Double) -> Color {
        let hue = 0.38 - tension * 0.38 // Green → Red
        let saturation = 0.5 + tension * 0.4
        let brightness = 0.7 + tension * 0.15
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    // MARK: - Corner Radius
    
    public static let radiusSmall: CGFloat = 6
    public static let radiusMedium: CGFloat = 10
    public static let radiusLarge: CGFloat = 16

    // MARK: - Spacing & Strokes

    public static let space4: CGFloat = 4
    public static let space8: CGFloat = 8
    public static let space12: CGFloat = 12
    public static let space16: CGFloat = 16
    public static let space24: CGFloat = 24
    public static let space32: CGFloat = 32
    public static let strokeSubtle: CGFloat = 1
    public static let strokeActive: CGFloat = 1.5

    // MARK: - Typography

    public static let controlLabelFont = Font.system(size: 11, weight: .semibold)
    public static let metadataFont = Font.system(size: 10, weight: .medium)
    public static let diagnosticFont = Font.system(size: 10, weight: .medium, design: .monospaced)
    
    // MARK: - Animation
    
    public static let springAnimation  = Animation.spring(response: 0.35, dampingFraction: 0.70)
    public static let quickAnimation   = Animation.easeOut(duration: 0.15)
    public static let feedbackFast     = Animation.easeOut(duration: 0.09)
    public static let transitionShort  = Animation.easeOut(duration: 0.18)
    /// Playful overshoot spring — use for icon bounces and toggle flips.
    public static let bouncy           = Animation.spring(response: 0.30, dampingFraction: 0.52)
    /// Crisp immediate spring with tiny tail — use for tab selections.
    public static let snappy           = Animation.spring(response: 0.22, dampingFraction: 0.80)
    /// Fade + slight upward drift — use for surface appearances.
    public static let glassIn          = Animation.easeOut(duration: 0.22)
}

// MARK: - View Modifiers

public struct XCardModifier: ViewModifier {
    public var isActive: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                    .fill(XTheme.cardGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                            .stroke(isActive ? XTheme.borderActive : XTheme.border, lineWidth: 1)
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(isActive ? 0.11 : 0.055))
                            .frame(height: 1)
                            .padding(.horizontal, 12)
                            .padding(.top, 1)
                    }
                    .shadow(color: XTheme.ambientShadow, radius: isActive ? 14 : 9, y: isActive ? 8 : 5)
            )
    }
}

/// A compact physical-feeling button treatment for performance controls.
public struct XTactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var isActive: Bool
    public var activeColor: Color

    public init(isActive: Bool = false, activeColor: Color = XTheme.primary) {
        self.isActive = isActive
        self.activeColor = activeColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                    .fill(
                        configuration.isPressed
                            ? AnyShapeStyle(XTheme.surfacePressed)
                            : (isActive
                                ? AnyShapeStyle(activeColor.opacity(0.16))
                                : AnyShapeStyle(XTheme.controlGradient))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                            .stroke(
                                isActive ? activeColor.opacity(0.62) : Color.white.opacity(0.09),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isActive ? activeColor.opacity(0.22) : Color.black.opacity(0.22),
                        radius: configuration.isPressed ? 1 : 4,
                        y: configuration.isPressed ? 1 : 3
                    )
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : XTheme.feedbackFast, value: configuration.isPressed)
    }
}

public struct XGlowModifier: ViewModifier {
    public var isActive: Bool
    public var color: Color = XTheme.primary
    
    public func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: 12)
            .shadow(color: isActive ? color.opacity(0.2) : .clear, radius: 24)
    }
}

// MARK: - XPulseModifier

/// Heartbeat-glow modifier. Emits two concentric rings that expand and fade
/// continuously while `isActive` is true. Layout-safe: pure overlay.
public struct XPulseModifier: ViewModifier {
    public var isActive: Bool
    public var color: Color
    public var speed: Double       // 1.0 = ~1.2 s cycle
    public var rings: Int          // 1 or 2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse1 = false
    @State private var pulse2 = false

    public init(isActive: Bool, color: Color = XTheme.primary, speed: Double = 1.0, rings: Int = 1) {
        self.isActive = isActive
        self.color = color
        self.speed = speed
        self.rings = rings
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    GeometryReader { geo in
                        let d = max(geo.size.width, geo.size.height)
                        ZStack {
                            pulseRing(scale: pulse1 ? 2.1 : 1.0, opacity: pulse1 ? 0 : 0.55, d: d)
                                .animation(.easeOut(duration: 1.1 / speed).repeatForever(autoreverses: false), value: pulse1)
                            if rings >= 2 {
                                pulseRing(scale: pulse2 ? 1.8 : 1.0, opacity: pulse2 ? 0 : 0.35, d: d)
                                    .animation(.easeOut(duration: 1.1 / speed).delay(0.45).repeatForever(autoreverses: false), value: pulse2)
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .onAppear  { if isActive && !reduceMotion { pulse1 = true; pulse2 = true } }
            .onChange(of: isActive) { _, active in
                if active && !reduceMotion { pulse1 = true; pulse2 = true }
                else { pulse1 = false; pulse2 = false }
            }
    }

    private func pulseRing(scale: CGFloat, opacity: Double, d: CGFloat) -> some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .frame(width: d, height: d)
            .scaleEffect(scale)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

// MARK: - XShimmerModifier

/// A subtle left-to-right shimmer sweep. Layout-safe: uses `mask` not frame changes.
public struct XShimmerModifier: ViewModifier {
    public var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    public func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12), .clear],
                        startPoint: .init(x: phase, y: 0),
                        endPoint:   .init(x: phase + 0.5, y: 0)
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                            phase = 1.5
                        }
                    }
                }
            }
    }
}

// MARK: - XRippleModifier

/// A one-shot ring that expands and fades each time `trigger` changes.
/// `trigger` should be a value that changes each time the effect is desired
/// (e.g. an incrementing Int, a Bool toggle, or a Date).
public struct XRippleModifier: ViewModifier {
    public var trigger: AnyHashable
    public var color: Color
    public var size: CGFloat      // diameter of the ring at peak
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0.8
    @State private var ringID: UUID = UUID()

    public init(trigger: AnyHashable, color: Color = XTheme.primary, size: CGFloat = 48) {
        self.trigger = trigger
        self.color = color
        self.size = size
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    Circle()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: size, height: size)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .id(ringID)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                ringID   = UUID()
                scale    = 0.4
                opacity  = 0.8
                withAnimation(.easeOut(duration: 0.55)) {
                    scale   = 1.8
                    opacity = 0
                }
            }
    }
}

// MARK: - View Extension

public extension View {
    func xCard(isActive: Bool = false) -> some View {
        modifier(XCardModifier(isActive: isActive))
    }
    
    func xGlow(isActive: Bool, color: Color = XTheme.primary) -> some View {
        modifier(XGlowModifier(isActive: isActive, color: color))
    }

    func xPulse(isActive: Bool, color: Color = XTheme.primary, speed: Double = 1.0, rings: Int = 1) -> some View {
        modifier(XPulseModifier(isActive: isActive, color: color, speed: speed, rings: rings))
    }

    func xShimmer(isActive: Bool) -> some View {
        modifier(XShimmerModifier(isActive: isActive))
    }

    func xRipple<H: Hashable>(trigger: H, color: Color = XTheme.primary, size: CGFloat = 48) -> some View {
        modifier(XRippleModifier(trigger: AnyHashable(trigger), color: color, size: size))
    }
}
