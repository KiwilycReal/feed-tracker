#if canImport(AppIntents)
import Foundation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@MainActor
public enum FeedTrackerSiriIntentStartupWiring {
    @discardableResult
    public static func wireHandler(
        engine: SessionTimerEngine,
        defaultStartSide: FeedingSide = .left
    ) -> SiriShortcutsHandler {
        let handler = SiriShortcutsHandler(
            engine: engine,
            defaultStartSide: defaultStartSide
        )
        FeedTrackerSiriIntentDependency.handler = handler
        return handler
    }
}
#endif
