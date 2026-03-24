# HF9 — Live Activity fit + timer sync + quick-action latency

## Scope
Covers the resumed HF9 hotfix on top of HF8 for release `r2026.03.01`.

## What changed
- Tightened the expanded Dynamic Island layout so the content fits the island envelope more safely:
  - top metadata now sits in the top-left / top-right corners instead of reserving a rigid top row height
  - reduced middle-row spacing, timer card padding, timer typography, and quick-action button height to avoid lower-edge clipping
- Made the Live Activity timer presentation render from a single app-authored checkpoint:
  - app-hosted refreshes now reconcile Live Activity state from `ActiveSessionViewModel.refresh(at:)`, deduped to one reconcile per displayed second
  - Live Activity content state also exposes a shared projection model and snaps running checkpoints to whole-second boundaries so active + total timers render from the same baseline
- Reduced widget-fallback quick-action latency further:
  - direct ActivityKit refresh now returns without waiting for deferred repository persistence to drain
  - recovery-state continuity still happens before the refresh, so runtime continuity remains intact

## Why this hotfix exists
HF8 improved the direction and interaction model, but QA still found three visible problems:
1. expanded Dynamic Island content could still clip at the bottom edge
2. the requested top-corner metadata treatment was not exact enough
3. active + total timers could visibly tick out of phase because the Live Activity view was rendering from separately phased timer projections

HF9 addresses those issues together without changing the core quick-action surface.

## Validation evidence
### Automated
- `swift test`
- `xcodebuild -project FeedTracker.xcodeproj -scheme FeedTracker -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

### Added / updated tests
- `ActiveSessionViewModelTests.testRefreshAlsoReconcilesLiveActivityFromAppTick`
  - verifies app-driven refreshes reconcile Live Activity once per displayed second
- `LiveActivityLifecycleTests.testProjectedDisplayKeepsActiveAndTotalTimersOnSharedCheckpoint`
  - verifies active + total projections come from the same app-authored checkpoint
- `LiveActivityLifecycleTests.testRunningContentStateSnapsDisplayCheckpointToWholeSecondBoundary`
  - verifies running Live Activity content state is snapped to a shared whole-second checkpoint

## Risk notes
- The Live Activity still uses the system-rendered time label for the top-right clock, with `en_GB` locale to preserve 24-hour format.
- Timer projection stays continuous, but now starts from shared app-authored checkpoints so active and total timer text no longer drift in visible phase.
- Widget-fallback persistence remains deferred; repository/history writes can finish after the Live Activity surface has already refreshed.
