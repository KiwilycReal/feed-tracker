import Foundation

public struct FeedTrackerLiveActivityContentState: Codable, Hashable, Sendable {
    public var activeSideRawValue: String?
    public var leftElapsed: TimeInterval
    public var rightElapsed: TimeInterval
    public var totalElapsed: TimeInterval
    public var timerStatusRawValue: String
    public var capturedAt: Date

    public init(state: LiveActivityState, capturedAt: Date = Date()) {
        self.activeSideRawValue = state.activeSide?.rawValue
        self.leftElapsed = state.leftElapsed
        self.rightElapsed = state.rightElapsed
        self.totalElapsed = state.totalElapsed
        self.timerStatusRawValue = state.timerStatus.rawValue
        self.capturedAt = capturedAt
    }

    public func projectedTotalElapsed(at now: Date) -> TimeInterval {
        guard timerStatusRawValue == LiveActivityTimerStatus.running.rawValue else {
            return totalElapsed
        }

        let delta = max(0, now.timeIntervalSince(capturedAt))
        return totalElapsed + delta
    }
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

@available(iOS 17.0, *)
public struct FeedTrackerLiveActivityAttributes: ActivityAttributes {
    public typealias ContentState = FeedTrackerLiveActivityContentState

    public let sessionID: String
    public let startLeftActionURL: String
    public let startRightActionURL: String
    public let endSessionActionURL: String

    public init(
        sessionID: UUID,
        actionRouter: any LiveActivityQuickActionRouting = LiveActivityQuickActionRouter()
    ) {
        self.sessionID = sessionID.uuidString
        self.startLeftActionURL = actionRouter.url(for: .startLeft).absoluteString
        self.startRightActionURL = actionRouter.url(for: .startRight).absoluteString
        self.endSessionActionURL = actionRouter.url(for: .endSession).absoluteString
    }
}
#else
public struct FeedTrackerLiveActivityAttributes: Sendable {
    public typealias ContentState = FeedTrackerLiveActivityContentState

    public let sessionID: String
    public let startLeftActionURL: String
    public let startRightActionURL: String
    public let endSessionActionURL: String

    public init(
        sessionID: UUID,
        actionRouter: any LiveActivityQuickActionRouting = LiveActivityQuickActionRouter()
    ) {
        self.sessionID = sessionID.uuidString
        self.startLeftActionURL = actionRouter.url(for: .startLeft).absoluteString
        self.startRightActionURL = actionRouter.url(for: .startRight).absoluteString
        self.endSessionActionURL = actionRouter.url(for: .endSession).absoluteString
    }
}
#endif
