#if canImport(AppIntents)
import XCTest
@testable import FeedTrackerCore

@MainActor
final class FeedTrackerLiveActivityAppIntentTests: XCTestCase {
    func testRuntimePrefersAppExecutorWhenAvailable() async throws {
        let appExecutor = AppExecutorSpy(
            report: FeedTrackerLiveActivityIntentExecutionReport(
                source: "app_live_activity_intent",
                reason: "quick_action_execute_with_app_host",
                executionHost: "app",
                refreshStrategy: "app_live_activity_coordinator",
                renderVersion: 51,
                displayedRefreshAttempt: "app_reconcile_requested",
                shouldPostExternalSyncSignal: false
            )
        )
        let emitter = SyncEmitterSpy()
        var fallbackCalled = false

        let report = try await FeedTrackerLiveActivityIntentRuntime.execute(
            action: .pauseSession,
            targetSessionID: "session-123",
            appExecutorProvider: { appExecutor },
            fallbackExecutor: { _, _ in
                fallbackCalled = true
                return FeedTrackerLiveActivityIntentExecutionReport(
                    source: "widget_live_activity_intent",
                    reason: "quick_action_execute_and_refresh",
                    executionHost: "widget_extension",
                    refreshStrategy: "activitykit_direct_refresh",
                    renderVersion: 52,
                    displayedRefreshAttempt: "updated_visible_activity",
                    shouldPostExternalSyncSignal: true
                )
            },
            externalSyncEmitter: emitter.capture
        )

        XCTAssertFalse(fallbackCalled)
        XCTAssertEqual(appExecutor.receivedActions, [.pauseSession])
        XCTAssertEqual(appExecutor.receivedSessionIDs, ["session-123"])
        XCTAssertEqual(report.executionHost, "app")
        XCTAssertEqual(emitter.capturedReports.map(\.executionHost), ["app"])
    }

    func testRuntimeFallsBackWhenAppExecutorIsUnavailable() async throws {
        let emitter = SyncEmitterSpy()
        var fallbackActions: [LiveActivityQuickAction] = []
        var fallbackSessionIDs: [String] = []

        let report = try await FeedTrackerLiveActivityIntentRuntime.execute(
            action: .switchSide,
            targetSessionID: "session-456",
            appExecutorProvider: { nil },
            fallbackExecutor: { action, sessionID in
                fallbackActions.append(action)
                fallbackSessionIDs.append(sessionID)
                return FeedTrackerLiveActivityIntentExecutionReport(
                    source: "widget_live_activity_intent",
                    reason: "quick_action_execute_and_refresh",
                    executionHost: "widget_extension",
                    refreshStrategy: "activitykit_direct_refresh",
                    renderVersion: 77,
                    displayedRefreshAttempt: "updated_visible_activity",
                    shouldPostExternalSyncSignal: true
                )
            },
            externalSyncEmitter: emitter.capture
        )

        XCTAssertEqual(fallbackActions, [.switchSide])
        XCTAssertEqual(fallbackSessionIDs, ["session-456"])
        XCTAssertEqual(report.executionHost, "widget_extension")
        XCTAssertEqual(emitter.capturedReports.map(\.executionHost), ["widget_extension"])
    }
}

@MainActor
private final class AppExecutorSpy: FeedTrackerLiveActivityIntentAppExecuting {
    private(set) var receivedActions: [LiveActivityQuickAction] = []
    private(set) var receivedSessionIDs: [String] = []
    private let report: FeedTrackerLiveActivityIntentExecutionReport

    init(report: FeedTrackerLiveActivityIntentExecutionReport) {
        self.report = report
    }

    func execute(
        action: LiveActivityQuickAction,
        targetSessionID: String
    ) async throws -> FeedTrackerLiveActivityIntentExecutionReport {
        receivedActions.append(action)
        receivedSessionIDs.append(targetSessionID)
        return report
    }
}

private final class SyncEmitterSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [FeedTrackerLiveActivityIntentExecutionReport] = []

    var capturedReports: [FeedTrackerLiveActivityIntentExecutionReport] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func capture(
        _ report: FeedTrackerLiveActivityIntentExecutionReport,
        _: LiveActivityQuickAction,
        _: String
    ) {
        lock.lock()
        storage.append(report)
        lock.unlock()
    }
}
#endif
