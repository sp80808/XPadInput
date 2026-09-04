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
        
        // Initial state
        XCTAssertEqual(tracker.streakDays, 0)
        XCTAssertEqual(tracker.totalPracticeTime, 0)
        
        // Record a session
        let sessionResult = PracticeSessionResult(
            lessonId: UUID(),
            startTime: Date().addingTimeInterval(-30),
            endTime: Date(),
            stepResults: [],
            overallAccuracy: 0.8,
            averageResponseTime: 1.0,
            completed: true
        )
        
        tracker.recordSession(sessionResult)
        
        XCTAssertGreaterThan(tracker.totalPracticeTime, 0)
        XCTAssertEqual(tracker.streakDays, 1)
    }
    
    func testLessonMastery() throws {
        let lessonId = UUID()
        var mastery = LessonMastery(lessonId: lessonId)
        
        XCTAssertEqual(mastery.masteryLevel, .notStarted)
        XCTAssertEqual(mastery.attemptCount, 0)
        
        // Simulate some attempts
        mastery.attemptCount = 5
        mastery.completedCount = 3
        mastery.proficientCompletions = 2
        mastery.perfectCompletions = 1
        mastery.totalAccuracy = 3.5 // Average 0.7
        
        let tracker = ProgressTracker.shared
        tracker.lessonMastery[lessonId] = mastery
        
        // Get updated mastery
        if let updatedMastery = tracker.getLessonMastery(for: lessonId) {
            XCTAssertNotEqual(updatedMastery.masteryLevel, .notStarted)
        }
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