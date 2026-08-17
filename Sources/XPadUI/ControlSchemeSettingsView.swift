import SwiftUI
import XPadCore
import XPadController

/// Polished native Settings and Configuration Studio for XPI Control Schemes, Ergonomics, Calibration & Remapping.
public struct ControlSchemeSettingsView: View {
    @Environment(AppState.self) private var appState
    
    @State private var selectedTab: SettingsTab = .ergonomics
    @State private var customSchemes: [ControlScheme] = []
    @State private var selectedSchemeId: String = ""
    @State private var isShowingCalibrationWizard = false
    @State private var learningTargetAction: SemanticMusicalAction? = nil
    @State private var conflictList: [MappingConflict] = []
    @State private var coverageIssues: [SchemeCoverageIssue] = []
    @State private var customSchemeName: String = ""
    @State private var isCreatingCustom = false
    
    public enum SettingsTab: String, CaseIterable, Identifiable {
        case ergonomics = "Feel & Ergonomics"
        case remapping = "Action Remapping"
        case liveTest = "Live Test Studio"
        case calibration = "Hardware Calibration"

        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .ergonomics: return "hand.tap.fill"
            case .remapping: return "arrow.triangle.2.circlepath"
            case .liveTest: return "waveform.path.ecg"
            case .calibration: return "scope"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header & Controller Status
            controllerHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(XTheme.surface)
            
            Divider()
                .overlay(XTheme.border)
            
            // MARK: - Scheme Picker & Primary Actions
            schemeToolbar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(XTheme.surface.opacity(0.6))
            
            Divider()
                .overlay(XTheme.border)
            
            // MARK: - Tab Selector
            tabSelector
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(XTheme.background)
            
            // MARK: - Active Tab Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .ergonomics:
                        ergonomicsView
                    case .remapping:
                        remappingView
                    case .liveTest:
                        liveTestStudioView
                    case .calibration:
                        calibrationStudioView
                    }
                }
                .padding(20)
            }
            .background(XTheme.background)
        }
        .frame(minWidth: 680, minHeight: 520)
        .onAppear {
            loadSchemes()
            selectedSchemeId = appState.controllerManager.activeScheme.id
            validateConflicts()
        }
        .sheet(item: $learningTargetAction) { action in
            inputLearnSheet(for: action)
        }
        .sheet(isPresented: $isShowingCalibrationWizard) {
            calibrationWizardSheet
        }
    }

    // MARK: - 1. Controller Header
    
    private var controllerHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(appState.controllerManager.isConnected ? XTheme.primary.opacity(0.18) : Color.white.opacity(0.06))
                    .frame(width: 42, height: 42)
                
                Image(systemName: appState.controllerManager.isConnected ? "gamecontroller.fill" : "gamecontroller")
                    .font(.system(size: 20))
                    .foregroundStyle(appState.controllerManager.isConnected ? XTheme.primary : XTheme.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(appState.controllerManager.controllerName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(XTheme.textPrimary)
                    
                    Text(appState.controllerManager.isConnected ? "Connected" : "Simulated / Disconnected")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(appState.controllerManager.isConnected ? XTheme.primary : XTheme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(appState.controllerManager.isConnected ? XTheme.primary.opacity(0.15) : Color.white.opacity(0.08))
                        )
                }
                
                // Hardware Capabilities Pill Badges
                HStack(spacing: 6) {
                    if let caps = appState.controllerManager.capabilityProfile {
                        if caps.hasHaptics { capabilityBadge("Haptics", icon: "dot.radiowaves.left.and.right") }
                        if caps.hasMotionIMU { capabilityBadge("Motion IMU", icon: "gyroscope") }
                        if caps.hasAdaptiveTriggers { capabilityBadge("Adaptive Triggers", icon: "gauge.with.needle") }
                        else if caps.hasAnalogTriggers { capabilityBadge("Analog Triggers", icon: "gauge.with.needle") }
                        if caps.hasTouchpad { capabilityBadge("Touchpad", icon: "hand.draw") }
                    } else {
                        Text("Standard Extended Gamepad Profile Active")
                            .font(.system(size: 11))
                            .foregroundStyle(XTheme.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                isShowingCalibrationWizard = true
            } label: {
                Label("Calibrate Hardware…", systemImage: "scope")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(XTheme.primary)
            .disabled(!appState.controllerManager.isConnected)
        }
    }
    
    private func capabilityBadge(_ title: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(title)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(XTheme.primaryLight)
        .padding(.horizontal, 6)
        .padding(.vertical, 1.5)
        .background(Capsule().fill(XTheme.primary.opacity(0.12)))
    }

    // MARK: - 2. Scheme Toolbar
    
    private var schemeToolbar: some View {
        HStack(spacing: 12) {
            Text("Control Scheme:")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(XTheme.textSecondary)
            
            Picker("", selection: Binding(
                get: { selectedSchemeId },
                set: { newId in
                    selectedSchemeId = newId
                    if let scheme = allSchemes.first(where: { $0.id == newId }) {
                        appState.controllerManager.selectControlScheme(scheme)
                        validateConflicts()
                    }
                }
            )) {
                Section("Built-In Schemes") {
                    ForEach(ControlSchemePreset.allBuiltIn) { scheme in
                        Text(scheme.name).tag(scheme.id)
                    }
                }
                
                if !customSchemes.isEmpty {
                    Section("Custom User Schemes") {
                        ForEach(customSchemes) { scheme in
                            Text(scheme.name).tag(scheme.id)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .frame(width: 240)
            
            Text(currentScheme.description)
                .font(.system(size: 11))
                .foregroundStyle(XTheme.textTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Actions
            Button {
                duplicateAsCustom()
            } label: {
                Label("Duplicate as Custom", systemImage: "plus.square.on.square")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(XTheme.primaryLight)
            
            Button {
                resetToDefaults()
            } label: {
                Text("Reset")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(XTheme.textTertiary)
        }
    }

    // MARK: - 3. Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? XTheme.textPrimary : XTheme.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedTab == tab ? XTheme.surfaceElevated : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            
            if !conflictList.isEmpty || !coverageIssues.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(XTheme.warning)
                    Text(warningSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(XTheme.warning)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(XTheme.warning.opacity(0.12)))
            }
        }
    }

    // MARK: - 4. Feel & Ergonomics View
    
    private var ergonomicsView: some View {
        VStack(spacing: 16) {
            // Hand Roles & Orientation
            settingsCard(title: "Hand Orientation & Roles", icon: "arrow.left.and.right.square") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Swap Left & Right Controller Roles", isOn: Binding(
                        get: { currentScheme.isLeftRightSwapped },
                        set: { val in updateScheme { $0.isLeftRightSwapped = val } }
                    ))
                    .font(.system(size: 13))
                    
                    Text("Reverses thumbstick and trigger tasks at the hardware layer (Left hand drives strumming & bends, Right hand steers harmony). For a fully remappable mirror, choose the Left-Handed Performance scheme.")
                        .font(.system(size: 11))
                        .foregroundStyle(XTheme.textTertiary)
                }
            }
            
            // Analog Stick Feel — ControlSurfaceProfile owns role-specific processing
            settingsCard(title: "Control Surface Feel", icon: "circle.grid.cross") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Surface Feel", selection: Binding(
                        get: { appState.controllerManager.surfaceProfile.feel },
                        set: { val in
                            var profile = appState.controllerManager.surfaceProfile
                            profile.feel = val
                            appState.controllerManager.applySurfaceProfile(profile)
                        }
                    )) {
                        ForEach(ControlSurfaceFeel.allCases) { feel in
                            Text(feel.pickerLabel).tag(feel)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Harmony (left) uses a different curve from strum (right Y) and bend (right X). Reduced Travel reaches full musical range with less physical movement. Instrument identity is unchanged.")
                        .font(.system(size: 11))
                        .foregroundStyle(XTheme.textTertiary)

                    Toggle("Mirror surface (left-handed)", isOn: Binding(
                        get: { appState.controllerManager.surfaceProfile.mirrored },
                        set: { val in
                            var profile = appState.controllerManager.surfaceProfile
                            profile.mirrored = val
                            appState.controllerManager.applySurfaceProfile(profile)
                        }
                    ))
                    .font(.system(size: 13))
                }
            }
            
            // Trigger Feel
            settingsCard(title: "Trigger Pressure Feel", icon: "gauge.with.needle") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Trigger Profile", selection: Binding(
                        get: { currentScheme.triggerFeel },
                        set: { val in updateScheme { $0.triggerFeel = val } }
                    )) {
                        ForEach(TriggerFeelPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Configures activation depth and pressure curve for acoustic muting and continuous dynamic swells.")
                        .font(.system(size: 11))
                        .foregroundStyle(XTheme.textTertiary)

                    Picker("Adaptive trigger force", selection: Binding(
                        get: { appState.controllerManager.surfaceProfile.triggerForce },
                        set: { val in
                            var profile = appState.controllerManager.surfaceProfile
                            profile.triggerForce = val
                            appState.controllerManager.applySurfaceProfile(profile)
                        }
                    )) {
                        ForEach(AdaptiveTriggerForcePolicy.allCases) { policy in
                            Text(policy.rawValue).tag(policy)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Force is DualSense-only. Off / Reduced / Standard never changes musical trigger values on Xbox or other pads.")
                        .font(.system(size: 11))
                        .foregroundStyle(XTheme.textTertiary)
                }
            }

            settingsCard(title: "Grip & Occupancy", icon: "hand.raised") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Grip", selection: Binding(
                        get: { appState.controllerManager.surfaceProfile.grip },
                        set: { val in
                            var profile = appState.controllerManager.surfaceProfile
                            profile.grip = val
                            appState.controllerManager.applySurfaceProfile(profile)
                        }
                    )) {
                        ForEach(GripProfile.allCases) { grip in
                            Text(grip.rawValue).tag(grip)
                        }
                    }
                    .pickerStyle(.menu)

                    if appState.controllerManager.lastErgonomicWarnings.isEmpty {
                        Text("No occupancy conflicts for this grip.")
                            .font(.system(size: 11))
                            .foregroundStyle(XTheme.textTertiary)
                    } else {
                        ForEach(appState.controllerManager.lastErgonomicWarnings) { warning in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: warning.kind == .intentionalTradeoff ? "info.circle" : "exclamationmark.triangle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(warning.kind == .intentionalTradeoff ? XTheme.primary : XTheme.warning)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(warning.kind.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(warning.message)
                                        .font(.system(size: 11))
                                        .foregroundStyle(XTheme.textTertiary)
                                }
                            }
                        }
                        Text("Warnings never block saving a custom mapping.")
                            .font(.system(size: 11))
                            .foregroundStyle(XTheme.textTertiary)
                    }
                }
            }
            
            // Haptics & Motion
            settingsCard(title: "Tactile Haptics & Motion Sensors", icon: "waveform.path") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Haptic Feedback:")
                            .font(.system(size: 13))
                            .foregroundStyle(XTheme.textSecondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { currentScheme.haptics },
                            set: { val in updateScheme { $0.haptics = val } }
                        )) {
                            ForEach(HapticFeedbackIntensity.allCases) { h in
                                Text(h.rawValue).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }

                    Text(currentScheme.haptics.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(XTheme.textTertiary)
                    
                    Divider().overlay(XTheme.border)
                    
                    Toggle("Enable 6-Axis Motion / IMU Tilt Expression", isOn: Binding(
                        get: { currentScheme.isMotionEnabled },
                        set: { val in updateScheme { $0.isMotionEnabled = val } }
                    ))
                    .font(.system(size: 13))
                }
            }
        }
    }

    // MARK: - 5. Action Remapping View
    
    private var remappingView: some View {
        VStack(spacing: 16) {
            if appState.controllerManager.remapSnapshot.hasRemappedElements {
                settingsCard(title: "macOS Controller Remap", icon: "arrow.triangle.2.circlepath") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Settings remapped this controller. HUD labels follow the physical control you actually press.")
                            .font(.system(size: 11))
                            .foregroundStyle(XTheme.textTertiary)
                        ForEach(appState.controllerManager.remapSnapshot.physicalNameByAlias.sorted(by: { $0.key < $1.key }), id: \.key) { alias, physical in
                            HStack {
                                Text(alias)
                                    .font(.system(size: 11, design: .monospaced))
                                Spacer()
                                Text(physical)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        }
                    }
                }
            }

            if !coverageIssues.isEmpty {
                settingsCard(title: "Scheme Coverage", icon: "checklist") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(coverageIssues) { issue in
                            Text(issue.message)
                                .font(.system(size: 11))
                                .foregroundStyle(issue.severity == .critical ? XTheme.tense : XTheme.textTertiary)
                        }
                    }
                }
            }

            ForEach(SemanticMusicalAction.ActionCategory.allCases) { cat in
                let actions = SemanticMusicalAction.allCases.filter { $0.category == cat }
                
                settingsCard(title: cat.rawValue, icon: categoryIcon(cat)) {
                    VStack(spacing: 1) {
                        ForEach(actions) { action in
                            actionRemapRow(action: action)
                        }
                    }
                }
            }
        }
    }
    
    private func actionRemapRow(action: SemanticMusicalAction) -> some View {
        let binding = currentScheme.binding(for: action)
        let boundInput = binding?.input ?? .unassigned
        let conflict = conflictList.first(where: { $0.actions.contains(action) })
        
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(action.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(XTheme.textPrimary)
                    
                    if let conflict = conflict {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(conflict.severity == .critical ? XTheme.tense : XTheme.warning)
                            .help(conflict.message)
                    }
                }
                
                Text(action.description)
                    .font(.system(size: 10))
                    .foregroundStyle(XTheme.textTertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Input Badge with Glyphs
            HStack(spacing: 6) {
                let displayed = ControllerRemapResolver.displayedInput(
                    for: boundInput,
                    snapshot: appState.controllerManager.remapSnapshot
                )
                Text(appState.controllerManager.physicalLabel(for: displayed))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(boundInput == .unassigned ? XTheme.textTertiary : XTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(boundInput == .unassigned ? Color.white.opacity(0.04) : XTheme.surfaceHover)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(XTheme.border, lineWidth: 1)
                            )
                    )
                if displayed != boundInput {
                    Text("remapped")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(XTheme.primary)
                }
                
                // Learn / Rebind Button
                Button {
                    startLearning(for: action)
                } label: {
                    Text("Rebind")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Menu {
                    Button {
                        updateScheme { scheme in
                            var next = scheme.binding(for: action) ?? .defaultBinding(for: .unassigned)
                            next.isInverted.toggle()
                            scheme.bindings[action] = next
                        }
                    } label: {
                        Label(
                            binding?.isInverted == true ? "Inversion On" : "Invert Axis / Polarity",
                            systemImage: binding?.isInverted == true ? "checkmark" : "arrow.up.arrow.down"
                        )
                    }

                    if let binding, !boundInput.isContinuous {
                        Picker("Held Behaviour", selection: Binding(
                            get: { binding.digitalBehavior },
                            set: { behavior in
                                updateScheme { scheme in
                                    var next = scheme.binding(for: action) ?? .defaultBinding(for: boundInput)
                                    next.digitalBehavior = behavior
                                    scheme.bindings[action] = next
                                }
                            }
                        )) {
                            ForEach(DigitalExpressionBehavior.allCases, id: \.self) { behavior in
                                Text(behavior.rawValue).tag(behavior)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        updateScheme { scheme in
                            scheme.bindings[action] = PhysicalControlBinding(input: .unassigned)
                        }
                    } label: {
                        Label("Unassign", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(XTheme.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 22)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    // MARK: - 6. Live Test Studio View
    
    private var liveTestStudioView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Action → Sound Timing", icon: "timer") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Collect software timing", isOn: Binding(
                        get: { appState.latencyProbe.isEnabled },
                        set: { appState.latencyProbe.isEnabled = $0 }
                    ))
                    Text(appState.latencyProbe.snapshot().summaryLine)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(XTheme.textSecondary)
                    Text("Host-time from controller callback through internal synth Note On return. This is not acoustic hardware latency. Graph mutation is attach/connect cost on the attack path. First-buffer is the first audio render callback after Note On.")
                        .font(.system(size: 11))
                        .foregroundStyle(XTheme.textTertiary)
                    Text(String(format: "Last first-buffer: %.2f ms", appState.audioEngine.lastFirstBufferMs))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(XTheme.textSecondary)
                    Button("Reset samples") {
                        appState.latencyProbe.reset()
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Live Stick Vectors
            HStack(spacing: 16) {
                stickTestBox(
                    title: "Left Thumbstick",
                    state: appState.controllerManager.controllerState.leftStick,
                    mappedAction: appState.controllerManager.activeScheme.actions(mappedTo: .leftStick2D).first
                )
                
                stickTestBox(
                    title: "Right Thumbstick",
                    state: appState.controllerManager.controllerState.rightStick,
                    mappedAction: appState.controllerManager.activeScheme.actions(mappedTo: .rightStick2D).first ?? appState.controllerManager.activeScheme.actions(mappedTo: .rightStickY).first
                )
            }
            
            // Live Triggers
            HStack(spacing: 16) {
                triggerTestBox(
                    title: "Left Trigger (L2 / LT)",
                    state: appState.controllerManager.controllerState.leftTrigger,
                    mappedAction: appState.controllerManager.activeScheme.actions(mappedTo: .leftTrigger).first
                )
                
                triggerTestBox(
                    title: "Right Trigger (R2 / RT)",
                    state: appState.controllerManager.controllerState.rightTrigger,
                    mappedAction: appState.controllerManager.activeScheme.actions(mappedTo: .rightTrigger).first
                )
            }
            
            // Currently Sounding Action Callout
            settingsCard(title: "Active Mapped Gesture Interpretation", icon: "waveform.badge.magnifyingglass") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Technique / Action:")
                            .font(.system(size: 11))
                            .foregroundStyle(XTheme.textTertiary)
                        
                        Text(appState.activeTechniqueLabel ?? (appState.lastFrame?.activeTechnique.displayName ?? "Resting / Neutral"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(XTheme.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("MPE Channel / Pitch Bend:")
                            .font(.system(size: 11))
                            .foregroundStyle(XTheme.textTertiary)
                        
                        Text(String(format: "%+.2f semitones", appState.lastFrame?.bend.bendSemitones ?? 0.0))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(XTheme.textPrimary)
                    }
                }
            }
        }
    }
    
    private func stickTestBox(title: String, state: ProcessedStickState, mappedAction: SemanticMusicalAction?) -> some View {
        settingsCard(title: title, icon: "circle.grid.cross") {
            VStack(spacing: 10) {
                // Vector Canvas
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                        .frame(width: 90, height: 90)
                    
                    // Crosshairs
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 90, height: 1)
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 90)
                    
                    // Puck
                    Circle()
                        .fill(XTheme.primary)
                        .frame(width: 12, height: 12)
                        .shadow(color: XTheme.primary.opacity(0.6), radius: 4)
                        .offset(x: CGFloat(state.x) * 40, y: CGFloat(-state.y) * 40)
                }
                
                HStack(spacing: 8) {
                    Text(String(format: "X: %+.2f", state.x))
                        .font(.system(size: 10, design: .monospaced))
                    Text(String(format: "Y: %+.2f", state.y))
                        .font(.system(size: 10, design: .monospaced))
                    Text(String(format: "Vel: %.1f", state.movementVelocity))
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(XTheme.textTertiary)
                
                if let action = mappedAction {
                    Text(action.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(XTheme.primaryLight)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(XTheme.primary.opacity(0.12)))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func triggerTestBox(title: String, state: ProcessedTriggerState, mappedAction: SemanticMusicalAction?) -> some View {
        settingsCard(title: title, icon: "gauge.with.needle") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(format: "Pressure: %.0f%%", state.value * 100))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(XTheme.textPrimary)
                    Spacer()
                    if state.isPressed {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(XTheme.primary)
                    }
                }
                
                // Pressure Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [XTheme.primary, XTheme.accent], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(state.value))
                    }
                }
                .frame(height: 8)
                
                if let action = mappedAction {
                    Text(action.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(XTheme.primaryLight)
                }
            }
        }
    }

    // MARK: - 7. Hardware Calibration Studio
    
    private var calibrationStudioView: some View {
        let cal = appState.controllerManager.hardwareCalibration
        
        return VStack(spacing: 16) {
            settingsCard(title: "Hardware Offsets & Measured Bounds", icon: "scope") {
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Left Stick Calibration")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(XTheme.textPrimary)
                            Text(String(format: "Rest Drift Offset: (X: %+.3f, Y: %+.3f)", cal.leftStick.restCenterX, cal.leftStick.restCenterY))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(XTheme.textTertiary)
                            Text(String(format: "Drift Deadzone Radius: %.3f", cal.leftStick.driftRadius))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(XTheme.textTertiary)
                            Text(String(format: "Max Reach Radius: %.3f", cal.leftStick.maxRadius))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(XTheme.textTertiary)
                        }
                        
                        Divider().frame(height: 60)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Right Stick Calibration")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(XTheme.textPrimary)
                            Text(String(format: "Rest Drift Offset: (X: %+.3f, Y: %+.3f)", cal.rightStick.restCenterX, cal.rightStick.restCenterY))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(XTheme.textTertiary)
                            Text(String(format: "Drift Deadzone Radius: %.3f", cal.rightStick.driftRadius))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(XTheme.textTertiary)
                            Text(String(format: "Max Reach Radius: %.3f", cal.rightStick.maxRadius))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(XTheme.textTertiary)
                        }
                    }
                    
                    Divider().overlay(XTheme.border)
                    
                    HStack {
                        Button {
                            isShowingCalibrationWizard = true
                        } label: {
                            Label("Run Interactive Calibration Wizard…", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(XTheme.primary)
                        
                        Spacer()
                        
                        Button("Reset Calibration") {
                            let id = "\(appState.controllerManager.connectedController?.vendorName ?? "generic")_\(appState.controllerManager.connectedController?.productCategory ?? "gamepad")"
                            ControllerSettingsStore.shared.resetCalibration(for: id)
                            appState.controllerManager.applyHardwareCalibration(ControllerHardwareCalibration())
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(XTheme.tense)
                    }
                }
            }
        }
    }

    // MARK: - 8. Input Learn Sheet
    
    private func inputLearnSheet(for action: SemanticMusicalAction) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 36))
                .foregroundStyle(XTheme.primary)
            
            VStack(spacing: 6) {
                Text("Input Learn Mode")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(XTheme.textPrimary)
                
                Text("Press or move the physical controller element you want to map to:")
                    .font(.system(size: 12))
                    .foregroundStyle(XTheme.textSecondary)
                
                Text(action.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(XTheme.primaryLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(XTheme.primary.opacity(0.15)))
            }
            
            ProgressView()
                .tint(XTheme.primary)
            
            Text("Listening for deliberate action (ignoring resting thumbstick jitter)…")
                .font(.system(size: 11))
                .foregroundStyle(XTheme.textTertiary)
            
            Button("Cancel") {
                appState.controllerManager.learningAction = nil
                learningTargetAction = nil
            }
            .buttonStyle(.bordered)
        }
        .padding(30)
        .frame(width: 420, height: 280)
        .background(XTheme.surfaceElevated)
        .onAppear {
            appState.controllerManager.learningAction = action
            appState.controllerManager.onInputLearned = { targetAction, detectedInput in
                updateScheme { scheme in
                    scheme.bindings[targetAction] = PhysicalControlBinding(input: detectedInput)
                }
                learningTargetAction = nil
            }
        }
    }

    // MARK: - 9. Calibration Wizard Modal Sheet
    
    private var calibrationWizardSheet: some View {
        VStack(spacing: 18) {
            Text("Hardware Calibration Wizard")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(XTheme.textPrimary)
            
            Text("Follow the prompt to capture rest drift and full rotation reach.")
                .font(.system(size: 12))
                .foregroundStyle(XTheme.textSecondary)
            
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 140, height: 140)
                
                // Crosshairs
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 140, height: 1)
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 140)
                
                // Live Stick puck
                Circle()
                    .fill(XTheme.primary)
                    .frame(width: 14, height: 14)
                    .offset(
                        x: CGFloat(appState.controllerManager.controllerState.leftStick.x) * 60,
                        y: CGFloat(-appState.controllerManager.controllerState.leftStick.y) * 60
                    )
            }
            
            Text("1. Leave thumbsticks untouched for 1 second.\n2. Rotate both thumbsticks fully around their outer perimeter.")
                .font(.system(size: 11))
                .foregroundStyle(XTheme.textTertiary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    appState.controllerManager.calibrationWizard.cancel()
                    isShowingCalibrationWizard = false
                }
                .buttonStyle(.bordered)
                
                Button("Finish & Save Calibration") {
                    let result = appState.controllerManager.calibrationWizard.finish()
                    appState.controllerManager.applyHardwareCalibration(result)
                    isShowingCalibrationWizard = false
                }
                .buttonStyle(.borderedProminent)
                .tint(XTheme.primary)
            }
        }
        .padding(24)
        .frame(width: 440, height: 360)
        .background(XTheme.surfaceElevated)
        .onAppear {
            appState.controllerManager.calibrationWizard.start()
        }
    }

    // MARK: - Helpers & Data Logic
    
    private var allSchemes: [ControlScheme] {
        ControlSchemePreset.allBuiltIn + customSchemes
    }
    
    private var currentScheme: ControlScheme {
        allSchemes.first(where: { $0.id == selectedSchemeId }) ?? ControlSchemePreset.xpiPerformance
    }
    
    private func loadSchemes() {
        customSchemes = ControllerSettingsStore.shared.loadCustomSchemes()
    }
    
    private func updateScheme(_ modifier: (inout ControlScheme) -> Void) {
        var scheme = currentScheme
        if scheme.isBuiltIn {
            // Auto-duplicate into a custom scheme if editing a built-in template
            scheme = scheme.makeCustomCopy()
            modifier(&scheme)
            customSchemes.append(scheme)
            selectedSchemeId = scheme.id
            ControllerSettingsStore.shared.saveCustomScheme(scheme)
        } else {
            modifier(&scheme)
            if let idx = customSchemes.firstIndex(where: { $0.id == scheme.id }) {
                customSchemes[idx] = scheme
            }
            ControllerSettingsStore.shared.saveCustomScheme(scheme)
        }
        appState.controllerManager.selectControlScheme(scheme)
        validateConflicts()
    }
    
    private func duplicateAsCustom() {
        let copy = currentScheme.makeCustomCopy()
        customSchemes.append(copy)
        selectedSchemeId = copy.id
        ControllerSettingsStore.shared.saveCustomScheme(copy)
        appState.controllerManager.selectControlScheme(copy)
        validateConflicts()
    }
    
    private func resetToDefaults() {
        if currentScheme.isBuiltIn {
            appState.controllerManager.selectControlScheme(currentScheme)
        } else {
            ControllerSettingsStore.shared.deleteCustomScheme(id: currentScheme.id)
            customSchemes.removeAll(where: { $0.id == currentScheme.id })
            let fallback = ControlSchemePreset.xpiPerformance
            selectedSchemeId = fallback.id
            appState.controllerManager.selectControlScheme(fallback)
        }
        validateConflicts()
    }
    
    private func startLearning(for action: SemanticMusicalAction) {
        learningTargetAction = action
    }
    
    private func validateConflicts() {
        conflictList = MappingConflict.detectConflicts(in: currentScheme)
        coverageIssues = currentScheme.coverageIssues(
            capabilities: appState.controllerManager.capabilityProfile
        )
        appState.controllerManager.refreshErgonomicWarnings()
    }

    private var warningSummary: String {
        let critical = conflictList.filter { $0.severity == .critical }.count
            + coverageIssues.filter { $0.severity == .critical }.count
        let total = conflictList.count + coverageIssues.count
        if critical > 0 {
            return "\(critical) critical, \(total) issue\(total == 1 ? "" : "s")"
        }
        return "\(total) Mapping Warning\(total == 1 ? "" : "s")"
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(XTheme.primary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(XTheme.textPrimary)
            }
            
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(XTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(XTheme.border, lineWidth: 1)
                )
        )
    }

    private func categoryIcon(_ cat: SemanticMusicalAction.ActionCategory) -> String {
        switch cat {
        case .excitation: return "bolt.horizontal.fill"
        case .expression: return "waveform.path"
        case .harmony: return "circle.hexagongrid.fill"
        case .articulation: return "hand.tap"
        case .directVoices: return "music.note.list"
        case .utility: return "wrench.and.screwdriver"
        }
    }
}
