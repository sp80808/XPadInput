import XCTest
@testable import XPadCore
@testable import XPadTheory

final class StyleMorphEngineTests: XCTestCase {

    private let engine = StyleMorphEngine()

    // MARK: - DeterministicRandom

    func testSeededRandomIsReproducible() {
        var a = DeterministicRandom(seed: 42)
        var b = DeterministicRandom(seed: 42)
        for _ in 0..<32 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testSeededRandomDiffersAcrossSeeds() {
        var a = DeterministicRandom(seed: 1)
        var b = DeterministicRandom(seed: 2)
        let streamA = (0..<8).map { _ in a.next() }
        let streamB = (0..<8).map { _ in b.next() }
        XCTAssertNotEqual(streamA, streamB)
    }

    func testStringSeedIsStable() {
        var a = DeterministicRandom(seed: "Neo-Soul Vamp")
        var b = DeterministicRandom(seed: "Neo-Soul Vamp")
        XCTAssertEqual(a.next(), b.next())
    }

    func testWeightedPickIgnoresZeroWeights() {
        var random = DeterministicRandom(seed: 7)
        for _ in 0..<64 {
            let index = random.pickWeightedIndex(weights: [0, 0, 1, 0])
            XCTAssertEqual(index, 2)
        }
    }

    // MARK: - Style DNA

    func testNormalisationClampsAndBalancesWeights() {
        let wild = HarmonicStyleDNA(
            name: "Wild",
            degreeWeights: [-4, 2, 2, 2, 2, 2, 2, 2, 2],
            minorLean: 4,
            extensionRichness: -3,
            suspendedColour: 8,
            borrowing: -1,
            secondaryDominantRate: 3,
            tritoneSubstitutionRate: -9,
            mediantShiftRate: 12,
            chordsPerBar: 99,
            cadenceStrength: -5
        ).normalised()

        XCTAssertEqual(wild.degreeWeights.count, HarmonicStyleDNA.degreeCount)
        XCTAssertEqual(wild.degreeWeights.reduce(0, +), 1.0, accuracy: 0.0001)
        XCTAssertEqual(wild.minorLean, 1.0, accuracy: 0.0001)
        XCTAssertEqual(wild.extensionRichness, 0.0, accuracy: 0.0001)
        XCTAssertEqual(wild.suspendedColour, 1.0, accuracy: 0.0001)
        XCTAssertEqual(wild.borrowing, 0.0, accuracy: 0.0001)
        XCTAssertEqual(wild.secondaryDominantRate, 1.0, accuracy: 0.0001)
        XCTAssertEqual(wild.mediantShiftRate, 1.0, accuracy: 0.0001)
        XCTAssertEqual(wild.chordsPerBar, 4.0, accuracy: 0.0001)
        XCTAssertEqual(wild.cadenceStrength, 0.0, accuracy: 0.0001)
    }

    func testZeroWeightsFallBackToUniformDistribution() {
        let empty = HarmonicStyleDNA(
            name: "Empty",
            degreeWeights: [],
            minorLean: 0,
            extensionRichness: 0,
            borrowing: 0,
            secondaryDominantRate: 0,
            chordsPerBar: 1,
            cadenceStrength: 0
        ).normalised()

        for weight in empty.degreeWeights {
            XCTAssertEqual(weight, 1.0 / Double(HarmonicStyleDNA.degreeCount), accuracy: 0.0001)
        }
    }

    // MARK: - Morphing

    func testBlendEndpointsReturnTheOriginals() {
        let start = HarmonicStyleLibrary.synthwave
        let end = HarmonicStyleLibrary.neoSoul

        let atZero = HarmonicStyleDNA.blend(start, end, amount: 0)
        let atOne = HarmonicStyleDNA.blend(start, end, amount: 1)

        XCTAssertEqual(atZero.name, start.name)
        XCTAssertEqual(atOne.name, end.name)
        for (lhs, rhs) in zip(atZero.degreeWeights, start.normalised().degreeWeights) {
            XCTAssertEqual(lhs, rhs, accuracy: 0.0001)
        }
        XCTAssertEqual(atOne.extensionRichness, end.normalised().extensionRichness, accuracy: 0.0001)
    }

    func testBlendIsLinearPerAxis() {
        let start = HarmonicStyleLibrary.popRoyalRoad
        let end = HarmonicStyleLibrary.cinematicTrailer
        let half = HarmonicStyleDNA.blend(start, end, amount: 0.5)

        let a = start.normalised()
        let b = end.normalised()

        XCTAssertEqual(half.extensionRichness, (a.extensionRichness + b.extensionRichness) / 2, accuracy: 0.0001)
        XCTAssertEqual(half.borrowing, (a.borrowing + b.borrowing) / 2, accuracy: 0.0001)
        XCTAssertEqual(half.chordsPerBar, (a.chordsPerBar + b.chordsPerBar) / 2, accuracy: 0.0001)
        XCTAssertEqual(half.name, "Pop / Royal Road → Cinematic Trailer 50%")
        XCTAssertEqual(half.degreeWeights.reduce(0, +), 1.0, accuracy: 0.0001)
    }

    func testBlendAmountIsClamped() {
        let start = HarmonicStyleLibrary.deepHouse
        let end = HarmonicStyleLibrary.ambientModal
        XCTAssertEqual(HarmonicStyleDNA.blend(start, end, amount: -5).name, start.name)
        XCTAssertEqual(HarmonicStyleDNA.blend(start, end, amount: 5).name, end.name)
    }

    func testMorphingKeepsOriginAsTheSource() {
        let morphed = engine.morphing(HarmonicStyleLibrary.synthwave, toward: HarmonicStyleLibrary.jazzStandard, amount: 0.25)
        XCTAssertTrue(morphed.name.hasPrefix(HarmonicStyleLibrary.synthwave.name))
        XCTAssertTrue(morphed.name.contains("Jazz Standard"))
    }

    // MARK: - Generation

    func testGenerationIsDeterministicForASeed() {
        let first = engine.generate(style: HarmonicStyleLibrary.neoSoul, key: .d, bars: 4, seed: 1234)
        let second = engine.generate(style: HarmonicStyleLibrary.neoSoul, key: .d, bars: 4, seed: 1234)

        XCTAssertEqual(first.blocks.count, second.blocks.count)
        for (a, b) in zip(first.blocks, second.blocks) {
            XCTAssertEqual(a.chord, b.chord)
            XCTAssertEqual(a.romanNumeral, b.romanNumeral)
            XCTAssertEqual(a.durationBeats, b.durationBeats, accuracy: 0.0001)
            XCTAssertEqual(a.humanizedVelocity, b.humanizedVelocity)
        }
    }

    func testGenerationVariesWithSeed() {
        var distinct = Set<String>()
        for seed in UInt64(0)..<8 {
            let progression = engine.generate(style: HarmonicStyleLibrary.synthwave, key: .c, bars: 4, seed: seed)
            distinct.insert(progression.blocks.map(\.romanNumeral).joined(separator: "-"))
        }
        XCTAssertGreaterThan(distinct.count, 1)
    }

    func testHarmonicRhythmFillsTheRequestedBars() {
        for style in HarmonicStyleLibrary.all {
            for bars in [2, 4, 8] {
                let progression = engine.generate(style: style, key: .g, bars: bars, seed: 9)
                let totalBeats = progression.blocks.reduce(0.0) { $0 + $1.durationBeats }
                XCTAssertEqual(totalBeats, Double(bars) * 4.0, accuracy: 0.0001, "\(style.name) at \(bars) bars")
                XCTAssertGreaterThanOrEqual(progression.blocks.count, 2)
            }
        }
    }

    func testEveryBlockCarriesARomanNumeral() {
        for style in HarmonicStyleLibrary.all {
            let progression = engine.generate(style: style, key: .e, bars: 4, seed: 77)
            XCTAssertFalse(progression.blocks.isEmpty, style.name)
            for block in progression.blocks {
                XCTAssertFalse(block.romanNumeral.isEmpty, "\(style.name) produced an unlabelled block")
            }
        }
    }

    func testVelocitiesStayInsideMIDIRange() {
        for style in HarmonicStyleLibrary.all {
            let progression = engine.generate(style: style, key: .a, bars: 4, seed: 3)
            for block in progression.blocks {
                XCTAssertGreaterThan(block.humanizedVelocity, 0)
                XCTAssertLessThanOrEqual(block.humanizedVelocity, 127)
            }
        }
    }

    func testMinorLeanStylesPreferMinorScales() {
        let progression = engine.generate(style: HarmonicStyleLibrary.cinematicTrailer, key: .a, bars: 4, seed: 5)
        XCTAssertTrue(progression.scale.type.isMinor)
        XCTAssertEqual(progression.scale.root, .a)
    }

    func testMajorLeanStylesPreferMajorScales() {
        let progression = engine.generate(style: HarmonicStyleLibrary.popRoyalRoad, key: .c, bars: 4, seed: 5)
        XCTAssertFalse(progression.scale.type.isMinor)
    }

    func testExplicitScaleOverridesStyleLean() {
        let progression = engine.generate(
            style: HarmonicStyleLibrary.ambientModal,
            key: .c,
            scale: Scale(root: .c, type: .dorian),
            bars: 4,
            seed: 11
        )
        XCTAssertEqual(progression.scale.type, .dorian)
    }

    func testBareStyleKeepsChordsDiatonicAndPlain() {
        let plain = HarmonicStyleDNA(
            name: "Plain Diatonic",
            degreeWeights: [1, 0.6, 0.4, 0.8, 0.9, 0.7, 0.3],
            minorLean: 0,
            extensionRichness: 0,
            suspendedColour: 0,
            borrowing: 0,
            secondaryDominantRate: 0,
            tritoneSubstitutionRate: 0,
            mediantShiftRate: 0,
            chordsPerBar: 1,
            cadenceStrength: 1
        )

        let scale = Scale(root: .c, type: .major)
        let diatonicRoots = Set(Chord.diatonicChords(root: .c, scale: scale).map(\.root))
        let progression = engine.generate(style: plain, key: .c, scale: scale, bars: 4, seed: 21)

        for block in progression.blocks {
            XCTAssertTrue(diatonicRoots.contains(block.chord.root), "\(block.chord.symbol) is not diatonic")
            XCTAssertEqual(block.chord.quality.intervals.count, 3, "plain style should not extend \(block.chord.symbol)")
        }
    }

    func testRichStyleAddsExtensions() {
        let progression = engine.generate(style: HarmonicStyleLibrary.neoSoul, key: .d, bars: 4, seed: 99)
        let extendedCount = progression.blocks.filter { $0.chord.quality.intervals.count >= 4 }.count
        XCTAssertGreaterThan(extendedCount, 0)
    }

    func testProgressionsStartWhereAsked() {
        let progression = engine.generate(style: HarmonicStyleLibrary.deepHouse, key: .f, bars: 4, seed: 2, startDegree: 3)
        XCTAssertEqual(progression.blocks.first?.chord.root, PitchClass.f.transposed(by: 5))
    }

    func testGeneratedProgressionIsPlayableByTheSequencerModel() {
        // The generator feeds `Sequencer.insertProgressionClip`, so it must produce
        // voiced, non-empty chord blocks with positive durations.
        let progression = engine.generate(from: HarmonicStyleLibrary.synthwave,
            toward: HarmonicStyleLibrary.cinematicTrailer, amount: 0.4, key: .b, bars: 8, seed: 8)
        XCTAssertGreaterThanOrEqual(progression.blocks.count, 2)
        XCTAssertEqual(
            progression.blocks.reduce(0.0) { $0 + $1.durationBeats },
            32.0,
            accuracy: 0.0001
        )
        for block in progression.blocks {
            XCTAssertGreaterThan(block.durationBeats, 0)
            XCTAssertFalse(block.chord.voicedNotes().isEmpty)
        }
    }

    func testStyleLibraryIsDiscoverable() {
        XCTAssertGreaterThanOrEqual(HarmonicStyleLibrary.all.count, 10)
        XCTAssertNotNil(HarmonicStyleLibrary.style(named: "neo-soul"))
        XCTAssertNotNil(HarmonicStyleLibrary.style(named: "  SYNTHWAVE "))
        XCTAssertNil(HarmonicStyleLibrary.style(named: "Polka"))
    }

    func testStyleNamesAreUnique() {
        let names = HarmonicStyleLibrary.all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }
}
