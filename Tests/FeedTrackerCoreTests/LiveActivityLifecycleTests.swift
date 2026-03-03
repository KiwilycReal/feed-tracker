import Foundation
import XCTest
@testable import FeedTrackerCore

@MainActor
final class LiveActivityLifecycleTests: XCTestCase {
    func testLiveActivityRemainsContinuouslyUpdatableAcrossBackgroundExitAndRelaunch() throws {
        let clock = LiveActivityTestClock(start: Date(timeIntervalSince1970: 120_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let controller = SpyLiveActivityController()
        let coordinator = LiveActivityLifecycleCoordinator(
            controller: controller,
            now: { clock.now }
        )

        try engine.start(.left)
        clock.advance(seconds: 40)
        coordinator.reconcile(snapshot: engine.snapshot(), source: "foreground")
        XCTAssertEqual(controller.startCount, 1)
        XCTAssertEqual(controller.lastState?.timerStatusRawValue, LiveActivityTimerStatus.running.rawValue)

        clock.advance(seconds: 25)
        coordinator.reconcile(snapshot: engine.snapshot(), source: "background")
        XCTAssertEqual(controller.updateCount, 1)

        clock.advance(seconds: 35)

        let relaunchedEngine = SessionTimerEngine(now: { clock.now })
        let recovery = try XCTUnwrap(engine.recoveryStateForPersistence())
        try relaunchedEngine.restore(from: recovery)
        coordinator.reconcile(snapshot: relaunchedEngine.snapshot(), source: "relaunch")

        XCTAssertEqual(controller.startCount, 1)
        XCTAssertGreaterThanOrEqual(controller.updateCount, 2)
        XCTAssertEqual(controller.lastState?.timerStatusRawValue, LiveActivityTimerStatus.running.rawValue)
        let projected = try XCTUnwrap(controller.lastState?.projectedTotalElapsed(at: clock.now))
        XCTAssertEqual(projected, 100, accuracy: 0.001)
    }

    func testEndingSessionEndsLiveActivityAndDoesNotRestoreAfterRelaunch() throws {
        let clock = LiveActivityTestClock(start: Date(timeIntervalSince1970: 130_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let controller = SpyLiveActivityController()
        let coordinator = LiveActivityLifecycleCoordinator(
            controller: controller,
            now: { clock.now }
        )

        try engine.start(.right)
        coordinator.reconcile(snapshot: engine.snapshot(), source: "running")
        _ = try engine.endSession(note: nil)
        coordinator.reconcile(snapshot: engine.snapshot(), source: "ended")

        XCTAssertEqual(controller.endCount, 1)
        XCTAssertFalse(controller.isActive)

        let relaunchedEngine = SessionTimerEngine(now: { clock.now })
        coordinator.reconcile(snapshot: relaunchedEngine.snapshot(), source: "relaunch")

        XCTAssertEqual(controller.startCount, 1)
        XCTAssertGreaterThanOrEqual(controller.endCount, 1)
    }

    func testCompactTimerProjectionStaysContinuousFromCapturedCheckpoint() {
        let now = Date(timeIntervalSince1970: 140_000)
        let state = FeedTrackerLiveActivityContentState(
            state: LiveActivityState(
                snapshot: SessionTimerSnapshot(
                    state: .running(side: .left),
                    activeSide: .left,
                    leftElapsed: 55,
                    rightElapsed: 10,
                    totalElapsed: 65,
                    startedAt: now.addingTimeInterval(-65),
                    endedAt: nil
                )
            ),
            capturedAt: now
        )

        let later = now.addingTimeInterval(30)
        XCTAssertEqual(state.projectedTotalElapsed(at: later), 95, accuracy: 0.001)
    }
}

@MainActor
private final class SpyLiveActivityController: LiveActivityControlling {
    private(set) var isActive = false
    private(set) var startCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var lastState: FeedTrackerLiveActivityAttributes.ContentState?

    func start(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState) {
        isActive = true
        startCount += 1
        lastState = state
    }

    func update(state: FeedTrackerLiveActivityAttributes.ContentState) {
        guard isActive else {
            return
        }
        updateCount += 1
        lastState = state
    }

    func end() {
        isActive = false
        endCount += 1
    }
}

private final class LiveActivityTestClock {
    var now: Date

    init(start: Date) {
        now = start
    }

    func advance(seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
