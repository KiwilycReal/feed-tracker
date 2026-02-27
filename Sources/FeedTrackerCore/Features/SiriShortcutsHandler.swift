import Foundation

public enum SiriShortcutStartOption: String, CaseIterable, Equatable, Sendable, Codable {
    case `default`
    case left
    case right

    func resolvedSide(defaultSide: FeedingSide) -> FeedingSide {
        switch self {
        case .default:
            return defaultSide
        case .left:
            return .left
        case .right:
            return .right
        }
    }
}

public enum SiriShortcutError: Error, Equatable, Sendable {
    case cannotStartAfterSessionEnded
}

public struct SiriShortcutStatus: Equatable, Sendable {
    public let state: SessionTimerState
    public let activeSide: FeedingSide?
    public let totalElapsed: TimeInterval
    public let phrase: String
}

@MainActor
public final class SiriShortcutsHandler {
    private let engine: SessionTimerEngine
    public let defaultStartSide: FeedingSide

    public init(
        engine: SessionTimerEngine,
        defaultStartSide: FeedingSide = .left
    ) {
        self.engine = engine
        self.defaultStartSide = defaultStartSide
    }

    public func startTracking(sideOption: SiriShortcutStartOption = .default) throws -> SiriShortcutStatus {
        let requestedSide = sideOption.resolvedSide(defaultSide: defaultStartSide)
        let state = engine.snapshot().state

        switch state {
        case .idle, .stopped:
            try engine.start(requestedSide)

        case .running(let activeSide):
            guard activeSide != requestedSide else { break }
            try engine.switch(to: requestedSide)

        case .paused(let pausedSide):
            try engine.resume()
            guard pausedSide != requestedSide else { break }
            try engine.switch(to: requestedSide)

        case .ended:
            throw SiriShortcutError.cannotStartAfterSessionEnded
        }

        return readCurrentStatus()
    }

    public func readCurrentStatus(at date: Date? = nil) -> SiriShortcutStatus {
        let snapshot = engine.snapshot(at: date)
        return SiriShortcutStatus(
            state: snapshot.state,
            activeSide: snapshot.activeSide,
            totalElapsed: snapshot.totalElapsed,
            phrase: phrase(for: snapshot)
        )
    }

    private func phrase(for snapshot: SessionTimerSnapshot) -> String {
        let total = SessionPresentation.durationText(snapshot.totalElapsed)

        switch snapshot.state {
        case .idle:
            return "No active feeding session. Total elapsed \(total)."
        case .running(let side):
            return "\(side.rawValue.capitalized) side active. Total elapsed \(total)."
        case .paused(let side):
            return "Session paused on \(side.rawValue) side. Total elapsed \(total)."
        case .stopped:
            return "Session stopped. Total elapsed \(total)."
        case .ended:
            return "Session completed. Total elapsed \(total)."
        }
    }
}
