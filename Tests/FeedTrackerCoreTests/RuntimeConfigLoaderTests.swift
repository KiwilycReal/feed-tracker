import XCTest
@testable import FeedTrackerCore

final class RuntimeConfigLoaderTests: XCTestCase {
    func testLoadReturnsConfigWhenEnvironmentIsValid() throws {
        let reader = FakeEnvironmentReader(values: [
            "FEED_TRACKER_ENV": "staging",
            "FEED_TRACKER_API_BASE_URL": "https://api.example.com",
            "FEED_TRACKER_REQUEST_TIMEOUT_SECONDS": "20"
        ])

        let config = try RuntimeConfigLoader.load(reader: reader)

        XCTAssertEqual(config.environment, .staging)
        XCTAssertEqual(config.apiBaseURL.absoluteString, "https://api.example.com")
        XCTAssertEqual(config.requestTimeoutSeconds, 20)
    }

    func testLoadThrowsWhenURLIsInvalid() {
        let reader = FakeEnvironmentReader(values: [
            "FEED_TRACKER_ENV": "development",
            "FEED_TRACKER_API_BASE_URL": "not-a-url",
            "FEED_TRACKER_REQUEST_TIMEOUT_SECONDS": "20"
        ])

        XCTAssertThrowsError(try RuntimeConfigLoader.load(reader: reader)) { error in
            XCTAssertEqual(error as? RuntimeConfigError, .invalidURL(value: "not-a-url"))
        }
    }

    func testLoadThrowsWhenValueIsMissing() {
        let reader = FakeEnvironmentReader(values: [
            "FEED_TRACKER_ENV": "production",
            "FEED_TRACKER_REQUEST_TIMEOUT_SECONDS": "20"
        ])

        XCTAssertThrowsError(try RuntimeConfigLoader.load(reader: reader)) { error in
            XCTAssertEqual(error as? RuntimeConfigError, .missingValue(key: "FEED_TRACKER_API_BASE_URL"))
        }
    }
}

private struct FakeEnvironmentReader: EnvironmentValueReading {
    let values: [String: String]

    func value(for key: String) -> String? {
        values[key]
    }
}
