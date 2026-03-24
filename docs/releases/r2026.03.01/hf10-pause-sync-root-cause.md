# HF10 — pause/sync root-cause fix + top inset + Chinese side labels

## Scope
Covers the HF10 hotfix on top of HF9 for release `r2026.03.01`.

## Root-cause analysis
HF9 reduced visible latency by refreshing Live Activity earlier, but one remaining sync defect was still possible around pause/resume boundaries.

The root cause was not only refresh timing. It was also a display-model mismatch:
- the app surface was presenting elapsed time with rounded whole-second text
- the Live Activity content state was freezing a floored whole-second checkpoint when the timer stopped advancing
- around fractional boundaries (for example ~`8.6s`), the app could visibly show the next second while the paused Live Activity froze the previous second

That made the problem look like "latency", but the deeper issue was that the widget was still re-deriving display seconds differently from the app-authored timer state.

## What changed
- Replaced the Live Activity's floor-based checkpoint model with a shared display-projection model:
  - content state now preserves the app-authored raw side elapsed baselines plus exact capture time
  - projection rounds each side's displayed seconds from that app-authored state
  - total displayed time is derived from displayed left + displayed right so active + total stay phase-aligned
- Reused the same display projection on the app surface:
  - active session cards now render `displayedLeftElapsed`, `displayedRightElapsed`, and `displayedTotalElapsed`
  - app-side Live Activity reconcile dedupe now keys off the same displayed values instead of floored raw seconds
- Adjusted Dynamic Island top content inward slightly to reduce cutoff risk at the top corners.
- Localized side labels to Chinese `左` / `右` in Dynamic Island compact and expanded treatments.

## Why this hotfix exists
HF9 fixed fit and refresh behavior, but QA could still observe a residual "pause/sync lag" symptom. HF10 addresses the deeper cause by making display seconds app-authored and shared, instead of letting the Live Activity invent its own paused checkpoint semantics.

## Validation evidence
### Automated
- `swift test`
- `xcodebuild -project FeedTrackerApp.xcodeproj -scheme FeedTrackerApp -destination 'generic/platform=iOS Simulator' build`
- `xcodebuild -project FeedTracker.xcodeproj -scheme FeedTracker -destination 'generic/platform=iOS Simulator' build`

### Added / updated tests
- `SessionTimerDisplayProjectionTests.testSnapshotValuesRoundEachSideAndDeriveTotalFromDisplayedSides`
- `SessionTimerDisplayProjectionTests.testProjectedValuesFreezePauseWithoutDroppingDisplayedSecond`
- `SessionTimerDisplayProjectionTests.testProjectedValuesAdvanceActiveAndTotalTogetherFromAppAuthoredBaseline`
- `LiveActivityLifecycleTests.testPausedContentStateKeepsRoundedDisplayedSecondAfterPauseBoundary`
- `LiveActivityLifecycleTests.testRunningContentStatePreservesRawBaselineAndProjectsDisplayedSecondsFromAppState`
- `ActiveSessionViewModelTests.testRefreshUsesSharedDisplayedSecondsForAppSurface`

## Risk notes
- Display semantics now intentionally derive total from displayed side values, not from separately rounded raw total elapsed.
- This is a broader but lower-risk consistency refactor: the app and Live Activity now share one display projection model.
- Dynamic Island top spacing is slightly more inset, so visual QA should verify compact/expanded balance on-device.
