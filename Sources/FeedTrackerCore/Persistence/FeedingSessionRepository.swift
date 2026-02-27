import Foundation

public protocol FeedingSessionRepository: Sendable {
    func fetchAll() async throws -> [FeedingSession]
    func fetch(id: UUID) async throws -> FeedingSession?
    func upsert(_ session: FeedingSession) async throws
    func remove(id: UUID) async throws
}

public actor InMemoryFeedingSessionRepository: FeedingSessionRepository {
    private var storage: [UUID: FeedingSession]

    public init(initialSessions: [FeedingSession] = []) {
        self.storage = Dictionary(uniqueKeysWithValues: initialSessions.map { ($0.id, $0) })
    }

    public func fetchAll() throws -> [FeedingSession] {
        storage.values.sorted(by: sortByNewest)
    }

    public func fetch(id: UUID) throws -> FeedingSession? {
        storage[id]
    }

    public func upsert(_ session: FeedingSession) throws {
        storage[session.id] = session
    }

    public func remove(id: UUID) throws {
        storage.removeValue(forKey: id)
    }

    private func sortByNewest(_ lhs: FeedingSession, _ rhs: FeedingSession) -> Bool {
        let lhsTime = lhs.endedAt ?? lhs.startedAt
        let rhsTime = rhs.endedAt ?? rhs.startedAt
        return lhsTime > rhsTime
    }
}
