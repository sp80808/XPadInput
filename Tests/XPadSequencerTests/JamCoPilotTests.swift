import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadMIDI
@testable import XPadSequencer

@MainActor
final class JamCoPilotTests: XCTestCase {

    // MARK: - Bar boundaries

    func testBarBoundaryFiresOncePerBarEntered() {
        let sequencer = Sequencer()
        var bars: [Int] = []
        sequencer.onBarBoundary = { bars.append($0) }

        sequencer.tick(to: 0)
        XCTAssertEqual(bars, [0])

        sequencer.tick(to: SequencerGrid.ticksPerBar - 1)
        XCTAssertEqual(bars, [0], "mid-bar ticks do not re-fire")

        sequencer.tick(to: SequencerGrid.ticksPerBar)
        XCTAssertEqual(bars, [0, 1])

        sequencer.tick(to: SequencerGrid.ticksPerBar * 3 + 42)
        XCTAssertEqual(bars, [0, 1, 3])

        sequencer.rewind()
        sequencer.tick(to: 0)
        XCTAssertEqual(bars, [0, 1, 3, 0], "rewinding re-arms the first bar")
    }

    func testStopResetsTheBarCursor() {
        let sequencer = Sequencer()
        var bars: [Int] = []
        sequencer.onBarBoundary = { bars.append($0) }

        sequencer.tick(to: SequencerGrid.ticksPerBar * 2)
        XCTAssertEqual(bars, [2], "a jump reports the bar it lands in, once")
        sequencer.stop()
        sequencer.tick(to: 0)
        XCTAssertEqual(bars, [2, 0], "stop re-arms the first bar")
    }

    // MARK: - Track roles

    func testMuteByRoleAndAudibleTracks() {
        let sequencer = Sequencer()
        XCTAssertEqual(Set(sequencer.audibleTracks), Set(TrackType.allCases))
        XCTAssertTrue(sequencer.populatedTracks.isEmpty)

        sequencer.setMuted(true, forType: .melody)
        XCTAssertTrue(sequencer.isMuted(.melody))
        XCTAssertFalse(sequencer.audibleTracks.contains(.melody))
        XCTAssertFalse(sequencer.isMuted(.bass))

        sequencer.setMuted(false, forType: .melody)
        XCTAssertTrue(sequencer.audibleTracks.contains(.melody))
    }

    func testSoloOverridesMuteForAudibility() {
        let sequencer = Sequencer()
        sequencer.setMuted(true, forType: .chords)
        sequencer.toggleSolo(trackIndex: 0)
        XCTAssertEqual(sequencer.audibleTracks, [.chords], "a soloed chords track sounds even when muted")
    }

    func testPopulatedTracksFollowsClipContent() {
        let sequencer = Sequencer()
        sequencer.insertProgressionClip(.factoryPresets(for: .naturalMinor)[0], targetTrack: .chords)
        XCTAssertEqual(sequencer.populatedTracks, [.chords])
    }

    // MARK: - Co-pilot rules

    private let pilot = JamCoPilot()
    private let allLayers = TrackType.allCases

    func testMidSectionIsAHold() {
        let directive = pilot.directive(
            bar: 3,
            energy: 0.9,
            activeLayers: [.chords],
            availableLayers: allLayers
        )
        XCTAssertEqual(directive.kind, .hold)
        XCTAssertFalse(directive.isActionable)
    }

    func testLastBarOfASectionRequestsAFill() {
        let directive = pilot.directive(
            bar: pilot.sectionLengthBars - 1,
            energy: 0.8,
            activeLayers: allLayers,
            availableLayers: allLayers
        )
        guard case .drumFill(let intensity) = directive.kind else {
            return XCTFail("expected a fill, got \(directive.kind)")
        }
        XCTAssertEqual(intensity, 0.8, accuracy: 0.0001)
    }

    func testQuietPlayingThinsOutAThickArrangement() {
        let directive = pilot.directive(
            bar: pilot.sectionLengthBars,
            energy: 0.1,
            activeLayers: [.drums, .bass, .chords, .melody],
            availableLayers: allLayers
        )
        guard case .dropOut(let track) = directive.kind else {
            return XCTFail("expected a drop out, got \(directive.kind)")
        }
        XCTAssertTrue([.melody, .chords, .gesture].contains(track), "drop a role that competes with the player")
    }

    func testLoudPlayingBuildsTheArrangement() {
        let directive = pilot.directive(
            bar: pilot.sectionLengthBars,
            energy: 0.9,
            activeLayers: [.drums],
            availableLayers: allLayers
        )
        guard case .addLayer(let track) = directive.kind else {
            return XCTFail("expected a layer to be added, got \(directive.kind)")
        }
        XCTAssertEqual(track, .bass, "layers arrive in band order after the drums")
    }

    func testNeverAddsALayerThatHasNothingToPlay() {
        let directive = pilot.directive(
            bar: pilot.sectionLengthBars,
            energy: 0.95,
            activeLayers: [.drums],
            availableLayers: [.drums, .chords]
        )
        guard case .addLayer(let track) = directive.kind else {
            return XCTFail("expected the chords layer, got \(directive.kind)")
        }
        XCTAssertEqual(track, .chords)
    }

    func testStayingOnOneProgressionIsBrokenUp() {
        let directive = pilot.directive(
            bar: pilot.sectionLengthBars * 2,
            energy: 0.5,
            activeLayers: allLayers,
            availableLayers: allLayers,
            sameProgressionBars: pilot.sectionLengthBars * 2,
            styleName: "Neo-Soul"
        )
        XCTAssertEqual(directive.kind, .regenerate(styleName: "Neo-Soul"))
    }

    func testEnergyIsClampedAndDecisionsStayReproducible() {
        for energy in [-3.0, 0.0, 0.5, 1.0, 9.0] {
            let first = pilot.directive(
                bar: pilot.sectionLengthBars * 2,
                energy: energy,
                activeLayers: [.drums, .bass, .chords],
                availableLayers: allLayers,
                seed: 99
            )
            let second = pilot.directive(
                bar: pilot.sectionLengthBars * 2,
                energy: energy,
                activeLayers: [.drums, .bass, .chords],
                availableLayers: allLayers,
                seed: 99
            )
            XCTAssertEqual(first, second)
        }
    }

    func testSectionHelpers() {
        let pilot = JamCoPilot(sectionLengthBars: 4)
        XCTAssertEqual(pilot.nextSectionBoundary(after: 0), 4)
        XCTAssertEqual(pilot.nextSectionBoundary(after: 5), 8)
        XCTAssertEqual(pilot.sectionProgress(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(pilot.sectionProgress(at: 2), 0.5, accuracy: 0.0001)
        XCTAssertEqual(pilot.sectionProgress(at: 6), 0.5, accuracy: 0.0001)
    }

    // MARK: - Drum fills

    func testFillStaysInsideTheBarAndIsSorted() {
        for intensity in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let hits = DrumFillGenerator.fill(intensity: intensity, beats: 4, seed: 5)
            XCTAssertFalse(hits.isEmpty)
            XCTAssertEqual(hits, hits.sorted { $0.tickOffset < $1.tickOffset })
            for hit in hits {
                XCTAssertLessThan(hit.tickOffset, SequencerGrid.ticksPerBar)
                XCTAssertGreaterThan(hit.velocity, 0)
                XCTAssertLessThanOrEqual(hit.velocity, 127)
                XCTAssertTrue([DrumFillGenerator.kick, DrumFillGenerator.snare,
                               DrumFillGenerator.closedHat, DrumFillGenerator.openHat].contains(hit.note))
            }
        }
    }

    func testLouderIntensityWritesABiggerFill() {
        let quiet = DrumFillGenerator.fill(intensity: 0.1, beats: 4, seed: 1)
        let loud = DrumFillGenerator.fill(intensity: 1.0, beats: 4, seed: 1)
        XCTAssertGreaterThan(loud.count, quiet.count)

        let long = DrumFillGenerator.fill(intensity: 0.5, beats: 8, seed: 1)
        let short = DrumFillGenerator.fill(intensity: 0.5, beats: 2, seed: 1)
        XCTAssertGreaterThanOrEqual(long.count, short.count)
    }

    func testFillLeavesTheDownbeatEmpty() {
        let hits = DrumFillGenerator.fill(intensity: 1.0, beats: 4, seed: 3)
        let lastHalfBeat = SequencerGrid.ticks(forBeats: 4) - SequencerGrid.ticks(forBeats: 0.25)
        XCTAssertTrue(hits.allSatisfy { $0.tickOffset <= lastHalfBeat })
    }

    func testFillIsReproducibleButSeedDependent() {
        XCTAssertEqual(
            DrumFillGenerator.fill(intensity: 0.7, beats: 4, seed: 7),
            DrumFillGenerator.fill(intensity: 0.7, beats: 4, seed: 7)
        )
        XCTAssertNotEqual(
            DrumFillGenerator.fill(intensity: 0.7, beats: 4, seed: 7),
            DrumFillGenerator.fill(intensity: 0.7, beats: 4, seed: 8)
        )
    }

    func testFillClipWrapsTheHits() {
        let clip = DrumFillGenerator.clip(intensity: 0.8, beats: 4, seed: 2, name: "Fill", startTick: 3840)
        let hits = DrumFillGenerator.fill(intensity: 0.8, beats: 4, seed: 2)
        XCTAssertEqual(clip.name, "Fill")
        XCTAssertEqual(clip.startTick, 3840)
        XCTAssertEqual(clip.durationTicks, SequencerGrid.ticksPerBar)
        XCTAssertEqual(clip.notes.count, hits.count)
        XCTAssertEqual(clip.notes.map(\.note), hits.map(\.note))
    }

    func testEmptyFillForNonPositiveLength() {
        XCTAssertTrue(DrumFillGenerator.fill(intensity: 0.5, beats: 0).isEmpty)
        XCTAssertTrue(DrumFillGenerator.fill(intensity: 0.5, beats: -2).isEmpty)
        XCTAssertTrue(DrumFillGenerator.fill(intensity: 0.5, beats: .nan).isEmpty)
    }
}
