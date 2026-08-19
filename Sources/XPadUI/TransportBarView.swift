import SwiftUI
import XPadCore
import XPadController
import XPadMIDI
import XPadAudio

/// Persistent transport bar with playback, key/scale, BPM, and status indicators.
struct TransportBar: View {
    @Environment(AppState.self) private var appState
    @State private var tapTimes: [Date] = []
    @State private var previousBPM: Double = 120.0
    @State private var bpmPulse: Bool = false
    
    var body: some View {
        @Bindable var state = appState
        
        HStack(spacing: 16) {
            // Transport controls
            HStack(spacing: 6) {
                TransportButton(icon: "stop.fill", label: "Stop", isActive: false) {
                    appState.stopActiveNotes()
                    appState.isPlaying = false
                }
                
                TransportButton(icon: "play.fill", label: "Play", isActive: appState.isPlaying) {
                    state.isPlaying.toggle()
                }
                
                TransportButton(
                    icon: "record.circle",
                    label: "Record",
                    isActive: appState.isRecording,
                    activeColor: XTheme.recording
                ) {
                    state.isRecording.toggle()
                }
                .overlay(
                    Group {
                        if appState.isRecording {
                            Circle()
                                .fill(XTheme.recording.opacity(0.4))
                                .frame(width: 40, height: 40)
                                .scaleEffect(bpmPulse ? 1.3 : 1.0)
                                .opacity(bpmPulse ? 0 : 1)
                        }
                    }
                )
                .onChange(of: appState.isRecording) { _, isRecording in
                    guard isRecording else { bpmPulse = false; return }
                    bpmPulse = true
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        bpmPulse = false
                    }
                }
                
                TransportButton(icon: "repeat", label: "Loop", isActive: appState.isLooping) {
                    state.isLooping.toggle()
                }
            }
            
            Divider()
                .frame(height: 20)
            
            // BPM & Tap Tempo
            HStack(spacing: 6) {
                Button {
                    state.metronomeEnabled.toggle()
                } label: {
                    Image(systemName: "metronome")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(appState.metronomeEnabled ? XTheme.primary : XTheme.textTertiary)
                        .frame(width: 25, height: 25)
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
                        .frame(width: 32)
                        .scaleEffect(bpmPulse && !appState.isRecording ? 1.15 : 1.0)
                    
                    Text("BPM")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(XTheme.textTertiary)
                }
                .onChange(of: appState.bpm) { _, newBPM in
                    guard abs(newBPM - previousBPM) > 0.5 else { return }
                    previousBPM = newBPM
                    bpmPulse = true
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                        bpmPulse = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        bpmPulse = false
                    }
                }

                // Tap Tempo Button
                Button {
                    registerTapTempo()
                } label: {
                    Text("TAP")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(XTheme.primary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(XTheme.primary.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Tap tempo beat calculator")
            }
            
            Divider()
                .frame(height: 20)

            HStack(spacing: 8) {
                KeySelectorView()
                ScaleSelectorView()
            }
            
            Divider()
                .frame(height: 20)

            HStack(spacing: 8) {
                InstrumentSelectorView(minWidth: 92)
                ActiveTechniqueStatusView(compact: true)
            }

            Divider()
                .frame(height: 20)
            
            // MIDI activity and wire protocol.
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.midiEngine.isMIDIActive ? XTheme.midiActivity : XTheme.textTertiary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .xGlow(isActive: appState.midiEngine.isMIDIActive, color: XTheme.midiActivity)
                    .scaleEffect(appState.midiEngine.isMIDIActive ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: appState.midiEngine.isMIDIActive)

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
                
                Toggle("", isOn: $state.midiEngine.virtualMIDIEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.6)
                    .frame(width: 30)
                    .labelsHidden()
            }
            
            Divider()
                .frame(height: 20)
            
            // Controller status
            HStack(spacing: 6) {
                Image(systemName: appState.controllerManager.isConnected ? "gamecontroller.fill" : "gamecontroller")
                    .font(.system(size: 11))
                    .foregroundColor(appState.controllerManager.isConnected ? XTheme.controllerConnected : XTheme.controllerDisconnected)
                
                Text(appState.controllerManager.controllerName)
                    .font(.system(size: 10))
                    .foregroundColor(XTheme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 110)
            }

            Spacer()

            // Master Volume & Mini Stereo VU Meter
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(XTheme.textTertiary)

                // Stereo Level Bars
                VStack(spacing: 2) {
                    levelBar(level: appState.virtualAudioDriver.levelMeter.linearLevelLeft)
                    levelBar(level: appState.virtualAudioDriver.levelMeter.linearLevelRight)
                }

                // Volume Slider
                Slider(
                    value: Binding(
                        get: { Double(appState.audioEngine.volume) },
                        set: { appState.audioEngine.setVolume(Float($0)) }
                    ),
                    in: 0.0...1.0
                )
                .tint(XTheme.primary)
                .frame(width: 65)
                .help("Master Synthesizer Output Volume")
            }

            Divider()
                .frame(height: 20)
            
            // Panic button
            Button {
                appState.panic()
            } label: {
                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(XTheme.tense)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(XTactileButtonStyle(activeColor: XTheme.tense))
            .help("MIDI Panic — All Notes Off")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 48)
        .background(XTheme.cardGradient)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 1)
        }
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
    
    var body: some View {
        Button(action: action) {
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
    }
}
