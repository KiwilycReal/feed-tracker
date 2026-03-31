import Foundation

public enum SessionTimerClockStatus: String, Codable, Equatable, Sendable {
    case idle
    case runningLeft
    case runningRight
    case pausedLeft
    case pausedRight
    case stopped
    case ended
}

public struct SessionTimerClockState: Codable, Equatable, Sendable {
    public let sessionID: UUID?
    public let status: SessionTimerClockStatus
    public let startedAt: Date?
    public let endedAt: Date?
    public let runningSince: Date?
    public let leftAccumulated: TimeInterval
    public let rightAccumulated: TimeInterval
    public let recordedAt: Date

    public init(
        sessionID: UUID?,
        status: SessionTimerClockStatus,
        startedAt: Date?,
        endedAt: Date?,
        runningSince: Date?,
        leftAccumulated: TimeInterval,
        rightAccumulated: TimeInterval,
        recordedAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.runningSince = runningSince
        self.leftAccumulated = max(0, leftAccumulated)
        self.rightAccumulated = max(0, rightAccumulated)
        self.recordedAt = recordedAt
    }

    public var activeSide: FeedingSide? {
        switch status {
        case .runningLeft, .pausedLeft:
            return .left
        case .runningRight, .pausedRight:
            return .right
        case .idle, .stopped, .ended:
            return nil
        }
    }

    public var sessionState: SessionTimerState {
        switch status {
        case .idle:
            return .idle
        case .runningLeft:
            return .running(side: .left)
        case .runningRight:
            return .running(side: .right)
        case .pausedLeft:
            return .paused(side: .left)
        case .pausedRight:
            return .paused(side: .right)
        case .stopped:
            return .stopped
        case .ended:
            return .ended
        }
    }

    public var liveActivitySyncToken: String {
        [
            sessionID?.uuidString ?? "none",
            status.rawValue,
            startedAt?.ISO8601Format() ?? "none",
            endedAt?.ISO8601Format() ?? "none",
            runningSince?.ISO8601Format() ?? "none",
            String(leftAccumulated.bitPattern),
            String(rightAccumulated.bitPattern)
        ].joined(separator: "|")
    }

    public func snapshot(at date: Date? = nil) -> SessionTimerSnapshot {
        let captureDate = date ?? recordedAt
        let activeSide = activeSide

        var leftElapsed = leftAccumulated
        var rightElapsed = rightAccumulated

        if let runningSince,
           let activeSide,
           runningSince <= captureDate,
           status == .runningLeft || status == .runningRight {
            let delta = max(0, captureDate.timeIntervalSince(runningSince))
            switch activeSide {
            case .left:
                leftElapsed += delta
            case .right:
                rightElapsed += delta
            }
        }

        return SessionTimerSnapshot(
            sessionID: sessionID,
            state: sessionState,
            activeSide: activeSide,
            leftElapsed: leftElapsed,
            rightElapsed: rightElapsed,
            totalElapsed: leftElapsed + rightElapsed,
            startedAt: startedAt,
            endedAt: endedAt,
            capturedAt: captureDate
        )
    }

    public var recoveryState: SessionTimerRecoveryState? {
        guard let sessionID, let startedAt else {
            return nil
        }

        switch status {
        case .idle, .ended:
            return nil
        case .runningLeft:
            return SessionTimerRecoveryState(
                sessionID: sessionID,
                status: .runningLeft,
                startedAt: startedAt,
                runningSince: runningSince,
                leftAccumulated: leftAccumulated,
                rightAccumulated: rightAccumulated
            )
        case .runningRight:
            return SessionTimerRecoveryState(
                sessionID: sessionID,
                status: .runningRight,
                startedAt: startedAt,
                runningSince: runningSince,
                leftAccumulated: leftAccumulated,
                rightAccumulated: rightAccumulated
            )
        case .pausedLeft:
            return SessionTimerRecoveryState(
                sessionID: sessionID,
                status: .pausedLeft,
                startedAt: startedAt,
                runningSince: nil,
                leftAccumulated: leftAccumulated,
                rightAccumulated: rightAccumulated
            )
        case .pausedRight:
            return SessionTimerRecoveryState(
                sessionID: sessionID,
                status: .pausedRight,
                startedAt: startedAt,
                runningSince: nil,
                leftAccumulated: leftAccumulated,
                rightAccumulated: rightAccumulated
            )
        case .stopped:
            return SessionTimerRecoveryState(
                sessionID: sessionID,
                status: .stopped,
                startedAt: startedAt,
                runningSince: nil,
                leftAccumulated: leftAccumulated,
                rightAccumulated: rightAccumulated
            )
        }
    }
}

public extension SessionTimerClockState {
    init(snapshot: SessionTimerSnapshot) {
        let status: SessionTimerClockStatus
        let runningSince: Date?
        let leftAccumulated: TimeInterval
        let rightAccumulated: TimeInterval

        switch snapshot.state {
        case .idle:
            status = .idle
            runningSince = nil
            leftAccumulated = 0
            rightAccumulated = 0
        case .running(let side):
            status = side == .left ? .runningLeft : .runningRight
            runningSince = snapshot.capturedAt
            switch side {
            case .left:
                leftAccumulated = max(0, snapshot.leftElapsed)
                rightAccumulated = max(0, snapshot.rightElapsed)
            case .right:
                leftAccumulated = max(0, snapshot.leftElapsed)
                rightAccumulated = max(0, snapshot.rightElapsed)
            }
        case .paused(let side):
            status = side == .left ? .pausedLeft : .pausedRight
            runningSince = nil
            leftAccumulated = max(0, snapshot.leftElapsed)
            rightAccumulated = max(0, snapshot.rightElapsed)
        case .stopped:
            status = .stopped
            runningSince = nil
            leftAccumulated = max(0, snapshot.leftElapsed)
            rightAccumulated = max(0, snapshot.rightElapsed)
        case .ended:
            status = .ended
            runningSince = nil
            leftAccumulated = max(0, snapshot.leftElapsed)
            rightAccumulated = max(0, snapshot.rightElapsed)
        }

        self.init(
            sessionID: snapshot.sessionID,
            status: status,
            startedAt: snapshot.startedAt,
            endedAt: snapshot.endedAt,
            runningSince: runningSince,
            leftAccumulated: leftAccumulated,
            rightAccumulated: rightAccumulated,
            recordedAt: snapshot.capturedAt
        )
    }

    init(recoveryState: SessionTimerRecoveryState, recordedAt: Date = Date()) {
        let status: SessionTimerClockStatus
        switch recoveryState.status {
        case .runningLeft:
            status = .runningLeft
        case .runningRight:
            status = .runningRight
        case .pausedLeft:
            status = .pausedLeft
        case .pausedRight:
            status = .pausedRight
        case .stopped:
            status = .stopped
        }

        self.init(
            sessionID: recoveryState.sessionID,
            status: status,
            startedAt: recoveryState.startedAt,
            endedAt: nil,
            runningSince: recoveryState.runningSince,
            leftAccumulated: recoveryState.leftAccumulated,
            rightAccumulated: recoveryState.rightAccumulated,
            recordedAt: recordedAt
        )
    }
}
