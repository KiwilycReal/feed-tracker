import Foundation

public enum LiveActivityTimerStatus: String, Equatable, Sendable, Codable {
    case idle
    case running
    case paused
    case stopped
    case ended
}

public struct LiveActivityState: Equatable, Sendable {
    public let activeSide: FeedingSide?
    public let leftElapsed: TimeInterval
    public let rightElapsed: TimeInterval
    public let totalElapsed: TimeInterval
    public let startedAt: Date?
    public let endedAt: Date?
    public let timerStatus: LiveActivityTimerStatus

    public init(
        activeSide: FeedingSide?,
        leftElapsed: TimeInterval,
        rightElapsed: TimeInterval,
        totalElapsed: TimeInterval,
        startedAt: Date?,
        endedAt: Date?,
        timerStatus: LiveActivityTimerStatus
    ) {
        self.activeSide = activeSide
        self.leftElapsed = leftElapsed
        self.rightElapsed = rightElapsed
        self.totalElapsed = totalElapsed
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.timerStatus = timerStatus
    }

    public init(snapshot: SessionTimerSnapshot) {
        self.init(
            activeSide: snapshot.activeSide,
            leftElapsed: snapshot.leftElapsed,
            rightElapsed: snapshot.rightElapsed,
            totalElapsed: snapshot.totalElapsed,
            startedAt: snapshot.startedAt,
            endedAt: snapshot.endedAt,
            timerStatus: LiveActivityTimerStatus(state: snapshot.state)
        )
    }
}
