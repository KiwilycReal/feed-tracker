import Foundation
import XCTest
@testable import FeedTrackerCore

@MainActor
final class ActiveSessionViewModelTests: XCTestCase {
    func testRefreshShowsActiveAndInactiveDurations() async throws {
        let clock = ViewModelTestClock(start: Date(timeIntervalSince1970: 10_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let viewModel = ActiveSessionViewModel(engine: engine, repository: repository)

        try viewModel.start(side: .left)
        clock.advance(seconds: 25)
        try viewModel.switchSide(to: .right)
        clock.advance(seconds: 10)
        viewModel.refresh()

        XCTAssertEqual(viewModel.displayState.activeSide, .right)
        XCTAssertEqual(viewModel.displayState.leftElapsed, 25, accuracy: 0.001)
        XCTAssertEqual(viewModel.displayState.rightElapsed, 10, accuracy: 0.001)
        XCTAssertEqual(viewModel.displayState.totalElapsed, 35, accuracy: 0.001)
    }

    func testRefreshAlsoReconcilesLiveActivityFromAppTick() async throws {
        let clock = ViewModelTestClock(start: Date(timeIntervalSince1970: 15_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let coordinator = LiveActivityCoordinatorSpy()
        let viewModel = ActiveSessionViewModel(
            engine: engine,
            repository: repository,
            liveActivityCoordinator: coordinator
        )

        try viewModel.start(side: .left)
        XCTAssertEqual(coordinator.snapshots.count, 2)

        clock.advance(seconds: 1)
        viewModel.refresh(at: clock.now)
        XCTAssertEqual(coordinator.snapshots.count, 3)
        XCTAssertEqual(coordinator.snapshots.last?.totalElapsed ?? -1, 1, accuracy: 0.001)

        viewModel.refresh(at: clock.now)
        XCTAssertEqual(coordinator.snapshots.count, 3)

        clock.advance(seconds: 1)
        viewModel.refresh(at: clock.now)
        XCTAssertEqual(coordinator.snapshots.count, 4)
        XCTAssertEqual(coordinator.snapshots.last?.totalElapsed ?? -1, 2, accuracy: 0.001)
    }

    func testEndSessionPersistsCompletedSession() async throws {
        let clock = ViewModelTestClock(start: Date(timeIntervalSince1970: 20_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let viewModel = ActiveSessionViewModel(engine: engine, repository: repository)

        try viewModel.start(side: .left)
        let activeSessions = try await waitForSessions(in: repository, count: 1)
        let activeSessionID = try XCTUnwrap(activeSessions.first?.id)
        clock.advance(seconds: 45)

        let session = try await viewModel.endSession(note: "saved by view model")
        let persistedOptional = try await repository.fetch(id: session.id)
        let persisted = try XCTUnwrap(persistedOptional)

        XCTAssertEqual(session.id, activeSessionID)
        XCTAssertEqual(session.totalDuration, 45, accuracy: 0.001)
        XCTAssertEqual(persisted.totalDuration, 45, accuracy: 0.001)
        XCTAssertEqual(persisted.note, "saved by view model")
    }

    func testStartPersistsRecoverableActiveSessionRecord() async throws {
        let clock = ViewModelTestClock(start: Date(timeIntervalSince1970: 19_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let viewModel = ActiveSessionViewModel(engine: engine, repository: repository)

        try viewModel.start(side: .right)

        let activeSessions = try await waitForSessions(in: repository, count: 1)
        let active = try XCTUnwrap(activeSessions.first)
        XCTAssertEqual(active.status, .active)
        XCTAssertEqual(active.leftDuration, 0, accuracy: 0.001)
        XCTAssertEqual(active.rightDuration, 0, accuracy: 0.001)
    }

    func testDisplayResetsToZeroAfterEndingSession() async throws {
        let clock = ViewModelTestClock(start: Date(timeIntervalSince1970: 21_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let viewModel = ActiveSessionViewModel(engine: engine, repository: repository)

        try viewModel.start(side: .right)
        clock.advance(seconds: 32)
        _ = try await viewModel.endSession()

        XCTAssertEqual(viewModel.displayState.state, .idle)
        XCTAssertEqual(viewModel.displayState.leftElapsed, 0, accuracy: 0.001)
        XCTAssertEqual(viewModel.displayState.rightElapsed, 0, accuracy: 0.001)
        XCTAssertEqual(viewModel.displayState.totalElapsed, 0, accuracy: 0.001)

        clock.advance(seconds: 5)
        viewModel.refresh(at: clock.now)

        XCTAssertEqual(viewModel.displayState.state, .idle)
        XCTAssertEqual(viewModel.displayState.totalElapsed, 0, accuracy: 0.001)
    }

    func testEndSessionWaitsForQueuedActivePersistAndKeepsCompletedRecordAuthoritative() async throws {
        let clock = ViewModelTestClock(start: Date(timeIntervalSince1970: 22_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = StatusDelayedUpsertRepository(activeDelayNanoseconds: 300_000_000)
        let viewModel = ActiveSessionViewModel(engine: engine, repository: repository)

        try viewModel.start(side: .left)
        clock.advance(seconds: 14)

        let session = try await viewModel.endSession(note: "keep final note")
        try await Task.sleep(nanoseconds: 400_000_000)

        let persisted = try await repository.fetch(id: session.id)
        let completed = try XCTUnwrap(persisted)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.totalDuration, 14, accuracy: 0.001)
        XCTAssertEqual(completed.note, "keep final note")
    }
}

@MainActor
private final class LiveActivityCoordinatorSpy: LiveActivityLifecycleCoordinating {
    private(set) var snapshots: [SessionTimerSnapshot] = []
    private(set) var sources: [String] = []

    func reconcile(snapshot: SessionTimerSnapshot, source: String) {
        snapshots.append(snapshot)
        sources.append(source)
    }
}

private final class ViewModelTestClock {
    var now: Date

    init(start: Date) {
        self.now = start
    }

    func advance(seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

private actor StatusDelayedUpsertRepository: FeedingSessionRepository {
    private var sessions: [UUID: FeedingSession] = [:]
    private let activeDelayNanoseconds: UInt64

    init(activeDelayNanoseconds: UInt64) {
        self.activeDelayNanoseconds = activeDelayNanoseconds
    }

    func fetchAll() async throws -> [FeedingSession] {
        sessions.values.sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
    }

    func fetch(id: UUID) async throws -> FeedingSession? {
        sessions[id]
    }

    func upsert(_ session: FeedingSession) async throws {
        if session.status != .completed {
            try await Task.sleep(nanoseconds: activeDelayNanoseconds)
        }

        sessions[session.id] = session
    }

    func remove(id: UUID) async throws {
        sessions.removeValue(forKey: id)
    }
}

private func waitForSessions(
    in repository: InMemoryFeedingSessionRepository,
    count: Int,
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    pollNanoseconds: UInt64 = 10_000_000,
    file: StaticString = #filePath,
    line: UInt = #line
) async throws -> [FeedingSession] {
    let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))

    while ContinuousClock.now < deadline {
        let sessions = try await repository.fetchAll()
        if sessions.count >= count {
            return sessions
        }
        try await Task.sleep(nanoseconds: pollNanoseconds)
    }

    let sessions = try await repository.fetchAll()
    XCTFail("Timed out waiting for \(count) persisted session(s)", file: file, line: line)
    return sessions
}
