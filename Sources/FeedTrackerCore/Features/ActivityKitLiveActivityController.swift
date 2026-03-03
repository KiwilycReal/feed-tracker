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
            let content = ActivityContent(state: state, staleDate: nil)
            Task {
                await activity.update(content)
            }
            return
        }

        let attributes = FeedTrackerLiveActivityAttributes(sessionID: sessionID)
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            do {
                let activity = try Activity<FeedTrackerLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
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

        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    public func end() {
        guard let activity = resolveActivity() else {
            return
        }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activityID = nil
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
