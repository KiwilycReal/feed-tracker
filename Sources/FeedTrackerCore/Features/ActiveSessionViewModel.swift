import Combine
import Foundation

public struct ActiveSessionDisplayState: Equatable, Sendable {
    public let activeSide: FeedingSide?
    public let leftElapsed: TimeInterval
    public let rightElapsed: TimeInterval
    public let totalElapsed: TimeInterval
    public let displayedLeftElapsed: TimeInterval
    public let displayedRightElapsed: TimeInterval
    public let displayedTotalElapsed: TimeInterval
    public let state: SessionTimerState
    public let capturedAt: Date

    public init(snapshot: SessionTimerSnapshot) {
        let displayValues = SessionTimerDisplayProjection.values(snapshot: snapshot)

        self.activeSide = snapshot.activeSide
        self.leftElapsed = snapshot.leftElapsed
        self.rightElapsed = snapshot.rightElapsed
        self.totalElapsed = snapshot.totalElapsed
        self.displayedLeftElapsed = displayValues.leftElapsed
        self.displayedRightElapsed = displayValues.rightElapsed
        self.displayedTotalElapsed = displayValues.totalElapsed
        self.state = snapshot.state
        self.capturedAt = snapshot.capturedAt
    }

    public func projectedDisplay(at date: Date) -> SessionTimerDisplayValues {
        SessionTimerDisplayProjection.values(
            state: LiveActivityState(
                activeSide: activeSide,
                leftElapsed: displayedLeftElapsed,
                rightElapsed: displayedRightElapsed,
                totalElapsed: displayedTotalElapsed,
                startedAt: nil,
                endedAt: nil,
                timerStatus: LiveActivityTimerStatus(state: state)
            ),
            capturedAt: capturedAt,
            now: date
        )
    }

    public static let idle = ActiveSessionDisplayState(
        snapshot: SessionTimerSnapshot(
            state: .idle,
            activeSide: nil,
            leftElapsed: 0,
            rightElapsed: 0,
            totalElapsed: 0,
            startedAt: nil,
            endedAt: nil,
            capturedAt: Date(timeIntervalSince1970: 0)
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

    private var pendingSessionPersistTask: Task<Void, Never>?
    private var lastSyncedLiveActivityToken: String?

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
        let snapshot = engine.snapshot(at: date)
        displayState = displayState(for: snapshot)
        syncLiveActivity(snapshot: snapshot, source: "active_session_vm.refresh")
    }

    public func reloadFromRecoveryStore(source: String) async {
        await drainPendingSessionPersistTask(cancel: true)

        guard let recoveryStore else {
            refresh()
            syncLiveActivity(source: source)
            return
        }

        do {
            if let recoveryState = try recoveryStore.load(strategy: .primaryStoreAuthoritativeWhenMissing) {
                try engine.restore(from: recoveryState)
                persistActiveSessionRecord(snapshot: engine.snapshot(), context: source)
                diagnostics?.record(
                    category: "session_recovery",
                    action: "reload_external_sync",
                    metadata: ["status": recoveryState.status.rawValue],
                    source: "active_session_vm"
                )
            } else {
                try recoveryStore.clear()
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
            await drainPendingSessionPersistTask()
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
            persistActiveSessionRecord(snapshot: engine.snapshot(), context: "session.restore")
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
        let snapshot = engine.snapshot()
        let recoveryState = engine.recoveryStateForPersistence()

        if recoveryState != nil {
            persistActiveSessionRecord(snapshot: snapshot, context: context)
        }

        guard let recoveryStore else {
            return
        }

        do {
            if let recoveryState {
                try recoveryStore.save(recoveryState)
                let marker = FeedTrackerSharedStorage.writeExternalSyncMarker()
                FeedTrackerSharedStorage.writeExternalSyncContext(
                    marker: marker,
                    source: "active_session_vm",
                    reason: context,
                    action: recoveryState.status.rawValue
                )
                diagnostics?.record(
                    category: "session_recovery",
                    action: "persist",
                    metadata: ["status": recoveryState.status.rawValue],
                    source: "active_session_vm"
                )
            } else {
                try recoveryStore.clear()
                let marker = FeedTrackerSharedStorage.writeExternalSyncMarker()
                FeedTrackerSharedStorage.writeExternalSyncContext(
                    marker: marker,
                    source: "active_session_vm",
                    reason: context,
                    action: "clear"
                )
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

    private func persistActiveSessionRecord(snapshot: SessionTimerSnapshot, context: String) {
        guard let session = try? snapshot.persistedSession() else {
            return
        }

        let previousTask = pendingSessionPersistTask
        pendingSessionPersistTask = Task {
            await previousTask?.value

            guard Task.isCancelled == false else {
                return
            }

            do {
                try await repository.upsert(session)
                diagnostics?.record(
                    category: "persistence",
                    action: "persist_active_session",
                    metadata: [
                        "context": context,
                        "sessionID": session.id.uuidString,
                        "status": session.status.rawValue
                    ],
                    source: "active_session_vm"
                )
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                diagnostics?.recordError(
                    context: "persistence.persist_active_session",
                    message: error.localizedDescription,
                    metadata: [
                        "eventContext": context,
                        "sessionID": session.id.uuidString
                    ],
                    source: "active_session_vm"
                )
            }
        }
    }

    private func drainPendingSessionPersistTask(cancel: Bool = false) async {
        let task = pendingSessionPersistTask
        if cancel {
            pendingSessionPersistTask = nil
            task?.cancel()
        }
        await task?.value
    }

}

private extension ActiveSessionViewModel {
    func displayState(for snapshot: SessionTimerSnapshot) -> ActiveSessionDisplayState {
        if case .ended = snapshot.state {
            return .idle
        }

        return ActiveSessionDisplayState(snapshot: snapshot)
    }

    func syncLiveActivity(source: String) {
        syncLiveActivity(clockState: engine.clockState(), source: source)
    }

    func syncLiveActivity(snapshot: SessionTimerSnapshot, source: String) {
        syncLiveActivity(clockState: engine.clockState(at: snapshot.capturedAt), source: source)
    }

    func syncLiveActivity(clockState: SessionTimerClockState, source: String) {
        let syncToken = liveActivitySyncToken(for: clockState)
        guard syncToken != lastSyncedLiveActivityToken else {
            return
        }

        liveActivityCoordinator?.reconcile(clockState: clockState, source: source)
        lastSyncedLiveActivityToken = syncToken
    }

    func liveActivitySyncToken(for clockState: SessionTimerClockState) -> String {
        clockState.liveActivitySyncToken
    }

    func sessionStateLabel(_ state: SessionTimerState) -> String {
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
