import SwiftUI
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio
import XPadSequencer

public enum WorkspaceTab: String, CaseIterable, Identifiable {
    case play = "Play"
    case harmony = "Harmony"
    case sequence = "Sequence"
    case map = "Controller Map"
    case library = "Library"
    case practice = "Practice"

    public var id: String { rawValue }

    /// Tabs shown in persistent navigation chrome. Practice is opened on
    /// demand and must not occupy first-launch screenspace.
    public static var persistentCases: [WorkspaceTab] {
        allCases.filter { $0 != .practice }
    }

    public var iconName: String {
        switch self {
        case .play: return "gamecontroller.fill"
        case .harmony: return "waveform.path.ecg"
        case .sequence: return "music.note.list"
        case .map: return "slider.vertical.3"
        case .library: return "folder.fill"
        case .practice: return "graduationcap.fill"
        }
    }
}

public enum InstrumentPlayMode: String, CaseIterable, Identifiable {
    case chords = "Chord Strummer"
    case arp = "Arpeggiator"
    case drone = "Drone Pad"
    case drums = "Rhythm Compass"
    case bass = "Bassline"
    case melody = "Melody Lead"

    public var id: String { rawValue }
}
