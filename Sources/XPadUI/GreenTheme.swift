import SwiftUI

/// XPadInput — Modern Flat Design System
/// Dark-mode first. Flat surfaces, bold typography, purposeful color, subtle depth.
public struct XTheme {
    
    // MARK: - Core Palette (Dark Mode)
    
    // Brand — Emerald family, refined for UI legibility
    public static let brand = Color(hue: 0.372, saturation: 0.72, brightness: 0.78)      // #22C55E refined
    public static let brandStrong = Color(hue: 0.372, saturation: 0.85, brightness: 0.62)  // hover/active
    public static let brandSubtle = Color(hue: 0.372, saturation: 0.35, brightness: 0.38)  // backgrounds
    public static let brandMuted = Color(hue: 0.372, saturation: 0.18, brightness: 0.28)   // borders
    
    // Accent — Warm amber for warnings, recording, attention
    public static let accent = Color(hue: 0.108, saturation: 0.88, brightness: 0.85)       // #F59E0B refined
    public static let accentSubtle = Color(hue: 0.108, saturation: 0.35, brightness: 0.38)
    
    // Danger — Red for panic, errors, destructive
    public static let danger = Color(hue: 0.978, saturation: 0.78, brightness: 0.82)       // #EF4444 refined
    public static let dangerSubtle = Color(hue: 0.978, saturation: 0.35, brightness: 0.38)
    
    // Info — Cyan for MIDI, expression, technical
    public static let info = Color(hue: 0.533, saturation: 0.78, brightness: 0.82)         // #06B6D4 refined
    public static let infoSubtle = Color(hue: 0.533, saturation: 0.35, brightness: 0.38)
    
    // Purple — For harmonic tension, creative
    public static let creative = Color(hue: 0.767, saturation: 0.72, brightness: 0.78)     // #A855F7 refined
    public static let creativeSubtle = Color(hue: 0.767, saturation: 0.35, brightness: 0.38)
    
    // MARK: - Neutral Surfaces (Layered Depth)
    
    /// Base canvas — deepest layer
    public static let canvas = Color(hue: 0.372, saturation: 0.06, brightness: 0.055)      // #0D0F0E
    
    /// Elevated surface — cards, panels
    public static let surface = Color(hue: 0.372, saturation: 0.05, brightness: 0.09)       // #161A18
    
    /// Higher elevation — modals, popovers, hovered cards
    public static let surfaceRaised = Color(hue: 0.372, saturation: 0.04, brightness: 0.125) // #1E2320
    
    /// Highest — tooltips, menus, active selection
    public static let surfaceHigh = Color(hue: 0.372, saturation: 0.04, brightness: 0.16)    // #272D29
    
    /// Input fields, controls
    public static let control = Color(hue: 0.372, saturation: 0.04, brightness: 0.11)      // #1B201E

    // MARK: - Semantic Aliases (DESIGN.md §23 — canonical token layer)

    public static let background = canvas
    public static let surfaceElevated = surfaceRaised
    /// Hover lift for interactive controls (between surface and surfaceRaised)
    public static let surfaceHover = Color(hue: 0.372, saturation: 0.05, brightness: 0.13)
    /// Pressed state — one step above hover
    public static let surfacePressed = Color(hue: 0.372, saturation: 0.045, brightness: 0.155)

    /// Primary identity accent
    public static let primary = brand
    public static let primaryLight = Color(hue: 0.372, saturation: 0.62, brightness: 0.92)
    public static let emerald = brand

    // Harmonic tension spectrum (DESIGN.md §6.2)
    public static let stable = brand                                        // tonic / resolution
    public static let natural = Color(hue: 0.455, saturation: 0.70, brightness: 0.78)   // green-cyan subdominant
    public static let strong = accent                                       // amber dominant
    public static let colourful = creative                                  // violet modal colour
    public static let tense = danger                                        // warm red outside harmony

    public static let expression = info                                     // MPE bend/timbre cyan
    public static let midiActivity = info

    public static let controllerConnected = brand
    public static let controllerDisconnected = disconnected

    /// Ambient soft shadow used by floating chrome
    public static let ambientShadow = Color.black.opacity(0.35)

    // MARK: - Geometry Aliases

    public static let radiusSmall = radiusS
    public static let radiusMedium = radiusM
    public static let radiusLarge = radiusL

    public static let strokeSubtle = borderThin
    public static let borderActive = Color(hue: 0.372, saturation: 0.55, brightness: 0.55).opacity(0.65)

    // MARK: - Typography Aliases

    /// Control value text inside compact transport selectors (~28pt tall controls)
    public static let controlLabelFont = Font.system(size: 12, weight: .semibold)
    
    // MARK: - Borders & Dividers
    
    public static let border = Color.white.opacity(0.06)
    public static let borderEmphasized = Color.white.opacity(0.12)
    public static let borderBrand = Color(hue: 0.372, saturation: 0.55, brightness: 0.45).opacity(0.5)
    
    // MARK: - Text Hierarchy
    
    public static let textPrimary = Color.white.opacity(0.94)
    public static let textSecondary = Color.white.opacity(0.64)
    public static let textTertiary = Color.white.opacity(0.42)
    public static let textDisabled = Color.white.opacity(0.24)
    public static let textInverse = Color(hue: 0.372, saturation: 0.15, brightness: 0.12)   // on brand
    
    // MARK: - Semantic State Colors
    
    public static let success = brand
    public static let warning = accent
    public static let error = danger
    public static let recording = danger
    public static let midiActive = info
    public static let connected = brand
    public static let disconnected = Color.white.opacity(0.22)
    
    // Musical tension gradient (green → amber → red)
    public static func tensionColor(_ tension: Double) -> Color {
        let t = max(0, min(1, tension))
        if t < 0.33 {
            let f = t / 0.33
            return Color(hue: 0.372, saturation: 0.72 - f * 0.15, brightness: 0.78 - f * 0.08)
        } else if t < 0.66 {
            let f = (t - 0.33) / 0.33
            return Color(hue: 0.372 - f * 0.264, saturation: 0.57 + f * 0.31, brightness: 0.70 + f * 0.12)
        } else {
            let f = (t - 0.66) / 0.34
            return Color(hue: 0.108 - f * 0.13, saturation: 0.88 - f * 0.10, brightness: 0.82 - f * 0.04)
        }
    }
    
    // MARK: - Typography Scale
    
    public static let fontDisplay = Font.system(size: 32, weight: .black, design: .rounded)
    public static let fontTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    public static let fontHeadline = Font.system(size: 17, weight: .semibold, design: .rounded)
    public static let fontBody = Font.system(size: 14, weight: .regular, design: .default)
    public static let fontBodyStrong = Font.system(size: 14, weight: .medium, design: .default)
    public static let fontLabel = Font.system(size: 12, weight: .semibold, design: .default)
    public static let fontCaption = Font.system(size: 11, weight: .medium, design: .default)
    public static let fontCaptionSmall = Font.system(size: 10, weight: .medium, design: .default)
    public static let fontMicro = Font.system(size: 9, weight: .medium, design: .default)
    
    // Monospace variants
    public static let fontMonoLarge = Font.system(size: 16, weight: .bold, design: .monospaced)
    public static let fontMono = Font.system(size: 13, weight: .semibold, design: .monospaced)
    public static let fontMonoSmall = Font.system(size: 11, weight: .semibold, design: .monospaced)
    public static let fontMonoMicro = Font.system(size: 9, weight: .bold, design: .monospaced)
    public static let fontMonoTiny = Font.system(size: 8, weight: .bold, design: .monospaced)

    /// Tabular / monospaced digit typography builder for numeric readouts (preventing layout jitter)
    public static func fontMonoDigits(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
    
    // MARK: - Spacing System (4pt base)
    
    public static let space1: CGFloat = 4
    public static let space2: CGFloat = 8
    public static let space3: CGFloat = 12
    public static let space4: CGFloat = 16
    public static let space5: CGFloat = 20
    public static let space6: CGFloat = 24
    public static let space8: CGFloat = 32
    public static let space10: CGFloat = 40
    public static let space12: CGFloat = 48
    
    // MARK: - Corner Radius
    
    public static let radiusXS: CGFloat = 4
    public static let radiusS: CGFloat = 6
    public static let radiusM: CGFloat = 10
    public static let radiusL: CGFloat = 14
    public static let radiusXL: CGFloat = 20
    public static let radiusPill: CGFloat = 999
    
    // MARK: - Border Widths
    
    public static let borderHairline: CGFloat = 0.5
    public static let borderThin: CGFloat = 1
    public static let borderMedium: CGFloat = 1.5
    public static let borderBold: CGFloat = 2
    
    // MARK: - Elevation (Subtle Depth)
    
    public static let elevation1 = (color: Color.black.opacity(0.25), radius: CGFloat(2), y: CGFloat(1))
    public static let elevation2 = (color: Color.black.opacity(0.30), radius: CGFloat(6), y: CGFloat(3))
    public static let elevation3 = (color: Color.black.opacity(0.35), radius: CGFloat(12), y: CGFloat(6))
    public static let elevation4 = (color: Color.black.opacity(0.40), radius: CGFloat(20), y: CGFloat(10))
    
    // Brand-tinted elevation for active/selected
    public static let elevationBrand1 = (color: brand.opacity(0.18), radius: CGFloat(4), y: CGFloat(2))
    public static let elevationBrand2 = (color: brand.opacity(0.22), radius: CGFloat(10), y: CGFloat(4))
    
    // MARK: - Animation Curves

    public static let springUI = Animation.spring(response: 0.32, dampingFraction: 0.82)
    public static let springSnappy = Animation.spring(response: 0.22, dampingFraction: 0.78)
    public static let springBouncy = Animation.spring(response: 0.28, dampingFraction: 0.55)
    public static let easeOutFast = Animation.easeOut(duration: 0.12)
    public static let easeOut = Animation.easeOut(duration: 0.18)
    public static let easeInOut = Animation.easeInOut(duration: 0.22)
    public static let easeInOutSlow = Animation.easeInOut(duration: 0.35)

    // Motion tokens (DESIGN.md §23) — semantic timing vocabulary
    /// Tactile touch / key press response
    public static let feedbackFast = Animation.easeOut(duration: 0.09)
    /// Control hover and menu transitions
    public static let quickAnimation = Animation.easeOut(duration: 0.15)
    /// Subtle disclosure state changes
    public static let transitionShort = Animation.easeOut(duration: 0.18)
    /// Standard UI physics
    public static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.70)
    /// Playful overshoot for toggles & icon bounces
    public static let bouncy = Animation.spring(response: 0.30, dampingFraction: 0.52)
    /// Crisp immediate spring for tab selections & numeric badges
    public static let snappy = Animation.spring(response: 0.22, dampingFraction: 0.80)
    /// Surface and overlay entrances
    public static let glassIn = Animation.easeOut(duration: 0.22)
    
    // MARK: - Gradients (Restrained, Purposeful)
    
    public static let brandGradient = LinearGradient(
        colors: [brand, brandStrong],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    public static let primaryGradient = brandGradient

    public static let surfaceGradient = LinearGradient(
        colors: [surface, surfaceRaised],
        startPoint: .top, endPoint: .bottom
    )

    /// Raised strip gradient for persistent chrome (transport bar)
    public static let cardGradient = LinearGradient(
        colors: [surfaceRaised, surface],
        startPoint: .top, endPoint: .bottom
    )
    
    public static let controlGradient = LinearGradient(
        colors: [Color.white.opacity(0.06), Color.white.opacity(0.015)],
        startPoint: .top, endPoint: .bottom
    )
    
    public static let canvasGradient = LinearGradient(
        colors: [canvas, Color(hue: 0.372, saturation: 0.08, brightness: 0.07)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    
    // MARK: - Icon Sizes
    
    public static let iconXS: CGFloat = 10
    public static let iconS: CGFloat = 12
    public static let iconM: CGFloat = 16
    public static let iconL: CGFloat = 20
    public static let iconXL: CGFloat = 24
    public static let iconXXL: CGFloat = 32
}

// MARK: - View Modifiers

/// Flat card with subtle border and optional brand accent on active
public struct XCardModifier: ViewModifier {
    public var elevated: Bool = false
    public var isActive: Bool = false
    public var borderColor: Color = XTheme.border
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: XTheme.radiusM)
                    .fill(elevated ? XTheme.surfaceRaised : XTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: XTheme.radiusM)
                            .stroke(isActive ? XTheme.borderBrand : borderColor, lineWidth: XTheme.borderThin)
                    )
                    .shadow(
                        color: isActive ? XTheme.elevationBrand1.color : XTheme.elevation1.color,
                        radius: isActive ? XTheme.elevationBrand1.radius : XTheme.elevation1.radius,
                        y: isActive ? XTheme.elevationBrand1.y : XTheme.elevation1.y
                    )
            )
    }
}

/// Flat button — no gradient, clean states
public struct XButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var variant: Variant = .primary
    public var size: Size = .regular
    
    public enum Variant {
        case primary      // brand fill
        case secondary    // surface fill, brand border
        case ghost        // transparent, brand text
        case danger       // danger fill
        case subtle       // surface fill, subtle border
    }
    
    public enum Size {
        case small        // 28pt height, 10pt font
        case regular      // 36pt height, 13pt font
        case large        // 44pt height, 15pt font
    }
    
    public init(variant: Variant = .primary, size: Size = .regular) {
        self.variant = variant
        self.size = size
    }
    
    private var height: CGFloat {
        switch size { case .small: 28; case .regular: 36; case .large: 44 }
    }
    private var font: Font {
        switch size { case .small: XTheme.fontCaption; case .regular: XTheme.fontLabel; case .large: XTheme.fontBodyStrong }
    }
    private var horizontalPadding: CGFloat {
        switch size { case .small: XTheme.space3; case .regular: XTheme.space4; case .large: XTheme.space5 }
    }
    private var cornerRadius: CGFloat { XTheme.radiusS }
    
    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        let bgColor: Color
        let borderColor: Color
        let textColor: Color
        
        switch variant {
        case .primary:
            bgColor = pressed ? XTheme.brandStrong : XTheme.brand
            borderColor = .clear
            textColor = XTheme.textInverse
        case .secondary:
            bgColor = pressed ? XTheme.surfaceRaised : XTheme.surface
            borderColor = pressed ? XTheme.brandStrong : XTheme.borderBrand
            textColor = XTheme.brand
        case .ghost:
            bgColor = pressed ? XTheme.brand.opacity(0.12) : .clear
            borderColor = .clear
            textColor = pressed ? XTheme.brandStrong : XTheme.brand
        case .danger:
            bgColor = pressed ? XTheme.danger.opacity(0.85) : XTheme.danger
            borderColor = .clear
            textColor = .white
        case .subtle:
            bgColor = pressed ? XTheme.surfaceRaised : XTheme.control
            borderColor = pressed ? XTheme.borderEmphasized : XTheme.border
            textColor = XTheme.textPrimary
        }
        
        return configuration.label
            .font(font)
            .foregroundColor(isEnabled ? textColor : XTheme.textDisabled)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isEnabled ? bgColor : XTheme.control.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: variant == .secondary ? XTheme.borderThin : 0)
                    )
            )
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : XTheme.easeOutFast, value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

/// Pill toggle button for toolbar items
public struct XToolButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var isActive: Bool = false
    public var activeColor: Color = XTheme.brand
    
    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        configuration.label
            .font(XTheme.fontCaption)
            .foregroundColor(
                isActive ? XTheme.textInverse :
                pressed ? activeColor :
                XTheme.textSecondary
            )
            .padding(.horizontal, XTheme.space3)
            .padding(.vertical, XTheme.space1)
            .background(
                Capsule()
                    .fill(
                        isActive ? activeColor :
                        pressed ? activeColor.opacity(0.12) :
                        XTheme.control
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isActive ? .clear :
                                pressed ? activeColor.opacity(0.4) : XTheme.border,
                                lineWidth: XTheme.borderThin
                            )
                    )
            )
            .scaleEffect(pressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : XTheme.easeOutFast, value: configuration.isPressed)
    }
}

/// Subtle focus ring for keyboard navigation
public struct XFocusRing: ViewModifier {
    public var isFocused: Bool
    public var color: Color = XTheme.brand
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: XTheme.radiusS)
                    .stroke(isFocused ? color : .clear, lineWidth: 2)
                    .padding(2)
            )
            .animation(XTheme.easeOutFast, value: isFocused)
    }
}

// MARK: - View Extensions

public extension View {
    func xCard(elevated: Bool = false, isActive: Bool = false) -> some View {
        modifier(XCardModifier(elevated: elevated, isActive: isActive))
    }
    
    func xButton(_ variant: XButtonStyle.Variant = .primary, size: XButtonStyle.Size = .regular) -> some View {
        buttonStyle(XButtonStyle(variant: variant, size: size))
    }
    
    func xToolButton(isActive: Bool = false, color: Color = XTheme.brand) -> some View {
        buttonStyle(XToolButtonStyle(isActive: isActive, activeColor: color))
    }
    
    func xFocusRing(_ isFocused: Bool, color: Color = XTheme.brand) -> some View {
        modifier(XFocusRing(isFocused: isFocused, color: color))
    }
}

// MARK: - Purposeful Animation Modifiers (Minimal Set)

/// Subtle pulse for live/recording states — concentric rings, no shimmer
public struct XPulseModifier: ViewModifier {
    public var isActive: Bool
    public var color: Color = XTheme.brand
    public var speed: Double = 1.0
    public var rings: Int = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    public init(isActive: Bool, color: Color = XTheme.brand, speed: Double = 1.0, rings: Int = 1) {
        self.isActive = isActive; self.color = color; self.speed = speed; self.rings = max(1, rings)
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    ZStack {
                        ForEach(0..<rings, id: \.self) { ring in
                            Circle()
                                .stroke(color.opacity(ring == 0 ? 0.45 : 0.28), lineWidth: 1.5)
                                .scaleEffect(pulse ? 1.6 : 1.0)
                                .opacity(pulse ? 0 : (ring == 0 ? 0.45 : 0.25))
                                .animation(
                                    .easeOut(duration: (1.2 / speed) + Double(ring) * 0.35)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(ring) * 0.4 / speed),
                                    value: pulse
                                )
                        }
                    }
                    .onAppear { pulse = true }
                    .onChange(of: isActive) { _, v in pulse = v }
                    .allowsHitTesting(false)
                }
            }
    }
}

/// One-shot ripple on trigger change
public struct XRippleModifier: ViewModifier {
    public var trigger: AnyHashable
    public var color: Color = XTheme.brand
    public var size: CGFloat = 56
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.55
    @State private var id = UUID()
    
    public init<T: Hashable>(trigger: T, color: Color = XTheme.brand, size: CGFloat = 56) {
        self.trigger = AnyHashable(trigger); self.color = color; self.size = size
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
                        .id(id)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                id = UUID()
                scale = 0.5; opacity = 0.55
                withAnimation(.easeOut(duration: 0.45)) {
                    scale = 1.8; opacity = 0
                }
            }
    }
}

public extension View {
    func xPulse(isActive: Bool, color: Color = XTheme.brand, speed: Double = 1.0, rings: Int = 1) -> some View {
        modifier(XPulseModifier(isActive: isActive, color: color, speed: speed, rings: rings))
    }

    func xRipple<T: Hashable>(trigger: T, color: Color = XTheme.brand, size: CGFloat = 56) -> some View {
        modifier(XRippleModifier(trigger: trigger, color: color, size: size))
    }
}

// MARK: - Glow

/// Soft luminous halo for active musical feedback (stick cursor, pressed pads).
/// Static while held; no breathing loop. Suppressed under Reduce Motion.
public struct XGlowModifier: ViewModifier {
    public var isActive: Bool
    public var color: Color = XTheme.brand
    public var radius: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isActive: Bool, color: Color = XTheme.brand, radius: CGFloat = 8) {
        self.isActive = isActive
        self.color = color
        self.radius = radius
    }

    public func body(content: Content) -> some View {
        content
            .shadow(color: isActive && !reduceMotion ? color.opacity(0.45) : .clear, radius: radius)
            .shadow(color: isActive && !reduceMotion ? color.opacity(0.20) : .clear, radius: radius * 2)
            .animation(reduceMotion ? nil : XTheme.quickAnimation, value: isActive)
    }
}

public extension View {
    func xGlow(isActive: Bool, color: Color = XTheme.brand, radius: CGFloat = 8) -> some View {
        modifier(XGlowModifier(isActive: isActive, color: color, radius: radius))
    }
}

// MARK: - Tactile Quick-Control Button Style

/// Tactile style for performance quick-controls: quiet at rest, hover lift,
/// press compression, tinted wash when active. Zero layout shift.
public struct XTactileButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var isActive: Bool = false
    public var activeColor: Color = XTheme.brand
    @State private var isHovering = false

    public init(isActive: Bool = false, activeColor: Color = XTheme.brand) {
        self.isActive = isActive
        self.activeColor = activeColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion

        configuration.label
            .opacity(isEnabled ? 1 : 0.45)
            .background(
                RoundedRectangle(cornerRadius: XTheme.radiusS)
                    .fill(fill(pressed: pressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: XTheme.radiusS)
                            .stroke(border(pressed: pressed), lineWidth: XTheme.borderThin)
                    )
            )
            .scaleEffect(pressed ? 0.97 : 1)
            .onHover { hovering in
                guard isEnabled else { return }
                isHovering = hovering
            }
            .animation(reduceMotion ? nil : XTheme.feedbackFast, value: configuration.isPressed)
            .animation(reduceMotion ? nil : XTheme.quickAnimation, value: isHovering)
            .animation(reduceMotion ? nil : XTheme.quickAnimation, value: isActive)
    }

    private func fill(pressed: Bool) -> Color {
        if isActive { return activeColor.opacity(0.10) }
        if pressed { return Color.white.opacity(0.08) }
        if isHovering { return Color.white.opacity(0.05) }
        return .clear
    }

    private func border(pressed: Bool) -> Color {
        if isActive { return activeColor.opacity(0.28) }
        if pressed || isHovering { return XTheme.borderEmphasized }
        return .clear
    }
}

// MARK: - Shimmer (DESIGN.md §23)

/// Subtle horizontal highlight sweep for live/selected chrome. Purely additive,
/// loops slowly, suppressed under Reduce Motion.
public struct XShimmerModifier: ViewModifier {
    public var isActive: Bool
    public var color: Color = XTheme.brand
    public var period: Double = 2.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    public init(isActive: Bool, color: Color = XTheme.brand, period: Double = 2.4) {
        self.isActive = isActive
        self.color = color
        self.period = period
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    GeometryReader { geo in
                        let bandWidth = max(24, geo.size.width * 0.4)
                        LinearGradient(
                            colors: [.clear, color.opacity(0.16), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: bandWidth)
                        .offset(x: phase * (geo.size.width + bandWidth))
                        .blur(radius: 2)
                    }
                    .allowsHitTesting(false)
                    .clipShape(Rectangle())
                    .onAppear {
                        withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            }
    }
}

public extension View {
    func xShimmer(isActive: Bool, color: Color = XTheme.brand, period: Double = 2.4) -> some View {
        modifier(XShimmerModifier(isActive: isActive, color: color, period: period))
    }

    /// Applies monospaced digit formatting and line limit to eliminate layout jitter on rapidly changing numbers
    func xStableNumeric() -> some View {
        self
            .monospacedDigit()
            .lineLimit(1)
    }

    /// Tabular figure container ensuring a minimum width so digit width fluctuations never shift surrounding views
    func xTabular(minWidth: CGFloat, alignment: Alignment = .trailing) -> some View {
        self
            .monospacedDigit()
            .lineLimit(1)
            .frame(minWidth: minWidth, alignment: alignment)
    }
}