import SwiftUI
import FeedTrackerCore
import Darwin

@MainActor
final class FeedTrackerDependencies {
    let engine: SessionTimerEngine
    let repository: any FeedingSessionRepository
    let diagnosticsLogger: DiagnosticsEventLogger

    init() {
        self.engine = SessionTimerEngine()
        self.diagnosticsLogger = DiagnosticsEventLogger(defaultSourceTag: "ios-app")

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
                    diagnostics: deps.diagnosticsLogger
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
