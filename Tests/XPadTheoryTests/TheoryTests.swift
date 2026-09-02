import XCTest
@testable import XPadCore
@testable import XPadTheory

final class TheoryTests: XCTestCase {

    // MARK: - Harmonic Degree Tests
    func testHarmonicDegreeProperties() {
        let chord = Chord(root: .c, quality: .major)
        let degree = HarmonicDegree(
            romanNumeral: .I,
            chord: chord,
            harmonicFunction: "Tonic",
            description: "Tonic Root chord of C Major"
        )

        XCTAssertEqual(degree.romanNumeral, .I)
        XCTAssertEqual(degree.chord.symbol, "C")
        XCTAssertEqual(degree.harmonicFunction, "Tonic")
        XCTAssertEqual(degree.id, "I_C")
    }

    // MARK: - Harmonic Wheel Tests
    func testHarmonicWheelLayers() {
        let cMajorWheel = HarmonicWheel(scale: .cMajor)

        for layer in WheelLayer.allCases {
            let sectors = cMajorWheel.sectorsByLayer[layer]
            XCTAssertNotNil(sectors)
            XCTAssertFalse(sectors?.isEmpty ?? true)
        }

        let diatonicSectors = cMajorWheel.sectorsByLayer[.diatonic] ?? []
        XCTAssertEqual(diatonicSectors.count, 7)
        XCTAssertEqual(diatonicSectors[0].chord.symbol, "C")
        XCTAssertEqual(diatonicSectors[1].chord.symbol, "Dm")
        XCTAssertEqual(diatonicSectors[2].chord.symbol, "Em")
        XCTAssertEqual(diatonicSectors[3].chord.symbol, "F")
        XCTAssertEqual(diatonicSectors[4].chord.symbol, "G")
        XCTAssertEqual(diatonicSectors[5].chord.symbol, "Am")
        XCTAssertEqual(diatonicSectors[6].chord.symbol, "B°")

        let aMinorWheel = HarmonicWheel(scale: .aMinor)
        let minorDiatonic = aMinorWheel.sectorsByLayer[.diatonic] ?? []
        XCTAssertEqual(minorDiatonic.count, 7)
        XCTAssertEqual(minorDiatonic[0].chord.symbol, "Am")
    }

    func testHarmonicWheelAngleLookup() {
        let wheel = HarmonicWheel(scale: .cMajor)

        let northSector = wheel.sector(forAngle: -Double.pi / 2.0, layer: .diatonic)
        XCTAssertNotNil(northSector)
        XCTAssertEqual(northSector?.chord.root, .c)

        for angle in stride(from: -Double.pi, through: Double.pi, by: 0.5) {
            let sector = wheel.sector(forAngle: angle, layer: .diatonic)
            XCTAssertNotNil(sector)
        }
    }

    func testHarmonicWheelNonHeptatonicScales() {
        let pentMajor = HarmonicWheel(scale: .pentatonicMajor)
        let pentMinor = HarmonicWheel(scale: Scale(root: .a, type: .pentatonicMinor))
        let blues = HarmonicWheel(scale: .blues)
        let chromatic = HarmonicWheel(scale: .chromatic)

        for wheel in [pentMajor, pentMinor, blues, chromatic] {
            for layer in WheelLayer.allCases {
                let sectors = wheel.sectorsByLayer[layer]
                XCTAssertNotNil(sectors, "\(wheel.scale.name) missing \(layer.rawValue)")
                XCTAssertFalse(sectors?.isEmpty ?? true, "\(wheel.scale.name) empty \(layer.rawValue)")
            }
            for angle in stride(from: -Double.pi, through: Double.pi, by: 0.25) {
                XCTAssertNotNil(wheel.sector(forAngle: angle, layer: .diatonic))
                XCTAssertNotNil(wheel.sector(forAngle: angle, layer: .tension))
            }
        }

        let pentDiatonic = pentMajor.sectorsByLayer[.diatonic] ?? []
        XCTAssertEqual(pentDiatonic.count, 5)
        XCTAssertEqual(pentDiatonic.map(\.romanNumeral), ["I", "ii", "iii", "V", "vi"])
        XCTAssertEqual(pentDiatonic.map(\.chord.root), [PitchClass.c, .d, .e, .g, .a])

        let pentTension = pentMajor.sectorsByLayer[.tension] ?? []
        XCTAssertFalse(pentTension.contains { $0.romanNumeral == "V7/IV" })
        XCTAssertTrue(pentTension.contains { $0.romanNumeral == "V7" })
        XCTAssertTrue(pentTension.contains { $0.romanNumeral == "V7/V" })
        XCTAssertTrue(pentTension.contains { $0.romanNumeral == "V7/vi" })

        let minorDiatonic = pentMinor.sectorsByLayer[.diatonic] ?? []
        XCTAssertEqual(minorDiatonic.count, 5)
        XCTAssertEqual(minorDiatonic.map(\.romanNumeral), ["i", "III", "iv", "v", "VII"])
        XCTAssertEqual(minorDiatonic.map(\.chord.root), [PitchClass.a, .c, .d, .e, .g])

        let bluesDiatonic = blues.sectorsByLayer[.diatonic] ?? []
        XCTAssertEqual(bluesDiatonic.count, 6)
        XCTAssertEqual(bluesDiatonic.map(\.romanNumeral), ["i", "III", "iv", "♭V°", "v", "VII"])
        XCTAssertEqual(bluesDiatonic[3].chord.quality, .diminished)

        let chromaticDiatonic = chromatic.sectorsByLayer[.diatonic] ?? []
        XCTAssertEqual(chromaticDiatonic.count, 12)
        XCTAssertEqual(chromaticDiatonic.map(\.chord.root).count, 12)
        XCTAssertEqual(Set(chromaticDiatonic.map(\.chord.root)).count, 12)
    }

    // MARK: - Voice Leading Engine Tests
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
            XCTAssertFalse(optimized.isEmpty)
            XCTAssertEqual(optimized.count, 3)
            for note in optimized {
                XCTAssertTrue([PitchClass.g, .b, .d].contains(note.pitchClass))
            }
        }
    }

    func testVoiceLeadingCommonTones() {
        let engine = VoiceLeadingEngine()
        let cMaj = Chord(root: .c, quality: .major)
        let aMin = Chord(root: .a, quality: .minor)

        let cVoicing = cMaj.voicedNotes(baseOctave: 3)
        let aVoicing = engine.optimizeTransition(from: cVoicing, to: aMin, strategy: .smooth)

        let commonPitchClasses = Set(aVoicing.map { $0.pitchClass }).intersection([.c, .e])
        XCTAssertEqual(commonPitchClasses.count, 2)
    }

    func testVoiceLeadingEmptyVoicing() {
        let engine = VoiceLeadingEngine()
        let targetChord = Chord(root: .f, quality: .major7)
        let result = engine.optimizeTransition(from: [], to: targetChord, strategy: .smooth)
        XCTAssertEqual(result.count, 4)
    }

    // MARK: - Harmonic Suggestion Engine Tests
    func testHarmonicSuggestionsGeneration() {
        let engine = HarmonicSuggestionEngine()
        let currentChord = Chord(root: .c, quality: .major)
        let suggestions = engine.suggestions(for: currentChord, in: .cMajor)

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.count <= 20)

        let resolutions = suggestions.filter { $0.category == .resolution }
        XCTAssertFalse(resolutions.isEmpty)

        let cinematic = suggestions.filter { $0.category == .cinematic }
        XCTAssertFalse(cinematic.isEmpty)

        for i in 0..<(suggestions.count - 1) {
            XCTAssertTrue(suggestions[i].score >= suggestions[i + 1].score)
        }
    }

    // MARK: - Modulation Engine Tests
    func testModulationPathwaysGeneration() {
        let engine = ModulationEngine()
        let source = Scale.cMajor
        let target = Scale(root: .g, type: .major)

        let paths = engine.pathways(from: source, to: target)
        XCTAssertFalse(paths.isEmpty)
        XCTAssertTrue(paths.contains(where: { $0.type == .dominantCycle }))

        let targetEb = Scale(root: .dSharp, type: .major)
        let mediantPaths = engine.pathways(from: source, to: targetEb)
        XCTAssertTrue(mediantPaths.contains(where: { $0.type == .chromaticMediant }))
    }

    // MARK: - Progression Tests
    func testProgressionFactoryPresets() {
        let majorPresets = Progression.factoryPresets(for: .cMajor)
        XCTAssertTrue(majorPresets.count >= 3)

        for p in majorPresets {
            XCTAssertFalse(p.blocks.isEmpty)
            XCTAssertTrue(p.totalBeats > 0)
        }

        let minorPresets = Progression.factoryPresets(for: .aMinor)
        XCTAssertTrue(minorPresets.count >= 2)
    }

    func testProgressionMutation() {
        let popProgression = Progression.factoryPresets(for: .cMajor).first!
        let mutatedWithPreservedRoots = popProgression.mutated(complexity: 0.5, preserveRoots: true)

        XCTAssertEqual(mutatedWithPreservedRoots.blocks.count, popProgression.blocks.count)
        XCTAssertTrue(mutatedWithPreservedRoots.name.contains("Mutated"))

        let mutatedAdventurous = popProgression.mutated(complexity: 1.0, preserveRoots: false)
        XCTAssertEqual(mutatedAdventurous.blocks.count, popProgression.blocks.count)
    }
}
