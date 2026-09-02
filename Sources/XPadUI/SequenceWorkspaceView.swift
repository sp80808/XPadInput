import SwiftUI
import UniformTypeIdentifiers
import XPadCore
import XPadSequencer
import XPadMIDI

public struct SequenceWorkspaceView: View {
    @ObservedObject var sequencer: Sequencer
    @State private var exportedMidiURL: URL?
    @State private var exportScale: Bool = false
    @State private var exportError: String?
    public init(sequencer: Sequencer) {
        self.sequencer = sequencer
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Scenes Header
            HStack(spacing: 12) {
                Text("Scenes:")
                    .font(.headline)
                ForEach(Array(sequencer.scenes.enumerated()), id: \.offset) { index, scene in
                    Button {
                        sequencer.activeSceneIndex = index
                    } label: {
                        Text(scene.name)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(sequencer.activeSceneIndex == index ? Color.accentColor : Color.white.opacity(0.1))
                            .foregroundStyle(sequencer.activeSceneIndex == index ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()

                // Export MIDI Drag & Drop Card
                Button {
                    exportCurrentMIDI()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Export .MID to DAW")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .scaleEffect(exportScale ? 1.08 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.75), value: exportScale)
                .onChange(of: exportedMidiURL) { _, newURL in
                    guard newURL != nil else { return }
                    exportScale = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        exportScale = false
                    }
                }
            }
            .padding(.horizontal)

            if let exportError {
                Text(exportError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
            }

            // Multi-track Timeline
            ScrollView {
                VStack(spacing: 10) {
                    if sequencer.activeSceneIndex < sequencer.scenes.count {
                        let activeScene = sequencer.scenes[sequencer.activeSceneIndex]
                        ForEach(activeScene.tracks) { track in
                            HStack(spacing: 16) {
                                // Track Header
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(track.type.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 120, alignment: .leading)

                                // Track Lane / Ruler
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.25))
                                        .frame(height: 60)

                                    // Grid Lines (4 bars)
                                    HStack(spacing: 0) {
                                        ForEach(0..<4) { bar in
                                            Rectangle()
                                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }

                                    // Clip Representation
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.accentColor.opacity(0.35))
                                        .frame(width: 200, height: 44)
                                        .padding(.leading, 8)
                                        .overlay(
                                            Text("\(track.name) Clip")
                                                .font(.caption2.bold())
                                                .padding(.leading, 14),
                                            alignment: .leading
                                        )
                                }
                            }
                            .padding(10)
                            .background(Material.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    private func exportCurrentMIDI() {
        guard !sequencer.recordedEvents.isEmpty else {
            self.exportError = "No recorded MIDI events to export. Enable Record and play a performance first."
            return
        }

        let exporter = SMFExporter()
        let midiData = exporter.encode(events: sequencer.recordedEvents, bpm: sequencer.transport.bpm)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("XPI Performance.mid")
        do {
            try midiData.write(to: tempURL)
            self.exportedMidiURL = tempURL
            self.exportError = nil
            NSWorkspace.shared.activateFileViewerSelecting([tempURL])
        } catch {
            print("Failed to save MIDI file: \(error)")
            self.exportError = "Failed to save MIDI file: \(error.localizedDescription)"
        }
    }
}
