import Foundation
import XCTest
@testable import FeedTrackerCore

@MainActor
final class LiveActivityLifecycleTests: XCTestCase {
    func testLiveActivityRemainsContinuouslyUpdatableAcrossBackgroundExitAndRelaunch() throws {
        let clock = LiveActivityTestClock(start: Date(timeIntervalSince1970: 120_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let controller = SpyLiveActivityController()
        let renderVersion = RenderVersionCounter()
        let coordinator = LiveActivityLifecycleCoordinator(
            controller: controller,
            now: { clock.now },
            nextRenderVersion: { renderVersion.next() }
        )

        try engine.start(.left)
        clock.advance(seconds: 40)
        coordinator.reconcile(snapshot: engine.snapshot(), source: "foreground")
        XCTAssertEqual(controller.startCount, 1)
        XCTAssertEqual(controller.lastState?.timerStatusRawValue, LiveActivityTimerStatus.running.rawValue)
        XCTAssertGreaterThan(controller.lastState?.renderVersion ?? 0, 0)

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

    func testCoordinatorUsesSnapshotSessionIdentifierWhenAvailable() {
        let clock = LiveActivityTestClock(start: Date(timeIntervalSince1970: 121_000))
        let controller = SpyLiveActivityController()
        let renderVersion = RenderVersionCounter()
        let coordinator = LiveActivityLifecycleCoordinator(
            controller: controller,
            now: { clock.now },
            nextRenderVersion: { renderVersion.next() }
        )

        let expectedSessionID = UUID(uuidString: "00000000-0000-0000-0000-00000000HF51".replacingOccurrences(of: "HF51", with: "1351"))!
        let snapshot = SessionTimerSnapshot(
            sessionID: expectedSessionID,
            state: .running(side: .left),
            activeSide: .left,
            leftElapsed: 22,
            rightElapsed: 3,
            totalElapsed: 25,
            startedAt: clock.now.addingTimeInterval(-25),
            endedAt: nil
        )

        coordinator.reconcile(snapshot: snapshot, source: "session-id-check")

        XCTAssertEqual(controller.lastStartSessionID, expectedSessionID)
        XCTAssertEqual(controller.lastObservedSessionID, expectedSessionID)
    }

    func testEndingSessionEndsLiveActivityAndDoesNotRestoreAfterRelaunch() throws {
        let clock = LiveActivityTestClock(start: Date(timeIntervalSince1970: 130_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let controller = SpyLiveActivityController()
        let renderVersion = RenderVersionCounter()
        let coordinator = LiveActivityLifecycleCoordinator(
            controller: controller,
            now: { clock.now },
            nextRenderVersion: { renderVersion.next() }
        )

        try engine.start(.right)
        coordinator.reconcile(snapshot: engine.snapshot(), source: "running")
        _ = try engine.endSession(note: nil)
        coordinator.reconcile(snapshot: engine.snapshot(), source: "ended")

        XCTAssertEqual(controller.endCount, 1)
        XCTAssertNotNil(controller.lastEndSessionID)
        XCTAssertFalse(controller.isActive)

        let relaunchedEngine = SessionTimerEngine(now: { clock.now })
        coordinator.reconcile(snapshot: relaunchedEngine.snapshot(), source: "relaunch")

        XCTAssertEqual(controller.startCount, 1)
        XCTAssertGreaterThanOrEqual(controller.endCount, 1)
    }

    func testTerminalReconcileIsIdempotentAndLogsConsistencyEvents() throws {
        let clock = LiveActivityTestClock(start: Date(timeIntervalSince1970: 135_000))
        let engine = SessionTimerEngine(now: { clock.now })
        let controller = SpyLiveActivityController()
        let diagnostics = DiagnosticsSpy()
        let renderVersion = RenderVersionCounter()
        let coordinator = LiveActivityLifecycleCoordinator(
            controller: controller,
            now: { clock.now },
            nextRenderVersion: { renderVersion.next() },
            diagnostics: diagnostics
        )

        try engine.start(.left)
        coordinator.reconcile(snapshot: engine.snapshot(), source: "running")
        _ = try engine.endSession(note: nil)

        coordinator.reconcile(snapshot: engine.snapshot(), source: "ended-1")
        coordinator.reconcile(snapshot: engine.snapshot(), source: "ended-2")

        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(controller.startCount, 1)
        XCTAssertGreaterThanOrEqual(controller.endCount, 1)

        let events = diagnostics.events
        let startEvents = events.filter { $0.action == "start" }
        let endEvents = events.filter { $0.action == "end" }
        XCTAssertEqual(startEvents.count, 1)
        XCTAssertGreaterThanOrEqual(endEvents.count, 1)
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
        XCTAssertEqual(state.projectedActiveSideElapsed(at: later), 85, accuracy: 0.001)
    }

    func testProjectedDisplayKeepsActiveAndTotalTimersOnSharedCheckpoint() {
        let now = Date(timeIntervalSince1970: 140_500)
        let state = FeedTrackerLiveActivityContentState(
            state: LiveActivityState(
                snapshot: SessionTimerSnapshot(
                    state: .running(side: .right),
                    activeSide: .right,
                    leftElapsed: 24,
                    rightElapsed: 11,
                    totalElapsed: 35,
                    startedAt: now.addingTimeInterval(-35),
                    endedAt: nil
                )
            ),
            capturedAt: now
        )

        let later = now.addingTimeInterval(19)
        let projection = state.projectedDisplay(at: later)

        XCTAssertEqual(projection.activeSide, .right)
        XCTAssertEqual(projection.leftElapsed, 24, accuracy: 0.001)
        XCTAssertEqual(projection.rightElapsed, 30, accuracy: 0.001)
        XCTAssertEqual(projection.activeSideElapsed, 30, accuracy: 0.001)
        XCTAssertEqual(projection.totalElapsed, 54, accuracy: 0.001)
        XCTAssertEqual(projection.timerStatus, .running)
    }

    func testPausedSnapshotPreservesLastActiveSideForLiveActivityLayout() throws {
        let clock = LiveActivityTestClock(start: Date(timeIntervalSince1970: 141_000))
        let engine = SessionTimerEngine(now: { clock.now })

        try engine.start(.right)
        clock.advance(seconds: 18)
        try engine.pause()

        let snapshot = engine.snapshot(at: clock.now)
        XCTAssertEqual(snapshot.activeSide, .right)

        let state = FeedTrackerLiveActivityContentState(
            state: LiveActivityState(snapshot: snapshot),
            capturedAt: clock.now
        )

        XCTAssertEqual(state.activeSideRawValue, FeedingSide.right.rawValue)
        XCTAssertEqual(state.projectedActiveSideElapsed(at: clock.now.addingTimeInterval(45)), 18, accuracy: 0.001)
        XCTAssertEqual(state.projectedTotalElapsed(at: clock.now.addingTimeInterval(45)), 18, accuracy: 0.001)
    }

    func testPausedContentStateKeepsRoundedDisplayedSecondAfterPauseBoundary() {
        let capturedAt = Date(timeIntervalSince1970: 141_050.6)
        let snapshot = SessionTimerSnapshot(
            state: .paused(side: .left),
            activeSide: .left,
            leftElapsed: 12.6,
            rightElapsed: 4.2,
            totalElapsed: 16.8,
            startedAt: capturedAt.addingTimeInterval(-16.8),
            endedAt: nil
        )

        let state = FeedTrackerLiveActivityContentState(
            state: LiveActivityState(snapshot: snapshot),
            capturedAt: capturedAt
        )

        XCTAssertEqual(state.projectedElapsed(for: .left, at: capturedAt.addingTimeInterval(10)), 13, accuracy: 0.001)
        XCTAssertEqual(state.projectedElapsed(for: .right, at: capturedAt.addingTimeInterval(10)), 4, accuracy: 0.001)
        XCTAssertEqual(state.projectedTotalElapsed(at: capturedAt.addingTimeInterval(10)), 17, accuracy: 0.001)
    }

    func testRunningContentStatePreservesRawBaselineAndProjectsDisplayedSecondsFromAppState() {
        let capturedAt = Date(timeIntervalSince1970: 141_100.82)
        let snapshot = SessionTimerSnapshot(
            state: .running(side: .left),
            activeSide: .left,
            leftElapsed: 12.82,
            rightElapsed: 5.31,
            totalElapsed: 18.13,
            startedAt: capturedAt.addingTimeInterval(-18.13),
            endedAt: nil
        )

        let state = FeedTrackerLiveActivityContentState(
            state: LiveActivityState(snapshot: snapshot),
            capturedAt: capturedAt
        )

        XCTAssertEqual(state.capturedAt.timeIntervalSince1970, 141_100.82, accuracy: 0.001)
        XCTAssertEqual(state.leftElapsed, 13, accuracy: 0.001)
        XCTAssertEqual(state.rightElapsed, 5, accuracy: 0.001)
        XCTAssertEqual(state.totalElapsed, 18, accuracy: 0.001)
        XCTAssertEqual(state.anchorDate(for: .left)?.timeIntervalSince1970 ?? -1, 141_087.82, accuracy: 0.001)
        XCTAssertNil(state.anchorDate(for: .right))
        XCTAssertEqual(state.totalAnchorDate?.timeIntervalSince1970 ?? -1, 141_082.82, accuracy: 0.001)
        XCTAssertEqual(state.projectedActiveSideElapsed(at: Date(timeIntervalSince1970: 141_103)), 15, accuracy: 0.001)
        XCTAssertEqual(state.projectedTotalElapsed(at: Date(timeIntervalSince1970: 141_103)), 20, accuracy: 0.001)
    }

    func testContentStateDecodesLegacyPayloadWithoutRenderVersion() throws {
        let payload = """
        {
          \"activeSideRawValue\": \"left\",
          \"leftElapsed\": 55,
          \"rightElapsed\": 10,
          \"totalElapsed\": 65,
          \"timerStatusRawValue\": \"running\",
          \"capturedAt\": \"2026-03-21T01:00:00Z\"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(FeedTrackerLiveActivityContentState.self, from: payload)

        XCTAssertEqual(state.activeSideRawValue, "left")
        XCTAssertEqual(state.totalElapsed, 65, accuracy: 0.001)
        XCTAssertEqual(state.renderVersion, 0)
    }
}

@MainActor
private final class SpyLiveActivityController: LiveActivityControlling {
    private(set) var isActive = false
    private(set) var startCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var lastState: FeedTrackerLiveActivityAttributes.ContentState?
    private(set) var lastStartSessionID: UUID?
    private(set) var lastUpdateSessionID: UUID?
    private(set) var lastEndSessionID: UUID?
    private(set) var lastObservedSessionID: UUID?

    func isActive(sessionID: UUID) -> Bool {
        lastObservedSessionID = sessionID
        return isActive && lastStartSessionID == sessionID
    }

    func start(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState) {
        isActive = true
        startCount += 1
        lastStartSessionID = sessionID
        lastObservedSessionID = sessionID
        lastState = state
    }

    func update(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState) {
        guard isActive else {
            return
        }
        updateCount += 1
        lastUpdateSessionID = sessionID
        lastObservedSessionID = sessionID
        lastState = state
    }

    func end(sessionID: UUID?, state: FeedTrackerLiveActivityAttributes.ContentState?) {
        isActive = false
        endCount += 1
        lastEndSessionID = sessionID
        if let sessionID {
            lastObservedSessionID = sessionID
        }
        if let state {
            lastState = state
        }
    }
}

private struct DiagnosticsRecord {
    let category: String
    let action: String
}

private final class RenderVersionCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0

    func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        value &+= 1
        return value
    }
}

private final class DiagnosticsSpy: @unchecked Sendable, DiagnosticsLogging {
    private let lock = NSLock()
    private var storage: [DiagnosticsRecord] = []

    var events: [DiagnosticsRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(category: String, action: String, metadata _: [String: String], source _: String) {
        lock.lock()
        storage.append(DiagnosticsRecord(category: category, action: action))
        lock.unlock()
    }

    func recordError(context: String, message _: String, metadata _: [String: String], source _: String) {
        lock.lock()
        storage.append(DiagnosticsRecord(category: "error", action: context))
        lock.unlock()
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
