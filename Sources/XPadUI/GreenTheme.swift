import SwiftUI

/// XPadInput green-themed design system.
public struct XTheme {
    // MARK: - Primary Colors
    
    public static let primary = Color(hue: 0.38, saturation: 0.85, brightness: 0.72)
    public static let primaryLight = Color(hue: 0.38, saturation: 0.55, brightness: 0.88)
    public static let primaryDark = Color(hue: 0.38, saturation: 0.90, brightness: 0.45)
    public static let accent = Color(hue: 0.35, saturation: 0.90, brightness: 0.82)
    public static let primaryMuted = Color(hue: 0.38, saturation: 0.20, brightness: 0.25)
    
    // MARK: - Surface Colors
    
    public static let background = Color(hue: 0.38, saturation: 0.08, brightness: 0.10)
    public static let surface = Color(hue: 0.38, saturation: 0.06, brightness: 0.14)
    public static let surfaceElevated = Color(hue: 0.38, saturation: 0.05, brightness: 0.18)
    public static let surfaceHover = Color(hue: 0.38, saturation: 0.10, brightness: 0.22)
    
    // MARK: - Text
    
    public static let textPrimary = Color.white.opacity(0.92)
    public static let textSecondary = Color.white.opacity(0.60)
    public static let textTertiary = Color.white.opacity(0.38)
    
    // MARK: - Musical State Colors
    
    public static let stable = Color(hue: 0.38, saturation: 0.80, brightness: 0.72)
    public static let natural = Color(hue: 0.48, saturation: 0.65, brightness: 0.70)
    public static let strong = Color(hue: 0.12, saturation: 0.70, brightness: 0.80)
    public static let colourful = Color(hue: 0.75, saturation: 0.55, brightness: 0.75)
    public static let tense = Color(hue: 0.02, saturation: 0.70, brightness: 0.75)
    
    // MARK: - Functional
    
    public static let recording = Color(hue: 0.0, saturation: 0.80, brightness: 0.80)
    public static let midiActivity = Color(hue: 0.38, saturation: 1.0, brightness: 1.0)
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
    
    // MARK: - Shadows
    
    public static let glowShadow = Color(hue: 0.38, saturation: 1.0, brightness: 0.7).opacity(0.3)
    
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
    
    // MARK: - Animation
    
    public static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
    public static let quickAnimation = Animation.easeOut(duration: 0.15)
}

// MARK: - View Modifiers

public struct XCardModifier: ViewModifier {
    public var isActive: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                    .fill(XTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                            .stroke(isActive ? XTheme.borderActive : XTheme.border, lineWidth: 1)
                    )
            )
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
