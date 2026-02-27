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

    func testEndSessionPersistsCompletedSession() async throws {
        let clock = ViewModelTestClock(start: Date(timeIntervalSince1970: 20_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let repository = InMemoryFeedingSessionRepository()
        let viewModel = ActiveSessionViewModel(engine: engine, repository: repository)

        try viewModel.start(side: .left)
        clock.advance(seconds: 45)

        let session = try await viewModel.endSession(note: "saved by view model")
        let persistedOptional = try await repository.fetch(id: session.id)
        let persisted = try XCTUnwrap(persistedOptional)

        XCTAssertEqual(session.totalDuration, 45, accuracy: 0.001)
        XCTAssertEqual(persisted.totalDuration, 45, accuracy: 0.001)
        XCTAssertEqual(persisted.note, "saved by view model")
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
