import Foundation
import XCTest
@testable import FeedTrackerCore

final class FileFeedingSessionRepositoryTests: XCTestCase {
    func testRepositoryPersistsSessionsAcrossReinitialization() async throws {
        let fileURL = try makeTempStoreURL(testName: #function)

        let firstSession = try FeedingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_120),
            leftDuration: 70,
            rightDuration: 50,
            note: "persist me",
            status: .completed
        )

        let repository = try FileFeedingSessionRepository(fileURL: fileURL)
        try await repository.upsert(firstSession)

        let reloadedRepository = try FileFeedingSessionRepository(fileURL: fileURL)
        let sessions = try await reloadedRepository.fetchAll()

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, firstSession.id)
        XCTAssertEqual(sessions.first?.note, "persist me")
    }

    func testRepositoryMigratesLegacyArrayPayloadToVersionedStore() async throws {
        let fileURL = try makeTempStoreURL(testName: #function)
        let legacySession = try FeedingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!,
            startedAt: Date(timeIntervalSince1970: 2_000),
            endedAt: Date(timeIntervalSince1970: 2_160),
            leftDuration: 90,
            rightDuration: 70,
            note: "legacy",
            status: .completed
        )

        let legacyData = try makeJSONEncoder().encode([legacySession])
        try legacyData.write(to: fileURL, options: .atomic)

        let repository = try FileFeedingSessionRepository(fileURL: fileURL)
        let sessions = try await repository.fetchAll()

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, legacySession.id)

        let migratedData = try Data(contentsOf: fileURL)
        let migratedStore = try makeJSONDecoder().decode(VersionedStoreProbe.self, from: migratedData)

        XCTAssertEqual(migratedStore.schemaVersion, FileFeedingSessionRepository.currentSchemaVersion.value)
        XCTAssertEqual(migratedStore.sessions.count, 1)
        XCTAssertEqual(migratedStore.sessions.first?.id, legacySession.id)
    }

    func testRepositoryMigratesVersion1StoreToCurrentVersion() async throws {
        let fileURL = try makeTempStoreURL(testName: #function)
        let v1Session = try FeedingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D3")!,
            startedAt: Date(timeIntervalSince1970: 3_000),
            endedAt: Date(timeIntervalSince1970: 3_180),
            leftDuration: 100,
            rightDuration: 80,
            note: "v1",
            status: .completed
        )

        let version1Store = VersionedStoreProbe(schemaVersion: 1, sessions: [v1Session])
        let version1Data = try makeJSONEncoder().encode(version1Store)
        try version1Data.write(to: fileURL, options: .atomic)

        _ = try FileFeedingSessionRepository(fileURL: fileURL)

        let migratedData = try Data(contentsOf: fileURL)
        let migratedStore = try makeJSONDecoder().decode(VersionedStoreProbe.self, from: migratedData)
        XCTAssertEqual(migratedStore.schemaVersion, FileFeedingSessionRepository.currentSchemaVersion.value)
        XCTAssertEqual(migratedStore.sessions.first?.id, v1Session.id)
    }

    func testSharedStorageMigrationFillsBootstrapSharedStoreFromLegacyHistory() async throws {
        let legacyURL = try makeTempStoreURL(testName: #function + ".legacy")
        let sharedURL = try makeTempStoreURL(testName: #function + ".shared")

        let legacySession = try FeedingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D4")!,
            startedAt: Date(timeIntervalSince1970: 4_000),
            endedAt: Date(timeIntervalSince1970: 4_120),
            leftDuration: 75,
            rightDuration: 45,
            note: "legacy history",
            status: .completed
        )

        let legacyData = try makeJSONEncoder().encode([legacySession])
        try legacyData.write(to: legacyURL, options: .atomic)

        _ = try FileFeedingSessionRepository(fileURL: sharedURL)

        FeedTrackerSharedStorage.migrateLegacySessionsIfNeeded(from: legacyURL, to: sharedURL)

        let sharedRepository = try FileFeedingSessionRepository(fileURL: sharedURL)
        let sessions = try await sharedRepository.fetchAll()

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, legacySession.id)
    }

    func testSharedStorageMigrationMergesLegacyHistoryIntoExistingSharedStore() async throws {
        let legacyURL = try makeTempStoreURL(testName: #function + ".legacy")
        let sharedURL = try makeTempStoreURL(testName: #function + ".shared")

        let legacySession = try FeedingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D5")!,
            startedAt: Date(timeIntervalSince1970: 5_000),
            endedAt: Date(timeIntervalSince1970: 5_090),
            leftDuration: 50,
            rightDuration: 40,
            note: "legacy only",
            status: .completed
        )
        let sharedSession = try FeedingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D6")!,
            startedAt: Date(timeIntervalSince1970: 6_000),
            endedAt: Date(timeIntervalSince1970: 6_180),
            leftDuration: 95,
            rightDuration: 85,
            note: "shared only",
            status: .completed
        )

        try makeJSONEncoder().encode([legacySession]).write(to: legacyURL, options: .atomic)

        let sharedRepository = try FileFeedingSessionRepository(fileURL: sharedURL)
        try await sharedRepository.upsert(sharedSession)

        FeedTrackerSharedStorage.migrateLegacySessionsIfNeeded(from: legacyURL, to: sharedURL)

        let reloadedRepository = try FileFeedingSessionRepository(fileURL: sharedURL)
        let sessions = try await reloadedRepository.fetchAll()

        XCTAssertEqual(Set(sessions.map(\.id)), Set([legacySession.id, sharedSession.id]))
    }

    private func makeTempStoreURL(testName: String) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("FeedTrackerCoreTests", isDirectory: true)
            .appendingPathComponent(testName, isDirectory: true)

        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("feeding-sessions.json")
    }

    private func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct VersionedStoreProbe: Codable {
    let schemaVersion: Int
    let sessions: [FeedingSession]
}
