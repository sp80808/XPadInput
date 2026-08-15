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

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .play: return "gamecontroller.fill"
        case .harmony: return "waveform.path.ecg"
        case .sequence: return "music.note.list"
        case .map: return "slider.vertical.3"
        case .library: return "folder.fill"
        }
    }
}

public enum InstrumentPlayMode: String, CaseIterable, Identifiable {
    case chords = "Chord Strummer"
    case drums = "Rhythm Compass"
    case bass = "Bassline"
    case melody = "Melody Lead"

    public var id: String { rawValue }
}
