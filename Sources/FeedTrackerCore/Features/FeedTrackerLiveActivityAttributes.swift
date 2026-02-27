#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

@available(iOS 17.0, *)
public struct FeedTrackerLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var activeSideRawValue: String?
        public var leftElapsed: TimeInterval
        public var rightElapsed: TimeInterval
        public var totalElapsed: TimeInterval
        public var timerStatusRawValue: String

        public init(state: LiveActivityState) {
            self.activeSideRawValue = state.activeSide?.rawValue
            self.leftElapsed = state.leftElapsed
            self.rightElapsed = state.rightElapsed
            self.totalElapsed = state.totalElapsed
            self.timerStatusRawValue = state.timerStatus.rawValue
        }
    }

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
