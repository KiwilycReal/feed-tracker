import XCTest
@testable import FeedTrackerCore

final class FeedItemTests: XCTestCase {
    func testValidationWithNonEmptyTitleIsValid() {
        let item = FeedItem(title: "Tech", url: URL(string: "https://example.com")!)
        XCTAssertTrue(FeedValidator.isValid(item))
    }

    func testValidationWithBlankTitleIsInvalid() {
        let item = FeedItem(title: "   ", url: URL(string: "https://example.com")!)
        XCTAssertFalse(FeedValidator.isValid(item))
    }
}
