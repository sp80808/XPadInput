# MPE Configuration

MIDI Polyphonic Expression (MPE) allows per-note pitch bend, pressure, and timbre.

## Host DAW Setup
Most modern DAWs support MPE. When using XPadInput's Virtual MIDI or AUv3 plugins:
- Enable MPE on the receiving track.
- Set the Pitch Bend Range to match XPadInput (default is ±48 semitones).

XPadInput broadcasts MPE Zone Configurations automatically when Virtual MIDI is enabled.
