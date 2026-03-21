# HF6 Evidence Note — Live Activity quick-action refresh ownership

## Root-cause diagnosis

HF6 treats the stale-on-device refresh bug as a **process-boundary / reconcile-trigger defect**, not a session-persistence defect:

1. Live Activity quick actions already mutate the authoritative session state correctly in shared storage.
2. The extension-side `Activity.update/end` path is only a **best-effort direct refresh** of the currently displayed activity.
3. When that extension-side refresh misses the visible activity (or is otherwise dropped), the app previously had **no immediate reconcile trigger** unless a later lifecycle event happened (`launch`, `scenePhase`, URL open).
4. That made app lifecycle re-entry the only consistently successful path for refreshing the displayed Live Activity instance.

## HF6 fix

HF6 adds an explicit cross-process refresh handoff:

- Widget / Live Activity intent still performs the shared-state mutation.
- The intent records an `ExternalSyncContext` payload with:
  - action
  - target session id
  - render version
  - extension-side displayed refresh attempt outcome
- The intent then posts a Darwin notification (`com.kiwilyc.feedtracker.live-activity-external-sync.v1`).
- The app now listens for that signal and immediately runs:
  - external recovery reload
  - history reload
  - app-owned Live Activity reconcile

So the displayed Live Activity no longer depends only on future app foreground/lifecycle re-entry to get reconciled.

## Observability added

### Shared context
`FeedTrackerSharedStorage.ExternalSyncContext` now persists the latest external sync request context.

### App diagnostics
The iOS app logs `live_activity_signal / received_external_sync_signal` with metadata including:
- sync marker
- context source
- reason
- quick action
- session id
- render version
- extension-side displayed refresh attempt
- marker mismatch flag (if context and marker diverge)

### Extension-side evidence
The Live Activity intent records the best-effort displayed refresh outcome as one of:
- `updated_visible_activity`
- `ended_visible_activity`
- `skipped_idle_state`
- `skipped_no_visible_activity`
- `skipped_stale_render_version`

This makes future failures diagnosable as either:
- extension resolved and updated the visible activity directly, or
- extension failed / skipped and the app-side reconcile path had to take over.
