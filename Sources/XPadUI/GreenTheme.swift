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
    
    public static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
    public static let quickAnimation = Animation.easeOut(duration: 0.15)
    public static let feedbackFast = Animation.easeOut(duration: 0.09)
    public static let transitionShort = Animation.easeOut(duration: 0.18)
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

public extension View {
    func xCard(isActive: Bool = false) -> some View {
        modifier(XCardModifier(isActive: isActive))
    }
    
    func xGlow(isActive: Bool, color: Color = XTheme.primary) -> some View {
        modifier(XGlowModifier(isActive: isActive, color: color))
    }
}
