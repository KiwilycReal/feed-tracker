# Siri Shortcuts Manual Test Script (AC-P1-13)

## Preconditions
- Device/simulator runs iOS 17+ (or macOS 14+ for AppIntents validation).
- Build includes:
  - `SiriShortcutsHandler`
  - `OpenFeedTrackerIntent`
  - `StartFeedTrackingIntent`
  - `ReadFeedTrackingStatusIntent`
  - `FeedTrackerAppShortcutsProvider`
- App has wired `FeedTrackerSiriIntentDependency.handler` during app startup.
- Siri + Shortcuts permissions are granted.

## Shortcut Coverage
- Open app: **Open Feed Tracker**
- Start tracking: **Start Feed Tracking** (left/right/default strategy)
- Read status: **Read Feed Tracking Status**

## Test Steps
1. Trigger **Open Feed Tracker**.
   - Expected: app opens into feed tracker flow.
2. Trigger **Start Feed Tracking** with side = `Default Side`.
   - Expected: active session starts using configured default side.
3. Wait ~10 seconds.
4. Trigger **Read Feed Tracking Status**.
   - Expected spoken/dialog phrase includes active side + total elapsed (e.g. `Left side active. Total elapsed 00:10.`).
5. Trigger **Start Feed Tracking** again with explicit opposite side.
   - Expected: running side switches, total elapsed keeps accumulating.
6. Trigger **Read Feed Tracking Status** again.
   - Expected phrase reports updated side + accumulated total elapsed.

## Siri Phrase Suggestions
- “Open Feed Tracker”
- “Start Feed Tracking”
- “Start Right Feed Tracking”
- “Read Feed Tracking Status”

## Optional CLI Helper
```bash
./scripts/manual_siri_shortcuts.sh
```

## Automated Unit Evidence
- `Tests/FeedTrackerCoreTests/SiriShortcutsHandlerTests.swift`
  - default/explicit side start behavior
  - running/paused phrase generation
  - post-end start guard
  - AppIntents bridge execution coverage
