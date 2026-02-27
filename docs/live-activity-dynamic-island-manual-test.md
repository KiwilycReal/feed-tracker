# Live Activity / Dynamic Island Manual Test Script (AC-MVP-10)

## Preconditions
- iOS 17+ device or simulator target that supports Live Activities.
- Build uses this branch changes including:
  - `LiveActivityQuickActionHandler`
  - `FeedTrackerLiveActivityAttributes`
  - `LiveActivityQuickActionRouter`
- Notifications + Live Activities permissions granted.

## Quick Action Deep Links
- Start Left: `feedtracker://live-activity?action=start_left`
- Start Right: `feedtracker://live-activity?action=start_right`
- End Session: `feedtracker://live-activity?action=end_session`

## Test Steps
1. Launch app and open active session screen.
2. Trigger quick action **Start Left** from Live Activity / Dynamic Island.
   - Expected: timer state becomes running, active side is left.
3. Wait ~10 seconds, then trigger quick action **Start Right**.
   - Expected: side switches to right, left elapsed remains accumulated, total keeps increasing.
4. Wait ~10 seconds, then trigger quick action **End Session**.
   - Expected: session ends and writes one completed record to history.
5. Open history list.
   - Expected: latest record has non-zero total duration and reflects the final side durations.

## Optional Simulator Helper
```bash
./scripts/manual_live_activity_quick_actions.sh
```

## Automated Unit Evidence
- `Tests/FeedTrackerCoreTests/LiveActivityQuickActionHandlerTests.swift`
  - start/switch/end quick actions
  - URL deep-link routing (`handle(url:)`)
  - pause/resume quick action continuity
  - persistence write on end-session action
  - explicit post-end guard (`cannotStartAfterSessionEnded`)
