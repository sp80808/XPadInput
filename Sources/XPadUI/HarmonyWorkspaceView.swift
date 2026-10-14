import SwiftUI
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio

public struct HarmonyWorkspaceView: View {
    @Binding var currentScale: Scale
    @Environment(AppState.self) private var appState
    @State private var voiceLeadingStrategy: VoiceLeadingStrategy = .smooth
    @State private var modulationTargetKey: PitchClass = .g

    private let modulationEngine = ModulationEngine()

    public init(currentScale: Binding<Scale>) {
        self._currentScale = currentScale
    }

    private var activeProgression: Progression {
        appState.activeProgression
    }

    private var selectedChord: Chord {
        let idx = appState.selectedProgressionBlockIndex
        if idx < activeProgression.blocks.count {
            return activeProgression.blocks[idx].chord
        }
        return appState.currentChord ?? Chord(root: appState.currentKey, quality: .major)
    }

    private var suggestions: [ChordSuggestion] {
        appState.harmonicSuggestions
    }

    private var modulationPaths: [ModulationPath] {
        let targetScale = Scale(root: modulationTargetKey, type: currentScale.type)
        return modulationEngine.pathways(from: currentScale, to: targetScale)
    }

    public var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            HSplitView {
                // Left Column: Progression Builder & Modulation Explorer
                VStack(alignment: .leading, spacing: 16) {
                    // Progression Builder Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chord Progression Builder")
                                    .font(XTheme.fontHeadline)
                                    .foregroundStyle(XTheme.textPrimary)
                                Text("Tactile Chords · \(activeProgression.blocks.count) blocks · \(Int(activeProgression.totalBeats)) beats")
                                    .font(.caption2)
                                    .foregroundStyle(XTheme.textSecondary)
                            }

                            Spacer()

                            // Perform in Play Mode Button
                            Button {
                                appState.chordPerformanceSource = .activeProgression
                                appState.selectedWorkspace = .play
                            } label: {
                                Label("Perform in Play", systemImage: "gamecontroller.fill")
                            }
                            .xButton(.secondary, size: .small)
                            .help("Switch to Play Workspace with active progression mapped to your controller")

                            // Mutate Button with (Y) prompt
                            Button {
                                appState.mutateActiveProgression(complexity: 0.4)
                            } label: {
                                HStack(spacing: 4) {
                                    ControllerShortcutBadge(label: "Y")
                                    Label("Mutate", systemImage: "wand.and.stars")
                                }
                            }
                            .xButton(.secondary, size: .small)

                            // Play All / Stop with (LT) prompt
                            Button {
                                appState.playActiveProgressionToggle()
                            } label: {
                                HStack(spacing: 4) {
                                    ControllerShortcutBadge(label: "LT")
                                    Label(appState.isPlayingProgression ? "Stop" : "Play All",
                                          systemImage: appState.isPlayingProgression ? "stop.fill" : "play.fill")
                                }
                            }
                            .xButton(.primary, size: .small)

                            // Send to Compose (RT)
                            Button {
                                appState.sendActiveProgressionToSequencer()
                                appState.showToast("Progression Sent to Compose (Chords Track)")
                            } label: {
                                HStack(spacing: 4) {
                                    ControllerShortcutBadge(label: "RT")
                                    Label("Send to Compose", systemImage: "arrow.right.to.line.compact")
                                }
                            }
                            .xButton(.primary, size: .small)
                        }

                        // Chord Blocks Row with Controller Focus
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(activeProgression.blocks.enumerated()), id: \.offset) { index, block in
                                    let isSelected = appState.selectedProgressionBlockIndex == index
                                    let isControllerFocused = isSelected && appState.harmonyFocusedZone == .progressionBlocks

                                    ChordBlockCard(
                                        block: block,
                                        index: index,
                                        isSelected: isSelected,
                                        isControllerFocused: isControllerFocused
                                    )
                                    .onTapGesture {
                                        appState.selectedProgressionBlockIndex = index
                                        appState.harmonyFocusedZone = .progressionBlocks
                                        appState.auditionChord(block.chord)
                                    }
                                }

                                // Add Block Button
                                Button {
                                    let newChord = suggestions.first?.chord ?? selectedChord
                                    appState.addChordToActiveProgression(newChord, durationBeats: 4.0)
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.title2)
                                        Text("Add")
                                            .font(.caption2)
                                    }
                                    .frame(width: 70, height: 104)
                                    .background(XTheme.surfaceRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusM))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: XTheme.radiusM)
                                            .stroke(XTheme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding()
                    .background(XTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusL))

                    // Style Morph Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Style Morph")
                                    .font(XTheme.fontHeadline)
                                    .foregroundStyle(XTheme.textPrimary)
                                Text("\(appState.harmonicStyle.name) → \(appState.harmonicStyleTarget.name) · \(Int(appState.styleMorphAmount * 100))% blended")
                                    .font(.caption2)
                                    .foregroundStyle(XTheme.textSecondary)
                            }

                            Spacer()

                            Button {
                                appState.generateStyleProgression()
                            } label: {
                                Label("Generate", systemImage: "wand.and.stars")
                            }
                            .xButton(.primary, size: .small)
                            .help("Write a new progression in the blended style")

                            Button {
                                appState.reharmoniseActiveProgression()
                            } label: {
                                Label("Reharmonise", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .xButton(.secondary, size: .small)
                            .help("Keep this progression's rhythm, change its harmony to the blended style")
                        }

                        HStack(spacing: 12) {
                            Picker("From", selection: $appState.harmonicStyle) {
                                ForEach(HarmonicStyleLibrary.all, id: \.name) { style in
                                    Text(style.name).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 190)

                            Picker("To", selection: $appState.harmonicStyleTarget) {
                                ForEach(HarmonicStyleLibrary.all, id: \.name) { style in
                                    Text(style.name).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 190)

                            Slider(value: $appState.styleMorphAmount, in: 0...1)
                                .help("Blend between the two styles")

                            Stepper(value: $appState.styleMorphBars, in: 1...16) {
                                Text("\(appState.styleMorphBars) bars")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(XTheme.textSecondary)
                            }
                            .fixedSize()
                        }

                        HStack(spacing: 8) {
                            Text("Root emphasis, extension colour, modal interchange, harmonic rhythm")
                                .font(.caption2)
                                .foregroundStyle(XTheme.textSecondary)
                            Spacer()
                            Text("\(appState.morphedStyle.chordsPerBar.formatted(.number.precision(.fractionLength(2)))) chords/bar")
                                .font(.caption2.monospaced())
                                .foregroundStyle(XTheme.textSecondary)
                        }
                    }
                    .padding()
                    .background(XTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusL))

                    // Modulation Explorer
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Modulation Explorer: \(appState.currentKey.standardName) → ")
                                .font(XTheme.fontHeadline)
                                .foregroundStyle(XTheme.textPrimary)
                            Picker("Target Key", selection: $modulationTargetKey) {
                                ForEach(PitchClass.allCases) { pc in
                                    Text(pc.standardName).tag(pc)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(modulationPaths) { path in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(path.type.rawValue)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(XTheme.brand)
                                            Spacer()
                                            Button("Audition Path") {
                                                playModulationPath(path)
                                            }
                                            .xButton(.secondary, size: .small)
                                        }
                                        Text(path.explanation)
                                            .font(.caption)
                                            .foregroundStyle(XTheme.textSecondary)
                                        HStack(spacing: 8) {
                                            ForEach(path.intermediateChords) { chord in
                                                Text(chord.symbol)
                                                    .font(.caption.monospaced())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(XTheme.surfaceHigh)
                                                    .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusS))
                                                    .onTapGesture {
                                                        appState.auditionChord(chord)
                                                    }
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(XTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusM))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(XTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusL))
                }
                .padding()
                .frame(minWidth: 440)

                // Right Column: "What Next?" Harmonic Suggestions & Voice Leading
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Harmonic Suggestions")
                                .font(XTheme.fontHeadline)
                                .foregroundStyle(XTheme.textPrimary)
                            Text("Based on active chord \(selectedChord.symbol)")
                                .font(.caption2)
                                .foregroundStyle(XTheme.textSecondary)
                        }
                        Spacer()
                        Picker("Voice Leading", selection: $voiceLeadingStrategy) {
                            ForEach(VoiceLeadingStrategy.allCases) { strat in
                                Text(strat.rawValue).tag(strat)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, item in
                                let isSelected = appState.harmonyFocusedZone == .suggestions && appState.harmonySelectedSuggestionIndex == index
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(item.chord.symbol)
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundStyle(isSelected ? XTheme.brand : XTheme.textPrimary)
                                            Text(item.category.rawValue)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(XTheme.brand.opacity(0.18))
                                                .foregroundStyle(XTheme.brand)
                                                .clipShape(Capsule())
                                        }
                                        Text(item.reason)
                                            .font(.caption)
                                            .foregroundStyle(XTheme.textSecondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()

                                    // Audition Button (A)
                                    Button {
                                        appState.harmonyFocusedZone = .suggestions
                                        appState.harmonySelectedSuggestionIndex = index
                                        appState.auditionChord(item.chord)
                                    } label: {
                                        HStack(spacing: 4) {
                                            if isSelected {
                                                ControllerShortcutBadge(label: "A")
                                            }
                                            Text("Audition")
                                        }
                                    }
                                    .xButton(.secondary, size: .small)

                                    // Add Button (X)
                                    Button {
                                        appState.addChordToActiveProgression(item.chord, durationBeats: 4.0)
                                        appState.showToast("Added \(item.chord.symbol) to Progression")
                                    } label: {
                                        HStack(spacing: 4) {
                                            if isSelected {
                                                ControllerShortcutBadge(label: "X")
                                            }
                                            Text("Add")
                                        }
                                    }
                                    .xButton(.primary, size: .small)
                                }
                                .padding(10)
                                .background(isSelected ? XTheme.brand.opacity(0.12) : XTheme.surfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusM))
                                .overlay(
                                    RoundedRectangle(cornerRadius: XTheme.radiusM)
                                        .stroke(isSelected ? XTheme.brand : Color.clear, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    appState.harmonyFocusedZone = .suggestions
                                    appState.harmonySelectedSuggestionIndex = index
                                    appState.auditionChord(item.chord)
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(minWidth: 380)
            }

            // Docked Bottom Controller Legend HUD
            HarmonyControllerHUD()
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

    private func playModulationPath(_ path: ModulationPath) {
        var delay: Double = 0.0
        for chord in path.intermediateChords {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                appState.auditionChord(chord)
            }
            delay += 1.2
        }
    }
}

// MARK: - Controller Shortcut Badge

public struct ControllerShortcutBadge: View {
    let label: String

    public init(label: String) {
        self.label = label
    }

    public var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(XTheme.brand)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(XTheme.brand.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(XTheme.brand.opacity(0.4), lineWidth: 0.5)
            )
    }
}

// MARK: - Chord Block Card with Controller Glow

private struct ChordBlockCard: View {
    let block: ChordBlock
    let index: Int
    let isSelected: Bool
    let isControllerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(block.romanNumeral.isEmpty ? "—" : block.romanNumeral)
                    .font(.caption2.bold())
                    .foregroundStyle(isSelected ? XTheme.brand : XTheme.textSecondary)
                Spacer()
                if isControllerFocused {
                    Text("#\(index + 1)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(XTheme.brand)
                }
            }

            Text(block.chord.symbol)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? XTheme.brand : XTheme.textPrimary)

            Text("\(Int(block.durationBeats)) beats")
                .font(.caption2)
                .foregroundStyle(XTheme.textSecondary)
        }
        .padding(12)
        .frame(width: 104, height: 104)
        .background(isSelected ? XTheme.brand.opacity(0.18) : XTheme.control)
        .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusM))
        .overlay(
            RoundedRectangle(cornerRadius: XTheme.radiusM)
                .stroke(isControllerFocused ? XTheme.brand : (isSelected ? XTheme.brand.opacity(0.5) : Color.clear), lineWidth: isControllerFocused ? 2 : 1)
        )
        .shadow(color: isControllerFocused ? XTheme.brand.opacity(0.3) : .clear, radius: 8)
        .scaleEffect(reduceMotion ? 1 : (isHovering ? 1.03 : 1.0))
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Harmony Controller HUD Bar

private struct HarmonyControllerHUD: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(XTheme.brand)
                Text("HARMONY CONTROLLER")
                    .font(.caption2.bold())
                    .foregroundStyle(XTheme.textSecondary)
            }

            Divider()
                .frame(height: 14)

            Group {
                legendItem(badge: "LB / RB", action: "Step Block")
                legendItem(badge: "D-Pad ↑↓", action: "Navigate")
                legendItem(badge: "A", action: "Audition")
                legendItem(badge: "X", action: "Add Chord")
                legendItem(badge: "Y", action: "Mutate")
                legendItem(badge: "B", action: "Delete")
                legendItem(badge: "RT", action: "Send to Compose")
                legendItem(badge: "LT", action: "Play All")
            }

            Spacer()

            if appState.chordPerformanceSource == .activeProgression {
                HStack(spacing: 4) {
                    Circle()
                        .fill(XTheme.brand)
                        .frame(width: 6, height: 6)
                    Text("Live Play Mode: Composed Progression")
                        .font(.caption2)
                        .foregroundStyle(XTheme.brand)
                }
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

