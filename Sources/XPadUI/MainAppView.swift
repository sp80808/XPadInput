import SwiftUI
import XPadCore
import XPadController

/// Main content view with sidebar navigation and transport bar.
public struct ContentView: View {
    @Environment(AppState.self) private var appState
    
    public init() {}
    
    public var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // Main content area
            HStack(spacing: 0) {
                // Sidebar
                SidebarView()
                
                Divider()
                    .background(XTheme.border)
                
                // Workspace content
                workspaceContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
                .background(XTheme.border)
            
            // Transport bar (always visible)
            TransportBar()
        }
        .background(XTheme.background)
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private var workspaceContent: some View {
        switch appState.selectedWorkspace {
        case .play:
            PlayView()
        case .harmony:
            HarmonyPlaceholderView()
        case .sequence:
            SequencePlaceholderView()
        case .map:
            MapPlaceholderView()
        case .library:
            LibraryPlaceholderView()
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 2) {
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
                    .fill(isSelected ? XTheme.primary.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
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
