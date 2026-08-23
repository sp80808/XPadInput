import XCTest
@testable import XPadController

final class ControllerVendorDatabaseTests: XCTestCase {

    private func classify(_ vendorName: String?, _ productCategory: String) -> ControllerKind {
        ControllerVendorDatabase.classify(vendorName: vendorName, productCategory: productCategory)
    }

    private func identify(_ vendorName: String?, _ productCategory: String) -> ControllerKind {
        ControllerKind.identify(vendorName: vendorName, productCategory: productCategory)
    }

    // MARK: - Rhythm Table Hits

    func testGuitarHeroRules() {
        XCTAssertEqual(classify("Activision", "Guitar Hero Live Guitar"), .guitarHero)
        XCTAssertEqual(classify("Mad Catz", "Rock Band 4 Wireless Fender"), .guitarHero)
        XCTAssertEqual(classify(nil, "raphnet NES adapter guitar"), .guitarHero)
        XCTAssertEqual(classify("PDP", "RIFF Master Guitar"), .guitarHero)
        XCTAssertEqual(classify(nil, "RIFFMASTER wireless guitar"), .guitarHero)
        XCTAssertEqual(classify("Generic", "Guitarpad USB"), .guitarHero)
    }

    func testSoundVoltexRules() {
        XCTAssertEqual(classify("Konami", "Sound Voltex Controller"), .soundVoltex)
        XCTAssertEqual(classify(nil, "Pocket Voltex mini"), .soundVoltex)
        XCTAssertEqual(classify("KOC", "SDVX keypad"), .soundVoltex)
    }

    func testBeatmaniaIIDXRules() {
        XCTAssertEqual(classify("Konami", "Beatmania IIDX controller"), .beatmaniaIIDX)
        XCTAssertEqual(classify("DJ DAO", "IIDX style pad"), .beatmaniaIIDX)
        XCTAssertEqual(classify(nil, "djdao premium"), .beatmaniaIIDX)
    }

    func testPopnMusicRules() {
        XCTAssertEqual(classify("Konami", "pop'n music controller"), .popnMusic)
        XCTAssertEqual(classify(nil, "POP'N MUSIC 9-button"), .popnMusic)
        XCTAssertEqual(classify("Clone", "PopN Music pad"), .popnMusic)
    }

    func testTaikoDrumRules() {
        XCTAssertEqual(classify("Bandai Namco", "Taiko no Tatsujin drum"), .taikoDrum)
        XCTAssertEqual(classify("HORI", "TAC drum controller"), .taikoDrum)
        XCTAssertEqual(classify(nil, "tatacon drum stick"), .taikoDrum)
        XCTAssertEqual(classify("Namco", "TATSUJIN controller"), .taikoDrum)
    }

    func testDanceMatRules() {
        XCTAssertEqual(classify("Konami", "Dance Mat USB"), .danceMat)
        XCTAssertEqual(classify(nil, "DDR stage pad"), .danceMat)
        XCTAssertEqual(classify("Generic", "StagePad deluxe"), .danceMat)
    }

    // MARK: - Niche Table Hits

    func testFlightStickRules() {
        XCTAssertEqual(classify("Saitek", "X52 Flight Control System"), .flightStick)
        XCTAssertEqual(classify("Thrustmaster", "T.Flight Hotas X"), .flightStick)
        XCTAssertEqual(classify("Thrustmaster", "HOTAS Warthog"), .flightStick)
        XCTAssertEqual(classify("Logitech", "Extreme 3D Pro"), .flightStick)
        XCTAssertEqual(classify("CH Products", "Flightstick Pro"), .flightStick)
        XCTAssertEqual(classify("VKB", "Gladiator NXT"), .flightStick)
        XCTAssertEqual(classify("Virpil", "VPC throttle"), .flightStick)
        XCTAssertEqual(classify(nil, "yoke and rudder"), .flightStick)
        XCTAssertEqual(classify("Saitek", "X56 Rhino"), .flightStick)
    }

    func testRacingWheelRules() {
        XCTAssertEqual(classify("Logitech", "Driving Force GT"), .racingWheel)
        XCTAssertEqual(classify("Logitech", "G29 wheel"), .racingWheel)
        XCTAssertEqual(classify("Logitech", "G920 racing"), .racingWheel)
        XCTAssertEqual(classify("Logitech", "G923"), .racingWheel)
        XCTAssertEqual(classify("Thrustmaster", "T300RS"), .racingWheel)
        XCTAssertEqual(classify("Thrustmaster", "T248 rim"), .racingWheel)
        XCTAssertEqual(classify("Thrustmaster", "TMX Pro"), .racingWheel)
        XCTAssertEqual(classify("Fanatec", "CSL DD podium"), .racingWheel)
        XCTAssertEqual(classify("Moza", "R5 bundle"), .racingWheel)
        XCTAssertEqual(classify(nil, "sim racing rig"), .racingWheel)
        XCTAssertEqual(classify("Generic", "wheel base v2"), .racingWheel)
    }

    func testFightStickRules() {
        XCTAssertEqual(classify("Qanba", "Obsidian arcade stick"), .fightStick)
        XCTAssertEqual(classify("Victrix", "Pro FS"), .fightStick)
        XCTAssertEqual(classify("Mayflash", "F300 elite"), .fightStick)
        XCTAssertEqual(classify("Mayflash", "F500 v2"), .fightStick)
        XCTAssertEqual(classify(nil, "Hit Box leverless"), .fightStick)
        XCTAssertEqual(classify("Snackbox", "Mixbox pad"), .fightStick)
        XCTAssertEqual(classify("Mad Catz", "TE2 tournament edition"), .fightStick)
        XCTAssertEqual(classify("Razer", "Atrox arcade stick"), .fightStick)
        XCTAssertEqual(classify("HORI", "RAP.V Hayabusa"), .fightStick)
        XCTAssertEqual(classify(nil, "FIGHTING STICK alpha"), .fightStick)
    }

    // MARK: - Standard Third-Party Pads

    func testEightBitDoSwitchStyleVsPlain() {
        XCTAssertEqual(classify("8BitDo", "Pro 2 Nintendo Switch Edition"), .switchPro)
        XCTAssertEqual(classify("8BitDo", "SN30 Pro+ Bluetooth gamepad"), .generic)
        XCTAssertEqual(identify("8BitDo", "M30 Sega Genesis pad"), .generic)
    }

    func testThirdPartyStandardPadsAreGeneric() {
        XCTAssertEqual(classify("Backbone", "Backbone One iPhone"), .generic)
        XCTAssertEqual(classify("Razer", "Kishi V2"), .generic)
        XCTAssertEqual(classify("GameSir", "T4 Kaleid"), .generic)
        XCTAssertEqual(classify("Flydigi", "Apex 4"), .generic)
        XCTAssertEqual(classify("SteelSeries", "Nimbus+"), .generic)
        XCTAssertEqual(classify("SteelSeries", "Stratus Duo"), .generic)
        XCTAssertEqual(classify("PowerA", "Spectra pad"), .generic)
        XCTAssertEqual(classify("Nacon", "Revolution Pro"), .generic)
        XCTAssertEqual(classify("Razer", "Wolverine V2"), .generic)
        XCTAssertEqual(classify("Razer", "Raiju Ultimate"), .generic)
        XCTAssertEqual(classify("Onside", "gamepad"), .generic)
    }

    // MARK: - Specificity Ordering

    func testHoriFightStickBeatsGenericHoriPad() {
        XCTAssertEqual(classify("HORI", "Fighting Stick Mini"), .fightStick)
        XCTAssertEqual(identify("HORI", "Fighting Stick Alpha"), .fightStick)
    }

    func testLogitechFlightStickBeatsLogitechBrand() {
        XCTAssertEqual(classify("Logitech", "Extreme 3D Pro joystick"), .flightStick)
        XCTAssertEqual(identify("Logitech", "Extreme 3D Pro"), .flightStick)
    }

    func testLogitechWheelStillWinsForWheelStrings() {
        XCTAssertEqual(classify("Logitech", "Driving Force wheel base"), .racingWheel)
    }

    func testXboxEliteStaysXboxThroughIdentify() {
        XCTAssertEqual(identify("Microsoft", "Xbox Elite Series 2 Controller"), .xbox)
        XCTAssertEqual(identify("Microsoft", "Xbox Wireless Controller"), .xbox)
    }

    func testIdentifyDelegatesToVendorDatabaseAfterFirstPartyChecks() {
        XCTAssertEqual(identify("Qanba", "Obsidian"), .fightStick)
        XCTAssertEqual(identify("Bandai Namco", "Taiko no Tatsujin drum"), .taikoDrum)
        XCTAssertEqual(identify(nil, "Sound Voltex SDVX pocket controller"), .soundVoltex)
        XCTAssertEqual(identify("Fanatec", "ClubSport wheel base"), .racingWheel)
        XCTAssertEqual(identify("Thrustmaster", "Hotas Warthog"), .flightStick)
        XCTAssertEqual(identify(nil, "Beatmania IIDX djdao"), .beatmaniaIIDX)
        XCTAssertEqual(identify("Konami", "pop'n music controller"), .popnMusic)
        XCTAssertEqual(identify(nil, "Dance Mat DDR"), .danceMat)
        XCTAssertEqual(identify("Activision", "Guitar Hero Live"), .guitarHero)
    }

    // MARK: - Unknown Strings

    func testUnknownStringsFallBackToGeneric() {
        XCTAssertEqual(classify("Acme", "Super Pad 9000"), .generic)
        XCTAssertEqual(classify(nil, ""), .generic)
        XCTAssertEqual(classify("", ""), .generic)
        XCTAssertEqual(identify("Unknown Vendor", "Mystery Device"), .generic)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(classify("HORI", "TAIKO DRUM"), .taikoDrum)
        XCTAssertEqual(classify("konami", "POP'N MUSIC"), .popnMusic)
        XCTAssertEqual(classify("QANBA", "ARCADE STICK"), .fightStick)
    }

    // MARK: - Suggested Scheme IDs

    func testSuggestedSchemeIDCoversAllCases() {
        let expectedByKind: [ControllerKind: String] = [
            .dualSense: "xpi_performance",
            .dualShock4: "xpi_performance",
            .xbox: "xpi_performance",
            .switchPro: "xpi_performance",
            .steamDeck: "xpi_performance",
            .generic: "xpi_performance",
            .simulated: "xpi_performance",
            .guitarHero: "xpi_rhythm_pad",
            .soundVoltex: "xpi_rhythm_pad",
            .beatmaniaIIDX: "xpi_rhythm_pad",
            .popnMusic: "xpi_rhythm_pad",
            .taikoDrum: "xpi_rhythm_pad",
            .danceMat: "xpi_rhythm_pad",
            .flightStick: "xpi_flight_deck",
            .racingWheel: "xpi_racing_wheel",
            .fightStick: "xpi_arcade_stick",
        ]
        for kind in ControllerKind.allCases {
            guard let expected = expectedByKind[kind] else {
                XCTFail("No expected scheme id defined for \(kind)")
                continue
            }
            XCTAssertEqual(kind.suggestedSchemeID, expected,
                           "\(kind) should map to \(expected)")
        }
    }

    func testSuggestedSchemeIDDistinctValues() {
        let ids = Set(ControllerKind.allCases.map { $0.suggestedSchemeID })
        XCTAssertEqual(ids, Set(["xpi_performance", "xpi_rhythm_pad",
                                 "xpi_arcade_stick", "xpi_racing_wheel", "xpi_flight_deck"]))
    }
}
