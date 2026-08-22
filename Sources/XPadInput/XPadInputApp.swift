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
            CommandGroup(replacing: .newItem) {}
            CommandMenu("MIDI") {
                Button("Panic — All Notes Off") {
                    appState.panic()
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])

                Divider()

                Toggle("Enable Virtual MIDI", isOn: $appState.midiEngine.virtualMIDIEnabled)
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            }
            CommandMenu("View") {
                Button(appState.isPracticeRequested ? "Exit Practice" : "Show Practice") {
                    appState.togglePractice()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
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
