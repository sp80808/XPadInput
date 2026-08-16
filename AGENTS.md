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

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:970c3bf2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->
