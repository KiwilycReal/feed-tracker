import XCTest
@testable import FeedTrackerCore

final class DiagnosticsExportTests: XCTestCase {
    func testRedactionMasksSensitiveMetadataAndMessages() async {
        let logger = DiagnosticsEventLogger(defaultSourceTag: "ios-app")

        await logger.recordEvent(
            category: "persistence",
            action: "save",
            metadata: [
                "note": "fed 120ml at 2am",
                "duration": "120"
            ],
            source: "history_vm"
        )

        await logger.recordErrorEvent(
            context: "history.edit",
            message: "Authorization token expired while saving",
            metadata: [
                "api_key": "super-secret",
                "sessionID": "abc"
            ],
            source: "history_vm"
        )

        let payload = await logger.makeExportPayload(
            appVersion: "0.1.0",
            buildNumber: "2",
            deviceModel: "iPhone17,2",
            maxEvents: 100
        )

        XCTAssertEqual(payload.events.count, 2)

        let saveEvent = try? XCTUnwrap(payload.events.first)
        XCTAssertEqual(saveEvent?.metadata["note"], "<redacted>")
        XCTAssertEqual(saveEvent?.metadata["duration"], "120")

        XCTAssertEqual(payload.lastErrorSummary?.message, "<redacted>")

        let errorEvent = payload.events.last
        XCTAssertEqual(errorEvent?.metadata["api_key"], "<redacted>")
        XCTAssertEqual(errorEvent?.metadata["summary"], "<redacted>")
    }

    func testExportPayloadSchemaIncludesRequiredFieldsAndLastNEvents() async {
        let logger = DiagnosticsEventLogger(defaultSourceTag: "ios-app", capacity: 500)

        for index in 0..<130 {
            await logger.recordEvent(
                category: "session",
                action: "tick",
                metadata: ["index": "\(index)"],
                source: "active_session_vm"
            )
        }

        let payload = await logger.makeExportPayload(
            appVersion: "0.2.0",
            buildNumber: "42",
            deviceModel: "iPhone17,2",
            sourceTag: "ios-app",
            maxEvents: 120
        )

        XCTAssertEqual(payload.appVersion, "0.2.0")
        XCTAssertEqual(payload.buildNumber, "42")
        XCTAssertEqual(payload.deviceModel, "iPhone17,2")
        XCTAssertEqual(payload.sourceTag, "ios-app")
        XCTAssertEqual(payload.events.count, 120)
        XCTAssertEqual(payload.events.first?.metadata["index"], "10")
        XCTAssertEqual(payload.events.last?.metadata["index"], "129")
        XCTAssertNil(payload.lastErrorSummary)
    }
}
