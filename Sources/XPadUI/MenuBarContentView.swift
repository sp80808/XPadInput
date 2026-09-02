import SwiftUI
import AppKit
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio

/// Compact menu-bar companion menu providing status, quick background toggles,
/// window focus controls, and panic actions when XPadInput is in the background.
public struct MenuBarContentView: View {
    @Bindable var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack {
            // MARK: - Controller & Status Header
            if appState.controllerManager.isConnected {
                Label("Controller: \(appState.controllerManager.controllerName)", systemImage: "gamecontroller.fill")
            } else {
                Label("No Gamepad Connected", systemImage: "gamecontroller")
            }

            Text("Key: \(appState.currentKey.displayName) \(appState.currentScale.shortDisplayName) • \(appState.instrumentProfile.name)")
                .font(.caption)

            Divider()

            // MARK: - Window Management & Focus
            Button("Open XPadInput Window") {
                focusMainWindow()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Divider()

            // MARK: - Background Input & MIDI Toggles
            Toggle("Background Gamepad Input", isOn: Binding(
                get: { appState.controllerManager.isBackgroundMonitoringEnabled },
                set: { appState.controllerManager.isBackgroundMonitoringEnabled = $0 }
            ))

            Toggle("Virtual MIDI Output", isOn: $appState.midiEngine.virtualMIDIEnabled)

            Divider()

            // MARK: - Panic
            Button("Panic — All Notes Off") {
                appState.panic()
            }
            .keyboardShortcut(".", modifiers: [.command, .shift])

            Divider()

            // MARK: - Instrument Profiles
            Menu("Instrument Profile") {
                ForEach(InstrumentProfile.playableProfiles, id: \.family) { profile in
                    Button {
                        appState.setInstrument(profile)
                    } label: {
                        if appState.instrumentProfile.family == profile.family {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                }
            }

            // MARK: - Workspace Navigation
            Menu("Switch Workspace") {
                ForEach(WorkspaceTab.persistentCases) { tab in
                    Button {
                        if let ws = Workspace(rawValue: tab.rawValue) {
                            appState.selectedWorkspace = ws
                            focusMainWindow()
                        }
                    } label: {
                        if appState.selectedWorkspace.rawValue == tab.rawValue {
                            Label(tab.rawValue, systemImage: "checkmark")
                        } else {
                            Text(tab.rawValue)
                        }
                    }
                }
            }

            Button(appState.isPracticeRequested ? "Exit Practice Mode" : "Open Practice Mode") {
                appState.togglePractice()
                focusMainWindow()
            }

            Divider()

            // MARK: - Utilities
            Button("Rescan Controllers") {
                appState.controllerManager.scanForControllers()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button(appState.showTransportBar ? "Hide Transport Bar" : "Show Transport Bar") {
                appState.toggleTransportBar()
            }
            .keyboardShortcut("t", modifiers: [.command, .option])

            Divider()

            Button("Quit XPadInput") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    private func focusMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows {
            if window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
