# AC-MVP-11 UI Review Checklist — Main Navigation + Visual Clarity

## Scope
Validate the first visual vertical slice with two primary pages:
- Active Session
- History

## Evidence in Code
- `Sources/FeedTrackerCore/UI/FeedTrackerMainNavigationView.swift`
- `Sources/FeedTrackerCore/UI/ActiveSessionView.swift`
- `Sources/FeedTrackerCore/UI/HistoryListView.swift`

## Review Checklist
- [x] App shell provides explicit main navigation with at least two pages (Active / History).
- [x] Active page highlights session status and key metrics (left/right/total) with clear visual hierarchy.
- [x] Active page actions are obvious and easy to trigger (start left/right, pause, resume, end).
- [x] History page provides readable chronological records and explicit delete affordance.
- [x] Empty state avoids blank screen and explains expected data.
- [x] Accent and spacing are consistent with minimal/clean/cute baseline.

## Screenshot Capture Plan (manual)
Capture and attach these screenshots in PR evidence:
1. `active-session-main.png` — Active tab with running session metrics.
2. `active-session-actions.png` — Active tab action row visible.
3. `history-list-main.png` — History tab with at least one completed session.
4. `history-empty-state.png` — History tab when no session exists.

## Design Notes
- Pink accent tint + rounded card blocks for a soft, family-friendly tone.
- Monospaced timer values to reduce scan friction during real-time updates.
- Status dot + label for immediate readability under sleep-deprived usage conditions.
