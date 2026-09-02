# XPadInput Codebase Improvement Plan

> **Audit Date:** 2026-08-22
> **Status:** Living document tracking necessary codebase improvements

---

## Priority 1: Critical (Fix Immediately)

### 1.1 Silent Error Swallowing in CoreHapticsEngine
**File:** `Sources/XPadController/CoreHapticsEngine.swift`
**Lines:** 65, 208, 214, 258

Empty `catch {}` blocks silently discard all CoreHaptics errors, making debugging impossible.

```swift
// Current (bad)
do {
    try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
} catch {}

// Suggested fix
do {
    try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
} catch {
    print("⚠️ CoreHaptics stop failed: \(error)")
}
```

---

### 1.2 Silent Error Swallowing in Persistence Layer
**File:** `Sources/XPadController/ControllerCalibration.swift`
**Lines:** 245, 255, 285, 297

All `UserDefaults` persistence failures are caught and only printed. User data can be lost without awareness.

**Fix:** Surface decode/encode failures through a delegate callback or error state property so the UI can alert the user.

---

### 1.3 Excessive Heap Allocation on Audio Hot Path
**File:** `Sources/XPadAudio/AudioEngine.swift`
**Lines:** 555, 583, 947

`AVAudioFormat(standardFormatWithSampleRate:channels:)` is allocated on every `noteOn` and `triggerDrum` call, creating heap pressure during fast playing.

**Fix:** Cache a single `AVAudioFormat` instance at init time and reuse it.

```swift
// At init time
private let voiceFormat: AVAudioFormat

// In noteOn/triggerDrum
// Replace: let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
// With: use cached voiceFormat
```

---

### 1.4 Timer-Based Voice Release on Main Thread
**File:** `Sources/XPadAudio/AudioEngine.swift`
**Lines:** 597, 616

Voice release tails are scheduled via `DispatchQueue.main.asyncAfter`. Main thread jitter can cut release tails early or cause voice leaks.

**Fix:** Use a dedicated high-priority serial dispatch queue for voice release scheduling, or drive release from the audio render callback itself.

---

## Priority 2: High (Fix Soon)

### 2.1 AppState is a God Object (1336 lines)
**File:** `Sources/XPadUI/AppState.swift`

AppState handles controller input routing, chord logic, MIDI passthru, host detection, practice mode, strumming, expression dispatch, and UI state—all in one class.

**Fix:** Extract focused coordinators:
- `ChordPerformanceCoordinator` — chord selection, strumming, voice-led chord logic
- `ExpressionRouter` — pitch/pressure/timbre dispatch
- `HostDetectionManager` — DAW auto-detect
- `PracticeSessionController` — practice mode lifecycle

---

### 2.2 Sequencer Timer Creates 1920 Tasks/Second
**File:** `Sources/XPadSequencer/Sequencer.swift`
**Lines:** 148-153

The 960-PPQN clock creates a new `Task { @MainActor in self.tick() }` on every timer fire. At 120 BPM, this is ~1920 tasks per second.

**Fix:** Use `DispatchQueue.main.async` directly instead of `Task`, or make `tick()` `nonisolated` with thread-safe state mutation.

---

### 2.3 Missing @MainActor on ControllerManager
**File:** `Sources/XPadController/ControllerManager.swift`
**Line:** 8

`ControllerManager` is `@Observable` but not `@MainActor`. It mutates state from `GCController` callbacks which run on an arbitrary queue, creating a data race risk.

**Fix:** Add `@MainActor` to the class declaration.

```swift
@MainActor
public final class ControllerManager: ObservableObject {
```

---

### 2.4 XPadAUInstrument Duplicates SynthVoice DSP
**File:** `Sources/XPadAudio/AUv3/XPadAUInstrument.swift`
**Lines:** 83-304

The AUv3 render block contains ~220 lines of DSP code nearly identical to `AudioEngine.SynthVoice`. Any DSP change must be applied twice.

**Fix:** Extract DSP math into a shared `VoiceDSP` struct or static methods that both `SynthVoice` and `AUPolyVoice` can call.

---

### 2.5 Significant Test Coverage Gaps

| Component | Test Status |
|-----------|-------------|
| `ControllerManager` | No tests for input routing, scheme switching, or calibration |
| `MIDIManager` | No tests for virtual port lifecycle, message emission, panic |
| `AudioEngine` | No tests for `noteOn`/`noteOff`, voice stealing, panic |
| `AppState` | No tests for the central coordinator |
| `Sequencer` | Only basic transport tests; no clock accuracy or recording |

**Fix:** Add test files:
- `XPadControllerTests/ControllerManagerTests.swift`
- `XPadMIDITests/MIDIEngineTests.swift`
- `XPadAudioTests/AudioEngineTests.swift`
- `XPadSequencerTests/SequencerClockTests.swift`

---

## Priority 3: Medium (Fix When Convenient)

### 3.1 Redundant Alias Properties
**Files:** Multiple

Several computed properties are trivial aliases that bloat the API:
- `Note.midiNumber` → `midiNote`
- `Note.name` → `displayName`
- `Chord.symbol` → `displayName`
- `Chord.voicedNotes` → `voiced`
- `Interval.shortName` → `name`
- `PitchClass.interval(to:)` → `semitones(to:)`
- `PitchClass.standardName` → `displayName`

**Fix:** Remove aliases and update callers, or mark as deprecated.

---

### 3.2 Inconsistent Enum Naming Conventions
**Files:** Multiple

- `VirtualPort` uses lowercase raw values (`"main"`, `"chords"`)
- `MIDITransportProtocol` uses `"midi1"`, `"midi2"` (lowercase)
- `ControllerKind` mixes `dualSense`, `dualShock4`, `switchPro`, `steamDeck`

**Fix:** Establish PascalCase for enum cases and descriptive strings for raw values.

---

### 3.3 Potential Retain Cycle in AppState Notification Observer
**File:** `Sources/XPadUI/AppState.swift`
**Lines:** 184-198

The `NSWorkspace.didActivateApplicationNotification` observer is stored but never removed in `deinit`.

**Fix:** Add cleanup in `deinit`:
```swift
deinit {
    if let observer = hostDetectionObserver {
        NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
}
```

---

### 3.4 Lock Usage Should Use `defer`
**File:** `Sources/XPadMIDI/MIDIManager.swift`
**Lines:** 405-411, 440-444, 752-757

Lock/unlock sequences are error-prone. If an early return is added between `lock()` and `unlock()`, the lock will be held indefinitely.

**Fix:** Use `defer { lock.unlock() }` immediately after `lock.lock()`.

---

### 3.5 XPadTests/main.swift is a Legacy Test Runner
**File:** `Sources/XPadTests/main.swift`
**Lines:** 1-2480

The project has both a legacy custom test runner (2480 lines) and modern XCTest targets. The legacy runner duplicates test logic and is not integrated with `swift test`.

**Fix:** Migrate remaining tests from `main.swift` into proper XCTest test targets and remove the `XPadTests` executable target from `Package.swift`.

---

### 3.6 ControllerCapabilityProfile Maps DualShock4 to DualSense
**File:** `Sources/XPadController/GamepadState.swift`
**Line:** 232

`ControllerCapabilityProfile.from` returns `.dualSense` for both DualSense and DualShock 4, but DualShock 4 lacks adaptive triggers and some haptic features.

**Fix:** Return a distinct `.dualShock4` profile with correct capabilities.

---

## Priority 4: Low (Nice to Have)

### 4.1 Magic Numbers in DSP and MIDI Code
**Files:** Multiple

- `AudioEngine.swift` line 1096: `0.45` (master gain scalar)
- `AudioEngine.swift` line 979: `0.49` (phase increment clamp)
- `MIDIManager.swift` line 1221: `12` (lastSentNotes capacity)
- `ChordVoicing.swift` line 65: `18` (crossing penalty)

**Fix:** Extract to `static let` constants with semantic names.

---

### 4.2 Scale Has Two `pitchClasses` Methods With Conflicting Semantics
**File:** `Sources/XPadCore/Scale.swift`
**Lines:** 81-83, 93-95

`pitchClasses` (computed property) uses `self.root`, while `pitchClasses(root:)` takes a parameter.

**Fix:** Keep the parameterized version and remove the computed property, or make the computed property delegate explicitly.

---

### 4.3 Force-Unwraps in Music Theory Code
**Files:**
- `Sources/XPadCore/PitchClass.swift` line 83
- `Sources/XPadCore/Note.swift` line 37
- `Sources/XPadAudio/AudioEngine.swift` line 555

**Fix:** Replace force-unwraps with nil-coalescing for defensive programming.

---

### 4.4 Redundant Static Arrays
**Files:**
- `Sources/XPadCore/Scale.swift` line 150
- `Sources/XPadAudio/AudioEngine.swift` line 256
- `Sources/XPadController/InputProcessingProfile.swift` line 63

`allScales`, `allPresets`, and similar arrays are computed at load time but rarely used.

**Fix:** Make them computed properties or lazy, or remove if unused.

---

## Architecture Observations

### Positive Findings
- **Module boundaries are clean:** `XPadCore` and `XPadTheory` have zero UI/audio/MIDI imports
- **Concurrency model is sound:** Real-time audio uses `NSLock` with `trySnapshot()` for non-blocking reads
- **No third-party dependencies:** Project correctly uses only Apple frameworks
- **@MainActor used appropriately:** On UI-bound classes (`AppState`, `PracticeEngine`, `Sequencer`)

### Areas for Improvement
- `XPadController` conditionally imports `AppKit` for `NSHapticFeedbackManager` fallback—acceptable but creates platform dependency
- `@unchecked Sendable` on `@Observable` classes is necessary but should be reviewed as Swift evolves

---

## Testing Coverage Summary

| Module | Source Files | Test Files | Coverage Assessment |
|--------|-------------|------------|---------------------|
| XPadCore | 17 | 6 | Good |
| XPadTheory | 10 | 4 | Good |
| XPadController | 32 | 11 | Moderate (no ControllerManager tests) |
| XPadMIDI | 8 | 7 | Moderate (no MIDIEngine tests) |
| XPadAudio | 8 | 7 | Moderate (no AudioEngine tests) |
| XPadSequencer | 1 | 1 | Poor (no clock or recording tests) |
| XPadPractice | 3 | 1 | Poor (no practice engine tests) |
| XPadUI | 22 | 0 | None |

---

## Recommended Implementation Order

1. Replace all empty `catch {}` blocks with proper error handling
2. Cache `AVAudioFormat` in AudioEngine
3. Refactor AppState into focused coordinators
4. Fix Sequencer timer task creation overhead
5. Add `@MainActor` to ControllerManager
6. Deduplicate DSP between SynthVoice and XPadAUInstrument
7. Add missing unit tests for critical components
8. Remove redundant alias properties
9. Use `defer` for lock unlock patterns
10. Remove legacy XPadTests/main.swift
