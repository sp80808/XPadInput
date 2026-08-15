import SwiftUI

/// Persistent transport bar with playback, key/scale, BPM, and status indicators.
struct TransportBar: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        HStack(spacing: 16) {
            // Transport controls
            HStack(spacing: 6) {
                TransportButton(icon: "stop.fill", isActive: false) {
                    appState.stopActiveNotes()
                    appState.isPlaying = false
                }
                
                TransportButton(icon: "play.fill", isActive: appState.isPlaying) {
                    state.isPlaying.toggle()
                }
                
                TransportButton(
                    icon: "record.circle",
                    isActive: appState.isRecording,
                    activeColor: XTheme.recording
                ) {
                    state.isRecording.toggle()
                }
                
                TransportButton(icon: "repeat", isActive: appState.isLooping) {
                    state.isLooping.toggle()
                }
            }
            
            Divider()
                .frame(height: 20)
            
            // BPM
            HStack(spacing: 4) {
                Image(systemName: "metronome")
                    .font(.system(size: 11))
                    .foregroundColor(appState.metronomeEnabled ? XTheme.primary : XTheme.textTertiary)
                    .onTapGesture {
                        state.metronomeEnabled.toggle()
                    }
                
                Text("\(Int(appState.bpm))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(XTheme.textPrimary)
                    .frame(width: 32)
                
                Text("BPM")
                    .font(.system(size: 9))
                    .foregroundColor(XTheme.textTertiary)
            }
            
            Divider()
                .frame(height: 20)
            
            // Key selector
            HStack(spacing: 6) {
                Text("Key")
                    .font(.system(size: 9))
                    .foregroundColor(XTheme.textTertiary)
                
                Picker("Key", selection: $state.currentKey) {
                    ForEach(PitchClass.allCases, id: \.self) { pc in
                        Text(pc.displayName).tag(pc)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 55)
                .onChange(of: appState.currentKey) { _, newKey in
                    appState.setKey(newKey)
                }
            }
            
            // Scale selector
            HStack(spacing: 6) {
                Picker("Scale", selection: Binding(
                    get: { appState.currentScale.id },
                    set: { id in
                        if let scale = Scale.allScales.first(where: { $0.id == id }) {
                            appState.setScale(scale)
                        }
                    }
                )) {
                    ForEach(Scale.allScales) { scale in
                        Text(scale.name).tag(scale.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            
            Divider()
                .frame(height: 20)
            
            // MIDI activity
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.midiEngine.isMIDIActive ? XTheme.midiActivity : XTheme.textTertiary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .xGlow(isActive: appState.midiEngine.isMIDIActive, color: XTheme.midiActivity)
                
                Text("MIDI")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(appState.midiEngine.virtualMIDIEnabled ? XTheme.textPrimary : XTheme.textTertiary)
                
                Toggle("", isOn: $state.midiEngine.virtualMIDIEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.6)
                    .frame(width: 30)
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
                    .frame(maxWidth: 120)
            }
            
            Spacer()
            
            // Panic button
            Button {
                appState.midiEngine.panic()
                appState.audioEngine.allNotesOff()
                appState.activeNotes.removeAll()
            } label: {
                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 12))
                    .foregroundColor(XTheme.tense)
            }
            .buttonStyle(.plain)
            .help("MIDI Panic — All Notes Off")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 40)
        .background(XTheme.surface)
    }
}

struct TransportButton: View {
    let icon: String
    let isActive: Bool
    var activeColor: Color = XTheme.primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? activeColor : XTheme.textSecondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isActive ? activeColor.opacity(0.15) : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}
