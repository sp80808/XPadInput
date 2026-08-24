import SwiftUI
import XPadAudio
import XPadCore
import XPadController

/// Compact, performance-safe disclosure for the controls that shape a live take.
struct PerformanceQuickControlsView: View {
    @Environment(AppState.self) private var appState
    @State private var showsGate = false
    @State private var showsVelocity = false
    @State private var showsArp = false
    @State private var showsTriggers = false
    @State private var showsEQ = false
    @State private var showsCompressor = false
    @State private var showsReverb = false
    @State private var soloOffset: CGFloat = 0
    @State private var duoFlip: Double = 0
    @State private var gateWiggle: Double = 0
    @State private var velocityWiggle: Double = 0
    @State private var arpWiggle: Double = 0
    @State private var triggerWiggle: Double = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            controls(compact: false)
            controls(compact: true)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                .fill(XTheme.surface.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                        .stroke(XTheme.border, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
    }

    private func controls(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 7) {
            Button { showsGate.toggle(); wiggle { gateWiggle = $0 } } label: {
                QuickControlLabel(
                    icon: "timer",
                    title: compact ? "Gate" : "Chord gate",
                    value: gateValue,
                    compact: compact
                )
            }
            .buttonStyle(XTactileButtonStyle(isActive: appState.chordGateConfiguration.mode != .momentary))
            .popover(isPresented: $showsGate, arrowEdge: .bottom) {
                ChordGatePopover()
            }
            .help("Choose how played chords release")
            .rotationEffect(.degrees(gateWiggle))

            Button { showsVelocity.toggle(); wiggle { velocityWiggle = $0 } } label: {
                QuickControlLabel(
                    icon: "dial.medium",
                    title: compact ? "Feel" : "Velocity",
                    value: appState.audioEngine.velocityCurve.rawValue,
                    compact: compact
                )
            }
            .buttonStyle(XTactileButtonStyle())
            .popover(isPresented: $showsVelocity, arrowEdge: .bottom) {
                VelocityPopover()
            }
            .help("Shape and stabilize performance velocity")
            .rotationEffect(.degrees(velocityWiggle))

            Button {
                let next: DuoPerformanceMode = appState.duoPerformanceMode == .instrumentOnly
                    ? .drumsAndInstrument
                    : .instrumentOnly
                appState.setDuoPerformanceMode(next)
                withAnimation(XTheme.bouncy) { duoFlip += 180 }
            } label: {
                QuickControlLabel(
                    icon: "square.grid.2x2.fill",
                    title: "Duo",
                    value: compact ? nil : (appState.duoPerformanceMode == .drumsAndInstrument ? "Drums on" : "Off"),
                    compact: compact
                )
                .rotation3DEffect(.degrees(duoFlip), axis: (x: 0, y: 1, z: 0))
            }
            .buttonStyle(
                XTactileButtonStyle(
                    isActive: appState.duoPerformanceMode == .drumsAndInstrument,
                    activeColor: XTheme.warning
                )
            )
            .help("Duo: A kick, X snare, Y closed hat, B open hat; both sticks remain on the instrument")
            .accessibilityValue(appState.duoPerformanceMode.rawValue)

            Button {
                withAnimation(XTheme.springAnimation) {
                    appState.isSoloModeActive.toggle()
                }
                if appState.isSoloModeActive {
                    withAnimation(XTheme.bouncy) { soloOffset = -3 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(XTheme.bouncy) { soloOffset = 0 }
                    }
                }
            } label: {
                QuickControlLabel(
                    icon: "guitars.fill",
                    title: "Solo",
                    value: compact ? nil : (appState.isSoloModeActive ? "Lead on" : "Strum"),
                    compact: compact
                )
                .offset(y: soloOffset)
            }
            .buttonStyle(
                XTactileButtonStyle(
                    isActive: appState.isSoloModeActive,
                    activeColor: .orange
                )
            )
            .help("Smart Soloing: Right stick locks to chord tones, passing runs, and blues inflections")

            Button { showsArp.toggle(); wiggle { arpWiggle = $0 } } label: {
                QuickControlLabel(
                    icon: "waveform.path.ecg",
                    title: "Arp",
                    value: compact ? nil : (appState.selectedPlayMode == .arp ? appState.arpeggiatorConfiguration.pattern.rawValue : "Off"),
                    compact: compact
                )
            }
            .buttonStyle(
                XTactileButtonStyle(
                    isActive: appState.selectedPlayMode == .arp,
                    activeColor: XTheme.accent
                )
            )
            .popover(isPresented: $showsArp, arrowEdge: .bottom) {
                ArpeggiatorPopover()
            }
            .help("Arpeggiator: Step chord tones to BPM across customizable patterns and octaves")
            .rotationEffect(.degrees(arpWiggle))

            Button { showsTriggers.toggle(); wiggle { triggerWiggle = $0 } } label: {
                QuickControlLabel(
                    icon: "hand.tap.fill",
                    title: compact ? "Trig" : "Triggers",
                    value: compact ? nil : appState.controllerManager.adaptiveTriggerEngine.leftConfig.mode.displayName,
                    compact: compact
                )
            }
            .buttonStyle(XTactileButtonStyle(isActive: appState.controllerManager.adaptiveTriggerEngine.isEnabled))
            .popover(isPresented: $showsTriggers, arrowEdge: .bottom) {
                AdaptiveTriggerQuickPopover()
            }
            .help("DualSense motor resistance, string tension and mod-wheel detents")
            .rotationEffect(.degrees(triggerWiggle))

            Button {
                withAnimation(XTheme.springAnimation) {
                    appState.toggleSynthMute()
                }
            } label: {
                QuickControlLabel(
                    icon: appState.isSynthMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    title: "Synth",
                    value: compact ? nil : (appState.isSynthMuted ? "Muted" : "On"),
                    compact: compact
                )
            }
            .buttonStyle(
                XTactileButtonStyle(
                    isActive: appState.isSynthMuted,
                    activeColor: XTheme.warning
                )
            )
            .help(appState.isSynthMuted ? "Synth muted — MIDI passthru prioritized" : "Mute built-in synthesizer")

            Spacer(minLength: compact ? 2 : 8)

            Button { showsEQ.toggle() } label: {
                QuickControlLabel(
                    icon: "slider.horizontal.3",
                    title: "EQ",
                    value: compact ? nil : effectState(appState.audioEngine.effectsSettings.equalizer.isEnabled),
                    compact: compact
                )
            }
            .buttonStyle(XTactileButtonStyle(isActive: appState.audioEngine.effectsSettings.equalizer.isEnabled))
            .popover(isPresented: $showsEQ, arrowEdge: .bottom) {
                EqualizerPopover()
            }

            Button { showsCompressor.toggle() } label: {
                QuickControlLabel(
                    icon: "waveform.path.ecg",
                    title: compact ? "Comp" : "Compressor",
                    value: compact ? nil : effectState(appState.audioEngine.effectsSettings.compressor.isEnabled),
                    compact: compact
                )
            }
            .buttonStyle(XTactileButtonStyle(isActive: appState.audioEngine.effectsSettings.compressor.isEnabled))
            .popover(isPresented: $showsCompressor, arrowEdge: .bottom) {
                CompressorPopover()
            }

            Button { showsReverb.toggle() } label: {
                QuickControlLabel(
                    icon: "dot.radiowaves.left.and.right",
                    title: compact ? "Verb" : "Reverb",
                    value: compact ? nil : "\(Int(appState.audioEngine.effectsSettings.reverb.mixPercent))%",
                    compact: compact
                )
            }
            .buttonStyle(XTactileButtonStyle(isActive: appState.audioEngine.effectsSettings.reverb.isEnabled))
            .popover(isPresented: $showsReverb, arrowEdge: .bottom) {
                ReverbPopover()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var gateValue: String {
        if appState.chordGateConfiguration.mode == .timed {
            return String(format: "%.2fs", appState.chordGateConfiguration.timedDuration)
        }
        return appState.chordGateConfiguration.mode.rawValue
    }

    private func effectState(_ enabled: Bool) -> String {
        enabled ? "On" : "Off"
    }

    /// Fires a ±5° wiggle oscillation on the given setter closure.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func wiggle(_ setAngle: @escaping (Double) -> Void) {
        guard !reduceMotion else { return }
        let seq: [Double] = [5, -5, 3, -3, 0]
        var delay = 0.0
        for deg in seq {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { setAngle(deg) }
            delay += 0.06
        }
    }
}

private struct QuickControlLabel: View {
    let icon: String
    let title: String
    let value: String?
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                if let value, !compact {
                    Text(value)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(XTheme.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .foregroundColor(XTheme.textSecondary)
        .padding(.horizontal, compact ? 8 : 10)
        .frame(minWidth: compact ? 44 : 70, minHeight: 38)
        .contentShape(RoundedRectangle(cornerRadius: XTheme.radiusSmall))
    }
}

private struct ChordGatePopover: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TactilePopoverShell(
            title: "Chord release",
            subtitle: "Keep chords musical without leaving notes stuck."
        ) {
            Picker("Release mode", selection: Binding(
                get: { appState.chordGateConfiguration.mode },
                set: { appState.setChordHoldMode($0) }
            )) {
                ForEach(ChordHoldMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if appState.chordGateConfiguration.mode == .timed {
                TactileSliderRow(
                    title: "Length",
                    value: String(format: "%.2f s", appState.chordGateConfiguration.timedDuration),
                    valueBinding: Binding(
                        get: { appState.chordGateConfiguration.timedDuration },
                        set: { appState.setChordTimedDuration($0) }
                    ),
                    range: 0.10...4.0,
                    step: 0.05
                )
            }

            Text(gateDescription)
                .font(.system(size: 10))
                .foregroundColor(XTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gateDescription: String {
        switch appState.chordGateConfiguration.mode {
        case .momentary: "Hold the strum gesture to sustain; return the stick to release."
        case .timed: "Each strum releases automatically after the chosen length."
        case .latch: "Strum once to hold; strum the same chord again to release."
        }
    }
}

private struct VelocityPopover: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TactilePopoverShell(
            title: "Velocity feel",
            subtitle: "Stabilizes controller variation before it reaches the synth or DAW."
        ) {
            Picker("Velocity curve", selection: Binding(
                get: { appState.audioEngine.velocityCurve },
                set: { appState.setVelocityCurve($0) }
            )) {
                ForEach(SynthVelocityCurve.allCases) { curve in
                    Text(curve.rawValue).tag(curve)
                }
            }
            .pickerStyle(.segmented)

            Text(velocityDescription)
                .font(.system(size: 10))
                .foregroundColor(XTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var velocityDescription: String {
        switch appState.audioEngine.velocityCurve {
        case .balanced: "Evenly controlled attacks with enough dynamic movement for expressive playing."
        case .expressive: "Wider dynamics and quicker response to intentional changes."
        case .even: "The tightest level range for consistent chords and drums."
        }
    }
}

private struct EqualizerPopover: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TactilePopoverShell(title: "Equalizer", subtitle: "Three broad musical tone controls.") {
            effectToggle("EQ", isOn: Binding(
                get: { appState.audioEngine.effectsSettings.equalizer.isEnabled },
                set: { value in update { $0.isEnabled = value } }
            ))
            TactileFloatSliderRow(title: "Low", suffix: "dB", value: floatBinding(\.lowGainDB), range: -12...12)
            TactileFloatSliderRow(title: "Mid", suffix: "dB", value: floatBinding(\.midGainDB), range: -12...12)
            TactileFloatSliderRow(title: "High", suffix: "dB", value: floatBinding(\.highGainDB), range: -12...12)
        }
    }

    private func floatBinding(_ keyPath: WritableKeyPath<SynthEqualizerSettings, Float>) -> Binding<Float> {
        Binding(
            get: { appState.audioEngine.effectsSettings.equalizer[keyPath: keyPath] },
            set: { value in update { $0[keyPath: keyPath] = value } }
        )
    }

    private func update(_ change: (inout SynthEqualizerSettings) -> Void) {
        var settings = appState.audioEngine.effectsSettings.equalizer
        change(&settings)
        appState.audioEngine.setEqualizer(settings)
    }
}

private struct CompressorPopover: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TactilePopoverShell(title: "Compressor", subtitle: "Smooths peaks while keeping attacks tactile.") {
            effectToggle("Compressor", isOn: Binding(
                get: { appState.audioEngine.effectsSettings.compressor.isEnabled },
                set: { value in update { $0.isEnabled = value } }
            ))
            TactileFloatSliderRow(title: "Threshold", suffix: "dB", value: floatBinding(\.thresholdDB), range: -40 ... -1)
            TactileFloatSliderRow(title: "Makeup", suffix: "dB", value: floatBinding(\.makeupGainDB), range: -6...12)
            TactileFloatSliderRow(title: "Release", suffix: "ms", value: floatBinding(\.releaseMilliseconds), range: 20...500)
        }
    }

    private func floatBinding(_ keyPath: WritableKeyPath<SynthCompressorSettings, Float>) -> Binding<Float> {
        Binding(
            get: { appState.audioEngine.effectsSettings.compressor[keyPath: keyPath] },
            set: { value in update { $0[keyPath: keyPath] = value } }
        )
    }

    private func update(_ change: (inout SynthCompressorSettings) -> Void) {
        var settings = appState.audioEngine.effectsSettings.compressor
        change(&settings)
        appState.audioEngine.setCompressor(settings)
    }
}

private struct ReverbPopover: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TactilePopoverShell(title: "Reverb", subtitle: "A restrained space after dynamics processing.") {
            effectToggle("Reverb", isOn: Binding(
                get: { appState.audioEngine.effectsSettings.reverb.isEnabled },
                set: { value in update { $0.isEnabled = value } }
            ))
            Picker("Space", selection: Binding(
                get: { appState.audioEngine.effectsSettings.reverb.style },
                set: { value in update { $0.style = value } }
            )) {
                ForEach(SynthReverbStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            TactileFloatSliderRow(title: "Mix", suffix: "%", value: floatBinding(\.mixPercent), range: 0...35)
        }
    }

    private func floatBinding(_ keyPath: WritableKeyPath<SynthReverbSettings, Float>) -> Binding<Float> {
        Binding(
            get: { appState.audioEngine.effectsSettings.reverb[keyPath: keyPath] },
            set: { value in update { $0[keyPath: keyPath] = value } }
        )
    }

    private func update(_ change: (inout SynthReverbSettings) -> Void) {
        var settings = appState.audioEngine.effectsSettings.reverb
        change(&settings)
        appState.audioEngine.setReverb(settings)
    }
}

private struct TactilePopoverShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(XTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(XTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(16)
        .frame(width: 310)
        .background(XTheme.surface)
    }
}

private struct TactileSliderRow: View {
    let title: String
    let value: String
    let valueBinding: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(XTheme.primaryLight)
            }
            .font(.system(size: 10, weight: .medium))
            Slider(value: valueBinding, in: range, step: step)
                .tint(XTheme.primary)
        }
    }
}

private struct TactileFloatSliderRow: View {
    let title: String
    let suffix: String
    let value: Binding<Float>
    let range: ClosedRange<Float>

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue, specifier: "%.1f") \(suffix)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(XTheme.primaryLight)
            }
            .font(.system(size: 10, weight: .medium))
            Slider(value: value, in: range)
                .tint(XTheme.primary)
        }
    }
}

@ViewBuilder
private func effectToggle(_ title: String, isOn: Binding<Bool>) -> some View {
    Toggle(title, isOn: isOn)
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.system(size: 11, weight: .semibold))
}

// MARK: - Adaptive Trigger Quick Popover

private struct AdaptiveTriggerQuickPopover: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(XTheme.primary)
                Text("Adaptive Motor Resistance")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.controllerManager.adaptiveTriggerEngine.isEnabled },
                    set: { appState.controllerManager.adaptiveTriggerEngine.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            Divider()

            // Mode Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Trigger Resistance Mode")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(XTheme.textSecondary)

                Picker("", selection: Binding(
                    get: { appState.controllerManager.adaptiveTriggerEngine.leftConfig.mode },
                    set: { mode in
                        appState.controllerManager.adaptiveTriggerEngine.leftConfig.mode = mode
                        appState.controllerManager.adaptiveTriggerEngine.rightConfig.mode = mode
                    }
                )) {
                    ForEach(AdaptiveTriggerMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }

            // String Gauge (if guitar mode)
            if appState.controllerManager.adaptiveTriggerEngine.leftConfig.mode == .guitarStringTension {
                VStack(alignment: .leading, spacing: 6) {
                    Text("String Gauge Tension")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(XTheme.textSecondary)

                    Picker("", selection: Binding(
                        get: { appState.controllerManager.adaptiveTriggerEngine.leftConfig.stringGauge },
                        set: { gauge in
                            appState.controllerManager.adaptiveTriggerEngine.leftConfig.stringGauge = gauge
                            appState.controllerManager.adaptiveTriggerEngine.rightConfig.stringGauge = gauge
                        }
                    )) {
                        ForEach(StringGauge.allCases, id: \.self) { gauge in
                            Text(gauge.displayName).tag(gauge)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Resistive Strength
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Motor Force Strength")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(XTheme.textSecondary)
                    Spacer()
                    Text("\(Int(appState.controllerManager.adaptiveTriggerEngine.leftConfig.resistiveStrength * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(XTheme.primary)
                }
                Slider(
                    value: Binding(
                        get: { appState.controllerManager.adaptiveTriggerEngine.leftConfig.resistiveStrength },
                        set: {
                            appState.controllerManager.adaptiveTriggerEngine.leftConfig.resistiveStrength = $0
                            appState.controllerManager.adaptiveTriggerEngine.rightConfig.resistiveStrength = $0
                        }
                    ),
                    in: 0.1...1.0
                )
                .tint(XTheme.primary)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}

private struct ArpeggiatorPopover: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TactilePopoverShell(
            title: "Arpeggiator",
            subtitle: "Sequence chord tones in real-time synced to transport BPM."
        ) {
            Toggle("Enable Arpeggiator", isOn: Binding(
                get: { appState.selectedPlayMode == .arp },
                set: { appState.setPlayMode($0 ? .arp : .chords) }
            ))
            .toggleStyle(.switch)
            .tint(XTheme.accent)

            Divider().background(XTheme.border)

            Picker("Pattern", selection: Binding(
                get: { appState.arpeggiatorConfiguration.pattern },
                set: {
                    var updated = appState.arpeggiatorConfiguration
                    updated.pattern = $0
                    appState.updateArpeggiatorConfiguration(updated)
                }
            )) {
                ForEach(ArpeggiatorPattern.allCases) { pattern in
                    Label(pattern.rawValue, systemImage: pattern.iconName).tag(pattern)
                }
            }
            .pickerStyle(.menu)

            Picker("Rate", selection: Binding(
                get: { appState.arpeggiatorConfiguration.rate },
                set: {
                    var updated = appState.arpeggiatorConfiguration
                    updated.rate = $0
                    appState.updateArpeggiatorConfiguration(updated)
                }
            )) {
                ForEach(ArpeggiatorRate.allCases) { rate in
                    Text(rate.rawValue).tag(rate)
                }
            }
            .pickerStyle(.segmented)

            Stepper(
                "Octaves: \(appState.arpeggiatorConfiguration.octaveRange)",
                value: Binding(
                    get: { appState.arpeggiatorConfiguration.octaveRange },
                    set: {
                        var updated = appState.arpeggiatorConfiguration
                        updated.octaveRange = $0
                        appState.updateArpeggiatorConfiguration(updated)
                    }
                ),
                in: 1...4
            )

            TactileSliderRow(
                title: "Gate length",
                value: "\(Int(appState.arpeggiatorConfiguration.gateLength * 100))%",
                valueBinding: Binding(
                    get: { appState.arpeggiatorConfiguration.gateLength },
                    set: {
                        var updated = appState.arpeggiatorConfiguration
                        updated.gateLength = $0
                        appState.updateArpeggiatorConfiguration(updated)
                    }
                ),
                range: 0.1...1.0,
                step: 0.05
            )

            Toggle("Latch Held Chord", isOn: Binding(
                get: { appState.arpeggiatorConfiguration.isLatched },
                set: {
                    var updated = appState.arpeggiatorConfiguration
                    updated.isLatched = $0
                    appState.updateArpeggiatorConfiguration(updated)
                }
            ))
            .toggleStyle(.switch)
            .tint(XTheme.accent)
        }
        .padding(14)
        .frame(width: 290)
    }
}


