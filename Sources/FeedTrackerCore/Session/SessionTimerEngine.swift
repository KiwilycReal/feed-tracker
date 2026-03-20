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
    case invalidRecoveryState
}

public struct SessionTimerSnapshot: Equatable, Sendable {
    public let sessionID: UUID?
    public let state: SessionTimerState
    public let activeSide: FeedingSide?
    public let leftElapsed: TimeInterval
    public let rightElapsed: TimeInterval
    public let totalElapsed: TimeInterval
    public let startedAt: Date?
    public let endedAt: Date?

    public init(
        sessionID: UUID? = nil,
        state: SessionTimerState,
        activeSide: FeedingSide?,
        leftElapsed: TimeInterval,
        rightElapsed: TimeInterval,
        totalElapsed: TimeInterval,
        startedAt: Date?,
        endedAt: Date?
    ) {
        self.sessionID = sessionID
        self.state = state
        self.activeSide = activeSide
        self.leftElapsed = leftElapsed
        self.rightElapsed = rightElapsed
        self.totalElapsed = totalElapsed
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public enum SessionTimerRecoveryStatus: String, Codable, Equatable, Sendable {
    case runningLeft
    case runningRight
    case pausedLeft
    case pausedRight
    case stopped
}

public struct SessionTimerRecoveryState: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let status: SessionTimerRecoveryStatus
    public let startedAt: Date
    public let runningSince: Date?
    public let leftAccumulated: TimeInterval
    public let rightAccumulated: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case sessionID
        case status
        case startedAt
        case runningSince
        case leftAccumulated
        case rightAccumulated
    }

    public init(
        sessionID: UUID = UUID(),
        status: SessionTimerRecoveryStatus,
        startedAt: Date,
        runningSince: Date?,
        leftAccumulated: TimeInterval,
        rightAccumulated: TimeInterval
    ) {
        self.sessionID = sessionID
        self.status = status
        self.startedAt = startedAt
        self.runningSince = runningSince
        self.leftAccumulated = leftAccumulated
        self.rightAccumulated = rightAccumulated
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(SessionTimerRecoveryStatus.self, forKey: .status)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.runningSince = try container.decodeIfPresent(Date.self, forKey: .runningSince)
        self.leftAccumulated = try container.decode(TimeInterval.self, forKey: .leftAccumulated)
        self.rightAccumulated = try container.decode(TimeInterval.self, forKey: .rightAccumulated)
        self.sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID)
            ?? Self.legacyDeterministicSessionID(
                status: status,
                startedAt: startedAt,
                runningSince: runningSince,
                leftAccumulated: leftAccumulated,
                rightAccumulated: rightAccumulated
            )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(status, forKey: .status)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(runningSince, forKey: .runningSince)
        try container.encode(leftAccumulated, forKey: .leftAccumulated)
        try container.encode(rightAccumulated, forKey: .rightAccumulated)
    }

    private static func legacyDeterministicSessionID(
        status: SessionTimerRecoveryStatus,
        startedAt: Date,
        runningSince: Date?,
        leftAccumulated: TimeInterval,
        rightAccumulated: TimeInterval
    ) -> UUID {
        let payload = [
            status.rawValue,
            startedAt.ISO8601Format(),
            runningSince?.ISO8601Format() ?? "nil",
            String(leftAccumulated.bitPattern),
            String(rightAccumulated.bitPattern)
        ].joined(separator: "|")

        let first = fnv1a64(payload.utf8)
        let second = fnv1a64((payload + "|feedtracker.legacy").utf8)
        var bytes = [UInt8](repeating: 0, count: 16)

        for index in 0..<8 {
            bytes[index] = UInt8((first >> UInt64((7 - index) * 8)) & 0xFF)
            bytes[8 + index] = UInt8((second >> UInt64((7 - index) * 8)) & 0xFF)
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func fnv1a64<C: Collection>(_ bytes: C) -> UInt64 where C.Element == UInt8 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}

public final class SessionTimerEngine {
    private let now: @Sendable () -> Date

    private var sessionID: UUID?
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
            sessionID = UUID()
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
            id: sessionID ?? UUID(),
            startedAt: startedAt ?? current,
            endedAt: endedAt,
            leftDuration: leftAccumulated,
            rightDuration: rightAccumulated,
            note: note,
            status: .completed
        )
    }

    public func recoveryStateForPersistence() -> SessionTimerRecoveryState? {
        guard let startedAt, let sessionID else {
            return nil
        }

        switch state {
        case .idle, .ended:
            return nil

        case .running(let side):
            let status: SessionTimerRecoveryStatus = side == .left ? .runningLeft : .runningRight
            return SessionTimerRecoveryState(
                sessionID: sessionID,
                status: status,
                startedAt: startedAt,
                runningSince: runningSince,
                leftAccumulated: leftAccumulated,
                rightAccumulated: rightAccumulated
            )

        case .paused(let side):
            let status: SessionTimerRecoveryStatus = side == .left ? .pausedLeft : .pausedRight
            return SessionTimerRecoveryState(
                sessionID: sessionID,
                status: status,
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

    public func reset() {
        sessionID = nil
        state = .idle
        startedAt = nil
        endedAt = nil
        runningSide = nil
        runningSince = nil
        leftAccumulated = 0
        rightAccumulated = 0
    }

    public func restore(from recoveryState: SessionTimerRecoveryState) throws {
        guard recoveryState.leftAccumulated >= 0, recoveryState.rightAccumulated >= 0 else {
            throw SessionTimerEngineError.invalidRecoveryState
        }

        self.sessionID = recoveryState.sessionID
        self.startedAt = recoveryState.startedAt
        self.endedAt = nil
        self.leftAccumulated = recoveryState.leftAccumulated
        self.rightAccumulated = recoveryState.rightAccumulated

        switch recoveryState.status {
        case .runningLeft:
            runningSide = .left
            runningSince = recoveryState.runningSince ?? recoveryState.startedAt
            state = .running(side: .left)

        case .runningRight:
            runningSide = .right
            runningSince = recoveryState.runningSince ?? recoveryState.startedAt
            state = .running(side: .right)

        case .pausedLeft:
            runningSide = nil
            runningSince = nil
            state = .paused(side: .left)

        case .pausedRight:
            runningSide = nil
            runningSince = nil
            state = .paused(side: .right)

        case .stopped:
            runningSide = nil
            runningSince = nil
            state = .stopped
        }
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
            sessionID: sessionID,
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
