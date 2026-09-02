import SwiftUI
import XPadCore
import XPadController

// MARK: - Ways to Play Gallery

/// Library-workspace section cataloguing every built-in control scheme as a
/// one-tap "way to play". Applying a scheme mirrors the Control Scheme
/// workspace flow (copy → persist → activate) and reveals a mini cheat-sheet
/// of the scheme's most important bindings.
public struct WaysToPlayGallery: View {
    @Environment(AppState.self) private var appState
    @State private var activeSchemeID: String = ""
    @State private var justAppliedID: String?

    private let presets = ControlSchemePreset.allBuiltIn

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ways to Play")
                    .font(.headline)
                Spacer()
                Text("\(presets.count) schemes")
                    .font(.caption.monospaced())
                    .foregroundColor(XTheme.primary)
            }

            Text("One tap switches the entire control surface. Each card lists its three most important bindings once applied.")
                .font(.caption)
                .foregroundColor(XTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
                ForEach(presets) { preset in
                    WayToPlayCard(
                        preset: preset,
                        isActive: activeSchemeID == preset.id,
                        isExpanded: justAppliedID == preset.id || (justAppliedID == nil && activeSchemeID == preset.id),
                        onApply: { apply(preset) }
                    )
                }
            }
        }
        .onAppear { activeSchemeID = appState.controllerManager.activeScheme.id }
    }

    private func apply(_ preset: ControlScheme) {
        let copy = preset.makeCustomCopy()
        ControllerSettingsStore.shared.saveCustomScheme(copy)
        appState.controllerManager.selectControlScheme(copy)
        ControllerSettingsStore.shared.saveActiveSchemeId(copy.id)
        activeSchemeID = copy.id
        justAppliedID = copy.id
    }
}

// MARK: - Card

private struct WayToPlayCard: View {
    @Environment(AppState.self) private var appState
    let preset: ControlScheme
    let isActive: Bool
    let isExpanded: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: Self.icon(for: preset.id))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(XTheme.primary)
                    .frame(width: 32, height: 32)
                    .background(XTheme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(XTheme.textPrimary)
                        .lineLimit(1)
                    if isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(XTheme.success)
                    }
                }
                Spacer()
            }

            Text(preset.description)
                .font(.system(size: 10.5))
                .foregroundColor(XTheme.textSecondary)
                .lineLimit(2)
                .frame(minHeight: 26, alignment: .top)

            if isExpanded {
                cheatSheet
            }

            HStack {
                Spacer()
                if isActive {
                    Label("In Use", systemImage: "waveform")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(XTheme.success)
                } else {
                    Button("Apply") { onApply() }
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(XTheme.primary)
                }
            }
        }
        .padding(11)
        .background(XTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(
                isActive ? XTheme.success.opacity(0.5) : XTheme.border,
                lineWidth: 1
            )
        )
    }

    /// Top-3 bindings: critical actions first, then recommended.
    private var cheatSheet: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(topBindings, id: \.action) { pair in
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 8))
                        .foregroundColor(XTheme.textTertiary)
                    Text(pair.control)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(XTheme.primary)
                    Spacer()
                    Text(pair.action)
                        .font(.system(size: 9.5))
                        .foregroundColor(XTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(XTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var topBindings: [(control: String, action: String)] {
        let ordered = ControlScheme.criticalActions + ControlScheme.recommendedActions
        return ordered.compactMap { action in
            guard let binding = preset.binding(for: action), binding.input != .unassigned else { return nil }
            return (binding.input.rawValue, action.displayName)
        }
        .prefix(3)
        .map { $0 }
    }

    static func icon(for schemeID: String) -> String {
        switch schemeID {
        case ControlSchemePreset.xpiPerformance.id: "bolt.waveform"
        case ControlSchemePreset.xpiClassic.id: "gamecontroller.fill"
        case ControlSchemePreset.lowFatigue.id: "leaf.fill"
        case ControlSchemePreset.leftHandedPerformance.id: "arrow.left.arrow.right.circle.fill"
        case ControlSchemePreset.oneHandLeft.id: "hand.raised.fill"
        case ControlSchemePreset.oneHandRight.id: "hand.raised.fill"
        case ControlSchemePreset.arcadeFightStick.id: "joystick.fill"
        case ControlSchemePreset.racingWheelCruise.id: "steeringwheel.fill"
        case ControlSchemePreset.flightDeckHOTAS.id: "airplane"
        case ControlSchemePreset.rhythmPadCompact.id: "metronome.fill"
        case ControlSchemePreset.fingerDrummer.id: "drum.fill"
        case ControlSchemePreset.bassGrooveLab.id: "guitars.fill"
        case ControlSchemePreset.ambientDrift.id: "cloud.fill"
        case ControlSchemePreset.gyroTheremin.id: "antenna.radiowaves.left.and.right"
        case ControlSchemePreset.turntablistChops.id: "circle.hexagongrid.fill"
        case ControlSchemePreset.firstTimer.id: "sparkles"
        default: "slider.horizontal.3"
        }
    }
}
