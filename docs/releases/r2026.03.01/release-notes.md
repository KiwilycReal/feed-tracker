# Release Notes — r2026.03.01

## Release identity
- Release branch: `release/r2026.03.01`
- Version: `0.2.0`
- Build: `20260304073001`
- Base commit: `dc14022` (latest `main` at release prep)

## Highlights
- MVP-01 delivered (PR #26):
  - Live Activity lifecycle continuity across foreground/background/relaunch
  - Compact/minimal Dynamic Island timer continuity projection
- MVP-02 delivered (PR #27):
  - Expanded Dynamic Island actions: switch side / pause / terminate
  - Lock screen action parity
  - Race-safe & idempotent action routing guards

## Included PRs (release scope)
- #26: https://github.com/KiwilycReal/feed-tracker/pull/26
- #27: https://github.com/KiwilycReal/feed-tracker/pull/27

## Automated validation snapshot (release prep)
- `swift test` passed (57 tests)
- iOS simulator build passed

## TestFlight release run
- Trigger source: `release/r2026.03.01`
- Workflow: `.github/workflows/release.yml`
- Run URL: (filled after dispatch)

## Notes
- This release contains no schema-breaking migration change.
- Existing diagnostics export and active-session recovery remain enabled.
