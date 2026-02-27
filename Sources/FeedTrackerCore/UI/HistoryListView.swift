#if canImport(SwiftUI)
import SwiftUI

@MainActor
public struct HistoryListView: View {
    @StateObject private var viewModel: HistoryListViewModel

    public init(viewModel: @autoclosure @escaping () -> HistoryListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        List(viewModel.items) { item in
            VStack(alignment: .leading, spacing: 6) {
                Text(item.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Text("Left: \(format(item.leftDuration))  Right: \(format(item.rightDuration))")
                Text("Total: \(format(item.totalDuration))")
                    .font(.subheadline)
                if let note = item.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .task {
            try? await viewModel.reload()
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
