import Foundation

public struct AuthSession: Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String?, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public func isValid(at date: Date = Date()) -> Bool {
        expiresAt > date
    }
}

public protocol AuthSessionStoring: Sendable {
    func load() async -> AuthSession?
    func save(_ session: AuthSession) async
    func clear() async
}

public protocol AccessTokenProviding: Sendable {
    func accessToken() async -> String?
}

public actor InMemoryAuthSessionStore: AuthSessionStoring {
    private var session: AuthSession?

    public init(session: AuthSession? = nil) {
        self.session = session
    }

    public func load() -> AuthSession? {
        session
    }

    public func save(_ session: AuthSession) {
        self.session = session
    }

    public func clear() {
        session = nil
    }
}

public struct DefaultAccessTokenProvider: AccessTokenProviding {
    private let store: AuthSessionStoring
    private let now: @Sendable () -> Date

    public init(
        store: AuthSessionStoring,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.now = now
    }

    public func accessToken() async -> String? {
        guard let session = await store.load(), session.isValid(at: now()) else {
            return nil
        }
        return session.accessToken
    }
}
