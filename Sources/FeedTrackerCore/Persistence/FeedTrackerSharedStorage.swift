import Foundation

public enum FeedTrackerSharedStorage {
    public static let appGroupIdentifier = "group.com.kiwilyc.feedtracker"
    public static let directoryName = "FeedTracker"
    public static let recoveryKey = "feedtracker.active_session_recovery.v1"
    public static let syncMarkerKey = "feedtracker.external_sync_marker.v1"
    public static let liveActivityRenderVersionFileName = "live_activity_render_version.v1"
    public static let liveActivityRenderVersionLockFileName = "live_activity_render_version.lock"
    public static let liveActivityActionLockFileName = "live_activity_action.lock"

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

    public static func liveActivityRenderVersionFileURL(fileManager: FileManager = .default) -> URL? {
        directoryURL(fileManager: fileManager)?
            .appendingPathComponent(liveActivityRenderVersionFileName)
    }

    public static func liveActivityRenderVersionLockFileURL(fileManager: FileManager = .default) -> URL? {
        directoryURL(fileManager: fileManager)?
            .appendingPathComponent(liveActivityRenderVersionLockFileName)
    }

    public static func liveActivityActionLockFileURL(fileManager: FileManager = .default) -> URL? {
        directoryURL(fileManager: fileManager)?
            .appendingPathComponent(liveActivityActionLockFileName)
    }

    public static func nextLiveActivityRenderVersion(fileManager: FileManager = .default) -> UInt64 {
        guard let fileURL = liveActivityRenderVersionFileURL(fileManager: fileManager),
              let lockFileURL = liveActivityRenderVersionLockFileURL(fileManager: fileManager) else {
            return fallbackRenderVersionStore.next()
        }

        do {
            let lock = try FeedTrackerExclusiveFileLock(fileURL: lockFileURL, fileManager: fileManager)
            defer { lock.unlock() }

            let nextValue = readRenderVersion(from: fileURL, fileManager: fileManager) &+ 1
            try writeRenderVersion(nextValue, to: fileURL, fileManager: fileManager)
            fallbackRenderVersionStore.set(nextValue)
            return nextValue
        } catch {
            return fallbackRenderVersionStore.next()
        }
    }

    public static func currentLiveActivityRenderVersion(fileManager: FileManager = .default) -> UInt64 {
        guard let fileURL = liveActivityRenderVersionFileURL(fileManager: fileManager),
              let lockFileURL = liveActivityRenderVersionLockFileURL(fileManager: fileManager) else {
            return fallbackRenderVersionStore.current()
        }

        do {
            let lock = try FeedTrackerExclusiveFileLock(fileURL: lockFileURL, fileManager: fileManager)
            defer { lock.unlock() }

            let currentValue = readRenderVersion(from: fileURL, fileManager: fileManager)
            fallbackRenderVersionStore.set(currentValue)
            return currentValue
        } catch {
            return fallbackRenderVersionStore.current()
        }
    }

    @discardableResult
    public static func writeExternalSyncMarker(
        _ marker: String = UUID().uuidString,
        userDefaults: UserDefaults? = FeedTrackerSharedStorage.sharedUserDefaults()
    ) -> String {
        userDefaults?.set(marker, forKey: syncMarkerKey)
        return marker
    }

    public static func readExternalSyncMarker(
        userDefaults: UserDefaults? = FeedTrackerSharedStorage.sharedUserDefaults()
    ) -> String? {
        userDefaults?.string(forKey: syncMarkerKey)
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

    private static func readRenderVersion(from fileURL: URL, fileManager: FileManager) -> UInt64 {
        guard fileManager.fileExists(atPath: fileURL.path),
              let contents = try? String(contentsOf: fileURL, encoding: .utf8)
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              let value = UInt64(contents) else {
            return 0
        }

        return value
    }

    private static func writeRenderVersion(_ value: UInt64, to fileURL: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try "\(value)".write(to: fileURL, atomically: false, encoding: .utf8)
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

private final class FallbackLiveActivityRenderVersionStore: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0

    func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        value &+= 1
        return value
    }

    func current() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: UInt64) {
        lock.lock()
        value = max(value, newValue)
        lock.unlock()
    }
}

private let fallbackRenderVersionStore = FallbackLiveActivityRenderVersionStore()

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
