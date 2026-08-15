import SwiftUI
import XPadCore
import XPadTheory
import XPadController
import XPadMIDI
import XPadAudio

public struct PlayWorkspaceView: View {
    @ObservedObject var controllerManager: ControllerManager
    @Binding var currentScale: Scale
    @State private var playMode: InstrumentPlayMode = .chords
    @State private var activeWheelLayer: WheelLayer = .diatonic
    @State private var strumVelocityDisplay: UInt8 = 0
    @State private var lastStrumDirection: StrumDirection?
    @State private var vibratingStringIndex: Int?
    
    // Performance state
    @State private var activeChord: Chord?
    @State private var activeVoicedNotes: [Note] = []

    private let strummer = VirtualStrummer()
    private let rhythmCompass = RhythmCompassEngine()
    private let voiceLeading = VoiceLeadingEngine()

    public init(controllerManager: ControllerManager, currentScale: Binding<Scale>) {
        self.controllerManager = controllerManager
        self._currentScale = currentScale
    }

    private var wheel: HarmonicWheel {
        HarmonicWheel(scale: currentScale)
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Instrument Mode Switcher
            Picker("Play Mode", selection: $playMode) {
                ForEach(InstrumentPlayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 500)
            .padding(.top, 8)

            switch playMode {
            case .chords:
                chordStrummerLayout
            case .drums:
                rhythmCompassLayout
            case .bass:
                bassInstrumentLayout
            case .melody:
                melodyInstrumentLayout
            }
        }
        .padding(20)
        .onReceive(controllerManager.$currentState) { state in
            handleGamepadState(state)
        }
    }

    // MARK: - Chord Strummer Layout
    private var chordStrummerLayout: some View {
        HStack(spacing: 30) {
            // Left: Harmonic Compass / Wheel
            VStack(spacing: 12) {
                HStack {
                    Text("Harmonic Compass (Left Stick)")
                        .font(.headline)
                    Spacer()
                    Picker("Layer", selection: $activeWheelLayer) {
                        ForEach(WheelLayer.allCases) { layer in
                            Text(layer.rawValue).tag(layer)
                        }
                    }
                    .pickerStyle(.menu)
                }

                harmonicWheelCanvas
                    .frame(width: 320, height: 320)
                    .background(Circle().fill(Color.black.opacity(0.2)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))

                if let chord = activeChord {
                    VStack(spacing: 4) {
                        Text(chord.symbol)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                        Text(chord.pitchClasses.map { $0.standardName }.joined(separator: " - "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Material.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Right: Virtual Strumming Surface
            VStack(spacing: 16) {
                HStack {
                    Text("Virtual Strummer (Right Stick)")
                        .font(.headline)
                    Spacer()
                    if let dir = lastStrumDirection {
                        Text(dir.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                // Virtual Strings Display
                VStack(spacing: 14) {
                    ForEach(0..<6) { stringIndex in
                        HStack(spacing: 12) {
                            Text("S\(6 - stringIndex)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(vibratingStringIndex == stringIndex ? Color.cyan : Color.white.opacity(0.2))
                                    .frame(height: vibratingStringIndex == stringIndex ? 4 : 2)
                                    .shadow(color: vibratingStringIndex == stringIndex ? .cyan : .clear, radius: 6)

                                if vibratingStringIndex == stringIndex {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 100)
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxHeight: 200)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Velocity & Trigger Mute Gauges
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Strum Velocity: \(strumVelocityDisplay)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ProgressView(value: Double(strumVelocityDisplay), total: 127.0)
                            .tint(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Palm Mute (L2/R2): \(Int(controllerManager.currentState.leftTrigger * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ProgressView(value: controllerManager.currentState.leftTrigger, total: 1.0)
                            .tint(.orange)
                    }
                }

                // Audition Strum Button (for mouse/trackpad users)
                Button {
                    triggerAuditionStrum()
                } label: {
                    HStack {
                        Image(systemName: "hand.draw.fill")
                        Text("Audition Strum (Space / Right Stick Down)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Material.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Harmonic Wheel Canvas
    private var harmonicWheelCanvas: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let radius = min(size.width, size.height) / 2.0 - 10

            guard let sectors = wheel.sectorsByLayer[activeWheelLayer] else { return }
            let sectorAngle = (2.0 * .pi) / Double(sectors.count)

            for (index, sector) in sectors.enumerated() {
                let startAngle = Angle(radians: sector.angle - sectorAngle / 2.0)
                let endAngle = Angle(radians: sector.angle + sectorAngle / 2.0)

                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                path.closeSubpath()

                let isSelected = activeChord?.symbol == sector.chord.symbol
                let fillColor = isSelected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.06)

                context.fill(path, with: .color(fillColor))
                context.stroke(path, with: .color(Color.white.opacity(0.15)), lineWidth: 1)

                // Draw Text Label
                let midAngle = sector.angle
                let textRadius = radius * 0.65
                let textPos = CGPoint(
                    x: center.x + CGFloat(cos(midAngle)) * textRadius,
                    y: center.y + CGFloat(sin(midAngle)) * textRadius
                )

                let label = "\(sector.romanNumeral)\n\(sector.chord.symbol)"
                let text = Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                context.draw(context.resolve(text), at: textPos, anchor: .center)
            }

            // Draw Left Stick Cursor
            let stick = controllerManager.currentState.leftStick
            if stick.isActive {
                let stickPos = CGPoint(
                    x: center.x + CGFloat(stick.x) * radius * 0.85,
                    y: center.y - CGFloat(stick.y) * radius * 0.85 // Flip Y for graphics coordinate
                )
                let cursorPath = Path(ellipseIn: CGRect(x: stickPos.x - 8, y: stickPos.y - 8, width: 16, height: 16))
                context.fill(cursorPath, with: .color(Color.cyan))
                context.stroke(cursorPath, with: .color(Color.white), lineWidth: 2)
            }
        }
    }

    // MARK: - Rhythm Compass Layout
    private var rhythmCompassLayout: some View {
        VStack(spacing: 20) {
            Text("Rhythm Compass: Rotate Left Stick to Select Subdivisions")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 300, height: 300)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))

                ForEach(Array(RhythmicSubdivision.allCases.enumerated()), id: \.offset) { index, sub in
                    let angle = Double(index) * (.pi / 4.0) - (.pi / 2.0)
                    let x = 110.0 * cos(angle)
                    let y = 110.0 * sin(angle)

                    VStack(spacing: 2) {
                        Text(sub.rawValue)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(8)
                    .background(Material.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .offset(x: x, y: y)
                }

                // Center stick indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .offset(
                        x: CGFloat(controllerManager.currentState.leftStick.x) * 100,
                        y: -CGFloat(controllerManager.currentState.leftStick.y) * 100
                    )
            }
            .frame(width: 320, height: 320)
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Bass & Melody Placeholders
    private var bassInstrumentLayout: some View {
        VStack(spacing: 12) {
            Text("Bassline Instrument")
                .font(.headline)
            Text("Left Stick selects scale degrees / chord roots. Face buttons trigger Root, 5th, 3rd, 7th.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var melodyInstrumentLayout: some View {
        VStack(spacing: 12) {
            Text("Melody Lead Instrument")
                .font(.headline)
            Text("Scale-locked melodic improvisation. Triggers shift register; face buttons trigger scale neighbours.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Gamepad State Processing
    private func handleGamepadState(_ state: GamepadState) {
        // 1. Left Stick selects chord from wheel
        if state.leftStick.isActive {
            if let sector = wheel.sector(forAngle: state.leftStick.angle, layer: activeWheelLayer) {
                if activeChord?.symbol != sector.chord.symbol {
                    activeChord = sector.chord
                    activeVoicedNotes = voiceLeading.optimizeTransition(
                        from: activeVoicedNotes,
                        to: sector.chord,
                        strategy: .smooth
                    )
                }
            }
        } else if activeChord == nil {
            // Default to tonic chord of scale
            let defaultSector = wheel.sectorsByLayer[.diatonic]?.first
            activeChord = defaultSector?.chord
            activeVoicedNotes = defaultSector?.chord.voicedNotes() ?? []
        }

        // 2. Right Stick strums chord
        let strum = strummer.processStick(
            x: state.rightStick.x,
            y: state.rightStick.y,
            triggerMute: state.leftTrigger,
            chordNotes: activeVoicedNotes
        )

        if let strum = strum {
            lastStrumDirection = strum.direction
            strumVelocityDisplay = strum.velocity
            playStrummedNotes(strum.notes)
        }
    }

    private func triggerAuditionStrum() {
        if activeVoicedNotes.isEmpty {
            activeVoicedNotes = activeChord?.voicedNotes() ?? [Note.c4]
        }
        let notes = activeVoicedNotes.enumerated().map { index, note in
            StrummedNote(note: note, velocity: 100, delayMs: Double(index) * 15.0, stringIndex: index)
        }
        lastStrumDirection = .down
        strumVelocityDisplay = 100
        playStrummedNotes(notes)
    }

    private func playStrummedNotes(_ notes: [StrummedNote]) {
        for (idx, strummed) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (strummed.delayMs / 1000.0)) {
                vibratingStringIndex = idx
                // Audio Engine
                AudioEngine.shared.noteOn(note: strummed.note.midiNumber, velocity: strummed.velocity)
                // CoreMIDI
                MIDIManager.shared.sendNoteOn(port: .chords, channel: 0, note: strummed.note.midiNumber, velocity: strummed.velocity)

                // Note off release after 1.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    AudioEngine.shared.noteOff(note: strummed.note.midiNumber)
                    MIDIManager.shared.sendNoteOff(port: .chords, channel: 0, note: strummed.note.midiNumber)
                    if vibratingStringIndex == idx {
                        vibratingStringIndex = nil
                    }
                }
            }
        }
    }
}
