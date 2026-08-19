import XCTest
@testable import XPadCore

final class HostMIDIContextTests: XCTestCase {
    func testCatalogCoversMajorDAWs() {
        let kinds = Set(HostMIDIContext.catalog.map(\.kind))
        let expected: [DAWHostKind] = [
            .internalSynth, .genericMPE, .genericMIDI,
            .logicPro, .abletonLive, .bitwigStudio, .cubase, .studioOne,
            .reaper, .digitalPerformer, .waveform, .mainStage, .garageBand,
            .flStudio, .proTools, .reason, .cakewalk, .luna, .ardour, .gigPerformer
        ]
        for kind in expected {
            XCTAssertTrue(kinds.contains(kind), "Missing host profile for \(kind.rawValue)")
        }
        XCTAssertFalse(kinds.contains(.autoDetect))
    }

    func testLogicLiveBitwigUseLowerZoneWithFifteenMembers() {
        for context in [HostMIDIContext.logicPro, .abletonLive, .bitwigStudio, .cubase, .studioOne] {
            XCTAssertTrue(context.supportsMPE, context.name)
            XCTAssertTrue(context.mpeZone.isLowerZone, context.name)
            XCTAssertEqual(context.mpeZone.memberCount, 15, context.name)
            XCTAssertEqual(context.mpeZone.masterChannel, 0, context.name)
            XCTAssertEqual(context.mpeZone.memberChannels.last, 15, context.name)
            XCTAssertEqual(context.bendRangeSemitones, 48, context.name)
            XCTAssertTrue(context.requiresOmniTrackForMPE, context.name)
        }
    }

    func testConventionalHostsStayOnChannelOne() {
        for context in [HostMIDIContext.flStudio, .proTools, .reason, .garageBand] {
            XCTAssertFalse(context.supportsMPE, context.name)
            XCTAssertEqual(context.dedicatedPortChannels.melody, 0, context.name)
            XCTAssertEqual(context.dedicatedPortChannels.drums, 9, context.name)
            XCTAssertEqual(context.destinationProfile.bendRangeSemitones, 2, context.name)
        }
    }

    func testAutoDetectPrefersFrontmostLogicBundle() {
        let signals = HostDetectionSignals(
            frontmostBundleIdentifier: "com.apple.logic10",
            frontmostProcessName: "Logic Pro",
            bundleIdentifiers: ["com.apple.logic10", "com.ableton.live"],
            processNames: ["Logic Pro", "Live"]
        )
        let resolved = HostMIDIContextResolver.resolve(selection: .autoDetect, signals: signals)
        XCTAssertEqual(resolved.kind, .logicPro)
        XCTAssertTrue(resolved.note.contains("frontmost"))
    }

    func testFrontmostLiveBeatsBackgroundLogic() {
        let signals = HostDetectionSignals(
            frontmostBundleIdentifier: "com.ableton.live",
            frontmostProcessName: "Live",
            bundleIdentifiers: ["com.apple.logic10", "com.ableton.live"],
            processNames: ["Logic Pro", "Live"]
        )
        let resolved = HostMIDIContextResolver.resolve(selection: .autoDetect, signals: signals)
        XCTAssertEqual(resolved.kind, .abletonLive)
    }

    func testBackgroundDAWIsUsedWhenFrontmostIsNotAHost() {
        let signals = HostDetectionSignals(
            frontmostBundleIdentifier: "com.apple.Safari",
            frontmostProcessName: "Safari",
            bundleIdentifiers: ["com.apple.Safari", "com.apple.logic10"],
            processNames: ["Safari", "Logic Pro"]
        )
        let resolved = HostMIDIContextResolver.resolve(selection: .autoDetect, signals: signals)
        XCTAssertEqual(resolved.kind, .logicPro)
        XCTAssertTrue(resolved.note.contains("running"))
    }

    func testAbletonDoesNotMatchUnrelatedLiveSubstring() {
        let delivery = HostMIDIContextResolver.resolve(
            selection: .autoDetect,
            signals: HostDetectionSignals(processNames: ["Delivery"])
        )
        XCTAssertEqual(delivery.kind, .internalSynth)

        let liveCaptions = HostMIDIContextResolver.resolve(
            selection: .autoDetect,
            signals: HostDetectionSignals(processNames: ["Live Captions"])
        )
        XCTAssertEqual(liveCaptions.kind, .internalSynth)

        let live = HostMIDIContextResolver.resolve(
            selection: .autoDetect,
            signals: HostDetectionSignals(processNames: ["Live"])
        )
        XCTAssertEqual(live.kind, .abletonLive)
    }

    func testCubaseVersionedBundlePrefixMatches() {
        let resolved = HostMIDIContextResolver.resolve(
            selection: .autoDetect,
            signals: HostDetectionSignals(bundleIdentifiers: ["com.steinberg.cubase14pro"])
        )
        XCTAssertEqual(resolved.kind, .cubase)
        XCTAssertEqual(resolved.context.mpeZone.memberCount, 15)
    }

    func testManualSelectionBeatsRunningDAW() {
        let signals = HostDetectionSignals(bundleIdentifiers: ["com.apple.logic10"])
        let resolved = HostMIDIContextResolver.resolve(selection: .flStudio, signals: signals)
        XCTAssertEqual(resolved.kind, .flStudio)
        XCTAssertFalse(resolved.context.supportsMPE)
    }

    func testFilteredTrackChannelDisablesMPEAndCollapsesPitchedRoles() {
        let layout = HostMIDIContextResolver.resolveLayout(
            context: .abletonLive,
            trackMode: .filtered(2)
        )
        XCTAssertFalse(layout.usesMPE)
        XCTAssertEqual(layout.channel(for: .melody), 2)
        XCTAssertEqual(layout.channel(for: .chords), 2)
        XCTAssertEqual(layout.channel(for: .bass), 2)
        XCTAssertEqual(layout.channel(for: .solo), 2)
        XCTAssertEqual(layout.channel(for: .drums), 9, "GM drums stay on Ch 10 unless the track itself is Ch 10")
        XCTAssertNotNil(layout.diagnostic)
        XCTAssertTrue(layout.diagnostic?.contains("All") == true)
    }

    func testOmniLiveKeepsDedicatedPortChannelOneAndMPE() {
        let layout = HostMIDIContextResolver.resolveLayout(
            context: .abletonLive,
            trackMode: .omni
        )
        XCTAssertTrue(layout.usesMPE)
        XCTAssertEqual(layout.channel(for: .melody), 0)
        XCTAssertEqual(layout.channel(for: .drums), 9)
        XCTAssertNil(layout.diagnostic)
    }

    func testSharedCableJamChannelsStayDistinctOnOmni() {
        let layout = HostMIDIContextResolver.resolveLayout(
            context: .genericMPE,
            trackMode: .omni,
            useSharedCable: true
        )
        XCTAssertEqual(layout.channel(for: .chords), 0)
        XCTAssertEqual(layout.channel(for: .bass), 1)
        XCTAssertEqual(layout.channel(for: .solo), 2)
        XCTAssertEqual(layout.channel(for: .drums), 9)
    }

    func testUpperZoneMembersDescendFromChannelFifteen() {
        let zone = MPEZoneLayout.upperFifteen
        XCTAssertEqual(zone.masterChannel, 15)
        XCTAssertEqual(zone.memberChannels.first, 14)
        XCTAssertEqual(zone.memberChannels.last, 0)
        XCTAssertEqual(zone.memberChannels.count, 15)
    }

    func testNoMatchFallsBackToInternalSynth() {
        let resolved = HostMIDIContextResolver.resolve(
            selection: .autoDetect,
            signals: HostDetectionSignals(bundleIdentifiers: ["com.apple.Safari"])
        )
        XCTAssertEqual(resolved.kind, .internalSynth)
        XCTAssertEqual(resolved.context.mpeZone.memberCount, 14)
    }

    func testLunaStaysConventionalWhileArdourUsesMPE() {
        XCTAssertFalse(HostMIDIContext.luna.supportsMPE)
        XCTAssertTrue(HostMIDIContext.ardour.supportsMPE)
        XCTAssertTrue(HostMIDIContext.gigPerformer.supportsMPE)
        XCTAssertEqual(HostMIDIContext.ardour.mpeZone.memberCount, 15)
    }
}
