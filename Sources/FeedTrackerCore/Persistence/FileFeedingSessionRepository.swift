import Foundation

public enum FileFeedingSessionRepositoryError: Error, Equatable, Sendable {
    case unsupportedPayload
    case unsupportedSchemaVersion(Int)
}

private struct VersionedFeedingSessionStore: Codable {
    let schemaVersion: Int
    let sessions: [FeedingSession]
}

public actor FileFeedingSessionRepository: FeedingSessionRepository {
    public static let currentSchemaVersion = StorageVersion(2)

    private let fileURL: URL
    private var storage: [UUID: FeedingSession]

    public init(fileURL: URL) throws {
        self.fileURL = fileURL

        let bootstrapStore = try Self.bootstrapStore(at: fileURL)
        self.storage = Dictionary(uniqueKeysWithValues: bootstrapStore.sessions.map { ($0.id, $0) })
    }

    public func fetchAll() throws -> [FeedingSession] {
        storage.values.sorted(by: sortByNewest)
    }

    public func fetch(id: UUID) throws -> FeedingSession? {
        storage[id]
    }

    public func upsert(_ session: FeedingSession) throws {
        storage[session.id] = session
        try persistCurrentState()
    }

    public func remove(id: UUID) throws {
        storage.removeValue(forKey: id)
        try persistCurrentState()
    }

    private func persistCurrentState() throws {
        let store = VersionedFeedingSessionStore(
            schemaVersion: Self.currentSchemaVersion.value,
            sessions: Array(storage.values)
        )
        try Self.write(store: store, to: fileURL)
    }

    private func sortByNewest(_ lhs: FeedingSession, _ rhs: FeedingSession) -> Bool {
        let lhsTime = lhs.endedAt ?? lhs.startedAt
        let rhsTime = rhs.endedAt ?? rhs.startedAt
        return lhsTime > rhsTime
    }

    private static func bootstrapStore(at fileURL: URL) throws -> VersionedFeedingSessionStore {
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            let emptyStore = VersionedFeedingSessionStore(
                schemaVersion: currentSchemaVersion.value,
                sessions: []
            )
            try write(store: emptyStore, to: fileURL)
            return emptyStore
        }

        let data = try Data(contentsOf: fileURL)
        if let decodedStore = try? JSONDecoder.feedTracker.decode(VersionedFeedingSessionStore.self, from: data) {
            return try migrateIfNeeded(store: decodedStore, fileURL: fileURL)
        }

        if let legacySessions = try? JSONDecoder.feedTracker.decode([FeedingSession].self, from: data) {
            let migratedStore = VersionedFeedingSessionStore(
                schemaVersion: currentSchemaVersion.value,
                sessions: legacySessions
            )
            try write(store: migratedStore, to: fileURL)
            return migratedStore
        }

        throw FileFeedingSessionRepositoryError.unsupportedPayload
    }

    private static func migrateIfNeeded(
        store: VersionedFeedingSessionStore,
        fileURL: URL
    ) throws -> VersionedFeedingSessionStore {
        guard store.schemaVersion <= currentSchemaVersion.value else {
            throw FileFeedingSessionRepositoryError.unsupportedSchemaVersion(store.schemaVersion)
        }

        guard store.schemaVersion < currentSchemaVersion.value else {
            return store
        }

        // v1 -> v2: keep same records, add explicit schema metadata and canonical serialization.
        let migratedStore = VersionedFeedingSessionStore(
            schemaVersion: currentSchemaVersion.value,
            sessions: store.sessions
        )

        try write(store: migratedStore, to: fileURL)
        return migratedStore
    }

    private static func write(store: VersionedFeedingSessionStore, to fileURL: URL) throws {
        let data = try JSONEncoder.feedTracker.encode(store)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var feedTracker: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var feedTracker: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
