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
                .widgetURL(appOpenURL(sessionID: context.attributes.sessionID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sideLabel(for: context.state.activeSideRawValue))
                            .font(.title3.weight(.semibold))
                        Label(statusLabel(for: context.state.timerStatusRawValue),
                              systemImage: statusIcon(for: context.state.timerStatusRawValue))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    elapsedView(for: context.state)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.vertical, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        intentActionButton(
                            title: "Switch",
                            systemImage: "arrow.triangle.2.circlepath",
                            tint: .accentColor,
                            action: .switchSide,
                            sessionID: context.attributes.sessionID
                        )

                        let pauseControl = pauseControlMetadata(for: context.state.timerStatusRawValue)
                        intentActionButton(
                            title: pauseControl.title,
                            systemImage: pauseControl.systemImage,
                            tint: Color.white.opacity(0.78),
                            action: .togglePause,
                            sessionID: context.attributes.sessionID
                        )

                        intentActionButton(
                            title: "End",
                            systemImage: "stop.fill",
                            tint: .red,
                            action: .terminate,
                            sessionID: context.attributes.sessionID
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)
                }
            } compactLeading: {
                Text(sideLabel(for: context.state.activeSideRawValue))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.leading, 4)
                    .padding(.trailing, 2)
            } compactTrailing: {
                HStack(spacing: 3) {
                    compactElapsedView(for: context.state)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Image(systemName: statusIcon(for: context.state.timerStatusRawValue))
                        .font(.caption2.weight(.bold))
                }
                .padding(.leading, 2)
                .padding(.trailing, 4)
            } minimal: {
                Image(systemName: statusIcon(for: context.state.timerStatusRawValue))
                    .font(.caption2.weight(.bold))
            }
            .widgetURL(appOpenURL(sessionID: context.attributes.sessionID))
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FeedTrackerLiveActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Feed Session")
                    .font(.headline)
                Spacer()
                Label(statusLabel(for: context.state.timerStatusRawValue),
                      systemImage: statusIcon(for: context.state.timerStatusRawValue))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            elapsedView(for: context.state)
                .font(.system(.title2, design: .rounded).monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 12) {
                intentActionButton(
                    title: "Switch",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .accentColor,
                    action: .switchSide,
                    sessionID: context.attributes.sessionID
                )

                let pauseControl = pauseControlMetadata(for: context.state.timerStatusRawValue)
                intentActionButton(
                    title: pauseControl.title,
                    systemImage: pauseControl.systemImage,
                    tint: Color.white.opacity(0.78),
                    action: .togglePause,
                    sessionID: context.attributes.sessionID
                )

                intentActionButton(
                    title: "End",
                    systemImage: "stop.fill",
                    tint: .red,
                    action: .terminate,
                    sessionID: context.attributes.sessionID
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func sideLabel(for raw: String?) -> String {
        switch raw {
        case "left":
            return "左"
        case "right":
            return "右"
        default:
            return "--"
        }
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

    private func statusIcon(for raw: String) -> String {
        switch raw {
        case LiveActivityTimerStatus.running.rawValue:
            return "play.fill"
        case LiveActivityTimerStatus.paused.rawValue:
            return "pause.fill"
        case LiveActivityTimerStatus.stopped.rawValue:
            return "stop.fill"
        case LiveActivityTimerStatus.ended.rawValue:
            return "checkmark"
        default:
            return "circle"
        }
    }

    private func pauseControlMetadata(for timerStatusRawValue: String) -> (title: String, systemImage: String) {
        if timerStatusRawValue == LiveActivityTimerStatus.paused.rawValue {
            return ("Resume", "play.fill")
        }

        return ("Pause", "pause.fill")
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
    private func compactElapsedView(for state: FeedTrackerLiveActivityContentState) -> some View {
        let startDate = state.capturedAt.addingTimeInterval(-state.totalElapsed)

        if state.timerStatusRawValue == LiveActivityTimerStatus.running.rawValue {
            Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
        } else {
            Text(Self.formattedCompactDuration(state.totalElapsed))
        }
    }

    private func intentActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: FeedTrackerLiveActivityIntentAction,
        sessionID: String
    ) -> some View {
        Button(intent: FeedTrackerLiveActivityControlIntent(action: action, sessionID: sessionID)) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.15), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text("Executes directly from Live Activity"))
    }

    private func appOpenURL(sessionID: String) -> URL? {
        URL(string: "feedtracker://live-activity?session=\(sessionID)")
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

    private static func formattedCompactDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}
