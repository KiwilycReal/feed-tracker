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
}

private final class InMemoryActiveSessionRecoveryStore: ActiveSessionRecoveryStoring {
    private var storedState: SessionTimerRecoveryState?

    func load() throws -> SessionTimerRecoveryState? {
        storedState
    }

    func save(_ state: SessionTimerRecoveryState) throws {
        storedState = state
    }

    func clear() throws {
        storedState = nil
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
