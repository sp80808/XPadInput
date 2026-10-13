import SwiftUI
import XPadCore
import XPadTheory

/// Musical context stays visible in the persistent header.
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
            Text("Key \(appState.currentKey.displayName)")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize(horizontal: true, vertical: false)
        .help("Choose key")
        .accessibilityLabel("Key")
        .accessibilityValue(appState.currentKey.displayName)
    }
}

/// Scale and tuning share one native menu.
struct ScaleSelectorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            ForEach(Scale.allScales) { scale in
                Button {
                    appState.setScale(scale)
                } label: {
                    if scale.id == appState.currentScale.id {
                        Label(scale.displayName, systemImage: "checkmark")
                    } else {
                        Text(scale.displayName)
                    }
                }
            }
            Divider()
            Menu("Tuning") {
                ForEach(MicrotonalTemperament.allCases) { temperament in
                    Button {
                        appState.setTemperament(temperament)
                    } label: {
                        if temperament == appState.currentTemperament {
                            Label(temperament.rawValue, systemImage: "checkmark")
                        } else {
                            Text(temperament.rawValue)
                        }
                    }
                }
            }
        } label: {
            Text(appState.currentScale.shortDisplayName)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize(horizontal: true, vertical: false)
        .help("Choose scale and tuning for the built-in synth and MPE output.")
        .accessibilityLabel("Scale")
        .accessibilityValue("\(appState.currentScale.displayName), tuning \(appState.currentTemperament.rawValue)")
    }
}
