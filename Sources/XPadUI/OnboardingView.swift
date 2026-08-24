import SwiftUI
import XPadCore
import XPadController

// MARK: - Onboarding Overlay

/// First-launch interactive tutorial that walks new users through the 5 key
/// concepts of XPadInput. Shown once; dismissed via "Get Started" or ⎋.
public struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var stepOpacity: Double = 1.0

    private static let steps: [OnboardingStep] = [
        .init(
            icon: "gamecontroller.fill",
            title: "Welcome to XPI",
            subtitle: "Your gamepad is now an MPE instrument",
            body: "XPadInput turns any Sony DualSense, Xbox, or Nintendo Switch Pro controller into a professional MIDI performance instrument with full polyphonic expression — no latency, no cables.",
            hint: "Connect your controller via USB or Bluetooth to begin.",
            accent: XTheme.primary
        ),
        .init(
            icon: "music.note",
            title: "Play Chords",
            subtitle: "Left stick + face buttons",
            body: "The left analog stick selects which diatonic chord to play. Sweep the right stick downward to strum — velocity follows your speed. L2/R2 add expression and vibrato.",
            hint: "Try tilting the left stick in any direction, then sweep the right stick.",
            accent: XTheme.accent
        ),
        .init(
            icon: "waveform.path",
            title: "MPE Expression",
            subtitle: "Every note is alive",
            body: "Triggers and gyroscope control per-note pitch bend (±48 semitones), pressure, and timbre in real time over MIDI Polyphonic Expression — all 16 member channels automatically managed.",
            hint: "Press L2 gently while holding a chord to add subtle vibrato.",
            accent: XTheme.expression
        ),
        .init(
            icon: "waveform.path.ecg",
            title: "Harmony Engine",
            subtitle: "Smart voice leading built in",
            body: "Change the Key and Scale from the header bar. The Harmony workspace shows the Circle of Fifths, chord suggestions, and smooth voice leading between any two chords.",
            hint: "Open the Harmony tab to explore the harmonic wheel.",
            accent: XTheme.colourful
        ),
        .init(
            icon: "puzzlepiece.extension.fill",
            title: "Install AU / VST3 Plugins",
            subtitle: "Ready for your DAW",
            body: "XPadInput can automatically place its Audio Unit and VST3 plugins into your system folders so Logic, Ableton, and other hosts discover them immediately.",
            hint: "Click the install button below, or skip and do this later.",
            accent: XTheme.primary
        ),
        .init(
            icon: "pianokeys",
            title: "Connect Your DAW",
            subtitle: "Virtual MIDI output ready",
            body: "Enable Virtual MIDI in the transport bar and XPI appears as a MIDI source in Ableton, Logic, GarageBand, and any CoreMIDI host. Use the built-in synth for zero-setup jamming.",
            hint: "Toggle the MIDI button in the bottom bar to go live.",
            accent: XTheme.midiActivity
        )
    ]

    public var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<Self.steps.count, id: \.self) { idx in
                        Capsule()
                            .fill(idx == currentStep ? XTheme.primary : XTheme.border)
                            .frame(width: idx == currentStep ? 24 : 8, height: 6)
                            .animation(XTheme.snappy, value: currentStep)
                    }
                }
                .padding(.top, 28)

                Spacer()

                // Step card
                let step = Self.steps[currentStep]
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(step.accent.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: step.icon)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(step.accent)
                    }

                    VStack(spacing: 6) {
                        Text(step.title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(XTheme.textPrimary)

                        Text(step.subtitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(step.accent)
                    }

                    Text(step.body)
                        .font(.system(size: 15))
                        .foregroundColor(XTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 440)

                    if step.title == "Install AU / VST3 Plugins" {
                        VStack(spacing: 8) {
                            Button(action: {
                                appState.installPlugins()
                            }) {
                                HStack {
                                    if appState.pluginInstallStatus == .installed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Plugins Installed")
                                    } else {
                                        Image(systemName: "arrow.down.app.fill")
                                        Text("Auto-Install Plugins")
                                    }
                                }
                            }
                            .buttonStyle(OnboardingSecondaryButtonStyle())
                            .disabled(appState.pluginInstallStatus == .installed)

                            if case .failed(let errorMsg) = appState.pluginInstallStatus {
                                Text(errorMsg)
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 400)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Hint pill
                    Label(step.hint, systemImage: "lightbulb.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(XTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(XTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: XTheme.radiusMedium)
                                .stroke(XTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusMedium))
                        .frame(maxWidth: 440)
                }
                .opacity(stepOpacity)
                .padding(.horizontal, 32)

                Spacer()

                // Navigation
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("← Back") { advance(by: -1) }
                            .buttonStyle(OnboardingSecondaryButtonStyle())
                    }
                    Spacer()
                    Button {
                        appState.completeOnboarding()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(XTheme.textTertiary)
                    }
                    .buttonStyle(.plain)

                    if currentStep < Self.steps.count - 1 {
                        Button("Next →") { advance(by: 1) }
                            .buttonStyle(OnboardingPrimaryButtonStyle())
                    } else {
                        Button("Get Started") { appState.completeOnboarding() }
                            .buttonStyle(OnboardingPrimaryButtonStyle())
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 560, maxHeight: 480)
            .background(
                RoundedRectangle(cornerRadius: XTheme.radiusLarge)
                    .fill(XTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: XTheme.radiusLarge)
                            .stroke(XTheme.border, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 40)
            .padding(24)
        }
        .onKeyPress(.escape) {
            appState.completeOnboarding()
            return .handled
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .animation(XTheme.springAnimation, value: currentStep)
    }

    private func advance(by delta: Int) {
        withAnimation(XTheme.feedbackFast) { stepOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            currentStep = max(0, min(Self.steps.count - 1, currentStep + delta))
            withAnimation(XTheme.glassIn) { stepOpacity = 1 }
        }
    }
}

// MARK: - Step model

private struct OnboardingStep {
    let icon: String
    let title: String
    let subtitle: String
    let body: String
    let hint: String
    let accent: Color
}

// MARK: - Button styles

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(XTheme.primary)
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(XTheme.feedbackFast, value: configuration.isPressed)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(XTheme.textSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(XTheme.surface)
                    .overlay(Capsule().stroke(XTheme.border, lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(XTheme.feedbackFast, value: configuration.isPressed)
    }
}
