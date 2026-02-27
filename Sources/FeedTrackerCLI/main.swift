import Foundation
import FeedTrackerCore

@main
struct FeedTrackerCLI {
    static func main() async {
        let engine = SessionTimerEngine()

        #if canImport(AppIntents)
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *) {
            await MainActor.run {
                _ = FeedTrackerSiriIntentStartupWiring.wireHandler(engine: engine)
            }
        }
        #endif

        let sample = FeedItem(title: "Bootstrap Feed", url: URL(string: "https://example.com/feed")!)
        print("feed-tracker bootstrap ready: \(FeedValidator.isValid(sample))")
    }
}
