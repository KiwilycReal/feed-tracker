import Combine
import Foundation

@MainActor
public final class DiagnosticsExportViewModel: ObservableObject {
    private let logger: DiagnosticsEventLogger
    private let appVersionProvider: () -> String
    private let buildNumberProvider: () -> String
    private let deviceModelProvider: () -> String
    private let sourceTag: String

    @Published public private(set) var exportURL: URL?
    @Published public private(set) var lastErrorMessage: String?

    public init(
        logger: DiagnosticsEventLogger,
        appVersionProvider: @escaping () -> String,
        buildNumberProvider: @escaping () -> String,
        deviceModelProvider: @escaping () -> String,
        sourceTag: String
    ) {
        self.logger = logger
        self.appVersionProvider = appVersionProvider
        self.buildNumberProvider = buildNumberProvider
        self.deviceModelProvider = deviceModelProvider
        self.sourceTag = sourceTag
    }

    public func exportDiagnostics(maxEvents: Int = 200) async {
        do {
            let payload = await logger.makeExportPayload(
                appVersion: appVersionProvider(),
                buildNumber: buildNumberProvider(),
                deviceModel: deviceModelProvider(),
                sourceTag: sourceTag,
                maxEvents: maxEvents
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)

            let filename = "feedtracker-diagnostics-\(Int(Date().timeIntervalSince1970)).json"
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: outputURL, options: .atomic)

            exportURL = outputURL
            lastErrorMessage = nil

            await logger.recordEvent(
                category: "diagnostics",
                action: "export_success",
                metadata: [
                    "eventCount": "\(payload.events.count)",
                    "buildNumber": payload.buildNumber
                ],
                source: "diagnostics_export"
            )
        } catch {
            exportURL = nil
            lastErrorMessage = error.localizedDescription
            await logger.recordErrorEvent(
                context: "diagnostics.export",
                message: error.localizedDescription,
                metadata: [:],
                source: "diagnostics_export"
            )
        }
    }

    public func clearExportURL() {
        exportURL = nil
    }

    public func clearError() {
        lastErrorMessage = nil
    }
}
