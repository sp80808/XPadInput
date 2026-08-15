import SwiftUI
import XPadCore

public enum GlyphSize {
    case mini    // 18x18 (Pill / compact list)
    case regular // 26x26 (HUD / standard buttons)
    case large   // 38x38 (Hero visualizers)

    var dimension: CGFloat {
        switch self {
        case .mini: return 18
        case .regular: return 26
        case .large: return 38
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .mini: return 9
        case .regular: return 12
        case .large: return 16
        }
    }
}

/// A styled vector glyph badge for any gamepad, rhythm controller, or niche control element.
public struct ControllerGlyphView: View {
    public let key: GlyphKey
    public let iconPack: ControllerIconPack
    public var isPressed: Bool
    public var size: GlyphSize
    public var showTooltip: Bool

    public init(
        key: GlyphKey,
        iconPack: ControllerIconPack = .playStation,
        isPressed: Bool = false,
        size: GlyphSize = .regular,
        showTooltip: Bool = false
    ) {
        self.key = key
        self.iconPack = iconPack
        self.isPressed = isPressed
        self.size = size
        self.showTooltip = showTooltip
    }

    private var spec: ControllerGlyphSpec {
        iconPack.glyph(for: key)
    }

    private var glyphColor: Color {
        Color(hex: spec.brandColorHex)
    }

    public var body: some View {
        ZStack {
            // Glow shadow when pressed
            if isPressed {
                Circle()
                    .fill(glyphColor.opacity(0.4))
                    .frame(width: size.dimension + 8, height: size.dimension + 8)
                    .blur(radius: 4)
            }

            // Outer ring / pill
            Circle()
                .fill(isPressed ? glyphColor : Color.black.opacity(0.45))
                .frame(width: size.dimension, height: size.dimension)
                .overlay(
                    Circle()
                        .stroke(isPressed ? Color.white : glyphColor.opacity(0.7), lineWidth: isPressed ? 1.5 : 1)
                )

            // Inner Symbol / Label
            Text(spec.shortLabel)
                .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(isPressed ? Color.white : glyphColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: size.dimension, height: size.dimension)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .help(showTooltip ? "\(spec.fullTitle): \(spec.musicalRoleHint)" : "")
    }
}

// MARK: - Color Hex Initializer
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
