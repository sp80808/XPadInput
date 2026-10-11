import SwiftUI
import XPadCore
import XPadController

public struct MapWorkspaceView: View {
    public var controllerManager: ControllerManager
    @State private var selectedPanel: Panel = .schemes

    private enum Panel: String, CaseIterable, Identifiable {
        case schemes = "Control schemes"
        case inputs = "Input monitor"
        case profiles = "OCDS profiles"
        var id: Self { self }
    }

    public init(controllerManager: ControllerManager) {
        self.controllerManager = controllerManager
    }

    private var state: GamepadState {
        ControllerManager.gamepadState(from: controllerManager.controllerState)
    }

    private var iconPack: ControllerIconPack {
        controllerManager.controllerKind.iconPack
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: XTheme.space4) {
                Label("Controller", systemImage: "gamecontroller.fill")
                    .font(XTheme.fontHeadline)
                    .foregroundStyle(XTheme.textPrimary)
                Spacer(minLength: XTheme.space3)
                XWidthSafePicker("Controller workspace", selection: $selectedPanel) {
                    ForEach(Panel.allCases) { panel in
                        Text(panel.rawValue).tag(panel)
                    }
                }
                .frame(maxWidth: 420)
            }
            .padding(XTheme.space4)
            .background(XTheme.surface)

            Divider().overlay(XTheme.border)

            switch selectedPanel {
            case .schemes:
                ControlSchemeSettingsView()
            case .profiles:
                OCDSProfileManagerView()
            case .inputs:
                HSplitView {
                    ScrollView {
                        controllerInspector
                    }
                    .frame(minWidth: 420)
                    assignmentInspector
                        .frame(minWidth: 340)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(XTheme.canvas)
    }

    private var controllerInspector: some View {
        // Left: Controller Visualizer & HUD
        VStack(spacing: 16) {
            // Top Header & Controller Switcher
            HStack(spacing: 12) {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: iconPack.brandAccentHex))

                // Controller Kind Picker
                Picker("Active Hardware Profile", selection: Binding(
                    get: { controllerManager.controllerKind },
                    set: { controllerManager.selectControllerKind($0) }
                )) {
                    ForEach(ControllerCategory.allCases, id: \.self) { cat in
                        Section(header: Text(cat.rawValue)) {
                            ForEach(ControllerKind.allCases.filter { $0.category == cat }) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 260)

                Spacer()

                Text(controllerManager.isConnected ? "Hardware Connected" : "Controller Preview")
                    .font(.caption2.bold())
                    .foregroundStyle(controllerManager.isConnected ? XTheme.connected : XTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(XTheme.surfaceHigh)
                    .clipShape(Capsule())
            }

            // Dedicated Controller Visualizer based on Kind
            Group {
                switch controllerManager.controllerKind {
                case .guitarHero:
                    GuitarHeroVisualizerView(state: state)
                case .soundVoltex:
                    SoundVoltexVisualizerView(state: state)
                case .beatmaniaIIDX:
                    BeatmaniaVisualizerView(state: state)
                case .taikoDrum:
                    TaikoDrumVisualizerView(state: state)
                case .danceMat:
                    DanceMatVisualizerView(state: state)
                case .flightStick:
                    FlightStickVisualizerView(state: state)
                case .racingWheel:
                    RacingWheelVisualizerView(state: state)
                case .fightStick:
                    FightStickVisualizerView(state: state)
                default:
                    ControllerVisualizerView()
                        .frame(height: 340)
                }
            }

            // Triggers & Shoulders Gauges (if standard)
            if controllerManager.controllerKind.category == .standard {
                HStack(spacing: 12) {
                    AdaptiveTriggerVisualizerHUD(
                        feedbackState: controllerManager.adaptiveTriggerEngine.leftState,
                        label: controllerManager.physicalLabel(for: .leftTrigger),
                        accentColor: XTheme.brand
                    )
                    AdaptiveTriggerVisualizerHUD(
                        feedbackState: controllerManager.adaptiveTriggerEngine.rightState,
                        label: controllerManager.physicalLabel(for: .rightTrigger),
                        accentColor: XTheme.accent
                    )
                }
            }
        }
        .padding()
    }

    private var assignmentInspector: some View {
        VStack(alignment: .leading, spacing: XTheme.space3) {
            Text("Current assignments")
                .font(XTheme.fontHeadline)
                .foregroundStyle(XTheme.textPrimary)
            Text(controllerManager.activeScheme.name)
                .font(XTheme.fontCaption)
                .foregroundStyle(XTheme.textSecondary)
            ScrollView {
                LazyVStack(spacing: XTheme.space2) {
                    ForEach(SemanticMusicalAction.allCases) { action in
                        assignmentRow(action)
                    }
                }
            }
        }
        .padding(XTheme.space4)
    }

    private func assignmentRow(_ action: SemanticMusicalAction) -> some View {
        let input = controllerManager.activeScheme.binding(for: action)?.input ?? .unassigned
        return HStack(spacing: XTheme.space3) {
            if input != .unassigned {
                ControllerGlyphView(key: controllerManager.controlGlyph(for: action), iconPack: iconPack, isPressed: false, size: .regular)
            } else {
                Image(systemName: "minus.circle")
                    .foregroundStyle(XTheme.textTertiary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(controllerManager.controlLabel(for: action))
                    .font(XTheme.fontCaption)
                    .fontWeight(.semibold)
                Text(action.displayName)
                    .font(XTheme.fontCaptionSmall)
                    .foregroundStyle(XTheme.textSecondary)
            }
            Spacer(minLength: XTheme.space2)
            Text(input == .unassigned ? "Unassigned" : "Mapped")
                .font(XTheme.fontCaptionSmall)
                .foregroundStyle(input == .unassigned ? XTheme.textTertiary : XTheme.brand)
        }
        .padding(XTheme.space3)
        .background(XTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: XTheme.radiusS))
        .accessibilityElement(children: .combine)
    }
}
