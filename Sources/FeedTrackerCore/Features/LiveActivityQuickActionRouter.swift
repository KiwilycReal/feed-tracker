import Foundation

public protocol LiveActivityQuickActionRouting: Sendable {
    func url(for action: LiveActivityQuickAction) -> URL
    func passiveOpenURL(sessionID: String?) -> URL
    func action(from url: URL) -> LiveActivityQuickAction?
    func isPassiveOpenURL(_ url: URL) -> Bool
}

public struct LiveActivityQuickActionRouter: LiveActivityQuickActionRouting {
    public let scheme: String
    public let host: String
    public let passiveRouteValue: String

    public init(
        scheme: String = "feedtracker",
        host: String = "live-activity",
        passiveRouteValue: String = "open"
    ) {
        self.scheme = scheme
        self.host = host
        self.passiveRouteValue = passiveRouteValue
    }

    public func url(for action: LiveActivityQuickAction) -> URL {
        var components = baseComponents()
        components.queryItems = [URLQueryItem(name: "action", value: action.rawValue)]

        guard let url = components.url else {
            preconditionFailure("Failed to construct live activity URL for action: \(action.rawValue)")
        }
        return url
    }

    public func passiveOpenURL(sessionID: String?) -> URL {
        var components = baseComponents()
        var queryItems = [URLQueryItem(name: "route", value: passiveRouteValue)]

        if let sessionID, sessionID.isEmpty == false {
            queryItems.append(URLQueryItem(name: "session", value: sessionID))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            preconditionFailure("Failed to construct passive live activity URL")
        }
        return url
    }

    public func action(from url: URL) -> LiveActivityQuickAction? {
        guard
            let components = matchedComponents(for: url),
            let rawAction = components.queryItems?.first(where: { $0.name == "action" })?.value
        else {
            return nil
        }

        return LiveActivityQuickAction(rawValue: rawAction)
    }

    public func isPassiveOpenURL(_ url: URL) -> Bool {
        guard
            let components = matchedComponents(for: url),
            let route = components.queryItems?.first(where: { $0.name == "route" })?.value
        else {
            return false
        }

        return route == passiveRouteValue
    }

    private func baseComponents() -> URLComponents {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        return components
    }

    private func matchedComponents(for url: URL) -> URLComponents? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == scheme.lowercased(),
            components.host?.lowercased() == host.lowercased()
        else {
            return nil
        }

        return components
    }
}
