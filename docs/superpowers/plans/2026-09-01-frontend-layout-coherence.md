# Frontend Layout, Ergonomics, and Design Coherence

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make XPadUI a professional, coherent macOS instrument: one shell, one token system, PLAY as the musical hero, secondary workspaces actually reachable.

**Architecture:** Restore the six-workspace information architecture already specified in `docs/architecture/design-spec.md`. `ContentView` becomes a labeled sidebar plus a workspace host. Play remains the launch workspace. Harmony, Sequence, Map, and Library — currently orphaned source files — mount into that host and adopt `XTheme`. PLAY density then follows spec §11.1 (about 58% musical / 42% performance) instead of letting HUD/DSP telemetry dominate.

**Tech Stack:** Native SwiftUI 6, `XTheme` in `Sources/XPadUI/GreenTheme.swift`, `ViewportMetrics`, `@Observable AppState`, zero third-party dependencies.

## Global Constraints

- No third-party packages. Apple frameworks only.
- `XPadCore` / `XPadTheory` stay free of UI and audio imports.
- Observe `@Environment(\.accessibilityReduceMotion)` for all motion.
- Do not increase audio/MIDI latency for visual polish.
- Design tokens live in `XTheme`. Do not introduce a second palette.
- Practice stays opt-in: first launch is Play, never Practice.
- Conservative git: do not commit or push unless the user asks.

**Beads epic:** `xpi-viz`

---

## Diagnosis (current vs spec)

The design spec already calls for six destinations, a compact labeled sidebar, slim transport, and `XTheme` as the single visual system. The running app does not match that spec:

1. **Unhosted workspaces.** `HarmonyWorkspaceView`, `SequenceWorkspaceView`, `MapWorkspaceView`, and `LibraryWorkspaceView` are never constructed. `ContentView` only swaps `PlayView` and `PracticeWorkspaceView`.
2. **Dead navigation.** Menu Bar Extra “Switch Workspace” writes `AppState.selectedWorkspace`, but the window never reads it (except Practice via `isPracticeRequested`). `WorkspaceTab.map` raw value is `"Controller Map"` while `Workspace.map` is `"Map"`, so Map selection fails `Workspace(rawValue:)`.
3. **Dual design systems.** Play / Practice / chrome sit on `XTheme`. Harmony / Sequence / Map still use `Color.accentColor` and system materials (`xpi-q7j.15`).
4. **PLAY overcrowding.** `PlayView` is a 1,448-line optional-panel stack. Spec §11.1 wants musical space to win.
5. **Duplicated identity.** Header wordmark, menu bar, and (soon) sidebar all compete to be “XPI”.

Do not invent a new visual language. Execute `docs/architecture/design-spec.md` sections 10, 11, 22, 23, 29.

---

## File map

| File | Responsibility |
| --- | --- |
| `Sources/XPadUI/WorkspaceNavigation.swift` | Single workspace enum helpers + labeled sidebar |
| `Sources/XPadUI/MainAppView.swift` | Shell: sidebar + host + slim header |
| `Sources/XPadUI/AppState.swift` | `selectWorkspace(_:)` lifecycle (stop practice on leave) |
| `Sources/XPadInput/XPadInputApp.swift` | Cmd+1…5 workspace commands |
| `Sources/XPadUI/MenuBarContentView.swift` | Switch Workspace uses `Workspace`, not mismatched raw values |
| `Sources/XPadUI/HarmonyWorkspaceView.swift` | XTheme restyle once hosted |
| `Sources/XPadUI/SequenceWorkspaceView.swift` | XTheme restyle once hosted |
| `Sources/XPadUI/MapWorkspaceView.swift` | XTheme restyle; later pipeline inspector |
| `Sources/XPadUI/LibraryWorkspaceView.swift` | Finish token pass |
| `Sources/XPadUI/PlayWorkspaceView.swift` | Density pass after shell |
| `Sources/XPadUI/GreenTheme.swift` | Token additions only if a semantic gap is real |

---

### Task 1: Host the six-workspace shell (`xpi-viz.1`)

**Files:**
- Modify: `Sources/XPadUI/WorkspaceNavigation.swift`
- Modify: `Sources/XPadUI/MainAppView.swift`
- Modify: `Sources/XPadUI/AppState.swift`
- Modify: `Sources/XPadInput/XPadInputApp.swift`
- Modify: `Sources/XPadUI/MenuBarContentView.swift`

**Interfaces:**
- Consumes: `AppState.selectedWorkspace`, `Workspace.persistentCases`, existing workspace view inits
- Produces: `AppState.selectWorkspace(_:)`, `WorkspaceSidebarView`, `ContentView` host switch

- [ ] **Step 1: Align navigation types**

Fix `WorkspaceTab.map` raw value to `"Map"`. Point `iconName` at the same SF Symbols as `Workspace.icon`. Menu Bar Extra iterates `Workspace.persistentCases` and assigns `appState.selectedWorkspace` directly.

- [ ] **Step 2: Add `selectWorkspace`**

In `AppState`:

```swift
public func selectWorkspace(_ workspace: Workspace) {
    if selectedWorkspace == .practice && workspace != .practice,
       practiceEngine.isPracticeActive {
        practiceEngine.stopPractice()
    }
    selectedWorkspace = workspace
}
```

Keep `togglePractice()` / `requestPractice()` / `dismissPractice()` as wrappers around this.

- [ ] **Step 3: Labeled sidebar**

Add `WorkspaceSidebarView` in `WorkspaceNavigation.swift`:

- Destinations: Play, Harmony, Sequence, Map, Library
- Practice below a divider (reachable, not the launch selection)
- Visible text labels (not icon-only)
- Controller connection indicator at the bottom
- Compact width ~76pt, regular ~96pt via `ViewportMetrics`
- Selected state uses `XTheme.brand` / `surfaceRaised`, not system tint
- `.accessibilityLabel` on each destination

- [ ] **Step 4: Host workspaces in `ContentView`**

Replace Play-vs-Practice-only switching with:

```swift
switch appState.selectedWorkspace {
case .play:      PlayView(onOpenSettings: { isShowingSettings = true })
case .harmony:   HarmonyWorkspaceView(currentScale: $appState.currentScale)
case .sequence:  SequenceWorkspaceView(sequencer: appState.sequencer)
case .map:       MapWorkspaceView(controllerManager: appState.controllerManager)
case .library:   LibraryWorkspaceView()
case .practice:  PracticeWorkspaceView()
}
```

Keep header + transport persistent. Slim the header wordmark; identity lives in the sidebar.

- [ ] **Step 5: Commands**

In `XPadInputApp`, add a Workspaces section: Cmd+1…5 for persistent cases. Keep Cmd+Shift+P for Practice and Cmd+Option+1…7 for Play section toggles.

- [ ] **Step 6: Build**

Run: `swift build --target XPadUI`

Expected: success. Failures about `HarmonyWorkspaceView` bindings or `Sequencer` observation must be fixed in this task, not deferred.

- [ ] **Step 7: Close bead**

`bd close xpi-viz.1 --reason="Shell hosts all six workspaces; menu and shortcuts agree"`

---

### Task 2: XTheme-unify secondary workspaces (`xpi-viz.2`)

**Files:** Harmony, Sequence, Map, Library workspace views. Related: `xpi-q7j.15`.

- [ ] Replace `Color.accentColor` / `Color.white.opacity` / `Color.primary` with `XTheme` tokens
- [ ] Section headers use `XTheme.fontHeadline` / `textSecondary`
- [ ] Cards use `xCard` / `surfaceRaised` / `radiusM` / `border`
- [ ] Buttons use `.xButton` or `XTactileButtonStyle`, not a mix of `.borderedProminent` and custom
- [ ] `swift build --target XPadUI`
- [ ] `bd close xpi-viz.2`

---

### Task 3: PLAY density (`xpi-viz.3`, related `xpi-54l`)

**Files:** `PlayWorkspaceView.swift`, `MainAppView.swift`, `ViewportMetrics.swift`

- [ ] Default `playSplitRatio` ≈ 0.58
- [ ] Chord display remains a hero even when HUD/DSP are visible
- [ ] Performance monitor / numeric lanes are secondary (collapsed by default on compact height)
- [ ] Compact width: keep chord, compass, controller status, transport; park extras
- [ ] `swift build`; visual QA against design-spec §11
- [ ] `bd close xpi-viz.3`

---

### Task 4: MAP inspector + scheme-aware labels (`xpi-viz.4`)

- [ ] Raw vs processed cursor, deadzone / curve preview
- [ ] HUD and onboarding call `controllerManager.controlLabel(for:)`
- [ ] `bd close xpi-viz.4`

---

### Task 5: Compact DAW companion (`xpi-viz.5`)

Blocked on Task 3. Three useful widths per spec §22. Do not shrink type below readable size.

---

## Out of scope for this epic

- AudioEngine hot-path allocations (`audioengine-noteon-and-triggerdrum-allocate-avaudioformat-pe`)
- MIDI 2.0 UMP (`xpi-6a2`)
- Snapshot test module (`xpi-iru`) — track separately; add after chrome is stable
- Splitting `AppState` (`xpi-q7j.5`)

## Verification

```bash
swift build
swift test
```

UI verification is visual: launch XPI, cycle Cmd+1…5, confirm each workspace fills the canvas with XTheme chrome, then return to Play and confirm transport/header still work.
