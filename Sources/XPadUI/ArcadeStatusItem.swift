import AppKit
import XPadController

/// Owns the hidden arcade menu-bar entry. Implemented as a raw NSStatusItem
/// because SceneBuilder on this toolchain cannot conditionally insert scenes;
/// the entry materialises in the system status bar only after the secret
/// ⌘⌥⇧G combination is pressed inside the app.
@MainActor
final class ArcadeStatusItemCoordinator: NSObject, NSMenuDelegate {
    private weak var appState: AppState?
    private var statusItem: NSStatusItem?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func reveal() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        rebuild(menu)
        statusItem = item
        syncButtonState()
    }

    func hide() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
        syncButtonState()
    }

    // MARK: - Button state

    private func syncButtonState() {
        guard let button = statusItem?.button else { return }
        let enabled = appState?.isArcadeModeEnabled == true
        if let image = NSImage(
            systemSymbolName: enabled ? "guitars.fill" : "guitars",
            accessibilityDescription: "Arcade Frets"
        ) {
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = "♪"
        }
        button.toolTip = enabled ? "Arcade Frets — Enabled" : "Arcade Frets"
    }

    // MARK: - Menu construction

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Arcade Frets", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let toggle = NSMenuItem(
            title: appState?.isArcadeModeEnabled == true ? "Disable Fret Lane" : "Enable Fret Lane",
            action: #selector(toggleFretLane),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = appState?.isArcadeModeEnabled == true ? .on : .off
        menu.addItem(toggle)

        if appState?.isArcadeModeEnabled == true {
            let open = NSMenuItem(
                title: "Open Fret Lane",
                action: #selector(openFretLane),
                keyEquivalent: ""
            )
            open.target = self
            menu.addItem(open)
        }

        menu.addItem(.separator())

        let legendHeader = NSMenuItem(title: "Lane Legend", action: nil, keyEquivalent: "")
        legendHeader.isEnabled = false
        menu.addItem(legendHeader)

        for line in [
            "L2 · I      L1 · IV",
            "R1 · V      R2 · vi",
            "✕ maj7/m7   □ sus",
            "△ add9/m9   ○ 6/m6"
        ] {
            let legend = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            legend.isEnabled = false
            menu.addItem(legend)
        }

        menu.addItem(.separator())

        let panic = NSMenuItem(
            title: "Panic — All Notes Off",
            action: #selector(panicAll),
            keyEquivalent: ""
        )
        panic.target = self
        menu.addItem(panic)
    }

    // MARK: - Actions

    @objc private func toggleFretLane() {
        appState?.toggleArcadeMode()
        syncButtonState()
        if let menu = statusItem?.menu {
            rebuild(menu)
        }
    }

    @objc private func openFretLane() {
        guard let appState else { return }
        appState.selectedWorkspace = .play
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func panicAll() {
        appState?.panic()
    }
}
