import Foundation
import XCTest
@testable import FeedTrackerCore

@MainActor
final class HistoryAndEditIntegrationTests: XCTestCase {
    func testHistoryListLoadsCompletedSessionsWithMetrics() async throws {
        let repository = InMemoryFeedingSessionRepository(initialSessions: [
            try FeedingSession(
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 220),
                leftDuration: 70,
                rightDuration: 50,
                note: "before sleep",
                status: .completed
            )
        ])

        let viewModel = HistoryListViewModel(repository: repository)
        try await viewModel.reload()

        XCTAssertEqual(viewModel.items.count, 1)
        let first = try XCTUnwrap(viewModel.items.first)
        XCTAssertEqual(first.leftDuration, 70)
        XCTAssertEqual(first.rightDuration, 50)
        XCTAssertEqual(first.totalDuration, 120)
        XCTAssertEqual(first.note, "before sleep")
    }

    func testEditFlowPersistsUpdatedDurationsAndNote() async throws {
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        let repository = InMemoryFeedingSessionRepository(initialSessions: [
            try FeedingSession(
                id: sessionID,
                startedAt: Date(timeIntervalSince1970: 500),
                endedAt: Date(timeIntervalSince1970: 620),
                leftDuration: 40,
                rightDuration: 80,
                note: "initial",
                status: .completed
            )
        ])

        let editViewModel = EditSessionViewModel(repository: repository)
        try await editViewModel.load(sessionID: sessionID)

        editViewModel.leftDuration = 65
        editViewModel.rightDuration = 55
        editViewModel.note = "updated after doctor advice"

        let saved = try await editViewModel.save()
        XCTAssertEqual(saved.leftDuration, 65)
        XCTAssertEqual(saved.rightDuration, 55)
        XCTAssertEqual(saved.totalDuration, 120)
        XCTAssertEqual(saved.note, "updated after doctor advice")

        let persisted = try await repository.fetch(id: sessionID)
        XCTAssertEqual(persisted?.leftDuration, 65)
        XCTAssertEqual(persisted?.rightDuration, 55)
        XCTAssertEqual(persisted?.note, "updated after doctor advice")
    }

    func testHistoryEditFlowPersistsChangesThroughHistoryListViewModel() async throws {
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
        let repository = InMemoryFeedingSessionRepository(initialSessions: [
            try FeedingSession(
                id: sessionID,
                startedAt: Date(timeIntervalSince1970: 700),
                endedAt: Date(timeIntervalSince1970: 790),
                leftDuration: 30,
                rightDuration: 60,
                note: "before edit",
                status: .completed
            )
        ])

        let historyViewModel = HistoryListViewModel(repository: repository)
        try await historyViewModel.reload()
        XCTAssertEqual(historyViewModel.items.first?.leftDuration, 30)

        try await historyViewModel.editSession(
            id: sessionID,
            leftDuration: 55,
            rightDuration: 45,
            note: "edited from history"
        )

        XCTAssertEqual(historyViewModel.items.first?.leftDuration, 55)
        XCTAssertEqual(historyViewModel.items.first?.rightDuration, 45)
        XCTAssertEqual(historyViewModel.items.first?.totalDuration, 100)
        XCTAssertEqual(historyViewModel.items.first?.note, "edited from history")

        let persisted = try await repository.fetch(id: sessionID)
        XCTAssertEqual(persisted?.leftDuration, 55)
        XCTAssertEqual(persisted?.rightDuration, 45)
        XCTAssertEqual(persisted?.note, "edited from history")
    }

    func testDeleteFlowRemovesSessionAndRefreshesHistoryList() async throws {
        let keepID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!
        let removeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C4")!

        let repository = InMemoryFeedingSessionRepository(initialSessions: [
            try FeedingSession(
                id: keepID,
                startedAt: Date(timeIntervalSince1970: 800),
                endedAt: Date(timeIntervalSince1970: 900),
                leftDuration: 40,
                rightDuration: 60,
                note: "keep me",
                status: .completed
            ),
            try FeedingSession(
                id: removeID,
                startedAt: Date(timeIntervalSince1970: 950),
                endedAt: Date(timeIntervalSince1970: 1020),
                leftDuration: 35,
                rightDuration: 35,
                note: "delete me",
                status: .completed
            )
        ])

        let historyViewModel = HistoryListViewModel(repository: repository)
        try await historyViewModel.reload()
        XCTAssertEqual(historyViewModel.items.map(\.id), [removeID, keepID])

        try await historyViewModel.deleteSession(id: removeID)

        XCTAssertEqual(historyViewModel.items.count, 1)
        XCTAssertEqual(historyViewModel.items.first?.id, keepID)

        let removedSession = try await repository.fetch(id: removeID)
        XCTAssertNil(removedSession)
    }
}
