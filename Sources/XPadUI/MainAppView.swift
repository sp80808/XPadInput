import SwiftUI
import XPadCore
import XPadController

/// Main content view for the unified XPI performance workstation.
public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingSettings = false

    public init() {}

    @ViewBuilder
    private var workspaceHost: some View {
        @Bindable var appState = appState
        switch appState.selectedWorkspace {
        case .play:
            PlayView(onOpenSettings: { isShowingSettings = true })
        case .harmony:
            HarmonyWorkspaceView(currentScale: $appState.currentScale)
        case .sequence:
            SequenceWorkspaceView(sequencer: appState.sequencer)
        case .map:
            MapWorkspaceView(controllerManager: appState.controllerManager)
        case .library:
            LibraryWorkspaceView()
        case .practice:
            PracticeWorkspaceView()
        }
    }

    public var body: some View {
        @Bindable var appState = appState
        GeometryReader { geo in
            let metrics = ViewportMetrics(size: geo.size)

            HStack(spacing: 0) {
                WorkspaceSidebarView()

                VStack(spacing: 0) {
                    TopPerformanceHeaderView(onOpenSettings: { isShowingSettings = true })

                    Divider()
                        .overlay(XTheme.border)

                    workspaceHost
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(XTheme.canvas)

                    Divider()
                        .overlay(XTheme.border)

                    if appState.showTransportBar {
                        TransportBar()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .environment(\.viewportMetrics, metrics)
        }
        .animation(XTheme.easeInOut, value: appState.selectedWorkspace)
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
    @State private var badgeHovered = false

    var body: some View {
        let isCompact = viewport.isCompactWidth

        HStack(spacing: isCompact ? XTheme.space3 : XTheme.space4) {
            // Instrument, key, and scale stay in the header. App identity
            // lives in the sidebar so this bar can stay a performance strip.
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

            ControlSchemePicker()
                .labelsHidden()
                .controlSize(.small)
                .frame(minWidth: 140, idealWidth: 200, maxWidth: 240)
                .help(appState.controllerManager.activeScheme.description)

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
                .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusS))
            }
            .buttonStyle(.plain)
            .help("Connect, calibrate or remap a controller")
            .accessibilityLabel("Controller setup")
            .onHover { badgeHovered = $0 }
            .animation(reduceMotion ? nil : XTheme.quickAnimation, value: badgeHovered)

            if appState.selectedWorkspace == .play {
                ViewLayoutMenuButton()
            }
        }
        .padding(.horizontal, isCompact ? XTheme.space4 : XTheme.space5)
        .padding(.vertical, isCompact ? XTheme.space2 : XTheme.space3)
        .background(XTheme.surface.opacity(0.6))
    }

    private func controllerBadgeText(isCompact: Bool) -> String {
        guard appState.controllerManager.isConnected else {
            return isCompact ? "Connect" : "Connect controller"
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