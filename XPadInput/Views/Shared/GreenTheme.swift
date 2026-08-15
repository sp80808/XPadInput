import SwiftUI

/// XPadInput green-themed design system.
struct XTheme {
    // MARK: - Primary Colors
    
    /// Primary green
    static let primary = Color(hue: 0.38, saturation: 0.85, brightness: 0.72)
    /// Light primary
    static let primaryLight = Color(hue: 0.38, saturation: 0.55, brightness: 0.88)
    /// Dark primary
    static let primaryDark = Color(hue: 0.38, saturation: 0.90, brightness: 0.45)
    /// Accent green (brighter)
    static let accent = Color(hue: 0.35, saturation: 0.90, brightness: 0.82)
    /// Muted green for backgrounds
    static let primaryMuted = Color(hue: 0.38, saturation: 0.20, brightness: 0.25)
    
    // MARK: - Surface Colors
    
    /// Deep background
    static let background = Color(hue: 0.38, saturation: 0.08, brightness: 0.10)
    /// Slightly elevated surface
    static let surface = Color(hue: 0.38, saturation: 0.06, brightness: 0.14)
    /// Card/panel surface
    static let surfaceElevated = Color(hue: 0.38, saturation: 0.05, brightness: 0.18)
    /// Hover state
    static let surfaceHover = Color(hue: 0.38, saturation: 0.10, brightness: 0.22)
    
    // MARK: - Text
    
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary = Color.white.opacity(0.38)
    
    // MARK: - Musical State Colors
    
    /// Tonic / Stable
    static let stable = Color(hue: 0.38, saturation: 0.80, brightness: 0.72)
    /// Subdominant / Natural
    static let natural = Color(hue: 0.48, saturation: 0.65, brightness: 0.70)
    /// Dominant / Strong
    static let strong = Color(hue: 0.12, saturation: 0.70, brightness: 0.80)
    /// Colourful / Modal
    static let colourful = Color(hue: 0.75, saturation: 0.55, brightness: 0.75)
    /// Tension / Outside
    static let tense = Color(hue: 0.02, saturation: 0.70, brightness: 0.75)
    
    // MARK: - Functional
    
    static let recording = Color(hue: 0.0, saturation: 0.80, brightness: 0.80)
    static let midiActivity = Color(hue: 0.38, saturation: 1.0, brightness: 1.0)
    static let controllerConnected = Color(hue: 0.38, saturation: 0.80, brightness: 0.80)
    static let controllerDisconnected = Color.white.opacity(0.3)
    
    // MARK: - Borders
    
    static let border = Color.white.opacity(0.08)
    static let borderActive = Color(hue: 0.38, saturation: 0.70, brightness: 0.60)
    
    // MARK: - Gradient
    
    static let primaryGradient = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let subtleGradient = LinearGradient(
        colors: [surface, surfaceElevated],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let glowGradient = RadialGradient(
        colors: [primary.opacity(0.3), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 200
    )
    
    // MARK: - Shadows
    
    static let glowShadow = Color(hue: 0.38, saturation: 1.0, brightness: 0.7).opacity(0.3)
    
    // MARK: - Tension Color
    
    /// Maps a 0.0-1.0 tension value to a color from stable green → tense red
    static func tensionColor(_ tension: Double) -> Color {
        let hue = 0.38 - tension * 0.38 // Green → Red
        let saturation = 0.5 + tension * 0.4
        let brightness = 0.7 + tension * 0.15
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    // MARK: - Corner Radius
    
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 10
    static let radiusLarge: CGFloat = 16
    
    // MARK: - Animation
    
    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let quickAnimation = Animation.easeOut(duration: 0.15)
}

// MARK: - View Modifiers

struct XCardModifier: ViewModifier {
    var isActive: Bool = false
    
    func body(content: Content) -> some View {
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

struct XGlowModifier: ViewModifier {
    var isActive: Bool
    var color: Color = XTheme.primary
    
    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: 12)
            .shadow(color: isActive ? color.opacity(0.2) : .clear, radius: 24)
    }
}

extension View {
    func xCard(isActive: Bool = false) -> some View {
        modifier(XCardModifier(isActive: isActive))
    }
    
    func xGlow(isActive: Bool, color: Color = XTheme.primary) -> some View {
        modifier(XGlowModifier(isActive: isActive, color: color))
    }
}
