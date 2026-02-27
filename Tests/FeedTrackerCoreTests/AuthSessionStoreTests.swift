import XCTest
@testable import FeedTrackerCore

final class AuthSessionStoreTests: XCTestCase {
    func testAccessTokenProviderReturnsTokenWhenSessionIsValid() async {
        let store = InMemoryAuthSessionStore()
        let validSession = AuthSession(
            accessToken: "token-123",
            refreshToken: "refresh-456",
            expiresAt: Date().addingTimeInterval(60)
        )
        await store.save(validSession)

        let provider = DefaultAccessTokenProvider(store: store)

        let token = await provider.accessToken()
        XCTAssertEqual(token, "token-123")
    }

    func testAccessTokenProviderReturnsNilWhenSessionIsExpired() async {
        let store = InMemoryAuthSessionStore()
        let expiredSession = AuthSession(
            accessToken: "expired",
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(-60)
        )
        await store.save(expiredSession)

        let provider = DefaultAccessTokenProvider(store: store)

        let token = await provider.accessToken()
        XCTAssertNil(token)
    }

    func testClearRemovesStoredSession() async {
        let store = InMemoryAuthSessionStore()
        let session = AuthSession(
            accessToken: "active",
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(60)
        )

        await store.save(session)
        await store.clear()

        let loaded = await store.load()
        XCTAssertNil(loaded)
    }
}
