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
}
