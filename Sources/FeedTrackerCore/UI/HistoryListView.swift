#if canImport(SwiftUI) && (os(iOS) || os(watchOS))
import SwiftUI

@MainActor
public struct HistoryListView: View {
    @StateObject private var viewModel: HistoryListViewModel
    @State private var pendingDeleteItem: HistorySessionListItem?
    @State private var deleteErrorMessage: String?

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
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    pendingDeleteItem = item
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .task {
            try? await viewModel.reload()
        }
        .alert(
            "Delete this session?",
            isPresented: deleteConfirmationBinding,
            presenting: pendingDeleteItem
        ) { item in
            Button("Cancel", role: .cancel) {
                pendingDeleteItem = nil
            }
            Button("Delete", role: .destructive) {
                Task {
                    await performDelete(for: item)
                }
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
        .alert("Delete failed", isPresented: deleteErrorBinding) {
            Button("OK", role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "Unknown error")
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteItem != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteItem = nil
                }
            }
        )
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    deleteErrorMessage = nil
                }
            }
        )
    }

    private func performDelete(for item: HistorySessionListItem) async {
        do {
            try await viewModel.deleteSession(id: item.id)
            pendingDeleteItem = nil
        } catch {
            pendingDeleteItem = nil
            deleteErrorMessage = error.localizedDescription
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
