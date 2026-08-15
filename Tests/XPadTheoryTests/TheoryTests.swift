import Testing
import Foundation
@testable import XPadCore
@testable import XPadTheory

@Suite("Exhaustive Music Theory Engine Tests")
struct TheoryTests {

    // MARK: - Harmonic Degree Tests
    @Test("Harmonic Degree Initialization and Properties")
    func testHarmonicDegreeProperties() {
        let chord = Chord(root: .c, quality: .major)
        let degree = HarmonicDegree(
            romanNumeral: .I,
            chord: chord,
            harmonicFunction: "Tonic",
            description: "Tonic Root chord of C Major"
        )

        #expect(degree.romanNumeral == .I)
        #expect(degree.chord.symbol == "C")
        #expect(degree.harmonicFunction == "Tonic")
        #expect(degree.id == "I_C")
    }

    // MARK: - Harmonic Wheel Tests
    @Test("Harmonic Wheel Construction for Major and Minor Scales")
    func testHarmonicWheelLayers() {
        let cMajorWheel = HarmonicWheel(scale: .cMajor)

        // All 5 layers should be populated
        for layer in WheelLayer.allCases {
            let sectors = cMajorWheel.sectorsByLayer[layer]
            #expect(sectors != nil)
            #expect(!(sectors?.isEmpty ?? true))
        }

        // Diatonic layer should have 7 chords
        let diatonicSectors = cMajorWheel.sectorsByLayer[.diatonic] ?? []
        #expect(diatonicSectors.count == 7)
        #expect(diatonicSectors[0].chord.symbol == "C")
        #expect(diatonicSectors[1].chord.symbol == "Dm")
        #expect(diatonicSectors[2].chord.symbol == "Em")
        #expect(diatonicSectors[3].chord.symbol == "F")
        #expect(diatonicSectors[4].chord.symbol == "G")
        #expect(diatonicSectors[5].chord.symbol == "Am")
        #expect(diatonicSectors[6].chord.symbol == "Bdim")

        // Test Minor Wheel
        let aMinorWheel = HarmonicWheel(scale: .aMinor)
        let minorDiatonic = aMinorWheel.sectorsByLayer[.diatonic] ?? []
        #expect(minorDiatonic.count == 7)
        #expect(minorDiatonic[0].chord.symbol == "Am")
    }

    @Test("Harmonic Wheel Polar Sector Angle Lookup")
    func testHarmonicWheelAngleLookup() {
        let wheel = HarmonicWheel(scale: .cMajor)

        // North (-pi/2) corresponds to index 0 (I - C major)
        let northSector = wheel.sector(forAngle: -Double.pi / 2.0, layer: .diatonic)
        #expect(northSector != nil)
        #expect(northSector?.chord.root == .c)

        // Sweeping across angles returns valid sectors
        for angle in stride(from: -Double.pi, through: Double.pi, by: 0.5) {
            let sector = wheel.sector(forAngle: angle, layer: .diatonic)
            #expect(sector != nil)
        }
    }

    // MARK: - Voice Leading Engine Tests
    @Test("Voice Leading Optimization Across Strategies")
    func testVoiceLeadingStrategies() {
        let engine = VoiceLeadingEngine()
        let cMaj = Chord(root: .c, quality: .major)
        let gMaj = Chord(root: .g, quality: .major)

        let initialVoicing = cMaj.voicedNotes(baseOctave: 3)

        for strategy in VoiceLeadingStrategy.allCases {
            let optimized = engine.optimizeTransition(
                from: initialVoicing,
                to: gMaj,
                strategy: strategy,
                baseOctave: 3
            )
            #expect(!optimized.isEmpty)
            #expect(optimized.count == 3)
            // Each note in G major should be G, B, or D
            for note in optimized {
                #expect([PitchClass.g, .b, .d].contains(note.pitchClass))
            }
        }
    }

    @Test("Voice Leading Smooth Transition Keeps Common Tones")
    func testVoiceLeadingCommonTones() {
        let engine = VoiceLeadingEngine()
        let cMaj = Chord(root: .c, quality: .major) // C, E, G
        let aMin = Chord(root: .a, quality: .minor) // A, C, E

        let cVoicing = cMaj.voicedNotes(baseOctave: 3)
        let aVoicing = engine.optimizeTransition(from: cVoicing, to: aMin, strategy: .smooth)

        // C and E should be preserved exactly in position or close
        let commonPitchClasses = Set(aVoicing.map { $0.pitchClass }).intersection([.c, .e])
        #expect(commonPitchClasses.count == 2)
    }

    @Test("Voice Leading Empty Voicing Fallback")
    func testVoiceLeadingEmptyVoicing() {
        let engine = VoiceLeadingEngine()
        let targetChord = Chord(root: .f, quality: .major7)
        let result = engine.optimizeTransition(from: [], to: targetChord, strategy: .smooth)
        #expect(result.count == 4)
    }

    // MARK: - Harmonic Suggestion Engine Tests
    @Test("Harmonic Suggestion Engine Multi-Category Suggestions")
    func testHarmonicSuggestionsGeneration() {
        let engine = HarmonicSuggestionEngine()
        let currentChord = Chord(root: .c, quality: .major)
        let suggestions = engine.suggestions(for: currentChord, in: .cMajor)

        #expect(!suggestions.isEmpty)
        #expect(suggestions.count <= 20)

        // Must contain resolution suggestions (e.g. G7 -> C)
        let resolutions = suggestions.filter { $0.category == .resolution }
        #expect(!resolutions.isEmpty)

        // Must contain cinematic mediant suggestions
        let cinematic = suggestions.filter { $0.category == .cinematic }
        #expect(!cinematic.isEmpty)

        // Ensure scored descending order
        for i in 0..<(suggestions.count - 1) {
            #expect(suggestions[i].score >= suggestions[i + 1].score)
        }
    }

    // MARK: - Modulation Engine Tests
    @Test("Modulation Pathways Search Across Multiple Key Centers")
    func testModulationPathwaysGeneration() {
        let engine = ModulationEngine()
        let source = Scale.cMajor
        let target = Scale(root: .g, type: .major) // Dominant key modulation

        let paths = engine.pathways(from: source, to: target)
        #expect(!paths.isEmpty)

        // Should include ii-V-I dominant cycle
        #expect(paths.contains(where: { $0.type == .dominantCycle }))

        // Modulation to chromatic mediant (C to E flat)
        let targetEb = Scale(root: .dSharp, type: .major) // Eb is dSharp rawValue 3
        let mediantPaths = engine.pathways(from: source, to: targetEb)
        #expect(mediantPaths.contains(where: { $0.type == .chromaticMediant }))
    }

    // MARK: - Progression Tests
    @Test("Progression Total Beats and Factory Presets")
    func testProgressionFactoryPresets() {
        let majorPresets = Progression.factoryPresets(for: .cMajor)
        #expect(majorPresets.count >= 3)

        for p in majorPresets {
            #expect(!p.blocks.isEmpty)
            #expect(p.totalBeats > 0)
        }

        let minorPresets = Progression.factoryPresets(for: .aMinor)
        #expect(minorPresets.count >= 2)
    }

    @Test("Progression Mutation Function")
    func testProgressionMutation() {
        let popProgression = Progression.factoryPresets(for: .cMajor).first!
        let mutatedWithPreservedRoots = popProgression.mutated(complexity: 0.5, preserveRoots: true)

        #expect(mutatedWithPresatedCount: mutatedWithPreservedRoots.blocks.count == popProgression.blocks.count)
        #expect(mutatedWithPreservedRoots.name.contains("Mutated"))

        let mutatedAdventurous = popProgression.mutated(complexity: 1.0, preserveRoots: false)
        #expect(mutatedAdventurous.blocks.count == popProgression.blocks.count)
    }
}
