import Foundation

public protocol LiveActivityLifecycleCoordinating: AnyObject, Sendable {
    @MainActor
    func reconcile(snapshot: SessionTimerSnapshot, source: String)
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

    public func reconcile(snapshot: SessionTimerSnapshot, source: String) {
        switch snapshot.state {
        case .idle, .ended:
            controller.end(sessionID: activeSessionID ?? snapshot.sessionID, state: contentState(for: snapshot))
            activeSessionID = nil
            diagnostics?.record(
                category: "live_activity_lifecycle",
                action: "end",
                metadata: ["source": source],
                source: "live_activity_coordinator"
            )

        case .running, .paused, .stopped:
            let sessionID = liveActivitySessionIdentifier(for: snapshot)
            let contentState = contentState(for: snapshot)
            activeSessionID = sessionID

            if controller.isActive(sessionID: sessionID) {
                controller.update(sessionID: sessionID, state: contentState)
                diagnostics?.record(
                    category: "live_activity_lifecycle",
                    action: "update",
                    metadata: [
                        "source": source,
                        "sessionID": sessionID.uuidString,
                        "timerStatus": contentState.timerStatusRawValue,
                        "renderVersion": "\(contentState.renderVersion)"
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
                        "renderVersion": "\(contentState.renderVersion)"
                    ],
                    source: "live_activity_coordinator"
                )
            }
        }
    }

    private func contentState(for snapshot: SessionTimerSnapshot) -> FeedTrackerLiveActivityAttributes.ContentState {
        FeedTrackerLiveActivityAttributes.ContentState(
            state: LiveActivityState(snapshot: snapshot),
            capturedAt: now(),
            renderVersion: nextRenderVersion()
        )
    }

    private func liveActivitySessionIdentifier(for snapshot: SessionTimerSnapshot) -> UUID {
        if let sessionID = snapshot.sessionID {
            return sessionID
        }

        return stableSessionIdentifier(startedAt: snapshot.startedAt)
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
