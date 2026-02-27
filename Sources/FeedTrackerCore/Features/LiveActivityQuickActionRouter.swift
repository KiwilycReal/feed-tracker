import Foundation

public protocol LiveActivityQuickActionRouting: Sendable {
    func url(for action: LiveActivityQuickAction) -> URL
    func action(from url: URL) -> LiveActivityQuickAction?
}

public struct LiveActivityQuickActionRouter: LiveActivityQuickActionRouting {
    public let scheme: String
    public let host: String

    public init(scheme: String = "feedtracker", host: String = "live-activity") {
        self.scheme = scheme
        self.host = host
    }

    public func url(for action: LiveActivityQuickAction) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "action", value: action.rawValue)]

        guard let url = components.url else {
            preconditionFailure("Failed to construct live activity URL for action: \(action.rawValue)")
        }
        return url
    }

    public func action(from url: URL) -> LiveActivityQuickAction? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == scheme.lowercased(),
            components.host?.lowercased() == host.lowercased(),
            let rawAction = components.queryItems?.first(where: { $0.name == "action" })?.value
        else {
            return nil
        }

        return LiveActivityQuickAction(rawValue: rawAction)
    }
}
