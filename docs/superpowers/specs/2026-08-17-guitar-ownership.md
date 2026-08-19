# Guitar Ownership Design

Date: 2026-08-17  
Implements: GitHub #22, #23, first slice of #26  
Modules: `XPadTheory`, `XPadController`, `XPadCore`, `XPadAudio`, `XPadUI`

## Problem

PLAY currently re-classifies the same thumb motion every frame:

- Left stick: `AppState.handleChordSelection` used a skip-band at sector edges. The musical selector was still stateless, so rest/risk were “magnitude > 0.3” rather than committed regions. `HarmonicWheel.sector(forAngle:)` is a different angle convention and is **not** the PLAY selector.
- Right stick: `InstrumentPerformanceEngine` inferred bend from X-dominance while notes were held, then set `suppressStrum`. A diagonal strum could become a bend mid-attack.
- Latency: `AudioEngine.noteOn` attaches a new `AVAudioSourceNode` on the attack path with no host-time probe. Issue #26 forbids a speculative voice-pool rewrite.

## Approach (chosen)

Stateful engines in the pure layers; UI and HUD follow committed state.

**Rejected:** visually smoothing a flickering selector (forbidden by #23). **Rejected:** extra mode buttons (#22). **Rejected:** rewriting the synth topology before measuring (#26).

### Left stick — `HarmonicSelectionState`

File: `Sources/XPadTheory/HarmonicSelectionState.swift`

- Angle convention matches PLAY: `atan2(y, x)`, index 0 at north (`π/2`), clockwise.
- Rest: radius `< 0.28` enter / `≥ 0.34` exit. Rest **retains** `committedIndex`.
- Ordinary: middle band, angular hysteresis of 0.18 sector-widths around the committed centre. Fast travel past the expanded band commits the raw index (including wrap 0 ↔ last).
- Risk: enter `≥ 0.82`, exit `≤ 0.72`. Deliberate rim, not accidental contact.
- Visual wheel uses `selectedChordIndex` / `harmonicSelection.region` only. Stick **position** is live, not eased.
- One haptic detent on sector commit (`harmonicCommit`); a second restrained cue on risk entry (`harmonicRisk`). Re-arm by leaving the sector / region.

### Right stick — `RightStickGestureOwnership`

File: `Sources/XPadController/RightStickGestureOwnership.swift`

Guitar/Bass: `idle → strum → sustain → bend → sustain/idle`.

- Vertical acquisition: `|y| ≥ 0.28` and `|y| ≥ |x|`.
- Strum holds until radius `< 0.16`. X wobble cannot steal the attack (`|y| ≥ |x| * 0.55` hold).
- After recentre with notes held: **sustain**. Lateral `|x| ≥ 0.22` and `|x| ≥ |y| * 1.10` acquires **bend**.
- Bend exits at `|x| < 0.10`. Re-entry uses the enter threshold.
- Keys: no strum, no stick bend.
- Strings: Y-dominant **bow**; guitar bend heuristic cannot interrupt bow.
- Lead / generic MPE: independent axes after note acquisition (X bend, Y timbre). `suppressStrum` always. Existing “lead always bends while held” remains so timbre tests stay valid.

`suppressStrum` is derived from ownership, not a duplicate X-dominance flag.

HUD: right-stick role becomes `Strum` / `Sustain` / `Bend` / `Timbre` / `Bow` only while owned; idle keeps the mapping label (no layout jump).

### Latency — `ActionSoundLatencyProbe`

File: `Sources/XPadCore/ActionSoundLatencyProbe.swift`

- Disabled by default. PLAY does not show it.
- Live Test Studio toggle collects host-time: input → gesture → dispatch → `AudioEngine.noteOn` return, plus attach/connect `lastGraphMutationMs`.
- Distributions: p50 / p95 / p99 / jitter (p95 − p50).
- This is **not** acoustic action-to-sound latency. Voice-pool work stays gated on these numbers (#26).

## Files

| File | Role |
|---|---|
| `HarmonicSelectionState.swift` | Committed sector + radial region |
| `RightStickGestureOwnership.swift` | Right-stick state machine |
| `ActionSoundLatencyProbe.swift` | Host-time probe |
| `InstrumentPerformanceEngine.swift` | Ownership drives bend + suppressStrum |
| `AppState.swift` | Wires selection, haptics, probe |
| `HarmonicWheelView.swift` | Committed sector fill, rest/risk rings, live stick |
| `ControllerPerformanceHUD.swift` | Owned-gesture role |
| `AudioEngine.swift` | `lastGraphMutationMs` |
| `ControlSchemeSettingsView.swift` | Diagnostics card |

## Tests

- `HarmonicSelectionStateTests`: north=0, boundary jitter, ±π wrap, rest retain, risk enter/exit.
- `RightStickGestureOwnershipTests`: diagonal strum, strum→sustain→bend, noisy centre, keys, strings bow, lead, engine integration.
- `ActionSoundLatencyProbeTests`: disabled, percentiles, jitter.

## Out of scope (next)

#24 ControlSurfaceProfile, #26 first-buffer timestamp + pool if numbers warrant, #27 periodic vibrato, #28 RealismMode as acceptance policy, #29/#30 DualSense truth, #3 DAW cert.
