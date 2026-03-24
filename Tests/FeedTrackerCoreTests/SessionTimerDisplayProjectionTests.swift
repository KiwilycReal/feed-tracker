import Foundation
import XCTest
@testable import FeedTrackerCore

final class SessionTimerDisplayProjectionTests: XCTestCase {
    func testSnapshotValuesRoundEachSideAndDeriveTotalFromDisplayedSides() {
        let snapshot = SessionTimerSnapshot(
            state: .paused(side: .right),
            activeSide: .right,
            leftElapsed: 1.8,
            rightElapsed: 5.6,
            totalElapsed: 7.4,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: nil
        )

        let values = SessionTimerDisplayProjection.values(snapshot: snapshot)

        XCTAssertEqual(values.leftElapsed, 2, accuracy: 0.001)
        XCTAssertEqual(values.rightElapsed, 6, accuracy: 0.001)
        XCTAssertEqual(values.activeSideElapsed, 6, accuracy: 0.001)
        XCTAssertEqual(values.totalElapsed, 8, accuracy: 0.001)
    }

    func testProjectedValuesFreezePauseWithoutDroppingDisplayedSecond() {
        let capturedAt = Date(timeIntervalSince1970: 2_000.25)
        let values = SessionTimerDisplayProjection.values(
            state: LiveActivityState(
                activeSide: .left,
                leftElapsed: 13,
                rightElapsed: 4,
                totalElapsed: 17,
                startedAt: capturedAt.addingTimeInterval(-16.8),
                endedAt: nil,
                timerStatus: .paused
            ),
            capturedAt: capturedAt,
            now: capturedAt.addingTimeInterval(20)
        )

        XCTAssertEqual(values.leftElapsed, 13, accuracy: 0.001)
        XCTAssertEqual(values.rightElapsed, 4, accuracy: 0.001)
        XCTAssertEqual(values.activeSideElapsed, 13, accuracy: 0.001)
        XCTAssertEqual(values.totalElapsed, 17, accuracy: 0.001)
    }

    func testProjectedValuesAdvanceOnlyOnWholeSecondBoundariesFromCapturedBaseline() {
        let capturedAt = Date(timeIntervalSince1970: 3_000.10)
        let baselineState = LiveActivityState(
            activeSide: .right,
            leftElapsed: 3,
            rightElapsed: 12,
            totalElapsed: 15,
            startedAt: capturedAt.addingTimeInterval(-14.8),
            endedAt: nil,
            timerStatus: .running
        )

        let beforeBoundary = SessionTimerDisplayProjection.values(
            state: baselineState,
            capturedAt: capturedAt,
            now: capturedAt.addingTimeInterval(0.95)
        )
        XCTAssertEqual(beforeBoundary.leftElapsed, 3, accuracy: 0.001)
        XCTAssertEqual(beforeBoundary.rightElapsed, 12, accuracy: 0.001)
        XCTAssertEqual(beforeBoundary.activeSideElapsed, 12, accuracy: 0.001)
        XCTAssertEqual(beforeBoundary.totalElapsed, 15, accuracy: 0.001)

        let afterBoundary = SessionTimerDisplayProjection.values(
            state: baselineState,
            capturedAt: capturedAt,
            now: capturedAt.addingTimeInterval(1.05)
        )
        XCTAssertEqual(afterBoundary.leftElapsed, 3, accuracy: 0.001)
        XCTAssertEqual(afterBoundary.rightElapsed, 13, accuracy: 0.001)
        XCTAssertEqual(afterBoundary.activeSideElapsed, 13, accuracy: 0.001)
        XCTAssertEqual(afterBoundary.totalElapsed, 16, accuracy: 0.001)
    }
}
