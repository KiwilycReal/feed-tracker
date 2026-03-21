#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

@available(iOS 17.0, *)
@MainActor
public final class ActivityKitLiveActivityController: LiveActivityControlling {
    private var activityID: String?

    public init() {}

    public var isActive: Bool {
        resolveActivity() != nil
    }

    public func start(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState) {
        if let activity = resolveActivity() {
            enqueueUpdate(activity: activity, state: state)
            return
        }

        let attributes = FeedTrackerLiveActivityAttributes(sessionID: sessionID)
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            guard shouldApplyRenderVersion(state.renderVersion) else {
                return
            }

            do {
                let activity = try Activity<FeedTrackerLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                guard shouldApplyRenderVersion(state.renderVersion) else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    return
                }
                activityID = activity.id
            } catch {
                // best-effort lifecycle continuity; ignore request failure to avoid breaking primary flow
            }
        }
    }

    public func update(state: FeedTrackerLiveActivityAttributes.ContentState) {
        guard let activity = resolveActivity() else {
            return
        }

        enqueueUpdate(activity: activity, state: state)
    }

    public func end(state: FeedTrackerLiveActivityAttributes.ContentState?) {
        let renderVersion = state?.renderVersion ?? FeedTrackerSharedStorage.nextLiveActivityRenderVersion()
        guard let activity = resolveActivity() else {
            activityID = nil
            return
        }

        let content = state.map { ActivityContent(state: $0, staleDate: nil) }
        Task {
            guard shouldApplyRenderVersion(renderVersion) else {
                return
            }

            await activity.end(content, dismissalPolicy: .immediate)
            guard shouldApplyRenderVersion(renderVersion) else {
                return
            }
            activityID = nil
        }
    }

    private func enqueueUpdate(
        activity: Activity<FeedTrackerLiveActivityAttributes>,
        state: FeedTrackerLiveActivityAttributes.ContentState
    ) {
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            guard shouldApplyRenderVersion(state.renderVersion) else {
                return
            }

            await activity.update(content)
        }
    }

    private func shouldApplyRenderVersion(_ renderVersion: UInt64) -> Bool {
        renderVersion == FeedTrackerSharedStorage.currentLiveActivityRenderVersion()
    }

    private func resolveActivity() -> Activity<FeedTrackerLiveActivityAttributes>? {
        if let activityID,
           let activity = Activity<FeedTrackerLiveActivityAttributes>.activities.first(where: { $0.id == activityID }) {
            return activity
        }

        if let existing = Activity<FeedTrackerLiveActivityAttributes>.activities.first {
            activityID = existing.id
            return existing
        }

        return nil
    }
}
#endif
