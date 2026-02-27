import Foundation

public struct StorageVersion: Comparable, Equatable, Hashable, Sendable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public static func < (lhs: StorageVersion, rhs: StorageVersion) -> Bool {
        lhs.value < rhs.value
    }
}

public protocol StorageVersionReading: Sendable {
    func currentVersion() async throws -> StorageVersion
}

public protocol StorageVersionWriting: Sendable {
    func setCurrentVersion(_ version: StorageVersion) async throws
}

public protocol StorageMigrationStep: Sendable {
    var targetVersion: StorageVersion { get }
    func run() async throws
}

public enum StorageMigrationError: Error, Equatable, Sendable {
    case downgradeNotSupported(current: StorageVersion, requested: StorageVersion)
    case missingPath(from: StorageVersion, to: StorageVersion)
}

public struct StorageMigrator: Sendable {
    private let reader: StorageVersionReading
    private let writer: StorageVersionWriting
    private let steps: [StorageMigrationStep]

    public init(
        reader: StorageVersionReading,
        writer: StorageVersionWriting,
        steps: [StorageMigrationStep]
    ) {
        self.reader = reader
        self.writer = writer
        self.steps = steps.sorted { $0.targetVersion < $1.targetVersion }
    }

    public func migrate(to targetVersion: StorageVersion) async throws {
        let currentVersion = try await reader.currentVersion()
        guard currentVersion <= targetVersion else {
            throw StorageMigrationError.downgradeNotSupported(current: currentVersion, requested: targetVersion)
        }

        if currentVersion == targetVersion {
            return
        }

        let plannedSteps = steps.filter { $0.targetVersion > currentVersion && $0.targetVersion <= targetVersion }
        let requiredVersions = Set((currentVersion.value + 1...targetVersion.value).map(StorageVersion.init))
        let availableVersions = Set(plannedSteps.map(\.targetVersion))

        guard requiredVersions.isSubset(of: availableVersions) else {
            throw StorageMigrationError.missingPath(from: currentVersion, to: targetVersion)
        }

        for step in plannedSteps {
            try await step.run()
            try await writer.setCurrentVersion(step.targetVersion)
        }
    }
}
