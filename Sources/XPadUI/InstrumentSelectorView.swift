import SwiftUI
import XPadCore

/// Compact instrument selector shared by the performance surface and transport bar.
///
/// SwiftUI's default menu picker is intentionally avoided here: on macOS it
/// renders a comparatively large native control and also exposes the picker
/// title inline, which clashes with XPI's compact custom control language.
struct InstrumentSelectorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var minWidth: CGFloat = 92

    var body: some View {
        Menu {
            ForEach(InstrumentProfile.playableProfiles, id: \.family) { profile in
                Button {
                    appState.setInstrument(profile)
                } label: {
                    if profile.family == appState.instrumentProfile.family {
                        Label(profile.family.shortName, systemImage: "checkmark")
                    } else {
                        Text(profile.family.shortName)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(appState.instrumentProfile.family.shortName)
                    .font(XTheme.controlLabelFont)
                    .foregroundColor(XTheme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isHovering ? XTheme.textSecondary : XTheme.textTertiary)
            }
            .padding(.horizontal, 10)
            .frame(minWidth: minWidth, minHeight: 28, maxHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                    .fill(isHovering ? AnyShapeStyle(XTheme.surfaceHover) : AnyShapeStyle(XTheme.controlGradient))
                    .overlay(
                        RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                            .stroke(
                                isHovering ? XTheme.borderActive.opacity(0.55) : Color.white.opacity(0.10),
                                lineWidth: XTheme.strokeSubtle
                            )
                    )
                    .shadow(color: Color.black.opacity(0.20), radius: 3, y: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: XTheme.radiusSmall))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: false)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : XTheme.quickAnimation, value: isHovering)
        .help("Choose performance instrument")
        .accessibilityLabel("Instrument")
        .accessibilityValue(appState.instrumentProfile.family.shortName)
    }
}

/// Shows expressive state only when it adds information beyond the selected
/// instrument name. This prevents labels such as "Guitar" being duplicated
/// beside or beneath the selector when no technique is active.
struct ActiveTechniqueStatusView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var compact: Bool = false

    var body: some View {
        if let technique = appState.activeTechniqueLabel {
            Text(technique)
                .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                .foregroundColor(XTheme.accent)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, compact ? 6 : 8)
                .padding(.vertical, compact ? 2 : 3)
                .background(
                    Capsule()
                        .fill(XTheme.accent.opacity(0.10))
                        .overlay(
                            Capsule()
                                .stroke(XTheme.accent.opacity(0.24), lineWidth: 1)
                        )
                )
                .animation(reduceMotion ? nil : XTheme.quickAnimation, value: technique)
                .transition(reduceMotion ? .identity : .scale(scale: 0.85, anchor: .center).combined(with: .opacity))
                .accessibilityLabel("Active technique")
                .accessibilityValue(technique)
        }
    }
}
