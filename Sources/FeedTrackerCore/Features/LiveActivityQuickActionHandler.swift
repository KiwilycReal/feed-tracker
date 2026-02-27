import Foundation

public enum LiveActivityQuickAction: String, CaseIterable, Equatable, Sendable, Codable {
    case startLeft = "start_left"
    case startRight = "start_right"
    case endSession = "end_session"
}

public enum LiveActivityQuickActionError: Error, Equatable, Sendable {
    case cannotStartAfterSessionEnded
    case cannotEndWithoutStartedSession
}

@MainActor
public final class LiveActivityQuickActionHandler {
    private let engine: SessionTimerEngine
    private let repository: any FeedingSessionRepository

    public init(
        engine: SessionTimerEngine,
        repository: any FeedingSessionRepository
    ) {
        self.engine = engine
        self.repository = repository
    }

    @discardableResult
    public func handle(_ action: LiveActivityQuickAction, note: String? = nil) async throws -> FeedingSession? {
        switch action {
        case .startLeft:
            try startOrSwitch(to: .left)
            return nil
        case .startRight:
            try startOrSwitch(to: .right)
            return nil
        case .endSession:
            do {
                let session = try engine.endSession(note: note)
                try await repository.upsert(session)
                return session
            } catch SessionTimerEngineError.sessionNotStarted {
                throw LiveActivityQuickActionError.cannotEndWithoutStartedSession
            }
        }
    }

    public func currentState(at date: Date? = nil) -> LiveActivityState {
        LiveActivityState(snapshot: engine.snapshot(at: date))
    }

    private func startOrSwitch(to requestedSide: FeedingSide) throws {
        let state = engine.snapshot().state

        switch state {
        case .idle, .stopped:
            try engine.start(requestedSide)

        case .running(let activeSide):
            guard activeSide != requestedSide else { return }
            try engine.switch(to: requestedSide)

        case .paused(let pausedSide):
            try engine.resume()
            guard pausedSide != requestedSide else { return }
            try engine.switch(to: requestedSide)

        case .ended:
            throw LiveActivityQuickActionError.cannotStartAfterSessionEnded
        }
    }
}
