---
name: theory-dsp-testing
description: Specialized instructions and workflows for validating 12-TET music theory algorithms, DSP audio engines, CoreMIDI MPE routers, and running test suites for XPadInput.
---

# Theory & DSP Testing Skill

When working on musical algorithms, DSP synthesis, or MIDI routing in XPadInput:

## 1. Validating Theory Changes
- **PitchClass & Enharmonics**: Whenever modifying pitch spelling or Circle of Fifths mappings, verify that standard names prefer flats for accidentals (`D♭`, `E♭`, `A♭`, `B♭`) except for `F♯`.
- **Inversion & Voicing Algorithms**: Ensure voice ranges remain within humanly playable piano/guitar registers (MIDI 36 to 84).
- **Voice Leading**: Always test edge cases (empty voicing transition, extreme jumps, large chords to dyads).

## 2. Audio & DSP Safety
- **No Dynamic Heap Allocation in Audio Thread**: Never call `malloc`, `Array.append`, or allocate reference types inside `AVAudioSourceNode` block.
- **Phase Continuity**: Ensure oscillator phases wrap smoothly within $[0.0, 1.0)$ to prevent audible clicks.
- **Soft Limiting**: Always pass mixed multi-voice output through `tanh(mix * 0.4)` soft saturation to protect speaker outputs and user ears.

## 3. Running Automated Tests
Execute the universal test runner:
```bash
swift run XPadTests
```
Ensure all suites pass with 0 failures before committing.
