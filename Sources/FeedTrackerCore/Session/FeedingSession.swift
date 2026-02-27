import Foundation

public enum FeedingSide: String, CaseIterable, Equatable, Sendable, Codable {
    case left
    case right
}

public enum FeedingSessionStatus: String, Equatable, Sendable, Codable {
    case active
    case paused
    case stopped
    case completed
}

public enum FeedingSessionValidationError: Error, Equatable, Sendable {
    case negativeDuration
}

public struct FeedingSession: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let leftDuration: TimeInterval
    public let rightDuration: TimeInterval
    public let note: String?
    public let status: FeedingSessionStatus

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date?,
        leftDuration: TimeInterval,
        rightDuration: TimeInterval,
        note: String? = nil,
        status: FeedingSessionStatus
    ) throws {
        guard leftDuration >= 0, rightDuration >= 0 else {
            throw FeedingSessionValidationError.negativeDuration
        }

        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.leftDuration = leftDuration
        self.rightDuration = rightDuration
        self.note = note
        self.status = status
    }

    public var totalDuration: TimeInterval {
        leftDuration + rightDuration
    }

    public func edited(
        leftDuration: TimeInterval,
        rightDuration: TimeInterval,
        note: String?
    ) throws -> FeedingSession {
        try FeedingSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            leftDuration: leftDuration,
            rightDuration: rightDuration,
            note: note,
            status: status
        )
    }
}
