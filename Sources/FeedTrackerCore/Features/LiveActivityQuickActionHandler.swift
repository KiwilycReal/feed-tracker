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

public enum LiveActivityQuickActionPersistenceMode: String, Equatable, Sendable {
    case immediate
    case deferred
}

@MainActor
public final class LiveActivityQuickActionHandler {
    private let engine: SessionTimerEngine
    private let repository: any FeedingSessionRepository
    private let router: any LiveActivityQuickActionRouting
    private let diagnostics: (any DiagnosticsLogging)?

    private var isActionInFlight = false
    private var pendingPersistenceTask: Task<Void, Never>?

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
    public func handle(
        _ action: LiveActivityQuickAction,
        note: String? = nil,
        persistenceMode: LiveActivityQuickActionPersistenceMode = .immediate
    ) async throws -> FeedingSession? {
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

        let mutationStartedAt = DispatchTime.now().uptimeNanoseconds

        do {
            switch action {
            case .switchSide:
                let didMutate = try handleSwitchSide()
                try await finalizeMutation(
                    action: action,
                    didMutate: didMutate,
                    persistenceMode: persistenceMode,
                    mutationStartedAt: mutationStartedAt
                )
                diagnostics?.record(
                    category: "live_activity",
                    action: "switch_side",
                    metadata: ["state": stateLabel(engine.snapshot().state)],
                    source: "live_activity_handler"
                )
                return nil

            case .pauseSession:
                let didMutate = try handlePause()
                try await finalizeMutation(
                    action: action,
                    didMutate: didMutate,
                    persistenceMode: persistenceMode,
                    mutationStartedAt: mutationStartedAt
                )
                diagnostics?.record(
                    category: "live_activity",
                    action: "pause_session",
                    metadata: ["state": stateLabel(engine.snapshot().state)],
                    source: "live_activity_handler"
                )
                return nil

            case .terminateSession:
                return try await handleTerminate(
                    note: note,
                    persistenceMode: persistenceMode,
                    mutationStartedAt: mutationStartedAt,
                    action: action
                )

            case .startLeft:
                let didMutate = try startOrSwitch(to: .left)
                try await finalizeMutation(
                    action: action,
                    didMutate: didMutate,
                    persistenceMode: persistenceMode,
                    mutationStartedAt: mutationStartedAt
                )
                diagnostics?.record(
                    category: "live_activity",
                    action: "start_left",
                    metadata: ["state": stateLabel(engine.snapshot().state)],
                    source: "live_activity_handler"
                )
                return nil

            case .startRight:
                let didMutate = try startOrSwitch(to: .right)
                try await finalizeMutation(
                    action: action,
                    didMutate: didMutate,
                    persistenceMode: persistenceMode,
                    mutationStartedAt: mutationStartedAt
                )
                diagnostics?.record(
                    category: "live_activity",
                    action: "start_right",
                    metadata: ["state": stateLabel(engine.snapshot().state)],
                    source: "live_activity_handler"
                )
                return nil

            case .endSession:
                return try await handleTerminate(
                    note: note,
                    persistenceMode: persistenceMode,
                    mutationStartedAt: mutationStartedAt,
                    action: action
                )
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
    public func handle(
        url: URL,
        note: String? = nil,
        persistenceMode: LiveActivityQuickActionPersistenceMode = .immediate
    ) async throws -> FeedingSession? {
        guard let action = router.action(from: url) else {
            diagnostics?.recordError(
                context: "live_activity.handle_url",
                message: LiveActivityQuickActionError.unsupportedDeepLink.localizedDescription,
                metadata: ["url": url.absoluteString],
                source: "live_activity_handler"
            )
            throw LiveActivityQuickActionError.unsupportedDeepLink
        }

        return try await handle(action, note: note, persistenceMode: persistenceMode)
    }

    public func currentState(at date: Date? = nil) -> LiveActivityState {
        LiveActivityState(snapshot: engine.snapshot(at: date))
    }

    public func currentClockState(at date: Date? = nil) -> SessionTimerClockState {
        engine.clockState(at: date)
    }

    public func flushPendingPersistence() async {
        await pendingPersistenceTask?.value
    }

    public func pendingPersistenceDrainer() -> Task<Void, Never>? {
        pendingPersistenceTask
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
    private func handleTerminate(
        note: String?,
        persistenceMode: LiveActivityQuickActionPersistenceMode,
        mutationStartedAt: UInt64,
        action: LiveActivityQuickAction
    ) async throws -> FeedingSession? {
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
        recordMutationLatency(
            action: action,
            didMutate: true,
            persistenceMode: persistenceMode,
            mutationStartedAt: mutationStartedAt
        )
        schedulePersistence(session: session, action: action)
        if persistenceMode == .immediate {
            await flushPendingPersistence()
        }
        diagnostics?.record(
            category: "live_activity",
            action: "terminate_session",
            metadata: ["sessionID": session.id.uuidString],
            source: "live_activity_handler"
        )
        return session
    }

    private func startOrSwitch(to requestedSide: FeedingSide) throws -> Bool {
        let state = engine.snapshot().state

        switch state {
        case .idle, .stopped:
            try engine.start(requestedSide)
            return true

        case .running(let activeSide):
            guard activeSide != requestedSide else {
                return false
            }
            try engine.switch(to: requestedSide)
            return true

        case .paused(let pausedSide):
            try engine.resume()
            guard pausedSide != requestedSide else {
                return true
            }
            try engine.switch(to: requestedSide)
            return true

        case .ended:
            throw LiveActivityQuickActionError.cannotStartAfterSessionEnded
        }
    }

    private func finalizeMutation(
        action: LiveActivityQuickAction,
        didMutate: Bool,
        persistenceMode: LiveActivityQuickActionPersistenceMode,
        mutationStartedAt: UInt64
    ) async throws {
        recordMutationLatency(
            action: action,
            didMutate: didMutate,
            persistenceMode: persistenceMode,
            mutationStartedAt: mutationStartedAt
        )

        guard didMutate,
              let session = try engine.snapshot().persistedSession() else {
            return
        }

        schedulePersistence(session: session, action: action)
        if persistenceMode == .immediate {
            await flushPendingPersistence()
        }
    }

    private func schedulePersistence(session: FeedingSession, action: LiveActivityQuickAction) {
        let queueEnqueuedAt = DispatchTime.now().uptimeNanoseconds
        let previousTask = pendingPersistenceTask
        let repository = self.repository
        let diagnostics = self.diagnostics

        pendingPersistenceTask = Task(priority: .userInitiated) {
            await previousTask?.value

            let persistStartedAt = DispatchTime.now().uptimeNanoseconds
            do {
                try await repository.upsert(session)
                diagnostics?.record(
                    category: "persistence",
                    action: "persist_active_session",
                    metadata: [
                        "action": action.rawValue,
                        "sessionID": session.id.uuidString,
                        "status": session.status.rawValue,
                        "queueWaitMs": millisecondsString(since: queueEnqueuedAt, until: persistStartedAt),
                        "persistMs": millisecondsString(since: persistStartedAt)
                    ],
                    source: "live_activity_handler"
                )
            } catch {
                diagnostics?.recordError(
                    context: "live_activity.persist_session",
                    message: error.localizedDescription,
                    metadata: [
                        "action": action.rawValue,
                        "sessionID": session.id.uuidString,
                        "status": session.status.rawValue
                    ],
                    source: "live_activity_handler"
                )
            }
        }
    }

    private func recordMutationLatency(
        action: LiveActivityQuickAction,
        didMutate: Bool,
        persistenceMode: LiveActivityQuickActionPersistenceMode,
        mutationStartedAt: UInt64
    ) {
        diagnostics?.record(
            category: "live_activity_latency",
            action: "mutation_complete",
            metadata: [
                "action": action.rawValue,
                "didMutate": didMutate ? "true" : "false",
                "persistenceMode": persistenceMode.rawValue,
                "mutationMs": millisecondsString(since: mutationStartedAt),
                "state": stateLabel(engine.snapshot().state)
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

private func millisecondsString(since start: UInt64, until end: UInt64? = nil) -> String {
    let finish = end ?? DispatchTime.now().uptimeNanoseconds
    let duration = Double(finish &- start) / 1_000_000
    return String(format: "%.1f", duration)
}
