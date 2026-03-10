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
}
