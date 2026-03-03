import Foundation

public protocol LiveActivityLifecycleCoordinating: AnyObject, Sendable {
    @MainActor
    func reconcile(snapshot: SessionTimerSnapshot, source: String)
}

public protocol LiveActivityControlling: AnyObject, Sendable {
    @MainActor var isActive: Bool { get }
    @MainActor func start(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState)
    @MainActor func update(state: FeedTrackerLiveActivityAttributes.ContentState)
    @MainActor func end()
}

public final class NoopLiveActivityController: LiveActivityControlling {
    @MainActor
    public var isActive: Bool { false }

    public init() {}

    @MainActor
    public func start(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState) {}

    @MainActor
    public func update(state: FeedTrackerLiveActivityAttributes.ContentState) {}

    @MainActor
    public func end() {}
}

@MainActor
public final class LiveActivityLifecycleCoordinator: LiveActivityLifecycleCoordinating {
    private let controller: any LiveActivityControlling
    private let now: @Sendable () -> Date
    private let diagnostics: (any DiagnosticsLogging)?

    private var activeSessionID: UUID?

    public init(
        controller: any LiveActivityControlling,
        now: @escaping @Sendable () -> Date = { Date() },
        diagnostics: (any DiagnosticsLogging)? = nil
    ) {
        self.controller = controller
        self.now = now
        self.diagnostics = diagnostics
    }

    public func reconcile(snapshot: SessionTimerSnapshot, source: String) {
        switch snapshot.state {
        case .idle, .ended:
            controller.end()
            activeSessionID = nil
            diagnostics?.record(
                category: "live_activity_lifecycle",
                action: "end",
                metadata: ["source": source],
                source: "live_activity_coordinator"
            )

        case .running, .paused, .stopped:
            let state = LiveActivityState(snapshot: snapshot)
            let contentState = FeedTrackerLiveActivityAttributes.ContentState(
                state: state,
                capturedAt: now()
            )

            if controller.isActive {
                controller.update(state: contentState)
                diagnostics?.record(
                    category: "live_activity_lifecycle",
                    action: "update",
                    metadata: [
                        "source": source,
                        "timerStatus": contentState.timerStatusRawValue
                    ],
                    source: "live_activity_coordinator"
                )
            } else {
                let sessionID = stableSessionIdentifier(startedAt: snapshot.startedAt)
                activeSessionID = sessionID
                controller.start(sessionID: sessionID, state: contentState)
                diagnostics?.record(
                    category: "live_activity_lifecycle",
                    action: "start",
                    metadata: [
                        "source": source,
                        "sessionID": sessionID.uuidString,
                        "timerStatus": contentState.timerStatusRawValue
                    ],
                    source: "live_activity_coordinator"
                )
            }
        }
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
