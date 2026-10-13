import SwiftUI
import UniformTypeIdentifiers
import XPadCore
import XPadTheory
import XPadSequencer
import XPadMIDI

public struct SequenceWorkspaceView: View {
    @ObservedObject var sequencer: Sequencer
    @Environment(AppState.self) private var appState
    @State private var exportedMidiURL: URL?
    @State private var exportScale: Bool = false
    @State private var exportError: String?

    public init(sequencer: Sequencer) {
        self.sequencer = sequencer
    }

    private var activeScene: XPadSequencer.Scene? {
        guard sequencer.scenes.indices.contains(sequencer.activeSceneIndex) else { return nil }
        return sequencer.scenes[sequencer.activeSceneIndex]
    }

    private var totalSceneTicks: UInt64 {
        let bars = activeScene?.lengthBars ?? 4
        return UInt64(bars * 960 * 4)
    }

    public var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            // Compose Top Toolbar: Scenes, Transport & Actions
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Scenes Selector with Controller LB/RB Hints
                    HStack(spacing: 6) {
                        Text("Scene:")
                            .font(XTheme.fontHeadline)
                            .foregroundStyle(XTheme.textPrimary)

                        ForEach(Array(sequencer.scenes.enumerated()), id: \.offset) { index, scene in
                            let isCurrent = sequencer.activeSceneIndex == index
                            Button {
                                sequencer.activeSceneIndex = index
                            } label: {
                                HStack(spacing: 4) {
                                    if index == 0 && isCurrent {
                                        ControllerShortcutBadge(label: "LB")
                                    } else if index == sequencer.scenes.count - 1 && isCurrent {
                                        ControllerShortcutBadge(label: "RB")
                                    }
                                    Text(scene.name)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isCurrent ? XTheme.brand : XTheme.surfaceHigh)
                                .foregroundStyle(isCurrent ? XTheme.textInverse : XTheme.textPrimary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    // Mini Transport Controls with Controller Glyphs
                    HStack(spacing: 8) {
                        // Play / Pause (A)
                        Button {
                            appState.isPlaying.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                ControllerShortcutBadge(label: "A")
                                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                                Text(appState.isPlaying ? "Pause" : "Play")
                            }
                        }
                        .xButton(appState.isPlaying ? .primary : .secondary, size: .small)

                        // Rewind to Bar 1 (B)
                        Button {
                            appState.isPlaying = false
                            sequencer.stop()
                            sequencer.rewind()
                            appState.showToast("Rewound to Bar 1")
                        } label: {
                            HStack(spacing: 4) {
                                ControllerShortcutBadge(label: "B")
                                Image(systemName: "backward.end.fill")
                                Text("Rewind")
                            }
                        }
                        .xButton(.secondary, size: .small)

                        // Record Toggle (X)
                        Button {
                            appState.isRecording.toggle()
                            sequencer.toggleRecording()
                            appState.showToast(appState.isRecording ? "Recording Armed" : "Recording Disarmed")
                        } label: {
                            HStack(spacing: 4) {
                                ControllerShortcutBadge(label: "X")
                                Circle()
                                    .fill(appState.isRecording ? Color.red : XTheme.textSecondary)
                                    .frame(width: 8, height: 8)
                                Text(appState.isRecording ? "Rec On" : "Record")
                            }
                        }
                        .xButton(appState.isRecording ? .primary : .secondary, size: .small)

                        // Insert Harmony Progression (Y)
                        Button {
                            sequencer.insertProgressionClip(appState.activeProgression, targetTrack: .chords)
                            appState.showToast("Harmony Progression Inserted")
                        } label: {
                            HStack(spacing: 4) {
                                ControllerShortcutBadge(label: "Y")
                                Image(systemName: "plus.rectangle.fill.on.rectangle.fill")
                                Text("Insert Harmony Clip")
                            }
                        }
                        .xButton(.primary, size: .small)

                        // Export MIDI to DAW
                        Button {
                            exportCurrentMIDI()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Export .MID")
                            }
                        }
                        .xButton(.secondary, size: .small)
                        .scaleEffect(exportScale ? 1.08 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: exportScale)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                if let exportError {
                    Text(exportError)
                        .font(.caption)
                        .foregroundStyle(XTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 16)
                }
            }

            Divider()
                .overlay(XTheme.border)
                .padding(.vertical, 10)

            // Multi-track Timeline with Real Clips & Live Playhead
            GeometryReader { geo in
                let totalWidth = max(400, geo.size.width - 200)

                ScrollView {
                    VStack(spacing: 12) {
                        if let scene = activeScene {
                            ForEach(Array(scene.tracks.enumerated()), id: \.offset) { trackIndex, track in
                                let isSelected = appState.sequenceSelectedTrackIndex == trackIndex

                                HStack(spacing: 14) {
                                    // Track Header & Controls
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(track.name)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(isSelected ? XTheme.brand : XTheme.textPrimary)
                                            Spacer()
                                            if isSelected {
                                                Circle()
                                                    .fill(XTheme.brand)
                                                    .frame(width: 6, height: 6)
                                            }
                                        }

                                        Text(track.type.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(XTheme.textSecondary)

                                        // Mute / Solo Buttons with Controller Badges
                                        HStack(spacing: 6) {
                                            Button {
                                                sequencer.toggleMute(trackIndex: trackIndex)
                                            } label: {
                                                HStack(spacing: 2) {
                                                    if isSelected {
                                                        ControllerShortcutBadge(label: "LT")
                                                    }
                                                    Text(track.isMuted ? "MUTED" : "M")
                                                        .font(.system(size: 9, weight: .bold))
                                                }
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(track.isMuted ? Color.red.opacity(0.3) : XTheme.surfaceHigh)
                                                .foregroundStyle(track.isMuted ? Color.red : XTheme.textSecondary)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }
                                            .buttonStyle(.plain)

                                            Button {
                                                sequencer.toggleSolo(trackIndex: trackIndex)
                                            } label: {
                                                HStack(spacing: 2) {
                                                    if isSelected {
                                                        ControllerShortcutBadge(label: "RT")
                                                    }
                                                    Text(track.isSolo ? "SOLO" : "S")
                                                        .font(.system(size: 9, weight: .bold))
                                                }
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(track.isSolo ? Color.yellow.opacity(0.3) : XTheme.surfaceHigh)
                                                .foregroundStyle(track.isSolo ? Color.yellow : XTheme.textSecondary)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(width: 140, alignment: .leading)
                                    .padding(.leading, 8)

                                    // Track Lane with Bar Grid, Clips & Playhead
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: XTheme.radiusS)
                                            .fill(XTheme.surfaceRaised)
                                            .frame(height: 72)

                                        // Bar Grid Lines
                                        let bars = scene.lengthBars
                                        HStack(spacing: 0) {
                                            ForEach(0..<bars, id: \.self) { bar in
                                                ZStack(alignment: .topLeading) {
                                                    Rectangle()
                                                        .stroke(XTheme.border.opacity(0.5), lineWidth: 0.5)
                                                    Text("Bar \(bar + 1)")
                                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                                        .foregroundStyle(XTheme.textTertiary)
                                                        .padding(4)
                                                }
                                                .frame(maxWidth: .infinity)
                                            }
                                        }

                                        // Render Real Clips on Track
                                        if track.clips.isEmpty {
                                            HStack {
                                                Spacer()
                                                if track.type == .chords {
                                                    Text("Empty Track · Press (Y) to Insert Harmony Progression")
                                                        .font(.caption2)
                                                        .foregroundStyle(XTheme.textTertiary)
                                                } else {
                                                    Text("Empty Track · Press (X) to Record Live Performance")
                                                        .font(.caption2)
                                                        .foregroundStyle(XTheme.textTertiary)
                                                }
                                                Spacer()
                                            }
                                        } else {
                                            ForEach(track.clips) { clip in
                                                let clipDurationRatio = Double(clip.durationTicks) / Double(totalSceneTicks)
                                                let clipStartRatio = Double(clip.startTick) / Double(totalSceneTicks)
                                                let clipWidth = max(80, totalWidth * CGFloat(clipDurationRatio))
                                                let clipOffset = totalWidth * CGFloat(clipStartRatio)

                                                SequencerClipItemView(clip: clip, width: clipWidth)
                                                    .offset(x: clipOffset)
                                            }
                                        }

                                        // Animated Playhead Line
                                        if sequencer.transport.isPlaying || sequencer.transport.currentTick > 0 {
                                            let currentTickInScene = sequencer.transport.currentTick % totalSceneTicks
                                            let playheadRatio = Double(currentTickInScene) / Double(totalSceneTicks)
                                            let playheadX = totalWidth * CGFloat(playheadRatio)

                                            Rectangle()
                                                .fill(XTheme.brand)
                                                .frame(width: 2, height: 72)
                                                .overlay(alignment: .top) {
                                                    Circle()
                                                        .fill(XTheme.brand)
                                                        .frame(width: 8, height: 8)
                                                        .offset(y: -4)
                                                }
                                                .shadow(color: XTheme.brand.opacity(0.8), radius: 4)
                                                .offset(x: playheadX)
                                                .animation(.linear(duration: 0.05), value: sequencer.transport.currentTick)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(10)
                                .background(isSelected ? XTheme.brand.opacity(0.08) : XTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusM))
                                .overlay(
                                    RoundedRectangle(cornerRadius: XTheme.radiusM)
                                        .stroke(isSelected ? XTheme.brand : Color.clear, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    appState.sequenceSelectedTrackIndex = trackIndex
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Docked Bottom Controller Legend HUD
            ComposeControllerHUD()
        }
        .overlay(alignment: .top) {
            if let toast = appState.lastActionToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(XTheme.brand)
                    Text(toast)
                        .font(.subheadline.bold())
                        .foregroundStyle(XTheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(XTheme.surfaceHigh)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: appState.lastActionToast)
        .background(XTheme.canvas)
    }

    private func exportCurrentMIDI() {
        guard !sequencer.recordedEvents.isEmpty else {
            self.exportError = "No recorded MIDI events to export. Insert a Harmony progression or enable Record first."
            return
        }

        let exporter = SMFExporter()
        let midiData = exporter.encode(events: sequencer.recordedEvents, bpm: sequencer.transport.bpm)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("XPI Composed Performance.mid")
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

// MARK: - Sequencer Clip Visualizer Item

private struct SequencerClipItemView: View {
    let clip: SequencerClip
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            // Clip Background with subtle brand fill
            RoundedRectangle(cornerRadius: XTheme.radiusXS)
                .fill(XTheme.brand.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusXS)
                        .stroke(XTheme.brand.opacity(0.6), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                // Clip Header
                HStack(spacing: 6) {
                    Text(clip.name)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(XTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(clip.notes.count) notes")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(XTheme.brand)
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)

                // Mini Piano Roll Note Markers
                GeometryReader { geo in
                    let clipW = geo.size.width
                    let clipH = max(10, geo.size.height)
                    let totalTicks = max(UInt64(1), clip.durationTicks)

                    ZStack(alignment: .leading) {
                        ForEach(Array(clip.notes.prefix(32).enumerated()), id: \.offset) { _, noteEvent in
                            let noteX = clipW * CGFloat(Double(noteEvent.startTick) / Double(totalTicks))
                            let noteW = max(4, clipW * CGFloat(Double(noteEvent.durationTicks) / Double(totalTicks)))
                            let noteNormY = CGFloat((Int(noteEvent.note) % 24)) / 24.0
                            let noteY = clipH * (1.0 - noteNormY)

                            RoundedRectangle(cornerRadius: 1)
                                .fill(XTheme.brand.opacity(0.85))
                                .frame(width: noteW, height: 3)
                                .offset(x: noteX, y: max(0, min(clipH - 3, noteY)))
                        }
                    }
                }
                .frame(maxHeight: 28)
                .padding(.horizontal, 4)
            }
        }
        .frame(width: width, height: 56)
        .padding(.leading, 4)
    }
}

// MARK: - Compose Controller HUD Bar

private struct ComposeControllerHUD: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(XTheme.brand)
                Text("COMPOSE CONTROLLER")
                    .font(.caption2.bold())
                    .foregroundStyle(XTheme.textSecondary)
            }

            Divider()
                .frame(height: 14)

            Group {
                legendItem(badge: "LB / RB", action: "Switch Scene")
                legendItem(badge: "D-Pad ↑↓", action: "Select Track")
                legendItem(badge: "A", action: "Play / Pause")
                legendItem(badge: "B", action: "Rewind")
                legendItem(badge: "X", action: "Record Live")
                legendItem(badge: "Y", action: "Insert Harmony Clip")
                legendItem(badge: "LT", action: "Mute")
                legendItem(badge: "RT", action: "Solo")
                legendItem(badge: "Menu", action: "Loop")
            }

            Spacer()

            HStack(spacing: 6) {
                Text("BPM: \(Int(appState.bpm))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(XTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(XTheme.surfaceHigh)
        .overlay(alignment: .top) {
            Divider().overlay(XTheme.border)
        }
    }

    private func legendItem(badge: String, action: String) -> some View {
        HStack(spacing: 4) {
            ControllerShortcutBadge(label: badge)
            Text(action)
                .font(.caption2)
                .foregroundStyle(XTheme.textSecondary)
        }
    }
}

