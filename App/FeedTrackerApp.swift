import SwiftUI
import FeedTrackerCore
import Darwin

final class UserDefaultsActiveSessionRecoveryStore: ActiveSessionRecoveryStoring {
    private let userDefaults: UserDefaults
    private let key: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "feedtracker.active_session_recovery.v1"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    func load() throws -> SessionTimerRecoveryState? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionTimerRecoveryState.self, from: data)
    }

    func save(_ state: SessionTimerRecoveryState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        userDefaults.set(data, forKey: key)
    }

    func clear() throws {
        userDefaults.removeObject(forKey: key)
    }
}

@MainActor
final class FeedTrackerDependencies {
    let engine: SessionTimerEngine
    let repository: any FeedingSessionRepository
    let diagnosticsLogger: DiagnosticsEventLogger
    let activeSessionRecoveryStore: any ActiveSessionRecoveryStoring

    init() {
        self.engine = SessionTimerEngine()
        self.diagnosticsLogger = DiagnosticsEventLogger(defaultSourceTag: "ios-app")
        self.activeSessionRecoveryStore = UserDefaultsActiveSessionRecoveryStore()

        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dataURL = supportDir?
            .appendingPathComponent("FeedTracker", isDirectory: true)
            .appendingPathComponent("sessions.json")

        if let dataURL, let fileRepo = try? FileFeedingSessionRepository(fileURL: dataURL) {
            self.repository = fileRepo
        } else {
            self.repository = InMemoryFeedingSessionRepository()
        }
    }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

enum DeviceModel {
    static func currentIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { partialResult, element in
            guard let value = element.value as? Int8, value != 0 else {
                return
            }
            partialResult.append(Character(UnicodeScalar(UInt8(value))))
        }

        return identifier.isEmpty ? "unknown" : identifier
    }
}

@main
@MainActor
struct FeedTrackerApp: App {
    private let deps = FeedTrackerDependencies()

    var body: some Scene {
        WindowGroup {
            FeedTrackerMainNavigationView(
                activeSessionViewModel: ActiveSessionViewModel(
                    engine: deps.engine,
                    repository: deps.repository,
                    diagnostics: deps.diagnosticsLogger,
                    recoveryStore: deps.activeSessionRecoveryStore
                ),
                historyViewModel: HistoryListViewModel(
                    repository: deps.repository,
                    diagnostics: deps.diagnosticsLogger
                ),
                diagnosticsExportViewModel: DiagnosticsExportViewModel(
                    logger: deps.diagnosticsLogger,
                    appVersionProvider: { deps.appVersion },
                    buildNumberProvider: { deps.buildNumber },
                    deviceModelProvider: { DeviceModel.currentIdentifier() },
                    sourceTag: "ios-app"
                )
            )
        }
    }
}
