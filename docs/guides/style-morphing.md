# Style Morphing & Generative Harmony

XPI can write chord progressions for you, in a style you choose, from a seed you
control. The engine is `StyleMorphEngine` in **XPadTheory**; the style data lives
in `HarmonicStyleDNA` / `HarmonicStyleLibrary`; the UI lives in the Harmony
workspace.

## Concepts

| Type | Role |
| --- | --- |
| `HarmonicStyleDNA` | A style as a small vector of numbers: where the music sits (major/minor lean), which degrees it emphasises, how colourful and how chromatic it is, and how fast the harmony moves. |
| `HarmonicStyleLibrary` | Ten researched dialects — pop/royal road, neo-soul, synthwave, cinematic trailer, lo-fi hip hop, gospel soul, deep house, ambient modal, jazz standard, liquid D&B. |
| `StyleMorphEngine` | Deterministic generator: seed + style + key + scale + bars → a `Progression` of labelled `ChordBlock`s. |
| `DeterministicRandom` (XPadCore) | Seeded SplitMix64 PRNG. Same seed, same music — on every machine, every launch. |

## Generating a progression

```swift
import XPadCore
import XPadTheory

let engine = StyleMorphEngine()

// A neo-soul vamp in D minor, four bars, reproducible from seed 1234.
let vamp = engine.generate(style: HarmonicStyleLibrary.neoSoul, key: .d, bars: 4, seed: 1234)

// Morph between two dialects instead of picking one.
let morph = engine.generate(
    from: HarmonicStyleLibrary.synthwave,
    toward: HarmonicStyleLibrary.cinematicTrailer,
    amount: 0.4,
    key: .b,
    bars: 8,
    seed: 8
)

// Keep an existing progression's rhythm, change its harmony.
let reharmonised = engine.reharmonise(vamp, style: HarmonicStyleLibrary.gospelSoul, seed: 7)
```

The result fills exactly the requested number of 4/4 bars: `durationBeats`
across all blocks always equals `bars * 4`, so a generated progression can be
handed straight to `Sequencer.insertProgressionClip(_:targetTrack:)`.

### Honouring a start degree

`startDegree` is a musical instruction, not a suggestion. The opening chord is
never substituted by the colour layers, so `startDegree: 3` in F minor always
sounds like B♭ minor (the iv) — including in styles whose mediant-shift or
modal-interchange rates are high.

## Inside the generator

Generation runs in three layers, each driven by the style vector:

1. **Degree walk.** Weighted Markov walk over the seven diatonic degrees:
   fourth-up motion is favoured, then fifth-up, then steps, with the tonic
   boosted in the final slot by `cadenceStrength` and ii→V / V→I cadences made
   more likely in strong-cadence styles.
2. **Substitutions.** Chromatic planing (±3/4 semitones, `mediantShiftRate`),
   modal interchange from a borrowed palette (`borrowing`), applied dominants
   (`secondaryDominantRate`, labelled `V7/x`), and tritone substitution of any
   dominant (`tritoneSubstitutionRate`, labelled `subV7`).
3. **Extension colour.** `extensionRichness` walks triads → 7ths → 9ths → 13ths,
   `suspendedColour` swaps in sus4/add9/sus2 voicings, and a diminished triad
   becomes a half-diminished seventh before it turns into a thirteenth.

Roman numerals are produced by the engine itself (a chromatic table plus a
marker suffix), so borrowed and substituted chords are labelled correctly
instead of being forced back into the key's diatonic spelling.

## In the app

The Harmony workspace (**HARMONY**) has a **Style Morph** card:

- **From / To** pickers choose the two dialects.
- The **slider** sets how far to morph between them; the header shows the
  blended name and percentage.
- **Generate** writes a new progression of the chosen bar length in the blended
  style and makes it the performance source, so the left stick performs it
  immediately in Play.
- **Reharmonise** keeps the current progression's rhythm and re-colours its
  harmony.

Both actions advance a seed counter, so repeated presses produce new material
while every result remains reproducible for a given (style, key, scale, bars,
seed) tuple — useful for bug reports and for re-creating a take.

## Tests

- `Tests/XPadTheoryTests/StyleMorphEngineTests.swift` — DNA normalisation,
  blending, determinism, harmonic rhythm, diatonic-only behaviour for a plain
  style, extension richness, and reharmonisation.
- `Sources/XPadTests/main.swift`, suite *"XPadTheory: Style Morphing &
  Deterministic Generation"* — the same properties plus the integration path
  from generated progression → sequenced clips → `AppState` actions.
