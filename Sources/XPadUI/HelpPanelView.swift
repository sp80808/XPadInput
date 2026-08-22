import SwiftUI
import XPadCore

// MARK: - Help Panel

/// Slide-in reference panel. Opened via the ? button in the header or ⌘?.
/// Contains five sections: Controls Map, Music Theory, MIDI Setup,
/// Troubleshooting, and Keyboard Shortcuts.
public struct HelpPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedSection: HelpSection = .controls

    public var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(XTheme.primary)
                Text("Help")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(XTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation(XTheme.glassIn) { appState.showHelpPanel = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(XTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(XTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Close Help (⌘?)")
                .keyboardShortcut("/", modifiers: [.command])
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(XTheme.surfaceElevated)

            Divider().background(XTheme.border)

            // ── Search ──────────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(XTheme.textTertiary)
                TextField("Search help…", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundColor(XTheme.textPrimary)
                    .tint(XTheme.primary)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(XTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(XTheme.surface)

            Divider().background(XTheme.border)

            HStack(spacing: 0) {
                // ── Section Nav ─────────────────────────────────────────────
                if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(HelpSection.allCases) { section in
                            Button {
                                withAnimation(XTheme.snappy) { selectedSection = section }
                            } label: {
                                Label(section.title, systemImage: section.icon)
                                    .font(.system(size: 12, weight: selectedSection == section ? .semibold : .regular))
                                    .foregroundColor(selectedSection == section ? XTheme.primary : XTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedSection == section
                                        ? XTheme.primary.opacity(0.12)
                                        : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .frame(width: 150)
                    .background(XTheme.surface.opacity(0.5))

                    Divider().background(XTheme.border)
                }

                // ── Content ─────────────────────────────────────────────────
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if searchText.isEmpty {
                            helpContent(for: selectedSection)
                        } else {
                            searchResults(query: searchText.lowercased())
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(width: 480)
        .background(XTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: XTheme.radiusLarge)
                .stroke(XTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24)
        .onKeyPress(.escape) {
            withAnimation(XTheme.glassIn) { appState.showHelpPanel = false }
            return .handled
        }
    }

    // MARK: - Content Builders

    @ViewBuilder
    private func helpContent(for section: HelpSection) -> some View {
        switch section {
        case .controls:     controlsContent()
        case .theory:       theoryContent()
        case .midi:         midiContent()
        case .troubleshoot: troubleshootContent()
        case .shortcuts:    shortcutsContent()
        }
    }

    @ViewBuilder
    private func searchResults(query: String) -> some View {
        let matches = HelpEntry.all.filter {
            $0.title.lowercased().contains(query) || $0.body.lowercased().contains(query)
        }
        if matches.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(XTheme.textTertiary)
                Text("No results for \"\(searchText)\"")
                    .font(.system(size: 13))
                    .foregroundColor(XTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            ForEach(matches) { entry in
                HelpEntryRow(entry: entry)
            }
        }
    }

    // MARK: - Section: Controls Map

    @ViewBuilder
    private func controlsContent() -> some View {
        helpHeader("Controller Map")
        controlRow(icon: "l.joystick.fill",  label: "Left Stick",    desc: "Navigate chord index up/down/left/right within the diatonic set")
        controlRow(icon: "r.joystick.fill",  label: "Right Stick ↓", desc: "Strum down — velocity tracks sweep speed")
        controlRow(icon: "r.joystick.fill",  label: "Right Stick ↑", desc: "Strum up")
        controlRow(icon: "l2.button.roundedtop.horizontal.fill", label: "L2", desc: "Pitch bend / vibrato depth (MPE)")
        controlRow(icon: "r2.button.roundedtop.horizontal.fill", label: "R2", desc: "Pressure / timbre expression (MPE CC74)")
        controlRow(icon: "l1.button.roundedtop.horizontal.fill", label: "L1", desc: "Octave down (hold) / Palm mute (tap)")
        controlRow(icon: "r1.button.roundedtop.horizontal.fill", label: "R1", desc: "Octave up (hold) / Harmonic (tap)")
        controlRow(icon: "dpad.up.fill",     label: "D-Pad ↑",       desc: "Voicing inversion up")
        controlRow(icon: "dpad.down.fill",   label: "D-Pad ↓",       desc: "Voicing inversion down")
        controlRow(icon: "dpad.left.fill",   label: "D-Pad ←",       desc: "Previous chord / progression back")
        controlRow(icon: "dpad.right.fill",  label: "D-Pad →",       desc: "Next chord / progression forward")
        controlRow(icon: "circle.fill",      label: "○ / B",         desc: "Individual chord tone: root")
        controlRow(icon: "cross.fill",       label: "✕ / A",         desc: "Chord tone: third")
        controlRow(icon: "square.fill",      label: "□ / X",         desc: "Chord tone: fifth")
        controlRow(icon: "triangle.fill",    label: "△ / Y",         desc: "Chord tone: seventh (extension)")
        controlRow(icon: "option",           label: "Options",        desc: "Toggle Solo Mode")
        controlRow(icon: "square.grid.2x2.fill", label: "Touchpad / Center", desc: "Panic — all notes off")

        helpHeader("Performance Tips")
        tipRow("Hold L1 + Strum for palm-muted percussive strumming")
        tipRow("Sweep right stick slowly for arpeggiated plucks, fast for strums")
        tipRow("Use L2 while sustaining for gentle pitch sag or vibrato")
        tipRow("Hold multiple face buttons simultaneously for chord-tone soloing")
    }

    // MARK: - Section: Music Theory

    @ViewBuilder
    private func theoryContent() -> some View {
        helpHeader("Scale & Key")
        textRow("Select a root key (e.g. D) and scale type (e.g. Natural Minor) in the header. XPI automatically derives all seven diatonic chords and voice-leading paths.")
        textRow("Tap the ← → transpose buttons next to the key selector to shift the entire performance up or down by a semitone without interrupting the current chord voicings.")

        helpHeader("Harmony Workspace")
        textRow("The Harmonic Wheel visualises keys on the Circle of Fifths. Green arcs show stable, closely-related chords. Orange shows colour chords. Red indicates tension.")
        textRow("Chord Suggestions show the three most harmonically plausible next chords based on voice-leading distance and scale function.")
        textRow("Progression Builder lets you arrange diatonic chords into a loop and trigger them in sequence from the D-Pad.")

        helpHeader("MPE Expression")
        textRow("XPI uses MIDI Polyphonic Expression: each note gets its own MIDI channel. Pitch bend, pressure, and timbre are applied independently per note — identical to a Roli Seaboard or Linnstrument.")
        textRow("Bend range is configurable per destination profile (default ±48 semitones for internal synth, ±2 for standard MIDI).")
        textRow("Microtonal temperaments (Equal, Pythagorean, Just, Meantone) pre-tune each note at note-on via a per-channel pitch bend.")
    }

    // MARK: - Section: MIDI Setup

    @ViewBuilder
    private func midiContent() -> some View {
        helpHeader("Virtual MIDI Output")
        textRow("Enable \"Virtual MIDI\" in the transport bar. XPI creates six CoreMIDI virtual sources: Main, Chords, Melody, Bass, Drums, and Expression (MPE).")
        textRow("In your DAW, arm a track on any of those sources. XPI sends full MPE on the Expression port, and lane-split MIDI 1 on the others.")

        helpHeader("MIDI Protocol")
        textRow("Use MIDI 1 for maximum compatibility. Use MIDI 2 UMP for 32-bit precision on hosts that support it (currently: Apple Logic Pro, some Korg hardware).")
        textRow("MIDI-CI session negotiation happens automatically when a CI-capable device is detected on the XPI Input port.")

        helpHeader("DAW-Specific Notes")
        textRow("Ableton Live: Create a MIDI track, set input to \"XPI Expression (MPE)\" and enable Track and Remote. Go to Preferences → MIDI and mark the device as MPE-enabled.")
        textRow("Logic Pro: XPI is auto-detected. Set the instrument to a Polyphonic Modulation-capable plug-in (e.g. Alchemy) to receive per-note CC74.")
        textRow("GarageBand: Use the XPI Main port. MPE expression is flattened to channel pressure and pitch bend automatically.")
    }

    // MARK: - Section: Troubleshooting

    @ViewBuilder
    private func troubleshootContent() -> some View {
        helpHeader("No Sound")
        textRow("1. Check the volume slider in the transport bar and verify the synth is not muted (speaker icon).")
        textRow("2. Verify the audio engine is running — it auto-starts on launch. If it failed, a banner appears in the header.")
        textRow("3. Check macOS System Settings → Sound → Output is set to the correct device.")

        helpHeader("Controller Not Detected")
        textRow("Use USB for lowest latency and most reliable detection. If Bluetooth: ensure the controller is paired in macOS Bluetooth preferences first.")
        textRow("Try \"Rescan Controllers\" (⌘⇧R) from the menu bar icon. If the controller still doesn't appear, unplug/replug or re-pair.")
        textRow("DualSense requires macOS 12.3+ and the latest firmware from PlayStation. Xbox controllers need macOS 11.3+.")

        helpHeader("Stuck Notes")
        textRow("Press the Panic button (⚠ in the transport bar, or ⌘⇧.) to send MIDI All Notes Off on every channel and port simultaneously.")

        helpHeader("High Latency")
        textRow("XPI targets <5 ms input-to-audio. Ensure no other apps are claiming the audio device exclusively. Reduce the buffer size in System Settings → Sound → Output if your device supports it.")
        textRow("Disable unneeded reverb and spatial audio effects in the FX and Spatial tabs — each adds processing load.")
    }

    // MARK: - Section: Keyboard Shortcuts

    @ViewBuilder
    private func shortcutsContent() -> some View {
        helpHeader("Transport")
        shortcutRow("Space", "Play / Pause")
        shortcutRow("⌘.", "Stop + All Notes Off (Panic)")
        shortcutRow("⌘⇧.", "MIDI Panic (⚠ button)")
        shortcutRow("K", "Toggle Metronome")
        shortcutRow("M", "Toggle Synth Mute")

        helpHeader("Navigation")
        shortcutRow("⌘O", "Bring window to front")
        shortcutRow("⌘⇧R", "Rescan controllers")
        shortcutRow("⌘?", "Open / Close this Help panel")

        helpHeader("Transpose")
        shortcutRow("⌥↑", "Transpose key up 1 semitone")
        shortcutRow("⌥↓", "Transpose key down 1 semitone")
        shortcutRow("⌥⇧↑", "Octave up (strum lane)")
        shortcutRow("⌥⇧↓", "Octave down (strum lane)")

        helpHeader("Workspaces")
        shortcutRow("⌘1", "Play workspace")
        shortcutRow("⌘2", "Harmony workspace")
        shortcutRow("⌘3", "Sequence workspace")
        shortcutRow("⌘4", "Map workspace")
        shortcutRow("⌘5", "Library workspace")
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func helpHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(XTheme.primary)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func controlRow(icon: String, label: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(XTheme.textSecondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(XTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(XTheme.textSecondary)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func textRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(XTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 3)
    }

    @ViewBuilder
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 10))
                .foregroundColor(XTheme.accent)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(XTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func shortcutRow(_ keys: String, _ action: String) -> some View {
        HStack(spacing: 10) {
            Text(keys)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(XTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(XTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(XTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .frame(minWidth: 60, alignment: .center)
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(XTheme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Help Section Enum

public enum HelpSection: String, CaseIterable, Identifiable {
    case controls    = "Controls"
    case theory      = "Music Theory"
    case midi        = "MIDI Setup"
    case troubleshoot = "Troubleshooting"
    case shortcuts   = "Shortcuts"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var icon: String {
        switch self {
        case .controls:     return "gamecontroller.fill"
        case .theory:       return "music.note"
        case .midi:         return "cable.connector"
        case .troubleshoot: return "wrench.and.screwdriver"
        case .shortcuts:    return "keyboard"
        }
    }
}

// MARK: - Searchable Entry model

struct HelpEntry: Identifiable {
    let id = UUID()
    let section: HelpSection
    let title: String
    let body: String

    static let all: [HelpEntry] = [
        .init(section: .controls,     title: "Left Stick",       body: "Navigate chord index up/down/left/right within the diatonic set"),
        .init(section: .controls,     title: "Right Stick Strum", body: "Sweep down to strum, up for up-strum. Velocity tracks sweep speed."),
        .init(section: .controls,     title: "L2 / R2",          body: "L2 pitch bend vibrato depth. R2 pressure and timbre CC74 MPE."),
        .init(section: .controls,     title: "L1 Octave / Mute", body: "Octave down hold, palm mute tap"),
        .init(section: .controls,     title: "R1 Octave / Harm", body: "Octave up hold, harmonic tap"),
        .init(section: .controls,     title: "Face Buttons",     body: "Individual chord tones: ○/B=root, ✕/A=third, □/X=fifth, △/Y=seventh"),
        .init(section: .controls,     title: "D-Pad",            body: "Inversion up/down and chord navigation"),
        .init(section: .theory,       title: "Scale & Key",      body: "Select root key and scale type in header. Transpose ± with arrow buttons."),
        .init(section: .theory,       title: "Harmony Workspace", body: "Circle of Fifths wheel, chord suggestions, progression builder"),
        .init(section: .theory,       title: "MPE Expression",   body: "Per-note pitch bend pressure and timbre on independent MIDI channels"),
        .init(section: .midi,         title: "Virtual MIDI",     body: "Enable Virtual MIDI in transport bar. Six CoreMIDI sources appear in DAW."),
        .init(section: .midi,         title: "MIDI 2 UMP",       body: "32-bit precision on MIDI 2 hosts like Logic Pro"),
        .init(section: .midi,         title: "Ableton Setup",    body: "MIDI track input XPI Expression MPE. Enable MPE in Preferences."),
        .init(section: .troubleshoot, title: "No Sound",         body: "Check volume slider, mute button, and macOS system audio output."),
        .init(section: .troubleshoot, title: "Controller Not Detected", body: "Rescan with ⌘⇧R. Bluetooth requires macOS pairing first."),
        .init(section: .troubleshoot, title: "Stuck Notes / Panic", body: "Press ⚠ panic button or ⌘⇧. to send All Notes Off."),
        .init(section: .troubleshoot, title: "High Latency",     body: "Close other audio apps, reduce buffer size, disable spatial audio FX."),
        .init(section: .shortcuts,    title: "Keyboard Shortcuts", body: "Space play, M mute, K metronome, ⌘? help, ⌘⇧. panic"),
    ]
}

struct HelpEntryRow: View {
    let entry: HelpEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: entry.section.icon)
                    .font(.system(size: 10))
                    .foregroundColor(XTheme.primary)
                Text(entry.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(XTheme.textPrimary)
            }
            Text(entry.body)
                .font(.system(size: 11))
                .foregroundColor(XTheme.textSecondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        Divider().background(XTheme.border)
    }
}
