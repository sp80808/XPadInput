# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

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


## Build & Test

```bash
# Build the project (executable target: XPI)
swift build

# Build in release mode
swift build -c release

# Package macOS App, DMG, ZIP with checksums (Alpha 0.0.04)
./scripts/package-macos.sh 0.0.04

# Run test suite
swift test
```

## Architecture Overview

XPI is a zero-third-party-dependency Swift 6 musical instrument and MPE workstation for macOS:
- **`XPadCore`**: Pure Swift foundational types (`Note`, `Scale`, `Chord`, `PitchClass`, `Interval`, `InstrumentProfile`).
- **`XPadTheory`**: Harmonic wheel, voice leading heuristics, progression engine, and chord bender.
- **`XPadPractice`**: Practice lessons, real-time chord evaluation, and progress tracking.
- **`XPadController`**: `GameController` hardware abstraction, analog stick/trigger processing, virtual strummer DSP, gesture tracking, adaptive triggers, and CoreHaptics.
- **`XPadMIDI`**: CoreMIDI virtual sources, MPE zone management, MIDI 2.0 UMP transport, MIDI-CI MPE profile, SMF and SMF2 binary exporters.
- **`XPadAudio`**: Real-time multi-voice polyphonic DSP synthesizer (`AVAudioSourceNode`), stereo master FX (EQ, compressor, reverb), and 3D spatial audio binaural engine.
- **`XPadSequencer`**: 960 PPQN multi-track timeline sequencer engine.
- **`XPadUI`**: Fluid native SwiftUI 6-workspace performance interface (`PLAY`, `HARMONY`, `SEQUENCE`, `MAP`, `LIBRARY`, `PRACTICE`) with `GreenTheme` motion design system.

## Conventions & Patterns
- **Zero Third-Party Dependencies**: Pure native Apple frameworks (`GameController`, `CoreMIDI`, `AVFAudio`, `AppKit`, `SwiftUI`).
- **Clean Separation of Concerns**: Zero UI/Audio imports in `XPadCore` and `XPadTheory`.
- **MainActor Isolation**: UI-bound managers are `@MainActor`; real-time DSP and MIDI queues run on dedicated real-time threads with lock synchronization (`NSLock`).
- **Motion & Accessibility**: All animations in `XPadUI` are layout-safe and strictly observe `@Environment(\.accessibilityReduceMotion)`.
