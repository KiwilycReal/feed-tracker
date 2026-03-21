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
        try await FeedTrackerLiveActivityIntentRuntime.executeAndRefresh(
            action: action.quickAction,
            targetSessionID: sessionID
        )
        return .result()
    }
}

@available(iOSApplicationExtension 16.1, *)
private enum FeedTrackerLiveActivityIntentRuntime {
    enum RuntimeError: LocalizedError {
        case sharedContainerUnavailable

        var errorDescription: String? {
            switch self {
            case .sharedContainerUnavailable:
                return "Shared FeedTracker app-group storage is unavailable."
            }
        }
    }

    struct RenderRefresh {
        let state: LiveActivityState
        let renderVersion: UInt64
    }

    static func executeAndRefresh(
        action: LiveActivityQuickAction,
        targetSessionID: String
    ) async throws {
        let actionLock = try makeActionLock()
        defer { actionLock.unlock() }

        let refresh = try await executeOnMain(action: action)
        FeedTrackerSharedStorage.writeExternalSyncMarker()
        try await refreshActivity(targetSessionID: targetSessionID, with: refresh)
    }

    static func refreshActivity(
        targetSessionID: String,
        with refresh: RenderRefresh
    ) async throws {
        let activities = Activity<FeedTrackerLiveActivityAttributes>.activities
        let targetActivity = activities.first(where: { $0.attributes.sessionID == targetSessionID }) ?? activities.first

        guard let activity = targetActivity else {
            return
        }

        guard refresh.renderVersion == FeedTrackerSharedStorage.currentLiveActivityRenderVersion() else {
            return
        }

        let contentState = FeedTrackerLiveActivityContentState(
            state: refresh.state,
            renderVersion: refresh.renderVersion
        )
        let content = ActivityContent(state: contentState, staleDate: nil)

        if refresh.state.timerStatus == .ended {
            await activity.end(content, dismissalPolicy: .immediate)
        } else if refresh.state.timerStatus != .idle {
            await activity.update(content)
        }
    }

    @MainActor
    private static func executeOnMain(action: LiveActivityQuickAction) async throws -> RenderRefresh {
        let engine = SessionTimerEngine()
        let recoveryStore = try makeRecoveryStore()

        if let recoveryState = try recoveryStore.load() {
            do {
                try engine.restore(from: recoveryState)
            } catch {
                try recoveryStore.clear()
            }
        }

        let handler = LiveActivityQuickActionHandler(
            engine: engine,
            repository: try makeRepository()
        )

        _ = try await handler.handle(action)

        if let persistedState = engine.recoveryStateForPersistence() {
            try recoveryStore.save(persistedState)
        } else {
            try recoveryStore.clear()
        }

        return RenderRefresh(
            state: handler.currentState(),
            renderVersion: FeedTrackerSharedStorage.nextLiveActivityRenderVersion()
        )
    }

    private static func makeActionLock() throws -> FeedTrackerExclusiveFileLock {
        guard let fileURL = FeedTrackerSharedStorage.liveActivityActionLockFileURL() else {
            throw RuntimeError.sharedContainerUnavailable
        }

        return try FeedTrackerExclusiveFileLock(fileURL: fileURL)
    }

    private static func makeRecoveryStore() throws -> RecoveryStore {
        guard let sharedDefaults = FeedTrackerSharedStorage.sharedUserDefaults() else {
            throw RuntimeError.sharedContainerUnavailable
        }

        return RecoveryStore(
            userDefaults: sharedDefaults,
            key: FeedTrackerSharedStorage.recoveryKey
        )
    }

    @MainActor
    private static func makeRepository() throws -> any FeedingSessionRepository {
        guard let fileURL = FeedTrackerSharedStorage.sessionsFileURL(),
              let repository = try? FileFeedingSessionRepository(fileURL: fileURL) else {
            throw RuntimeError.sharedContainerUnavailable
        }

        return repository
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
