import Foundation

public struct FeedTrackerLiveActivityContentState: Codable, Hashable, Sendable {
    public var activeSideRawValue: String?
    public var leftElapsed: TimeInterval
    public var rightElapsed: TimeInterval
    public var totalElapsed: TimeInterval
    public var timerStatusRawValue: String
    public var capturedAt: Date
    public var renderVersion: UInt64

    private enum CodingKeys: String, CodingKey {
        case activeSideRawValue
        case leftElapsed
        case rightElapsed
        case totalElapsed
        case timerStatusRawValue
        case capturedAt
        case renderVersion
    }

    public init(
        state: LiveActivityState,
        capturedAt: Date = Date(),
        renderVersion: UInt64 = 0
    ) {
        self.activeSideRawValue = state.activeSide?.rawValue
        self.leftElapsed = state.leftElapsed
        self.rightElapsed = state.rightElapsed
        self.totalElapsed = state.totalElapsed
        self.timerStatusRawValue = state.timerStatus.rawValue
        self.capturedAt = capturedAt
        self.renderVersion = renderVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.activeSideRawValue = try container.decodeIfPresent(String.self, forKey: .activeSideRawValue)
        self.leftElapsed = try container.decode(TimeInterval.self, forKey: .leftElapsed)
        self.rightElapsed = try container.decode(TimeInterval.self, forKey: .rightElapsed)
        self.totalElapsed = try container.decode(TimeInterval.self, forKey: .totalElapsed)
        self.timerStatusRawValue = try container.decode(String.self, forKey: .timerStatusRawValue)
        self.capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        self.renderVersion = try container.decodeIfPresent(UInt64.self, forKey: .renderVersion) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(activeSideRawValue, forKey: .activeSideRawValue)
        try container.encode(leftElapsed, forKey: .leftElapsed)
        try container.encode(rightElapsed, forKey: .rightElapsed)
        try container.encode(totalElapsed, forKey: .totalElapsed)
        try container.encode(timerStatusRawValue, forKey: .timerStatusRawValue)
        try container.encode(capturedAt, forKey: .capturedAt)
        try container.encode(renderVersion, forKey: .renderVersion)
    }

    public func projectedTotalElapsed(at now: Date) -> TimeInterval {
        guard timerStatusRawValue == LiveActivityTimerStatus.running.rawValue else {
            return totalElapsed
        }

        let delta = max(0, now.timeIntervalSince(capturedAt))
        return totalElapsed + delta
    }

    public func projectedElapsed(for side: FeedingSide, at now: Date) -> TimeInterval {
        let baseline: TimeInterval
        switch side {
        case .left:
            baseline = leftElapsed
        case .right:
            baseline = rightElapsed
        }

        guard timerStatusRawValue == LiveActivityTimerStatus.running.rawValue,
              activeSideRawValue == side.rawValue else {
            return baseline
        }

        let delta = max(0, now.timeIntervalSince(capturedAt))
        return baseline + delta
    }

    public func projectedActiveSideElapsed(at now: Date) -> TimeInterval {
        guard let activeSide = FeedingSide(rawValue: activeSideRawValue ?? "") else {
            return 0
        }

        return projectedElapsed(for: activeSide, at: now)
    }
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

@available(iOS 17.0, *)
public struct FeedTrackerLiveActivityAttributes: ActivityAttributes {
    public typealias ContentState = FeedTrackerLiveActivityContentState

    public let sessionID: String

    // MVP-02 parity action URLs (expanded island + lock screen)
    public let switchSideActionURL: String
    public let pauseSessionActionURL: String
    public let terminateSessionActionURL: String

    // Backward-compatible URLs
    public let startLeftActionURL: String
    public let startRightActionURL: String
    public let endSessionActionURL: String

    public init(
        sessionID: UUID,
        actionRouter: any LiveActivityQuickActionRouting = LiveActivityQuickActionRouter()
    ) {
        self.sessionID = sessionID.uuidString
        self.switchSideActionURL = actionRouter.url(for: .switchSide).absoluteString
        self.pauseSessionActionURL = actionRouter.url(for: .pauseSession).absoluteString
        self.terminateSessionActionURL = actionRouter.url(for: .terminateSession).absoluteString

        self.startLeftActionURL = actionRouter.url(for: .startLeft).absoluteString
        self.startRightActionURL = actionRouter.url(for: .startRight).absoluteString
        self.endSessionActionURL = actionRouter.url(for: .endSession).absoluteString
    }
}
#else
public struct FeedTrackerLiveActivityAttributes: Sendable {
    public typealias ContentState = FeedTrackerLiveActivityContentState

    public let sessionID: String

    public let switchSideActionURL: String
    public let pauseSessionActionURL: String
    public let terminateSessionActionURL: String

    public let startLeftActionURL: String
    public let startRightActionURL: String
    public let endSessionActionURL: String

    public init(
        sessionID: UUID,
        actionRouter: any LiveActivityQuickActionRouting = LiveActivityQuickActionRouter()
    ) {
        self.sessionID = sessionID.uuidString
        self.switchSideActionURL = actionRouter.url(for: .switchSide).absoluteString
        self.pauseSessionActionURL = actionRouter.url(for: .pauseSession).absoluteString
        self.terminateSessionActionURL = actionRouter.url(for: .terminateSession).absoluteString

        self.startLeftActionURL = actionRouter.url(for: .startLeft).absoluteString
        self.startRightActionURL = actionRouter.url(for: .startRight).absoluteString
        self.endSessionActionURL = actionRouter.url(for: .endSession).absoluteString
    }
}
#endif
