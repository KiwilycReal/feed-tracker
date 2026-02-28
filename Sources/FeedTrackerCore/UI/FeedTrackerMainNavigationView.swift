#if canImport(SwiftUI) && (os(iOS) || os(watchOS))
import SwiftUI

@MainActor
public struct FeedTrackerMainNavigationView: View {
    @StateObject private var activeSessionViewModel: ActiveSessionViewModel
    @StateObject private var historyViewModel: HistoryListViewModel
    @StateObject private var diagnosticsExportViewModel: DiagnosticsExportViewModel

    public init(
        activeSessionViewModel: @autoclosure @escaping () -> ActiveSessionViewModel,
        historyViewModel: @autoclosure @escaping () -> HistoryListViewModel,
        diagnosticsExportViewModel: @autoclosure @escaping () -> DiagnosticsExportViewModel
    ) {
        _activeSessionViewModel = StateObject(wrappedValue: activeSessionViewModel())
        _historyViewModel = StateObject(wrappedValue: historyViewModel())
        _diagnosticsExportViewModel = StateObject(wrappedValue: diagnosticsExportViewModel())
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
                    .toolbar {
#if os(iOS)
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button {
                                    Task {
                                        await diagnosticsExportViewModel.exportDiagnostics(maxEvents: 200)
                                    }
                                } label: {
                                    Label("Export Diagnostics", systemImage: "square.and.arrow.up")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
#endif
                    }
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
        .tint(FeedTrackerPalette.accent)
#if os(iOS)
        .sheet(isPresented: exportSheetBinding) {
            if let exportURL = diagnosticsExportViewModel.exportURL {
                ActivityShareSheet(activityItems: [exportURL])
            }
        }
#endif
        .alert("Diagnostics Export Failed", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) {
                diagnosticsExportViewModel.clearError()
            }
        } message: {
            Text(diagnosticsExportViewModel.lastErrorMessage ?? "Unknown error")
        }
    }

#if os(iOS)
    private var exportSheetBinding: Binding<Bool> {
        Binding(
            get: { diagnosticsExportViewModel.exportURL != nil },
            set: { isPresented in
                if !isPresented {
                    diagnosticsExportViewModel.clearExportURL()
                }
            }
        )
    }
#endif

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { diagnosticsExportViewModel.lastErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    diagnosticsExportViewModel.clearError()
                }
            }
        )
    }
}
#endif
