#if canImport(SwiftUI) && (os(iOS) || os(watchOS))
import SwiftUI

@MainActor
public struct ActiveSessionView: View {
    @StateObject private var viewModel: ActiveSessionViewModel
    private let refreshEvery: TimeInterval

    public init(viewModel: @autoclosure @escaping () -> ActiveSessionViewModel, refreshEvery: TimeInterval = 1) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.refreshEvery = refreshEvery
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Side: \(viewModel.displayState.activeSide?.rawValue.capitalized ?? "None")")
            Text("Left: \(format(viewModel.displayState.leftElapsed))")
            Text("Right: \(format(viewModel.displayState.rightElapsed))")
            Text("Total: \(format(viewModel.displayState.totalElapsed))")
        }
        .font(.headline)
        .onReceive(
            Timer.publish(every: refreshEvery, on: .main, in: .common).autoconnect()
        ) { _ in
            viewModel.refresh()
        }
    }

    private func format(_ value: TimeInterval) -> String {
        let rounded = Int(value.rounded())
        let minutes = rounded / 60
        let seconds = rounded % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
#endif
