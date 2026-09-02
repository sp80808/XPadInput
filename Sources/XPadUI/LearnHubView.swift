import SwiftUI
import XPadCore
import XPadController

// MARK: - Tutorial Mission Persistence

/// UserDefaults-backed record of completed guided missions.
public enum TutorialMissionStore {
    private static let key = "xpi_tutorial_completed"

    public static func completedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    public static func markCompleted(_ id: String) {
        var done = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !done.contains(id) else { return }
        done.append(id)
        UserDefaults.standard.set(done, forKey: key)
    }

    public static func resetAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Learn Hub

/// Catalog of guided missions with completion tracking.
/// Opened from the Library workspace card, the Help menu, or onboarding.
public struct LearnHubView: View {
    @Environment(AppState.self) private var appState
    @State private var completedIDs = TutorialMissionStore.completedIDs()

    private let missions = TutorialMission.factoryPresets()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(XTheme.border)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(missions) { mission in
                        MissionCard(
                            mission: mission,
                            isCompleted: completedIDs.contains(mission.id),
                            isActive: appState.activeTutorialMissionID == mission.id,
                            onStart: { appState.startTutorial(missionID: mission.id) }
                        )
                    }
                }
                .padding(14)
            }
            footer
        }
        .background(XTheme.surfaceElevated)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(XTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Learn Hub")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(XTheme.textPrimary)
                Text("Play your controller through guided missions — the app watches your input.")
                    .font(.system(size: 11))
                    .foregroundColor(XTheme.textSecondary)
            }
            Spacer()
            if !completedIDs.isEmpty {
                Text("\(completedIDs.count)/\(missions.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(XTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(XTheme.primary.opacity(0.12))
                    .clipShape(Capsule())
            }
            Button {
                appState.showLearnHub = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(XTheme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(XTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Reset Progress") {
                TutorialMissionStore.resetAll()
                completedIDs = []
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundColor(XTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(XTheme.surface)
    }
}

// MARK: - Mission Card

private struct MissionCard: View {
    @Environment(AppState.self) private var appState
    let mission: TutorialMission
    let isCompleted: Bool
    let isActive: Bool
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: badgeIcon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(badgeColor)
                .frame(width: 30, height: 30)
                .background(badgeColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(mission.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(XTheme.textPrimary)
                Text(mission.summary)
                    .font(.system(size: 11))
                    .foregroundColor(XTheme.textSecondary)
                Text("\(mission.steps.count) steps")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(XTheme.textTertiary)
            }
            Spacer()
            Button(isActive ? "In Progress" : (isCompleted ? "Replay" : "Start")) {
                onStart()
            }
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.borderedProminent)
            .tint(isActive ? XTheme.textTertiary : XTheme.primary)
            .disabled(isActive)
        }
        .padding(12)
        .background(XTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(borderColor, lineWidth: 1))
    }

    private var badgeIcon: String {
        if isActive { return "play.circle.fill" }
        return isCompleted ? "checkmark.circle.fill" : "\(mission.steps.count).circle"
    }

    private var badgeColor: Color {
        if isActive { return XTheme.warning }
        return isCompleted ? XTheme.success : XTheme.textTertiary
    }

    private var borderColor: Color {
        isActive ? XTheme.warning.opacity(0.5)
                 : (isCompleted ? XTheme.success.opacity(0.35) : XTheme.border)
    }
}

// MARK: - Tutorial Overlay

/// Floating checklist bound to the live tutorial engine. Rendered above all
/// workspace chrome while a mission is active; polls engine progress so it
/// updates without touching the real-time audio/MIDI paths.
public struct TutorialOverlayView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        if let mission = appState.activeTutorialMission {
            TimelineView(.periodic(from: .now, by: 0.08)) { _ in
                MissionChecklist(mission: mission)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

private struct MissionChecklist: View {
    @Environment(AppState.self) private var appState
    let mission: TutorialMission

    private var progress: TutorialProgress { appState.tutorialEngine.currentProgress }
    private var schemeName: String { appState.controllerManager.activeScheme.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(headerColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mission.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(XTheme.textPrimary)
                    Text(progress.isMissionComplete ? "Mission complete!" : "Scheme: \(schemeName)")
                        .font(.system(size: 10))
                        .foregroundColor(XTheme.textSecondary)
                }
                Spacer()
                Button {
                    appState.endActiveTutorial(markCompleteIfFinished: true)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(XTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("End mission")
            }

            // Steps
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(mission.steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(index: index, step: step)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(XTheme.surface)
                    Capsule()
                        .fill(progress.isMissionComplete ? successColor : XTheme.primary)
                        .frame(width: geo.size.width * progress.fractionCompleted)
                }
            }
            .frame(height: 4)

            if progress.isMissionComplete {
                Button {
                    appState.endActiveTutorial(markCompleteIfFinished: true)
                } label: {
                    Label("Finish Mission", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(successColor)
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(XTheme.surfaceElevated.opacity(0.96))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(headerColor.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
    }

    @ViewBuilder
    private func stepRow(index: Int, step: TutorialStep) -> some View {
        let isDone = progress.completedSteps.contains(where: { $0.stepID == step.id })
        let isActive = index == progress.currentStepIndex && !isDone

        HStack(alignment: .top, spacing: 7) {
            Image(systemName: isDone ? "checkmark.circle.fill" : (isActive ? "circle.dotted" : "circle"))
                .font(.system(size: 12))
                .foregroundColor(isDone ? successColor : (isActive ? XTheme.primary : XTheme.textTertiary))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.resolvedInstruction(scheme: appState.controllerManager.activeScheme))
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isDone ? XTheme.textTertiary : XTheme.textPrimary)
                    .strikethrough(isDone)
                if isActive, let hint = progress.activeStepHint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(XTheme.primary.opacity(0.85))
                }
            }
        }
        .opacity(isDone ? 0.55 : 1)
    }

    private var headerColor: Color { progress.isMissionComplete ? XTheme.success : XTheme.primary }
    private var successColor: Color { XTheme.success }
}

// MARK: - Step Instruction Resolution

extension TutorialStep {
    /// Substitutes `%@` placeholders with the control names bound in `scheme`.
    public func resolvedInstruction(scheme: ControlScheme) -> String {
        guard instruction.contains("%@") else { return instruction }
        return instruction.replacingOccurrences(
            of: "%@",
            with: TutorialEngine.hint(for: gesture, scheme: scheme)
        )
    }
}
