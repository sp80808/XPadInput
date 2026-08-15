import SwiftUI
import XPadCore
import XPadController

/// Main content view with sidebar navigation and transport bar.
public struct ContentView: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // XPI is intentionally a single, focused performance surface.
            PlayView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .background(XTheme.border)
            
            // Transport bar (always visible)
            TransportBar()
        }
        .background {
            ZStack {
                XTheme.background
                RadialGradient(
                    colors: [XTheme.primary.opacity(0.10), .clear],
                    center: .topLeading,
                    startRadius: 24,
                    endRadius: 620
                )
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 2) {
            VStack(spacing: 0) {
                Text("XPI")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(XTheme.primary)
                Text("MIDI")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(XTheme.textTertiary)
            }
            .frame(width: 60, height: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("XPI: Game Controller MIDI")

            ForEach(Workspace.allCases) { workspace in
                SidebarButton(
                    workspace: workspace,
                    isSelected: appState.selectedWorkspace == workspace
                ) {
                    withAnimation(XTheme.springAnimation) {
                        state.selectedWorkspace = workspace
                    }
                }
            }
            
            Spacer()
            
            // Controller indicator
            VStack(spacing: 6) {
                Image(systemName: appState.controllerManager.isConnected ? "gamecontroller.fill" : "gamecontroller")
                    .font(.system(size: 18))
                    .foregroundColor(appState.controllerManager.isConnected ? XTheme.controllerConnected : XTheme.controllerDisconnected)
                    .xGlow(isActive: appState.controllerManager.isConnected)
                
                Text(appState.controllerManager.isConnected ? "Connected" : "No Pad")
                    .font(.caption2)
                    .foregroundColor(XTheme.textTertiary)
            }
            .padding(.bottom, 12)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .frame(width: 72)
        .background(XTheme.surface.opacity(0.5))
    }
}

struct SidebarButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    let workspace: Workspace
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: workspace.icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? XTheme.primary : XTheme.textSecondary)
                
                Text(workspace.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? XTheme.primary : XTheme.textTertiary)
            }
            .frame(width: 60, height: 52)
            .background(
                RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                    .fill(
                        isSelected
                            ? XTheme.primary.opacity(0.14)
                            : isHovering ? XTheme.surfaceHover.opacity(0.72) : .clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                            .stroke(isSelected ? XTheme.primary.opacity(0.34) : Color.clear, lineWidth: 1)
                    )
            )
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(XTheme.primaryGradient)
                    .frame(width: 3, height: isSelected ? 28 : 0)
                    .padding(.leading, 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: XTheme.radiusSmall))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Open \(workspace.rawValue) workspace")
        .accessibilityLabel("\(workspace.rawValue) workspace")
        .accessibilityValue(isSelected ? "Selected" : "")
        .animation(reduceMotion ? nil : XTheme.quickAnimation, value: isHovering)
        .animation(reduceMotion ? nil : XTheme.quickAnimation, value: isSelected)
    }
}

// MARK: - Placeholder Views

struct HarmonyPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(XTheme.primary.opacity(0.4))
            Text("Harmony Workspace")
                .font(.title2)
                .foregroundColor(XTheme.textSecondary)
            Text("Scale explorer, chord construction, progression builder")
                .font(.caption)
                .foregroundColor(XTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SequencePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 48))
                .foregroundColor(XTheme.primary.opacity(0.4))
            Text("Sequence Workspace")
                .font(.title2)
                .foregroundColor(XTheme.textSecondary)
            Text("Timeline, clips, scenes, melody editor")
                .font(.caption)
                .foregroundColor(XTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MapPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 48))
                .foregroundColor(XTheme.primary.opacity(0.4))
            Text("Map Workspace")
                .font(.title2)
                .foregroundColor(XTheme.textSecondary)
            Text("Controller mapping, gesture design, modulation matrix")
                .font(.caption)
                .foregroundColor(XTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LibraryPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 48))
                .foregroundColor(XTheme.primary.opacity(0.4))
            Text("Library")
                .font(.title2)
                .foregroundColor(XTheme.textSecondary)
            Text("Presets, controller profiles, progression ideas")
                .font(.caption)
                .foregroundColor(XTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
