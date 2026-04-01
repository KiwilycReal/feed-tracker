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
    private static let lockScreenSpec = LiveActivitySurfaceSpec(
        activeFont: .system(size: 27, weight: .bold, design: .rounded).monospacedDigit(),
        totalFont: .system(size: 23, weight: .bold, design: .rounded).monospacedDigit(),
        clockFont: .caption2.monospacedDigit().weight(.semibold),
        badgeFont: .system(size: 11, weight: .semibold, design: .rounded),
        contentSpacing: 10,
        timerSpacing: 8,
        compactTimerSpacing: 6,
        panelHorizontalPadding: 10,
        panelVerticalPadding: 8,
        metricMinHeight: 58,
        controlSize: 52,
        actionSpacing: 8,
        actionMinHeight: 34,
        badgeHorizontalPadding: 7,
        badgeVerticalPadding: 3
    )
    private static let expandedSpec = LiveActivitySurfaceSpec(
        activeFont: .system(size: 24, weight: .bold, design: .rounded).monospacedDigit(),
        totalFont: .system(size: 20, weight: .bold, design: .rounded).monospacedDigit(),
        clockFont: .system(size: 11, weight: .semibold, design: .rounded).monospacedDigit(),
        badgeFont: .system(size: 10, weight: .semibold, design: .rounded),
        contentSpacing: 8,
        timerSpacing: 6,
        compactTimerSpacing: 4,
        panelHorizontalPadding: 9,
        panelVerticalPadding: 7,
        metricMinHeight: 50,
        controlSize: 46,
        actionSpacing: 6,
        actionMinHeight: 31,
        badgeHorizontalPadding: 6,
        badgeVerticalPadding: 3
    )

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
        let spec = Self.lockScreenSpec

        VStack(alignment: .leading, spacing: spec.contentSpacing) {
            surfaceHeader(for: context.state, spec: spec)

            primaryMetricsStrip(
                for: context.state,
                sessionID: context.attributes.sessionID,
                spec: spec
            )

            actionStrip(sessionID: context.attributes.sessionID, spec: spec)
        }
        .padding(.vertical, 6)
    }

    private func expandedTopLeadingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        metadataBadge(for: state, spec: Self.expandedSpec)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .padding(.leading, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expandedTopTrailingView() -> some View {
        liveClockView(font: Self.expandedSpec.clockFont, foregroundOpacity: 0.72)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .padding(.trailing, 11)
    }

    private func expandedMiddleRow(
        context: ActivityViewContext<FeedTrackerLiveActivityAttributes>
    ) -> some View {
        primaryMetricsStrip(
            for: context.state,
            sessionID: context.attributes.sessionID,
            spec: Self.expandedSpec
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 3)
        .padding(.horizontal, 6)
    }

    private func expandedBottomRow(
        context: ActivityViewContext<FeedTrackerLiveActivityAttributes>
    ) -> some View {
        actionStrip(sessionID: context.attributes.sessionID, spec: Self.expandedSpec)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.top, 1)
            .padding(.bottom, 1)
    }

    private func surfaceHeader(
        for state: FeedTrackerLiveActivityContentState,
        spec: LiveActivitySurfaceSpec
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            metadataBadge(for: state, spec: spec)
            Spacer(minLength: 8)
            liveClockView(font: spec.clockFont, foregroundOpacity: 0.76)
        }
    }

    private func compactLeadingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        HStack(spacing: 3) {
            Text(compactSideBadge(for: state.activeSideRawValue))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.84))
            activeElapsedText(for: state, font: .caption2.monospacedDigit().weight(.semibold), compact: true)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(.leading, 6)
        .padding(.trailing, 3)
    }

    private func compactTrailingView(for state: FeedTrackerLiveActivityContentState) -> some View {
        HStack(spacing: 3) {
            totalElapsedText(for: state, font: .caption2.monospacedDigit().weight(.semibold), compact: true)
                .foregroundStyle(totalTimerColor)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
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

    private func primaryMetricsStrip(
        for state: FeedTrackerLiveActivityContentState,
        sessionID: String,
        spec: LiveActivitySurfaceSpec
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            timerMetricsRow(
                for: state,
                sessionID: sessionID,
                activeFont: spec.activeFont,
                totalFont: spec.totalFont,
                panelHorizontalPadding: spec.panelHorizontalPadding,
                panelVerticalPadding: spec.panelVerticalPadding,
                panelSpacing: spec.timerSpacing,
                controlSize: spec.controlSize,
                minHeight: spec.metricMinHeight
            )

            timerMetricsRow(
                for: state,
                sessionID: sessionID,
                activeFont: spec.activeFont,
                totalFont: spec.totalFont,
                panelHorizontalPadding: max(7, spec.panelHorizontalPadding - 2),
                panelVerticalPadding: max(6, spec.panelVerticalPadding - 1),
                panelSpacing: spec.compactTimerSpacing,
                controlSize: max(40, spec.controlSize - 4),
                minHeight: max(46, spec.metricMinHeight - 4)
            )
        }
    }

    private func timerMetricsRow(
        for state: FeedTrackerLiveActivityContentState,
        sessionID: String,
        activeFont: Font,
        totalFont: Font,
        panelHorizontalPadding: CGFloat,
        panelVerticalPadding: CGFloat,
        panelSpacing: CGFloat,
        controlSize: CGFloat,
        minHeight: CGFloat
    ) -> some View {
        let pauseControl = pauseControlMetadata(for: state.timerStatusRawValue)

        return HStack(alignment: .center, spacing: panelSpacing) {
            timerPanel(
                title: "Active",
                accent: .white,
                isLeading: true,
                minHeight: minHeight,
                horizontalPadding: panelHorizontalPadding,
                verticalPadding: panelVerticalPadding
            ) {
                activeElapsedText(for: state, font: activeFont, compact: false)
                    .foregroundStyle(.white)
            }
            .layoutPriority(1)

            intentCircleActionButton(
                title: pauseControl.title,
                systemImage: pauseControl.systemImage,
                tint: Color.white.opacity(0.88),
                backgroundOpacity: 0.18,
                size: controlSize,
                action: .togglePause,
                sessionID: sessionID
            )
            .fixedSize()

            timerPanel(
                title: "Total",
                accent: totalTimerColor,
                isLeading: false,
                minHeight: minHeight,
                horizontalPadding: panelHorizontalPadding,
                verticalPadding: panelVerticalPadding
            ) {
                totalElapsedText(for: state, font: totalFont, compact: false)
                    .foregroundStyle(totalTimerColor)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func actionStrip(sessionID: String, spec: LiveActivitySurfaceSpec) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spec.actionSpacing) {
                intentPillActionButton(
                    title: "Switch",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .accentColor,
                    backgroundOpacity: 0.16,
                    action: .switchSide,
                    sessionID: sessionID,
                    minHeight: spec.actionMinHeight
                )

                intentPillActionButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                    tint: .red,
                    backgroundOpacity: 0.18,
                    action: .terminate,
                    sessionID: sessionID,
                    minHeight: spec.actionMinHeight
                )
            }

            VStack(spacing: spec.actionSpacing) {
                intentPillActionButton(
                    title: "Switch",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .accentColor,
                    backgroundOpacity: 0.16,
                    action: .switchSide,
                    sessionID: sessionID,
                    minHeight: spec.actionMinHeight
                )

                intentPillActionButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                    tint: .red,
                    backgroundOpacity: 0.18,
                    action: .terminate,
                    sessionID: sessionID,
                    minHeight: spec.actionMinHeight
                )
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
        minHeight: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let alignment: Alignment = isLeading ? .leading : .trailing

        return VStack(alignment: isLeading ? .leading : .trailing, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(accent.opacity(0.76))
                .textCase(.uppercase)
                .lineLimit(1)

            content()
                .lineLimit(1)
                .minimumScaleFactor(0.54)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(minHeight: minHeight, alignment: alignment)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func metadataBadge(
        for state: FeedTrackerLiveActivityContentState,
        spec: LiveActivitySurfaceSpec
    ) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.white.opacity(0.82))
                .frame(width: 5, height: 5)
            Text(expandedSideLabel(for: state.activeSideRawValue))
                .font(spec.badgeFont)
                .foregroundStyle(.white.opacity(0.82))
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .padding(.horizontal, spec.badgeHorizontalPadding)
        .padding(.vertical, spec.badgeVerticalPadding)
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
        minHeight: CGFloat
    ) -> some View {
        Button(intent: FeedTrackerLiveActivityControlIntent(action: action, sessionID: sessionID)) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .frame(minHeight: minHeight)
            .background(tint.opacity(backgroundOpacity), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.14), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text("Executes directly from Live Activity"))
    }

    private func liveClockView(font: Font, foregroundOpacity: Double) -> some View {
        Text(Date(), style: .time)
            .font(font)
            .foregroundStyle(.white.opacity(foregroundOpacity))
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

@available(iOSApplicationExtension 17.0, *)
private struct LiveActivitySurfaceSpec {
    let activeFont: Font
    let totalFont: Font
    let clockFont: Font
    let badgeFont: Font
    let contentSpacing: CGFloat
    let timerSpacing: CGFloat
    let compactTimerSpacing: CGFloat
    let panelHorizontalPadding: CGFloat
    let panelVerticalPadding: CGFloat
    let metricMinHeight: CGFloat
    let controlSize: CGFloat
    let actionSpacing: CGFloat
    let actionMinHeight: CGFloat
    let badgeHorizontalPadding: CGFloat
    let badgeVerticalPadding: CGFloat
}
