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
        List {
            if viewModel.items.isEmpty {
                emptyStateView
                    .listRowBackground(FeedTrackerPalette.pageBackground)
            } else {
                ForEach(viewModel.items) { item in
                    HistoryRow(item: item)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(FeedTrackerPalette.pageBackground)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteItem = item
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(FeedTrackerPalette.pageBackground)
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

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(FeedTrackerPalette.accent)
            Text("No sessions yet")
                .font(.headline)
                .foregroundStyle(FeedTrackerPalette.primaryText)
            Text("Complete a feeding session and it will appear here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(FeedTrackerPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
}

private struct HistoryRow: View {
    let item: HistorySessionListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(FeedTrackerPalette.primaryText)
                Spacer()
                Text(SessionPresentation.durationText(item.totalDuration))
                    .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
                    .foregroundStyle(FeedTrackerPalette.accent)
            }

            HStack(spacing: 12) {
                durationChip(title: "Left", value: item.leftDuration, color: FeedTrackerPalette.leftSide)
                durationChip(title: "Right", value: item.rightDuration, color: FeedTrackerPalette.rightSide)
            }

            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(FeedTrackerPalette.secondaryText)
                    .padding(.top, 2)
            }
        }
        .feedTrackerCardStyle()
    }

    private func durationChip(title: String, value: TimeInterval, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(title): \(SessionPresentation.durationText(value))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FeedTrackerPalette.primaryText)
        }
    }
}
#endif
