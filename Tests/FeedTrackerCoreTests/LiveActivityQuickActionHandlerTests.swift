import Foundation
import XCTest
@testable import FeedTrackerCore

@MainActor
final class LiveActivityQuickActionHandlerTests: XCTestCase {
    func testSwitchSideTogglesFromRunningState() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 40_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)
        clock.advance(seconds: 30)

        try await handler.handle(.switchSide)
        clock.advance(seconds: 12)

        let state = handler.currentState()
        XCTAssertEqual(state.activeSide, .right)
        XCTAssertEqual(state.leftElapsed, 30, accuracy: 0.001)
        XCTAssertEqual(state.rightElapsed, 12, accuracy: 0.001)
    }

    func testPauseSessionTogglesToResumeWhenAlreadyPaused() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 50_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startRight)
        clock.advance(seconds: 10)
        try await handler.handle(.pauseSession)

        let pausedSnapshot = handler.currentState(at: clock.now)
        XCTAssertEqual(pausedSnapshot.timerStatus, .paused)
        XCTAssertEqual(pausedSnapshot.rightElapsed, 10, accuracy: 0.001)

        try await handler.handle(.pauseSession)
        let resumedSnapshot = handler.currentState(at: clock.now)
        XCTAssertEqual(resumedSnapshot.timerStatus, .running)
        XCTAssertEqual(resumedSnapshot.activeSide, .right)

        clock.advance(seconds: 15)
        let advancedSnapshot = handler.currentState(at: clock.now)
        XCTAssertEqual(advancedSnapshot.rightElapsed, 25, accuracy: 0.001)
    }

    func testTerminateSessionPersistsCompletedSession() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 70_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)
        let activeSessions = try await repository.fetchAll()
        let activeSessionID = try XCTUnwrap(activeSessions.first?.id)
        clock.advance(seconds: 18)

        let ended = try await handler.handle(.terminateSession, note: "ended from live activity")
        let session = try XCTUnwrap(ended)
        let persisted = try await repository.fetch(id: session.id)

        XCTAssertEqual(session.id, activeSessionID)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.totalDuration, 18, accuracy: 0.001)
        XCTAssertEqual(session.note, "ended from live activity")
        XCTAssertEqual(persisted?.id, session.id)
    }

    func testSwitchAndPausePersistAuthoritativeActiveSessionState() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 60_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)
        let startedSessions = try await repository.fetchAll()
        let started = try XCTUnwrap(startedSessions.first)
        XCTAssertEqual(started.status, .active)

        clock.advance(seconds: 12)
        try await handler.handle(.switchSide)
        let switchedRecord = try await repository.fetch(id: started.id)
        let switched = try XCTUnwrap(switchedRecord)
        XCTAssertEqual(switched.status, .active)
        XCTAssertEqual(switched.leftDuration, 12, accuracy: 0.001)

        clock.advance(seconds: 7)
        try await handler.handle(.pauseSession)
        let pausedRecord = try await repository.fetch(id: started.id)
        let paused = try XCTUnwrap(pausedRecord)
        XCTAssertEqual(paused.status, .paused)
        XCTAssertEqual(paused.leftDuration, 12, accuracy: 0.001)
        XCTAssertEqual(paused.rightDuration, 7, accuracy: 0.001)
    }

    func testTerminateIsIdempotentAfterEndedAndDoesNotMutateState() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 80_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)
        clock.advance(seconds: 5)
        let first = try await handler.handle(.terminateSession)
        XCTAssertNotNil(first)

        let second = try await handler.handle(.terminateSession)
        XCTAssertNil(second)

        let snapshot = handler.currentState()
        XCTAssertEqual(snapshot.timerStatus, .ended)
        XCTAssertNil(snapshot.activeSide)

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    func testSwitchSideThrowsWhenSessionNotStarted() async {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 81_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        await XCTAssertThrowsErrorAsync(try await handler.handle(.switchSide)) { error in
            XCTAssertEqual(error as? LiveActivityQuickActionError, .cannotSwitchWithoutStartedSession)
        }
    }

    func testActionInFlightGuardSkipsConcurrentMutation() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 82_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = DelayedUpsertRepository(delayNanoseconds: 300_000_000)
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository)

        try await handler.handle(.startLeft)
        clock.advance(seconds: 9)

        let terminateTask = Task {
            try await handler.handle(.terminateSession)
        }

        await Task.yield()
        let skipped = try await handler.handle(.switchSide)
        XCTAssertNil(skipped)

        let terminated = try await terminateTask.value
        XCTAssertNotNil(terminated)

        let snapshot = handler.currentState()
        XCTAssertEqual(snapshot.timerStatus, .ended)
        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    func testHandleURLParsesRouterDeepLinkAndExecutesAction() async throws {
        let clock = QuickActionTestClock(start: Date(timeIntervalSince1970: 95_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let router = LiveActivityQuickActionRouter()
        let handler = LiveActivityQuickActionHandler(engine: engine, repository: repository, router: router)

        try await handler.handle(url: router.url(for: .startRight))
        try await handler.handle(url: router.url(for: .switchSide))

        let state = handler.currentState()
        XCTAssertEqual(state.activeSide, .left)
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

    func testRouterBuildsPassiveOpenURLWithoutAction() {
        let router = LiveActivityQuickActionRouter()
        let url = router.passiveOpenURL(sessionID: "session-123")

        XCTAssertTrue(router.isPassiveOpenURL(url))
        XCTAssertNil(router.action(from: url))
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "session" })?.value, "session-123")
    }

    func testAttributesExposeMVP02ParityActionURLs() {
        let attrs = FeedTrackerLiveActivityAttributes(sessionID: UUID())
        XCTAssertTrue(attrs.switchSideActionURL.contains("action=switch_side"))
        XCTAssertTrue(attrs.pauseSessionActionURL.contains("action=pause_session"))
        XCTAssertTrue(attrs.terminateSessionActionURL.contains("action=terminate_session"))
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

private actor DelayedUpsertRepository: FeedingSessionRepository {
    private var sessions: [UUID: FeedingSession] = [:]
    private let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchAll() async throws -> [FeedingSession] {
        sessions.values.sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
    }

    func fetch(id: UUID) async throws -> FeedingSession? {
        sessions[id]
    }

    func upsert(_ session: FeedingSession) async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        sessions[session.id] = session
    }

    func remove(id: UUID) async throws {
        sessions.removeValue(forKey: id)
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
