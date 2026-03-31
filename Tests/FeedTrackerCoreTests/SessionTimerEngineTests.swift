import Foundation
import XCTest
@testable import FeedTrackerCore

final class SessionTimerEngineTests: XCTestCase {
    func testEngineAggregatesElapsedAcrossSwitchPauseResumeAndEnd() throws {
        let clock = TestClock(start: Date(timeIntervalSince1970: 1_000))
        let engine = SessionTimerEngine(now: { clock.now })

        try engine.start(.left)
        clock.advance(seconds: 30)

        try engine.switch(to: .right)
        clock.advance(seconds: 20)

        try engine.pause()
        clock.advance(seconds: 15) // pause should not accumulate

        try engine.resume()
        clock.advance(seconds: 10)

        let runningSnapshot = engine.snapshot()
        XCTAssertEqual(runningSnapshot.state, .running(side: .right))
        XCTAssertEqual(runningSnapshot.leftElapsed, 30, accuracy: 0.001)
        XCTAssertEqual(runningSnapshot.rightElapsed, 30, accuracy: 0.001)
        XCTAssertEqual(runningSnapshot.totalElapsed, 60, accuracy: 0.001)

        let completed = try engine.endSession(note: "night feed")
        XCTAssertEqual(completed.leftDuration, 30, accuracy: 0.001)
        XCTAssertEqual(completed.rightDuration, 30, accuracy: 0.001)
        XCTAssertEqual(completed.totalDuration, 60, accuracy: 0.001)
        XCTAssertEqual(completed.note, "night feed")
        XCTAssertEqual(completed.status, .completed)

        let endedSnapshot = engine.snapshot()
        XCTAssertEqual(endedSnapshot.state, .ended)
    }

    func testStopCurrentSideAllowsRestartOnAnotherSide() throws {
        let clock = TestClock(start: Date(timeIntervalSince1970: 2_000))
        let engine = SessionTimerEngine(now: { clock.now })

        try engine.start(.left)
        clock.advance(seconds: 12)
        try engine.stopCurrentSide()

        let stopped = engine.snapshot()
        XCTAssertEqual(stopped.state, .stopped)
        XCTAssertEqual(stopped.leftElapsed, 12, accuracy: 0.001)

        try engine.start(.right)
        clock.advance(seconds: 18)

        let running = engine.snapshot()
        XCTAssertEqual(running.state, .running(side: .right))
        XCTAssertEqual(running.rightElapsed, 18, accuracy: 0.001)
        XCTAssertEqual(running.totalElapsed, 30, accuracy: 0.001)
    }

    func testStartAfterEndingCreatesFreshSessionWithoutAppRestart() throws {
        let clock = TestClock(start: Date(timeIntervalSince1970: 2_500))
        let engine = SessionTimerEngine(now: { clock.now })

        try engine.start(.left)
        clock.advance(seconds: 20)
        _ = try engine.endSession(note: "first")

        clock.advance(seconds: 5)
        try engine.start(.right)
        clock.advance(seconds: 12)

        let snapshot = engine.snapshot()
        XCTAssertEqual(snapshot.state, .running(side: .right))
        XCTAssertEqual(snapshot.leftElapsed, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.rightElapsed, 12, accuracy: 0.001)
        XCTAssertEqual(snapshot.totalElapsed, 12, accuracy: 0.001)
    }

    func testTerminalEndedStateRejectsStaleMutationsWithoutChangingSnapshot() throws {
        let clock = TestClock(start: Date(timeIntervalSince1970: 2_900))
        let engine = SessionTimerEngine(now: { clock.now })

        try engine.start(.left)
        clock.advance(seconds: 8)
        _ = try engine.endSession(note: nil)

        let baseline = engine.snapshot()

        XCTAssertThrowsError(try engine.pause())
        XCTAssertThrowsError(try engine.resume())
        XCTAssertThrowsError(try engine.stopCurrentSide())
        XCTAssertThrowsError(try engine.switch(to: .right))

        let after = engine.snapshot()
        XCTAssertEqual(after.state, .ended)
        XCTAssertEqual(after.leftElapsed, baseline.leftElapsed, accuracy: 0.001)
        XCTAssertEqual(after.rightElapsed, baseline.rightElapsed, accuracy: 0.001)
        XCTAssertEqual(after.totalElapsed, baseline.totalElapsed, accuracy: 0.001)
    }

    func testInvalidTransitionResumeWithoutPauseThrows() throws {
        let clock = TestClock(start: Date(timeIntervalSince1970: 3_000))
        let engine = SessionTimerEngine(now: { clock.now })

        XCTAssertThrowsError(try engine.resume()) { error in
            XCTAssertEqual(
                error as? SessionTimerEngineError,
                .invalidTransition(action: "resume", state: .idle)
            )
        }
    }

    func testResetClearsRecoveredOrRunningStateBackToIdle() throws {
        let clock = TestClock(start: Date(timeIntervalSince1970: 3_100))
        let engine = SessionTimerEngine(now: { clock.now })

        try engine.start(.right)
        clock.advance(seconds: 14)
        engine.reset()

        let snapshot = engine.snapshot()
        XCTAssertEqual(snapshot.state, .idle)
        XCTAssertNil(snapshot.activeSide)
        XCTAssertEqual(snapshot.leftElapsed, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.rightElapsed, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.totalElapsed, 0, accuracy: 0.001)
    }

    func testRecoveryStateDecodesLegacyPayloadWithoutSessionID() throws {
        let legacyPayload = """
        {
          \"status\": \"runningLeft\",
          \"startedAt\": \"2026-03-20T12:00:00Z\",
          \"runningSince\": \"2026-03-20T12:00:10Z\",
          \"leftAccumulated\": 12,
          \"rightAccumulated\": 3
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let recoveryState = try decoder.decode(SessionTimerRecoveryState.self, from: legacyPayload)
        let decodedAgain = try decoder.decode(SessionTimerRecoveryState.self, from: legacyPayload)

        XCTAssertEqual(recoveryState.status, .runningLeft)
        XCTAssertEqual(recoveryState.leftAccumulated, 12, accuracy: 0.001)
        XCTAssertEqual(recoveryState.rightAccumulated, 3, accuracy: 0.001)
        XCTAssertEqual(recoveryState.sessionID, decodedAgain.sessionID)
    }

    func testClockStateProjectsRunningElapsedFromRecordedCheckpoint() throws {
        let clock = TestClock(start: Date(timeIntervalSince1970: 3_200))
        let engine = SessionTimerEngine(now: { clock.now })

        try engine.start(.left)
        clock.advance(seconds: 12)

        let recordedAt = clock.now
        let clockState = engine.clockState(at: recordedAt)

        clock.advance(seconds: 9)
        let projected = clockState.snapshot(at: clock.now)

        XCTAssertEqual(clockState.status, .runningLeft)
        XCTAssertEqual(clockState.runningSince?.timeIntervalSince1970 ?? -1, recordedAt.addingTimeInterval(-12).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(projected.leftElapsed, 21, accuracy: 0.001)
        XCTAssertEqual(projected.rightElapsed, 0, accuracy: 0.001)
        XCTAssertEqual(projected.totalElapsed, 21, accuracy: 0.001)
    }

    func testClockStateRecoveryStateKeepsPausedSideWithoutRunningAnchor() {
        let startedAt = Date(timeIntervalSince1970: 3_300)
        let recordedAt = startedAt.addingTimeInterval(25)
        let sessionID = UUID()

        let clockState = SessionTimerClockState(
            sessionID: sessionID,
            status: .pausedRight,
            startedAt: startedAt,
            endedAt: nil,
            runningSince: nil,
            leftAccumulated: 8,
            rightAccumulated: 17,
            recordedAt: recordedAt
        )

        let recoveryState = clockState.recoveryState

        XCTAssertEqual(recoveryState?.sessionID, sessionID)
        XCTAssertEqual(recoveryState?.status, .pausedRight)
        XCTAssertEqual(recoveryState?.runningSince, nil)
        XCTAssertEqual(recoveryState?.leftAccumulated ?? -1, 8, accuracy: 0.001)
        XCTAssertEqual(recoveryState?.rightAccumulated ?? -1, 17, accuracy: 0.001)
    }
}

private final class TestClock {
    var now: Date

    init(start: Date) {
        self.now = start
    }

    func advance(seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
