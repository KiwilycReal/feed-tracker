#if canImport(SwiftUI) && (os(iOS) || os(watchOS))
import SwiftUI

@MainActor
public struct FeedTrackerMainNavigationView: View {
    @StateObject private var activeSessionViewModel: ActiveSessionViewModel
    @StateObject private var historyViewModel: HistoryListViewModel

    public init(
        activeSessionViewModel: @autoclosure @escaping () -> ActiveSessionViewModel,
        historyViewModel: @autoclosure @escaping () -> HistoryListViewModel
    ) {
        _activeSessionViewModel = StateObject(wrappedValue: activeSessionViewModel())
        _historyViewModel = StateObject(wrappedValue: historyViewModel())
    }

    public var body: some View {
        TabView {
            NavigationStack {
                ActiveSessionView(viewModel: activeSessionViewModel)
                    .navigationTitle("Active Session")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Active", systemImage: "heart.text.square.fill")
            }

            NavigationStack {
                HistoryListView(viewModel: historyViewModel)
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
        .tint(FeedTrackerPalette.accent)
    }
}
#endif
