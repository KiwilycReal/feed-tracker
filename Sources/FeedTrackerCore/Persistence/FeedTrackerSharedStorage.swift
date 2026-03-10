import Foundation

public enum FeedTrackerSharedStorage {
    public static let appGroupIdentifier = "group.com.kiwilyc.feedtracker"
    public static let directoryName = "FeedTracker"
    public static let recoveryKey = "feedtracker.active_session_recovery.v1"

    public static func sharedUserDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    public static func directoryURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    public static func sessionsFileURL(fileManager: FileManager = .default) -> URL? {
        directoryURL(fileManager: fileManager)?
            .appendingPathComponent("sessions.json")
    }

    public static func migrateLegacySessionsIfNeeded(
        from legacyURL: URL?,
        to sharedURL: URL,
        fileManager: FileManager = .default
    ) {
        guard let legacyURL,
              legacyURL != sharedURL,
              fileManager.fileExists(atPath: legacyURL.path),
              let legacySessions = try? loadSessions(from: legacyURL),
              !legacySessions.isEmpty else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: sharedURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let sharedSessions = try loadSessionsIfPresent(from: sharedURL, fileManager: fileManager) ?? []
            let mergedSessions = mergeSessions(sharedSessions, legacySessions)

            guard mergedSessions.count != sharedSessions.count else {
                return
            }

            try writeSessions(mergedSessions, to: sharedURL)
        } catch {
            // keep using whichever repository location can still initialize
        }
    }

    private static func loadSessionsIfPresent(
        from fileURL: URL,
        fileManager: FileManager
    ) throws -> [FeedingSession]? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return try loadSessions(from: fileURL)
    }

    private static func loadSessions(from fileURL: URL) throws -> [FeedingSession] {
        let data = try Data(contentsOf: fileURL)

        if let store = try? JSONDecoder.feedTrackerSharedStorage.decode(VersionedSessionStore.self, from: data) {
            return store.sessions
        }

        return try JSONDecoder.feedTrackerSharedStorage.decode([FeedingSession].self, from: data)
    }

    private static func writeSessions(_ sessions: [FeedingSession], to fileURL: URL) throws {
        let store = VersionedSessionStore(
            schemaVersion: FileFeedingSessionRepository.currentSchemaVersion.value,
            sessions: sessions
        )
        let data = try JSONEncoder.feedTrackerSharedStorage.encode(store)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func mergeSessions(
        _ sharedSessions: [FeedingSession],
        _ legacySessions: [FeedingSession]
    ) -> [FeedingSession] {
        var orderedSessions = sharedSessions
        var knownIDs = Set(sharedSessions.map(\.id))

        for session in legacySessions where knownIDs.insert(session.id).inserted {
            orderedSessions.append(session)
        }

        return orderedSessions.sorted { lhs, rhs in
            let lhsTime = lhs.endedAt ?? lhs.startedAt
            let rhsTime = rhs.endedAt ?? rhs.startedAt
            return lhsTime > rhsTime
        }
    }
}

private struct VersionedSessionStore: Codable {
    let schemaVersion: Int
    let sessions: [FeedingSession]
}

private extension JSONEncoder {
    static var feedTrackerSharedStorage: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var feedTrackerSharedStorage: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
