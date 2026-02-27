import Foundation

public struct FeedItem: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let url: URL
    public let createdAt: Date

    public init(id: UUID = UUID(), title: String, url: URL, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.createdAt = createdAt
    }
}

public enum FeedValidator {
    public static func isValid(_ item: FeedItem) -> Bool {
        !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
