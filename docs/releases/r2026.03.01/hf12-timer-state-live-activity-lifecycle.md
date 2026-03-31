# HF12 — timer-state and Live Activity lifecycle re-architecture

## Scope
Covers hotfix `hf12` for release `r2026.03.01`.

## User-reported symptoms
HF12 addresses three related failures that could not be solved reliably with another surface-level patch:
- the expanded Dynamic Island top line could still clip against the capsule edge
- after moving between foreground/background, the Live Activity timer could briefly appear to jump too fast
- the Live Activity / Dynamic Island could disappear during a long-running session and fail to come back consistently

## Root cause
The remaining problems were all downstream of one architectural issue:
- timer business state, display checkpoints, persistence state, and ActivityKit lifecycle were still coupled too loosely
- multiple callers could keep rebuilding Live Activity content from ad-hoc snapshots instead of a stable timer clock model
- foreground refreshes could trigger unnecessary Live Activity reconciliation even when no authoritative state changed
- once the displayed Activity instance disappeared, the lifecycle layer did not have a clean, explicit way to decide whether to restart it from the same authoritative state

## HF12 architecture change
HF12 introduces a shared timer clock state as the bottom-layer source for both recovery and Live Activity rendering:
- `SessionTimerClockState` becomes the canonical serializable timer clock model
- the engine now derives both persistence recovery state and UI snapshots from that clock state
- Live Activity reconciliation now compares stable state tokens instead of per-refresh elapsed projections
- the app, quick-action fallback runtime, and lifecycle coordinator all author Live Activity content from the same clock-state representation
- redundant foreground refreshes are skipped when the visible Activity is already healthy, reducing unnecessary render churn
- if the visible Activity instance is gone, the same clock state can still restart it cleanly

## Lifecycle behavior changes
### App / foreground
- `ActiveSessionViewModel` now syncs Live Activity from `SessionTimerClockState`, not from a per-refresh snapshot token that included projected elapsed seconds.
- Foreground timer refreshes no longer force Live Activity lifecycle updates every second.

### Quick actions / widget-hosted intent fallback
- widget-hosted actions now refresh ActivityKit directly from the post-mutation clock state
- termination and idle handling are decided from the same canonical state model

### Coordinator
- the lifecycle coordinator now:
  - derives rendered content from clock state
  - records a last reconciled state token
  - skips redundant running-state reconciles only when the target activity is still active
  - restarts the activity when the same running state exists but the displayed instance has disappeared

## UI fit adjustment
To address the remaining top-line clipping in expanded Dynamic Island:
- increased top/leading/trailing padding for the top metadata rows
- added bottom padding and slightly more separation before the middle row

## Diagnostics and coverage
HF12 keeps the existing render-version diagnostics and adds/validates architecture-specific coverage:
- `ActiveSessionViewModelTests.testRefreshDoesNotReconcileLiveActivityOnEveryForegroundTick`
- `LiveActivityLifecycleTests.testRedundantRunningReconcileRestartsActivityIfDisplayedInstanceDisappears`
- `SessionTimerEngineTests.testClockStateProjectsRunningElapsedFromRecordedCheckpoint`
- `SessionTimerEngineTests.testClockStateRecoveryStateKeepsPausedSideWithoutRunningAnchor`

## Validation evidence
### Automated
- `swift test`
- `xcodebuild -project FeedTracker.xcodeproj -scheme FeedTracker -configuration Debug -destination 'generic/platform=iOS Simulator' build`

## Expected outcome
HF12 moves timer/lifecycle consistency to a shared state model:
- the app surface, Live Activity, and fallback intent runtime all derive from the same timer clock source
- background/foreground transitions no longer require frequent Live Activity rewrites just to keep elapsed time moving
- a missing displayed Live Activity can be recreated from authoritative state instead of silently drifting out of sync
- the expanded Dynamic Island top line gets additional inset to avoid clipping
