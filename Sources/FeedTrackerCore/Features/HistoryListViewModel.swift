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
    private let diagnostics: (any DiagnosticsLogging)?

    @Published public private(set) var items: [HistorySessionListItem] = []

    public init(
        repository: any FeedingSessionRepository,
        diagnostics: (any DiagnosticsLogging)? = nil
    ) {
        self.repository = repository
        self.diagnostics = diagnostics
    }

    public func reload() async throws {
        do {
            let sessions = try await repository.fetchAll()
            items = sessions
                .filter { $0.status == .completed }
                .map(HistorySessionListItem.init(session:))

            diagnostics?.record(
                category: "persistence",
                action: "history_reload",
                metadata: ["count": "\(items.count)"],
                source: "history_vm"
            )
        } catch {
            diagnostics?.recordError(
                context: "history.reload",
                message: error.localizedDescription,
                metadata: [:],
                source: "history_vm"
            )
            throw error
        }
    }

    public func deleteSession(id: UUID) async throws {
        do {
            try await repository.remove(id: id)
            diagnostics?.record(
                category: "persistence",
                action: "history_delete",
                metadata: ["sessionID": id.uuidString],
                source: "history_vm"
            )
            try await reload()
        } catch {
            diagnostics?.recordError(
                context: "history.delete",
                message: error.localizedDescription,
                metadata: ["sessionID": id.uuidString],
                source: "history_vm"
            )
            throw error
        }
    }

    public func editSession(
        id: UUID,
        leftDuration: TimeInterval,
        rightDuration: TimeInterval,
        note: String?
    ) async throws {
        do {
            guard let session = try await repository.fetch(id: id) else {
                throw HistoryListViewModelError.sessionNotFound
            }

            let updated = try session.edited(
                leftDuration: leftDuration,
                rightDuration: rightDuration,
                note: note
            )

            try await repository.upsert(updated)
            diagnostics?.record(
                category: "persistence",
                action: "history_edit",
                metadata: [
                    "sessionID": id.uuidString,
                    "leftDuration": "\(Int(leftDuration.rounded()))",
                    "rightDuration": "\(Int(rightDuration.rounded()))"
                ],
                source: "history_vm"
            )
            try await reload()
        } catch {
            diagnostics?.recordError(
                context: "history.edit",
                message: error.localizedDescription,
                metadata: ["sessionID": id.uuidString],
                source: "history_vm"
            )
            throw error
        }
    }
}
