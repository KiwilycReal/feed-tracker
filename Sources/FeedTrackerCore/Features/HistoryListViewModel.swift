import Combine
import Foundation

public enum HistoryListViewModelError: Error, Equatable {
    case sessionNotFound
}

public struct HistorySessionListItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let leftDuration: TimeInterval
    public let rightDuration: TimeInterval
    public let totalDuration: TimeInterval
    public let note: String?

    init(session: FeedingSession) {
        self.id = session.id
        self.startedAt = session.startedAt
        self.endedAt = session.endedAt
        self.leftDuration = session.leftDuration
        self.rightDuration = session.rightDuration
        self.totalDuration = session.totalDuration
        self.note = session.note
    }
}

@MainActor
public final class HistoryListViewModel: ObservableObject {
    private let repository: any FeedingSessionRepository

    @Published public private(set) var items: [HistorySessionListItem] = []

    public init(repository: any FeedingSessionRepository) {
        self.repository = repository
    }

    public func reload() async throws {
        let sessions = try await repository.fetchAll()
        items = sessions
            .filter { $0.status == .completed }
            .map(HistorySessionListItem.init(session:))
    }

    public func deleteSession(id: UUID) async throws {
        try await repository.remove(id: id)
        try await reload()
    }

    public func editSession(
        id: UUID,
        leftDuration: TimeInterval,
        rightDuration: TimeInterval,
        note: String?
    ) async throws {
        guard let session = try await repository.fetch(id: id) else {
            throw HistoryListViewModelError.sessionNotFound
        }

        let updated = try session.edited(
            leftDuration: leftDuration,
            rightDuration: rightDuration,
            note: note
        )

        try await repository.upsert(updated)
        try await reload()
    }
}
