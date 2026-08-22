import SwiftUI
import XPadCore
import XPadController
import XPadMIDI
import XPadAudio

/// Persistent transport bar with playback, key/scale, BPM, and status indicators.
/// Persistent transport bar with playback, key/scale, BPM, and status indicators.
struct TransportBar: View {
    @Environment(AppState.self) private var appState
    @Environment(\.viewportMetrics) private var viewport
    @State private var tapTimes: [Date] = []
    @State private var previousBPM: Double = 120.0
    @State private var bpmPulse: Bool = false
    @State private var recordPulse: Bool = false
    @State private var tapRippleTrigger: Int = 0
    @State private var panicShake: Double = 0
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            content(density: .expanded)
            content(density: .regular)
            content(density: .compact)
        }
        .padding(.horizontal, viewport.isCompactWidth ? 10 : 16)
        .padding(.vertical, 6)
        .frame(height: viewport.isCompactHeight ? 42 : 48)
        .background(XTheme.cardGradient)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 1)
        }
    }
    
    private enum BarDensity {
        case expanded, regular, compact
    }
    
    @ViewBuilder
    private func content(density: BarDensity) -> some View {
        @Bindable var state = appState
        let spacing: CGFloat = density == .compact ? 8 : (density == .regular ? 12 : 16)
        
        HStack(spacing: spacing) {
            // 1. Playback / Transport controls
            transportButtons(compact: density == .compact)
            
            divider()
            
            // 2. BPM & Tap Tempo
            bpmSection(compact: density == .compact)
            
            // 3. Middle selectors: Contextually show Key/Scale & Instrument on wider viewports
            if density == .expanded {
                divider()
                HStack(spacing: 8) {
                    KeySelectorView()
                    ScaleSelectorView()
                    TemperamentSelectorView()
                }
                
                divider()
                HStack(spacing: 8) {
                    InstrumentSelectorView(minWidth: 92)
                    ActiveTechniqueStatusView(compact: true)
                }
            } else if density == .regular {
                divider()
                HStack(spacing: 6) {
                    InstrumentSelectorView(minWidth: 80)
                    ActiveTechniqueStatusView(compact: true)
                }
            }
            
            divider()
            
            // 4. MIDI Activity & Wire Protocol
            midiSection(compact: density == .compact)
            
            // 5. Controller Status
            if density != .compact {
                divider()
                controllerStatusSection()
            }
            
            Spacer(minLength: 4)
            
            // 6. Master Volume & Mini Stereo VU Meter
            masterVolumeSection(sliderWidth: density == .compact ? 46 : (density == .regular ? 60 : 75))
            
            divider()
            
            // 7. Panic button
            panicButton()
        }
    }
    
    @ViewBuilder
    private func transportButtons(compact: Bool) -> some View {
        @Bindable var state = appState
        HStack(spacing: compact ? 4 : 6) {
            TransportButton(icon: "stop.fill", label: "Stop", isActive: false) {
                appState.stopActiveNotes()
                appState.isPlaying = false
            }
            
            TransportButton(icon: "play.fill", label: "Play", isActive: appState.isPlaying) {
                state.isPlaying.toggle()
            }
            .overlay {
                if appState.isPlaying {
                    RotatingArcOverlay(color: XTheme.primary)
                        .frame(width: 36, height: 36)
                        .allowsHitTesting(false)
                }
            }
            
            TransportButton(
                icon: "record.circle",
                label: "Record",
                isActive: appState.isRecording,
                activeColor: XTheme.recording
            ) {
                state.isRecording.toggle()
            }
            .xPulse(isActive: appState.isRecording, color: XTheme.recording, speed: 0.75, rings: 2)
            
            TransportButton(icon: "repeat", label: "Loop", isActive: appState.isLooping) {
                state.isLooping.toggle()
            }
        }
    }
    
    @ViewBuilder
    private func bpmSection(compact: Bool) -> some View {
        @Bindable var state = appState
        HStack(spacing: compact ? 4 : 6) {
            Button {
                state.metronomeEnabled.toggle()
            } label: {
                Image(systemName: "metronome")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(appState.metronomeEnabled ? XTheme.primary : XTheme.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(XTactileButtonStyle(isActive: appState.metronomeEnabled))
            .help(appState.metronomeEnabled ? "Disable metronome" : "Enable metronome")
            .accessibilityLabel("Metronome")
            .accessibilityValue(appState.metronomeEnabled ? "On" : "Off")
            .keyboardShortcut("k", modifiers: [])
            
            HStack(spacing: 2) {
                Text("\(Int(appState.bpm))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(XTheme.textPrimary)
                    .frame(width: 28)
                    .scaleEffect(bpmPulse ? 1.2 : 1.0)
                
                if !compact {
                    Text("BPM")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(XTheme.textTertiary)
                }
            }
            .onChange(of: appState.bpm) { _, newBPM in
                guard abs(newBPM - previousBPM) > 0.5 else { return }
                previousBPM = newBPM
                bpmPulse = true
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    bpmPulse = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    bpmPulse = false
                }
            }

            // Tap Tempo Button
            Button {
                tapRippleTrigger += 1
                registerTapTempo()
            } label: {
                Text("TAP")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(XTheme.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(XTheme.primary.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Tap tempo beat calculator")
            .xRipple(trigger: tapRippleTrigger, color: XTheme.primary, size: 36)
        }
    }
    
    @ViewBuilder
    private func midiSection(compact: Bool) -> some View {
        @Bindable var state = appState
        HStack(spacing: 5) {
            Circle()
                .fill(appState.midiEngine.isMIDIActive ? XTheme.midiActivity : XTheme.textTertiary.opacity(0.3))
                .frame(width: 6, height: 6)
                .xPulse(isActive: appState.midiEngine.isMIDIActive, color: XTheme.midiActivity, speed: 1.5)

            Menu {
                ForEach(MIDITransportProtocol.allCases) { transport in
                    Button {
                        state.midiEngine.transportProtocol = transport
                    } label: {
                        HStack {
                            Text(transport.rawValue)
                            if appState.midiEngine.transportProtocol == transport {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(appState.midiEngine.transportProtocol.shortLabel)
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                }
                .foregroundColor(appState.midiEngine.virtualMIDIEnabled ? XTheme.textPrimary : XTheme.textTertiary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("CoreMIDI virtual-source protocol")
            
            if !compact {
                Toggle("", isOn: $state.midiEngine.virtualMIDIEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.55)
                    .frame(width: 26)
                    .labelsHidden()
            }
        }
    }
    
    @ViewBuilder
    private func controllerStatusSection() -> some View {
        HStack(spacing: 5) {
            Image(systemName: appState.controllerManager.isConnected ? "gamecontroller.fill" : "gamecontroller")
                .font(.system(size: 11))
                .foregroundColor(appState.controllerManager.isConnected ? XTheme.controllerConnected : XTheme.controllerDisconnected)
            
            Text(appState.controllerManager.isConnected ? appState.controllerManager.controllerName : "Preview")
                .font(.system(size: 10))
                .foregroundColor(XTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 95)
        }
    }
    
    @ViewBuilder
    private func masterVolumeSection(sliderWidth: CGFloat) -> some View {
        HStack(spacing: 5) {
            // Interactive Mute Synth button with responsive XTheme styling
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.toggleSynthMute()
                }
            } label: {
                Image(systemName: appState.isSynthMuted ? "speaker.slash.fill" : (appState.audioEngine.volume > 0.5 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(appState.isSynthMuted ? XTheme.warning : XTheme.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(
                XTactileButtonStyle(
                    isActive: appState.isSynthMuted,
                    activeColor: XTheme.warning
                )
            )
            .help(appState.isSynthMuted ? "Unmute Built-in Synth" : "Mute Built-in Synth (Prioritizes MIDI/DAW Passthru)")
            .accessibilityLabel("Mute Synth")
            .accessibilityValue(appState.isSynthMuted ? "Muted" : "Active")
            .keyboardShortcut("m", modifiers: [])

            // Stereo Level Bars (dimmed when muted)
            VStack(spacing: 2) {
                levelBar(level: appState.isSynthMuted ? 0 : appState.virtualAudioDriver.levelMeter.linearLevelLeft)
                levelBar(level: appState.isSynthMuted ? 0 : appState.virtualAudioDriver.levelMeter.linearLevelRight)
            }
            .opacity(appState.isSynthMuted ? 0.35 : 1.0)

            // Volume Slider (dimmed when muted, un-mutes automatically when dragged)
            Slider(
                value: Binding(
                    get: { Double(appState.audioEngine.volume) },
                    set: {
                        appState.audioEngine.setVolume(Float($0))
                        if appState.isSynthMuted {
                            appState.setSynthMuted(false)
                        }
                    }
                ),
                in: 0.0...1.0
            )
            .tint(appState.isSynthMuted ? XTheme.textTertiary : XTheme.primary)
            .opacity(appState.isSynthMuted ? 0.45 : 1.0)
            .frame(width: sliderWidth)
            .help(appState.isSynthMuted ? "Synth is muted — Drag to unmute and adjust volume" : "Master Synthesizer Output Volume")
        }
    }
    
    @ViewBuilder
    private func panicButton() -> some View {
        Button {
            appState.panic()
            withAnimation(.interpolatingSpring(stiffness: 900, damping: 10)) {
                panicShake = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { panicShake = 0 }
        } label: {
            Image(systemName: "exclamationmark.octagon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(XTheme.tense)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(XTactileButtonStyle(activeColor: XTheme.tense))
        .help("MIDI Panic — All Notes Off")
        .rotationEffect(.degrees(panicShake == 0 ? 0 : panicShake > 0.5 ? 8 : -8))
        .animation(panicShake > 0 ? .interpolatingSpring(stiffness: 900, damping: 8) : .default, value: panicShake)
    }
    
    @ViewBuilder
    private func divider() -> some View {
        Divider()
            .frame(height: 18)
    }

    private func levelBar(level: Float) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.1))
                .frame(width: 38, height: 4)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [XTheme.emerald, level > 0.85 ? XTheme.tense : XTheme.primary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: CGFloat(max(0, min(1.0, level))) * 38, height: 4)
        }
    }

    private func registerTapTempo() {
        let now = Date()
        tapTimes.append(now)
        if tapTimes.count > 4 {
            tapTimes.removeFirst()
        }
        guard tapTimes.count >= 2 else { return }
        var intervals: [Double] = []
        for i in 1..<tapTimes.count {
            intervals.append(tapTimes[i].timeIntervalSince(tapTimes[i - 1]))
        }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        if avgInterval > 0.2 && avgInterval < 2.0 {
            let calculatedBPM = 60.0 / avgInterval
            appState.setBPM(calculatedBPM)
        }
    }
}

struct TransportButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var activeColor: Color = XTheme.primary
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippleTrigger = 0
    
    var body: some View {
        Button {
            if !reduceMotion { rippleTrigger += 1 }
            action()
        } label: {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isActive ? activeColor : XTheme.textSecondary)
                    .frame(width: 28, height: 28)
                if isActive && label == "Play" {
                    Circle()
                        .fill(activeColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                }
            }
        }
        .buttonStyle(XTactileButtonStyle(isActive: isActive, activeColor: activeColor))
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(isActive ? "On" : "Off")
        .xRipple(trigger: rippleTrigger, color: activeColor, size: 40)
    }
}

// MARK: - Rotating Arc Overlay

/// A thin partial-circle arc that rotates continuously, used behind the Play button
/// to signal live playback. Pure overlay — zero layout impact.
struct RotatingArcOverlay: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        if !reduceMotion {
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }
}
