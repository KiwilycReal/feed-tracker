import SwiftUI
import FeedTrackerCore
import CoreFoundation
import Darwin

final class LiveActivityExternalSyncObserver {
    private let callback: @Sendable () -> Void
    private let notificationName: String

    init(
        notificationName: String = FeedTrackerSharedStorage.liveActivityExternalSyncNotificationName,
        callback: @escaping @Sendable () -> Void
    ) {
        self.callback = callback
        self.notificationName = notificationName

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else {
                    return
                }

                let instance = Unmanaged<LiveActivityExternalSyncObserver>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                instance.callback()
            },
            notificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(notificationName as CFString),
            nil
        )
    }
}

final class UserDefaultsActiveSessionRecoveryStore: ActiveSessionRecoveryStoring {
    private let userDefaultsStores: [UserDefaults]
    private let key: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = FeedTrackerSharedStorage.recoveryKey
    ) {
        self.userDefaultsStores = [userDefaults]
        self.key = key
    }

    init(
        userDefaultsStores: [UserDefaults],
        key: String = FeedTrackerSharedStorage.recoveryKey
    ) {
        self.userDefaultsStores = userDefaultsStores
        self.key = key
    }

    func load(strategy: ActiveSessionRecoveryLoadStrategy) throws -> SessionTimerRecoveryState? {
        var lastError: Error?
        var primaryStoreWasMissing = false

        for (index, userDefaults) in userDefaultsStores.enumerated() {
            guard let data = userDefaults.data(forKey: key) else {
                if index == 0 {
                    primaryStoreWasMissing = true

                    if strategy == .primaryStoreAuthoritativeWhenMissing {
                        return nil
                    }
                }
                continue
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let state = try decoder.decode(SessionTimerRecoveryState.self, from: data)

                if index > 0, primaryStoreWasMissing == false {
                    try save(state)
                }

                return state
            } catch {
                lastError = error
                continue
            }
        }

        if let lastError {
            throw lastError
        }

        return nil
    }

    func save(_ state: SessionTimerRecoveryState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        for userDefaults in userDefaultsStores {
            userDefaults.set(data, forKey: key)
        }
    }

    func clear() throws {
        for userDefaults in userDefaultsStores {
            userDefaults.removeObject(forKey: key)
        }
    }
}

@MainActor
final class FeedTrackerDependencies {
    let engine: SessionTimerEngine
    let repository: any FeedingSessionRepository
    let diagnosticsLogger: DiagnosticsEventLogger
    let activeSessionRecoveryStore: any ActiveSessionRecoveryStoring
    let liveActivityCoordinator: any LiveActivityLifecycleCoordinating
    let quickActionHandler: LiveActivityQuickActionHandler
    let liveActivityRouter: any LiveActivityQuickActionRouting
    let activeSessionViewModel: ActiveSessionViewModel
    let historyViewModel: HistoryListViewModel
    let diagnosticsExportViewModel: DiagnosticsExportViewModel

    private lazy var liveActivityExternalSyncObserver: LiveActivityExternalSyncObserver = {
        LiveActivityExternalSyncObserver { [weak self] in
            Task { [weak self] in
                guard let self else {
                    return
                }

                await self.handleExternalSyncSignal(source: "app.darwin.live_activity_external_sync")
            }
        }
    }()
    private var lastHandledExternalSyncMarker: String?

    init() {
        self.engine = SessionTimerEngine()
        self.diagnosticsLogger = DiagnosticsEventLogger(defaultSourceTag: "ios-app")
        self.activeSessionRecoveryStore = UserDefaultsActiveSessionRecoveryStore(
            userDefaultsStores: FeedTrackerDependencies.makeRecoveryStores()
        )
        self.repository = FeedTrackerDependencies.makeRepository()

        let controller = FeedTrackerDependencies.makeLiveActivityController()
        self.liveActivityCoordinator = LiveActivityLifecycleCoordinator(
            controller: controller,
            diagnostics: diagnosticsLogger
        )
        self.quickActionHandler = LiveActivityQuickActionHandler(
            engine: engine,
            repository: repository,
            diagnostics: diagnosticsLogger
        )
        self.liveActivityRouter = LiveActivityQuickActionRouter()
        self.activeSessionViewModel = ActiveSessionViewModel(
            engine: engine,
            repository: repository,
            diagnostics: diagnosticsLogger,
            recoveryStore: activeSessionRecoveryStore,
            liveActivityCoordinator: liveActivityCoordinator
        )
        self.historyViewModel = HistoryListViewModel(
            repository: repository,
            diagnostics: diagnosticsLogger
        )
        self.diagnosticsExportViewModel = DiagnosticsExportViewModel(
            logger: diagnosticsLogger,
            appVersionProvider: { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown" },
            buildNumberProvider: { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" },
            deviceModelProvider: { DeviceModel.currentIdentifier() },
            sourceTag: "ios-app"
        )
        self.lastHandledExternalSyncMarker = nil
#if canImport(AppIntents)
        if #available(iOS 17.0, *) {
            FeedTrackerLiveActivityIntentDependency.executor = self
        }
#endif
        _ = liveActivityExternalSyncObserver
    }

    private static func makeLiveActivityController() -> any LiveActivityControlling {
#if canImport(ActivityKit)
        if #available(iOS 17.0, *) {
            return ActivityKitLiveActivityController()
        }
#endif
        return NoopLiveActivityController()
    }

    private static func makeRecoveryStores() -> [UserDefaults] {
        if let sharedDefaults = FeedTrackerSharedStorage.sharedUserDefaults() {
            return [sharedDefaults, .standard]
        }

        return [.standard]
    }

    private static func makeRepository(fileManager: FileManager = .default) -> any FeedingSessionRepository {
        let legacyURL = legacySessionsFileURL(fileManager: fileManager)

        if let sharedURL = FeedTrackerSharedStorage.sessionsFileURL(fileManager: fileManager) {
            FeedTrackerSharedStorage.migrateLegacySessionsIfNeeded(
                from: legacyURL,
                to: sharedURL,
                fileManager: fileManager
            )

            if let repository = try? FileFeedingSessionRepository(fileURL: sharedURL) {
                return repository
            }
        }

        if let legacyURL,
           let repository = try? FileFeedingSessionRepository(fileURL: legacyURL) {
            return repository
        }

        return InMemoryFeedingSessionRepository()
    }

    private static func legacySessionsFileURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(FeedTrackerSharedStorage.directoryName, isDirectory: true)
            .appendingPathComponent("sessions.json")
    }

    func reconcileLiveActivity(source: String) {
        liveActivityCoordinator.reconcile(snapshot: engine.snapshot(), source: source)
    }

    private func preloadEngineForAppHostedIntent(source: String) {
        do {
            if let recoveryState = try activeSessionRecoveryStore.load(strategy: .primaryStoreAuthoritativeWhenMissing) {
                try engine.restore(from: recoveryState)
                diagnosticsLogger.record(
                    category: "live_activity_intent",
                    action: "preload_recovery_success",
                    metadata: [
                        "source": source,
                        "status": recoveryState.status.rawValue
                    ],
                    source: "ios-app"
                )
            } else {
                try activeSessionRecoveryStore.clear()
                engine.reset()
                diagnosticsLogger.record(
                    category: "live_activity_intent",
                    action: "preload_recovery_reset",
                    metadata: ["source": source],
                    source: "ios-app"
                )
            }
        } catch {
            diagnosticsLogger.recordError(
                context: "live_activity_intent.preload_recovery",
                message: error.localizedDescription,
                metadata: ["source": source],
                source: "ios-app"
            )
        }
    }

    private func persistRecoveryStateForAppHostedIntent(source: String) {
        do {
            if let recoveryState = engine.recoveryStateForPersistence() {
                try activeSessionRecoveryStore.save(recoveryState)
                diagnosticsLogger.record(
                    category: "live_activity_intent",
                    action: "persist_recovery_state",
                    metadata: [
                        "source": source,
                        "status": recoveryState.status.rawValue
                    ],
                    source: "ios-app"
                )
            } else {
                try activeSessionRecoveryStore.clear()
                diagnosticsLogger.record(
                    category: "live_activity_intent",
                    action: "clear_recovery_state",
                    metadata: ["source": source],
                    source: "ios-app"
                )
            }
        } catch {
            diagnosticsLogger.recordError(
                context: "live_activity_intent.persist_recovery",
                message: error.localizedDescription,
                metadata: ["source": source],
                source: "ios-app"
            )
        }
    }

    private func reloadFromExternalSyncIfNeeded(source: String) async {
        guard let syncMarker = FeedTrackerSharedStorage.readExternalSyncMarker(),
              syncMarker != lastHandledExternalSyncMarker else {
            return
        }

        lastHandledExternalSyncMarker = syncMarker
        await activeSessionViewModel.reloadFromRecoveryStore(source: source)

        do {
            try await historyViewModel.reload()
        } catch {
            diagnosticsLogger.recordError(
                context: "history.reload_external_sync",
                message: error.localizedDescription,
                metadata: [:],
                source: "ios-app"
            )
        }
    }

    private func handleExternalSyncSignal(source: String) async {
        let syncMarker = FeedTrackerSharedStorage.readExternalSyncMarker()
        let context = FeedTrackerSharedStorage.readExternalSyncContext()
        var metadata: [String: String] = [
            "source": source,
            "marker": syncMarker ?? "missing"
        ]

        if let context {
            metadata["contextMarker"] = context.marker
            metadata["contextSource"] = context.source
            metadata["reason"] = context.reason
            if let action = context.action {
                metadata["action"] = action
            }
            if let sessionID = context.sessionID {
                metadata["sessionID"] = sessionID
            }
            if let renderVersion = context.renderVersion {
                metadata["renderVersion"] = "\(renderVersion)"
            }
            if let displayedRefreshAttempt = context.displayedRefreshAttempt {
                metadata["displayedRefreshAttempt"] = displayedRefreshAttempt
            }
            if let executionHost = context.executionHost {
                metadata["executionHost"] = executionHost
            }
            if let refreshStrategy = context.refreshStrategy {
                metadata["refreshStrategy"] = refreshStrategy
            }
            if let syncMarker, syncMarker != context.marker {
                metadata["markerMismatch"] = "true"
            }
        }

        diagnosticsLogger.record(
            category: "live_activity_signal",
            action: "received_external_sync_signal",
            metadata: metadata,
            source: "ios-app"
        )

        await reloadFromExternalSyncIfNeeded(source: "app.external_signal")
        reconcileLiveActivity(source: "app.external_signal")
    }

    func handleAppLaunch() async {
        await reloadFromExternalSyncIfNeeded(source: "app.launch.external_sync")
        reconcileLiveActivity(source: "app.launch")
    }

    func handleScenePhase(_ phase: ScenePhase) async {
        switch phase {
        case .active:
            await reloadFromExternalSyncIfNeeded(source: "app.scene.active.external_sync")
            reconcileLiveActivity(source: "app.scene.active")
        case .inactive:
            await reloadFromExternalSyncIfNeeded(source: "app.scene.inactive.external_sync")
            reconcileLiveActivity(source: "app.scene.inactive")
        case .background:
            await reloadFromExternalSyncIfNeeded(source: "app.scene.background.external_sync")
            reconcileLiveActivity(source: "app.scene.background")
        @unknown default:
            await reloadFromExternalSyncIfNeeded(source: "app.scene.unknown.external_sync")
            reconcileLiveActivity(source: "app.scene.unknown")
        }
    }

    func handleLiveActivityURL(_ url: URL) async {
        if liveActivityRouter.isPassiveOpenURL(url) {
            await reloadFromExternalSyncIfNeeded(source: "app.url.live_activity.passive_open")
            reconcileLiveActivity(source: "app.url.live_activity.passive_open")
            return
        }

        do {
            _ = try await quickActionHandler.handle(url: url)
            reconcileLiveActivity(source: "app.url.live_activity")
        } catch {
            diagnosticsLogger.recordError(
                context: "live_activity.url",
                message: error.localizedDescription,
                metadata: ["url": url.absoluteString],
                source: "ios-app"
            )
        }
    }
}

#if canImport(AppIntents)
@available(iOS 17.0, *)
extension FeedTrackerDependencies: FeedTrackerLiveActivityIntentAppExecuting {
    func execute(
        action: LiveActivityQuickAction,
        targetSessionID: String
    ) async throws -> FeedTrackerLiveActivityIntentExecutionReport {
        let source = "app.live_activity_intent"
        preloadEngineForAppHostedIntent(source: source)

        diagnosticsLogger.record(
            category: "live_activity_intent",
            action: "execute_in_app_host",
            metadata: [
                "action": action.rawValue,
                "targetSessionID": targetSessionID
            ],
            source: "ios-app"
        )

        _ = try await quickActionHandler.handle(action)
        persistRecoveryStateForAppHostedIntent(source: source)

        do {
            try await historyViewModel.reload()
        } catch {
            diagnosticsLogger.recordError(
                context: "live_activity_intent.history_reload",
                message: error.localizedDescription,
                metadata: ["action": action.rawValue],
                source: "ios-app"
            )
        }

        reconcileLiveActivity(source: source)

        let report = FeedTrackerLiveActivityIntentExecutionReport(
            source: "app_live_activity_intent",
            reason: "quick_action_execute_with_app_host",
            executionHost: "app",
            refreshStrategy: "app_live_activity_coordinator",
            renderVersion: FeedTrackerSharedStorage.currentLiveActivityRenderVersion(),
            displayedRefreshAttempt: "app_reconcile_requested",
            shouldPostExternalSyncSignal: false
        )

        diagnosticsLogger.record(
            category: "live_activity_intent",
            action: "app_host_reconcile_requested",
            metadata: [
                "action": action.rawValue,
                "targetSessionID": targetSessionID,
                "renderVersion": "\(report.renderVersion ?? 0)"
            ],
            source: "ios-app"
        )

        return report
    }
}
#endif

enum DeviceModel {
    static func currentIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { partialResult, element in
            guard let value = element.value as? Int8, value != 0 else {
                return
            }
            partialResult.append(Character(UnicodeScalar(UInt8(value))))
        }

        return identifier.isEmpty ? "unknown" : identifier
    }
}

@main
@MainActor
struct FeedTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let deps = FeedTrackerDependencies()

    var body: some Scene {
        WindowGroup {
            FeedTrackerMainNavigationView(
                activeSessionViewModel: deps.activeSessionViewModel,
                historyViewModel: deps.historyViewModel,
                diagnosticsExportViewModel: deps.diagnosticsExportViewModel
            )
            .onAppear {
                Task {
                    await deps.handleAppLaunch()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                Task {
                    await deps.handleScenePhase(newPhase)
                }
            }
            .onOpenURL { url in
                Task {
                    await deps.handleLiveActivityURL(url)
                }
            }
        }
    }
}
