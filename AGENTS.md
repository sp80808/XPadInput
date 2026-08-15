# AGENTS.md: Developer & Agent Operating Instructions for XPadInput

## 1. System Overview & Mission

**XPadInput** is a native macOS application and music workstation that reimagines standard consumer game controllers (Sony DualSense / DualShock 4, Microsoft Xbox Controller, Nintendo Switch Pro, and generic MFi gamepads) into professional-grade, expressive MPE MIDI instruments, intelligent harmony engines, and real-time performance workstations.

### Core Objectives
1. **Low-Latency Tactile Control**: Sub-5ms input-to-sound latency via CoreMIDI and AVAudioEngine.
2. **Deep Music Theory Integration**: Intelligent harmonic wheels, modal interchange, voice-leading optimization, and progression building.
3. **True MPE Support**: Multi-channel polyphonic expression mapping continuous gamepad dimensions (triggers, gyro, touch surface, analog velocity) to pitch bend (±48 semitones), polyphonic aftertouch, and CC74 timbre.
4. **Zero-Dependency Native Architecture**: 100% pure Swift with Apple frameworks (`GameController`, `CoreMIDI`, `AVFAudio`, `AppKit`, `SwiftUI`).

---

## 2. Workspace Modular Architecture

The repository is organized into distinct Swift packages and modules:

```
Sources/
├── XPadCore/          # Foundational musical types & domain primitives
│   ├── PitchClass.swift
│   ├── Interval.swift
│   ├── Note.swift
│   ├── Scale.swift
│   ├── Chord.swift
│   └── PerformanceEvent.swift
│
├── XPadTheory/        # Harmony, analysis & progression algorithms
│   ├── HarmonicDegree.swift
│   ├── HarmonicWheel.swift
│   ├── VoiceLeadingEngine.swift
│   ├── HarmonicSuggestionEngine.swift
│   ├── ModulationEngine.swift
│   └── Progression.swift
│
├── XPadController/    # GameController hardware abstraction & gesture DSP
│   ├── GamepadState.swift
│   ├── VirtualStrummer.swift
│   ├── RhythmCompassEngine.swift
│   ├── GestureRecorder.swift
│   └── ControllerManager.swift
│
├── XPadMIDI/          # CoreMIDI virtual endpoints & MPE zone dispatcher
│   ├── MIDIManager.swift
│   ├── MPEManager.swift
│   └── SMFExporter.swift
│
├── XPadAudio/         # Real-time multi-voice polyphonic DSP synthesizer
│   └── AudioEngine.swift
│
├── XPadSequencer/     # Tick-based 960 PPQN multi-track timeline engine
│   └── Sequencer.swift
│
├── XPadUI/            # Native SwiftUI 5-workspace interface & visualizers
│   ├── MainAppView.swift
│   ├── TransportBarView.swift
│   ├── PlayWorkspaceView.swift
│   ├── HarmonyWorkspaceView.swift
│   ├── SequenceWorkspaceView.swift
│   ├── MapWorkspaceView.swift
│   ├── LibraryWorkspaceView.swift
│   └── WorkspaceNavigation.swift
│
└── XPadInput/         # App main entrypoint
    └── XPadInputApp.swift
```

---

## 3. Engineering Guidelines for Agents

### 3.1 Strict Design Rules
- **No Third-Party Dependencies**: Do not introduce CocoaPods, Carthage, or third-party SPM packages unless explicitly requested. Use native Apple APIs (`GameController`, `CoreMIDI`, `AVFAudio`).
- **Clean Separation of Concerns**:
  - `XPadCore` and `XPadTheory` must remain deterministic, pure Swift models with zero audio or UI dependencies.
  - `XPadMIDI` and `XPadAudio` are isolated from UI state and communicate via thread-safe callbacks or Swift Concurrency.
  - UI components reside strictly in `XPadUI`.
- **Concurrency & MainActor**:
  - UI-bound state managers (`ControllerManager`, `Sequencer`) are `@MainActor` annotated.
  - Real-time DSP and MIDI queues utilize dedicated high-priority threads with explicit lock synchronization (`NSLock` / `@unchecked Sendable` isolation).
  - Never perform blocking I/O, file access, or heavy theory loops inside the audio render thread (`AVAudioSourceNode`).

### 3.2 Git & Filesystem Sanitation
- **AppleDouble Exclusion**: Always ensure `._*` files are purged before commits.
- **Git Commits**: Keep commit messages structured, semantic (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`), and descriptive.

---

## 4. Test Suites & Verification

Every module is accompanied by an exhaustive test suite under `Tests/`:
- `XPadCoreTests`: Tests pitch class math, enharmonics, intervals, note frequencies, scale quantization, and chord voicings.
- `XPadTheoryTests`: Tests harmonic wheels, polar lookups, SATB/smooth voice leading, suggestions, modulations, and progressions.
- `XPadControllerTests`: Tests deadzones, strum velocity, direction heuristics, rhythm compass polar sectors, and gesture capture.
- `XPadMIDITests`: Tests virtual port lifecycles, MPE multi-channel distribution, and SMF binary encoding.
- `XPadAudioTests`: Tests synth preset configurations and ADSR state machine transitions.
- `XPadSequencerTests`: Tests transport states, clip recording, 960 PPQN clock, and scene transitions.

### Running Tests
```bash
swift test
```

### Building the Project
```bash
swift build
```
