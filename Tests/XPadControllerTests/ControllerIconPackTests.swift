import XCTest
@testable import XPadCore
@testable import XPadTheory
@testable import XPadController

final class ControllerIconPackTests: XCTestCase {

    // MARK: - Controller Icon Pack Verification
    func testIconPacksCompleteness() {
        let packs: [ControllerIconPack] = [
            .playStation,
            .xbox,
            .nintendoSwitch,
            .guitarHero,
            .beatmaniaIIDX,
            .soundVoltex,
            .taikoDrum,
            .danceMat,
            .flightStick,
            .racingWheel,
            .fightStick,
            .popnMusic
        ]

        for pack in packs {
            XCTAssertFalse(pack.name.isEmpty)
            XCTAssertTrue(pack.brandAccentHex.starts(with: "#"))
            XCTAssertFalse(pack.glyphs.isEmpty)
        }
    }

    func testPlayStationGlyphs() {
        let ps = ControllerIconPack.playStation
        let cross = ps.glyph(for: .psCross)
        XCTAssertEqual(cross.shortLabel, "✕")
        XCTAssertEqual(cross.fullTitle, "Cross Button")
        XCTAssertEqual(cross.brandColorHex, "#2E6DB4")

        let circle = ps.glyph(for: .psCircle)
        XCTAssertEqual(circle.shortLabel, "○")
    }

    func testGuitarHeroEngine() {
        let engine = NicheControllerMappingEngine()
        let scale = Scale.cMajor

        // Whammy Pitch Bend
        var state = GamepadState()
        state.whammy = 0.5
        let actions = engine.processGuitarHero(state: state, scale: scale)
        XCTAssertTrue(actions.contains(where: {
            if case .pitchBend(let cents) = $0 { return cents < -50.0 }
            return false
        }))

        // Fret + Strum Down
        state.fret1 = true
        state.strumDown = true
        let strumActions = engine.processGuitarHero(state: state, scale: scale)
        XCTAssertTrue(strumActions.contains(where: {
            if case .chordStrum(let notes, _, let dir) = $0 {
                return dir == .down && notes.first?.pitchClass == .c
            }
            return false
        }))
    }

    func testSoundVoltexEngine() {
        let engine = NicheControllerMappingEngine()
        let scale = Scale.cMajor

        var state = GamepadState()
        state.encoderL = 0.8 // high filter cutoff
        state.buttonX = true // BT-A chord
        let actions = engine.processSoundVoltex(state: state, scale: scale)

        XCTAssertTrue(actions.contains(where: {
            if case .timbreCutoff(let cutoff) = $0 { return cutoff > 0.8 }
            return false
        }))
        XCTAssertTrue(actions.contains(where: {
            if case .chordStrum = $0 { return true }
            return false
        }))
    }

    func testBeatmaniaEngine() {
        let engine = NicheControllerMappingEngine()
        let scale = Scale.cMajor

        var state = GamepadState()
        state.turntableVelocity = 0.5
        state.buttonA = true // Key 1 (White)
        let actions = engine.processBeatmania(state: state, scale: scale)

        XCTAssertTrue(actions.contains(where: {
            if case .pitchBend = $0 { return true }
            return false
        }))
        XCTAssertTrue(actions.contains(where: {
            if case .singleNoteOn = $0 { return true }
            return false
        }))
    }

    func testControllerKindsCategories() {
        XCTAssertEqual(ControllerKind.dualSense.category, .standard)
        XCTAssertEqual(ControllerKind.guitarHero.category, .rhythm)
        XCTAssertEqual(ControllerKind.soundVoltex.category, .rhythm)
        XCTAssertEqual(ControllerKind.flightStick.category, .niche)
        XCTAssertEqual(ControllerKind.racingWheel.category, .niche)
    }
}
