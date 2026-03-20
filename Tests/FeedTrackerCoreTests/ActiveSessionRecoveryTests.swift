import Foundation
import XCTest
@testable import FeedTrackerCore

@MainActor
final class ActiveSessionRecoveryTests: XCTestCase {
    func testRestoreRunningSessionAfterForceKillKeepsSessionUsable() async throws {
        let clock = RecoveryTestClock(start: Date(timeIntervalSince1970: 60_000))
        let repository = InMemoryFeedingSessionRepository()
        let store = InMemoryActiveSessionRecoveryStore()

        do {
            let engine = SessionTimerEngine(now: { clock.now })
            let viewModel = ActiveSessionViewModel(
                engine: engine,
                repository: repository,
                recoveryStore: store
            )

            try viewModel.start(side: .left)
            clock.advance(seconds: 120)
        }

        let restoredEngine = SessionTimerEngine(now: { clock.now })
        let restoredViewModel = ActiveSessionViewModel(
            engine: restoredEngine,
            repository: repository,
            recoveryStore: store
        )

        XCTAssertEqual(restoredViewModel.displayState.state, .running(side: .left))
        XCTAssertEqual(restoredViewModel.displayState.leftElapsed, 120, accuracy: 0.001)
        XCTAssertEqual(restoredViewModel.displayState.rightElapsed, 0, accuracy: 0.001)

        try restoredViewModel.switchSide(to: .right)
        clock.advance(seconds: 15)
        restoredViewModel.refresh()
        XCTAssertEqual(restoredViewModel.displayState.state, .running(side: .right))
        XCTAssertEqual(restoredViewModel.displayState.totalElapsed, 135, accuracy: 0.001)
    }

    func testNoRecoveryAfterSessionEnded() async throws {
        let clock = RecoveryTestClock(start: Date(timeIntervalSince1970: 70_000))
        let repository = InMemoryFeedingSessionRepository()
        let store = InMemoryActiveSessionRecoveryStore()

        do {
            let engine = SessionTimerEngine(now: { clock.now })
            let viewModel = ActiveSessionViewModel(
                engine: engine,
                repository: repository,
                recoveryStore: store
            )

            try viewModel.start(side: .left)
            clock.advance(seconds: 30)
            _ = try await viewModel.endSession(note: "done")
        }

        XCTAssertNil(try store.load())

        let restoredEngine = SessionTimerEngine(now: { clock.now })
        let restoredViewModel = ActiveSessionViewModel(
            engine: restoredEngine,
            repository: repository,
            recoveryStore: store
        )

        XCTAssertEqual(restoredViewModel.displayState.state, .idle)
        XCTAssertEqual(restoredViewModel.displayState.totalElapsed, 0, accuracy: 0.001)
    }

    func testPausedSessionRestoresPausedWithoutElapsedDrift() async throws {
        let clock = RecoveryTestClock(start: Date(timeIntervalSince1970: 80_000))
        let repository = InMemoryFeedingSessionRepository()
        let store = InMemoryActiveSessionRecoveryStore()

        do {
            let engine = SessionTimerEngine(now: { clock.now })
            let viewModel = ActiveSessionViewModel(
                engine: engine,
                repository: repository,
                recoveryStore: store
            )

            try viewModel.start(side: .left)
            clock.advance(seconds: 45)
            try viewModel.pause()
        }

        clock.advance(seconds: 300)

        let restoredEngine = SessionTimerEngine(now: { clock.now })
        let restoredViewModel = ActiveSessionViewModel(
            engine: restoredEngine,
            repository: repository,
            recoveryStore: store
        )

        XCTAssertEqual(restoredViewModel.displayState.state, .paused(side: .left))
        XCTAssertEqual(restoredViewModel.displayState.leftElapsed, 45, accuracy: 0.001)

        try restoredViewModel.resume()
        clock.advance(seconds: 10)
        restoredViewModel.refresh()

        XCTAssertEqual(restoredViewModel.displayState.state, .running(side: .left))
        XCTAssertEqual(restoredViewModel.displayState.leftElapsed, 55, accuracy: 0.001)
    }

    func testExternalSyncReloadUsesAuthoritativePrimaryMissingStrategy() async throws {
        let clock = RecoveryTestClock(start: Date(timeIntervalSince1970: 90_000))
        let repository = InMemoryFeedingSessionRepository()
        let store = StrategyRecordingRecoveryStore()
        let engine = SessionTimerEngine(now: { clock.now })
        let viewModel = ActiveSessionViewModel(
            engine: engine,
            repository: repository,
            recoveryStore: store
        )

        try viewModel.start(side: .right)
        XCTAssertEqual(store.recordedStrategies.first, .fallbackAllowed)

        store.nextLoadResult = nil
        await viewModel.reloadFromRecoveryStore(source: "test.external_sync")

        XCTAssertEqual(store.recordedStrategies.last, .primaryStoreAuthoritativeWhenMissing)
        XCTAssertEqual(store.clearCallCount, 1)
        XCTAssertEqual(viewModel.displayState.state, .idle)
        XCTAssertEqual(viewModel.displayState.totalElapsed, 0, accuracy: 0.001)
    }

    func testExternalResetCancelsQueuedActivePersistBeforeItCanRewriteCompletedSession() async throws {
        let clock = RecoveryTestClock(start: Date(timeIntervalSince1970: 91_000))
        let repository = StatusDelayedUpsertRepository(activeDelayNanoseconds: 300_000_000)
        let store = InMemoryActiveSessionRecoveryStore()
        let engine = SessionTimerEngine(now: { clock.now })
        let viewModel = ActiveSessionViewModel(
            engine: engine,
            repository: repository,
            recoveryStore: store
        )

        try viewModel.start(side: .left)
        let snapshot = engine.snapshot()
        let sessionID = try XCTUnwrap(snapshot.sessionID)
        let startedAt = try XCTUnwrap(snapshot.startedAt)

        let completed = try FeedingSession(
            id: sessionID,
            startedAt: startedAt,
            endedAt: clock.now.addingTimeInterval(9),
            leftDuration: 9,
            rightDuration: 0,
            note: "widget completed",
            status: .completed
        )
        try await repository.upsert(completed)
        try store.clear()

        await viewModel.reloadFromRecoveryStore(source: "test.external_sync.widget_end")
        try await Task.sleep(nanoseconds: 400_000_000)

        let persisted = try await repository.fetch(id: sessionID)
        let final = try XCTUnwrap(persisted)
        XCTAssertEqual(final.status, .completed)
        XCTAssertEqual(final.note, "widget completed")
        XCTAssertEqual(viewModel.displayState.state, .idle)
    }
}

private final class InMemoryActiveSessionRecoveryStore: ActiveSessionRecoveryStoring {
    private var storedState: SessionTimerRecoveryState?

    func load(strategy: ActiveSessionRecoveryLoadStrategy) throws -> SessionTimerRecoveryState? {
        storedState
    }

    func save(_ state: SessionTimerRecoveryState) throws {
        storedState = state
    }

    func clear() throws {
        storedState = nil
    }
}

private final class StrategyRecordingRecoveryStore: ActiveSessionRecoveryStoring {
    var nextLoadResult: SessionTimerRecoveryState?
    private(set) var recordedStrategies: [ActiveSessionRecoveryLoadStrategy] = []
    private(set) var clearCallCount = 0

    func load(strategy: ActiveSessionRecoveryLoadStrategy) throws -> SessionTimerRecoveryState? {
        recordedStrategies.append(strategy)
        return nextLoadResult
    }

    func save(_ state: SessionTimerRecoveryState) throws {
        nextLoadResult = state
    }

    func clear() throws {
        clearCallCount += 1
        nextLoadResult = nil
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

private final class RecoveryTestClock {
    var now: Date

    init(start: Date) {
        now = start
    }

    func advance(seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
