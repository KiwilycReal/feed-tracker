import Foundation

public struct FeedTrackerLiveActivityDisplayProjection: Equatable, Sendable {
    public let activeSide: FeedingSide?
    public let activeSideElapsed: TimeInterval
    public let leftElapsed: TimeInterval
    public let rightElapsed: TimeInterval
    public let totalElapsed: TimeInterval
    public let timerStatus: LiveActivityTimerStatus

    public init(
        activeSide: FeedingSide?,
        activeSideElapsed: TimeInterval,
        leftElapsed: TimeInterval,
        rightElapsed: TimeInterval,
        totalElapsed: TimeInterval,
        timerStatus: LiveActivityTimerStatus
    ) {
        self.activeSide = activeSide
        self.activeSideElapsed = activeSideElapsed
        self.leftElapsed = leftElapsed
        self.rightElapsed = rightElapsed
        self.totalElapsed = totalElapsed
        self.timerStatus = timerStatus
    }
}

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
        self.leftElapsed = max(0, state.leftElapsed)
        self.rightElapsed = max(0, state.rightElapsed)
        self.totalElapsed = max(0, state.totalElapsed)
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
        projectedDisplayValues(at: now).totalElapsed
    }

    public func projectedElapsed(for side: FeedingSide, at now: Date) -> TimeInterval {
        let projection = projectedDisplayValues(at: now)
        switch side {
        case .left:
            return projection.leftElapsed
        case .right:
            return projection.rightElapsed
        }
    }

    public func projectedActiveSideElapsed(at now: Date) -> TimeInterval {
        projectedDisplayValues(at: now).activeSideElapsed
    }

    public func projectedDisplay(at now: Date) -> FeedTrackerLiveActivityDisplayProjection {
        let projection = projectedDisplayValues(at: now)

        return FeedTrackerLiveActivityDisplayProjection(
            activeSide: projection.activeSide,
            activeSideElapsed: projection.activeSideElapsed,
            leftElapsed: projection.leftElapsed,
            rightElapsed: projection.rightElapsed,
            totalElapsed: projection.totalElapsed,
            timerStatus: LiveActivityTimerStatus(rawValue: timerStatusRawValue) ?? .idle
        )
    }

    private func projectedDisplayValues(at now: Date) -> SessionTimerDisplayValues {
        SessionTimerDisplayProjection.values(
            state: LiveActivityState(
                activeSide: FeedingSide(rawValue: activeSideRawValue ?? ""),
                leftElapsed: leftElapsed,
                rightElapsed: rightElapsed,
                totalElapsed: totalElapsed,
                startedAt: nil,
                endedAt: nil,
                timerStatus: LiveActivityTimerStatus(rawValue: timerStatusRawValue) ?? .idle
            ),
            capturedAt: capturedAt,
            now: now
        )
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
