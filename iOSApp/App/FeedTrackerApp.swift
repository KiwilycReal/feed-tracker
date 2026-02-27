import SwiftUI
import FeedTrackerCore

@main
struct FeedTrackerApp: App {
    private let sampleItem = FeedItem(
        title: "Baby Feeding Guide",
        url: URL(string: "https://example.com/feed.xml")!
    )

    var body: some Scene {
        WindowGroup {
            ContentView(sampleItem: sampleItem)
        }
    }
}
