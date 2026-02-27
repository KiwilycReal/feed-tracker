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

    @Published public private(set) var displayState: ActiveSessionDisplayState

    public init(
        engine: SessionTimerEngine,
        repository: any FeedingSessionRepository
    ) {
        self.engine = engine
        self.repository = repository
        self.displayState = ActiveSessionDisplayState(snapshot: engine.snapshot())
    }

    public func refresh(at date: Date? = nil) {
        displayState = ActiveSessionDisplayState(snapshot: engine.snapshot(at: date))
    }

    public func start(side: FeedingSide) throws {
        try engine.start(side)
        refresh()
    }

    public func switchSide(to side: FeedingSide) throws {
        try engine.switch(to: side)
        refresh()
    }

    public func pause() throws {
        try engine.pause()
        refresh()
    }

    public func resume() throws {
        try engine.resume()
        refresh()
    }

    public func stopCurrentSide() throws {
        try engine.stopCurrentSide()
        refresh()
    }

    @discardableResult
    public func endSession(note: String? = nil) async throws -> FeedingSession {
        let session = try engine.endSession(note: note)
        try await repository.upsert(session)
        refresh()
        return session
    }
}
