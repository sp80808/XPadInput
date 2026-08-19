import Foundation
import XPadCore

/// Tracks user progress across practice sessions and provides analytics
@MainActor
public final class ProgressTracker: ObservableObject {
    public static let shared = ProgressTracker()
    
    // MARK: - Published State
    @Published public var sessionHistory: [PracticeSessionResult] = []
    @Published public var lessonMastery: [UUID: LessonMastery] = [:]
    @Published public var totalPracticeTime: TimeInterval = 0
    @Published public var streakDays: Int = 0
    @Published public var lastPracticeDate: Date?
    @Published public var weeklyGoalMinutes: Int = 30
    @Published public var weeklyPracticeMinutes: Int = 0
    
    // MARK: - Private State
    private let userDefaultsKey = "com.xpadinput.progresstracker"
    private let maxHistoryCount = 100
    
    // MARK: - Initialization
    private init() {
        loadProgress()
    }
    
    // MARK: - Session Recording
    public func recordSession(_ result: PracticeSessionResult) {
        sessionHistory.append(result)
        
        // Keep only recent history
        if sessionHistory.count > maxHistoryCount {
            sessionHistory = Array(sessionHistory.suffix(maxHistoryCount))
        }
        
        // Update total practice time
        totalPracticeTime += result.duration
        
        // Update lesson mastery
        updateLessonMastery(for: result.lessonId, with: result)
        
        // Update streak and weekly practice
        updateStreak(result.endTime)
        updateWeeklyPractice(result.duration)
        
        // Save progress
        saveProgress()
    }
    
    // MARK: - Lesson Mastery
    private func updateLessonMastery(for lessonId: UUID, with result: PracticeSessionResult) {
        var mastery = lessonMastery[lessonId] ?? LessonMastery(lessonId: lessonId)
        
        mastery.attemptCount += 1
        mastery.totalAccuracy += result.overallAccuracy
        mastery.averageResponseTime = (mastery.averageResponseTime * Double(mastery.completedCount) + result.averageResponseTime) / Double(mastery.completedCount + 1)
        
        if result.completed {
            mastery.completedCount += 1
            if result.overallAccuracy >= 0.9 {
                mastery.perfectCompletions += 1
            }
            if result.overallAccuracy >= 0.8 {
                mastery.proficientCompletions += 1
            }
        }
        
        // Update mastery level
        mastery.masteryLevel = calculateMasteryLevel(mastery)
        
        lessonMastery[lessonId] = mastery
    }
    
    private func calculateMasteryLevel(_ mastery: LessonMastery) -> MasteryLevel {
        let proficiencyRate = mastery.attemptCount > 0 ? Double(mastery.proficientCompletions) / Double(mastery.attemptCount) : 0
        let perfectRate = mastery.attemptCount > 0 ? Double(mastery.perfectCompletions) / Double(mastery.attemptCount) : 0
        
        if mastery.completedCount >= 5 && proficiencyRate >= 0.8 && perfectRate >= 0.5 {
            return .expert
        } else if mastery.completedCount >= 3 && proficiencyRate >= 0.7 {
            return .advanced
        } else if mastery.completedCount >= 1 && proficiencyRate >= 0.6 {
            return .intermediate
        } else if mastery.attemptCount >= 1 {
            return .beginner
        } else {
            return .notStarted
        }
    }
    
    // MARK: - Streak Tracking
    private func updateStreak(_ date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        
        if let lastDate = lastPracticeDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysBetween == 1 {
                streakDays += 1
            } else if daysBetween > 1 {
                streakDays = 1
            }
            // If daysBetween == 0, same day, don't change streak
        } else {
            streakDays = 1
        }
        
        lastPracticeDate = date
    }
    
    // MARK: - Weekly Practice Tracking
    private func updateWeeklyPractice(_ duration: TimeInterval) {
        let now = Date()
        
        // Filter sessions from current week (simplified - using last 7 days)
        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let currentWeekSessions = sessionHistory.filter { session in
            session.startTime >= weekAgo
        }
        
        weeklyPracticeMinutes = Int(currentWeekSessions.reduce(0) { $0 + $1.duration } / 60)
    }
    
    // MARK: - Analytics
    public func getLessonMastery(for lessonId: UUID) -> LessonMastery? {
        lessonMastery[lessonId]
    }
    
    public func getRecentSessions(limit: Int = 10) -> [PracticeSessionResult] {
        Array(sessionHistory.suffix(limit)).reversed()
    }
    
    public func getAverageAccuracy() -> Double {
        guard !sessionHistory.isEmpty else { return 0 }
        return sessionHistory.reduce(0) { $0 + $1.overallAccuracy } / Double(sessionHistory.count)
    }
    
    public func getAverageResponseTime() -> TimeInterval {
        guard !sessionHistory.isEmpty else { return 0 }
        return sessionHistory.reduce(0) { $0 + $1.averageResponseTime } / Double(sessionHistory.count)
    }
    
    public func getCompletedLessonsCount() -> Int {
        lessonMastery.values.filter { $0.masteryLevel != .notStarted }.count
    }
    
    public func getMasteredLessonsCount() -> Int {
        lessonMastery.values.filter { $0.masteryLevel == .expert }.count
    }
    
    public func getWeeklyProgress() -> Double {
        guard weeklyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(weeklyPracticeMinutes) / Double(weeklyGoalMinutes))
    }
    
    public func getCategoryProgress(category: LessonCategory) -> CategoryProgress {
        let categoryLessons = lessonMastery.values.filter { mastery in
            // This would need lesson data, simplified for now
            return true
        }
        
        let mastered = categoryLessons.filter { $0.masteryLevel == .expert }.count
        let inProgress = categoryLessons.filter { $0.masteryLevel == .intermediate || $0.masteryLevel == .advanced }.count
        let total = categoryLessons.count
        
        return CategoryProgress(
            category: category,
            masteredCount: mastered,
            inProgressCount: inProgress,
            totalCount: total
        )
    }
    
    public func getImprovementTrend(for lessonId: UUID, sessions: Int = 5) -> ImprovementTrend {
        let lessonSessions = sessionHistory.filter { $0.lessonId == lessonId }
        let recentSessions = Array(lessonSessions.suffix(sessions))
        
        guard recentSessions.count >= 2 else {
            return ImprovementTrend(direction: .insufficientData, change: 0)
        }
        
        let firstHalf = recentSessions.prefix(recentSessions.count / 2)
        let secondHalf = recentSessions.suffix(recentSessions.count / 2)
        
        let firstAvg = firstHalf.reduce(0) { $0 + $1.overallAccuracy } / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0) { $0 + $1.overallAccuracy } / Double(secondHalf.count)
        
        let change = secondAvg - firstAvg
        
        if change > 0.1 {
            return ImprovementTrend(direction: .improving, change: change)
        } else if change < -0.1 {
            return ImprovementTrend(direction: .declining, change: change)
        } else {
            return ImprovementTrend(direction: .stable, change: change)
        }
    }
    
    // MARK: - Goal Management
    public func setWeeklyGoal(_ minutes: Int) {
        weeklyGoalMinutes = max(5, min(120, minutes))
        saveProgress()
    }
    
    public func isWeeklyGoalMet() -> Bool {
        weeklyPracticeMinutes >= weeklyGoalMinutes
    }
    
    // MARK: - Data Persistence
    private func saveProgress() {
        let sessionHistoryData = sessionHistory.map { SessionResultData(from: $0) }
        let data = ProgressData(
            sessionHistoryData: sessionHistoryData,
            lessonMastery: lessonMastery,
            totalPracticeTime: totalPracticeTime,
            streakDays: streakDays,
            lastPracticeDate: lastPracticeDate,
            weeklyGoalMinutes: weeklyGoalMinutes
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadProgress() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(ProgressData.self, from: data) else {
            return
        }
        
        sessionHistory = decoded.sessionHistoryData.map { $0.toSessionResult() }
        lessonMastery = decoded.lessonMastery
        totalPracticeTime = decoded.totalPracticeTime
        streakDays = decoded.streakDays
        lastPracticeDate = decoded.lastPracticeDate
        weeklyGoalMinutes = decoded.weeklyGoalMinutes
        
        // Recalculate weekly practice based on loaded history
        updateWeeklyPractice(0)
    }
    
    public func resetProgress() {
        sessionHistory = []
        lessonMastery = [:]
        totalPracticeTime = 0
        streakDays = 0
        lastPracticeDate = nil
        weeklyPracticeMinutes = 0
        saveProgress()
    }
}

// MARK: - Supporting Types

public struct LessonMastery: Codable, Sendable {
    public let lessonId: UUID
    public var attemptCount: Int
    public var completedCount: Int
    public var proficientCompletions: Int
    public var perfectCompletions: Int
    public var totalAccuracy: Double
    public var averageResponseTime: TimeInterval
    public var masteryLevel: MasteryLevel
    
    public init(lessonId: UUID) {
        self.lessonId = lessonId
        self.attemptCount = 0
        self.completedCount = 0
        self.proficientCompletions = 0
        self.perfectCompletions = 0
        self.totalAccuracy = 0.0
        self.averageResponseTime = 0.0
        self.masteryLevel = .notStarted
    }
    
    public var averageAccuracy: Double {
        guard attemptCount > 0 else { return 0.0 }
        return totalAccuracy / Double(attemptCount)
    }
}

public enum MasteryLevel: String, CaseIterable, Codable, Sendable {
    case notStarted = "Not Started"
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    
    public var sortOrder: Int {
        switch self {
        case .notStarted: return 0
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        }
    }
}

public enum TrendDirection: String, Codable, Sendable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
    case insufficientData = "Insufficient Data"
}

public struct ImprovementTrend: Codable, Sendable {
    public let direction: TrendDirection
    public let change: Double
}

public struct CategoryProgress: Identifiable, Codable, Sendable {
    public var id = UUID()
    public let category: LessonCategory
    public let masteredCount: Int
    public let inProgressCount: Int
    public let totalCount: Int
    
    public var progressPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(masteredCount + inProgressCount) / Double(totalCount)
    }
}

// MARK: - Persistence Data

private struct ProgressData: Codable {
    let sessionHistoryData: [SessionResultData]
    let lessonMastery: [UUID: LessonMastery]
    let totalPracticeTime: TimeInterval
    let streakDays: Int
    let lastPracticeDate: Date?
    let weeklyGoalMinutes: Int
    
    init(sessionHistoryData: [SessionResultData], lessonMastery: [UUID: LessonMastery], totalPracticeTime: TimeInterval, streakDays: Int, lastPracticeDate: Date?, weeklyGoalMinutes: Int) {
        self.sessionHistoryData = sessionHistoryData
        self.lessonMastery = lessonMastery
        self.totalPracticeTime = totalPracticeTime
        self.streakDays = streakDays
        self.lastPracticeDate = lastPracticeDate
        self.weeklyGoalMinutes = weeklyGoalMinutes
    }
}

private struct SessionResultData: Codable {
    let id: UUID
    let lessonId: UUID
    let startTime: Date
    let endTime: Date
    let stepResultsData: [StepResultData]
    let overallAccuracy: Double
    let averageResponseTime: Double
    let completed: Bool
    
    init(from result: PracticeSessionResult) {
        self.id = result.id
        self.lessonId = result.lessonId
        self.startTime = result.startTime
        self.endTime = result.endTime
        self.stepResultsData = result.stepResults.map { StepResultData(from: $0) }
        self.overallAccuracy = result.overallAccuracy
        self.averageResponseTime = result.averageResponseTime
        self.completed = result.completed
    }
    
    func toSessionResult() -> PracticeSessionResult {
        PracticeSessionResult(
            id: id,
            lessonId: lessonId,
            startTime: startTime,
            endTime: endTime,
            stepResults: stepResultsData.map { $0.toStepResult() },
            overallAccuracy: overallAccuracy,
            averageResponseTime: averageResponseTime,
            completed: completed
        )
    }
}

private struct StepResultData: Codable {
    let id: UUID
    let stepId: UUID
    let playedChordData: ChordData
    let isCorrect: Bool
    let timingAccuracy: Double
    let responseTimeSeconds: Double
    let timestamp: Date
    
    init(from result: StepResult) {
        self.id = result.id
        self.stepId = result.stepId
        self.playedChordData = ChordData(from: result.playedChord)
        self.isCorrect = result.isCorrect
        self.timingAccuracy = result.timingAccuracy
        self.responseTimeSeconds = result.responseTimeSeconds
        self.timestamp = result.timestamp
    }
    
    func toStepResult() -> StepResult {
        StepResult(
            id: id,
            stepId: stepId,
            playedChord: playedChordData.toChord(),
            isCorrect: isCorrect,
            timingAccuracy: timingAccuracy,
            responseTimeSeconds: responseTimeSeconds,
            timestamp: timestamp
        )
    }
}

private struct ChordData: Codable {
    let root: Int
    let quality: String
    
    init(from chord: Chord) {
        self.root = chord.root.rawValue
        self.quality = chord.quality.rawValue
    }
    
    func toChord() -> Chord {
        Chord(root: PitchClass.allCases[root], quality: ChordQuality(rawValue: quality) ?? .major)
    }
}