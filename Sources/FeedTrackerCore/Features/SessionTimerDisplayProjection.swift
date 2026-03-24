import Foundation

public struct SessionTimerDisplayValues: Equatable, Sendable {
    public let activeSide: FeedingSide?
    public let activeSideElapsed: TimeInterval
    public let leftElapsed: TimeInterval
    public let rightElapsed: TimeInterval
    public let totalElapsed: TimeInterval

    public init(
        activeSide: FeedingSide?,
        activeSideElapsed: TimeInterval,
        leftElapsed: TimeInterval,
        rightElapsed: TimeInterval,
        totalElapsed: TimeInterval
    ) {
        self.activeSide = activeSide
        self.activeSideElapsed = activeSideElapsed
        self.leftElapsed = leftElapsed
        self.rightElapsed = rightElapsed
        self.totalElapsed = totalElapsed
    }
}

public enum SessionTimerDisplayProjection {
    private struct ProjectionInput {
        let activeSide: FeedingSide?
        let leftElapsed: TimeInterval
        let rightElapsed: TimeInterval
        let timerStatus: LiveActivityTimerStatus
        let capturedAt: Date?
        let now: Date?
    }

    public static func values(snapshot: SessionTimerSnapshot) -> SessionTimerDisplayValues {
        values(
            input: ProjectionInput(
                activeSide: snapshot.activeSide,
                leftElapsed: snapshot.leftElapsed,
                rightElapsed: snapshot.rightElapsed,
                timerStatus: LiveActivityTimerStatus(state: snapshot.state),
                capturedAt: nil,
                now: nil
            )
        )
    }

    public static func values(
        state: LiveActivityState,
        capturedAt: Date,
        now: Date
    ) -> SessionTimerDisplayValues {
        values(
            input: ProjectionInput(
                activeSide: state.activeSide,
                leftElapsed: state.leftElapsed,
                rightElapsed: state.rightElapsed,
                timerStatus: state.timerStatus,
                capturedAt: capturedAt,
                now: now
            )
        )
    }

    public static func displayedWholeSeconds(_ value: TimeInterval) -> TimeInterval {
        max(0, TimeInterval(Int(value.rounded())))
    }

    private static func values(input: ProjectionInput) -> SessionTimerDisplayValues {
        let baselineLeftElapsed: TimeInterval
        let baselineRightElapsed: TimeInterval

        if input.capturedAt == nil {
            baselineLeftElapsed = displayedWholeSeconds(input.leftElapsed)
            baselineRightElapsed = displayedWholeSeconds(input.rightElapsed)
        } else {
            baselineLeftElapsed = max(0, input.leftElapsed)
            baselineRightElapsed = max(0, input.rightElapsed)
        }

        let projectedElapsedDelta: TimeInterval
        if input.timerStatus == .running,
           let capturedAt = input.capturedAt,
           let now = input.now {
            projectedElapsedDelta = max(0, TimeInterval(Int(now.timeIntervalSince(capturedAt))))
        } else {
            projectedElapsedDelta = 0
        }

        let displayedLeftElapsed: TimeInterval
        let displayedRightElapsed: TimeInterval

        switch input.activeSide {
        case .left where input.timerStatus == .running:
            displayedLeftElapsed = baselineLeftElapsed + projectedElapsedDelta
            displayedRightElapsed = baselineRightElapsed
        case .right where input.timerStatus == .running:
            displayedLeftElapsed = baselineLeftElapsed
            displayedRightElapsed = baselineRightElapsed + projectedElapsedDelta
        default:
            displayedLeftElapsed = baselineLeftElapsed
            displayedRightElapsed = baselineRightElapsed
        }

        let displayedTotalElapsed = displayedLeftElapsed + displayedRightElapsed

        let displayedActiveElapsed: TimeInterval
        switch input.activeSide {
        case .left:
            displayedActiveElapsed = displayedLeftElapsed
        case .right:
            displayedActiveElapsed = displayedRightElapsed
        case nil:
            displayedActiveElapsed = 0
        }

        return SessionTimerDisplayValues(
            activeSide: input.activeSide,
            activeSideElapsed: displayedActiveElapsed,
            leftElapsed: displayedLeftElapsed,
            rightElapsed: displayedRightElapsed,
            totalElapsed: displayedTotalElapsed
        )
    }
}

extension LiveActivityTimerStatus {
    init(state: SessionTimerState) {
        switch state {
        case .idle:
            self = .idle
        case .running:
            self = .running
        case .paused:
            self = .paused
        case .stopped:
            self = .stopped
        case .ended:
            self = .ended
        }
    }
}
