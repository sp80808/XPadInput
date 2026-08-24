import Foundation
import XPadCore
import XPadTheory

// Import ChordSuggestion for the guidance suggestions feature
// This should be available from XPadTheory

/// Real-time evaluation engine for practice sessions
@MainActor
public final class PracticeEngine: ObservableObject {
    // MARK: - Published State
    @Published public var currentLesson: PracticeLesson?
    @Published public var currentStepIndex: Int = 0
    @Published public var isPracticeActive: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var currentResult: StepResult?
    @Published public var sessionResults: [StepResult] = []
    @Published public var feedbackMessage: String = ""
    @Published public var feedbackType: FeedbackType = .neutral
    @Published public var timingAccuracy: Double = 1.0
    @Published public var sessionStartTime: Date?
    @Published public var elapsedTime: TimeInterval = 0
    
    // MARK: - Private State
    private var stepStartTime: Date?
    private var currentChallenge: PracticeChallenge?
    private var challengeTimer: Timer?
    private var challengeRemainingTime: TimeInterval = 0
    private var sessionTimer: Timer?
    private var advanceWorkItem: DispatchWorkItem?
    private var hintWorkItem: DispatchWorkItem?
    private let evaluationTolerance: Double = 0.8 // 80% match required for correctness
    
    // MARK: - Feedback Types
    public enum FeedbackType {
        case neutral
        case correct
        case incorrect
        case hint
        case encouragement
        case perfect
    }
    
    // MARK: - Initialization
    public init() {}
    
    // MARK: - Lesson Management
    public func startLesson(_ lesson: PracticeLesson) {
        cancelPendingTimers()
        currentLesson = lesson
        currentStepIndex = 0
        sessionResults = []
        isPracticeActive = true
        isPaused = false
        sessionStartTime = Date()
        elapsedTime = 0
        feedbackMessage = "Lesson started: \(lesson.title)"
        feedbackType = .neutral
        
        startSessionTimer()
        beginCurrentStep()
    }
    
    public func startChallenge(_ challenge: PracticeChallenge) {
        cancelPendingTimers()
        currentChallenge = challenge
        currentLesson = nil
        currentStepIndex = 0
        sessionResults = []
        isPracticeActive = true
        isPaused = false
        sessionStartTime = Date()
        elapsedTime = 0
        challengeRemainingTime = 0
        feedbackMessage = "Challenge started: \(challenge.title)"
        feedbackType = .neutral
        
        startSessionTimer()
        
        if let timeLimit = challenge.timeLimitSeconds {
            startChallengeTimer(timeLimit: TimeInterval(timeLimit))
        }
        
        beginCurrentStep()
    }
    
    public func pausePractice() {
        isPaused = true
        advanceWorkItem?.cancel()
        advanceWorkItem = nil
        hintWorkItem?.cancel()
        hintWorkItem = nil
        sessionTimer?.invalidate()
        challengeTimer?.invalidate()
        feedbackMessage = "Practice paused"
        feedbackType = .neutral
    }
    
    public func resumePractice() {
        isPaused = false
        startSessionTimer()
        
        if currentChallenge != nil {
            if challengeRemainingTime > 0 {
                startChallengeTimer(timeLimit: challengeRemainingTime)
            }
        }
        
        feedbackMessage = "Practice resumed"
        feedbackType = .neutral
    }
    
    public func stopPractice() {
        cancelPendingTimers()
        isPracticeActive = false
        isPaused = false
        stepStartTime = nil
        challengeRemainingTime = 0
        
        if let startTime = sessionStartTime {
            let sessionResult = PracticeSessionResult(
                lessonId: currentLesson?.id ?? UUID(),
                startTime: startTime,
                endTime: Date(),
                stepResults: sessionResults,
                overallAccuracy: calculateOverallAccuracy(),
                averageResponseTime: calculateAverageResponseTime(),
                completed: currentStepIndex >= (currentLesson?.steps.count ?? 0)
            )
            // Store result for progress tracking
            ProgressTracker.shared.recordSession(sessionResult)
        }
        
        feedbackMessage = "Practice session ended"
        feedbackType = .neutral
    }
    
    public func resetPractice() {
        cancelPendingTimers()
        currentLesson = nil
        currentChallenge = nil
        currentStepIndex = 0
        sessionResults = []
        isPracticeActive = false
        isPaused = false
        currentResult = nil
        feedbackMessage = ""
        feedbackType = .neutral
        timingAccuracy = 1.0
        sessionStartTime = nil
        elapsedTime = 0
        stepStartTime = nil
        challengeRemainingTime = 0
    }
    
    private func cancelPendingTimers() {
        advanceWorkItem?.cancel()
        advanceWorkItem = nil
        hintWorkItem?.cancel()
        hintWorkItem = nil
        sessionTimer?.invalidate()
        sessionTimer = nil
        challengeTimer?.invalidate()
        challengeTimer = nil
    }
    
    // MARK: - Step Management
    private func beginCurrentStep() {
        advanceWorkItem?.cancel()
        advanceWorkItem = nil
        hintWorkItem?.cancel()
        hintWorkItem = nil
        
        guard let lesson = currentLesson,
              currentStepIndex < lesson.steps.count else {
            completeLesson()
            return
        }
        
        stepStartTime = Date()
        let step = lesson.steps[currentStepIndex]
        feedbackMessage = step.instruction
        feedbackType = .neutral
        
        if let hint = step.hint {
            let stepId = step.id
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self,
                      self.isPracticeActive,
                      self.currentStepIndex < lesson.steps.count,
                      lesson.steps[self.currentStepIndex].id == stepId,
                      self.currentResult == nil else { return }
                self.feedbackMessage = hint
                self.feedbackType = .hint
            }
            hintWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
        }
    }
    
    public func advanceToNextStep() {
        advanceWorkItem?.cancel()
        advanceWorkItem = nil
        guard let lesson = currentLesson else { return }
        
        currentStepIndex += 1
        
        if currentStepIndex >= lesson.steps.count {
            completeLesson()
        } else {
            beginCurrentStep()
        }
    }
    
    public func goToStep(_ index: Int) {
        advanceWorkItem?.cancel()
        advanceWorkItem = nil
        guard let lesson = currentLesson,
              index >= 0 && index < lesson.steps.count else { return }
        
        currentStepIndex = index
        currentResult = nil
        beginCurrentStep()
    }
    
    private func completeLesson() {
        let accuracy = calculateOverallAccuracy()
        let avgResponseTime = calculateAverageResponseTime()
        
        if accuracy >= 0.9 {
            feedbackMessage = "Excellent! You mastered this lesson! (Accuracy: \(Int(accuracy * 100))%)"
            feedbackType = .perfect
        } else if accuracy >= 0.8 {
            feedbackMessage = "Great job! Keep practicing to improve. (Accuracy: \(Int(accuracy * 100))%)"
            feedbackType = .correct
        } else if accuracy >= 0.6 {
            feedbackMessage = "Good effort! Review the difficult sections. (Accuracy: \(Int(accuracy * 100))%)"
            feedbackType = .encouragement
        } else {
            feedbackMessage = "Keep practicing! Review the lesson material and try again. (Accuracy: \(Int(accuracy * 100))%)"
            feedbackType = .encouragement
        }
        
        isPracticeActive = false
        sessionTimer?.invalidate()
        challengeTimer?.invalidate()
        
        if let startTime = sessionStartTime {
            let sessionResult = PracticeSessionResult(
                lessonId: currentLesson?.id ?? UUID(),
                startTime: startTime,
                endTime: Date(),
                stepResults: sessionResults,
                overallAccuracy: accuracy,
                averageResponseTime: avgResponseTime,
                completed: true
            )
            ProgressTracker.shared.recordSession(sessionResult)
        }
    }
    
    // MARK: - Chord Evaluation
    public func evaluateChordInput(_ chord: Chord) {
        guard isPracticeActive, !isPaused else { return }
        guard advanceWorkItem == nil else { return }
        guard let lesson = currentLesson,
              currentStepIndex < lesson.steps.count else { return }
        
        let stepIndex = currentStepIndex
        let lessonId = lesson.id
        let step = lesson.steps[stepIndex]
        let responseTime = stepStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // Evaluate chord correctness
        let isCorrect = evaluateChordCorrectness(chord, expected: step.expectedChord)
        
        // Calculate timing accuracy (ideal response time is 1-2 seconds per beat)
        let idealResponseTime = step.durationBeats * 0.5
        let timingAccuracy = calculateTimingAccuracy(responseTime: responseTime, ideal: idealResponseTime)
        
        // Create step result
        let result = StepResult(
            stepId: step.id,
            playedChord: chord,
            isCorrect: isCorrect,
            timingAccuracy: timingAccuracy,
            responseTimeSeconds: responseTime
        )
        
        currentResult = result
        sessionResults.append(result)
        self.timingAccuracy = timingAccuracy
        
        // Provide feedback
        if isCorrect {
            if timingAccuracy >= 0.9 {
                feedbackMessage = "Perfect! Great timing and accuracy."
                feedbackType = .perfect
            } else if timingAccuracy >= 0.7 {
                feedbackMessage = "Correct! Work on timing for perfection."
                feedbackType = .correct
            } else {
                feedbackMessage = "Correct chord, but try to respond faster."
                feedbackType = .correct
            }
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self,
                      self.isPracticeActive,
                      self.currentLesson?.id == lessonId,
                      self.currentStepIndex == stepIndex else { return }
                self.advanceWorkItem = nil
                self.advanceToNextStep()
            }
            advanceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        } else {
            let suggestion = generateIncorrectChordSuggestion(played: chord, expected: step.expectedChord)
            feedbackMessage = "Not quite. \(suggestion)"
            feedbackType = .incorrect
        }
    }
    
    private func evaluateChordCorrectness(_ played: Chord, expected: Chord) -> Bool {
        // Exact match
        if played.root == expected.root && played.quality == expected.quality {
            return true
        }
        
        // Root match with compatible quality (for easier learning)
        if played.root == expected.root {
            let compatibleQualities: Set<ChordQuality> = [.major, .major7, .major9, .add9]
            let minorCompatible: Set<ChordQuality> = [.minor, .minor7, .minor9]
            
            if compatibleQualities.contains(expected.quality) && compatibleQualities.contains(played.quality) {
                return true
            }
            if minorCompatible.contains(expected.quality) && minorCompatible.contains(played.quality) {
                return true
            }
        }
        
        // Enharmonic equivalence (different spelling, same pitch classes)
        let playedPitches = Set(played.pitchClasses)
        let expectedPitches = Set(expected.pitchClasses)
        let intersection = playedPitches.intersection(expectedPitches)
        let matchPercentage = Double(intersection.count) / Double(max(playedPitches.count, expectedPitches.count))
        
        return matchPercentage >= evaluationTolerance
    }
    
    private func calculateTimingAccuracy(responseTime: TimeInterval, ideal: TimeInterval) -> Double {
        guard ideal > 0 else { return 1.0 }
        
        let ratio = responseTime / ideal
        if ratio <= 1.0 {
            // Response was faster than ideal - still good
            return 1.0 - (ratio * 0.1) // Slight penalty for being too fast
        } else if ratio <= 1.5 {
            // Within acceptable range
            return 1.0 - ((ratio - 1.0) * 0.3)
        } else if ratio <= 2.0 {
            // Slow but acceptable
            return 0.7 - ((ratio - 1.5) * 0.4)
        } else {
            // Too slow
            return max(0.1, 0.5 - ((ratio - 2.0) * 0.2))
        }
    }
    
    private func generateIncorrectChordSuggestion(played: Chord, expected: Chord) -> String {
        if played.root != expected.root {
            return "Try the \(expected.root.displayName) note instead of \(played.root.displayName)."
        } else if played.quality != expected.quality {
            return "Correct root, but change the chord quality to \(expected.quality.rawValue)."
        } else {
            return "Close! Try adjusting your voicing slightly."
        }
    }
    
    // MARK: - Challenge Mode
    private func startChallengeTimer(timeLimit: TimeInterval) {
        challengeTimer?.invalidate()
        challengeRemainingTime = timeLimit
        challengeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.challengeRemainingTime -= 1.0
                if self.challengeRemainingTime <= 0 {
                    timer.invalidate()
                    self.completeChallenge(timeExpired: true)
                }
            }
        }
    }
    
    private func completeChallenge(timeExpired: Bool) {
        challengeTimer?.invalidate()
        sessionTimer?.invalidate()
        
        let accuracy = calculateOverallAccuracy()
        
        if timeExpired {
            feedbackMessage = "Time's up! Final accuracy: \(Int(accuracy * 100))%"
        } else {
            feedbackMessage = "Challenge complete! Accuracy: \(Int(accuracy * 100))%"
        }
        
        feedbackType = accuracy >= currentChallenge?.targetAccuracy ?? 0.8 ? .perfect : .encouragement
        isPracticeActive = false
        
        if let startTime = sessionStartTime {
            let sessionResult = PracticeSessionResult(
                lessonId: currentChallenge?.id ?? UUID(),
                startTime: startTime,
                endTime: Date(),
                stepResults: sessionResults,
                overallAccuracy: accuracy,
                averageResponseTime: calculateAverageResponseTime(),
                completed: !timeExpired
            )
            ProgressTracker.shared.recordSession(sessionResult)
        }
    }
    
    // MARK: - Session Timer
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPracticeActive, !self.isPaused else { return }
                if let startTime = self.sessionStartTime {
                    self.elapsedTime = Date().timeIntervalSince(startTime)
                }
            }
        }
    }
    
    // MARK: - Calculations
    private func calculateOverallAccuracy() -> Double {
        guard !sessionResults.isEmpty else { return 0 }
        let correctCount = sessionResults.filter { $0.isCorrect }.count
        return Double(correctCount) / Double(sessionResults.count)
    }
    
    private func calculateAverageResponseTime() -> Double {
        guard !sessionResults.isEmpty else { return 0 }
        let totalTime = sessionResults.reduce(0) { $0 + $1.responseTimeSeconds }
        return totalTime / Double(sessionResults.count)
    }
    
    // MARK: - Computed Properties
    public var currentStep: PracticeStep? {
        guard let lesson = currentLesson,
              currentStepIndex < lesson.steps.count else { return nil }
        return lesson.steps[currentStepIndex]
    }
    
    public var progress: Double {
        guard let lesson = currentLesson else { return 0 }
        return Double(currentStepIndex) / Double(max(1, lesson.steps.count))
    }
    
    public var remainingTime: TimeInterval? {
        guard currentChallenge != nil else { return nil }
        return max(0, challengeRemainingTime)
    }
    
    public var hasActiveChallenge: Bool {
        currentChallenge != nil
    }
    
    public var isLastStep: Bool {
        guard let lesson = currentLesson else { return false }
        return currentStepIndex >= lesson.steps.count - 1
    }
    
    public var sessionAccuracy: Double {
        calculateOverallAccuracy()
    }
    
    public var averageResponseTime: Double {
        calculateAverageResponseTime()
    }
}

// MARK: - Practice Engine Extensions

extension PracticeEngine {
    /// Get hint for current step
    public func getCurrentStepHint() -> String? {
        currentStep?.hint
    }
    
    /// Get harmonic context for current step
    public func getCurrentStepContext() -> String? {
        currentStep?.harmonicContext
    }
    
    /// Check if current response is on track
    public func isCurrentResponseOnTrack(chord: Chord) -> Bool {
        guard let step = currentStep else { return false }
        
        // Check if at least the root is correct
        if chord.root == step.expectedChord.root {
            return true
        }
        
        // Check if there are common tones
        let playedPitches = Set(chord.pitchClasses)
        let expectedPitches = Set(step.expectedChord.pitchClasses)
        let commonTones = playedPitches.intersection(expectedPitches)
        
        return !commonTones.isEmpty
    }
    
    /// Get harmonic suggestions for the current step to guide users
    public func getGuidanceSuggestions() -> [ChordSuggestion] {
        guard let step = currentStep else { return [] }
        
        let engine = HarmonicSuggestionEngine()
        let suggestions = engine.suggestions(for: step.expectedChord, in: currentLesson?.scale ?? Scale(root: .c, type: .major))
        
        // Return top 3 suggestions sorted by score
        return Array(suggestions.prefix(3))
    }
}