import Combine
import Foundation

public enum EditSessionViewModelError: Error, Equatable {
    case sessionNotLoaded
    case sessionNotFound
}

@MainActor
public final class EditSessionViewModel: ObservableObject {
    private let repository: any FeedingSessionRepository
    private var loadedSession: FeedingSession?

    @Published public private(set) var sessionID: UUID?
    @Published public var leftDuration: TimeInterval = 0
    @Published public var rightDuration: TimeInterval = 0
    @Published public var note: String = ""

    public init(repository: any FeedingSessionRepository) {
        self.repository = repository
    }

    public func load(sessionID: UUID) async throws {
        guard let session = try await repository.fetch(id: sessionID) else {
            throw EditSessionViewModelError.sessionNotFound
        }

        loadedSession = session
        self.sessionID = session.id
        leftDuration = session.leftDuration
        rightDuration = session.rightDuration
        note = session.note ?? ""
    }

    @discardableResult
    public func save() async throws -> FeedingSession {
        guard let session = loadedSession else {
            throw EditSessionViewModelError.sessionNotLoaded
        }

        let updated = try session.edited(
            leftDuration: leftDuration,
            rightDuration: rightDuration,
            note: note.isEmpty ? nil : note
        )

        try await repository.upsert(updated)
        loadedSession = updated
        return updated
    }
}
