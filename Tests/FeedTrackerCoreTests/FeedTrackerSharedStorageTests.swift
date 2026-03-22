import Foundation
import XCTest
@testable import FeedTrackerCore

final class FeedTrackerSharedStorageTests: XCTestCase {
    func testLiveActivityDisplayTargetRoundTripsAndClears() {
        let suiteName = "FeedTrackerSharedStorageTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated test user defaults suite")
            return
        }

        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let written = FeedTrackerSharedStorage.writeLiveActivityDisplayTarget(
            activityID: "activity-123",
            sessionID: "session-456",
            userDefaults: userDefaults
        )

        XCTAssertEqual(written, LiveActivityDisplayTarget(activityID: "activity-123", sessionID: "session-456"))
        XCTAssertEqual(
            FeedTrackerSharedStorage.readLiveActivityDisplayTarget(userDefaults: userDefaults),
            written
        )

        FeedTrackerSharedStorage.clearLiveActivityDisplayTarget(userDefaults: userDefaults)
        XCTAssertNil(FeedTrackerSharedStorage.readLiveActivityDisplayTarget(userDefaults: userDefaults))
    }

    func testExternalSyncContextRoundTripsAndClears() {
        let suiteName = "FeedTrackerSharedStorageTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated test user defaults suite")
            return
        }

        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let written = FeedTrackerSharedStorage.writeExternalSyncContext(
            marker: "marker-123",
            source: "widget_live_activity_intent",
            reason: "quick_action_execute_and_refresh",
            action: "pause_session",
            sessionID: "session-456",
            renderVersion: 42,
            displayedRefreshAttempt: "skipped_no_visible_activity",
            executionHost: "widget_extension",
            refreshStrategy: "activitykit_direct_refresh",
            timestamp: timestamp,
            userDefaults: userDefaults
        )

        XCTAssertEqual(
            written,
            ExternalSyncContext(
                marker: "marker-123",
                source: "widget_live_activity_intent",
                reason: "quick_action_execute_and_refresh",
                action: "pause_session",
                sessionID: "session-456",
                renderVersion: 42,
                displayedRefreshAttempt: "skipped_no_visible_activity",
                executionHost: "widget_extension",
                refreshStrategy: "activitykit_direct_refresh",
                timestamp: timestamp
            )
        )
        XCTAssertEqual(
            FeedTrackerSharedStorage.readExternalSyncContext(userDefaults: userDefaults),
            written
        )

        FeedTrackerSharedStorage.clearExternalSyncContext(userDefaults: userDefaults)
        XCTAssertNil(FeedTrackerSharedStorage.readExternalSyncContext(userDefaults: userDefaults))
    }
}
