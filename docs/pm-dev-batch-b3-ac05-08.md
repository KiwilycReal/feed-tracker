# Developer Task Package — Batch B3 (AC-MVP-05..08)

## Goal
Deliver the first end-to-end MVP functional slice: deterministic timer engine + active session UI + history + edit flow.

## Scope
- AC-MVP-05
- AC-MVP-06
- AC-MVP-07
- AC-MVP-08

## Implementation Checklist
- [ ] Define `FeedingSession` aggregate model (left/right elapsed, total elapsed, status, timestamps).
- [ ] Implement `SessionTimerEngine` state machine:
  - start(left|right)
  - switch(left|right)
  - pause
  - resume
  - stopCurrentSide
  - endSession
- [ ] Add guardrails for invalid transitions (e.g., resume without paused state).
- [ ] Create Active Session view model + UI binding to timer engine.
- [ ] Build History list view model + list rendering from repository.
- [ ] Build Edit Session flow (load, mutate side durations, save).
- [ ] Persist edited values and verify after app restart.
- [ ] Add deterministic unit tests for transition graph and elapsed calculations.
- [ ] Add integration tests for History+Edit persistence roundtrip.

## Mandatory PR Evidence Table
Use this exact rows in PR description:

| AC ID | Status (PASS/FAIL/BLOCKED) | Evidence Link | Note |
|---|---|---|---|
| AC-MVP-05 |  |  |  |
| AC-MVP-06 |  |  |  |
| AC-MVP-07 |  |  |  |
| AC-MVP-08 |  |  |  |

## Quality Gates (must all pass)
- Build/compile passes
- Lint passes (or explicit placeholder notice if lint tool bootstrap still pending)
- Unit tests pass
- Coverage gate met (Global >= 70%, Core >= 80%)
- No P0 crash/blocker in core session flow

## Rollback Requirement
Before merge, provide rollback point:
- Tag suggestion: `rollback/ac-mvp-05-08-<yyyymmdd>`
- Include exact rollback command in PR:
  - `git checkout main && git pull && git revert <merge_commit_sha>`

## Risk Notes (must include in PR)
- Known timer precision limitations (if any)
- Any UI timing drift in background/foreground transitions
- Any watchOS parity deferred beyond this batch
