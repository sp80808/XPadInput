import XCTest
@testable import XPadAudio

final class SoundQualitySettingsTests: XCTestCase {
    func testBalancedVelocityCurveIsMonotonicAndAudibleAtLowVelocity() {
        let curve = SynthVelocityCurve.balanced
        let zero = curve.normalizedAmplitude(for: 0)
        let soft = curve.normalizedAmplitude(for: 24)
        let medium = curve.normalizedAmplitude(for: 72)
        let hard = curve.normalizedAmplitude(for: 127)

        XCTAssertEqual(zero, 0)
        XCTAssertGreaterThan(soft, 0)
        XCTAssertLessThan(soft, medium)
        XCTAssertLessThan(medium, hard)
        XCTAssertEqual(hard, 1, accuracy: 0.0001)
        XCTAssertGreaterThan(soft, SynthVelocityCurve.expressive.normalizedAmplitude(for: 24))
    }

    func testEffectSettingsClampToSafeMusicalRanges() {
        let settings = SynthEffectsSettings(
            equalizer: .init(lowGainDB: -50, midGainDB: 50, highGainDB: 18),
            compressor: .init(
                thresholdDB: -90,
                headroomDB: 40,
                attackMilliseconds: 0,
                releaseMilliseconds: 900,
                makeupGainDB: 24
            ),
            reverb: .init(mixPercent: 80)
        ).normalized

        XCTAssertEqual(settings.equalizer.lowGainDB, -12)
        XCTAssertEqual(settings.equalizer.midGainDB, 12)
        XCTAssertEqual(settings.equalizer.highGainDB, 12)
        XCTAssertEqual(settings.compressor.thresholdDB, -40)
        XCTAssertEqual(settings.compressor.headroomDB, 20)
        XCTAssertEqual(settings.compressor.attackMilliseconds, 0.1)
        XCTAssertEqual(settings.compressor.releaseMilliseconds, 500)
        XCTAssertEqual(settings.compressor.makeupGainDB, 12)
        XCTAssertEqual(settings.reverb.mixPercent, 35)
    }

    func testDuoDrumsUseGeneralMIDINotes() {
        XCTAssertEqual(BuiltInDrumSound.kick.midiNote, 36)
        XCTAssertEqual(BuiltInDrumSound.snare.midiNote, 38)
        XCTAssertEqual(BuiltInDrumSound.closedHiHat.midiNote, 42)
        XCTAssertEqual(BuiltInDrumSound.openHiHat.midiNote, 46)
    }
}
