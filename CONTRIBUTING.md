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

## 6. Filesystem Sanitation

Purge AppleDouble files before committing:
```bash
dot_clean .
git status
```

Do not commit `._*` files, `.DS_Store`, or build artifacts.

---

## 7. Documentation Updates

When changing behaviour, update the relevant spec:

- Musical or MIDI behaviour changes → `MIDI_MPE_SPEC.md` or `INSTRUMENT_TECHNIQUES.md`
- UI/interaction changes → `DESIGN.md`
- Architecture or performance changes → `TECH_STACK.md`
- Milestone changes → `ROADMAP.md`

---

## 8. Design Review

Before merging, verify against the checklist in `DESIGN.md` §27:

- Musical causality is visible, not just raw telemetry.
- The mapping leverages familiar gamepad ergonomics.
- Colour is never the only differentiator.
- Display state is separated from musical state.
- No gratuitous high-frequency SwiftUI invalidation.

---

## 9. Questions

- Existing discussion: open an issue with the `question` label.
- Design direction: reference `DESIGN.md` and `SOUL.md`.
