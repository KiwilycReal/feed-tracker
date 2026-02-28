import Foundation

public protocol ActiveSessionRecoveryStoring {
    func load() throws -> SessionTimerRecoveryState?
    func save(_ state: SessionTimerRecoveryState) throws
    func clear() throws
}
