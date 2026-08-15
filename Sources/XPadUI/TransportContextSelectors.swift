import SwiftUI
import XPadCore

/// Compact XPI-themed key selector for the persistent transport bar.
struct KeySelectorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            ForEach(PitchClass.allCases, id: \.self) { pitchClass in
                Button {
                    appState.setKey(pitchClass)
                } label: {
                    if pitchClass == appState.currentKey {
                        Label(pitchClass.displayName, systemImage: "checkmark")
                    } else {
                        Text(pitchClass.displayName)
                    }
                }
            }
        } label: {
            CompactTransportMenuLabel(
                prefix: "Key",
                value: appState.currentKey.displayName,
                minWidth: 66
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: false)
        .help("Choose key")
        .accessibilityLabel("Key")
        .accessibilityValue(appState.currentKey.displayName)
    }
}

/// Compact XPI-themed scale selector for the persistent transport bar.
struct ScaleSelectorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            ForEach(Scale.allScales) { scale in
                Button {
                    appState.setScale(scale)
                } label: {
                    if scale.id == appState.currentScale.id {
                        Label(scale.name, systemImage: "checkmark")
                    } else {
                        Text(scale.name)
                    }
                }
            }
        } label: {
            CompactTransportMenuLabel(
                prefix: nil,
                value: appState.currentScale.name,
                minWidth: 116
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: false)
        .help("Choose scale")
        .accessibilityLabel("Scale")
        .accessibilityValue(appState.currentScale.name)
    }
}

/// Shared visual treatment for small transport menu controls.
private struct CompactTransportMenuLabel: View {
    let prefix: String?
    let value: String
    let minWidth: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            if let prefix {
                Text(prefix)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(XTheme.textTertiary)
            }

            Text(value)
                .font(XTheme.controlLabelFont)
                .foregroundColor(XTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 2)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(XTheme.textTertiary)
        }
        .padding(.horizontal, 8)
        .frame(minWidth: minWidth, minHeight: 28, maxHeight: 28)
        .background(
            RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                .fill(XTheme.controlGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: XTheme.radiusSmall)
                        .stroke(Color.white.opacity(0.10), lineWidth: XTheme.strokeSubtle)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: XTheme.radiusSmall))
    }
}
