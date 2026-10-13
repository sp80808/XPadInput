import XCTest
@testable import XPadController

@MainActor
final class InputLearningSessionTests: XCTestCase {
    func testSuccessfulCompletionClearsSessionBeforeCallingUI() {
        let manager = ControllerManager()
        var learned: (SemanticMusicalAction, PhysicalControlInput)?
        let sessionID = manager.beginInputLearning(for: .primaryExcitation) { action, input in
            XCTAssertNil(manager.learningAction)
            learned = (action, input)
        }

        manager.completeInputLearning(
            sessionID: sessionID,
            action: .primaryExcitation,
            input: .rightStickY
        )

        XCTAssertNil(manager.learningAction)
        XCTAssertEqual(learned?.0, .primaryExcitation)
        XCTAssertEqual(learned?.1, .rightStickY)
    }

    func testCancellationClearsSessionAndSuppressesLateCompletion() {
        let manager = ControllerManager()
        var completionCount = 0
        let sessionID = manager.beginInputLearning(for: .primaryExcitation) { _, _ in
            completionCount += 1
        }

        manager.cancelInputLearning(sessionID: sessionID)
        manager.completeInputLearning(
            sessionID: sessionID,
            action: .primaryExcitation,
            input: .rightStickY
        )

        XCTAssertNil(manager.learningAction)
        XCTAssertEqual(completionCount, 0)
    }

    func testStaleCompletionCannotAffectReplacementSession() {
        let manager = ControllerManager()
        var oldCompletionCount = 0
        var newCompletionCount = 0
        let oldSessionID = manager.beginInputLearning(for: .primaryExcitation) { _, _ in
            oldCompletionCount += 1
        }
        let newSessionID = manager.beginInputLearning(for: .pitchExpression) { _, _ in
            newCompletionCount += 1
        }

        manager.completeInputLearning(
            sessionID: oldSessionID,
            action: .primaryExcitation,
            input: .rightStickY
        )

        XCTAssertEqual(manager.learningAction, .pitchExpression)
        XCTAssertEqual(oldCompletionCount, 0)
        XCTAssertEqual(newCompletionCount, 0)

        manager.completeInputLearning(
            sessionID: newSessionID,
            action: .pitchExpression,
            input: .leftStickX
        )

        XCTAssertNil(manager.learningAction)
        XCTAssertEqual(oldCompletionCount, 0)
        XCTAssertEqual(newCompletionCount, 1)
    }
}
