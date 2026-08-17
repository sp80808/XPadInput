import SwiftUI
import XPadCore
import XPadController

/// Main content view for the unified XPI performance workstation.
public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingSettings = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Pro Performance Header Bar
            TopPerformanceHeaderView(onOpenSettings: { isShowingSettings = true })
            
            Divider()
                .background(XTheme.border)
            
            // Unified Main Play & Chord Building Stage
            PlayView(onOpenSettings: { isShowingSettings = true })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .background(XTheme.border)
            
            // Transport Bar (Always docked at bottom)
            TransportBar()
        }
        .sheet(isPresented: $isShowingSettings) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(XTheme.primary)
                        Text("Controller & Hardware Configuration")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(XTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 8)
                    Button("Done") {
                        isShowingSettings = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .fixedSize()
                }
                .padding(16)
                .background(XTheme.surfaceElevated)

                Divider().overlay(XTheme.border)

                ControlSchemeSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 720, idealWidth: 840, minHeight: 560, idealHeight: 680)
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
    var onOpenSettings: () -> Void = {}
    
    var body: some View {
        @Bindable var state = appState
        
        HStack(spacing: 16) {
            // App Branding
            HStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(XTheme.primary)
                    .xGlow(isActive: appState.controllerManager.isConnected)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("XPI")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(XTheme.textPrimary)
                    Text("MPE INSTRUMENT")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(XTheme.primary)
                }
            }
            
            Divider()
                .frame(height: 24)
                .background(XTheme.border)
            
            // Instrument Profile Switcher
            InstrumentSelectorView(minWidth: 120)
            
            Divider()
                .frame(height: 24)
                .background(XTheme.border)
            
            // Key & Scale Selectors
            HStack(spacing: 8) {
                KeySelectorView()
                ScaleSelectorView()
            }
            
            Spacer()
            
            // Controller Hardware Status Badge
            Button {
                onOpenSettings()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.controllerManager.isConnected ? XTheme.controllerConnected : XTheme.primaryLight.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .xGlow(isActive: appState.controllerManager.isConnected)
                    
                    Text(appState.controllerManager.isConnected ? appState.controllerManager.controllerKind.rawValue : "Simulated Gamepad")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(XTheme.textPrimary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(XTheme.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(XTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(XTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Configure Controller Scheme, Calibrate Deadzones, and Remap Buttons")
            
            // Settings Button
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(XTheme.textSecondary)
                    .padding(7)
                    .background(XTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Open Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(XTheme.surface.opacity(0.4))
    }
}
