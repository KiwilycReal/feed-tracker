import Foundation

public enum SessionPresentation {
    public static func statusTitle(for state: SessionTimerState) -> String {
        switch state {
        case .idle:
            "Ready to start"
        case .running(let side):
            "Running · \(side.rawValue.capitalized)"
        case .paused(let side):
            "Paused · \(side.rawValue.capitalized)"
        case .stopped:
            "Stopped"
        case .ended:
            "Session completed"
        }
    }

    public static func statusSubtitle(for state: SessionTimerState) -> String {
        switch state {
        case .idle:
            "Tap left or right to start tracking."
        case .running:
            "Timer updates live every second."
        case .paused:
            "Resume to continue, or end the session."
        case .stopped:
            "Start left or right to continue this session."
        case .ended:
            "Start a new session when ready."
        }
    }

    public static func durationText(_ value: TimeInterval) -> String {
        let rounded = max(0, Int(value.rounded()))
        let hours = rounded / 3600
        let minutes = (rounded % 3600) / 60
        let seconds = rounded % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}
