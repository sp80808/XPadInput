import SwiftUI
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio
import XPadSequencer

public struct MainAppView: View {
    @StateObject private var controllerManager = ControllerManager()
    @StateObject private var sequencer = Sequencer()
    @State private var currentScale: Scale = .cMajor
    @State private var isMPEEnabled: Bool = true
    @State private var activeTab: WorkspaceTab = .play

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Persistent Top Transport & Workspace Navigation Bar
            TransportBarView(
                controllerManager: controllerManager,
                sequencer: sequencer,
                currentScale: $currentScale,
                isMPEEnabled: $isMPEEnabled,
                activeTab: $activeTab
            )

            Divider()

            // Active Workspace Content
            Group {
                switch activeTab {
                case .play:
                    PlayWorkspaceView(controllerManager: controllerManager, currentScale: $currentScale)
                case .harmony:
                    HarmonyWorkspaceView(currentScale: $currentScale)
                case .sequence:
                    SequenceWorkspaceView(sequencer: sequencer)
                case .map:
                    MapWorkspaceView(controllerManager: controllerManager)
                case .library:
                    LibraryWorkspaceView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            AudioEngine.shared.startEngine()
            if isMPEEnabled {
                MPEManager().sendMPEZoneConfiguration()
            }
        }
    }
}
