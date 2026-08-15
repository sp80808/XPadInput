import SwiftUI
import XPadUI

@main
struct XPadInputApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
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
                    appState.midiEngine.panic()
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
            }
        }
    }
}
