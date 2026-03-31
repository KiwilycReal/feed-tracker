import Foundation

public protocol LiveActivityLifecycleCoordinating: AnyObject, Sendable {
    @MainActor
    func reconcile(clockState: SessionTimerClockState, source: String)
}

public protocol LiveActivityControlling: AnyObject, Sendable {
    @MainActor func isActive(sessionID: UUID) -> Bool
    @MainActor func start(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState)
    @MainActor func update(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState)
    @MainActor func end(sessionID: UUID?, state: FeedTrackerLiveActivityAttributes.ContentState?)
}

public final class NoopLiveActivityController: LiveActivityControlling {
    public init() {}

    @MainActor
    public func isActive(sessionID _: UUID) -> Bool { false }

    @MainActor
    public func start(sessionID _: UUID, state _: FeedTrackerLiveActivityAttributes.ContentState) {}

    @MainActor
    public func update(sessionID _: UUID, state _: FeedTrackerLiveActivityAttributes.ContentState) {}

    @MainActor
    public func end(sessionID _: UUID?, state _: FeedTrackerLiveActivityAttributes.ContentState?) {}
}

@MainActor
public final class LiveActivityLifecycleCoordinator: LiveActivityLifecycleCoordinating {
    private let controller: any LiveActivityControlling
    private let now: @Sendable () -> Date
    private let nextRenderVersion: @Sendable () -> UInt64
    private let diagnostics: (any DiagnosticsLogging)?

    private var activeSessionID: UUID?
    private var lastReconciledSyncToken: String?

    public init(
        controller: any LiveActivityControlling,
        now: @escaping @Sendable () -> Date = { Date() },
        nextRenderVersion: @escaping @Sendable () -> UInt64 = { FeedTrackerSharedStorage.nextLiveActivityRenderVersion() },
        diagnostics: (any DiagnosticsLogging)? = nil
    ) {
        self.controller = controller
        self.now = now
        self.nextRenderVersion = nextRenderVersion
        self.diagnostics = diagnostics
    }

    public func reconcile(clockState: SessionTimerClockState, source: String) {
        let snapshot = clockState.snapshot(at: now())
        let sessionID = liveActivitySessionIdentifier(for: clockState)
        let isRedundantRunningReconcile = clockState.status != .idle
            && clockState.status != .ended
            && lastReconciledSyncToken == clockState.liveActivitySyncToken
            && controller.isActive(sessionID: sessionID)

        if isRedundantRunningReconcile {
            diagnostics?.record(
                category: "live_activity_lifecycle",
                action: "skip_redundant_reconcile",
                metadata: [
                    "source": source,
                    "sessionID": sessionID.uuidString,
                    "status": clockState.status.rawValue
                ],
                source: "live_activity_coordinator"
            )
            return
        }

        switch clockState.status {
        case .idle, .ended:
            controller.end(sessionID: activeSessionID ?? snapshot.sessionID, state: contentState(for: snapshot))
            activeSessionID = nil
            lastReconciledSyncToken = clockState.liveActivitySyncToken
            diagnostics?.record(
                category: "live_activity_lifecycle",
                action: "end",
                metadata: ["source": source],
                source: "live_activity_coordinator"
            )

        case .runningLeft, .runningRight, .pausedLeft, .pausedRight, .stopped:
            let contentState = contentState(for: clockState, capturedAt: snapshot.capturedAt)
            activeSessionID = sessionID
            lastReconciledSyncToken = clockState.liveActivitySyncToken

            if controller.isActive(sessionID: sessionID) {
                controller.update(sessionID: sessionID, state: contentState)
                diagnostics?.record(
                    category: "live_activity_lifecycle",
                    action: "update",
                    metadata: [
                        "source": source,
                        "sessionID": sessionID.uuidString,
                        "timerStatus": contentState.timerStatusRawValue,
                        "renderVersion": "\(contentState.renderVersion)",
                        "capturedAt": contentState.capturedAt.ISO8601Format(),
                        "displayedLeftElapsed": "\(Int(contentState.leftElapsed))",
                        "displayedRightElapsed": "\(Int(contentState.rightElapsed))",
                        "displayedTotalElapsed": "\(Int(contentState.totalElapsed))"
                    ],
                    source: "live_activity_coordinator"
                )
            } else {
                controller.start(sessionID: sessionID, state: contentState)
                diagnostics?.record(
                    category: "live_activity_lifecycle",
                    action: "start",
                    metadata: [
                        "source": source,
                        "sessionID": sessionID.uuidString,
                        "timerStatus": contentState.timerStatusRawValue,
                        "renderVersion": "\(contentState.renderVersion)",
                        "capturedAt": contentState.capturedAt.ISO8601Format(),
                        "displayedLeftElapsed": "\(Int(contentState.leftElapsed))",
                        "displayedRightElapsed": "\(Int(contentState.rightElapsed))",
                        "displayedTotalElapsed": "\(Int(contentState.totalElapsed))"
                    ],
                    source: "live_activity_coordinator"
                )
            }
        }
    }

    private func contentState(
        for clockState: SessionTimerClockState,
        capturedAt: Date
    ) -> FeedTrackerLiveActivityAttributes.ContentState {
        clockState.liveActivityContentState(
            at: capturedAt,
            renderVersion: nextRenderVersion()
        )
    }

    private func contentState(for snapshot: SessionTimerSnapshot) -> FeedTrackerLiveActivityAttributes.ContentState {
        FeedTrackerLiveActivityAttributes.ContentState(
            state: LiveActivityState(snapshot: snapshot),
            capturedAt: snapshot.capturedAt,
            renderVersion: nextRenderVersion()
        )
    }

    private func liveActivitySessionIdentifier(for clockState: SessionTimerClockState) -> UUID {
        if let sessionID = clockState.sessionID {
            return sessionID
        }

        return stableSessionIdentifier(startedAt: clockState.startedAt)
    }

    private func stableSessionIdentifier(startedAt: Date?) -> UUID {
        if let activeSessionID {
            return activeSessionID
        }

        guard let startedAt else {
            return UUID()
        }

        let raw = Int64(startedAt.timeIntervalSince1970 * 1_000)
        let upper = UInt64(bitPattern: raw)
        let lower = upper ^ 0xA5A5_A5A5_A5A5_A5A5

        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8((upper >> UInt64((7 - index) * 8)) & 0xFF)
            bytes[index + 8] = UInt8((lower >> UInt64((7 - index) * 8)) & 0xFF)
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
