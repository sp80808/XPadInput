import SwiftUI
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio
import XPadSequencer

public struct TransportBarView: View {
    @ObservedObject var controllerManager: ControllerManager
    @ObservedObject var sequencer: Sequencer
    @Binding var currentScale: Scale
    @Binding var isMPEEnabled: Bool
    @Binding var activeTab: WorkspaceTab
    
    public init(
        controllerManager: ControllerManager,
        sequencer: Sequencer,
        currentScale: Binding<Scale>,
        isMPEEnabled: Binding<Bool>,
        activeTab: Binding<WorkspaceTab>
    ) {
        self.controllerManager = controllerManager
        self.sequencer = sequencer
        self._currentScale = currentScale
        self._isMPEEnabled = isMPEEnabled
        self._activeTab = activeTab
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Workspace Tabs
            HStack(spacing: 4) {
                ForEach(WorkspaceTab.allCases) { tab in
                    Button {
                        activeTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                            Text(tab.rawValue)
                                .fontWeight(activeTab == tab ? .semibold : .regular)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activeTab == tab ?
                            Color.accentColor.opacity(0.2) :
                            Color.clear
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(activeTab == tab ? Color.accentColor : Color.secondary)
                }
            }
            .padding(4)
            .background(Material.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()

            // Key & Scale Selector
            HStack(spacing: 8) {
                Menu {
                    ForEach(PitchClass.allCases) { pc in
                        Button(pc.standardName) {
                            currentScale = Scale(root: pc, type: currentScale.type)
                        }
                    }
                } label: {
                    Text("Key: \(currentScale.root.standardName)")
                        .fontWeight(.medium)
                }
                .menuStyle(.borderlessButton)

                Menu {
                    ForEach(ScaleType.allCases) { type in
                        Button(type.rawValue) {
                            currentScale = Scale(root: currentScale.root, type: type)
                        }
                    }
                } label: {
                    Text(currentScale.type.rawValue)
                        .fontWeight(.medium)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Material.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider().frame(height: 20)

            // Transport Controls
            HStack(spacing: 8) {
                Button {
                    if sequencer.transport.isPlaying {
                        sequencer.stop()
                    } else {
                        sequencer.play()
                    }
                } label: {
                    Image(systemName: sequencer.transport.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(sequencer.transport.isPlaying ? .red : .green)
                        .frame(width: 28, height: 28)
                        .background(Material.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    sequencer.toggleRecording()
                } label: {
                    Circle()
                        .fill(sequencer.transport.isRecording ? Color.red : Color.gray.opacity(0.4))
                        .frame(width: 14, height: 14)
                        .padding(7)
                        .background(Material.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // BPM
                HStack(spacing: 4) {
                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Int(sequencer.transport.bpm))")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Material.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider().frame(height: 20)

            // Controller Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(controllerManager.isHardwareConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Image(systemName: "gamecontroller")
                Text(controllerManager.controllerKind.rawValue)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Material.ultraThinMaterial)
            .clipShape(Capsule())

            // MPE Mode Toggle
            Toggle(isOn: $isMPEEnabled) {
                Text("MPE")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .toggleStyle(.button)
            .tint(.purple)

            // Panic Button
            Button {
                MIDIManager.shared.panic()
                AudioEngine.shared.panic()
            } label: {
                Text("PANIC")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Material.bar)
    }
}
