# Live Activity / Dynamic Island Manual Test Script (AC-MVP-10)

## Preconditions
- iOS 17+ device or simulator target that supports Live Activities.
- Build uses this branch changes including:
  - `LiveActivityQuickActionHandler`
  - `FeedTrackerLiveActivityAttributes`
- Notifications + Live Activities permissions granted.

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

## Automated Unit Evidence
- `Tests/FeedTrackerCoreTests/LiveActivityQuickActionHandlerTests.swift`
  - start/switch/end quick actions
  - pause/resume quick action continuity
  - persistence write on end-session action
  - explicit post-end guard (`cannotStartAfterSessionEnded`)
