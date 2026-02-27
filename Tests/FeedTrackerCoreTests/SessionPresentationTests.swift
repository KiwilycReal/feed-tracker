import XCTest
@testable import FeedTrackerCore

final class SessionPresentationTests: XCTestCase {
    func testDurationTextUsesMinuteSecondFormatUnderOneHour() {
        XCTAssertEqual(SessionPresentation.durationText(0), "00:00")
        XCTAssertEqual(SessionPresentation.durationText(75), "01:15")
        XCTAssertEqual(SessionPresentation.durationText(3_599), "59:59")
    }

    func testDurationTextUsesHourMinuteSecondFormatAtOrAboveOneHour() {
        XCTAssertEqual(SessionPresentation.durationText(3_600), "01:00:00")
        XCTAssertEqual(SessionPresentation.durationText(3_661), "01:01:01")
    }

    func testStatusTitleMatchesState() {
        XCTAssertEqual(SessionPresentation.statusTitle(for: .idle), "Ready to start")
        XCTAssertEqual(SessionPresentation.statusTitle(for: .running(side: .left)), "Running · Left")
        XCTAssertEqual(SessionPresentation.statusTitle(for: .paused(side: .right)), "Paused · Right")
        XCTAssertEqual(SessionPresentation.statusTitle(for: .stopped), "Stopped")
        XCTAssertEqual(SessionPresentation.statusTitle(for: .ended), "Session completed")
    }
}
