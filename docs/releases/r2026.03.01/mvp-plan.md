# feed-tracker Release MVP Plan (SoT)

- MVP_PLAN_VERSION: v1
- MODE: RELEASE
- RELEASE_ID: r2026.03.01
- HOTFIX_ID: none
- REPO: feed-tracker
- Planned SemVer: 0.2.0 (MINOR bump from 0.1.0)
- Planned tag: v0.2.0

## 1) Release Objective (only high-priority scope)
Deliver reliable Live Activity + Dynamic Island session continuity and interaction parity across foreground/background/lock screen contexts:
1. Live Activity remains visible while feeding is active, even after app exit.
2. Dynamic Island keeps showing current session timer.
3. Dynamic Island expanded view provides 3 actions: switch side, pause, terminate.
4. Lock screen Live Activity provides the same 3 actions: switch side, pause, terminate.

## 2) MVP Breakdown (minimum necessary)

### MVP-01 — Live Activity lifecycle continuity (display + timer consistency)
**Goal**: guarantee persistent, correct session display in Dynamic Island/lock screen across app lifecycle.

**In scope**
- ActivityKit lifecycle hardening for active feeding session.
- Session snapshot persistence for app background/termination recovery.
- Timer display consistency using persisted baseline + elapsed recalculation.
- Dynamic Island compact visibility for current active session timer.

**Out of scope**
- UI redesign outside Live Activity surface.
- New analytics backend.

### MVP-02 — Interactive controls parity (expanded island + lock screen)
**Goal**: ensure both surfaces expose identical, functional controls with state-safe behavior.

**In scope**
- Add/verify 3 controls on both surfaces: switch side, pause, terminate.
- Unified action routing + idempotency guards.
- Foreground/background action handling consistency.
- Manual scripts + automated evidence for all required scenes.

**Out of scope**
- Additional controls not requested (resume button as standalone surface button is optional if pause toggles state).

## 3) Acceptance Criteria (release-level)
- AC-R2026.03.01-01: Active session keeps Live Activity visible after app goes background or user exits app.
- AC-R2026.03.01-02: Dynamic Island (compact/minimal) continuously shows current session elapsed timer.
- AC-R2026.03.01-03: Dynamic Island expanded has exactly required actions (switch side, pause, terminate), all executable.
- AC-R2026.03.01-04: Lock screen Live Activity has same required actions and execution behavior.
- AC-R2026.03.01-05: Action results remain state-consistent (no duplicate transitions, no stale ended session mutation).

(Per-AC traceability and verification are defined in `ac-traceability.md`.)

## 4) Scene Matrix (must be explicitly covered)
- iOS foreground (app active)
- iOS background (home-screened)
- app exited/terminated and relaunched
- lock screen Live Activity
- Dynamic Island compact/minimal
- Dynamic Island expanded

## 5) Risks and Mitigations
1. **ActivityKit lifecycle drift** (activity stale or dropped after state transitions)
   - Mitigation: explicit activity state reconciliation on app lifecycle events; persistence-backed restore path.
2. **Timer inconsistency** (UI timer diverges from persisted session state)
   - Mitigation: single source-of-truth session clock model + deterministic elapsed recompute on restore.
3. **Action race conditions** (rapid taps in expanded/lock screen causing double transitions)
   - Mitigation: idempotent action handler with transition guards and serialized mutation pipeline.
4. **Post-end stale actions** (actions still applied after terminate)
   - Mitigation: strict terminal-state gating + no-op with logged diagnostics.

## 6) Rollback Strategy
- Rollback unit: per-MVP PR merge commit (revertable independently).
- If release regression found:
  1) revert offending MVP merge commit(s) from `main`;
  2) merge latest `main` into `release/r2026.03.01`;
  3) rerun release workflow;
  4) retag only after QA pass.
- Tag rule remains `v<semver>` only after release QA acceptance.

## 7) Delivery Sequence
1. MVP-01 implementation + evidence -> PR merge.
2. MVP-02 implementation + evidence -> PR merge.
3. Merge latest `main` into `release/r2026.03.01`.
4. Run release workflow for TestFlight.
5. Human QA gate -> release decision.
