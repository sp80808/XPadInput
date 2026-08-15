import SwiftUI
import AppKit
import XPadUI

@main
struct XPadInputApp: App {
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}
