import Foundation

public struct DiagnosticsErrorSummary: Codable, Equatable, Sendable {
    public let context: String
    public let message: String
    public let timestamp: Date

    public init(context: String, message: String, timestamp: Date) {
        self.context = context
        self.message = message
        self.timestamp = timestamp
    }
}

public struct DiagnosticsEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let category: String
    public let action: String
    public let source: String
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        category: String,
        action: String,
        source: String,
        timestamp: Date,
        metadata: [String: String]
    ) {
        self.id = id
        self.category = category
        self.action = action
        self.source = source
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

public struct DiagnosticsExportPayload: Codable, Equatable, Sendable {
    public let appVersion: String
    public let buildNumber: String
    public let deviceModel: String
    public let sourceTag: String
    public let exportedAt: Date
    public let events: [DiagnosticsEvent]
    public let lastErrorSummary: DiagnosticsErrorSummary?

    public init(
        appVersion: String,
        buildNumber: String,
        deviceModel: String,
        sourceTag: String,
        exportedAt: Date,
        events: [DiagnosticsEvent],
        lastErrorSummary: DiagnosticsErrorSummary?
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.deviceModel = deviceModel
        self.sourceTag = sourceTag
        self.exportedAt = exportedAt
        self.events = events
        self.lastErrorSummary = lastErrorSummary
    }
}

public protocol DiagnosticsLogging: Sendable {
    func record(category: String, action: String, metadata: [String: String], source: String)
    func recordError(context: String, message: String, metadata: [String: String], source: String)
}

public struct DiagnosticsRedactor: Sendable {
    public let sensitiveKeyFragments: [String]
    public let sensitiveMessageFragments: [String]

    public init(
        sensitiveKeyFragments: [String],
        sensitiveMessageFragments: [String]
    ) {
        self.sensitiveKeyFragments = sensitiveKeyFragments
        self.sensitiveMessageFragments = sensitiveMessageFragments
    }

    public static let `default` = DiagnosticsRedactor(
        sensitiveKeyFragments: [
            "note", "message", "token", "password", "authorization", "api_key", "apikey", "email"
        ],
        sensitiveMessageFragments: [
            "token", "password", "authorization", "bearer", "api key"
        ]
    )

    public func redact(metadata: [String: String]) -> [String: String] {
        var redacted: [String: String] = [:]

        for (key, value) in metadata {
            let normalizedKey = key.lowercased()
            let shouldRedact = sensitiveKeyFragments.contains { normalizedKey.contains($0) }
            if shouldRedact {
                redacted[key] = "<redacted>"
            } else {
                redacted[key] = truncate(value)
            }
        }

        return redacted
    }

    public func redactMessage(_ message: String) -> String {
        let normalized = message.lowercased()
        if sensitiveMessageFragments.contains(where: { normalized.contains($0) }) {
            return "<redacted>"
        }

        return truncate(message)
    }

    private func truncate(_ value: String, maxLength: Int = 180) -> String {
        if value.count <= maxLength {
            return value
        }

        return String(value.prefix(maxLength)) + "…"
    }
}

public actor DiagnosticsEventLogger: DiagnosticsLogging {
    private let defaultSourceTag: String
    private let capacity: Int
    private let redactor: DiagnosticsRedactor

    private var events: [DiagnosticsEvent] = []
    private var lastErrorSummary: DiagnosticsErrorSummary?

    public init(
        defaultSourceTag: String,
        capacity: Int = 500,
        redactor: DiagnosticsRedactor = .default
    ) {
        self.defaultSourceTag = defaultSourceTag
        self.capacity = max(100, capacity)
        self.redactor = redactor
    }

    nonisolated public func record(
        category: String,
        action: String,
        metadata: [String: String] = [:],
        source: String
    ) {
        Task {
            await recordEvent(
                category: category,
                action: action,
                metadata: metadata,
                source: source
            )
        }
    }

    nonisolated public func recordError(
        context: String,
        message: String,
        metadata: [String: String] = [:],
        source: String
    ) {
        Task {
            await recordErrorEvent(
                context: context,
                message: message,
                metadata: metadata,
                source: source
            )
        }
    }

    public func recordEvent(
        category: String,
        action: String,
        metadata: [String: String] = [:],
        source: String? = nil
    ) {
        let sourceValue = source ?? defaultSourceTag
        let event = DiagnosticsEvent(
            category: category,
            action: action,
            source: sourceValue,
            timestamp: Date(),
            metadata: redactor.redact(metadata: metadata)
        )
        append(event)
    }

    public func recordErrorEvent(
        context: String,
        message: String,
        metadata: [String: String] = [:],
        source: String? = nil
    ) {
        let sourceValue = source ?? defaultSourceTag
        let redactedMessage = redactor.redactMessage(message)

        lastErrorSummary = DiagnosticsErrorSummary(
            context: context,
            message: redactedMessage,
            timestamp: Date()
        )

        let event = DiagnosticsEvent(
            category: "error",
            action: context,
            source: sourceValue,
            timestamp: Date(),
            metadata: redactor.redact(metadata: metadata.merging(["summary": redactedMessage], uniquingKeysWith: { _, new in new }))
        )
        append(event)
    }

    public func makeExportPayload(
        appVersion: String,
        buildNumber: String,
        deviceModel: String,
        sourceTag: String? = nil,
        maxEvents: Int = 200
    ) -> DiagnosticsExportPayload {
        let requested = max(100, maxEvents)
        let selectedEvents = Array(events.suffix(requested))

        return DiagnosticsExportPayload(
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceModel: deviceModel,
            sourceTag: sourceTag ?? defaultSourceTag,
            exportedAt: Date(),
            events: selectedEvents,
            lastErrorSummary: lastErrorSummary
        )
    }

    private func append(_ event: DiagnosticsEvent) {
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
    }
}
