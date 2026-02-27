#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@MainActor
public enum FeedTrackerSiriIntentDependency {
    public static var handler: SiriShortcutsHandler?
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public enum StartTrackingSideIntentParameter: String, AppEnum {
    case `default`
    case left
    case right

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tracking Side"

    public static var caseDisplayRepresentations: [StartTrackingSideIntentParameter: DisplayRepresentation] = [
        .default: "Default Side",
        .left: "Left",
        .right: "Right"
    ]

    var shortcutOption: SiriShortcutStartOption {
        switch self {
        case .default:
            return .default
        case .left:
            return .left
        case .right:
            return .right
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct OpenFeedTrackerIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Feed Tracker"
    public static var description = IntentDescription("Open the Feed Tracker app.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening Feed Tracker.")
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct StartFeedTrackingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Feed Tracking"
    public static var description = IntentDescription("Start tracking with left/right side or default strategy.")
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Side")
    public var side: StartTrackingSideIntentParameter

    public init() {
        self.side = .default
    }

    public init(side: StartTrackingSideIntentParameter) {
        self.side = side
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let handler = await MainActor.run(body: { FeedTrackerSiriIntentDependency.handler }) else {
            return .result(dialog: "Feed Tracker shortcuts are not configured yet.")
        }

        let status = try await MainActor.run {
            try handler.startTracking(sideOption: side.shortcutOption)
        }

        return .result(dialog: IntentDialog(stringLiteral: status.phrase))
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct ReadFeedTrackingStatusIntent: AppIntent {
    public static var title: LocalizedStringResource = "Read Feed Tracking Status"
    public static var description = IntentDescription("Read current side and total elapsed time.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let handler = await MainActor.run(body: { FeedTrackerSiriIntentDependency.handler }) else {
            return .result(dialog: "Feed Tracker shortcuts are not configured yet.")
        }

        let status = await MainActor.run {
            handler.readCurrentStatus()
        }

        return .result(dialog: IntentDialog(stringLiteral: status.phrase))
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct FeedTrackerAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenFeedTrackerIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open feed tracker in \(.applicationName)"
            ],
            shortTitle: "Open",
            systemImageName: "app"
        )

        AppShortcut(
            intent: StartFeedTrackingIntent(),
            phrases: [
                "Start feed tracking in \(.applicationName)",
                "Start \(\.$side) feed tracking in \(.applicationName)"
            ],
            shortTitle: "Start",
            systemImageName: "play.circle"
        )

        AppShortcut(
            intent: ReadFeedTrackingStatusIntent(),
            phrases: [
                "Read feed status in \(.applicationName)",
                "What's the feed status in \(.applicationName)"
            ],
            shortTitle: "Read Status",
            systemImageName: "waveform"
        )
    }
}
#endif
