# Developer Task Package — Batch B3 (AC-MVP-05..08)

## Goal
Deliver the first end-to-end MVP functional slice: deterministic timer engine + active session UI + history + edit flow.

## Scope
- AC-MVP-05
- AC-MVP-06
- AC-MVP-07
- AC-MVP-08

## Implementation Checklist
- [x] Define `FeedingSession` aggregate model (left/right elapsed, total elapsed, status, timestamps).
- [x] Implement `SessionTimerEngine` state machine:
  - start(left|right)
  - switch(left|right)
  - pause
  - resume
  - stopCurrentSide
  - endSession
- [x] Add guardrails for invalid transitions (e.g., resume without paused state).
- [x] Create Active Session view model + UI binding to timer engine.
- [x] Build History list view model + list rendering from repository.
- [x] Build Edit Session flow (load, mutate side durations, save).
- [x] Persist edited values and verify after app restart.
- [x] Add deterministic unit tests for transition graph and elapsed calculations.
- [x] Add integration tests for History+Edit persistence roundtrip.

## Mandatory PR Evidence Table
Use this exact rows in PR description:

| AC ID | Status (PASS/FAIL/BLOCKED) | Evidence Link | Note |
|---|---|---|---|
| AC-MVP-05 | PASS | `Sources/FeedTrackerCore/Session/SessionTimerEngine.swift`, `Tests/FeedTrackerCoreTests/SessionTimerEngineTests.swift` | Deterministic transition coverage: start/switch/pause/resume/stop/end + invalid transitions |
| AC-MVP-06 | PASS | `Sources/FeedTrackerCore/Features/ActiveSessionViewModel.swift`, `Sources/FeedTrackerCore/UI/ActiveSessionView.swift`, `Tests/FeedTrackerCoreTests/ActiveSessionViewModelTests.swift` | Active side + inactive accumulations + total elapsed live refresh model |
| AC-MVP-07 | PASS | `Sources/FeedTrackerCore/Persistence/FeedingSessionRepository.swift`, `Sources/FeedTrackerCore/Features/HistoryListViewModel.swift`, `Sources/FeedTrackerCore/UI/HistoryListView.swift`, `Tests/FeedTrackerCoreTests/HistoryAndEditIntegrationTests.swift` | Completed-session history list with key metrics (left/right/total/timestamp/note) |
| AC-MVP-08 | PASS | `Sources/FeedTrackerCore/Session/FeedingSession.swift`, `Sources/FeedTrackerCore/Features/EditSessionViewModel.swift`, `Tests/FeedTrackerCoreTests/HistoryAndEditIntegrationTests.swift` | Edit flow saves and re-reads persisted durations/notes safely |

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
