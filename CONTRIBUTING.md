# Contributing to XPI: Game Controller MIDI

Thank you for your interest in contributing. XPI is a native macOS musical instrument built with pure Swift and Apple frameworks. This guide explains how to work with the codebase effectively.

---

## 1. Before You Start

### Prerequisites
- macOS 14.0 (Sonoma) or later
- Xcode 15+ or Swift 6.0 toolchain
- `git` for version control

### Clone and Build
```bash
git clone https://github.com/your-username/XPadInput.git
cd XPadInput
swift build
swift test
```

---

## 2. Module Boundaries

Respect the separation of concerns defined in `AGENTS.md`:

| Module | Allowed Dependencies | Must Not Import |
| :--- | :--- | :--- |
| `XPadCore` | None | `AVFAudio`, `CoreMIDI`, `SwiftUI`, `GameController` |
| `XPadTheory` | `XPadCore` | `AVFAudio`, `CoreMIDI`, `SwiftUI`, `GameController` |
| `XPadController` | `XPadCore`, `XPadTheory` | `SwiftUI` |
| `XPadMIDI` | `XPadCore`, `XPadTheory` | `SwiftUI` |
| `XPadAudio` | `XPadCore`, `XPadTheory` | `SwiftUI`, `CoreMIDI` |
| `XPadSequencer` | `XPadCore`, `XPadTheory`, `XPadMIDI`, `XPadAudio` | `SwiftUI` |
| `XPadUI` | All above | None (UI layer) |

Pure theory models must remain deterministic, `Sendable` value types with zero side effects.

---

## 3. Concurrency Rules

- **UI state** uses `@MainActor`.
- **Audio render callbacks** (`AVAudioSourceNode`) must never call `async`/`await`, perform blocking I/O, or allocate on the hot path.
- **MIDI queues** use dedicated serial queues with explicit `NSLock` synchronization.
- **Controller callbacks** should publish lightweight state; heavy processing is deferred.

---

## 4. Testing Requirements

- Add tests for every new public type or behaviour.
- Run `swift test` before committing; the suite must pass.
- Theory tests should cover edge cases: enharmonics, boundary intervals, empty collections, and invalid input.
- MIDI tests should verify byte-level encoding where practical.
- Audio tests should validate state-machine transitions, not just sample output.

---

## 5. Commit Conventions

Keep commits structured and semantic:

| Prefix | Use For |
| :--- | :--- |
| `feat:` | New feature or module |
| `fix:` | Bug fix |
| `refactor:` | Code restructuring without behaviour change |
| `test:` | Test additions or corrections |
| `docs:` | Documentation changes |
| `perf:` | Performance improvements |

Example:
```
feat(MIDI): add polyphonic key pressure fallback for legacy synths
```

---

## 6. Task Tracking with Beads (`bd`)

This repository uses **Beads (`bd`)** backed by Dolt for distributed issue and milestone tracking:

```bash
# View available ready tasks
bd ready

# View issue details
bd show <issue-id>

# Claim an issue to work on
bd update <issue-id> --claim

# Complete and close work
bd close <issue-id>
```

---

## 7. Filesystem Sanitation

Purge AppleDouble files before committing:
```bash
dot_clean .
git status
```

Do not commit `._*` files, `.DS_Store`, or release/agentic build artifacts (enforced via `.gitignore`).

---

## 8. Continuous Integration & Release Gate

Every push and PR runs through the GitHub Actions macOS CI workflow (`.github/workflows/macos-ci.yml`):
- `swift package resolve` & `swift build`
- `swift test` (all unit test suites)
- Release `XPI.app` packaging and `.dmg` / `.zip` artifact validation with SHA-256 checksums

Ensure all local tests pass (`swift test`) before opening a PR.

---

## 9. Documentation Updates

When changing behaviour, update the relevant spec:

- Musical or MIDI behaviour changes → `MIDI_MPE_SPEC.md` or `INSTRUMENT_TECHNIQUES.md`
- UI/interaction changes → `DESIGN.md`
- Architecture or performance changes → `TECH_STACK.md`
- Milestone changes → `ROADMAP.md`
- MIDI 2.0 / MIDI-CI changes → `MIDI2_ROADMAP.md`

---

## 10. Design Review

Before merging, verify against the checklist in `DESIGN.md` §27:

- Musical causality is visible, not just raw telemetry.
- The mapping leverages familiar gamepad ergonomics.
- Colour is never the only differentiator.
- Display state is separated from musical state.
- No gratuitous high-frequency SwiftUI invalidation.

---

## 11. Questions

- Issue tracking & task discovery: run `bd ready` or check [GitHub Issues](https://github.com/sp80808/XPadInput/issues).
- Design direction: reference `DESIGN.md` and `SOUL.md`.

