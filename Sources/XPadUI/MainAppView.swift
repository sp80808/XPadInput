import SwiftUI
import XPadCore
import XPadController

/// Main content view for the unified XPI performance workstation.
/// Main content view for the unified XPI performance workstation.
public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingSettings = false
    @State private var workspaceDirection: WorkspaceTransitionDirection = .forward

    private enum WorkspaceTransitionDirection { case forward, backward }
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            let metrics = ViewportMetrics(size: geo.size)
            
            VStack(spacing: 0) {
                // Top Pro Performance Header Bar
                TopPerformanceHeaderView(onOpenSettings: { isShowingSettings = true })
                
                Divider()
                    .background(XTheme.border)
                
                // Play is the launch workspace. Practice is swapped in only after
                // an explicit request (View > Show Practice) so it never occupies
                // first-launch screenspace.
                if appState.isPracticeRequested {
                    PracticeWorkspaceView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal:   .opacity.combined(with: .move(edge: .leading))
                        ))
                } else {
                    PlayView(onOpenSettings: { isShowingSettings = true })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal:   .opacity.combined(with: .move(edge: .trailing))
                        ))
                }
                
                Divider()
                    .background(XTheme.border)
                
                // Transport Bar (Always docked at bottom)
                TransportBar()
            }
            .environment(\.viewportMetrics, metrics)
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isPracticeRequested)
        .sheet(isPresented: $isShowingSettings) {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(XTheme.primary)
                        Text("Controller & Hardware Configuration")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(XTheme.textPrimary)
                    }
                    Spacer()
                    Button("Done") {
                        isShowingSettings = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(16)
                .background(XTheme.surfaceElevated)

                Divider().overlay(XTheme.border)

                ControlSchemeSettingsView()
            }
            .frame(minWidth: 780, minHeight: 600)
        }
        .background {
            ZStack {
                XTheme.background
                RadialGradient(
                    colors: [XTheme.primary.opacity(0.14), .clear],
                    center: .topLeading,
                    startRadius: 24,
                    endRadius: 800
                )
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Top Performance Header Bar

struct TopPerformanceHeaderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.viewportMetrics) private var viewport
    var onOpenSettings: () -> Void = {}
    @State private var gearHovered = false
    @State private var connectRippleTrigger = 0
    @State private var wasConnected = false
    
    var body: some View {
        @Bindable var state = appState
        let isCompact = viewport.isCompactWidth
        
        HStack(spacing: isCompact ? 10 : 16) {
            // App Branding
            HStack(spacing: isCompact ? 6 : 8) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: isCompact ? 14 : 16, weight: .bold))
                    .foregroundColor(XTheme.primary)
                    .scaleEffect(appState.controllerManager.isConnected ? 1.04 : 1.0)
                    .animation(
                        appState.controllerManager.isConnected
                            ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                            : .easeOut(duration: 0.2),
                        value: appState.controllerManager.isConnected
                    )
                    .xGlow(isActive: appState.controllerManager.isConnected)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("XPI")
                        .font(.system(size: isCompact ? 13 : 14, weight: .black, design: .rounded))
                        .foregroundColor(XTheme.textPrimary)
                    if !isCompact {
                        Text("MPE INSTRUMENT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(XTheme.primary)
                    }
                }
            }
            
            Divider()
                .frame(height: 20)
                .background(XTheme.border)
            
            // Instrument Profile Switcher
            InstrumentSelectorView(minWidth: isCompact ? 86 : 116)
            
            Divider()
                .frame(height: 20)
                .background(XTheme.border)
            
            // Key & Scale Selectors
            HStack(spacing: isCompact ? 4 : 8) {
                KeySelectorView()
                ScaleSelectorView()
            }
            
            Spacer(minLength: 8)
            
            // Controller Hardware Status Badge
            Button {
                onOpenSettings()
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(appState.controllerManager.isConnected ? XTheme.controllerConnected : XTheme.primaryLight.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .xPulse(isActive: appState.controllerManager.isConnected, color: XTheme.controllerConnected)
                    
                    Text(controllerBadgeText(isCompact: isCompact))
                        .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
                        .foregroundColor(XTheme.textPrimary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(XTheme.textTertiary)
                }
                .padding(.horizontal, isCompact ? 7 : 10)
                .padding(.vertical, 5)
                .background(XTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            appState.controllerManager.isConnected ? XTheme.controllerConnected.opacity(0.5) : XTheme.border,
                            lineWidth: 1
                        )
                        .animation(XTheme.glassIn, value: appState.controllerManager.isConnected)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .xRipple(trigger: connectRippleTrigger, color: XTheme.controllerConnected, size: 56)
            }
            .buttonStyle(.plain)
            .help("Configure Controller Scheme, Calibrate Deadzones, and Remap Buttons")
            .onChange(of: appState.controllerManager.isConnected) { _, isConnected in
                if isConnected && !wasConnected { connectRippleTrigger += 1 }
                wasConnected = isConnected
            }
            
            // Settings Button
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(gearHovered ? XTheme.primary : XTheme.textSecondary)
                    .rotationEffect(.degrees(gearHovered ? 45 : 0))
                    .animation(XTheme.snappy, value: gearHovered)
                    .padding(6)
                    .background(XTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Open Settings")
            .onHover { gearHovered = $0 }
        }
        .padding(.horizontal, isCompact ? 10 : 16)
        .padding(.vertical, isCompact ? 6 : 8)
        .background(XTheme.surface.opacity(0.4))
    }
    
    private func controllerBadgeText(isCompact: Bool) -> String {
        guard appState.controllerManager.isConnected else {
            return isCompact ? "Sim Pad" : "Simulated Gamepad"
        }
        if isCompact {
            switch appState.controllerManager.controllerKind {
            case .dualSense: return "DualSense"
            case .dualShock4: return "DS4"
            case .xbox: return "Xbox"
            case .switchPro: return "Switch"
            case .steamDeck: return "Deck"
            case .guitarHero: return "Guitar"
            case .fightStick: return "FightStick"
            case .racingWheel: return "Wheel"
            case .flightStick: return "HOTAS"
            default: return "Gamepad"
            }
        }
        return appState.controllerManager.controllerKind.rawValue
    }
}
