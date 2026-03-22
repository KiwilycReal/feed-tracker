# HF7 — Live Activity quick-action host reconciliation

## Problem restatement

HF4/HF5/HF6 improved render coordination and app-owned reconciliation, but the on-device symptom persisted:

- Live Activity quick actions changed the real session state correctly.
- The visible Live Activity / Dynamic Island UI still did not refresh immediately.
- Foregrounding the app caused the UI to catch up.

That symptom pattern points to a host-boundary problem, not a business-state problem.

## Root cause hypothesis

The quick-action `LiveActivityIntent` lived only in the widget extension target.
That meant the system could execute the action entirely in the extension host, where we were relying on direct `Activity.update/end` plus a Darwin signal.

HF6 made the app a better reconciler, but Darwin notifications do **not** wake a suspended app into existence. So when the app process was not already alive, the app-owned reconcile path never ran until the user foregrounded the app.

## HF7 architecture change

HF7 moves the Live Activity AppIntent definition into `FeedTrackerCore`, so the same intent type is linked into:

- the iOS app target
- the Live Activity widget extension target

The runtime now follows this execution policy:

1. Prefer an app-host executor (`FeedTrackerLiveActivityIntentDependency.executor`).
2. In the app host, preload recovery state, execute the quick action against the app-owned engine/repository, persist recovery state, refresh history, and request app-owned Live Activity reconcile immediately.
3. Only if no app-host executor is available, fall back to the widget-extension path that mutates shared state and attempts direct `ActivityKit` refresh.

This removes the previous architectural dependency on “extension updates the visible activity directly or the user later foregrounds the app”.

## Observability added

`ExternalSyncContext` now captures:

- `executionHost`
- `refreshStrategy`

This makes future diagnostics able to distinguish:

- app-hosted reconcile (`executionHost=app`, `refreshStrategy=app_live_activity_coordinator`)
- widget fallback (`executionHost=widget_extension`, `refreshStrategy=activitykit_direct_refresh`)

The app also logs preload/persist/reconcile events for the app-hosted intent path.

## Evidence collected

Local verification completed:

- `swift test` ✅
- `xcodebuild -scheme FeedTracker -project FeedTracker.xcodeproj -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` ✅
- Xcode extracted App Intents metadata for both:
  - `FeedTrackerCore.appintents`
  - `FeedTrackerLiveActivityWidgetExtension.appex/Metadata.appintents`

That confirms the shared Live Activity intent now builds into both the app and extension products, which is the key prerequisite for host-side execution handoff.

## Manual verification focus

Manual QA should re-run:

- pause from Live Activity
- resume from Live Activity
- stop from Live Activity
- switch side from Live Activity
- repeated quick actions without foregrounding the app

And confirm diagnostics/export markers show the expected execution host and refresh strategy.
