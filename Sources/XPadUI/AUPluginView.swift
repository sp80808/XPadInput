import SwiftUI
import XPadCore
import XPadTheory
import XPadAudio
import XPadMIDI

/// Compact, premium DAW plugin interface for AUv3 / VST3 windows.
public struct AUPluginView: View {
    @State private var keyRoot: PitchClass = .d
    @State private var currentScale: Scale = .naturalMinor
    @State private var voiceLeadingStrategy: VoiceLeadingStrategy = .smooth
    @State private var filterCutoff: Double = 2800.0
    @State private var filterResonance: Double = 0.25
    @State private var saturation: Double = 0.1
    @State private var reverbMix: Double = 10.0
    @State private var mpeBendRange: Double = 48.0
    @State private var activeNotes: Set<UInt8> = []
    
    private let voiceLeadingEngine = VoiceLeadingEngine()
    @State private var previousVoicing: [Note] = []
    
    public init() {}
    
    private var diatonicChords: [Chord] {
        Chord.diatonicChords(root: keyRoot, scale: currentScale)
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "pianokeys.inverse")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(XTheme.primary)
                    Text("XPI: Game Controller MIDI")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(XTheme.textPrimary)
                    Text("AUv3 / VST3")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(XTheme.primary.opacity(0.2))
                        .foregroundColor(XTheme.primary)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(XTheme.stable)
                            .frame(width: 7, height: 7)
                        Text("MPE Ready (±\(Int(mpeBendRange))st)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(XTheme.textSecondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 11))
                            .foregroundColor(XTheme.primary)
                        Text("CoreAudio HAL")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(XTheme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Theory & Chords Row
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Key Selector
                    Menu {
                        ForEach(PitchClass.allCases, id: \.self) { pc in
                            Button(pc.displayName) { keyRoot = pc }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Key: \(keyRoot.displayName)")
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(XTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    // Scale Selector
                    Menu {
                        ForEach(ScaleType.allCases, id: \.self) { st in
                            Button(st.rawValue.capitalized) { currentScale = Scale(root: keyRoot, type: st) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentScale.type.rawValue.capitalized)
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(XTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    // Voice Leading Strategy
                    Menu {
                        ForEach(VoiceLeadingStrategy.allCases, id: \.self) { strategy in
                            Button(strategy.rawValue) { voiceLeadingStrategy = strategy }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Voice Leading: \(voiceLeadingStrategy.rawValue)")
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(XTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                }
                
                // Diatonic Chord Triggers
                HStack(spacing: 8) {
                    ForEach(Array(diatonicChords.enumerated()), id: \.offset) { index, chord in
                        Button {
                            triggerChord(chord)
                        } label: {
                            VStack(spacing: 2) {
                                Text(romanNumeral(for: index + 1))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(XTheme.primary)
                                Text(chord.symbol)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(XTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(XTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(XTheme.primary.opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Synth & DSP Controls Grid
            HStack(spacing: 16) {
                // Filter Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("FILTER & DRIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(XTheme.textTertiary)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cutoff: \(Int(filterCutoff)) Hz")
                                .font(.system(size: 10))
                                .foregroundColor(XTheme.textSecondary)
                            Slider(value: $filterCutoff, in: 100...12000)
                                .tint(XTheme.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Res: \(Int(filterResonance * 100))%")
                                .font(.system(size: 10))
                                .foregroundColor(XTheme.textSecondary)
                            Slider(value: $filterResonance, in: 0...0.9)
                                .tint(XTheme.expression)
                        }
                    }
                }
                .padding(10)
                .background(XTheme.surface.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Effects Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("MASTER FX")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(XTheme.textTertiary)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Drive: \(Int(saturation * 100))%")
                                .font(.system(size: 10))
                                .foregroundColor(XTheme.textSecondary)
                            Slider(value: $saturation, in: 0...1.0)
                                .tint(XTheme.tense)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reverb: \(Int(reverbMix))%")
                                .font(.system(size: 10))
                                .foregroundColor(XTheme.textSecondary)
                            Slider(value: $reverbMix, in: 0...50)
                                .tint(XTheme.primary)
                        }
                    }
                }
                .padding(10)
                .background(XTheme.surface.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .frame(minWidth: 620, minHeight: 340)
        .background(XTheme.background)
    }
    
    private func triggerChord(_ chord: Chord) {
        let voiced: [Note]
        if !previousVoicing.isEmpty {
            voiced = voiceLeadingEngine.optimizeTransition(from: previousVoicing, to: chord, strategy: voiceLeadingStrategy)
        } else {
            voiced = chord.voicedNotes(baseOctave: 3)
        }
        previousVoicing = voiced
        
        let notes = voiced.map { $0.midiNumber }
        for note in notes {
            AudioEngine.shared.noteOn(note: note, velocity: 100)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            for note in notes {
                AudioEngine.shared.noteOff(note: note)
            }
        }
    }
    
    private func romanNumeral(for degree: Int) -> String {
        switch degree {
        case 1: return "I"
        case 2: return "ii"
        case 3: return "iii"
        case 4: return "IV"
        case 5: return "V"
        case 6: return "vi"
        case 7: return "vii°"
        default: return "\(degree)"
        }
    }
}
