# Guitar Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the DualSense guitar loop own its sticks: stable harmonic selection, strum→sustain→bend arbitration, and measurable software attack latency.

**Architecture:** Pure stateful engines in `XPadTheory` / `XPadController` / `XPadCore`; `AppState` is the only UI-facing owner; HUD/wheel display committed semantics; live stick position stays un-eased.

**Tech Stack:** Swift 5.10, macOS 14, XCTest, no third-party packages.

## Global Constraints

- No CocoaPods / Carthage / third-party SPM.
- `XPadCore` and `XPadTheory` stay free of audio/UI.
- Never ease live stick/trigger **position**.
- Do not rewrite `AudioEngine` voice topology unless probe evidence shows attach/connect jitter.
- Instrument profiles choose which right-stick transitions are legal.

---

### Task 1: Harmonic selection hysteresis

**Files:**
- Create: `Sources/XPadTheory/HarmonicSelectionState.swift`
- Create: `Tests/XPadTheoryTests/HarmonicSelectionStateTests.swift`
- Modify: `Sources/XPadUI/AppState.swift` (`handleChordSelection`)
- Modify: `Sources/XPadUI/HarmonicWheelView.swift`
- Modify: `Sources/XPadCore/MusicalTechnique.swift` (`harmonicCommit`, `harmonicRisk`)

**Interfaces:**
- Produces: `HarmonicSelectionState.evaluate(angle:radius:) -> HarmonicSelectionSnapshot`
- Angle: `atan2(y,x)`, index 0 at `π/2`, clockwise.

- [x] **Step 1: Tests for jitter, wrap, rest, risk**
- [x] **Step 2: Implement `HarmonicSelectionState`**
- [x] **Step 3: Wire AppState + committed wheel visuals + haptics**
- [x] **Step 4: `swift test --filter HarmonicSelectionStateTests`**

### Task 2: Right-stick gesture ownership

**Files:**
- Create: `Sources/XPadController/RightStickGestureOwnership.swift`
- Create: `Tests/XPadControllerTests/RightStickGestureOwnershipTests.swift`
- Modify: `Sources/XPadController/InstrumentPerformanceEngine.swift`
- Modify: `Sources/XPadUI/ControllerPerformanceHUD.swift`

**Interfaces:**
- Produces: `RightStickGestureOwnership.evaluate(x:y:notesHeld:) -> RightStickOwnedGesture`
- `PerformanceFrame.ownedGesture` and `suppressStrum` from ownership.

- [x] **Step 1: Tests for diagonal strum, sustain→bend, keys, strings, lead**
- [x] **Step 2: State machine + profile policy**
- [x] **Step 3: Engine uses ownership instead of one-frame X-dominance**
- [x] **Step 4: HUD role without idle layout jump**
- [x] **Step 5: `swift test --filter RightStickGestureOwnershipTests`**

### Task 3: Action→sound software probe

**Files:**
- Create: `Sources/XPadCore/ActionSoundLatencyProbe.swift`
- Create: `Tests/XPadCoreTests/ActionSoundLatencyProbeTests.swift`
- Modify: `Sources/XPadAudio/AudioEngine.swift` (`lastGraphMutationMs`)
- Modify: `Sources/XPadUI/AppState.swift`, `ControlSchemeSettingsView.swift`, `ExpressionMapWorkspaceView.swift`

- [x] **Step 1: Probe + percentile tests**
- [x] **Step 2: Mark input / gesture / dispatch / synth return**
- [x] **Step 3: Live Test Studio card (off by default)**
- [ ] **Step 4: Record a DualSense baseline on macOS hardware (p50/p95/p99, 1/4/8/16 voices)** — needs hardware, not this agent
- [ ] **Step 5: First-buffer render timestamp** — only if Task 3 numbers show attach/connect is the variance
- [ ] **Step 6: Voice pool** — gated on Step 4 evidence (#26)

### Task 4: Remaining guitar-ownership issues (not this PR)

- [ ] #24 `ControlSurfaceProfile` + passive calibration
- [ ] #27 periodic vibrato vs motion energy
- [ ] #28 technique confidence + RealismMode as acceptance policy
- [ ] #29/#30 DualSense adaptive triggers and touchpad gating
- [ ] #25/#32 remapping + mapping-conflict analysis
- [ ] #3/#13/#15 DAW / MIDI 2 / live expression certification

## Verification

```bash
swift test
swift build
```

Linux cloud agents cannot compile the macOS 14 package; GitHub `macos-latest` CI is the gate.
