import SwiftUI

// MARK: - Viewport Size Classes

/// Horizontal viewport width classifications for XPadInput.
public enum ViewportWidthClass: Sendable, Equatable, Comparable {
    case compact    // < 960 pt (split screen, compact window)
    case regular    // 960 ... 1380 pt (standard laptop / desktop window)
    case expanded   // > 1380 pt (large display / full-screen workstation)
    
    public static func from(width: CGFloat) -> ViewportWidthClass {
        if width < 960 {
            return .compact
        } else if width < 1380 {
            return .regular
        } else {
            return .expanded
        }
    }
}

/// Vertical viewport height classifications for XPadInput.
public enum ViewportHeightClass: Sendable, Equatable, Comparable {
    case compact    // < 680 pt (small laptop, tight split screen)
    case regular    // 680 ... 880 pt (standard window height)
    case expanded   // > 880 pt (tall window / external display)
    
    public static func from(height: CGFloat) -> ViewportHeightClass {
        if height < 680 {
            return .compact
        } else if height < 880 {
            return .regular
        } else {
            return .expanded
        }
    }
}

// MARK: - Viewport Metrics

/// Comprehensive viewport dimensions, size classes, and continuous dynamic scale factors.
public struct ViewportMetrics: Sendable, Equatable {
    public let size: CGSize
    public let widthClass: ViewportWidthClass
    public let heightClass: ViewportHeightClass
    
    /// Continuous linear scale factor relative to a baseline 1200x800 viewport.
    /// Clamped between 0.75 and 1.35 for stable legibility and crisp geometry.
    public let scaleFactor: CGFloat
    
    /// Dynamic left-column ratio for 2-column workspace layouts.
    public let leftColumnRatio: CGFloat
    
    /// Dynamic padding & spacing scale factor (0.7 to 1.25).
    public let spacingScale: CGFloat
    
    public init(size: CGSize = CGSize(width: 1200, height: 800)) {
        self.size = size
        self.widthClass = ViewportWidthClass.from(width: size.width)
        self.heightClass = ViewportHeightClass.from(height: size.height)
        
        let widthScale = size.width / 1200.0
        let heightScale = size.height / 800.0
        let baseScale = min(widthScale, heightScale)
        self.scaleFactor = max(0.75, min(1.35, baseScale))
        
        // Contextual left-column proportion
        switch widthClass {
        case .compact:
            self.leftColumnRatio = 0.36
        case .regular:
            self.leftColumnRatio = 0.38
        case .expanded:
            self.leftColumnRatio = 0.40
        }
        
        self.spacingScale = max(0.7, min(1.25, baseScale))
    }
    
    public var isCompactWidth: Bool { widthClass == .compact }
    public var isCompactHeight: Bool { heightClass == .compact }
    public var isCompact: Bool { isCompactWidth || isCompactHeight }
    public var isExpanded: Bool { widthClass == .expanded && heightClass == .expanded }
}

// MARK: - SwiftUI Environment Key

private struct ViewportMetricsKey: EnvironmentKey {
    static let defaultValue = ViewportMetrics()
}

public extension EnvironmentValues {
    var viewportMetrics: ViewportMetrics {
        get { self[ViewportMetricsKey.self] }
        set { self[ViewportMetricsKey.self] = newValue }
    }
}

// MARK: - Viewport Aware View Modifier & Container

public struct ViewportAwareModifier: ViewModifier {
    public func body(content: Content) -> some View {
        GeometryReader { geo in
            let metrics = ViewportMetrics(size: geo.size)
            content
                .environment(\.viewportMetrics, metrics)
        }
    }
}

public extension View {
    /// Injects `ViewportMetrics` calculated from the current geometry reader into the SwiftUI environment.
    func viewportAware() -> some View {
        self.modifier(ViewportAwareModifier())
    }
}
