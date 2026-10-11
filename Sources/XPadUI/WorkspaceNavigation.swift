import SwiftUI

public enum WorkspaceTab: String, CaseIterable, Identifiable {
    case play = "Play"
    case harmony = "Harmony"
    case sequence = "Sequence"
    case map = "Map"
    case library = "Library"
    case practice = "Practice"

    public var id: String { rawValue }

    /// Tabs shown in persistent navigation chrome. Practice is opened on
    /// demand and must not occupy first-launch screenspace.
    public static var persistentCases: [WorkspaceTab] {
        allCases.filter { $0 != .practice }
    }

    public var iconName: String {
        switch self {
        case .play: return "gamecontroller.fill"
        case .harmony: return "music.note.list"
        case .sequence: return "rectangle.3.group.fill"
        case .map: return "slider.horizontal.3"
        case .library: return "books.vertical.fill"
        case .practice: return "graduationcap.fill"
        }
    }
}

public enum InstrumentPlayMode: String, CaseIterable, Identifiable {
    case chords = "Chord Strummer"
    case arp = "Arpeggiator"
    case drone = "Drone Pad"
    case drums = "Rhythm Compass"
    case bass = "Bassline"
    case melody = "Melody Lead"

    public var id: String { rawValue }
}

// MARK: - Workspace Sidebar

/// Compact labeled destination rail. Identity, workspace selection, and
/// controller liveness live here so the performance header can stay slim.
struct WorkspaceSidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.viewportMetrics) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let compact = viewport.isCompactWidth
        let width: CGFloat = compact ? 76 : 96

        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: compact ? 16 : 18, weight: .bold))
                    .foregroundStyle(XTheme.brand)
                Text("XPI")
                    .font(.system(size: compact ? 11 : 12, weight: .black, design: .rounded))
                    .foregroundStyle(XTheme.textPrimary)
                if !compact {
                    Text("MPE")
                        .font(XTheme.fontMonoTiny)
                        .foregroundStyle(XTheme.brand)
                }
            }
            .padding(.top, XTheme.space4)
            .padding(.bottom, XTheme.space3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("XPI MPE instrument")

            VStack(spacing: XTheme.space1) {
                ForEach(Workspace.persistentCases) { workspace in
                    WorkspaceSidebarItem(
                        workspace: workspace,
                        isSelected: appState.selectedWorkspace == workspace,
                        compact: compact
                    ) {
                        appState.selectWorkspace(workspace)
                    }
                }
            }
            .padding(.horizontal, XTheme.space1)

            Spacer(minLength: XTheme.space3)

            Divider()
                .overlay(XTheme.border)
                .padding(.horizontal, XTheme.space2)

            WorkspaceSidebarItem(
                workspace: .practice,
                isSelected: appState.selectedWorkspace == .practice,
                compact: compact
            ) {
                appState.togglePractice()
            }
            .padding(.horizontal, XTheme.space1)
            .padding(.top, XTheme.space2)

            HStack(spacing: 6) {
                Circle()
                    .fill(appState.controllerManager.isConnected ? XTheme.connected : XTheme.disconnected)
                    .frame(width: 6, height: 6)
                    .xPulse(
                        isActive: appState.controllerManager.isConnected,
                        color: XTheme.connected,
                        speed: 0.9
                    )
                if !compact {
                    Text(appState.controllerManager.isConnected ? "Live" : "Sim")
                        .font(XTheme.fontMicro)
                        .foregroundStyle(XTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, XTheme.space3)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                appState.controllerManager.isConnected
                    ? "Controller connected"
                    : "No controller connected"
            )
        }
        .frame(width: width)
        .background(XTheme.surface.opacity(0.92))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(width: XTheme.borderHairline)
        }
        .animation(reduceMotion ? nil : XTheme.easeOut, value: compact)
    }
}

private struct WorkspaceSidebarItem: View {
    let workspace: Workspace
    let isSelected: Bool
    let compact: Bool
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: workspace.icon)
                    .font(.system(size: compact ? 15 : 16, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? XTheme.brand : (hovering ? XTheme.textPrimary : XTheme.textSecondary))
                    .frame(height: 18)
                Text(workspace.rawValue)
                    .font(compact ? XTheme.fontMicro : XTheme.fontCaptionSmall)
                    .foregroundStyle(isSelected ? XTheme.textPrimary : XTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, XTheme.space2)
            .background {
                RoundedRectangle(cornerRadius: XTheme.radiusS)
                    .fill(isSelected ? XTheme.brand.opacity(0.12) : (hovering ? XTheme.surfaceHover : Color.clear))
            }
        }
        .buttonStyle(.plain)
        .help(workspace.rawValue)
        .accessibilityLabel(workspace.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : XTheme.easeOutFast, value: isSelected)
        .animation(reduceMotion ? nil : XTheme.easeOutFast, value: hovering)
    }
}
