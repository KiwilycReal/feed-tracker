import ActivityKit
import AppIntents
import FeedTrackerCore
import Foundation

@available(iOSApplicationExtension 16.1, *)
enum FeedTrackerLiveActivityIntentAction: String, AppEnum {
    case switchSide
    case togglePause
    case terminate

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Feed Session Action")

    static var caseDisplayRepresentations: [FeedTrackerLiveActivityIntentAction: DisplayRepresentation] = [
        .switchSide: DisplayRepresentation(title: "Switch Side"),
        .togglePause: DisplayRepresentation(title: "Pause / Resume"),
        .terminate: DisplayRepresentation(title: "End Session")
    ]

    var quickAction: LiveActivityQuickAction {
        switch self {
        case .switchSide:
            return .switchSide
        case .togglePause:
            return .pauseSession
        case .terminate:
            return .terminateSession
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct FeedTrackerLiveActivityControlIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Feed Session Control"
    static let openAppWhenRun = false

    @Parameter(title: "Action")
    var action: FeedTrackerLiveActivityIntentAction

    @Parameter(title: "Session ID")
    var sessionID: String

    init() {
        action = .switchSide
        sessionID = ""
    }

    init(action: FeedTrackerLiveActivityIntentAction, sessionID: String) {
        self.action = action
        self.sessionID = sessionID
    }

    func perform() async throws -> some IntentResult {
        let state = try await FeedTrackerLiveActivityIntentRuntime.execute(action: action.quickAction)
        try await FeedTrackerLiveActivityIntentRuntime.refreshActivity(
            targetSessionID: sessionID,
            with: state
        )
        return .result()
    }
}

@available(iOSApplicationExtension 16.1, *)
private enum FeedTrackerLiveActivityIntentRuntime {
    private static let appGroupIdentifier = "group.com.kiwilyc.feedtracker"
    private static let recoveryKey = "feedtracker.active_session_recovery.v1"

    static func execute(action: LiveActivityQuickAction) async throws -> LiveActivityState {
        try await executeOnMain(action: action)
    }

    static func refreshActivity(
        targetSessionID: String,
        with state: LiveActivityState
    ) async throws {
        let activities = Activity<FeedTrackerLiveActivityAttributes>.activities
        let targetActivity = activities.first(where: { $0.attributes.sessionID == targetSessionID }) ?? activities.first

        guard let activity = targetActivity else {
            return
        }

        let contentState = FeedTrackerLiveActivityContentState(state: state)
        let content = ActivityContent(state: contentState, staleDate: nil)

        if state.timerStatus == .ended || state.timerStatus == .idle {
            await activity.end(content, dismissalPolicy: .immediate)
        } else {
            await activity.update(content)
        }
    }

    @MainActor
    private static func executeOnMain(action: LiveActivityQuickAction) async throws -> LiveActivityState {
        let engine = SessionTimerEngine()
        let recoveryStore = RecoveryStore(
            userDefaults: UserDefaults(suiteName: appGroupIdentifier) ?? .standard,
            key: recoveryKey
        )

        if let recoveryState = try recoveryStore.load() {
            do {
                try engine.restore(from: recoveryState)
            } catch {
                try recoveryStore.clear()
            }
        }

        let handler = LiveActivityQuickActionHandler(
            engine: engine,
            repository: makeRepository()
        )

        _ = try await handler.handle(action)

        if let persistedState = engine.recoveryStateForPersistence() {
            try recoveryStore.save(persistedState)
        } else {
            try recoveryStore.clear()
        }

        return handler.currentState()
    }

    @MainActor
    private static func makeRepository() -> any FeedingSessionRepository {
        guard let fileURL = sessionsFileURL(),
              let repository = try? FileFeedingSessionRepository(fileURL: fileURL) else {
            return InMemoryFeedingSessionRepository()
        }

        return repository
    }

    private static func sessionsFileURL(fileManager: FileManager = .default) -> URL? {
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return containerURL
                .appendingPathComponent("FeedTracker", isDirectory: true)
                .appendingPathComponent("sessions.json")
        }

        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FeedTracker", isDirectory: true)
            .appendingPathComponent("sessions.json")
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct RecoveryStore {
    let userDefaults: UserDefaults
    let key: String

    func load() throws -> SessionTimerRecoveryState? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionTimerRecoveryState.self, from: data)
    }

    func save(_ state: SessionTimerRecoveryState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        userDefaults.set(try encoder.encode(state), forKey: key)
    }

    func clear() throws {
        userDefaults.removeObject(forKey: key)
    }
}
