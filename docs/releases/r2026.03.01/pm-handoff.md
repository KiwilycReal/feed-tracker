# PM Handoff — r2026.03.01

- MODE: RELEASE
- RELEASE_ID: r2026.03.01
- HOTFIX_ID: none
- Current SemVer baseline: 0.1.0
- Release target version: 0.2.0 (tag `v0.2.0` after QA)

## Source of Truth
- `docs/releases/r2026.03.01/mvp-plan.md`
- `docs/releases/r2026.03.01/ac-traceability.md`

## Developer Dispatch Order (strict)

### Dispatch 1 — MVP-01
Branch naming:
- `feature/r2026.03.01-MVP-01-live-activity-lifecycle`

Required deliverables:
1. Live Activity lifecycle continuity across foreground/background/exit.
2. Compact/minimal Dynamic Island timer continuity.
3. Recovery-safe state sync for elapsed timer after relaunch.
4. Evidence docs for lifecycle/compact timer scenes.

Must satisfy ACs:
- AC-R2026.03.01-01
- AC-R2026.03.01-02

### Dispatch 2 — MVP-02
Branch naming:
- `feature/r2026.03.01-MVP-02-action-parity`

Required deliverables:
1. Expanded Dynamic Island actions: switch side, pause, terminate.
2. Lock screen actions with same capability and behavior parity.
3. Race-safe and idempotent action routing guards.
4. Evidence docs for expanded and lock-screen action scripts.

Must satisfy ACs:
- AC-R2026.03.01-03
- AC-R2026.03.01-04
- AC-R2026.03.01-05

## PR Requirements (each MVP)
- PR title: `[MVP-0X] <type(scope): summary>`
- Include AC evidence table with explicit links to test files + manual evidence docs.
- Include rollback section with exact revert command for merge commit.
- CI gates all green before merge.

## Release Preparation After MVP-02 Merge
1. Merge latest `main` into `release/r2026.03.01`.
2. Bump marketing version to `0.2.0` (MINOR rule) and increment build number.
3. Run release workflow for TestFlight on `release/r2026.03.01`.
4. Provide run URL + artifact evidence + QA checklist handoff.

## Exact Handoff Command
`sessions_send dev-1476823938343374879 "MODE=RELEASE RELEASE_ID=r2026.03.01 HOTFIX_ID=none MVP_ID=MVP-01. Implement Dispatch 1 from docs/releases/r2026.03.01/pm-handoff.md and satisfy AC-R2026.03.01-01..02 with tests + manual evidence docs. Open PR with AC table + rollback. Do not BLOCK unless strict human-only input is required."`
