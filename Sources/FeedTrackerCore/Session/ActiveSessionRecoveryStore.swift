import Foundation

public enum ActiveSessionRecoveryLoadStrategy: Sendable {
    case fallbackAllowed
    case primaryStoreAuthoritativeWhenMissing
}

public protocol ActiveSessionRecoveryStoring {
    func load(strategy: ActiveSessionRecoveryLoadStrategy) throws -> SessionTimerRecoveryState?
    func save(_ state: SessionTimerRecoveryState) throws
    func clear() throws
}

public extension ActiveSessionRecoveryStoring {
    func load() throws -> SessionTimerRecoveryState? {
        try load(strategy: .fallbackAllowed)
    }
}
