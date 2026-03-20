import Foundation

public enum LiveActivityQuickAction: String, CaseIterable, Equatable, Sendable, Codable {
    // Release r2026.03.01 required surface actions
    case switchSide = "switch_side"
    case pauseSession = "pause_session"
    case terminateSession = "terminate_session"

    // Backward-compatible actions used by existing deep links/tests
    case startLeft = "start_left"
    case startRight = "start_right"
    case endSession = "end_session"
}

public enum LiveActivityQuickActionError: Error, Equatable, Sendable {
    case cannotStartAfterSessionEnded
    case cannotSwitchWithoutStartedSession
    case unsupportedDeepLink
}

@MainActor
public final class LiveActivityQuickActionHandler {
    private let engine: SessionTimerEngine
    private let repository: any FeedingSessionRepository
    private let router: any LiveActivityQuickActionRouting
    private let diagnostics: (any DiagnosticsLogging)?

    private var isActionInFlight = false

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
        guard isActionInFlight == false else {
            diagnostics?.record(
                category: "live_activity",
                action: "guard_in_flight_skip",
                metadata: ["requestedAction": action.rawValue],
                source: "live_activity_handler"
            )
            return nil
        }

        isActionInFlight = true
        defer { isActionInFlight = false }

        do {
            switch action {
            case .switchSide:
                let didMutate = try handleSwitchSide()
                if didMutate {
                    try await persistCurrentSessionState(action: action)
                }
                diagnostics?.record(
                    category: "live_activity",
                    action: "switch_side",
                    metadata: ["state": stateLabel(engine.snapshot().state)],
                    source: "live_activity_handler"
                )
                return nil

            case .pauseSession:
                let didMutate = try handlePause()
                if didMutate {
                    try await persistCurrentSessionState(action: action)
                }
                diagnostics?.record(
                    category: "live_activity",
                    action: "pause_session",
                    metadata: ["state": stateLabel(engine.snapshot().state)],
                    source: "live_activity_handler"
                )
                return nil

            case .terminateSession:
                return try await handleTerminate(note: note)

            case .startLeft:
                try startOrSwitch(to: .left)
                try await persistCurrentSessionState(action: action)
                diagnostics?.record(
                    category: "live_activity",
                    action: "start_left",
                    metadata: ["state": stateLabel(engine.snapshot().state)],
                    source: "live_activity_handler"
                )
                return nil

            case .startRight:
                try startOrSwitch(to: .right)
                try await persistCurrentSessionState(action: action)
                diagnostics?.record(
                    category: "live_activity",
                    action: "start_right",
                    metadata: ["state": stateLabel(engine.snapshot().state)],
                    source: "live_activity_handler"
                )
                return nil

            case .endSession:
                return try await handleTerminate(note: note)
            }
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

    private func handleSwitchSide() throws -> Bool {
        let state = engine.snapshot().state

        switch state {
        case .running(let active):
            try engine.switch(to: active == .left ? .right : .left)
            return true

        case .paused(let paused):
            try engine.resume()
            try engine.switch(to: paused == .left ? .right : .left)
            return true

        case .stopped:
            try engine.start(.left)
            return true

        case .idle:
            throw LiveActivityQuickActionError.cannotSwitchWithoutStartedSession

        case .ended:
            diagnostics?.record(
                category: "live_activity",
                action: "switch_side_ignored_terminal",
                metadata: [:],
                source: "live_activity_handler"
            )
            return false
        }
    }

    private func handlePause() throws -> Bool {
        let state = engine.snapshot().state

        switch state {
        case .running:
            try engine.pause()
            return true

        case .paused:
            try engine.resume()
            return true

        case .idle, .stopped, .ended:
            diagnostics?.record(
                category: "live_activity",
                action: "pause_toggle_ignored",
                metadata: ["state": stateLabel(state)],
                source: "live_activity_handler"
            )
            return false
        }
    }

    @discardableResult
    private func handleTerminate(note: String?) async throws -> FeedingSession? {
        let state = engine.snapshot().state
        guard state != .idle, state != .ended else {
            diagnostics?.record(
                category: "live_activity",
                action: "terminate_ignored",
                metadata: ["state": stateLabel(state)],
                source: "live_activity_handler"
            )
            return nil
        }

        let session = try engine.endSession(note: note)
        try await repository.upsert(session)
        diagnostics?.record(
            category: "live_activity",
            action: "terminate_session",
            metadata: ["sessionID": session.id.uuidString],
            source: "live_activity_handler"
        )
        return session
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

    private func persistCurrentSessionState(action: LiveActivityQuickAction) async throws {
        let snapshot = engine.snapshot()
        guard let session = try snapshot.persistedSession() else {
            return
        }

        try await repository.upsert(session)
        diagnostics?.record(
            category: "persistence",
            action: "persist_active_session",
            metadata: [
                "action": action.rawValue,
                "sessionID": session.id.uuidString,
                "status": session.status.rawValue
            ],
            source: "live_activity_handler"
        )
    }

    private func stateLabel(_ state: SessionTimerState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .running(let side):
            return "running_\(side.rawValue)"
        case .paused(let side):
            return "paused_\(side.rawValue)"
        case .stopped:
            return "stopped"
        case .ended:
            return "ended"
        }
    }
}
