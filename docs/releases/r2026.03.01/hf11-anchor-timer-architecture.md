# HF11 — anchor-based timer rendering architecture

## Scope
Covers the HF11 hotfix on top of HF10 for release `r2026.03.01`.

## User-reported symptom
The active timer could temporarily stop moving and then jump several seconds later.

That symptom was still possible even after prior sync fixes because the product still depended on local per-second ticking in more than one place:
- the app active-session screen refreshed the `ActiveSessionViewModel` every second via `Timer.publish`
- the Live Activity / Dynamic Island widget re-projected elapsed time through `TimelineView(.periodic)`

When either surface was throttled, delayed, or coalesced by the system, the UI could visibly freeze and then catch up later.

## Root cause
The remaining issue was architectural rather than a single bug:
- elapsed time was still being *presented* as a locally ticking counter
- app UI and Live Activity owned separate ticking mechanisms
- Live Activity updates were still influenced by app-side periodic refresh behavior

That made timer smoothness depend on scheduled callbacks arriving on time.

## HF11 architecture change
HF11 moves timer presentation to a captured-anchor model:
- each `SessionTimerSnapshot` now records `capturedAt`
- app and Live Activity both derive display baselines from the same captured snapshot
- displayed side seconds are snapshotted once, then advanced from that checkpoint instead of mutating counters every second
- the app active-session screen no longer uses `Timer.publish` to refresh the view model
- the Live Activity / Dynamic Island widget no longer uses `TimelineView(.periodic)` for timer text
- running timer text in the widget is rendered from system timer/date rendering (`Text(..., style: .timer)`) using anchor dates derived from app-authored state

## New rendering model
### App surface
- `ActiveSessionViewModel` still owns session state transitions and persistence.
- `ActiveSessionView` now renders the active metrics from a captured display baseline.
- A `TimelineView` is used only as a foreground view-time source; it does **not** mutate session state.
- Displayed totals are still derived from displayed left + displayed right so the in-app surface stays phase-aligned.

### Live Activity / Dynamic Island
- Content state now stores app-authored displayed baselines plus `capturedAt`.
- Running active/total timers are rendered from anchor dates (`capturedAt - displayedElapsed`) so the system owns continuous timer progression.
- This removes dependency on widget-local one-second callback delivery.

## Observability improvements
Live Activity lifecycle diagnostics now include:
- `capturedAt`
- `displayedLeftElapsed`
- `displayedRightElapsed`
- `displayedTotalElapsed`

That makes future timer investigations traceable to the exact authored display checkpoint, instead of only raw lifecycle events.

## Validation evidence
### Automated
- `swift test`
- `xcodebuild -project FeedTracker.xcodeproj -scheme FeedTracker -configuration Debug -destination 'generic/platform=iOS Simulator' build`

### Key updated coverage
- `SessionTimerDisplayProjectionTests.testProjectedValuesAdvanceOnlyOnWholeSecondBoundariesFromCapturedBaseline`
- `LiveActivityLifecycleTests.testRunningContentStatePreservesRawBaselineAndProjectsDisplayedSecondsFromAppState`
- `ActiveSessionViewModelTests.testRefreshUsesSharedDisplayedSecondsForAppSurface`

## Risk notes
- Display continuity is now intentionally based on captured whole-second baselines rather than fragile free-running local ticks.
- This is a larger but more reliable architecture change: timer correctness now depends on stable timestamps and authored anchors, not on per-surface callback cadence.
