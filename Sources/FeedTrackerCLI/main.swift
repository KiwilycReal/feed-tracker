import Foundation
import FeedTrackerCore

let sample = FeedItem(title: "Bootstrap Feed", url: URL(string: "https://example.com/feed")!)
print("feed-tracker bootstrap ready: \(FeedValidator.isValid(sample))")
