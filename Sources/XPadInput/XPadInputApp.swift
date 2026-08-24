import SwiftUI
import XPadUI

@main
struct XPadInputApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup("XPI: Game Controller MIDI") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 1100, minHeight: 700)
                .onAppear {
                    appState.initialize()
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Interactive Tutorials (Learn Hub)...") {
                    appState.showLearnHub = true
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .sidebar) {
                Section("Workspaces") {
                    Button(appState.isPracticeRequested ? "Exit Practice Workspace" : "Open Practice Workspace") {
                        appState.togglePractice()
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                }

                Divider()

                Section("Play Workspace Sections") {
                    Toggle("Harmonic Wheel & Theory", isOn: Binding(
                        get: { appState.showHarmonicPanel },
                        set: { appState.showHarmonicPanel = $0 }
                    ))
                    .keyboardShortcut("1", modifiers: [.command, .option])

                    Toggle("Harmonic Progression Tabs", isOn: Binding(
                        get: { appState.showHarmonicTabSection },
                        set: { appState.showHarmonicTabSection = $0 }
                    ))
                    .keyboardShortcut("2", modifiers: [.command, .option])

                    Toggle("Controller HUD Visualizer", isOn: Binding(
                        get: { appState.showControllerVisualizer },
                        set: { appState.showControllerVisualizer = $0 }
                    ))
                    .keyboardShortcut("3", modifiers: [.command, .option])

                    Toggle("Performance Quick Controls", isOn: Binding(
                        get: { appState.showPerformanceQuickControls },
                        set: { appState.showPerformanceQuickControls = $0 }
                    ))
                    .keyboardShortcut("4", modifiers: [.command, .option])

                    Toggle("Performance Monitor & Lanes", isOn: Binding(
                        get: { appState.showPerformanceMonitor },
                        set: { appState.showPerformanceMonitor = $0 }
                    ))
                    .keyboardShortcut("5", modifiers: [.command, .option])

                    Toggle("DSP & Synth Workspace", isOn: Binding(
                        get: { appState.showDSPWorkspace },
                        set: { appState.showDSPWorkspace = $0 }
                    ))
                    .keyboardShortcut("6", modifiers: [.command, .option])

                    Toggle("Strum & MIDI Activity Bar", isOn: Binding(
                        get: { appState.showStrumMidiBar },
                        set: { appState.showStrumMidiBar = $0 }
                    ))
                    .keyboardShortcut("7", modifiers: [.command, .option])
                }

                Divider()

                Button("Reset Workspace Layout") {
                    appState.resetPlayLayout()
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
            }

            CommandMenu("MIDI") {
                Button("Panic — All Notes Off") {
                    appState.panic()
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])

                Divider()

                Toggle("Enable Virtual MIDI", isOn: $appState.midiEngine.virtualMIDIEnabled)
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            }
            CommandMenu("Controller") {
                Button("Refresh Controllers") {
                    appState.controllerManager.scanForControllers()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Toggle("Background Input", isOn: Binding(
                    get: { appState.controllerManager.isBackgroundMonitoringEnabled },
                    set: { appState.controllerManager.isBackgroundMonitoringEnabled = $0 }
                ))
            }
        }

        MenuBarExtra("XPI: Game Controller MIDI", systemImage: appState.controllerManager.isConnected ? "gamecontroller.fill" : "gamecontroller") {
            MenuBarContentView(appState: appState)
        }
    }
}
