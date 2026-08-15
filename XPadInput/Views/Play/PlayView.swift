import SwiftUI

/// The main Play workspace - gamepad instrument mode.
struct PlayView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left panel: Harmonic wheel + chord info
                VStack(spacing: 16) {
                    // Current chord display
                    ChordDisplayView()
                    
                    // Harmonic wheel
                    HarmonicWheelView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Active notes display
                    ActiveNotesView()
                }
                .padding(20)
                .frame(width: geo.size.width * 0.55)
                
                Divider()
                    .background(XTheme.border)
                
                // Right panel: Controller visualiser + strum info
                VStack(spacing: 16) {
                    ControllerVisualizerView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    StrumIndicatorView()
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Chord Display

struct ChordDisplayView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 16) {
            // Chord name
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentChord?.displayName ?? "—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.textPrimary)
                    .contentTransition(.numericText())
                
                if let chord = appState.currentChord {
                    HStack(spacing: 8) {
                        if let roman = chord.romanNumeral(in: appState.currentKey, scale: appState.currentScale) {
                            Text(roman)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(XTheme.primary)
                        }
                        
                        let tension = chord.tension(in: appState.currentKey, scale: appState.currentScale)
                        TensionBadge(tension: tension)
                    }
                }
            }
            
            Spacer()
            
            // Key & Scale
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(appState.currentKey.displayName) \(appState.currentScale.name)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(XTheme.textSecondary)
                
                Text("Modifier: \(appState.controllerManager.controllerState.activeModifier.rawValue)")
                    .font(.system(size: 11))
                    .foregroundColor(XTheme.textTertiary)
            }
        }
        .padding(16)
        .xCard(isActive: appState.currentChord != nil)
    }
}

struct TensionBadge: View {
    let tension: Double
    
    var label: String {
        if tension < 0.15 { return "Stable" }
        if tension < 0.3 { return "Natural" }
        if tension < 0.5 { return "Colourful" }
        if tension < 0.7 { return "Adventurous" }
        return "Outside"
    }
    
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(XTheme.tensionColor(tension))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(XTheme.tensionColor(tension).opacity(0.15))
            )
    }
}

// MARK: - Active Notes

struct ActiveNotesView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(appState.activeNotes, id: \.midiNote) { note in
                Text(note.displayName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(XTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(XTheme.primary.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(XTheme.primary.opacity(0.4), lineWidth: 1)
                            )
                    )
                    .transition(.scale.combined(with: .opacity))
            }
            
            if appState.activeNotes.isEmpty {
                Text("No notes playing")
                    .font(.caption)
                    .foregroundColor(XTheme.textTertiary)
            }
            
            Spacer()
        }
        .animation(XTheme.quickAnimation, value: appState.activeNotes.map(\.midiNote))
        .padding(12)
        .xCard()
    }
}

// MARK: - Strum Indicator

struct StrumIndicatorView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 20) {
            // Strum direction
            VStack(spacing: 4) {
                Image(systemName: appState.lastStrumDirection == .down ? "arrow.down" :
                        appState.lastStrumDirection == .up ? "arrow.up" : "minus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(appState.lastStrumDirection != .none ? XTheme.accent : XTheme.textTertiary)
                    .xGlow(isActive: appState.lastStrumDirection != .none)
                
                Text("Strum")
                    .font(.caption2)
                    .foregroundColor(XTheme.textTertiary)
            }
            
            // Velocity bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(XTheme.surface)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(XTheme.primaryGradient)
                                .frame(width: geo.size.width * CGFloat(appState.lastVelocity) / 127.0)
                        }
                }
                .frame(width: 100, height: 8)
                
                Text("Vel: \(appState.lastVelocity)")
                    .font(.caption2)
                    .foregroundColor(XTheme.textTertiary)
            }
            
            Spacer()
        }
        .padding(12)
        .xCard()
    }
}
