# HF2 Evidence — Live Activity UX + Home Timer Reset

## Scope
HF2 covers AC-HF2-01..06 from the thread checkpoint:
1. Dynamic Island compact safe padding, no edge clipping
2. Compact emphasis = 中文 side label (`左/右`) + timer + status icon
3. Expanded island buttons are large/easy to tap and execute directly without launching app
4. Pause toggles to resume immediately from expanded island without app launch
5. Lock screen Live Activity keeps the same direct-action behavior and prominent timer treatment
6. App home timer resets to zero after a session ends (no stale prior-session values)

## Code Evidence
- `LiveActivityWidgetExtension/FeedTrackerLiveActivityWidget.swift`
  - compact leading now shows concise `左/右`
  - compact trailing shows timer + status icon with extra inner padding to avoid edge clipping
  - expanded and lock-screen controls use large circular buttons (`48x48`) for switch / pause-resume / end
  - non-button surface still uses `.widgetURL(...)`, while action buttons execute through `Button(intent: ...)`
  - lock-screen timer uses the same prominent elapsed rendering strategy as island surfaces
- `LiveActivityWidgetExtension/FeedTrackerLiveActivityIntents.swift`
  - adds `LiveActivityIntent`-backed direct actions for switch / pause-resume / terminate
  - executes mutations without opening the app (`openAppWhenRun = false`)
  - refreshes or ends the active Live Activity after each action
- `Sources/FeedTrackerCore/Features/LiveActivityQuickActionHandler.swift`
  - pause action now toggles back to resume when current state is paused
- `Sources/FeedTrackerCore/Features/ActiveSessionViewModel.swift`
  - ended session snapshots are normalized back to `.idle` for the home screen display
  - elapsed values return to zero after session completion

## Automated Verification
### Commands run
```bash
swift test
xcodebuild -project FeedTracker.xcodeproj -scheme FeedTracker -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

### Result
- `swift test` ✅
- `xcodebuild ... build` ✅

## Test Evidence Mapping
- AC-HF2-03 / AC-HF2-04 / AC-HF2-05 direct action state behavior
  - `Tests/FeedTrackerCoreTests/LiveActivityQuickActionHandlerTests.swift`
  - `testPauseSessionTogglesToResumeWhenAlreadyPaused`
  - `testSwitchSideTogglesFromRunningState`
  - `testTerminateSessionPersistsCompletedSession`
- AC-HF2-06 home timer reset
  - `Tests/FeedTrackerCoreTests/ActiveSessionViewModelTests.swift`
  - `testDisplayResetsToZeroAfterEndingSession`
- Continuous timer projection backing compact timer presentation
  - `Tests/FeedTrackerCoreTests/LiveActivityLifecycleTests.swift`
  - `testCompactTimerProjectionStaysContinuousFromCapturedCheckpoint`

## Manual Surface Checkpoints
These still need final human verification on a real Dynamic Island device / lock screen surface:
- compact island visual padding and clipping
- compact Chinese side label readability
- direct-tap feel on expanded island buttons
- lock-screen button ergonomics and parity

Recommended reference scripts/docs:
- `docs/releases/r2026.03.01/evidence/dynamic-island-compact-timer.md`
- `docs/releases/r2026.03.01/evidence/dynamic-island-expanded-actions.md`
- `docs/releases/r2026.03.01/evidence/lockscreen-actions.md`

## Risk Notes
- Build is clean and behavior is covered by automated state tests.
- Xcode still reports non-blocking AppIntent availability warnings for synthesized accessors in the widget intent file; build succeeds and functionality is unaffected.
