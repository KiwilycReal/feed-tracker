import ActivityKit
import FeedTrackerCore
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 17.0, *)
@main
struct FeedTrackerLiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        FeedTrackerLiveActivityWidget()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct FeedTrackerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedTrackerLiveActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    actionLink(
                        title: "Switch",
                        systemImage: "arrow.triangle.2.circlepath",
                        urlString: context.attributes.switchSideActionURL
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    actionLink(
                        title: "Pause",
                        systemImage: "pause.fill",
                        urlString: context.attributes.pauseSessionActionURL
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        elapsedView(for: context.state)
                            .font(.title3.monospacedDigit())

                        Spacer()

                        actionLink(
                            title: "End",
                            systemImage: "stop.fill",
                            urlString: context.attributes.terminateSessionActionURL,
                            tint: .red
                        )
                    }
                }
            } compactLeading: {
                Text(sideLabel(for: context.state.activeSideRawValue))
                    .font(.caption.bold())
            } compactTrailing: {
                elapsedView(for: context.state)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                elapsedView(for: context.state)
                    .font(.caption2.monospacedDigit())
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FeedTrackerLiveActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Feed Session")
                    .font(.headline)
                Spacer()
                Text(statusLabel(for: context.state.timerStatusRawValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            elapsedView(for: context.state)
                .font(.title2.monospacedDigit())

            HStack(spacing: 12) {
                actionLink(
                    title: "Switch",
                    systemImage: "arrow.triangle.2.circlepath",
                    urlString: context.attributes.switchSideActionURL
                )
                actionLink(
                    title: "Pause",
                    systemImage: "pause.fill",
                    urlString: context.attributes.pauseSessionActionURL
                )
                actionLink(
                    title: "End",
                    systemImage: "stop.fill",
                    urlString: context.attributes.terminateSessionActionURL,
                    tint: .red
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func sideLabel(for raw: String?) -> String {
        guard let raw else { return "•" }
        return raw == "left" ? "L" : "R"
    }

    private func statusLabel(for raw: String) -> String {
        switch raw {
        case LiveActivityTimerStatus.running.rawValue:
            return "Running"
        case LiveActivityTimerStatus.paused.rawValue:
            return "Paused"
        case LiveActivityTimerStatus.stopped.rawValue:
            return "Stopped"
        case LiveActivityTimerStatus.ended.rawValue:
            return "Ended"
        default:
            return "Idle"
        }
    }

    @ViewBuilder
    private func elapsedView(for state: FeedTrackerLiveActivityContentState) -> some View {
        let startDate = state.capturedAt.addingTimeInterval(-state.totalElapsed)

        if state.timerStatusRawValue == LiveActivityTimerStatus.running.rawValue {
            Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
        } else {
            Text(Self.formattedDuration(state.totalElapsed))
        }
    }

    @ViewBuilder
    private func actionLink(
        title: String,
        systemImage: String,
        urlString: String,
        tint: Color = .accentColor
    ) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.14), in: Capsule())
            }
            .tint(tint)
        }
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}
