import Foundation

public extension SessionTimerClockState {
    func liveActivityContentState(
        at date: Date,
        renderVersion: UInt64
    ) -> FeedTrackerLiveActivityAttributes.ContentState {
        FeedTrackerLiveActivityAttributes.ContentState(
            state: LiveActivityState(snapshot: snapshot(at: date)),
            capturedAt: date,
            renderVersion: renderVersion
        )
    }
}
