import Combine
import Foundation

public struct ActiveSessionDisplayState: Equatable, Sendable {
    public let activeSide: FeedingSide?
    public let leftElapsed: TimeInterval
    public let rightElapsed: TimeInterval
    public let totalElapsed: TimeInterval
    public let state: SessionTimerState

    public init(snapshot: SessionTimerSnapshot) {
        self.activeSide = snapshot.activeSide
        self.leftElapsed = snapshot.leftElapsed
        self.rightElapsed = snapshot.rightElapsed
        self.totalElapsed = snapshot.totalElapsed
        self.state = snapshot.state
    }

    public static let idle = ActiveSessionDisplayState(
        snapshot: SessionTimerSnapshot(
            state: .idle,
            activeSide: nil,
            leftElapsed: 0,
            rightElapsed: 0,
            totalElapsed: 0,
            startedAt: nil,
            endedAt: nil
        )
    )
}

@MainActor
public final class ActiveSessionViewModel: ObservableObject {
    private let engine: SessionTimerEngine
    private let repository: any FeedingSessionRepository
    private let diagnostics: (any DiagnosticsLogging)?
    private let recoveryStore: (any ActiveSessionRecoveryStoring)?
    private let liveActivityCoordinator: (any LiveActivityLifecycleCoordinating)?

    @Published public private(set) var displayState: ActiveSessionDisplayState

    public init(
        engine: SessionTimerEngine,
        repository: any FeedingSessionRepository,
        diagnostics: (any DiagnosticsLogging)? = nil,
        recoveryStore: (any ActiveSessionRecoveryStoring)? = nil,
        liveActivityCoordinator: (any LiveActivityLifecycleCoordinating)? = nil
    ) {
        self.engine = engine
        self.repository = repository
        self.diagnostics = diagnostics
        self.recoveryStore = recoveryStore
        self.liveActivityCoordinator = liveActivityCoordinator
        self.displayState = .idle

        restoreRecoveredState()
        self.displayState = displayState(for: engine.snapshot())
        syncLiveActivity(source: "active_session_vm.init")
    }

    public func refresh(at date: Date? = nil) {
        displayState = displayState(for: engine.snapshot(at: date))
    }

    public func reloadFromRecoveryStore(source: String) {
        guard let recoveryStore else {
            refresh()
            syncLiveActivity(source: source)
            return
        }

        do {
            if let recoveryState = try recoveryStore.load(strategy: .primaryStoreAuthoritativeWhenMissing) {
                try engine.restore(from: recoveryState)
                diagnostics?.record(
                    category: "session_recovery",
                    action: "reload_external_sync",
                    metadata: ["status": recoveryState.status.rawValue],
                    source: "active_session_vm"
                )
            } else {
                engine.reset()
                diagnostics?.record(
                    category: "session_recovery",
                    action: "reload_external_sync_reset",
                    metadata: [:],
                    source: "active_session_vm"
                )
            }

            refresh()
            syncLiveActivity(source: source)
        } catch {
            diagnostics?.recordError(
                context: "session_recovery.reload_external_sync",
                message: error.localizedDescription,
                metadata: [:],
                source: "active_session_vm"
            )
        }
    }

    public func start(side: FeedingSide) throws {
        do {
            try engine.start(side)
            refresh()
            persistRecoveryState(context: "session.start")
            syncLiveActivity(source: "active_session_vm.start")
            diagnostics?.record(
                category: "session",
                action: "start",
                metadata: [
                    "side": side.rawValue,
                    "state": sessionStateLabel(displayState.state)
                ],
                source: "active_session_vm"
            )
        } catch {
            diagnostics?.recordError(
                context: "session.start",
                message: error.localizedDescription,
                metadata: ["side": side.rawValue],
                source: "active_session_vm"
            )
            throw error
        }
    }

    public func switchSide(to side: FeedingSide) throws {
        do {
            try engine.switch(to: side)
            refresh()
            persistRecoveryState(context: "session.switch_side")
            syncLiveActivity(source: "active_session_vm.switch_side")
            diagnostics?.record(
                category: "session",
                action: "switch_side",
                metadata: [
                    "side": side.rawValue,
                    "state": sessionStateLabel(displayState.state)
                ],
                source: "active_session_vm"
            )
        } catch {
            diagnostics?.recordError(
                context: "session.switch_side",
                message: error.localizedDescription,
                metadata: ["side": side.rawValue],
                source: "active_session_vm"
            )
            throw error
        }
    }

    public func pause() throws {
        do {
            try engine.pause()
            refresh()
            persistRecoveryState(context: "session.pause")
            syncLiveActivity(source: "active_session_vm.pause")
            diagnostics?.record(
                category: "session",
                action: "pause",
                metadata: ["state": sessionStateLabel(displayState.state)],
                source: "active_session_vm"
            )
        } catch {
            diagnostics?.recordError(
                context: "session.pause",
                message: error.localizedDescription,
                metadata: [:],
                source: "active_session_vm"
            )
            throw error
        }
    }

    public func resume() throws {
        do {
            try engine.resume()
            refresh()
            persistRecoveryState(context: "session.resume")
            syncLiveActivity(source: "active_session_vm.resume")
            diagnostics?.record(
                category: "session",
                action: "resume",
                metadata: ["state": sessionStateLabel(displayState.state)],
                source: "active_session_vm"
            )
        } catch {
            diagnostics?.recordError(
                context: "session.resume",
                message: error.localizedDescription,
                metadata: [:],
                source: "active_session_vm"
            )
            throw error
        }
    }

    public func stopCurrentSide() throws {
        do {
            try engine.stopCurrentSide()
            refresh()
            persistRecoveryState(context: "session.stop_current_side")
            syncLiveActivity(source: "active_session_vm.stop_current_side")
            diagnostics?.record(
                category: "session",
                action: "stop_current_side",
                metadata: ["state": sessionStateLabel(displayState.state)],
                source: "active_session_vm"
            )
        } catch {
            diagnostics?.recordError(
                context: "session.stop_current_side",
                message: error.localizedDescription,
                metadata: [:],
                source: "active_session_vm"
            )
            throw error
        }
    }

    @discardableResult
    public func endSession(note: String? = nil) async throws -> FeedingSession {
        do {
            let session = try engine.endSession(note: note)
            try await repository.upsert(session)
            refresh()
            persistRecoveryState(context: "session.end")
            syncLiveActivity(source: "active_session_vm.end")
            diagnostics?.record(
                category: "persistence",
                action: "save_completed_session",
                metadata: [
                    "sessionID": session.id.uuidString,
                    "totalDuration": "\(Int(session.totalDuration.rounded()))"
                ],
                source: "active_session_vm"
            )
            return session
        } catch {
            diagnostics?.recordError(
                context: "session.end_and_persist",
                message: error.localizedDescription,
                metadata: [:],
                source: "active_session_vm"
            )
            throw error
        }
    }

    private func restoreRecoveredState() {
        guard let recoveryStore else {
            return
        }

        do {
            guard let recoveryState = try recoveryStore.load() else {
                return
            }

            try engine.restore(from: recoveryState)
            diagnostics?.record(
                category: "session_recovery",
                action: "restore_success",
                metadata: ["status": recoveryState.status.rawValue],
                source: "active_session_vm"
            )
        } catch {
            do {
                try recoveryStore.clear()
            } catch {
                diagnostics?.recordError(
                    context: "session_recovery.clear_after_failed_restore",
                    message: error.localizedDescription,
                    metadata: [:],
                    source: "active_session_vm"
                )
            }

            diagnostics?.recordError(
                context: "session_recovery.restore",
                message: error.localizedDescription,
                metadata: [:],
                source: "active_session_vm"
            )
        }
    }

    private func persistRecoveryState(context: String) {
        guard let recoveryStore else {
            return
        }

        do {
            if let state = engine.recoveryStateForPersistence() {
                try recoveryStore.save(state)
                diagnostics?.record(
                    category: "session_recovery",
                    action: "persist",
                    metadata: ["status": state.status.rawValue],
                    source: "active_session_vm"
                )
            } else {
                try recoveryStore.clear()
                diagnostics?.record(
                    category: "session_recovery",
                    action: "clear",
                    metadata: ["context": context],
                    source: "active_session_vm"
                )
            }
        } catch {
            diagnostics?.recordError(
                context: "session_recovery.persist",
                message: error.localizedDescription,
                metadata: ["eventContext": context],
                source: "active_session_vm"
            )
        }
    }

    private func displayState(for snapshot: SessionTimerSnapshot) -> ActiveSessionDisplayState {
        if case .ended = snapshot.state {
            return .idle
        }

        return ActiveSessionDisplayState(snapshot: snapshot)
    }

    private func syncLiveActivity(source: String) {
        liveActivityCoordinator?.reconcile(snapshot: engine.snapshot(), source: source)
    }

    private func sessionStateLabel(_ state: SessionTimerState) -> String {
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
