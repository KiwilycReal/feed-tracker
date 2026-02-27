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

    public init(snapshot: SessionTimerSnapshot) {
        self.activeSide = snapshot.activeSide
        self.leftElapsed = snapshot.leftElapsed
        self.rightElapsed = snapshot.rightElapsed
        self.totalElapsed = snapshot.totalElapsed
        self.startedAt = snapshot.startedAt
        self.endedAt = snapshot.endedAt
        self.timerStatus = LiveActivityTimerStatus(state: snapshot.state)
    }
}

private extension LiveActivityTimerStatus {
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
