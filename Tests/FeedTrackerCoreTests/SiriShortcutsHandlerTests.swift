import Foundation
import XCTest
@testable import FeedTrackerCore

@MainActor
final class SiriShortcutsHandlerTests: XCTestCase {
    func testStartTrackingUsesDefaultSideWhenNoSideIsProvided() throws {
        let clock = SiriShortcutTestClock(start: Date(timeIntervalSince1970: 130_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let handler = SiriShortcutsHandler(engine: engine, defaultStartSide: .left)

        let status = try handler.startTracking()

        XCTAssertEqual(status.state, .running(side: .left))
        XCTAssertEqual(status.activeSide, .left)
        XCTAssertEqual(status.phrase, "Left side active. Total elapsed 00:00.")
    }

    func testStartTrackingCanSwitchSidesFromRunningState() throws {
        let clock = SiriShortcutTestClock(start: Date(timeIntervalSince1970: 140_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let handler = SiriShortcutsHandler(engine: engine, defaultStartSide: .left)

        _ = try handler.startTracking(sideOption: .left)
        clock.advance(seconds: 22)
        _ = try handler.startTracking(sideOption: .right)
        clock.advance(seconds: 8)

        let status = handler.readCurrentStatus()
        XCTAssertEqual(status.state, .running(side: .right))
        XCTAssertEqual(status.totalElapsed, 30, accuracy: 0.001)
        XCTAssertEqual(status.phrase, "Right side active. Total elapsed 00:30.")
    }

    func testReadCurrentStatusReturnsPausedPhraseWithElapsedTotal() throws {
        let clock = SiriShortcutTestClock(start: Date(timeIntervalSince1970: 150_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let handler = SiriShortcutsHandler(engine: engine, defaultStartSide: .right)

        _ = try handler.startTracking(sideOption: .default)
        clock.advance(seconds: 12)
        try engine.pause()

        let status = handler.readCurrentStatus()
        XCTAssertEqual(status.state, .paused(side: .right))
        XCTAssertEqual(status.phrase, "Session paused on right side. Total elapsed 00:12.")
    }

    func testStartTrackingThrowsWhenSessionAlreadyEnded() throws {
        let clock = SiriShortcutTestClock(start: Date(timeIntervalSince1970: 160_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let handler = SiriShortcutsHandler(engine: engine)

        _ = try handler.startTracking(sideOption: .left)
        clock.advance(seconds: 6)
        _ = try engine.endSession()

        XCTAssertThrowsError(try handler.startTracking(sideOption: .right)) { error in
            XCTAssertEqual(error as? SiriShortcutError, .cannotStartAfterSessionEnded)
        }
    }
}

#if canImport(AppIntents)
import AppIntents

@available(macOS 14.0, *)
@MainActor
final class SiriAppIntentsBridgeTests: XCTestCase {
    override func tearDown() {
        FeedTrackerSiriIntentDependency.handler = nil
        super.tearDown()
    }

    func testStartFeedTrackingIntentUsesDefaultStrategyWhenConfigured() async throws {
        let clock = SiriShortcutTestClock(start: Date(timeIntervalSince1970: 170_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let handler = SiriShortcutsHandler(engine: engine, defaultStartSide: .right)
        FeedTrackerSiriIntentDependency.handler = handler

        let intent = StartFeedTrackingIntent()
        _ = try await intent.perform()

        let status = handler.readCurrentStatus()
        XCTAssertEqual(status.activeSide, .right)
        XCTAssertEqual(status.state, .running(side: .right))
    }

    func testReadFeedTrackingStatusIntentRunsWithoutConfiguredSideInput() async throws {
        let clock = SiriShortcutTestClock(start: Date(timeIntervalSince1970: 175_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let handler = SiriShortcutsHandler(engine: engine)
        FeedTrackerSiriIntentDependency.handler = handler

        _ = try handler.startTracking(sideOption: .left)
        clock.advance(seconds: 15)

        let intent = ReadFeedTrackingStatusIntent()
        _ = try await intent.perform()

        let status = handler.readCurrentStatus()
        XCTAssertEqual(status.totalElapsed, 15, accuracy: 0.001)
    }

    func testStartFeedTrackingIntentFallsBackSafelyWhenDependencyIsMissing() async throws {
        FeedTrackerSiriIntentDependency.handler = nil

        let intent = StartFeedTrackingIntent(side: .left)
        _ = try await intent.perform()

        XCTAssertNil(FeedTrackerSiriIntentDependency.handler)
    }

    func testStartupWiringRegistersSiriHandlerWithSharedEngineState() throws {
        let clock = SiriShortcutTestClock(start: Date(timeIntervalSince1970: 180_000))
        let engine = SessionTimerEngine(now: { clock.now })

        let wired = FeedTrackerSiriIntentStartupWiring.wireHandler(
            engine: engine,
            defaultStartSide: .right
        )

        XCTAssertTrue(FeedTrackerSiriIntentDependency.handler === wired)

        _ = try wired.startTracking()
        clock.advance(seconds: 7)

        let status = wired.readCurrentStatus()
        XCTAssertEqual(status.activeSide, .right)
        XCTAssertEqual(status.totalElapsed, 7, accuracy: 0.001)
    }

    func testAppShortcutsProviderPublishesThreeShortcuts() {
        XCTAssertEqual(FeedTrackerAppShortcutsProvider.appShortcuts.count, 3)
    }
}
#endif

private final class SiriShortcutTestClock {
    var now: Date

    init(start: Date) {
        self.now = start
    }

    func advance(seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
