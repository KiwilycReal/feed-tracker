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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                metadataBadge(for: context.state)
                Spacer(minLength: 8)
                liveClockView()
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
            }

            synchronizedTimerRow(
                for: context.state,
                activeFont: .system(size: 30, weight: .bold, design: .rounded).monospacedDigit(),
                totalFont: .system(size: 26, weight: .bold, design: .rounded).monospacedDigit(),
                sessionID: context.attributes.sessionID,
                pauseButtonSize: 58,
                panelHeight: 68,
                rowSpacing: 10
            )

            HStack(spacing: 10) {
                intentPillActionButton(
                    title: "Switch",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .accentColor,
                    backgroundOpacity: 0.16,
                    action: .switchSide,
                    sessionID: context.attributes.sessionID,
                    height: 38
                )

                intentPillActionButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                    tint: .red,
                    backgroundOpacity: 0.18,
                    action: .terminate,
                    sessionID: context.attributes.sessionID,
                    height: 38
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func expandedTopLeadingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        metadataBadge(for: state)
            .padding(.top, 2)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expandedTopTrailingView() -> some View {
        liveClockView()
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 2)
            .padding(.trailing, 6)
    }

    private func expandedMiddleRow(
        context: ActivityViewContext<FeedTrackerLiveActivityAttributes>
    ) -> some View {
        synchronizedTimerRow(
            for: context.state,
            activeFont: .system(size: 27, weight: .bold, design: .rounded).monospacedDigit(),
            totalFont: .system(size: 23, weight: .bold, design: .rounded).monospacedDigit(),
            sessionID: context.attributes.sessionID,
            pauseButtonSize: 52,
            panelHeight: 60,
            rowSpacing: 8
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private func expandedBottomRow(
        context: ActivityViewContext<FeedTrackerLiveActivityAttributes>
    ) -> some View {
        HStack(spacing: 8) {
            intentPillActionButton(
                title: "Switch",
                systemImage: "arrow.triangle.2.circlepath",
                tint: .accentColor,
                backgroundOpacity: 0.16,
                action: .switchSide,
                sessionID: context.attributes.sessionID,
                height: 34
            )

            intentPillActionButton(
                title: "Stop",
                systemImage: "stop.fill",
                tint: .red,
                backgroundOpacity: 0.18,
                action: .terminate,
                sessionID: context.attributes.sessionID,
                height: 34
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 1)
    }

    private func compactLeadingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        HStack(spacing: 3) {
            Text(compactSideBadge(for: state.activeSideRawValue))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.84))
            activeElapsedText(for: state, font: .caption2.monospacedDigit().weight(.semibold), compact: true)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.leading, 6)
        .padding(.trailing, 3)
    }

    private func compactTrailingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        HStack(spacing: 3) {
            totalElapsedText(for: state, font: .caption2.monospacedDigit().weight(.semibold), compact: true)
                .foregroundStyle(totalTimerColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Image(systemName: statusIcon(for: state.timerStatusRawValue))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.leading, 3)
        .padding(.trailing, 6)
    }

    private func minimalView(for state: FeedTrackerLiveActivityContentState) -> some View {
        Image(systemName: statusIcon(for: state.timerStatusRawValue))
            .font(.caption2.weight(.bold))
    }

    private func synchronizedTimerRow(
        for state: FeedTrackerLiveActivityContentState,
        activeFont: Font,
        totalFont: Font,
        sessionID: String,
        pauseButtonSize: CGFloat,
        panelHeight: CGFloat,
        rowSpacing: CGFloat
    ) -> some View {
        let pauseControl = pauseControlMetadata(for: state.timerStatusRawValue)

        return HStack(spacing: rowSpacing) {
            timerPanel(title: "Active", accent: .white, isLeading: true, height: panelHeight) {
                activeElapsedText(for: state, font: activeFont, compact: false)
                    .foregroundStyle(.white)
            }

            intentCircleActionButton(
                title: pauseControl.title,
                systemImage: pauseControl.systemImage,
                tint: Color.white.opacity(0.88),
                backgroundOpacity: 0.18,
                size: pauseButtonSize,
                action: .togglePause,
                sessionID: sessionID
            )

            timerPanel(title: "Total", accent: totalTimerColor, isLeading: false, height: panelHeight) {
                totalElapsedText(for: state, font: totalFont, compact: false)
                    .foregroundStyle(totalTimerColor)
            }
        }
    }

    @ViewBuilder
    private func activeElapsedText(for state: FeedTrackerLiveActivityContentState, font: Font, compact: Bool) -> some View {
        let activeSide = FeedingSide(rawValue: state.activeSideRawValue ?? "")
        let staticElapsed = activeSide == .right ? state.rightElapsed : state.leftElapsed
        let anchorDate = activeSide.flatMap { state.anchorDate(for: $0) }

        elapsedText(
            anchorDate: anchorDate,
            staticElapsed: staticElapsed,
            font: font,
            compact: compact
        )
    }

    @ViewBuilder
    private func totalElapsedText(for state: FeedTrackerLiveActivityContentState, font: Font, compact: Bool) -> some View {
        elapsedText(
            anchorDate: state.totalAnchorDate,
            staticElapsed: state.totalElapsed,
            font: font,
            compact: compact
        )
    }

    @ViewBuilder
    private func elapsedText(anchorDate: Date?, staticElapsed: TimeInterval, font: Font, compact: Bool) -> some View {
        if let anchorDate {
            Text(anchorDate, style: .timer)
                .font(font)
                .monospacedDigit()
        } else {
            Text(compact ? Self.formattedCompactDuration(staticElapsed) : Self.formattedDuration(staticElapsed))
                .font(font)
                .monospacedDigit()
        }
    }

    private func timerPanel<Content: View>(
        title: String,
        accent: Color,
        isLeading: Bool,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: isLeading ? .leading : .trailing, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent.opacity(0.76))
                .textCase(.uppercase)
                .lineLimit(1)

            content()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .trailing)
        .frame(height: height, alignment: isLeading ? .leading : .trailing)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func metadataBadge(for state: FeedTrackerLiveActivityContentState) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.82))
                .frame(width: 6, height: 6)
            Text(expandedSideLabel(for: state.activeSideRawValue))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
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
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
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
        sessionID: String,
        height: CGFloat
    ) -> some View {
        Button(intent: FeedTrackerLiveActivityControlIntent(action: action, sessionID: sessionID)) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: height)
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
            return "左"
        case "right":
            return "右"
        default:
            return "--"
        }
    }

    private func compactSideBadge(for raw: String?) -> String {
        switch raw {
        case "left":
            return "左"
        case "right":
            return "右"
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
