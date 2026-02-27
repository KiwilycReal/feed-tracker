import Foundation

public protocol FeedItemRepository: Sendable {
    func fetchAll() async throws -> [FeedItem]
    func upsert(_ item: FeedItem) async throws
    func remove(id: UUID) async throws
}

public actor InMemoryFeedItemRepository: FeedItemRepository {
    private var storage: [UUID: FeedItem]

    public init(initialItems: [FeedItem] = []) {
        self.storage = Dictionary(uniqueKeysWithValues: initialItems.map { ($0.id, $0) })
    }

    public func fetchAll() throws -> [FeedItem] {
        storage.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func upsert(_ item: FeedItem) throws {
        storage[item.id] = item
    }

    public func remove(id: UUID) throws {
        storage.removeValue(forKey: id)
    }
}
