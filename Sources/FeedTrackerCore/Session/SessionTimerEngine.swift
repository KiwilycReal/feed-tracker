import Foundation

public enum SessionTimerState: Equatable, Sendable {
    case idle
    case running(side: FeedingSide)
    case paused(side: FeedingSide)
    case stopped
    case ended
}

public enum SessionTimerEngineError: Error, Equatable, Sendable {
    case invalidTransition(action: String, state: SessionTimerState)
    case sessionNotStarted
}

public struct SessionTimerSnapshot: Equatable, Sendable {
    public let state: SessionTimerState
    public let activeSide: FeedingSide?
    public let leftElapsed: TimeInterval
    public let rightElapsed: TimeInterval
    public let totalElapsed: TimeInterval
    public let startedAt: Date?
    public let endedAt: Date?
}

public final class SessionTimerEngine {
    private let now: @Sendable () -> Date

    private var state: SessionTimerState = .idle
    private var startedAt: Date?
    private var endedAt: Date?
    private var runningSide: FeedingSide?
    private var runningSince: Date?
    private var leftAccumulated: TimeInterval = 0
    private var rightAccumulated: TimeInterval = 0

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    public func start(_ side: FeedingSide) throws {
        let current = now()

        switch state {
        case .idle, .ended:
            startedAt = current
            endedAt = nil
            leftAccumulated = 0
            rightAccumulated = 0
            runningSide = side
            runningSince = current
            state = .running(side: side)

        case .stopped:
            runningSide = side
            runningSince = current
            state = .running(side: side)

        default:
            throw SessionTimerEngineError.invalidTransition(action: "start", state: state)
        }
    }

    public func `switch`(to side: FeedingSide) throws {
        guard case .running(let activeSide) = state else {
            throw SessionTimerEngineError.invalidTransition(action: "switch", state: state)
        }

        let current = now()
        accumulateRunningInterval(until: current)

        runningSide = side
        runningSince = current
        state = .running(side: side)

        if activeSide == side {
            state = .running(side: side)
        }
    }

    public func pause() throws {
        guard case .running(let side) = state else {
            throw SessionTimerEngineError.invalidTransition(action: "pause", state: state)
        }

        let current = now()
        accumulateRunningInterval(until: current)

        runningSince = nil
        runningSide = nil
        state = .paused(side: side)
    }

    public func resume() throws {
        guard case .paused(let side) = state else {
            throw SessionTimerEngineError.invalidTransition(action: "resume", state: state)
        }

        let current = now()
        runningSide = side
        runningSince = current
        state = .running(side: side)
    }

    public func stopCurrentSide() throws {
        guard case .running = state else {
            throw SessionTimerEngineError.invalidTransition(action: "stopCurrentSide", state: state)
        }

        let current = now()
        accumulateRunningInterval(until: current)

        runningSide = nil
        runningSince = nil
        state = .stopped
    }

    @discardableResult
    public func endSession(note: String? = nil) throws -> FeedingSession {
        guard startedAt != nil else {
            throw SessionTimerEngineError.sessionNotStarted
        }

        if case .ended = state {
            throw SessionTimerEngineError.invalidTransition(action: "endSession", state: state)
        }

        let current = now()

        if case .running = state {
            accumulateRunningInterval(until: current)
        }

        runningSide = nil
        runningSince = nil
        endedAt = current
        state = .ended

        return try FeedingSession(
            startedAt: startedAt ?? current,
            endedAt: endedAt,
            leftDuration: leftAccumulated,
            rightDuration: rightAccumulated,
            note: note,
            status: .completed
        )
    }

    public func snapshot(at date: Date? = nil) -> SessionTimerSnapshot {
        let now = date ?? self.now()
        var leftElapsed = leftAccumulated
        var rightElapsed = rightAccumulated

        if case .running(let side) = state, let runningSince {
            let delta = max(0, now.timeIntervalSince(runningSince))
            switch side {
            case .left:
                leftElapsed += delta
            case .right:
                rightElapsed += delta
            }
        }

        return SessionTimerSnapshot(
            state: state,
            activeSide: activeSide(for: state),
            leftElapsed: leftElapsed,
            rightElapsed: rightElapsed,
            totalElapsed: leftElapsed + rightElapsed,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    private func activeSide(for state: SessionTimerState) -> FeedingSide? {
        if case .running(let side) = state {
            return side
        }
        return nil
    }

    private func accumulateRunningInterval(until date: Date) {
        guard let runningSince, let runningSide else {
            return
        }

        let delta = max(0, date.timeIntervalSince(runningSince))
        switch runningSide {
        case .left:
            leftAccumulated += delta
        case .right:
            rightAccumulated += delta
        }
    }
}
