import Foundation

/// Musical role that owns a conventional MIDI channel on an XPI virtual source.
public enum MIDISourceRole: String, CaseIterable, Codable, Sendable, Identifiable {
    case melody
    case chords
    case bass
    case drums
    case solo

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .melody: return "Melody"
        case .chords: return "Chords"
        case .bass: return "Bass"
        case .drums: return "Drums"
        case .solo: return "Solo / Lead"
        }
    }
}

/// Zero-indexed MIDI channels for each performance role.
public struct MIDIRoleChannelMap: Equatable, Codable, Sendable {
    public var melody: UInt8
    public var chords: UInt8
    public var bass: UInt8
    public var drums: UInt8
    public var solo: UInt8

    public init(
        melody: UInt8 = 0,
        chords: UInt8 = 0,
        bass: UInt8 = 0,
        drums: UInt8 = 9,
        solo: UInt8 = 0
    ) {
        self.melody = Self.clamp(melody)
        self.chords = Self.clamp(chords)
        self.bass = Self.clamp(bass)
        self.drums = Self.clamp(drums)
        self.solo = Self.clamp(solo)
    }

    /// Shared-cable jam layout: Ch 1 chords, 2 bass, 3 lead, 10 drums.
    public static let sharedCableJam = MIDIRoleChannelMap(
        melody: 2,
        chords: 0,
        bass: 1,
        drums: 9,
        solo: 2
    )

    /// Dedicated virtual-port layout: each XPI source uses Ch 1, drums use GM Ch 10.
    public static let dedicatedPorts = MIDIRoleChannelMap()

    public func channel(for role: MIDISourceRole) -> UInt8 {
        switch role {
        case .melody: return melody
        case .chords: return chords
        case .bass: return bass
        case .drums: return drums
        case .solo: return solo
        }
    }

    public func displayChannel(for role: MIDISourceRole) -> Int {
        Int(channel(for: role)) + 1
    }

    private static func clamp(_ value: UInt8) -> UInt8 {
        min(15, value)
    }
}

/// MPE zone advertised to the host. Channels are zero-indexed internally.
public struct MPEZoneLayout: Equatable, Codable, Sendable {
    public var isLowerZone: Bool
    /// Member (note) channels, 1...15. Lower zone members start at MIDI Ch 2.
    public var memberCount: Int

    public init(isLowerZone: Bool = true, memberCount: Int = 14) {
        self.isLowerZone = isLowerZone
        self.memberCount = max(1, min(15, memberCount))
    }

    public static let lowerFourteen = MPEZoneLayout(isLowerZone: true, memberCount: 14)
    public static let lowerFifteen = MPEZoneLayout(isLowerZone: true, memberCount: 15)
    public static let upperFifteen = MPEZoneLayout(isLowerZone: false, memberCount: 15)

    public var masterChannel: UInt8 {
        isLowerZone ? 0 : 15
    }

    public var memberChannels: [UInt8] {
        if isLowerZone {
            return Array(1...UInt8(memberCount))
        }
        let first: Int = 14
        return (0..<memberCount).map { UInt8(first - $0) }
    }

    public var displaySummary: String {
        let zone = isLowerZone ? "Lower" : "Upper"
        let master = Int(masterChannel) + 1
        let members = memberChannels.map { String(Int($0) + 1) }.joined(separator: "–")
        return "\(zone) zone · master Ch \(master) · members Ch \(members)"
    }
}

/// How a DAW MIDI track interprets incoming channel numbers.
public enum DAWTrackChannelMode: Equatable, Codable, Sendable {
    /// Track listens to every channel (Ableton MPE input, Logic "All", Cubase "Any").
    case omni
    /// Track inspector / MIDI From is filtered to a single 0-indexed channel.
    case filtered(UInt8)
}

/// Observable signals used to auto-select a host. Pure data; no AppKit.
public struct HostDetectionSignals: Equatable, Sendable {
    public var frontmostBundleIdentifier: String?
    public var frontmostProcessName: String?
    public var bundleIdentifiers: [String]
    public var processNames: [String]
    public var midiClientNames: [String]

    public init(
        frontmostBundleIdentifier: String? = nil,
        frontmostProcessName: String? = nil,
        bundleIdentifiers: [String] = [],
        processNames: [String] = [],
        midiClientNames: [String] = []
    ) {
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.frontmostProcessName = frontmostProcessName
        self.bundleIdentifiers = bundleIdentifiers
        self.processNames = processNames
        self.midiClientNames = midiClientNames
    }

    public var frontmostOnly: HostDetectionSignals {
        HostDetectionSignals(
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            frontmostProcessName: frontmostProcessName,
            bundleIdentifiers: [frontmostBundleIdentifier].compactMap { $0 },
            processNames: [frontmostProcessName].compactMap { $0 }
        )
    }
}

/// User-facing host selection. `autoDetect` is a mode, not a profile.
public enum DAWHostKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case autoDetect = "Auto-Detect"
    case internalSynth = "Internal Synth"
    case genericMPE = "Generic MPE"
    case genericMIDI = "Generic MIDI"
    case logicPro = "Logic Pro"
    case abletonLive = "Ableton Live"
    case bitwigStudio = "Bitwig Studio"
    case cubase = "Cubase / Nuendo"
    case studioOne = "Studio One"
    case reaper = "REAPER"
    case digitalPerformer = "Digital Performer"
    case waveform = "Waveform"
    case mainStage = "MainStage"
    case garageBand = "GarageBand"
    case flStudio = "FL Studio"
    case proTools = "Pro Tools"
    case reason = "Reason"
    case cakewalk = "Cakewalk / Sonar"
    case luna = "LUNA"
    case ardour = "Ardour"
    case gigPerformer = "Gig Performer"

    public var id: String { rawValue }

    public var isAutoDetect: Bool { self == .autoDetect }

    /// Hosts that appear in the MAP picker besides Auto-Detect.
    public static var selectableHosts: [DAWHostKind] {
        allCases.filter { !$0.isAutoDetect }
    }
}

/// Researched MIDI / MPE channel contract for one DAW or destination class.
///
/// This is a source-side routing policy, not a claim that every host has been
/// certified. Manual DAW proof remains GitHub #3 / #13.
public struct HostMIDIContext: Equatable, Codable, Sendable, Identifiable {
    public var kind: DAWHostKind
    public var supportsMPE: Bool
    public var mpeZone: MPEZoneLayout
    public var bendRangeSemitones: Double
    public var dedicatedPortChannels: MIDIRoleChannelMap
    public var sharedCableChannels: MIDIRoleChannelMap
    public var keepGMDrumsOnChannel10: Bool
    public var requiresOmniTrackForMPE: Bool
    public var setupHint: String
    public var bundleIdentifiers: [String]
    public var processNameHints: [String]
    public var exactProcessNames: [String]
    public var midiClientHints: [String]

    public var id: String { kind.rawValue }
    public var name: String { kind.rawValue }

    public init(
        kind: DAWHostKind,
        supportsMPE: Bool,
        mpeZone: MPEZoneLayout = .lowerFifteen,
        bendRangeSemitones: Double = 48,
        dedicatedPortChannels: MIDIRoleChannelMap = .dedicatedPorts,
        sharedCableChannels: MIDIRoleChannelMap = .sharedCableJam,
        keepGMDrumsOnChannel10: Bool = true,
        requiresOmniTrackForMPE: Bool = true,
        setupHint: String,
        bundleIdentifiers: [String] = [],
        processNameHints: [String] = [],
        exactProcessNames: [String] = [],
        midiClientHints: [String] = []
    ) {
        self.kind = kind
        self.supportsMPE = supportsMPE
        self.mpeZone = mpeZone
        self.bendRangeSemitones = bendRangeSemitones
        self.dedicatedPortChannels = dedicatedPortChannels
        self.sharedCableChannels = sharedCableChannels
        self.keepGMDrumsOnChannel10 = keepGMDrumsOnChannel10
        self.requiresOmniTrackForMPE = requiresOmniTrackForMPE
        self.setupHint = setupHint
        self.bundleIdentifiers = bundleIdentifiers
        self.processNameHints = processNameHints
        self.exactProcessNames = exactProcessNames
        self.midiClientHints = midiClientHints
    }

    public var destinationProfile: DestinationCapabilityProfile {
        if kind == .internalSynth { return .internalSynth }
        if supportsMPE {
            return DestinationCapabilityProfile(
                name: name,
                supportsMPE: true,
                supportsChannelPressure: true,
                supportsPolyPressure: true,
                bendRangeSemitones: bendRangeSemitones,
                supportsCC74: true,
                supportsKeyswitchArticulations: false,
                supportsPortamento: true,
                supportsLegatoOverlap: true,
                pressureMode: .mpePressure
            )
        }
        return DestinationCapabilityProfile(
            name: name,
            supportsMPE: false,
            supportsChannelPressure: true,
            supportsPolyPressure: false,
            bendRangeSemitones: 2,
            supportsCC74: true,
            supportsKeyswitchArticulations: false,
            supportsPortamento: false,
            supportsLegatoOverlap: true,
            pressureMode: .channelPressure
        )
    }

    public func matches(_ signals: HostDetectionSignals) -> Bool {
        let bundles = signals.bundleIdentifiers.map { $0.lowercased() }
        if bundleIdentifiers.contains(where: { candidate in
            let needle = candidate.lowercased()
            return bundles.contains { $0 == needle || $0.hasPrefix(needle) }
        }) {
            return true
        }

        if signals.processNames.contains(where: processNameMatches) {
            return true
        }

        let clients = signals.midiClientNames.map { $0.lowercased() }
        if midiClientHints.contains(where: { hint in
            let needle = hint.lowercased()
            guard needle.count >= 5 else {
                return clients.contains { $0 == needle }
            }
            return clients.contains { $0 == needle || $0.contains(needle) }
        }) {
            return true
        }
        return false
    }

    /// Short hints must match the whole process name so "Live" does not catch "Live Captions".
    private func processNameMatches(_ name: String) -> Bool {
        let lowered = name.lowercased()
        if exactProcessNames.contains(where: { $0.lowercased() == lowered }) {
            return true
        }
        return processNameHints.contains { hint in
            let needle = hint.lowercased()
            guard needle.count >= 5 else {
                return lowered == needle
            }
            return lowered == needle || lowered.contains(needle)
        }
    }

    /// Catalog of researched host defaults. Auto-Detect is a selection mode, not a row.
    public static let catalog: [HostMIDIContext] = [
        .internalSynth,
        .genericMPE,
        .genericMIDI,
        .logicPro,
        .abletonLive,
        .bitwigStudio,
        .cubase,
        .studioOne,
        .reaper,
        .digitalPerformer,
        .waveform,
        .mainStage,
        .garageBand,
        .flStudio,
        .proTools,
        .reason,
        .cakewalk,
        .luna,
        .ardour,
        .gigPerformer
    ]

    public static func context(for kind: DAWHostKind) -> HostMIDIContext {
        catalog.first { $0.kind == kind } ?? .internalSynth
    }
}

// MARK: - Researched host defaults

extension HostMIDIContext {
    public static let internalSynth = HostMIDIContext(
        kind: .internalSynth,
        supportsMPE: true,
        mpeZone: .lowerFourteen,
        bendRangeSemitones: 48,
        setupHint: "Internal synth follows XPI's 14-member lower zone. Choose Auto-Detect or a named DAW to retarget MIDI channels for that host."
    )

    public static let genericMPE = HostMIDIContext(
        kind: .genericMPE,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "MMA lower zone: master MIDI Ch 1, members 2–16, ±48 st. Put the destination track on All / Any Channels."
    )

    public static let genericMIDI = HostMIDIContext(
        kind: .genericMIDI,
        supportsMPE: false,
        mpeZone: .lowerFourteen,
        bendRangeSemitones: 2,
        setupHint: "Conventional MIDI. Melody/chords/bass on Ch 1 of their virtual ports; drums on GM Ch 10. Set the DAW track to that channel or All."
    )

    /// Logic MIDI Mono Mode default is common base channel 1, voices on 2–16, ±48 st.
    public static let logicPro = HostMIDIContext(
        kind: .logicPro,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Set the instrument to MIDI Mono Mode: On (common base channel 1), pitch range 48. Track MIDI Channel should be All. Alchemy/ES2/Sampler/Sculpture/Retro Synth are the bundled MPE path. MIDI 2.0 is a Logic preference, not a channel change.",
        bundleIdentifiers: ["com.apple.logic10", "com.apple.mobilelogic"],
        processNameHints: ["logic pro"],
        midiClientHints: ["logic pro"]
    )

    /// Live locks MPE input tracks to All Channels; master Ch 1 never carries notes.
    public static let abletonLive = HostMIDIContext(
        kind: .abletonLive,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Link/MIDI: enable Track and MPE on the XPI source. An MPE MIDI track is fixed to All Channels; Live never places notes on master Ch 1. Live 11/12 instruments accept the lower zone; constrain Last Note Channel if a plug-in has fewer voices.",
        bundleIdentifiers: ["com.ableton.live"],
        processNameHints: ["ableton"],
        exactProcessNames: ["Live"],
        midiClientHints: ["ableton"]
    )

    public static let bitwigStudio = HostMIDIContext(
        kind: .bitwigStudio,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Use a Generic MPE controller or XPI Expression (MPE) with 15 member channels, lower zone. Polymer/Phase-4/Grid accept MPE natively; third-party devices may need Force MPE Mode. Leave note-channel filter on All.",
        bundleIdentifiers: ["com.bitwig.BitwigStudio"],
        processNameHints: ["bitwig"],
        midiClientHints: ["bitwig"]
    )

    /// Cubase MPE Mode uses channel 1 as base; Input Group/Channel must be Any for per-note CCs.
    public static let cubase = HostMIDIContext(
        kind: .cubase,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Studio Setup → Note Expression Input Device: MPE Mode (base Ch 1). Route the instrument track to XPI Expression (MPE). Named Steinberg MPE hardware pages keep their preset routing; a generic CoreMIDI source needs Input Group/Channel = Any Input or per-note CCs are dropped.",
        bundleIdentifiers: [
            "com.steinberg.cubase15",
            "com.steinberg.cubase14",
            "com.steinberg.cubase13",
            "com.steinberg.cubase12",
            "com.steinberg.cubasepro",
            "com.steinberg.cubase",
            "com.steinberg.nuendo15",
            "com.steinberg.nuendo14",
            "com.steinberg.nuendo"
        ],
        processNameHints: ["cubase", "nuendo"],
        midiClientHints: ["cubase", "nuendo"]
    )

    public static let studioOne = HostMIDIContext(
        kind: .studioOne,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "External Devices: enable MPE on the XPI input. That greys out the MIDI channel selector because the track must see every channel. Pitch-bend range 48. Bundled PreSonus instruments are generally not MPE; use a third-party MPE instrument.",
        bundleIdentifiers: [
            "com.presonus.studioone7",
            "com.presonus.studioone6",
            "com.presonus.studioone5",
            "com.presonus.studioone"
        ],
        processNameHints: ["studio one"],
        midiClientHints: ["studio one", "presonus"]
    )

    /// REAPER records multi-channel MIDI without an MPE switch; the track must be All Channels.
    public static let reaper = HostMIDIContext(
        kind: .reaper,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Track input: MIDI → XPI Expression (MPE) → All Channels, and Map input to channel = Through. There is no MPE toggle; the hosted plug-in must understand the lower zone.",
        bundleIdentifiers: ["com.cockos.reaper"],
        processNameHints: ["reaper"],
        midiClientHints: ["reaper"]
    )

    public static let digitalPerformer = HostMIDIContext(
        kind: .digitalPerformer,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Digital Performer 11+ accepts MPE on a MIDI/instrument track set to all channels. Use the lower zone (master 1, members 2–16) and ±48 st unless the instrument documents otherwise.",
        bundleIdentifiers: ["com.motu.DigitalPerformer", "com.motu.digitalperformer"],
        processNameHints: ["digital performer"],
        midiClientHints: ["digital performer", "motu"]
    )

    public static let waveform = HostMIDIContext(
        kind: .waveform,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Waveform records MPE as note expression. Use All Channels on the track and the lower 15-member zone.",
        bundleIdentifiers: ["com.tracktion.waveform", "com.tracktion.Waveform"],
        processNameHints: ["waveform"],
        midiClientHints: ["waveform", "tracktion"]
    )

    public static let mainStage = HostMIDIContext(
        kind: .mainStage,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "MainStage uses Logic's MIDI Mono Mode instruments. Common base channel 1, members 2–16, matching pitch-bend range.",
        bundleIdentifiers: ["com.apple.mainstage3", "com.apple.mainstage"],
        processNameHints: ["mainstage"],
        midiClientHints: ["mainstage"]
    )

    public static let garageBand = HostMIDIContext(
        kind: .garageBand,
        supportsMPE: false,
        bendRangeSemitones: 2,
        setupHint: "macOS GarageBand has only basic pressure/bend on some instruments and no MPE editing. XPI sends conventional MIDI on Ch 1 (drums on 10). iOS GarageBand's Support MPE Controllers toggle does not apply here.",
        bundleIdentifiers: ["com.apple.garageband10", "com.apple.mobilegarageband"],
        processNameHints: ["garageband"],
        midiClientHints: ["garageband"]
    )

    /// Image-Line has been skipping MPE in favour of MIDI 2 per-note; treat as conventional.
    public static let flStudio = HostMIDIContext(
        kind: .flStudio,
        supportsMPE: false,
        bendRangeSemitones: 2,
        sharedCableChannels: MIDIRoleChannelMap(melody: 0, chords: 0, bass: 0, drums: 9, solo: 0),
        setupHint: "FL Studio does not implement MPE channel zones. Send conventional MIDI on Ch 1 of each XPI port (drums GM Ch 10). Set the Channel MIDI out to that channel, or use separate MIDI inputs per port.",
        bundleIdentifiers: ["com.image-line.flstudio", "com.imageline.flstudio"],
        processNameHints: ["fl studio", "fl64", "fl.exe"],
        midiClientHints: ["fl studio", "image-line"]
    )

    public static let proTools = HostMIDIContext(
        kind: .proTools,
        supportsMPE: false,
        bendRangeSemitones: 2,
        sharedCableChannels: MIDIRoleChannelMap(melody: 0, chords: 0, bass: 0, drums: 9, solo: 0),
        setupHint: "Pro Tools MIDI tracks filter by channel. Use Ch 1 for pitched roles and GM Ch 10 for drums, or set the track channel to match. Native MPE is not a shipping routing mode.",
        bundleIdentifiers: [
            "com.avid.ProTools",
            "com.avid.ProToolsUltimate",
            "com.avid.ProToolsStudio",
            "com.avid.ProToolsIntro",
            "com.avid.ProToolsArtist"
        ],
        processNameHints: ["pro tools"],
        midiClientHints: ["pro tools", "avid"]
    )

    public static let reason = HostMIDIContext(
        kind: .reason,
        supportsMPE: false,
        bendRangeSemitones: 2,
        sharedCableChannels: MIDIRoleChannelMap(melody: 0, chords: 0, bass: 0, drums: 9, solo: 0),
        setupHint: "Reason devices typically listen on a single MIDI channel (usually Ch 1). XPI uses conventional MIDI; enable the XPI port on the sequencer track MIDI input.",
        bundleIdentifiers: [
            "com.reasonstudios.Reason",
            "com.propellerheads.Reason",
            "se.propellerheads.Reason"
        ],
        processNameHints: ["reason"],
        midiClientHints: ["reason"]
    )

    public static let cakewalk = HostMIDIContext(
        kind: .cakewalk,
        supportsMPE: false,
        bendRangeSemitones: 2,
        setupHint: "Cakewalk / Sonar will pass multi-channel MIDI but has no MPE note editor. Prefer conventional Ch 1 / drums Ch 10, or All Channels if you intentionally send MPE from XPI Expression.",
        bundleIdentifiers: ["com.bandlab.cakewalk", "com.cakewalk.sonar"],
        processNameHints: ["cakewalk", "sonar"],
        midiClientHints: ["cakewalk", "sonar"]
    )

    /// Universal Audio LUNA has no shipping MPE zone; treat as conventional channel MIDI.
    public static let luna = HostMIDIContext(
        kind: .luna,
        supportsMPE: false,
        bendRangeSemitones: 2,
        sharedCableChannels: MIDIRoleChannelMap(melody: 0, chords: 0, bass: 0, drums: 9, solo: 0),
        setupHint: "LUNA MIDI tracks filter by channel. Use Ch 1 for pitched XPI ports and GM Ch 10 for drums, or set the track channel to match.",
        bundleIdentifiers: ["com.uaudio.LUNA", "com.uaudio.luna", "com.universal-audio.luna"],
        processNameHints: ["luna"],
        exactProcessNames: ["LUNA"],
        midiClientHints: ["luna"]
    )

    /// Ardour records multi-channel MIDI similarly to REAPER; the track must be All Channels.
    public static let ardour = HostMIDIContext(
        kind: .ardour,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Set the MIDI track to All Channels and leave channel map Through. Ardour has no separate MPE toggle; the instrument plugin must understand the lower zone.",
        bundleIdentifiers: ["org.ardour.Ardour", "org.ardour.Ardour8", "org.ardour.Ardour7", "org.ardour.Ardour6"],
        processNameHints: ["ardour"],
        midiClientHints: ["ardour"]
    )

    public static let gigPerformer = HostMIDIContext(
        kind: .gigPerformer,
        supportsMPE: true,
        mpeZone: .lowerFifteen,
        setupHint: "Enable MPE on the Gig Performer MIDI input block feeding XPI Expression (MPE). Use All Channels / the lower 15-member zone and ±48 st unless the hosted plugin documents a smaller Last Note Channel.",
        bundleIdentifiers: [
            "com.deskew.gigperformer5",
            "com.deskew.gigperformer4",
            "com.deskew.GigPerformer",
            "com.deskew.gigperformer"
        ],
        processNameHints: ["gig performer"],
        midiClientHints: ["gig performer"]
    )
}

/// Result of combining a host profile with the DAW track's channel inspector.
public struct ResolvedMIDIChannelLayout: Equatable, Sendable {
    public var host: DAWHostKind
    public var usesMPE: Bool
    public var mpeZone: MPEZoneLayout
    public var channels: MIDIRoleChannelMap
    public var trackMode: DAWTrackChannelMode
    public var diagnostic: String?

    public func channel(for role: MIDISourceRole) -> UInt8 {
        channels.channel(for: role)
    }

    public var summary: String {
        if usesMPE {
            return mpeZone.displaySummary
        }
        return "Ch \(channels.displayChannel(for: .melody)) pitched · Ch \(channels.displayChannel(for: .drums)) drums"
    }
}

public enum HostMIDIContextResolver {
    /// Frontmost / first matching signal wins. Manual selection always wins over Auto-Detect.
    public static func resolve(
        selection: DAWHostKind,
        signals: HostDetectionSignals = HostDetectionSignals()
    ) -> (kind: DAWHostKind, context: HostMIDIContext, note: String) {
        if !selection.isAutoDetect {
            let context = HostMIDIContext.context(for: selection)
            return (selection, context, "Manual host: \(selection.rawValue)")
        }

        let detectionOrder: [DAWHostKind] = [
            .logicPro, .mainStage, .abletonLive, .bitwigStudio, .cubase, .studioOne,
            .reaper, .digitalPerformer, .waveform, .gigPerformer, .ardour, .garageBand,
            .flStudio, .proTools, .reason, .luna, .cakewalk
        ]

        if let kind = firstMatch(in: detectionOrder, signals: signals.frontmostOnly) {
            let context = HostMIDIContext.context(for: kind)
            return (kind, context, "Detected \(kind.rawValue) as the frontmost app.")
        }

        if let kind = firstMatch(in: detectionOrder, signals: signals) {
            let context = HostMIDIContext.context(for: kind)
            return (kind, context, "\(kind.rawValue) is running. Using its channel map.")
        }

        return (.internalSynth, .internalSynth, "No DAW detected. Using Internal Synth.")
    }

    private static func firstMatch(in order: [DAWHostKind], signals: HostDetectionSignals) -> DAWHostKind? {
        order.first { HostMIDIContext.context(for: $0).matches(signals) }
    }

    public static func resolveLayout(
        context: HostMIDIContext,
        trackMode: DAWTrackChannelMode,
        useSharedCable: Bool = false
    ) -> ResolvedMIDIChannelLayout {
        var channels = useSharedCable ? context.sharedCableChannels : context.dedicatedPortChannels

        switch trackMode {
        case .omni:
            return ResolvedMIDIChannelLayout(
                host: context.kind,
                usesMPE: context.supportsMPE,
                mpeZone: context.mpeZone,
                channels: channels,
                trackMode: trackMode,
                diagnostic: nil
            )

        case .filtered(let rawChannel):
            let channel = min(15, rawChannel)
            let display = Int(channel) + 1
            channels.melody = channel
            channels.chords = channel
            channels.bass = channel
            channels.solo = channel
            if !context.keepGMDrumsOnChannel10 || channel == 9 {
                channels.drums = channel
            }

            let diagnostic: String
            if context.supportsMPE && context.requiresOmniTrackForMPE {
                diagnostic = "Track MIDI channel is \(display), which filters away MPE member channels. XPI is sending conventional MIDI on Ch \(display). Set the track to All / Any Channels to restore MPE."
                return ResolvedMIDIChannelLayout(
                    host: context.kind,
                    usesMPE: false,
                    mpeZone: context.mpeZone,
                    channels: channels,
                    trackMode: trackMode,
                    diagnostic: diagnostic
                )
            }

            diagnostic = "Track MIDI channel \(display) applied to pitched roles."
            return ResolvedMIDIChannelLayout(
                host: context.kind,
                usesMPE: false,
                mpeZone: context.mpeZone,
                channels: channels,
                trackMode: trackMode,
                diagnostic: diagnostic
            )
        }
    }
}
