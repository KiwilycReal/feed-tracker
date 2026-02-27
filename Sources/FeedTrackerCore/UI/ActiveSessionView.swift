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
        VStack(alignment: .leading, spacing: 14) {
            statusBadge

            VStack(spacing: 10) {
                metricRow(title: "Left", value: format(viewModel.displayState.leftElapsed))
                metricRow(title: "Right", value: format(viewModel.displayState.rightElapsed))
                metricRow(title: "Total", value: format(viewModel.displayState.totalElapsed), emphasize: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pink.opacity(0.08))
            )

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Start Left") {
                        activate(side: .left)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Start Right") {
                        activate(side: .right)
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 8) {
                    Button("Pause") {
                        do {
                            try viewModel.pause()
                        } catch {
                            actionErrorMessage = error.localizedDescription
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Resume") {
                        do {
                            try viewModel.resume()
                        } catch {
                            actionErrorMessage = error.localizedDescription
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("End Session") {
                        Task {
                            do {
                                _ = try await viewModel.endSession()
                            } catch {
                                actionErrorMessage = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
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

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text("Status: \(stateLabel)")
                .font(.subheadline.weight(.semibold))
        }
    }

    private var statusColor: Color {
        switch viewModel.displayState.state {
        case .running:
            return .green
        case .paused:
            return .orange
        case .stopped, .idle, .ended:
            return .gray
        }
    }

    private var stateLabel: String {
        switch viewModel.displayState.state {
        case .running(let side):
            return "Running (\(side.rawValue.capitalized))"
        case .paused(let side):
            return "Paused (\(side.rawValue.capitalized))"
        case .stopped:
            return "Stopped"
        case .ended:
            return "Ended"
        case .idle:
            return "Idle"
        }
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

    private func metricRow(title: String, value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(emphasize ? .title3.weight(.bold) : .headline)
                .monospacedDigit()
        }
    }

    private func activate(side: FeedingSide) {
        do {
            switch viewModel.displayState.state {
            case .idle, .stopped:
                try viewModel.start(side: side)
            case .running(let activeSide):
                guard activeSide != side else { return }
                try viewModel.switchSide(to: side)
            case .paused(let pausedSide):
                try viewModel.resume()
                guard pausedSide != side else { return }
                try viewModel.switchSide(to: side)
            case .ended:
                actionErrorMessage = "Session already ended. Start a new session from app root."
            }
        } catch {
            actionErrorMessage = error.localizedDescription
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
