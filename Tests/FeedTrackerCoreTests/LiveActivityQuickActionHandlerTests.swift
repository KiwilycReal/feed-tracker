import Foundation
import XCTest
@testable import FeedTrackerCore

@MainActor
final class LiveActivityQuickActionHandlerTests: XCTestCase {
    func testStartLeftCreatesRunningStateFromIdle() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 40_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)

        let state = handler.currentState()
        XCTAssertEqual(state.activeSide, .left)
        XCTAssertEqual(state.timerStatus, .running)
    }

    func testStartRightSwitchesSideFromRunningLeft() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 50_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)
        clock.advance(seconds: 30)
        try await handler.handle(.startRight)
        clock.advance(seconds: 12)

        let state = handler.currentState()
        XCTAssertEqual(state.activeSide, .right)
        XCTAssertEqual(state.leftElapsed, 30, accuracy: 0.001)
        XCTAssertEqual(state.rightElapsed, 12, accuracy: 0.001)
        XCTAssertEqual(state.totalElapsed, 42, accuracy: 0.001)
    }

    func testStartLeftResumesFromPausedAndSwitchesSide() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 60_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startRight)
        clock.advance(seconds: 10)
        try engine.pause()
        clock.advance(seconds: 3)

        try await handler.handle(.startLeft)
        clock.advance(seconds: 7)

        let state = handler.currentState()
        XCTAssertEqual(state.activeSide, .left)
        XCTAssertEqual(state.rightElapsed, 10, accuracy: 0.001)
        XCTAssertEqual(state.leftElapsed, 7, accuracy: 0.001)
        XCTAssertEqual(state.totalElapsed, 17, accuracy: 0.001)
    }

    func testEndSessionPersistsCompletedSession() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 70_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)
        clock.advance(seconds: 18)

        let ended = try await handler.handle(.endSession, note: "ended from dynamic island")
        let session = try XCTUnwrap(ended)
        let persisted = try await repository.fetch(id: session.id)

        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.totalDuration, 18, accuracy: 0.001)
        XCTAssertEqual(session.note, "ended from dynamic island")
        XCTAssertEqual(persisted?.id, session.id)
    }

    func testStartAfterEndedSessionThrowsExplicitError() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 80_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)
        clock.advance(seconds: 5)
        _ = try await handler.handle(.endSession)

        await XCTAssertThrowsErrorAsync(try await handler.handle(.startRight)) { error in
            XCTAssertEqual(error as? LiveActivityQuickActionError, .cannotStartAfterSessionEnded)
        }
    }

    func testCurrentStateMapsTimerStatus() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 90_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        XCTAssertEqual(handler.currentState().timerStatus, .idle)

        try await handler.handle(.startLeft)
        XCTAssertEqual(handler.currentState().timerStatus, .running)

        try engine.pause()
        XCTAssertEqual(handler.currentState().timerStatus, .paused)

        try engine.resume()
        try engine.stopCurrentSide()
        XCTAssertEqual(handler.currentState().timerStatus, .stopped)

        _ = try await handler.handle(.endSession)
        XCTAssertEqual(handler.currentState().timerStatus, .ended)
    }

    func testHandleURLParsesRouterDeepLinkAndExecutesAction() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 95_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let router = LiveActivityQuickActionRouter()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository, router: router)

        try await handler.handle(url: router.url(for: .startRight))

        let state = handler.currentState()
        XCTAssertEqual(state.activeSide, .right)
        XCTAssertEqual(state.timerStatus, .running)
    }

    func testHandleURLThrowsForUnknownLink() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 96_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        let unknown = URL(string: "feedtracker://live-activity?action=do_nothing")!
        await XCTAssertThrowsErrorAsync(try await handler.handle(url: unknown)) { error in
            XCTAssertEqual(error as? LiveActivityQuickActionError, .unsupportedDeepLink)
        }
    }

    func testRouterBuildsRoundTripURLsForAllActions() {
        let router = LiveActivityQuickActionRouter()

        for action in LiveActivityQuickAction.allCases {
            let url = router.url(for: action)
            XCTAssertEqual(router.action(from: url), action)
        }
    }
}

private final class QuickActionTestClock {
    var now: Date

    init(start: Date) {
        self.now = start
    }

    func advance(seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ verify: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        verify(error)
    }
}
