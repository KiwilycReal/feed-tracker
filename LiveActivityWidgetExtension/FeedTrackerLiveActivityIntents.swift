import FeedTrackerCore
import Foundation

// Live Activity AppIntent definitions now live in FeedTrackerCore so the same
// intent type is linked into both the iOS app target and the widget extension.
// This lets the system prefer app-host execution for quick actions when
// available, while keeping the widget extension build source-compatible.
