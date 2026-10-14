import XCTest
import XPadCore
import XPadTheory
import XPadPractice

@MainActor
final class XPadPracticeTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// A copy of everything `ProgressTracker` publishes.
    ///
    /// `ProgressTracker.shared` is a singleton backed by `UserDefaults`, so a
    /// test that records sessions has to put the store back the way it found it
    /// instead of assuming it starts empty.
    private struct TrackerSnapshot {
        let history: [PracticeSessionResult]
        let mastery: [UUID: LessonMastery]
        let totalPracticeTime: TimeInterval
        let streakDays: Int
        let lastPracticeDate: Date?
        let weeklyPracticeMinutes: Int
    }

    private func snapshot(_ tracker: ProgressTracker) -> TrackerSnapshot {
        TrackerSnapshot(
            history: tracker.sessionHistory,
            mastery: tracker.lessonMastery,
            totalPracticeTime: tracker.totalPracticeTime,
            streakDays: tracker.streakDays,
            lastPracticeDate: tracker.lastPracticeDate,
            weeklyPracticeMinutes: tracker.weeklyPracticeMinutes
        )
    }

    private func restore(_ snapshot: TrackerSnapshot, to tracker: ProgressTracker) {
        tracker.sessionHistory = snapshot.history
        tracker.lessonMastery = snapshot.mastery
        tracker.totalPracticeTime = snapshot.totalPracticeTime
        tracker.streakDays = snapshot.streakDays
        tracker.lastPracticeDate = snapshot.lastPracticeDate
        tracker.weeklyPracticeMinutes = snapshot.weeklyPracticeMinutes
    }
    
    func testPracticeLessonCreation() throws {
        let lesson = PracticeLesson(
            title: "Test Lesson",
            description: "A test lesson",
            category: .fundamentals,
            difficulty: .beginner,
            key: .c,
            scale: Scale(root: .c, type: .major),
            steps: [
                PracticeStep(
                    instruction: "Play C major",
                    expectedChord: Chord(root: .c, quality: .major)
                )
            ]
        )
        
        XCTAssertEqual(lesson.title, "Test Lesson")
        XCTAssertEqual(lesson.steps.count, 1)
        XCTAssertEqual(lesson.category, .fundamentals)
    }
    
    func testFactoryPresets() throws {
        let presets = PracticeLesson.factoryPresets()
        XCTAssertFalse(presets.isEmpty, "Factory presets should not be empty")
        
        // Test ii-V-I major lesson
        let majorLesson = presets.first { $0.title.contains("ii-V-I") && $0.title.contains("Major") }
        XCTAssertNotNil(majorLesson, "Should have ii-V-I major lesson")
        XCTAssertEqual(majorLesson?.difficulty, .beginner)
    }
    
    func testStepResultCreation() throws {
        let result = StepResult(
            stepId: UUID(),
            playedChord: Chord(root: .c, quality: .major),
            isCorrect: true,
            timingAccuracy: 0.9,
            responseTimeSeconds: 1.5
        )
        
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.timingAccuracy, 0.9)
    }
    
    func testPracticeSessionResult() throws {
        let sessionResult = PracticeSessionResult(
            lessonId: UUID(),
            startTime: Date().addingTimeInterval(-60),
            endTime: Date(),
            stepResults: [],
            overallAccuracy: 0.85,
            averageResponseTime: 1.2,
            completed: true
        )
        
        XCTAssertTrue(sessionResult.completed)
        XCTAssertEqual(sessionResult.overallAccuracy, 0.85)
        XCTAssertGreaterThan(sessionResult.duration, 0)
    }
    
    func testProgressTrackerBasic() throws {
        let tracker = ProgressTracker.shared
        let before = snapshot(tracker)
        defer { restore(before, to: tracker) }
        let lessonId = UUID()

        // Record a session
        let sessionResult = PracticeSessionResult(
            lessonId: lessonId,
            startTime: Date().addingTimeInterval(-30),
            endTime: Date(),
            stepResults: [],
            overallAccuracy: 0.8,
            averageResponseTime: 1.0,
            completed: true
        )
        
        tracker.recordSession(sessionResult)
        
        XCTAssertEqual(tracker.totalPracticeTime, before.totalPracticeTime + sessionResult.duration, accuracy: 0.0001)
        XCTAssertEqual(tracker.sessionHistory.count, before.history.count + 1)
        XCTAssertNotNil(tracker.getLessonMastery(for: lessonId))
        XCTAssertEqual(tracker.streakDays, 1, "a session today starts a one-day streak")
        XCTAssertGreaterThanOrEqual(tracker.weeklyPracticeMinutes, Int(sessionResult.duration / 60))
    }
    
    func testLessonMastery() throws {
        let lessonId = UUID()
        let tracker = ProgressTracker.shared
        let before = snapshot(tracker)
        defer { restore(before, to: tracker) }

        let fresh = LessonMastery(lessonId: lessonId)
        XCTAssertEqual(fresh.masteryLevel, .notStarted)
        XCTAssertEqual(fresh.attemptCount, 0)
        XCTAssertEqual(fresh.averageAccuracy, 0, accuracy: 0.0001)
        XCTAssertNil(tracker.getLessonMastery(for: lessonId), "no sessions means no mastery record yet")

        // Drive the public API: mastery is derived from recorded sessions, not
        // written into the tracker directly.
        for _ in 0..<3 {
            tracker.recordSession(
                PracticeSessionResult(
                    lessonId: lessonId,
                    startTime: Date(),
                    endTime: Date().addingTimeInterval(60),
                    stepResults: [],
                    overallAccuracy: 0.85,
                    averageResponseTime: 0.9,
                    completed: true
                )
            )
        }

        let mastery = try XCTUnwrap(tracker.getLessonMastery(for: lessonId))
        XCTAssertEqual(mastery.attemptCount, 3)
        XCTAssertEqual(mastery.completedCount, 3)
        XCTAssertEqual(mastery.proficientCompletions, 3, "85% counts as proficient")
        XCTAssertEqual(mastery.perfectCompletions, 0, "85% is below the perfect threshold")
        XCTAssertEqual(mastery.averageAccuracy, 0.85, accuracy: 0.0001)
        XCTAssertEqual(mastery.averageResponseTime, 0.9, accuracy: 0.0001)
        XCTAssertEqual(mastery.masteryLevel, .advanced, "three proficient completions reaches advanced")
        XCTAssertNotEqual(mastery.masteryLevel, .notStarted)

        // An incomplete attempt is recorded but does not count as a completion.
        tracker.recordSession(
            PracticeSessionResult(
                lessonId: lessonId,
                startTime: Date(),
                endTime: Date().addingTimeInterval(30),
                stepResults: [],
                overallAccuracy: 0.2,
                averageResponseTime: 2.0,
                completed: false
            )
        )
        let afterAbandon = try XCTUnwrap(tracker.getLessonMastery(for: lessonId))
        XCTAssertEqual(afterAbandon.attemptCount, 4)
        XCTAssertEqual(afterAbandon.completedCount, 3)
        XCTAssertEqual(afterAbandon.masteryLevel, .advanced, "an abandoned attempt does not promote a level")
        XCTAssertGreaterThanOrEqual(tracker.getCompletedLessonsCount(), 1, "the lesson now counts as started")
    }
    
    func testChallengeCreation() throws {
        let challenge = PracticeChallenge(
            type: .guessNextChord,
            title: "Test Challenge",
            description: "A test challenge",
            timeLimitSeconds: 30,
            targetAccuracy: 0.8,
            baseProgression: Progression(scale: Scale(root: .c, type: .major))
        )
        
        XCTAssertEqual(challenge.type, .guessNextChord)
        XCTAssertEqual(challenge.timeLimitSeconds, 30)
        XCTAssertEqual(challenge.targetAccuracy, 0.8)
    }
    
    func testLessonDifficultyOrder() throws {
        XCTAssertEqual(LessonDifficulty.beginner.sortOrder, 0)
        XCTAssertEqual(LessonDifficulty.intermediate.sortOrder, 1)
        XCTAssertEqual(LessonDifficulty.advanced.sortOrder, 2)
        XCTAssertEqual(LessonDifficulty.expert.sortOrder, 3)
    }
    
    func testMasteryLevelOrder() throws {
        XCTAssertEqual(MasteryLevel.notStarted.sortOrder, 0)
        XCTAssertEqual(MasteryLevel.beginner.sortOrder, 1)
        XCTAssertEqual(MasteryLevel.intermediate.sortOrder, 2)
        XCTAssertEqual(MasteryLevel.advanced.sortOrder, 3)
        XCTAssertEqual(MasteryLevel.expert.sortOrder, 4)
    }
}