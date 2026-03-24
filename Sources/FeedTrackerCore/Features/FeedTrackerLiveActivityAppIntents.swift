#if canImport(AppIntents)
import AppIntents
import Foundation

public struct FeedTrackerLiveActivityIntentExecutionReport: Equatable, Sendable {
    public let source: String
    public let reason: String
    public let executionHost: String
    public let refreshStrategy: String
    public let renderVersion: UInt64?
    public let displayedRefreshAttempt: String?
    public let shouldPostExternalSyncSignal: Bool

    public init(
        source: String,
        reason: String,
        executionHost: String,
        refreshStrategy: String,
        renderVersion: UInt64? = nil,
        displayedRefreshAttempt: String? = nil,
        shouldPostExternalSyncSignal: Bool
    ) {
        self.source = source
        self.reason = reason
        self.executionHost = executionHost
        self.refreshStrategy = refreshStrategy
        self.renderVersion = renderVersion
        self.displayedRefreshAttempt = displayedRefreshAttempt
        self.shouldPostExternalSyncSignal = shouldPostExternalSyncSignal
    }
}

@available(iOS 17.0, *)
@MainActor
public protocol FeedTrackerLiveActivityIntentAppExecuting: AnyObject {
    func execute(
        action: LiveActivityQuickAction,
        targetSessionID: String
    ) async throws -> FeedTrackerLiveActivityIntentExecutionReport
}

@available(iOS 17.0, *)
@MainActor
public enum FeedTrackerLiveActivityIntentDependency {
    public static var executor: (any FeedTrackerLiveActivityIntentAppExecuting)?
}

@available(iOS 17.0, *)
public enum FeedTrackerLiveActivityIntentAction: String, CaseIterable, Equatable, Sendable, Codable, AppEnum {
    case switchSide
    case togglePause
    case terminate

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Feed Session Action")

    public static var caseDisplayRepresentations: [FeedTrackerLiveActivityIntentAction: DisplayRepresentation] = [
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

@available(iOS 17.0, *)
public struct FeedTrackerCoreAppIntentsPackage: AppIntentsPackage {
    public static var includedPackages: [any AppIntentsPackage.Type] { [] }
}

@available(iOS 17.0, *)
enum FeedTrackerLiveActivityIntentRuntime {
    typealias AppExecutorProvider = () async -> (any FeedTrackerLiveActivityIntentAppExecuting)?
    typealias FallbackExecutor = (LiveActivityQuickAction, String) async throws -> FeedTrackerLiveActivityIntentExecutionReport
    typealias ExternalSyncEmitter = (FeedTrackerLiveActivityIntentExecutionReport, LiveActivityQuickAction, String) -> Void

    static func executeAndRefresh(
        action: LiveActivityQuickAction,
        targetSessionID: String
    ) async throws {
        _ = try await execute(
            action: action,
            targetSessionID: targetSessionID,
            appExecutorProvider: defaultAppExecutorProvider,
            fallbackExecutor: executeFallback,
            externalSyncEmitter: emitExternalSync
        )
    }

    static func execute(
        action: LiveActivityQuickAction,
        targetSessionID: String,
        appExecutorProvider: AppExecutorProvider,
        fallbackExecutor: FallbackExecutor,
        externalSyncEmitter: ExternalSyncEmitter
    ) async throws -> FeedTrackerLiveActivityIntentExecutionReport {
        let report: FeedTrackerLiveActivityIntentExecutionReport
        if let appExecutor = await appExecutorProvider() {
            report = try await appExecutor.execute(action: action, targetSessionID: targetSessionID)
        } else {
            report = try await fallbackExecutor(action, targetSessionID)
        }

        externalSyncEmitter(report, action, targetSessionID)
        return report
    }

    private static func defaultAppExecutorProvider() async -> (any FeedTrackerLiveActivityIntentAppExecuting)? {
        await MainActor.run {
            FeedTrackerLiveActivityIntentDependency.executor
        }
    }

    private static func emitExternalSync(
        report: FeedTrackerLiveActivityIntentExecutionReport,
        action: LiveActivityQuickAction,
        targetSessionID: String
    ) {
        let marker = FeedTrackerSharedStorage.writeExternalSyncMarker()
        FeedTrackerSharedStorage.writeExternalSyncContext(
            marker: marker,
            source: report.source,
            reason: report.reason,
            action: action.rawValue,
            sessionID: targetSessionID,
            renderVersion: report.renderVersion,
            displayedRefreshAttempt: report.displayedRefreshAttempt,
            executionHost: report.executionHost,
            refreshStrategy: report.refreshStrategy
        )

        if report.shouldPostExternalSyncSignal {
            FeedTrackerSharedStorage.postLiveActivityExternalSyncSignal()
        }
    }

    private static func executeFallback(
        action: LiveActivityQuickAction,
        targetSessionID: String
    ) async throws -> FeedTrackerLiveActivityIntentExecutionReport {
#if canImport(ActivityKit) && os(iOS)
        return try await executeFallbackOnIOS(action: action, targetSessionID: targetSessionID)
#else
        throw NSError(
            domain: "FeedTrackerLiveActivityIntentRuntime",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Live Activity fallback execution is only supported on iOS."]
        )
#endif
    }
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

@available(iOS 17.0, *)
public struct FeedTrackerLiveActivityControlIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Feed Session Control"
    public static let openAppWhenRun = false

    @Parameter(title: "Action")
    public var action: FeedTrackerLiveActivityIntentAction

    @Parameter(title: "Session ID")
    public var sessionID: String

    public init() {
        action = .switchSide
        sessionID = ""
    }

    public init(action: FeedTrackerLiveActivityIntentAction, sessionID: String) {
        self.action = action
        self.sessionID = sessionID
    }

    public func perform() async throws -> some IntentResult {
        try await FeedTrackerLiveActivityIntentRuntime.executeAndRefresh(
            action: action.quickAction,
            targetSessionID: sessionID
        )
        return .result()
    }
}

@available(iOS 17.0, *)
private enum FeedTrackerLiveActivityIntentFallbackRuntime {
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
        let persistenceDrainer: Task<Void, Never>?
    }

    enum DisplayedRefreshAttempt: String {
        case endedVisibleActivity = "ended_visible_activity"
        case updatedVisibleActivity = "updated_visible_activity"
        case skippedIdleState = "skipped_idle_state"
        case skippedNoVisibleActivity = "skipped_no_visible_activity"
        case skippedStaleRenderVersion = "skipped_stale_render_version"
    }

    static func refreshActivity(
        targetSessionID: String,
        with refresh: RenderRefresh
    ) async -> DisplayedRefreshAttempt {
        guard let activity = resolveTargetActivity(sessionID: targetSessionID) else {
            return .skippedNoVisibleActivity
        }

        guard refresh.renderVersion == FeedTrackerSharedStorage.currentLiveActivityRenderVersion() else {
            return .skippedStaleRenderVersion
        }

        let contentState = FeedTrackerLiveActivityContentState(
            state: refresh.state,
            renderVersion: refresh.renderVersion
        )
        let content = ActivityContent(state: contentState, staleDate: nil)

        if refresh.state.timerStatus == .ended {
            await activity.end(content, dismissalPolicy: .immediate)
            if FeedTrackerSharedStorage.readLiveActivityDisplayTarget()?.sessionID == targetSessionID {
                FeedTrackerSharedStorage.clearLiveActivityDisplayTarget()
            }
            return .endedVisibleActivity
        }

        guard refresh.state.timerStatus != .idle else {
            return .skippedIdleState
        }

        FeedTrackerSharedStorage.writeLiveActivityDisplayTarget(
            activityID: activity.id,
            sessionID: targetSessionID
        )
        await activity.update(content)
        return .updatedVisibleActivity
    }

    @MainActor
    static func executeOnMain(action: LiveActivityQuickAction) async throws -> RenderRefresh {
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

        _ = try await handler.handle(action, persistenceMode: .deferred)

        if let persistedState = engine.recoveryStateForPersistence() {
            try recoveryStore.save(persistedState)
        } else {
            try recoveryStore.clear()
        }

        return RenderRefresh(
            state: handler.currentState(),
            renderVersion: FeedTrackerSharedStorage.nextLiveActivityRenderVersion(),
            persistenceDrainer: handler.pendingPersistenceDrainer()
        )
    }

    static func makeActionLock() throws -> FeedTrackerExclusiveFileLock {
        guard let fileURL = FeedTrackerSharedStorage.liveActivityActionLockFileURL() else {
            throw RuntimeError.sharedContainerUnavailable
        }

        return try FeedTrackerExclusiveFileLock(fileURL: fileURL)
    }

    static func makeRecoveryStore() throws -> RecoveryStore {
        guard let sharedDefaults = FeedTrackerSharedStorage.sharedUserDefaults() else {
            throw RuntimeError.sharedContainerUnavailable
        }

        return RecoveryStore(
            userDefaults: sharedDefaults,
            key: FeedTrackerSharedStorage.recoveryKey
        )
    }

    @MainActor
    static func makeRepository() throws -> any FeedingSessionRepository {
        guard let fileURL = FeedTrackerSharedStorage.sessionsFileURL(),
              let repository = try? FileFeedingSessionRepository(fileURL: fileURL) else {
            throw RuntimeError.sharedContainerUnavailable
        }

        return repository
    }

    static func resolveTargetActivity(sessionID: String) -> Activity<FeedTrackerLiveActivityAttributes>? {
        let activities = Activity<FeedTrackerLiveActivityAttributes>.activities

        if let storedTarget = FeedTrackerSharedStorage.readLiveActivityDisplayTarget(),
           storedTarget.sessionID == sessionID,
           let activity = activities.first(where: {
               $0.id == storedTarget.activityID && $0.attributes.sessionID == sessionID
           }) {
            return activity
        }

        if let activity = activities.first(where: { $0.attributes.sessionID == sessionID }) {
            FeedTrackerSharedStorage.writeLiveActivityDisplayTarget(
                activityID: activity.id,
                sessionID: sessionID
            )
            return activity
        }

        if FeedTrackerSharedStorage.readLiveActivityDisplayTarget()?.sessionID == sessionID {
            FeedTrackerSharedStorage.clearLiveActivityDisplayTarget()
        }

        return nil
    }
}

@available(iOS 17.0, *)
private extension FeedTrackerLiveActivityIntentRuntime {
    static func executeFallbackOnIOS(
        action: LiveActivityQuickAction,
        targetSessionID: String
    ) async throws -> FeedTrackerLiveActivityIntentExecutionReport {
        let actionLock = try FeedTrackerLiveActivityIntentFallbackRuntime.makeActionLock()
        defer { actionLock.unlock() }

        let refresh = try await FeedTrackerLiveActivityIntentFallbackRuntime.executeOnMain(action: action)
        let displayedRefreshAttempt = await FeedTrackerLiveActivityIntentFallbackRuntime.refreshActivity(
            targetSessionID: targetSessionID,
            with: refresh
        )

        return FeedTrackerLiveActivityIntentExecutionReport(
            source: "widget_live_activity_intent",
            reason: "quick_action_execute_and_refresh",
            executionHost: "widget_extension",
            refreshStrategy: "activitykit_direct_refresh",
            renderVersion: refresh.renderVersion,
            displayedRefreshAttempt: displayedRefreshAttempt.rawValue,
            shouldPostExternalSyncSignal: true
        )
    }
}

@available(iOS 17.0, *)
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
#endif
#endif
