import SwiftUI
import XPadCore
import XPadController

/// Main content view for the unified XPI performance workstation.
public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingSettings = false
    @State private var workspaceDirection: WorkspaceTransitionDirection = .forward

    private enum WorkspaceTransitionDirection { case forward, backward }

    public init() {}

    public var body: some View {
        @Bindable var appState = appState
        GeometryReader { geo in
            let metrics = ViewportMetrics(size: geo.size)

            VStack(spacing: 0) {
                // Top Performance Header Bar
                TopPerformanceHeaderView(onOpenSettings: { isShowingSettings = true })

                Divider()
                    .overlay(XTheme.border)

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
                    .overlay(XTheme.border)

                // Transport Bar (toggleable / docked at bottom)
                if appState.showTransportBar {
                    TransportBar()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .environment(\.viewportMetrics, metrics)
        }
        .animation(XTheme.easeInOut, value: appState.isPracticeRequested)
        .animation(XTheme.easeInOut, value: appState.showTransportBar)
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheet()
        }
        .sheet(isPresented: $appState.showLearnHub) {
            LearnHubView()
        }
        .overlay(alignment: .trailing) {
            TutorialOverlayView()
                .padding(.trailing, 16)
                .padding(.bottom, 64)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(XTheme.glassIn, value: appState.activeTutorialMissionID)
        }
        .background {
            XTheme.canvasGradient
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Settings Sheet

private struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: XTheme.space3) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(XTheme.brand)
                    Text("Controller & Hardware Configuration")
                        .font(XTheme.fontHeadline)
                        .foregroundColor(XTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                Button("Done") { dismiss() }
                    .xButton(.primary, size: .regular)
                    .keyboardShortcut(.defaultAction)
                    .fixedSize()
            }
            .padding(XTheme.space5)
            .background(XTheme.surface)

            Divider().overlay(XTheme.border)

            ControlSchemeSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, idealWidth: 840, minHeight: 560, idealHeight: 680)
        .background(XTheme.surface)
    }
}

// MARK: - Top Performance Header Bar

struct TopPerformanceHeaderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.viewportMetrics) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onOpenSettings: () -> Void = {}
    @State private var gearHovered = false
    @State private var badgeHovered = false
    @State private var connectRippleTrigger = 0
    @State private var wasConnected = false

    var body: some View {
        @Bindable var state = appState
        let isCompact = viewport.isCompactWidth

        HStack(spacing: isCompact ? XTheme.space3 : XTheme.space4) {
            // App Branding
            HStack(spacing: isCompact ? XTheme.space2 : XTheme.space3) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: isCompact ? 16 : 18, weight: .bold))
                    .foregroundColor(XTheme.brand)
                    .scaleEffect(appState.controllerManager.isConnected ? 1.03 : 1.0)
                    .animation(
                        appState.controllerManager.isConnected
                            ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                            : XTheme.easeOut,
                        value: appState.controllerManager.isConnected
                    )
                    .xPulse(isActive: appState.controllerManager.isConnected, color: XTheme.connected)

                VStack(alignment: .leading, spacing: 0) {
                    Text("XPI")
                        .font(.system(size: isCompact ? 14 : 16, weight: .black, design: .rounded))
                        .foregroundColor(XTheme.textPrimary)
                    if !isCompact {
                        Text("MPE INSTRUMENT")
                            .font(XTheme.fontMonoTiny)
                            .foregroundColor(XTheme.brand)
                    }
                }
            }

            Divider()
                .frame(height: 20)
                .overlay(XTheme.border)

            // Instrument Profile Switcher
            InstrumentSelectorView(minWidth: isCompact ? 92 : 128)

            Divider()
                .frame(height: 20)
                .overlay(XTheme.border)

            // Key & Scale Selectors
            HStack(spacing: isCompact ? XTheme.space2 : XTheme.space3) {
                KeySelectorView()
                ScaleSelectorView()
            }

            Spacer(minLength: XTheme.space3)

            // Controller Hardware Status Badge
            Button {
                onOpenSettings()
            } label: {
                HStack(spacing: XTheme.space2) {
                    Circle()
                        .fill(appState.controllerManager.isConnected ? XTheme.connected : XTheme.disconnected)
                        .frame(width: 7, height: 7)
                        .xPulse(isActive: appState.controllerManager.isConnected, color: XTheme.connected, speed: 0.8)

                    Text(controllerBadgeText(isCompact: isCompact))
                        .font(XTheme.fontCaptionSmall)
                        .foregroundColor(XTheme.textPrimary)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(badgeHovered ? XTheme.textSecondary : XTheme.textTertiary)
                        .offset(x: badgeHovered ? 1.5 : 0)
                }
                .padding(.horizontal, isCompact ? XTheme.space3 : XTheme.space4)
                .padding(.vertical, XTheme.space1)
                .background(badgeHovered ? XTheme.surfaceHover : XTheme.control)
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusS)
                        .stroke(
                            appState.controllerManager.isConnected ? XTheme.borderBrand : XTheme.border,
                            lineWidth: XTheme.borderThin
                        )
                        .opacity(badgeHovered ? 1.0 : 0.8)
                        .animation(XTheme.easeOut, value: appState.controllerManager.isConnected)
                )
                .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusS))
                .xRipple(trigger: connectRippleTrigger, color: XTheme.connected, size: 56)
            }
            .buttonStyle(.plain)
            .help("Configure Controller Scheme, Calibrate Deadzones, and Remap Buttons")
            .onHover { badgeHovered = $0 }
            .animation(reduceMotion ? nil : XTheme.quickAnimation, value: badgeHovered)
            .onChange(of: appState.controllerManager.isConnected) { _, isConnected in
                if isConnected && !wasConnected { connectRippleTrigger += 1 }
                wasConnected = isConnected
            }

            // Settings Button
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(gearHovered ? XTheme.brand : XTheme.textSecondary)
                    .rotationEffect(.degrees(gearHovered ? 45 : 0))
                    .animation(reduceMotion ? nil : XTheme.springSnappy, value: gearHovered)
                    .padding(XTheme.space2)
                    .background(
                        RoundedRectangle(cornerRadius: XTheme.radiusS)
                            .fill(gearHovered ? AnyShapeStyle(XTheme.surfaceHover) : AnyShapeStyle(XTheme.control))
                            .animation(reduceMotion ? nil : XTheme.quickAnimation, value: gearHovered)
                    )
            }
            .buttonStyle(.plain)
            .help("Open Settings")
            .onHover { gearHovered = $0 }
        }
        .padding(.horizontal, isCompact ? XTheme.space4 : XTheme.space5)
        .padding(.vertical, isCompact ? XTheme.space2 : XTheme.space3)
        .background(XTheme.surface.opacity(0.6))
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