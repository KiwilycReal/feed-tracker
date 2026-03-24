# HF8 — Live Activity / Dynamic Island redesign + quick-action latency hotfix

## Scope
Covers `AC-HF8-01..10` for release `r2026.03.01`.

## What changed
- Preserved the last active side in Live Activity content state even after pausing, so the expanded island layout remains stable and still shows the pre-pause side.
- Redesigned the Dynamic Island presentation into a 3-row composition:
  - top row: active side label + live 24h clock
  - middle row: large active-side timer (white), circular pause/resume control, total timer (timer yellow)
  - bottom row: switch + stop controls hugging the lower contour
- Updated compact island content so the active-side elapsed timer is visible alongside total elapsed time.
- Added active-side elapsed projection helpers for validation and future diagnostics.
- Reduced quick-action latency by moving repository persistence off the immediate render path:
  - widget fallback now refreshes ActivityKit before waiting for queued persistence
  - app-hosted intent execution now reconciles Live Activity immediately and reloads history asynchronously after persistence drains
- Added latency diagnostics around quick-action mutation and queued persistence stages.

## Validation evidence
### Automated
- `swift test`
- `xcodebuild -project FeedTrackerApp.xcodeproj -scheme FeedTrackerApp -destination 'generic/platform=iOS Simulator' build`
- `xcodebuild -project FeedTracker.xcodeproj -scheme FeedTracker -destination 'generic/platform=iOS Simulator' build`

### Added / updated tests
- `LiveActivityLifecycleTests.testCompactTimerProjectionStaysContinuousFromCapturedCheckpoint`
  - now verifies projected active-side elapsed time in addition to total elapsed time.
- `LiveActivityLifecycleTests.testPausedSnapshotPreservesLastActiveSideForLiveActivityLayout`
  - verifies paused snapshots preserve the last active side and keep projections stable.
- `LiveActivityQuickActionHandlerTests.testDeferredPersistenceLeavesMutatedStateAvailableBeforeRepositoryFlush`
  - verifies quick-action state mutation is visible before deferred persistence completes, then flushes to storage correctly.

## Risk notes
- The live 24h clock uses a forced `en_GB` locale in the widget view to ensure 24-hour formatting.
- Deferred repository persistence is serialized to preserve ordering across rapid quick actions.
- Activity recovery storage remains synchronous, so runtime continuity is preserved even though history reload moved off the critical UI path.
