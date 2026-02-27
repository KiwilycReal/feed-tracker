import SwiftUI
import FeedTrackerCore

@MainActor
final class FeedTrackerDependencies {
    let engine: SessionTimerEngine
    let repository: any FeedingSessionRepository

    init() {
        self.engine = SessionTimerEngine()

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
}

@main
struct FeedTrackerApp: App {
    private let deps = FeedTrackerDependencies()

    var body: some Scene {
        WindowGroup {
            FeedTrackerMainNavigationView(
                activeSessionViewModel: ActiveSessionViewModel(engine: deps.engine, repository: deps.repository),
                historyViewModel: HistoryListViewModel(repository: deps.repository)
            )
        }
    }
}
