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
    private static let liveClockLocale = Locale(identifier: "en_GB")
    private let totalTimerColor = Color(red: 1, green: 0.82, blue: 0.24)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedTrackerLiveActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(appOpenURL(sessionID: context.attributes.sessionID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedTopLeadingView(for: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    expandedTopTrailingView()
                }

                DynamicIslandExpandedRegion(.center) {
                    expandedMiddleRow(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottomRow(context: context)
                }
            } compactLeading: {
                compactLeadingView(for: context.state)
            } compactTrailing: {
                compactTrailingView(for: context.state)
            } minimal: {
                minimalView(for: context.state)
            }
            .widgetURL(appOpenURL(sessionID: context.attributes.sessionID))
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FeedTrackerLiveActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white.opacity(0.82))
                        .frame(width: 8, height: 8)
                    Text(expandedSideLabel(for: context.state.activeSideRawValue))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .textCase(.uppercase)
                }

                Spacer()

                liveClockView()
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
            }

            HStack(spacing: 12) {
                timerPanel(title: "Active", accent: .white, isLeading: true) {
                    activeElapsedView(for: context.state)
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }

                let pauseControl = pauseControlMetadata(for: context.state.timerStatusRawValue)
                intentCircleActionButton(
                    title: pauseControl.title,
                    systemImage: pauseControl.systemImage,
                    tint: Color.white.opacity(0.88),
                    backgroundOpacity: 0.18,
                    size: 60,
                    action: .togglePause,
                    sessionID: context.attributes.sessionID
                )

                timerPanel(title: "Total", accent: totalTimerColor, isLeading: false) {
                    totalElapsedView(for: context.state)
                        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(totalTimerColor)
                }
            }

            HStack(spacing: 10) {
                intentPillActionButton(
                    title: "Switch",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .accentColor,
                    backgroundOpacity: 0.16,
                    action: .switchSide,
                    sessionID: context.attributes.sessionID
                )

                intentPillActionButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                    tint: .red,
                    backgroundOpacity: 0.18,
                    action: .terminate,
                    sessionID: context.attributes.sessionID
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func expandedTopLeadingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.82))
                .frame(width: 8, height: 8)
            Text(expandedSideLabel(for: state.activeSideRawValue))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .frame(height: 42, alignment: .leading)
    }

    private func expandedTopTrailingView() -> some View {
        liveClockView()
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white.opacity(0.76))
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .frame(height: 42, alignment: .trailing)
    }

    private func expandedMiddleRow(
        context: ActivityViewContext<FeedTrackerLiveActivityAttributes>
    ) -> some View {
        HStack(spacing: 12) {
            timerPanel(title: "Active", accent: .white, isLeading: true) {
                activeElapsedView(for: context.state)
                    .font(.system(size: 29, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }

            let pauseControl = pauseControlMetadata(for: context.state.timerStatusRawValue)
            intentCircleActionButton(
                title: pauseControl.title,
                systemImage: pauseControl.systemImage,
                tint: Color.white.opacity(0.88),
                backgroundOpacity: 0.18,
                size: 58,
                action: .togglePause,
                sessionID: context.attributes.sessionID
            )

            timerPanel(title: "Total", accent: totalTimerColor, isLeading: false) {
                totalElapsedView(for: context.state)
                    .font(.system(size: 25, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(totalTimerColor)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
    }

    private func expandedBottomRow(
        context: ActivityViewContext<FeedTrackerLiveActivityAttributes>
    ) -> some View {
        HStack(spacing: 10) {
            intentPillActionButton(
                title: "Switch",
                systemImage: "arrow.triangle.2.circlepath",
                tint: .accentColor,
                backgroundOpacity: 0.16,
                action: .switchSide,
                sessionID: context.attributes.sessionID
            )

            intentPillActionButton(
                title: "Stop",
                systemImage: "stop.fill",
                tint: .red,
                backgroundOpacity: 0.18,
                action: .terminate,
                sessionID: context.attributes.sessionID
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42, alignment: .bottom)
        .padding(.horizontal, 2)
        .padding(.bottom, 0)
    }

    private func compactLeadingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        HStack(spacing: 3) {
            Text(compactSideBadge(for: state.activeSideRawValue))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.84))
            compactActiveElapsedView(for: state)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.leading, 4)
        .padding(.trailing, 2)
    }

    private func compactTrailingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        HStack(spacing: 3) {
            compactTotalElapsedView(for: state)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(totalTimerColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Image(systemName: statusIcon(for: state.timerStatusRawValue))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.leading, 2)
        .padding(.trailing, 4)
    }

    private func minimalView(for state: FeedTrackerLiveActivityContentState) -> some View {
        Image(systemName: statusIcon(for: state.timerStatusRawValue))
            .font(.caption2.weight(.bold))
    }

    @ViewBuilder
    private func totalElapsedView(for state: FeedTrackerLiveActivityContentState) -> some View {
        let startDate = state.capturedAt.addingTimeInterval(-state.totalElapsed)

        if state.timerStatusRawValue == LiveActivityTimerStatus.running.rawValue {
            Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
        } else {
            Text(Self.formattedDuration(state.totalElapsed))
        }
    }

    @ViewBuilder
    private func activeElapsedView(for state: FeedTrackerLiveActivityContentState) -> some View {
        if let side = FeedingSide(rawValue: state.activeSideRawValue ?? "") {
            let baseline: TimeInterval = side == .left ? state.leftElapsed : state.rightElapsed
            let startDate = state.capturedAt.addingTimeInterval(-baseline)

            if state.timerStatusRawValue == LiveActivityTimerStatus.running.rawValue {
                Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
            } else {
                Text(Self.formattedDuration(baseline))
            }
        } else {
            Text("--:--")
        }
    }

    @ViewBuilder
    private func compactActiveElapsedView(for state: FeedTrackerLiveActivityContentState) -> some View {
        if let side = FeedingSide(rawValue: state.activeSideRawValue ?? "") {
            let baseline: TimeInterval = side == .left ? state.leftElapsed : state.rightElapsed
            let startDate = state.capturedAt.addingTimeInterval(-baseline)

            if state.timerStatusRawValue == LiveActivityTimerStatus.running.rawValue {
                Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
            } else {
                Text(Self.formattedCompactDuration(baseline))
            }
        } else {
            Text("--")
        }
    }

    @ViewBuilder
    private func compactTotalElapsedView(for state: FeedTrackerLiveActivityContentState) -> some View {
        let startDate = state.capturedAt.addingTimeInterval(-state.totalElapsed)

        if state.timerStatusRawValue == LiveActivityTimerStatus.running.rawValue {
            Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
        } else {
            Text(Self.formattedCompactDuration(state.totalElapsed))
        }
    }

    private func timerPanel<Content: View>(
        title: String,
        accent: Color,
        isLeading: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: isLeading ? .leading : .trailing, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent.opacity(0.78))
                .textCase(.uppercase)
                .lineLimit(1)

            content()
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
        .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .trailing)
        .frame(height: 68, alignment: isLeading ? .leading : .trailing)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func intentCircleActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        backgroundOpacity: Double,
        size: CGFloat,
        action: FeedTrackerLiveActivityIntentAction,
        sessionID: String
    ) -> some View {
        Button(intent: FeedTrackerLiveActivityControlIntent(action: action, sessionID: sessionID)) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(tint.opacity(backgroundOpacity), in: Circle())
                .overlay(Circle().strokeBorder(tint.opacity(0.12), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text("Executes directly from Live Activity"))
    }

    private func intentPillActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        backgroundOpacity: Double,
        action: FeedTrackerLiveActivityIntentAction,
        sessionID: String
    ) -> some View {
        Button(intent: FeedTrackerLiveActivityControlIntent(action: action, sessionID: sessionID)) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(tint.opacity(backgroundOpacity), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.14), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text("Executes directly from Live Activity"))
    }

    private func liveClockView() -> some View {
        Text(Date(), style: .time)
            .environment(\.locale, Self.liveClockLocale)
    }

    private func expandedSideLabel(for raw: String?) -> String {
        switch raw {
        case "left":
            return "Left"
        case "right":
            return "Right"
        default:
            return "--"
        }
    }

    private func compactSideBadge(for raw: String?) -> String {
        switch raw {
        case "left":
            return "L"
        case "right":
            return "R"
        default:
            return "•"
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

    private func appOpenURL(sessionID: String) -> URL? {
        LiveActivityQuickActionRouter().passiveOpenURL(sessionID: sessionID)
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
