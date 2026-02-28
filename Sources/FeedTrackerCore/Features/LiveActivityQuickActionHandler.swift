import Foundation

public enum LiveActivityQuickAction: String, CaseIterable, Equatable, Sendable, Codable {
    case startLeft = "start_left"
    case startRight = "start_right"
    case endSession = "end_session"
}

public enum LiveActivityQuickActionError: Error, Equatable, Sendable {
    case cannotStartAfterSessionEnded
    case cannotEndWithoutStartedSession
    case unsupportedDeepLink
}

@MainActor
public final class LiveActivityQuickActionHandler {
    private let engine: SessionTimerEngine
    private let repository: any FeedingSessionRepository
    private let router: any LiveActivityQuickActionRouting
    private let diagnostics: (any DiagnosticsLogging)?

    public init(
        engine: SessionTimerEngine,
        repository: any FeedingSessionRepository,
        router: any LiveActivityQuickActionRouting = LiveActivityQuickActionRouter(),
        diagnostics: (any DiagnosticsLogging)? = nil
    ) {
        self.engine = engine
        self.repository = repository
        self.router = router
        self.diagnostics = diagnostics
    }

    @discardableResult
    public func handle(_ action: LiveActivityQuickAction, note: String? = nil) async throws -> FeedingSession? {
        do {
            switch action {
            case .startLeft:
                try startOrSwitch(to: .left)
                diagnostics?.record(
                    category: "live_activity",
                    action: "start_left",
                    metadata: [:],
                    source: "live_activity_handler"
                )
                return nil
            case .startRight:
                try startOrSwitch(to: .right)
                diagnostics?.record(
                    category: "live_activity",
                    action: "start_right",
                    metadata: [:],
                    source: "live_activity_handler"
                )
                return nil
            case .endSession:
                let session = try engine.endSession(note: note)
                try await repository.upsert(session)
                diagnostics?.record(
                    category: "live_activity",
                    action: "end_session",
                    metadata: ["sessionID": session.id.uuidString],
                    source: "live_activity_handler"
                )
                return session
            }
        } catch SessionTimerEngineError.sessionNotStarted {
            diagnostics?.recordError(
                context: "live_activity.end_session",
                message: SessionTimerEngineError.sessionNotStarted.localizedDescription,
                metadata: [:],
                source: "live_activity_handler"
            )
            throw LiveActivityQuickActionError.cannotEndWithoutStartedSession
        } catch {
            diagnostics?.recordError(
                context: "live_activity.handle",
                message: error.localizedDescription,
                metadata: ["action": action.rawValue],
                source: "live_activity_handler"
            )
            throw error
        }
    }

    @discardableResult
    public func handle(url: URL, note: String? = nil) async throws -> FeedingSession? {
        guard let action = router.action(from: url) else {
            diagnostics?.recordError(
                context: "live_activity.handle_url",
                message: LiveActivityQuickActionError.unsupportedDeepLink.localizedDescription,
                metadata: ["url": url.absoluteString],
                source: "live_activity_handler"
            )
            throw LiveActivityQuickActionError.unsupportedDeepLink
        }

        return try await handle(action, note: note)
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
