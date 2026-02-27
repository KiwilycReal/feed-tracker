import SwiftUI
import FeedTrackerCore

struct ContentView: View {
    let sampleItem: FeedItem

    var body: some View {
        NavigationStack {
            List {
                Text(sampleItem.title)
                Text(sampleItem.url.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label(
                    FeedValidator.isValid(sampleItem) ? "Feed item is valid" : "Feed item is invalid",
                    systemImage: FeedValidator.isValid(sampleItem) ? "checkmark.circle.fill" : "xmark.octagon.fill"
                )
                .foregroundStyle(FeedValidator.isValid(sampleItem) ? .green : .red)
            }
            .navigationTitle("FeedTracker")
        }
    }
}

#Preview {
    ContentView(
        sampleItem: FeedItem(
            title: "Preview Feed",
            url: URL(string: "https://example.com/preview.xml")!
        )
    )
}
