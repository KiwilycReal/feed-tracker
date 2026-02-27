import Foundation

public struct RuntimeConfig: Equatable, Sendable {
    public let environment: Environment
    public let apiBaseURL: URL
    public let requestTimeoutSeconds: TimeInterval

    public init(environment: Environment, apiBaseURL: URL, requestTimeoutSeconds: TimeInterval) {
        self.environment = environment
        self.apiBaseURL = apiBaseURL
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }
}

public extension RuntimeConfig {
    enum Environment: String, Equatable, Sendable {
        case development
        case staging
        case production
    }
}

public protocol EnvironmentValueReading: Sendable {
    func value(for key: String) -> String?
}

public struct ProcessEnvironmentReader: EnvironmentValueReading {
    private let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    public func value(for key: String) -> String? {
        environment[key]
    }
}

public struct RuntimeConfigKeys: Equatable, Sendable {
    public let environment: String
    public let apiBaseURL: String
    public let requestTimeoutSeconds: String

    public init(
        environment: String = "FEED_TRACKER_ENV",
        apiBaseURL: String = "FEED_TRACKER_API_BASE_URL",
        requestTimeoutSeconds: String = "FEED_TRACKER_REQUEST_TIMEOUT_SECONDS"
    ) {
        self.environment = environment
        self.apiBaseURL = apiBaseURL
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }
}

public enum RuntimeConfigError: Error, Equatable, Sendable {
    case missingValue(key: String)
    case invalidEnvironment(value: String)
    case invalidURL(value: String)
    case invalidTimeout(value: String)
}

public enum RuntimeConfigLoader {
    public static func load(
        reader: EnvironmentValueReading = ProcessEnvironmentReader(),
        keys: RuntimeConfigKeys = RuntimeConfigKeys()
    ) throws -> RuntimeConfig {
        let environmentRaw = try requiredValue(for: keys.environment, reader: reader)
        guard let environment = RuntimeConfig.Environment(rawValue: environmentRaw) else {
            throw RuntimeConfigError.invalidEnvironment(value: environmentRaw)
        }

        let apiBaseURLRaw = try requiredValue(for: keys.apiBaseURL, reader: reader)
        guard let apiBaseURL = URL(string: apiBaseURLRaw), apiBaseURL.scheme != nil else {
            throw RuntimeConfigError.invalidURL(value: apiBaseURLRaw)
        }

        let timeoutRaw = try requiredValue(for: keys.requestTimeoutSeconds, reader: reader)
        guard let requestTimeoutSeconds = TimeInterval(timeoutRaw), requestTimeoutSeconds > 0 else {
            throw RuntimeConfigError.invalidTimeout(value: timeoutRaw)
        }

        return RuntimeConfig(
            environment: environment,
            apiBaseURL: apiBaseURL,
            requestTimeoutSeconds: requestTimeoutSeconds
        )
    }

    private static func requiredValue(for key: String, reader: EnvironmentValueReading) throws -> String {
        guard let value = reader.value(for: key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw RuntimeConfigError.missingValue(key: key)
        }
        return value
    }
}
