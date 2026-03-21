#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

@available(iOS 17.0, *)
@MainActor
public final class ActivityKitLiveActivityController: LiveActivityControlling {
    private var activityID: String?
    private var sessionID: String?

    public init() {}

    public func isActive(sessionID: UUID) -> Bool {
        resolveActivity(for: sessionID.uuidString) != nil
    }

    public func start(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState) {
        let requestedSessionID = sessionID.uuidString
        self.sessionID = requestedSessionID

        if let activity = resolveActivity(for: requestedSessionID) {
            enqueueUpdate(activity: activity, state: state)
            return
        }

        let attributes = FeedTrackerLiveActivityAttributes(sessionID: sessionID)
        let content = ActivityContent(state: state, staleDate: nil)

        Task { [requestedSessionID] in
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
                await MainActor.run {
                    storeResolvedActivity(activity, sessionID: requestedSessionID)
                }
            } catch {
                // best-effort lifecycle continuity; ignore request failure to avoid breaking primary flow
            }
        }
    }

    public func update(sessionID: UUID, state: FeedTrackerLiveActivityAttributes.ContentState) {
        let requestedSessionID = sessionID.uuidString
        self.sessionID = requestedSessionID

        guard let activity = resolveActivity(for: requestedSessionID) else {
            return
        }

        enqueueUpdate(activity: activity, state: state)
    }

    public func end(sessionID: UUID?, state: FeedTrackerLiveActivityAttributes.ContentState?) {
        let requestedSessionID = sessionID?.uuidString
            ?? self.sessionID
            ?? FeedTrackerSharedStorage.readLiveActivityDisplayTarget()?.sessionID
        let renderVersion = state?.renderVersion ?? FeedTrackerSharedStorage.nextLiveActivityRenderVersion()

        guard let activity = resolveActivity(for: requestedSessionID) else {
            clearResolvedActivity(sessionID: requestedSessionID)
            return
        }

        let content = state.map { ActivityContent(state: $0, staleDate: nil) }
        Task { [requestedSessionID] in
            guard shouldApplyRenderVersion(renderVersion) else {
                return
            }

            await activity.end(content, dismissalPolicy: .immediate)
            guard shouldApplyRenderVersion(renderVersion) else {
                return
            }
            await MainActor.run {
                clearResolvedActivity(sessionID: requestedSessionID)
            }
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

    private func resolveActivity(for requestedSessionID: String?) -> Activity<FeedTrackerLiveActivityAttributes>? {
        let activities = Activity<FeedTrackerLiveActivityAttributes>.activities
        guard let requestedSessionID else {
            return nil
        }

        if let storedTarget = FeedTrackerSharedStorage.readLiveActivityDisplayTarget(),
           storedTarget.sessionID == requestedSessionID,
           let activity = activities.first(where: {
               $0.id == storedTarget.activityID && $0.attributes.sessionID == requestedSessionID
           }) {
            storeResolvedActivity(activity, sessionID: requestedSessionID)
            return activity
        }

        if let activityID,
           let activity = activities.first(where: {
               $0.id == activityID && $0.attributes.sessionID == requestedSessionID
           }) {
            storeResolvedActivity(activity, sessionID: requestedSessionID)
            return activity
        }

        if let activity = activities.first(where: { $0.attributes.sessionID == requestedSessionID }) {
            storeResolvedActivity(activity, sessionID: requestedSessionID)
            return activity
        }

        if FeedTrackerSharedStorage.readLiveActivityDisplayTarget()?.sessionID == requestedSessionID {
            FeedTrackerSharedStorage.clearLiveActivityDisplayTarget()
        }

        if self.sessionID == requestedSessionID {
            activityID = nil
        }

        return nil
    }

    private func storeResolvedActivity(
        _ activity: Activity<FeedTrackerLiveActivityAttributes>,
        sessionID: String
    ) {
        activityID = activity.id
        self.sessionID = sessionID
        FeedTrackerSharedStorage.writeLiveActivityDisplayTarget(
            activityID: activity.id,
            sessionID: sessionID
        )
    }

    private func clearResolvedActivity(sessionID expectedSessionID: String?) {
        if let expectedSessionID,
           FeedTrackerSharedStorage.readLiveActivityDisplayTarget()?.sessionID == expectedSessionID {
            FeedTrackerSharedStorage.clearLiveActivityDisplayTarget()
        }

        if expectedSessionID == nil || self.sessionID == expectedSessionID {
            self.sessionID = nil
        }
        activityID = nil
    }
}
#endif
