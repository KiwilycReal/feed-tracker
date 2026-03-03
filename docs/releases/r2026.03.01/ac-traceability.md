# AC Traceability — r2026.03.01

- MODE: RELEASE
- RELEASE_ID: r2026.03.01
- HOTFIX_ID: none
- MVP_PLAN_VERSION: v1

## AC Table

| AC ID | MVP | Requirement | Scene Coverage | Verification Method | Expected Evidence Location |
|---|---|---|---|---|---|
| AC-R2026.03.01-01 | MVP-01 | Active feeding session keeps Live Activity visible after app background/exit (no session loss). | foreground, background, app exited/relaunch, lock screen | integration test + manual script | `Tests/FeedTrackerCoreTests/LiveActivityLifecycleTests.swift` + `docs/releases/r2026.03.01/evidence/manual-live-activity-lifecycle.md` |
| AC-R2026.03.01-02 | MVP-01 | Dynamic Island compact/minimal continuously shows current elapsed session timer. | compact island, foreground/background | manual script with timed checkpoints + screenshot/video capture | `docs/releases/r2026.03.01/evidence/dynamic-island-compact-timer.md` |
| AC-R2026.03.01-03 | MVP-02 | Dynamic Island expanded includes executable actions: switch side, pause, terminate. | expanded island (foreground/background) | unit tests for routing + manual execution script | `Tests/FeedTrackerCoreTests/LiveActivityQuickActionHandlerTests.swift` + `docs/releases/r2026.03.01/evidence/dynamic-island-expanded-actions.md` |
| AC-R2026.03.01-04 | MVP-02 | Lock screen Live Activity includes same executable actions: switch side, pause, terminate. | lock screen (screen locked while active session) | manual script + integration assertions on resulting state | `docs/releases/r2026.03.01/evidence/lockscreen-actions.md` |
| AC-R2026.03.01-05 | MVP-02 | Action-state consistency guaranteed (no duplicate transitions, no terminal-state mutation, no stale timer). | all scenes above | deterministic state-machine tests + diagnostic event assertions | `Tests/FeedTrackerCoreTests/SessionTimerEngineTests.swift` + `Tests/FeedTrackerCoreTests/LiveActivityLifecycleTests.swift` |

## Verification Notes
- All ACs require BOTH:
  1) automated evidence (unit/integration where applicable), and
  2) manual scene script evidence for Dynamic Island/lock screen surfaces.
- A single missing scene in coverage = AC not accepted.

## Pass/Fail Rule
- PASS only when evidence files are linked in PR description AC table with reproducible steps.
- FAIL if behavior works only in foreground but not in background/lock-screen contexts.
