#if canImport(SwiftUI) && (os(iOS) || os(watchOS))
import SwiftUI

@MainActor
public struct ActiveSessionView: View {
    @StateObject private var viewModel: ActiveSessionViewModel
    @State private var actionErrorMessage: String?
    private let refreshEvery: TimeInterval

    public init(viewModel: @autoclosure @escaping () -> ActiveSessionViewModel, refreshEvery: TimeInterval = 1) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.refreshEvery = refreshEvery
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusCard
                metricsCard
                actionsCard
            }
            .padding(16)
        }
        .background(FeedTrackerPalette.pageBackground.ignoresSafeArea())
        .onReceive(
            Timer.publish(every: refreshEvery, on: .main, in: .common).autoconnect()
        ) { _ in
            viewModel.refresh()
        }
        .alert("Action failed", isPresented: actionErrorBinding) {
            Button("OK", role: .cancel) {
                actionErrorMessage = nil
            }
        } message: {
            Text(actionErrorMessage ?? "Unknown error")
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(SessionPresentation.statusTitle(for: viewModel.displayState.state))
                    .font(.headline)
                    .foregroundStyle(FeedTrackerPalette.primaryText)
                Text(SessionPresentation.statusSubtitle(for: viewModel.displayState.state))
                    .font(.subheadline)
                    .foregroundStyle(FeedTrackerPalette.secondaryText)
            }
        }
        .feedTrackerCardStyle()
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Session")
                .font(.headline)
                .foregroundStyle(FeedTrackerPalette.primaryText)

            VStack(spacing: 8) {
                metricRow(title: "Left", value: SessionPresentation.durationText(viewModel.displayState.displayedLeftElapsed), tint: FeedTrackerPalette.leftSide)
                metricRow(title: "Right", value: SessionPresentation.durationText(viewModel.displayState.displayedRightElapsed), tint: FeedTrackerPalette.rightSide)
                metricRow(title: "Total", value: SessionPresentation.durationText(viewModel.displayState.displayedTotalElapsed), tint: FeedTrackerPalette.accent)
            }
        }
        .feedTrackerCardStyle()
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(FeedTrackerPalette.primaryText)

            HStack(spacing: 10) {
                actionButton(title: "Left", systemImage: "l.circle.fill", tint: FeedTrackerPalette.leftSide) {
                    handleSideSelection(.left)
                }

                actionButton(title: "Right", systemImage: "r.circle.fill", tint: FeedTrackerPalette.rightSide) {
                    handleSideSelection(.right)
                }
            }

            HStack(spacing: 10) {
                if isPaused {
                    actionButton(title: "Resume", systemImage: "play.fill", tint: FeedTrackerPalette.success) {
                        do {
                            try viewModel.resume()
                        } catch {
                            present(error)
                        }
                    }
                } else {
                    actionButton(title: "Pause", systemImage: "pause.fill", tint: FeedTrackerPalette.secondaryText) {
                        do {
                            try viewModel.pause()
                        } catch {
                            present(error)
                        }
                    }
                    .disabled(!isRunning)
                }

                actionButton(title: "End", systemImage: "stop.fill", tint: .red) {
                    Task {
                        do {
                            _ = try await viewModel.endSession()
                        } catch {
                            present(error)
                        }
                    }
                }
                .disabled(!canEndSession)
            }
        }
        .feedTrackerCardStyle()
    }

    private var statusColor: Color {
        switch viewModel.displayState.state {
        case .idle:
            FeedTrackerPalette.secondaryText
        case .running:
            FeedTrackerPalette.success
        case .paused:
            FeedTrackerPalette.rightSide
        case .stopped:
            FeedTrackerPalette.leftSide
        case .ended:
            FeedTrackerPalette.accent
        }
    }

    private var isRunning: Bool {
        if case .running = viewModel.displayState.state {
            return true
        }
        return false
    }

    private var isPaused: Bool {
        if case .paused = viewModel.displayState.state {
            return true
        }
        return false
    }

    private var canEndSession: Bool {
        switch viewModel.displayState.state {
        case .idle, .ended:
            false
        case .running, .paused, .stopped:
            true
        }
    }

    private func handleSideSelection(_ side: FeedingSide) {
        do {
            switch viewModel.displayState.state {
            case .idle, .stopped, .ended:
                try viewModel.start(side: side)
            case .running(let activeSide):
                guard activeSide != side else { return }
                try viewModel.switchSide(to: side)
            case .paused(let pausedSide):
                try viewModel.resume()
                if pausedSide != side {
                    try viewModel.switchSide(to: side)
                }
            }
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        actionErrorMessage = (error as NSError).localizedDescription
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { actionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    actionErrorMessage = nil
                }
            }
        )
    }

    private func metricRow(title: String, value: String, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: "timer")
                .font(.subheadline)
                .foregroundStyle(FeedTrackerPalette.secondaryText)
            Spacer()
            Text(value)
                .font(.system(.title3, design: .rounded).monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 4)
    }

    private func actionButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}
#endif
