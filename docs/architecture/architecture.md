# Architecture

XPadInput is a purely native macOS application written in 100% Swift. 
It requires zero third-party dependencies.

## Modules
- **XPadCore:** Foundational musical types & domain primitives
- **XPadTheory:** Harmony, analysis & progression algorithms
- **XPadController:** GameController hardware abstraction & gesture DSP
- **XPadMIDI:** CoreMIDI virtual endpoints & MPE zone dispatcher
- **XPadAudio:** Real-time multi-voice polyphonic DSP synthesizer & AUv3
- **XPadSequencer:** Tick-based 960 PPQN multi-track timeline engine
- **XPadUI:** Native SwiftUI interface & visualizers
- **XPadPractice:** Practice mode for chord progression learning

See `DESIGN.md` in the project root for deep architectural decisions.
