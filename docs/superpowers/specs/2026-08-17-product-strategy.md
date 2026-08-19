# XPadInput Product Strategy

Date: 2026-08-17  
Status: Active direction for feature work  
Related: GitHub #22–#33, `DESIGN.md`, `PRODUCT_RESEARCH.md`, `ROADMAP.md`

## Bet

XPadInput is a **theory-deep guitar-MPE workstation**, not a CC mapper. The product is the loop:

**gesture → 5-layer harmonic wheel → voice leading → MPE**

Ship one certifiable DualSense guitar loop before new instruments, AI, Atmos, Scala, hardware, or iOS.

## Honest inventory

| Layer | Status | Implication |
|---|---|---|
| Guitar PLAY (strum, wheel, MPE, HUD, techniques) | End-to-end | This is the product. Protect it. |
| Keys / Lead profiles | Partial | Next instruments, same grammar. |
| Drums / Bass / Strings / Winds / Vocals / Turntable | Spec + stubs | Do not market as shipped. |
| Harmony / Sequence / Library | Real engines, older visual idiom | Function exists; unify onto `XTheme`. |
| MIDI 2 UMP / SMF2 / AUv3 / OSC / Link | Source-complete | Unproven in Live / Logic / Bitwig. |
| Neural co-pilot, Atmos, Scala, dongle, iOS | Roadmap | After the guitar loop is certified. |

## Competitive frame (2026)

- **MIDIpad** is the only real product competitor: DualShock/DualSense guitar+drums, free demo, paid MPE. Do not compete on “two modes + DualSense feel.” Compete on musical causality once the guitar feel is in the same league.
- Universal Controller MIDI / Gamepad MIDI are mapping utilities. Listing CCs is how we lose.

## Feature principles

1. Musical causality: every control answers what note, what function, what expression lane.
2. One grammar: wheel + strummer + triggers + gyro. New instruments reuse it.
3. Guitar is the reference implementation.
4. Feel before breadth: hysteresis and latency beat a seventh profile.
5. Capability honesty: hide DualSense-only chrome on Xbox.
6. Live stick/trigger **position** is never eased (`DESIGN.md` §9.3).
7. Settings stay contained.

## Phases (work, not calendar)

### Phase 0 — Guitar ownership (now)

Issues **#22, #23, #24, #26, #27, #28**, then DualSense truth **#29/#30**, remapping **#25/#32**, DESIGN P0 visual unification, DAW cert **#3/#13/#15**.

Exit: a stranger with a DualSense plays 16 bars in key, one modal interchange, a sustain-bend, and records it into Logic without a settings tutorial.

### Phase 1 — Same grammar, more instruments

Keys, Lead, Bass as vertical slices. OCDS becomes meaningful (guitar + keys). Drums only if DualSense drum feel can beat MIDIpad.

### Phase 2 — Studio gravity

Compact DAW companion, AUv3 as the install path, Sequence round-trip, Library lock-in. MIDI 2 as **certified**, not more encoders.

### Phase 3 — Ambition

Scala, on-device co-pilot (only if better than “What Next?”), Atmos, dongle, iOS. Not before 0–2.

## Defer

Coaching that fades with mastery (**#33**) until mappings are trustworthy. Sony Access research (**#31**) after the main DualSense path is honest.
