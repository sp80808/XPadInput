import SwiftUI
import XPadCore
import XPadTheory
import XPadController
import XPadPractice

// MARK: - Practice Workspace View

public struct PracticeWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: PracticeTab = .lessons
    @State private var selectedLesson: PracticeLesson?
    @State private var selectedCategory: LessonCategory = .fundamentals
    @State private var showLessonDetail = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Library chrome stays hidden during an active session so the
            // lesson view can use the full content area.
            if selectedTab != .practice {
                PracticeHeaderView(
                    selectedTab: $selectedTab,
                    progressTracker: appState.progressTracker,
                    isSessionActive: appState.practiceEngine.isPracticeActive,
                    onDismiss: dismissWorkspace
                )
                
                Divider().background(XTheme.border)
            }
            
            // Tab Content
            ZStack {
                switch selectedTab {
                case .lessons:
                    LessonLibraryView(
                        selectedCategory: $selectedCategory,
                        selectedLesson: $selectedLesson,
                        showLessonDetail: $showLessonDetail,
                        onStartLesson: startLesson
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .practice:
                    ActivePracticeView(
                        practiceEngine: appState.practiceEngine,
                        onExit: exitPractice
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .progress:
                    ProgressDashboardView(
                        progressTracker: appState.progressTracker
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .challenges:
                    ChallengeModeView(
                        onStartChallenge: startChallenge
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .sheet(isPresented: $showLessonDetail) {
            if let lesson = selectedLesson {
                LessonDetailView(
                    lesson: lesson,
                    onStart: {
                        showLessonDetail = false
                        startLesson(lesson)
                    }
                )
            }
        }
    }
    
    private func startLesson(_ lesson: PracticeLesson) {
        selectedLesson = lesson
        selectedTab = .practice
        appState.practiceEngine.startLesson(lesson)
    }
    
    private func startChallenge(_ challenge: PracticeChallenge) {
        selectedTab = .practice
        appState.practiceEngine.startChallenge(challenge)
    }
    
    private func exitPractice() {
        appState.practiceEngine.stopPractice()
        selectedTab = .lessons
    }

    private func dismissWorkspace() {
        appState.dismissPractice()
        selectedTab = .lessons
    }
}

// MARK: - Practice Tabs

enum PracticeTab: String, CaseIterable, Identifiable {
    case lessons = "Lessons"
    case practice = "Practice"
    case progress = "Progress"
    case challenges = "Challenges"
    
    var id: String { rawValue }
}

// MARK: - Practice Header

struct PracticeHeaderView: View {
    @Binding var selectedTab: PracticeTab
    let progressTracker: ProgressTracker
    var isSessionActive: Bool = false
    var onDismiss: () -> Void = {}

    private var visibleTabs: [PracticeTab] {
        PracticeTab.allCases.filter { $0 != .practice || isSessionActive }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo and Title
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(XTheme.primary)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("PRACTICE")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(XTheme.textPrimary)
                    Text("Learning Workspace")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(XTheme.primary)
                }
            }

            HStack(spacing: 4) {
                ForEach(visibleTabs) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? XTheme.textPrimary : XTheme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedTab == tab ? XTheme.primary.opacity(0.2) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(selectedTab == tab ? 1.05 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.75), value: selectedTab)
                }
            }
            
            Spacer()
            
            // Progress Stats
            HStack(spacing: 16) {
                ProgressStatItem(
                    icon: "flame.fill",
                    value: "\(progressTracker.streakDays)",
                    label: "Day Streak"
                )
                ProgressStatItem(
                    icon: "clock.fill",
                    value: formatTime(progressTracker.totalPracticeTime),
                    label: "Total Time"
                )
                ProgressStatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(progressTracker.getCompletedLessonsCount())",
                    label: "Completed"
                )
            }

            Button("Done") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(XTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(XTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .help("Return to Play")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(XTheme.surface.opacity(0.4))
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
}

struct ProgressStatItem: View {
    let icon: String
    let value: String
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(XTheme.primary)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(XTheme.textPrimary)
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(XTheme.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(XTheme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .scaleEffect(reduceMotion ? 1 : (isHovering ? 1.04 : 1.0))
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Lesson Library View

struct LessonLibraryView: View {
    @Binding var selectedCategory: LessonCategory
    @Binding var selectedLesson: PracticeLesson?
    @Binding var showLessonDetail: Bool
    let onStartLesson: (PracticeLesson) -> Void
    
    private let lessons = PracticeLesson.factoryPresets()
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LessonCategory.allCases) { category in
                        CategoryFilterButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(XTheme.surface.opacity(0.3))
            
            Divider().background(XTheme.border)
            
            // Lesson Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredLessons) { lesson in
                        LessonCard(
                            lesson: lesson,
                            mastery: ProgressTracker.shared.getLessonMastery(for: lesson.id)
                        ) {
                            selectedLesson = lesson
                            showLessonDetail = true
                        }
                    }
                }
                .padding(16)
            }
        }
    }
    
    private var filteredLessons: [PracticeLesson] {
        lessons.filter { $0.category == selectedCategory }
    }
}

struct CategoryFilterButton: View {
    let category: LessonCategory
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isSelected ? .white : XTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? XTheme.primary : XTheme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected && !reduceMotion ? 1.05 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75), value: isSelected)
    }
}

struct LessonCard: View {
    let lesson: PracticeLesson
    let mastery: LessonMastery?
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(lesson.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(XTheme.textPrimary)
                    .lineLimit(2)
                
                Spacer()
                
                if let mastery = mastery {
                    MasteryBadge(level: mastery.masteryLevel)
                }
            }
            
            // Description
            Text(lesson.description)
                .font(.system(size: 10))
                .foregroundColor(XTheme.textSecondary)
                .lineLimit(3)
            
            // Metadata
            HStack(spacing: 8) {
                DifficultyBadge(difficulty: lesson.difficulty)
                Text("•")
                    .foregroundColor(XTheme.textTertiary)
                Text("\(lesson.estimatedDurationMinutes) min")
                    .font(.system(size: 9))
                    .foregroundColor(XTheme.textTertiary)
                Text("•")
                    .foregroundColor(XTheme.textTertiary)
                Text("\(lesson.steps.count) steps")
                    .font(.system(size: 9))
                    .foregroundColor(XTheme.textTertiary)
            }
            
            Spacer()
            
            // Start Button
            Button(action: onTap) {
                HStack {
                    Image(systemName: mastery == nil ? "play.fill" : "arrow.clockwise")
                        .font(.system(size: 10))
                    Text(mastery == nil ? "Start Lesson" : "Practice Again")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(XTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(XTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(XTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(height: 140)
        .scaleEffect(reduceMotion ? 1 : (isHovering ? 1.02 : 1.0))
        .shadow(color: .black.opacity(reduceMotion ? 0 : (isHovering ? 0.2 : 0)), radius: reduceMotion ? 0 : (isHovering ? 8 : 0), y: reduceMotion ? 0 : (isHovering ? 3 : 0))
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

struct DifficultyBadge: View {
    let difficulty: LessonDifficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(difficultyColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(difficultyColor.opacity(0.15))
            .clipShape(Capsule())
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }
}

struct MasteryBadge: View {
    let level: MasteryLevel
    
    var body: some View {
        Text(level.rawValue)
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(masteryColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(masteryColor.opacity(0.15))
            .clipShape(Capsule())
    }
    
    private var masteryColor: Color {
        switch level {
        case .notStarted: return XTheme.textTertiary
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return XTheme.primary
        }
    }
}

// MARK: - Lesson Detail View

struct LessonDetailView: View {
    let lesson: PracticeLesson
    let onStart: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                
                Spacer()
                
                Text("Lesson Details")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(XTheme.textPrimary)
                
                Spacer()
                
                Button("Start") { onStart() }
                    .buttonStyle(.plain)
                    .foregroundColor(XTheme.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(XTheme.surface.opacity(0.4))
            
            Divider().background(XTheme.border)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title and Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(XTheme.textPrimary)
                        
                        Text(lesson.description)
                            .font(.system(size: 13))
                            .foregroundColor(XTheme.textSecondary)
                    }
                    
                    // Metadata
                    HStack(spacing: 12) {
                        DifficultyBadge(difficulty: lesson.difficulty)
                        Text(lesson.category.rawValue)
                            .font(.system(size: 10))
                            .foregroundColor(XTheme.textSecondary)
                        Text("•")
                            .foregroundColor(XTheme.textTertiary)
                        Text("\(lesson.estimatedDurationMinutes) min")
                            .font(.system(size: 10))
                            .foregroundColor(XTheme.textSecondary)
                    }
                    
                    Divider()
                    
                    // Learning Objectives
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Learning Objectives")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(XTheme.textPrimary)
                        
                        ForEach(lesson.learningObjectives, id: \.self) { objective in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(XTheme.primary)
                                Text(objective)
                                    .font(.system(size: 11))
                                    .foregroundColor(XTheme.textSecondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Lesson Steps Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lesson Steps")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(XTheme.textPrimary)
                        
                        ForEach(Array(lesson.steps.enumerated()), id: \.offset) { index, step in
                            StepPreviewRow(step: step, index: index + 1)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct StepPreviewRow: View {
    let step: PracticeStep
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(XTheme.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.instruction)
                    .font(.system(size: 11))
                    .foregroundColor(XTheme.textPrimary)
                
                if let hint = step.hint {
                    Text(hint)
                        .font(.system(size: 9))
                        .foregroundColor(XTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Active Practice View

struct ActivePracticeView: View {
    @ObservedObject var practiceEngine: PracticeEngine
    let onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Practice Header
            PracticeSessionHeader(
                practiceEngine: practiceEngine,
                onExit: onExit
            )
            
            Divider().background(XTheme.border)
            
            if practiceEngine.isPracticeActive {
                // Active Practice Content
                VStack(spacing: 0) {
                    // Current Step Display
                    CurrentStepDisplay(practiceEngine: practiceEngine)
                        .frame(maxHeight: .infinity)
                    
                    // Feedback Bar
                    PracticeFeedbackBar(
                        feedbackMessage: practiceEngine.feedbackMessage,
                        feedbackType: practiceEngine.feedbackType
                    )
                }
            } else {
                // Session Complete / Idle State
                PracticeSessionCompleteView(
                    practiceEngine: practiceEngine,
                    onRestart: {
                        if let lesson = practiceEngine.currentLesson {
                            practiceEngine.startLesson(lesson)
                        }
                    },
                    onExit: onExit
                )
            }
        }
    }
}

struct PracticeSessionHeader: View {
    @ObservedObject var practiceEngine: PracticeEngine
    let onExit: () -> Void
    
    var body: some View {
        HStack {
            // Back Button
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(XTheme.textSecondary)
            }
            .buttonStyle(.plain)
            
            // Lesson Title
            VStack(alignment: .leading, spacing: 2) {
                Text(practiceEngine.currentLesson?.title ?? "Practice")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(XTheme.textPrimary)
                Text("Step \(practiceEngine.currentStepIndex + 1) of \(practiceEngine.currentLesson?.steps.count ?? 0)")
                    .font(.system(size: 9))
                    .foregroundColor(XTheme.textTertiary)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 8) {
                if practiceEngine.isPaused {
                    Button("Resume") {
                        practiceEngine.resumePractice()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(XTheme.primary)
                } else {
                    Button("Pause") {
                        practiceEngine.pausePractice()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(XTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(XTheme.surface.opacity(0.4))
    }
}

struct CurrentStepDisplay: View {
    @ObservedObject var practiceEngine: PracticeEngine
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Bar
            ProgressView(value: practiceEngine.progress)
                .tint(XTheme.primary)
            
            // Current Instruction
            if let step = practiceEngine.currentStep {
                VStack(spacing: 12) {
                    Text(step.instruction)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(XTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    if let context = step.harmonicContext {
                        Text(context)
                            .font(.system(size: 12))
                            .foregroundColor(XTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(XTheme.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    // Expected Chord Display
                    ChordDisplayCard(chord: step.expectedChord)
                    
                    // Guidance suggestions
                    let suggestions = practiceEngine.getGuidanceSuggestions()
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Try these similar chords:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(XTheme.textTertiary)
                            
                            ForEach(suggestions.prefix(3), id: \.chord.displayName) { suggestion in
                                HStack {
                                    Text(suggestion.chord.displayName)
                                        .font(.system(size: 9))
                                        .foregroundColor(XTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
                .background(XTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Spacer()
            
            // Timer (for challenges)
            if practiceEngine.hasActiveChallenge, let remainingTime = practiceEngine.remainingTime {
                Text("\(Int(remainingTime))s")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(remainingTime < 10 ? .red : XTheme.textPrimary)
            }
        }
        .padding(20)
    }
}

struct ChordDisplayCard: View {
    let chord: Chord
    
    var body: some View {
        VStack(spacing: 8) {
            Text(chord.displayName)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(XTheme.primary)
            
            Text(chord.quality.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(XTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(XTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(XTheme.primary, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PracticeFeedbackBar: View {
    let feedbackMessage: String
    let feedbackType: PracticeEngine.FeedbackType
    
    var body: some View {
        HStack {
            Image(systemName: feedbackIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(feedbackColor)
            
            Text(feedbackMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(feedbackColor)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(feedbackColor.opacity(0.1))
    }
    
    private var feedbackIcon: String {
        switch feedbackType {
        case .neutral: return "info.circle.fill"
        case .correct: return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        case .hint: return "lightbulb.fill"
        case .encouragement: return "hand.thumbsup.fill"
        case .perfect: return "star.fill"
        }
    }
    
    private var feedbackColor: Color {
        switch feedbackType {
        case .neutral: return XTheme.textSecondary
        case .correct: return .green
        case .incorrect: return .red
        case .hint: return .blue
        case .encouragement: return .orange
        case .perfect: return XTheme.primary
        }
    }
}

struct PracticeSessionCompleteView: View {
    @ObservedObject var practiceEngine: PracticeEngine
    let onRestart: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Completion Icon
            Image(systemName: practiceEngine.sessionAccuracy >= 0.8 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(practiceEngine.sessionAccuracy >= 0.8 ? .green : .orange)
            
            // Results
            VStack(spacing: 12) {
                Text("Session Complete")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(XTheme.textPrimary)
                
                Text("Accuracy: \(Int(practiceEngine.sessionAccuracy * 100))%")
                    .font(.system(size: 16))
                    .foregroundColor(XTheme.textSecondary)
                
                Text("Average Response: \(String(format: "%.1f", practiceEngine.averageResponseTime))s")
                    .font(.system(size: 14))
                    .foregroundColor(XTheme.textTertiary)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("Try Again") {
                    onRestart()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Exit") {
                    onExit()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Progress Dashboard View

struct ProgressDashboardView: View {
    let progressTracker: ProgressTracker
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Stats
                VStack(spacing: 16) {
                    Text("Your Progress")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(XTheme.textPrimary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Total Practice",
                            value: formatTime(progressTracker.totalPracticeTime),
                            icon: "clock.fill"
                        )
                        StatCard(
                            title: "Current Streak",
                            value: "\(progressTracker.streakDays) days",
                            icon: "flame.fill"
                        )
                        StatCard(
                            title: "Lessons Completed",
                            value: "\(progressTracker.getCompletedLessonsCount())",
                            icon: "checkmark.circle.fill"
                        )
                        StatCard(
                            title: "Mastered Lessons",
                            value: "\(progressTracker.getMasteredLessonsCount())",
                            icon: "star.fill"
                        )
                    }
                }
                .padding(20)
                .background(XTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Weekly Goal
                VStack(spacing: 12) {
                    HStack {
                        Text("Weekly Goal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(XTheme.textPrimary)
                        Spacer()
                        Text("\(progressTracker.weeklyPracticeMinutes) / \(progressTracker.weeklyGoalMinutes) min")
                            .font(.system(size: 12))
                            .foregroundColor(XTheme.textSecondary)
                    }
                    
                    ProgressView(value: progressTracker.getWeeklyProgress())
                        .tint(XTheme.primary)
                    
                    if progressTracker.isWeeklyGoalMet() {
                        Text("Goal achieved! 🎉")
                            .font(.system(size: 11))
                            .foregroundColor(XTheme.primary)
                    }
                }
                .padding(16)
                .background(XTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Recent Sessions
                VStack(spacing: 12) {
                    Text("Recent Sessions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(XTheme.textPrimary)
                    
                    ForEach(progressTracker.getRecentSessions(limit: 5)) { session in
                        SessionRow(session: session)
                    }
                }
                .padding(16)
                .background(XTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(XTheme.primary)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(XTheme.textPrimary)
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(XTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(XTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SessionRow: View {
    let session: PracticeSessionResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(session.startTime))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(XTheme.textPrimary)
                Text("\(Int(session.overallAccuracy * 100))% accuracy")
                    .font(.system(size: 9))
                    .foregroundColor(session.overallAccuracy >= 0.8 ? .green : .orange)
            }
            
            Spacer()
            
            Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(session.completed ? .green : .red)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Challenge Mode View

struct ChallengeModeView: View {
    let onStartChallenge: (PracticeChallenge) -> Void
    
    private let challenges = PracticeChallenge.factoryPresets()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Challenges")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(XTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(challenges) { challenge in
                    ChallengeCard(challenge: challenge) {
                        onStartChallenge(challenge)
                    }
                }
            }
            .padding(20)
        }
    }
}

struct ChallengeCard: View {
    let challenge: PracticeChallenge
    let onStart: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(challenge.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(XTheme.textPrimary)
                
                Spacer()
                
                if let timeLimit = challenge.timeLimitSeconds {
                    Text("\(timeLimit)s")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(XTheme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(XTheme.surface)
                        .clipShape(Capsule())
                }
            }
            
            Text(challenge.description)
                .font(.system(size: 11))
                .foregroundColor(XTheme.textSecondary)
                .lineLimit(2)
            
            HStack {
                Text("Target: \(Int(challenge.targetAccuracy * 100))% accuracy")
                    .font(.system(size: 10))
                    .foregroundColor(XTheme.textTertiary)
                
                Spacer()
                
                Button("Start Challenge") {
                    onStart()
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(XTheme.expression)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(XTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(XTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}