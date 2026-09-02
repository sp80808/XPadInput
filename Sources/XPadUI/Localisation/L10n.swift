// L10n.swift — XPadUI
// Compile-time-safe localisation access for XPadInput.
//
// Usage (static string):
//   Text(L10n.Transport.play)
//
// Usage (formatted string):
//   Text(L10n.MenuBar.controllerConnected("DualSense"))
//
// All keys mirror the keys in en.lproj/Localizable.strings.
// The Bundle.xpadUI computed property resolves the module bundle so strings
// are found regardless of how the package is embedded.

import Foundation
import SwiftUI

// MARK: - Bundle helper

extension Bundle {
    /// The bundle that contains XPadUI's resources (works for SPM module bundles).
    static var xpadUI: Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle.main
#endif
    }
}

// MARK: - Localised string helpers

/// Returns a localised String for `key` from the XPadUI module bundle.
func xLoc(_ key: String, _ args: CVarArg...) -> String {
    let fmt = NSLocalizedString(key, bundle: .xpadUI, comment: "")
    guard !args.isEmpty else { return fmt }
    return String(format: fmt, arguments: args)
}

/// Returns a SwiftUI `LocalizedStringKey`-compatible `String` (static keys only).
/// For formatted strings use `xLoc(_:_:)` and wrap in `Text(verbatim:)`.
func xKey(_ key: String) -> LocalizedStringKey {
    LocalizedStringKey(key)
}

// MARK: - L10n namespace

/// Typed key namespace — prevents typos, enables autocomplete, and lets Xcode
/// "Find > Usages" trace every call site back to its `.strings` entry.
enum L10n {

    // MARK: Common
    enum Common {
        static var done:    String { xLoc("common.done") }
        static var cancel:  String { xLoc("common.cancel") }
        static var start:   String { xLoc("common.start") }
        static var exit:    String { xLoc("common.exit") }
        static var add:     String { xLoc("common.add") }
        static var stop:    String { xLoc("common.stop") }
        static var play:    String { xLoc("common.play") }
        static var on:      String { xLoc("common.on") }
        static var off:     String { xLoc("common.off") }
        static var yes:     String { xLoc("common.yes") }
        static var no:      String { xLoc("common.no") }
        static var active:  String { xLoc("common.active") }
        static var muted:   String { xLoc("common.muted") }
    }

    // MARK: App Branding
    enum App {
        static var brandName:     String { xLoc("app.brand.name") }
        static var brandSubtitle: String { xLoc("app.brand.subtitle") }
    }

    // MARK: Controller Kind
    enum ControllerKind {
        static var simulatedCompact: String { xLoc("controller.kind.simulated.compact") }
        static var simulated:  String { xLoc("controller.kind.simulated") }
        static var dualsense:  String { xLoc("controller.kind.dualsense") }
        static var dualshock4: String { xLoc("controller.kind.dualshock4") }
        static var xbox:       String { xLoc("controller.kind.xbox") }
        static var switchPro:  String { xLoc("controller.kind.switch") }
        static var steamDeck:  String { xLoc("controller.kind.steamdeck") }
        static var guitar:     String { xLoc("controller.kind.guitar") }
        static var fightStick: String { xLoc("controller.kind.fightstick") }
        static var wheel:      String { xLoc("controller.kind.wheel") }
        static var hotas:      String { xLoc("controller.kind.hotas") }
        static var generic:    String { xLoc("controller.kind.generic") }
    }

    // MARK: Settings Sheet
    enum Settings {
        static var sheetTitle:           String { xLoc("settings.sheet.title") }
        static var controllerBadgeHelp:  String { xLoc("header.controller.badge.help") }
        static var openSettingsHelp:     String { xLoc("header.settings.help") }

        static var tabErgonomics:  String { xLoc("settings.tab.ergonomics") }
        static var tabRemapping:   String { xLoc("settings.tab.remapping") }
        static var tabLiveTest:    String { xLoc("settings.tab.liveTest") }
        static var tabCalibration: String { xLoc("settings.tab.calibration") }

        static var controllerConnected:       String { xLoc("settings.controller.connected") }
        static var controllerSimulated:       String { xLoc("settings.controller.simulated") }
        static var controllerStandardProfile: String { xLoc("settings.controller.standardProfile") }
        static var calibrateButton:           String { xLoc("settings.calibrate.button") }

        static var schemeLabel:     String { xLoc("settings.scheme.label") }
        static var schemeBuiltIn:   String { xLoc("settings.scheme.builtIn") }
        static var schemeCustom:    String { xLoc("settings.scheme.custom") }
        static var schemeDuplicate: String { xLoc("settings.scheme.duplicate") }
        static var schemeReset:     String { xLoc("settings.scheme.reset") }

        enum Ergonomics {
            static var backgroundTitle:       String { xLoc("settings.ergonomics.background.title") }
            static var backgroundInputToggle: String { xLoc("settings.ergonomics.backgroundInput.toggle") }
            static var backgroundInputNote:   String { xLoc("settings.ergonomics.backgroundInput.note") }
            static var handOrientationTitle:  String { xLoc("settings.ergonomics.handOrientation.title") }
            static var swapRolesToggle:       String { xLoc("settings.ergonomics.swapRoles.toggle") }
            static var swapRolesNote:         String { xLoc("settings.ergonomics.swapRoles.note") }
            static var stickFeelTitle:        String { xLoc("settings.ergonomics.stickFeel.title") }
            static var stickFeelPicker:       String { xLoc("settings.ergonomics.stickFeel.picker") }
            static var stickFeelNote:         String { xLoc("settings.ergonomics.stickFeel.note") }
            static var triggerFeelTitle:      String { xLoc("settings.ergonomics.triggerFeel.title") }
            static var triggerFeelPicker:     String { xLoc("settings.ergonomics.triggerFeel.picker") }
            static var triggerFeelNote:       String { xLoc("settings.ergonomics.triggerFeel.note") }
            static var hapticsTitle:          String { xLoc("settings.ergonomics.haptics.title") }
            static var hapticsLabel:          String { xLoc("settings.ergonomics.haptics.label") }
            static var motionToggle:          String { xLoc("settings.ergonomics.motion.toggle") }
        }

        enum Remapping {
            static var coverageTitle:  String { xLoc("settings.remapping.coverage.title") }
            static var rebindButton:   String { xLoc("settings.remapping.rebind.button") }
            static var inversionOn:    String { xLoc("settings.remapping.inversion.on") }
            static var inversionLabel: String { xLoc("settings.remapping.inversion.label") }
            static var heldBehaviour:  String { xLoc("settings.remapping.heldBehaviour") }
            static var unassign:       String { xLoc("settings.remapping.unassign") }
        }

        enum LiveTest {
            static var leftStick:      String { xLoc("settings.liveTest.leftStick") }
            static var rightStick:     String { xLoc("settings.liveTest.rightStick") }
            static var leftTrigger:    String { xLoc("settings.liveTest.leftTrigger") }
            static var rightTrigger:   String { xLoc("settings.liveTest.rightTrigger") }
            static var gestureTitle:   String { xLoc("settings.liveTest.gesture.title") }
            static var techniqueLabel: String { xLoc("settings.liveTest.technique.label") }
            static var bendLabel:      String { xLoc("settings.liveTest.bend.label") }
            static var resting:        String { xLoc("settings.liveTest.resting") }
        }

        enum Calibration {
            static var leftStick:     String { xLoc("settings.calibration.leftStick") }
            static var rightStick:    String { xLoc("settings.calibration.rightStick") }
            static func restDrift(x: Float, y: Float) -> String { xLoc("settings.calibration.restDrift", x, y) }
            static func driftRadius(_ r: Float) -> String       { xLoc("settings.calibration.driftRadius", r) }
            static func maxRadius(_ r: Float) -> String         { xLoc("settings.calibration.maxRadius", r) }
            static var wizardButton:  String { xLoc("settings.calibration.wizard.button") }
            static var reset:         String { xLoc("settings.calibration.reset") }
            static var wizardTitle:   String { xLoc("settings.calibration.wizard.title") }
            static var wizardSubtitle:String { xLoc("settings.calibration.wizard.subtitle") }
            static var wizardSteps:   String { xLoc("settings.calibration.wizard.steps") }
            static var wizardFinish:  String { xLoc("settings.calibration.wizard.finish") }
        }

        enum Learn {
            static var title:       String { xLoc("settings.learn.title") }
            static var instruction: String { xLoc("settings.learn.instruction") }
            static var listening:   String { xLoc("settings.learn.listening") }
        }

        enum Warnings {
            static func critical(_ c: Int, _ n: Int) -> String { xLoc("settings.warnings.critical", c, n) }
            static func summary(_ n: Int) -> String            { xLoc("settings.warnings.summary", n) }
        }
    }

    // MARK: Transport Bar
    enum Transport {
        static var stop:            String { xLoc("transport.stop") }
        static var play:            String { xLoc("transport.play") }
        static var record:          String { xLoc("transport.record") }
        static var loop:            String { xLoc("transport.loop") }
        static var metronomeDisableHelp: String { xLoc("transport.metronome.disable.help") }
        static var metronomeEnableHelp:  String { xLoc("transport.metronome.enable.help") }
        static var metronomeLabel:  String { xLoc("transport.metronome.label") }
        static var bpmLabel:        String { xLoc("transport.bpm.label") }
        static var tapHelp:         String { xLoc("transport.tap.help") }
        static var tapButton:       String { xLoc("transport.tap.button") }
        static var midiProtocolHelp:String { xLoc("transport.midi.protocol.help") }
        static var controllerPreview: String { xLoc("transport.controller.preview") }
        static var synthUnmuteHelp: String { xLoc("transport.synth.unmute.help") }
        static var synthMuteHelp:   String { xLoc("transport.synth.mute.help") }
        static var synthMuteLabel:  String { xLoc("transport.synth.mute.label") }
        static var volumeMutedHelp: String { xLoc("transport.volume.slider.muted.help") }
        static var volumeHelp:      String { xLoc("transport.volume.slider.help") }
        static var panicHelp:       String { xLoc("transport.panic.help") }
        static var keyHelp:         String { xLoc("transport.key.help") }
        static var keyLabel:        String { xLoc("transport.key.label") }
        static var scaleHelp:       String { xLoc("transport.scale.help") }
        static var scaleLabel:      String { xLoc("transport.scale.label") }
    }

    // MARK: Instrument Selector
    enum Instrument {
        static var selectorHelp:  String { xLoc("instrument.selector.help") }
        static var selectorLabel: String { xLoc("instrument.selector.label") }
        // Play modes
        static var modeChordStrummer: String { xLoc("instrument.mode.chordStrummer") }
        static var modeDrums:         String { xLoc("instrument.mode.drums") }
        static var modeBass:          String { xLoc("instrument.mode.bass") }
        static var modeMelody:        String { xLoc("instrument.mode.melody") }
    }

    // MARK: Navigation
    enum Nav {
        static var play:     String { xLoc("nav.tab.play") }
        static var harmony:  String { xLoc("nav.tab.harmony") }
        static var sequence: String { xLoc("nav.tab.sequence") }
        static var map:      String { xLoc("nav.tab.map") }
        static var library:  String { xLoc("nav.tab.library") }
        static var practice: String { xLoc("nav.tab.practice") }
    }

    // MARK: Menu Bar
    enum MenuBar {
        static func controllerConnected(_ name: String) -> String { xLoc("menuBar.controller.connected", name) }
        static var controllerDisconnected: String { xLoc("menuBar.controller.disconnected") }
        static func keyLabel(key: String, scale: String, profile: String) -> String { xLoc("menuBar.key.label", key, scale, profile) }
        static var openWindow:           String { xLoc("menuBar.openWindow") }
        static var toggleBackgroundInput:String { xLoc("menuBar.toggle.backgroundInput") }
        static var toggleVirtualMidi:    String { xLoc("menuBar.toggle.virtualMidi") }
        static var panic:                String { xLoc("menuBar.panic") }
        static var instrumentProfileMenu:String { xLoc("menuBar.instrumentProfile.menu") }
        static var switchWorkspaceMenu:  String { xLoc("menuBar.switchWorkspace.menu") }
        static var practiceExit:         String { xLoc("menuBar.practice.exit") }
        static var practiceOpen:         String { xLoc("menuBar.practice.open") }
        static var rescanControllers:    String { xLoc("menuBar.rescanControllers") }
        static var quit:                 String { xLoc("menuBar.quit") }
    }

    // MARK: Play Workspace
    enum Play {
        static var tabChords:      String { xLoc("play.tab.chords") }
        static var tabProgression: String { xLoc("play.tab.progression") }
        static var tabSuggestions: String { xLoc("play.tab.suggestions") }

        static var dspTabPerformance: String { xLoc("play.dsp.tab.performance") }
        static var dspTabSynth:       String { xLoc("play.dsp.tab.synth") }
        static var dspTabFX:          String { xLoc("play.dsp.tab.fx") }
        static var dspTabSpatial:     String { xLoc("play.dsp.tab.spatial") }

        static var lanesHeader:        String { xLoc("play.lanes.header") }
        static var lanesStrumTitle:    String { xLoc("play.lanes.strum.title") }
        static var lanesStrumSubtitle: String { xLoc("play.lanes.strum.subtitle") }
        static var lanesFaceTitle:     String { xLoc("play.lanes.face.title") }
        static var lanesFaceSubtitle:  String { xLoc("play.lanes.face.subtitle") }

        static var outputError:   String { xLoc("play.output.error") }
        static var outputVirtual: String { xLoc("play.output.virtual") }
        static var outputInternal:String { xLoc("play.output.internal") }

        static var fxHeader:       String { xLoc("play.fx.header") }
        static var fxEQ:           String { xLoc("play.fx.eq") }
        static var fxCompressor:   String { xLoc("play.fx.compressor") }
        static var fxReverb:       String { xLoc("play.fx.reverb") }

        static var diatonicHeader: String { xLoc("play.chords.diatonic.header") }

        static var progressionHeader: String { xLoc("play.progression.header") }
        static var progressionMutate: String { xLoc("play.progression.mutate") }
        static var progressionStop:   String { xLoc("play.progression.stop") }
        static var progressionPlay:   String { xLoc("play.progression.play") }
        static var progressionAdd:    String { xLoc("play.progression.add") }

        static var suggestionsHeader: String { xLoc("play.suggestions.header") }

        static var synthHeader:   String { xLoc("play.dsp.synth.header") }
        static func cutoff(_ hz: Int) -> String    { xLoc("play.dsp.cutoff.label", hz) }
        static func resonance(_ pct: Int) -> String { xLoc("play.dsp.resonance.label", pct) }
        static func drive(_ pct: Int) -> String    { xLoc("play.dsp.drive.label", pct) }
        static func reverb(_ pct: Int) -> String   { xLoc("play.dsp.reverb.label", pct) }

        static var notesNone:        String { xLoc("play.notes.none") }
        static var notesCountLabel:  String { xLoc("play.notes.count.label") }
        static var performanceHeader:String { xLoc("play.performance.header") }
        static var midiLabel:        String { xLoc("play.midi.label") }
        static var midiProtocolMPE:  String { xLoc("play.midi.protocol.mpe") }
        static var midiProtocolMIDI: String { xLoc("play.midi.protocol.midi") }

        static var expressionBend:     String { xLoc("play.expression.bend") }
        static var expressionPressure: String { xLoc("play.expression.pressure") }
        static var expressionTimbre:   String { xLoc("play.expression.timbre") }
        static var expressionMute:     String { xLoc("play.expression.mute") }
    }

    // MARK: Tension Badge
    enum Tension {
        static var stable:      String { xLoc("tension.stable") }
        static var natural:     String { xLoc("tension.natural") }
        static var colourful:   String { xLoc("tension.colourful") }
        static var adventurous: String { xLoc("tension.adventurous") }
        static var outside:     String { xLoc("tension.outside") }
    }

    // MARK: Harmony Workspace
    enum Harmony {
        static var progressionBuilderTitle: String { xLoc("harmony.progression.builder.title") }
        static var progressionMutate:       String { xLoc("harmony.progression.mutate") }
        static var progressionStop:         String { xLoc("harmony.progression.stop") }
        static var progressionPlayAll:      String { xLoc("harmony.progression.playAll") }
        static func modulationExplorerTitle(_ key: String) -> String { xLoc("harmony.modulation.explorer.title", key) }
        static var modulationTargetKey:     String { xLoc("harmony.modulation.targetKey") }
        static var modulationAuditionPath:  String { xLoc("harmony.modulation.auditionPath") }
        static var voiceLeadingPicker:      String { xLoc("harmony.voiceLeading.picker") }
        static func suggestionsTitle(_ chord: String) -> String { xLoc("harmony.suggestions.title", chord) }
        static var suggestionsAudition:     String { xLoc("harmony.suggestions.audition") }
        static var suggestionsAdd:          String { xLoc("harmony.suggestions.add") }
        static func chordBlockBeats(_ n: Int) -> String { xLoc("harmony.chordBlock.beats", n) }
    }

    // MARK: Sequence Workspace
    enum Sequence {
        static var scenesLabel:   String { xLoc("sequence.scenes.label") }
        static var exportButton:  String { xLoc("sequence.export.button") }
        static func exportError(_ msg: String) -> String { xLoc("sequence.export.error", msg) }
        static func clipLabel(_ name: String) -> String  { xLoc("sequence.clip.label", name) }
    }

    // MARK: Practice Workspace
    enum Practice {
        static var headerTitle:    String { xLoc("practice.header.title") }
        static var headerSubtitle: String { xLoc("practice.header.subtitle") }
        static var headerDone:     String { xLoc("practice.header.done") }
        static var headerDoneHelp: String { xLoc("practice.header.done.help") }

        static var tabLessons:    String { xLoc("practice.tab.lessons") }
        static var tabPractice:   String { xLoc("practice.tab.practice") }
        static var tabProgress:   String { xLoc("practice.tab.progress") }
        static var tabChallenges: String { xLoc("practice.tab.challenges") }

        static var statsStreak: String { xLoc("practice.stats.streak") }
        static var statsTotal:  String { xLoc("practice.stats.total") }
        static var statsDone:   String { xLoc("practice.stats.done") }

        static var lessonCardStart: String { xLoc("practice.lessonCard.start") }
        static var lessonCardAgain: String { xLoc("practice.lessonCard.again") }

        static var lessonDetailTitle:      String { xLoc("practice.lessonDetail.title") }
        static var lessonDetailObjectives: String { xLoc("practice.lessonDetail.objectives") }
        static var lessonDetailSteps:      String { xLoc("practice.lessonDetail.steps") }

        static var sessionFallbackTitle:   String { xLoc("practice.session.fallbackTitle") }
        static func sessionStepProgress(current: Int, total: Int) -> String { xLoc("practice.session.stepProgress", current, total) }
        static var sessionResume:          String { xLoc("practice.session.resume") }
        static var sessionPause:           String { xLoc("practice.session.pause") }
        static var sessionGuidanceSimilar: String { xLoc("practice.session.guidance.similar") }
        static func sessionTimer(_ secs: Int) -> String { xLoc("practice.session.timer", secs) }
        static var sessionCompleteTitle:   String { xLoc("practice.session.complete.title") }
        static func sessionAccuracy(_ pct: Int) -> String       { xLoc("practice.session.complete.accuracy", pct) }
        static func sessionAvgResponse(_ s: Double) -> String   { xLoc("practice.session.complete.avgResponse", s) }
        static var sessionTryAgain:        String { xLoc("practice.session.tryAgain") }
        static func sessionRowAccuracy(_ pct: Int) -> String    { xLoc("practice.session.row.accuracy", pct) }

        static var progressTitle:        String { xLoc("practice.progress.title") }
        static var statsTotalPractice:   String { xLoc("practice.stats.totalPractice") }
        static var statsCurrentStreak:   String { xLoc("practice.stats.currentStreak") }
        static func statsDays(_ n: Int) -> String { xLoc("practice.stats.days", n) }
        static var statsLessonsCompleted:String { xLoc("practice.stats.lessonsCompleted") }
        static var statsMasteredLessons: String { xLoc("practice.stats.masteredLessons") }
        static var progressWeeklyGoal:   String { xLoc("practice.progress.weeklyGoal") }
        static func progressWeeklyGoalProgress(done: Int, total: Int) -> String { xLoc("practice.progress.weeklyGoalProgress", done, total) }
        static var progressGoalAchieved: String { xLoc("practice.progress.goalAchieved") }
        static var progressRecentSessions:String { xLoc("practice.progress.recentSessions") }

        static var challengesTitle:   String { xLoc("practice.challenges.title") }
        static func challengeTargetAccuracy(_ pct: Int) -> String { xLoc("practice.challenge.targetAccuracy", pct) }
        static var challengeStart:    String { xLoc("practice.challenge.start") }
    }

    // MARK: Map Workspace
    enum Map {
        static var controllerPicker:     String { xLoc("map.controller.picker") }
        static var controllerConnected:  String { xLoc("map.controller.connected") }
        static var controllerSimulation: String { xLoc("map.controller.simulation") }
        static var tabModulation:        String { xLoc("map.tab.modulation") }
        static var tabControlSchemes:    String { xLoc("map.tab.controlSchemes") }
        static var tabOCDS:              String { xLoc("map.tab.ocds") }
        static var viewModePicker:       String { xLoc("map.viewMode.picker") }
        static var imuTitle:             String { xLoc("map.imu.title") }
        static func imuPitch(_ v: Double) -> String { xLoc("map.imu.pitch", v) }
        static func imuRoll(_ v: Double) -> String  { xLoc("map.imu.roll", v) }
        static func imuYaw(_ v: Double) -> String   { xLoc("map.imu.yaw", v) }
        static var stickLeftLabel:       String { xLoc("map.stick.left.label") }
        static var stickRightLabel:      String { xLoc("map.stick.right.label") }
        static var triggerLeftLabel:     String { xLoc("map.trigger.left.label") }
        static var triggerRightLabel:    String { xLoc("map.trigger.right.label") }

        // Expression map sub-sections
        static var sectionPhysical:      String { xLoc("map.section.physical") }
        static var sectionGesture:       String { xLoc("map.section.gesture") }
        static var sectionInstrument:    String { xLoc("map.section.instrument") }
        static var sectionMidi:          String { xLoc("map.section.midi") }
        static var sectionPicker:        String { xLoc("map.section.picker") }
        static var techniqueMonitorTitle:String { xLoc("map.techniqueMonitor.title") }
        static var techniqueMonitorEmpty:String { xLoc("map.techniqueMonitor.empty") }
        static var physicalLeftStick:    String { xLoc("map.physical.leftStick") }
        static var physicalRightStick:   String { xLoc("map.physical.rightStick") }
        static var physicalStickNote:    String { xLoc("map.physical.stickNote") }
        static var gesturePitchAssist:   String { xLoc("map.gesture.pitchAssist") }
        static var gestureRealism:       String { xLoc("map.gesture.realism") }
        static var gestureTheoryAssist:  String { xLoc("map.gesture.theoryAssist") }
        static var gestureChromatic:     String { xLoc("map.gesture.chromatic") }
        static var gestureChordTone:     String { xLoc("map.gesture.chordTone") }
        static var instrumentFamily:     String { xLoc("map.instrument.family") }
        static var instrumentPreset:     String { xLoc("map.instrument.preset") }
        static var instrumentBendRange:  String { xLoc("map.instrument.bendRange") }
        static var instrumentVibrato:    String { xLoc("map.instrument.vibrato") }
        static var instrumentHammerOn:   String { xLoc("map.instrument.hammerOn") }
        static var midiHost:             String { xLoc("map.midi.host") }
        static var midiTrackChannel:     String { xLoc("map.midi.trackChannel") }
        static var midiChannelAny:       String { xLoc("map.midi.channel.any") }
        static func midiChannelNumbered(_ n: Int) -> String { xLoc("map.midi.channel.numbered", n) }
        static var midiActiveHost:       String { xLoc("map.midi.activeHost") }
        static var midiDetection:        String { xLoc("map.midi.detection") }
        static var midiMpeOutput:        String { xLoc("map.midi.mpeOutput") }
        static var midiMpeZone:          String { xLoc("map.midi.mpeZone") }
        static var midiBendRange:        String { xLoc("map.midi.bendRange") }
        static var midiMelodySolo:       String { xLoc("map.midi.melodyBass") }
        static var midiChordsBass:       String { xLoc("map.midi.chordsBass") }
        static var midiDrums:            String { xLoc("map.midi.drums") }
        static var midiPressure:         String { xLoc("map.midi.pressure") }
        static var midiArticulation:     String { xLoc("map.midi.articulation") }
        static var midiSlide:            String { xLoc("map.midi.slide") }
        static var midiRedetect:         String { xLoc("map.midi.redetect") }
        static var midiPassthru:         String { xLoc("map.midi.passthru") }
        static var midiPassthruRouting:  String { xLoc("map.midi.passthruRouting") }
    }

    // MARK: OCDS Workspace
    enum OCDS {
        static var title:            String { xLoc("ocds.title") }
        static var subtitle:         String { xLoc("ocds.subtitle") }
        static var schemaButton:     String { xLoc("ocds.schema.button") }
        static var exportButton:     String { xLoc("ocds.export.button") }
        static var importButton:     String { xLoc("ocds.import.button") }
        static var profilesTitle:    String { xLoc("ocds.profiles.title") }
        static var profilesPicker:   String { xLoc("ocds.profiles.picker") }
        static var metadataTitle:    String { xLoc("ocds.metadata.title") }
        static var metaIdentifier:   String { xLoc("ocds.metadata.identifier") }
        static var metaAuthor:       String { xLoc("ocds.metadata.author") }
        static var metaVersion:      String { xLoc("ocds.metadata.version") }
        static var metaCategory:     String { xLoc("ocds.metadata.category") }
        static var metaVendor:       String { xLoc("ocds.metadata.vendor") }
        static var hardwareTitle:    String { xLoc("ocds.hardware.title") }
        static func capabilitySticks(_ n: Int) -> String    { xLoc("ocds.capability.sticks", n) }
        static func capabilityTriggers(_ n: Int) -> String  { xLoc("ocds.capability.triggers", n) }
        static func capabilityButtons(_ n: Int) -> String   { xLoc("ocds.capability.buttons", n) }
        static var capabilityAdaptive:  String { xLoc("ocds.capability.adaptive") }
        static var capabilityIMU:       String { xLoc("ocds.capability.imu") }
        static var capabilityTouchpad:  String { xLoc("ocds.capability.touchpad") }
        static var bindingsTitle:       String { xLoc("ocds.bindings.title") }
        static var bindingsEmpty:       String { xLoc("ocds.bindings.empty") }
        static func bindingsCurveDeadzone(curve: String, dz: Float) -> String { xLoc("ocds.bindings.curveDeadzone", curve, dz) }
        static var triggersTitle:       String { xLoc("ocds.triggers.title") }
        static var triggersEmpty:       String { xLoc("ocds.triggers.empty") }
        static func triggersMode(_ m: String) -> String { xLoc("ocds.triggers.mode", m) }
        static func triggersStrengthRange(s: Float, lo: Float, hi: Float) -> String { xLoc("ocds.triggers.strengthRange", s, lo, hi) }
        static var skinTitle:           String { xLoc("ocds.skin.title") }
        static func skinAnchors(_ n: Int) -> String { xLoc("ocds.skin.anchors", n) }
        static var skinBase:            String { xLoc("ocds.skin.base") }
        static var skinAccent:          String { xLoc("ocds.skin.accent") }
        static var skinLED:             String { xLoc("ocds.skin.led") }
        static var schemaSheetTitle:    String { xLoc("ocds.schemaSheet.title") }
        static var exportSheetTitle:    String { xLoc("ocds.exportSheet.title") }
        static var importSheetTitle:    String { xLoc("ocds.importSheet.title") }
        static var importValidate:      String { xLoc("ocds.import.validate") }
    }

    // MARK: Virtual Audio
    enum VirtualAudio {
        static var title:              String { xLoc("virtualAudio.title") }
        static var subtitle:           String { xLoc("virtualAudio.subtitle") }
        static var levelMonitorTitle:  String { xLoc("virtualAudio.levelMonitor.title") }
        static func levelMonitorReadout(l: Double, r: Double) -> String { xLoc("virtualAudio.levelMonitor.readout", l, r) }
        static var bufferLatencyLabel: String { xLoc("virtualAudio.bufferLatency.label") }
        static var sampleRateLabel:    String { xLoc("virtualAudio.sampleRate.label") }
        static var stemCaptureTitle:   String { xLoc("virtualAudio.stemCapture.title") }
        static func stemCaptureRecording(secs: Double, frames: UInt64) -> String { xLoc("virtualAudio.stemCapture.recording", secs, frames) }
        static func stemCaptureSaved(_ path: String) -> String { xLoc("virtualAudio.stemCapture.saved", path) }
        static var stemCaptureIdle:    String { xLoc("virtualAudio.stemCapture.idle") }
        static var stemCaptureStop:    String { xLoc("virtualAudio.stemCapture.stop") }
        static var stemCaptureStart:   String { xLoc("virtualAudio.stemCapture.start") }
        static func startError(_ msg: String) -> String   { xLoc("virtualAudio.stemCapture.startError", msg) }
        static func captureError(_ msg: String) -> String { xLoc("virtualAudio.stemCapture.captureError", msg) }
    }

    // MARK: Library Workspace
    enum Library {
        static var presetsTitle:    String { xLoc("library.presets.title") }
        static var dawTitle:        String { xLoc("library.daw.title") }
        static var dawSubtitle:     String { xLoc("library.daw.subtitle") }
        static var ocdsTitle:       String { xLoc("library.ocds.title") }
        static var ocdsSubtitle:    String { xLoc("library.ocds.subtitle") }
        static var presetActive:    String { xLoc("library.preset.active") }
        static var presetSelect:    String { xLoc("library.preset.select") }
        static func presetOscLabel(a: String, b: String) -> String { xLoc("library.preset.osc.label", a, b) }
        static var dawAutoDetect:   String { xLoc("library.daw.autodetect.title") }
        static var dawLogic:        String { xLoc("library.daw.logic.title") }
        static var dawAbleton:      String { xLoc("library.daw.ableton.title") }
        static var dawBitwig:       String { xLoc("library.daw.bitwig.title") }
    }

    // MARK: AU Plugin View
    enum Plugin {
        static var title:             String { xLoc("plugin.title") }
        static var formatBadge:       String { xLoc("plugin.format.badge") }
        static func mpeBadge(_ st: Int) -> String { xLoc("plugin.mpe.badge", st) }
        static var halBadge:          String { xLoc("plugin.hal.badge") }
        static func keyLabel(_ k: String) -> String { xLoc("plugin.key.label", k) }
        static func voiceLeadingLabel(_ v: String) -> String { xLoc("plugin.voiceLeading.label", v) }
        static var filterHeader:      String { xLoc("plugin.filter.header") }
        static func filterCutoff(_ hz: Int) -> String    { xLoc("plugin.filter.cutoff", hz) }
        static func filterResonance(_ pct: Int) -> String{ xLoc("plugin.filter.resonance", pct) }
        static var fxHeader:          String { xLoc("plugin.fx.header") }
        static func fxDrive(_ pct: Int) -> String   { xLoc("plugin.fx.drive", pct) }
        static func fxReverb(_ pct: Int) -> String  { xLoc("plugin.fx.reverb", pct) }
    }

    // MARK: Performance Quick Controls
    enum QuickControls {
        static var gateTitle:         String { xLoc("quickControls.gate.title.full") }
        static var gateTitleCompact:  String { xLoc("quickControls.gate.title.compact") }
        static var gateHelp:          String { xLoc("quickControls.gate.help") }
        static var velocityTitle:     String { xLoc("quickControls.velocity.title") }
        static var velocityTitleCompact: String { xLoc("quickControls.velocity.title.compact") }
        static var velocityHelp:      String { xLoc("quickControls.velocity.help") }
        static var duoTitle:          String { xLoc("quickControls.duo.title") }
        static var duoOn:             String { xLoc("quickControls.duo.on") }
        static var duoOff:            String { xLoc("quickControls.duo.off") }
        static var duoHelp:           String { xLoc("quickControls.duo.help") }
        static var soloTitle:         String { xLoc("quickControls.solo.title") }
        static var soloOn:            String { xLoc("quickControls.solo.on") }
        static var soloStrum:         String { xLoc("quickControls.solo.strum") }
        static var soloHelp:          String { xLoc("quickControls.solo.help") }
        static var triggersTitle:     String { xLoc("quickControls.triggers.title") }
        static var triggersTitleCompact: String { xLoc("quickControls.triggers.title.compact") }
        static var triggersHelp:      String { xLoc("quickControls.triggers.help") }
        static var synthTitle:        String { xLoc("quickControls.synth.title") }
        static var synthMuted:        String { xLoc("quickControls.synth.muted") }
        static var synthOn:           String { xLoc("quickControls.synth.on") }
        static var synthMutedHelp:    String { xLoc("quickControls.synth.muted.help") }
        static var synthHelp:         String { xLoc("quickControls.synth.help") }
        static var eqTitle:           String { xLoc("quickControls.eq.title") }
        static var compressorTitle:   String { xLoc("quickControls.compressor.title") }
        static var compressorTitleFull: String { xLoc("quickControls.compressor.title.full") }
        static var reverbTitle:       String { xLoc("quickControls.reverb.title") }
        static var reverbTitleFull:   String { xLoc("quickControls.reverb.title.full") }

        static var gatePopoverTitle:    String { xLoc("quickControls.gate.popover.title") }
        static var gatePopoverSubtitle: String { xLoc("quickControls.gate.popover.subtitle") }
        static var gateReleaseMode:     String { xLoc("quickControls.gate.releaseMode") }
        static var gateLength:          String { xLoc("quickControls.gate.length") }
        static var gateDescMomentary:   String { xLoc("quickControls.gate.desc.momentary") }
        static var gateDescTimed:       String { xLoc("quickControls.gate.desc.timed") }
        static var gateDescLatch:       String { xLoc("quickControls.gate.desc.latch") }

        static var velocityPopoverTitle:    String { xLoc("quickControls.velocity.popover.title") }
        static var velocityPopoverSubtitle: String { xLoc("quickControls.velocity.popover.subtitle") }
        static var velocityCurve:           String { xLoc("quickControls.velocity.curve") }
        static var velocityDescBalanced:    String { xLoc("quickControls.velocity.desc.balanced") }
        static var velocityDescExpressive:  String { xLoc("quickControls.velocity.desc.expressive") }
        static var velocityDescEven:        String { xLoc("quickControls.velocity.desc.even") }

        static var eqPopoverTitle:    String { xLoc("quickControls.eq.popover.title") }
        static var eqPopoverSubtitle: String { xLoc("quickControls.eq.popover.subtitle") }
        static var eqToggle:          String { xLoc("quickControls.eq.toggle") }
        static var eqLow:             String { xLoc("quickControls.eq.low") }
        static var eqMid:             String { xLoc("quickControls.eq.mid") }
        static var eqHigh:            String { xLoc("quickControls.eq.high") }

        static var compressorPopoverTitle:    String { xLoc("quickControls.compressor.popover.title") }
        static var compressorPopoverSubtitle: String { xLoc("quickControls.compressor.popover.subtitle") }
        static var compressorToggle:          String { xLoc("quickControls.compressor.toggle") }
        static var compressorThreshold:       String { xLoc("quickControls.compressor.threshold") }
        static var compressorMakeup:          String { xLoc("quickControls.compressor.makeup") }
        static var compressorRelease:         String { xLoc("quickControls.compressor.release") }

        static var reverbPopoverTitle:    String { xLoc("quickControls.reverb.popover.title") }
        static var reverbPopoverSubtitle: String { xLoc("quickControls.reverb.popover.subtitle") }
        static var reverbToggle:          String { xLoc("quickControls.reverb.toggle") }
        static var reverbSpace:           String { xLoc("quickControls.reverb.space") }
        static var reverbMix:             String { xLoc("quickControls.reverb.mix") }

        static var triggersPopoverTitle:     String { xLoc("quickControls.triggers.popover.title") }
        static var triggersModeLabel:        String { xLoc("quickControls.triggers.mode.label") }
        static var triggersStringGaugeLabel: String { xLoc("quickControls.triggers.stringGauge.label") }
        static var triggersMotorForceLabel:  String { xLoc("quickControls.triggers.motorForce.label") }
    }

    // MARK: Solo Mode HUD
    enum SoloHUD {
        static var title:          String { xLoc("soloHUD.title") }
        static func harmonicLock(_ name: String) -> String { xLoc("soloHUD.harmonicLock", name) }
        static var compassNorth:   String { xLoc("soloHUD.compass.north") }
        static var compassSouth:   String { xLoc("soloHUD.compass.south") }
        static var compassEast:    String { xLoc("soloHUD.compass.east") }
        static var compassWest:    String { xLoc("soloHUD.compass.west") }
        static func octave(_ n: Int) -> String { xLoc("soloHUD.octave", n) }
        static var readyTitle:     String { xLoc("soloHUD.ready.title") }
        static var readySubtitle:  String { xLoc("soloHUD.ready.subtitle") }
    }

    // MARK: Multi-Controller HUD
    enum MultiController {
        static var title:          String { xLoc("multiController.title") }
        static func syncLabel(a: String, b: String) -> String { xLoc("multiController.sync.label", a, b) }
        static func channel(_ n: Int) -> String { xLoc("multiController.channel", n) }
        static func testTriggerHelp(_ note: String) -> String { xLoc("multiController.testTrigger.help", note) }
    }

    // MARK: Input HUDs
    enum InputHUD {
        static var triggerPos:         String { xLoc("inputHUD.trigger.pos") }
        static var triggerForce:       String { xLoc("inputHUD.trigger.force") }
        static func notchLocked(_ n: Int) -> String { xLoc("inputHUD.trigger.notchLocked", n) }
    }

    // MARK: Niche Controller Visualizers
    enum Visualizer {
        enum Guitar {
            static var title:       String { xLoc("visualizer.guitar.title") }
            static var fretGreen:   String { xLoc("visualizer.guitar.fret.green") }
            static var fretRed:     String { xLoc("visualizer.guitar.fret.red") }
            static var fretYellow:  String { xLoc("visualizer.guitar.fret.yellow") }
            static var fretBlue:    String { xLoc("visualizer.guitar.fret.blue") }
            static var fretOrange:  String { xLoc("visualizer.guitar.fret.orange") }
            static var strumBar:    String { xLoc("visualizer.guitar.strumBar") }
            static func whammy(_ pct: Int) -> String    { xLoc("visualizer.guitar.whammy", pct) }
            static func starPower(_ pct: Int) -> String { xLoc("visualizer.guitar.starPower", pct) }
        }
        enum SDVX {
            static var title: String { xLoc("visualizer.sdvx.title") }
            static var volL:  String { xLoc("visualizer.sdvx.volL") }
            static var volR:  String { xLoc("visualizer.sdvx.volR") }
            static var fxL:   String { xLoc("visualizer.sdvx.fxL") }
            static var fxR:   String { xLoc("visualizer.sdvx.fxR") }
        }
        enum Beatmania {
            static var title:     String { xLoc("visualizer.beatmania.title") }
            static var turntable: String { xLoc("visualizer.beatmania.turntable") }
            static var keys:      String { xLoc("visualizer.beatmania.keys") }
        }
        enum Taiko {
            static var title: String { xLoc("visualizer.taiko.title") }
            static var don:   String { xLoc("visualizer.taiko.don") }
        }
        enum Dance {
            static var title: String { xLoc("visualizer.dance.title") }
        }
        enum Flight {
            static var stick:                  String { xLoc("visualizer.flight.stick") }
            static func throttle(_ pct: Int) -> String { xLoc("visualizer.flight.throttle", pct) }
            static func rudder(_ pct: Int) -> String   { xLoc("visualizer.flight.rudder", pct) }
        }
        enum Wheel {
            static var steering: String { xLoc("visualizer.wheel.steering") }
            static var clutch:   String { xLoc("visualizer.wheel.clutch") }
            static var brake:    String { xLoc("visualizer.wheel.brake") }
            static var gas:      String { xLoc("visualizer.wheel.gas") }
        }
        enum Fight {
            static var stick: String { xLoc("visualizer.fight.stick") }
            static var lp:    String { xLoc("visualizer.fight.lp") }
            static var mp:    String { xLoc("visualizer.fight.mp") }
            static var hp:    String { xLoc("visualizer.fight.hp") }
            static var p3:    String { xLoc("visualizer.fight.3p") }
            static var lk:    String { xLoc("visualizer.fight.lk") }
            static var mk:    String { xLoc("visualizer.fight.mk") }
            static var hk:    String { xLoc("visualizer.fight.hk") }
            static var k3:    String { xLoc("visualizer.fight.3k") }
        }
    }
}
