import Foundation

public extension SessionTimerSnapshot {
    func persistedSession(note: String? = nil) throws -> FeedingSession? {
        guard let sessionID, let startedAt else {
            return nil
        }

        let status: FeedingSessionStatus
        let endedAt: Date?

        switch state {
        case .running:
            status = .active
            endedAt = nil
        case .paused:
            status = .paused
            endedAt = nil
        case .stopped:
            status = .stopped
            endedAt = nil
        case .ended:
            status = .completed
            endedAt = self.endedAt
        case .idle:
            return nil
        }

        return try FeedingSession(
            id: sessionID,
            startedAt: startedAt,
            endedAt: endedAt,
            leftDuration: leftElapsed,
            rightDuration: rightElapsed,
            note: note,
            status: status
        )
    }
}
