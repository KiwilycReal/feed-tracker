# HF1 Manual Verification — Live Activity Enablement

Scope: `HF-r2026.03.01-hf1-LIVE-ACTIVITY-ENABLE`

## Preconditions
- Build from branch `hotfix/r2026.03.01-hf1-live-activity-enable`
- iOS 17+ physical device (Dynamic Island device preferred)
- TestFlight/internal build installed

## Verification Steps
1. Open **Settings → FeedTracker** and confirm **Live Activities** toggle exists.
2. Launch app and start a feed session.
3. Lock screen: confirm Live Activity appears with timer + actions.
4. Open Dynamic Island (expanded): confirm **Switch / Pause / End** actions visible.
5. Tap each action and verify app state transitions:
   - Switch: side toggles with continuous elapsed accumulation
   - Pause: timer stops increasing while paused
   - End: session terminates and history receives completed entry
6. Relaunch app and verify no crash/regression in active-session screen.

## Expected screenshots
- `docs/releases/r2026.03.01/evidence/artifacts/hf1-settings-live-activities-toggle.png`
- `docs/releases/r2026.03.01/evidence/artifacts/hf1-lockscreen-live-activity.png`
- `docs/releases/r2026.03.01/evidence/artifacts/hf1-dynamic-island-expanded-actions.png`
- `docs/releases/r2026.03.01/evidence/artifacts/hf1-action-result-in-app.png`

## Acceptance
- Live Activities setting is present.
- Live Activity card renders on lock screen / island.
- Actions are functional and behavior matches in-app state machine.
