import XCTest
@testable import FeedTrackerCore

final class InMemoryFeedItemRepositoryTests: XCTestCase {
    func testUpsertAndFetchAllSortedByNewestFirst() async throws {
        let repo = InMemoryFeedItemRepository()
        let older = FeedItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Older",
            url: URL(string: "https://example.com/1")!,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newer = FeedItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Newer",
            url: URL(string: "https://example.com/2")!,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        try await repo.upsert(older)
        try await repo.upsert(newer)

        let items = try await repo.fetchAll()
        XCTAssertEqual(items.map(\.id), [newer.id, older.id])
    }

    func testRemoveDeletesItemByID() async throws {
        let existing = FeedItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
            title: "To delete",
            url: URL(string: "https://example.com/delete")!
        )
        let repo = InMemoryFeedItemRepository(initialItems: [existing])

        try await repo.remove(id: existing.id)

        let items = try await repo.fetchAll()
        XCTAssertTrue(items.isEmpty)
    }
}

final class StorageMigratorTests: XCTestCase {
    func testMigratorExecutesForwardStepsAndPersistsLatestVersion() async throws {
        let store = VersionStore(current: StorageVersion(1))
        let step2 = RecordingMigrationStep(targetVersion: StorageVersion(2))
        let step3 = RecordingMigrationStep(targetVersion: StorageVersion(3))
        let migrator = StorageMigrator(reader: store, writer: store, steps: [step3, step2])

        try await migrator.migrate(to: StorageVersion(3))

        let current = try await store.currentVersion()
        let step2RunCount = await step2.currentRunCount()
        let step3RunCount = await step3.currentRunCount()

        XCTAssertEqual(current, StorageVersion(3))
        XCTAssertEqual(step2RunCount, 1)
        XCTAssertEqual(step3RunCount, 1)
    }

    func testMigratorThrowsWhenPathIsMissing() async {
        let store = VersionStore(current: StorageVersion(1))
        let step3 = RecordingMigrationStep(targetVersion: StorageVersion(3))
        let migrator = StorageMigrator(reader: store, writer: store, steps: [step3])

        do {
            try await migrator.migrate(to: StorageVersion(3))
            XCTFail("Expected missingPath error")
        } catch {
            XCTAssertEqual(
                error as? StorageMigrationError,
                .missingPath(from: StorageVersion(1), to: StorageVersion(3))
            )
        }
    }
}

private actor VersionStore: StorageVersionReading, StorageVersionWriting {
    private var version: StorageVersion

    init(current: StorageVersion) {
        self.version = current
    }

    func currentVersion() throws -> StorageVersion {
        version
    }

    func setCurrentVersion(_ version: StorageVersion) throws {
        self.version = version
    }
}

private actor RecordingMigrationStep: StorageMigrationStep {
    let targetVersion: StorageVersion
    private var runCount: Int = 0

    init(targetVersion: StorageVersion) {
        self.targetVersion = targetVersion
    }

    func run() throws {
        runCount += 1
    }

    func currentRunCount() -> Int {
        runCount
    }
}
