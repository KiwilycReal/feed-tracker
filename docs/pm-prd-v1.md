# Feed Tracker — PM PRD v1 (Thread 1476823938343374879)

## 1) Objective and Context
Build an iOS-first + watchOS-assist feeding tracker for a family pair (non-public-market target) with fast start/stop timing, reliable local history, and low-friction in-session controls. MVP must prioritize functional correctness, data reliability, and quick daily-use interactions over broad feature breadth.

## 2) In Scope / Out of Scope

### In Scope (MVP + P1)
- iOS primary app flow for creating, running, finishing, and saving feeding sessions.
- Left/right side timing with pause/resume and total elapsed display.
- Active Session screen + History screen.
- Edit/delete history items.
- Dynamic Island / Live Activity quick actions for in-session control.
- Local-first persistent storage.
- watchOS companion support for quick session operations (assistive scope).
- P1 Siri shortcuts (open app / start with side/default / read current status).

### Out of Scope (current phase)
- Public growth features, onboarding funnels, analytics pipeline.
- Full cloud backend and account system.
- Guaranteed cross-account Family iCloud sync in MVP (future extension only).
- App Store GTM process (default delivery path is TestFlight only).

## 3) Assumptions and Open Questions

### Assumptions
- Release channel is TestFlight by default.
- Functional quality gates are mandatory before each releasable build.
- iOS target baseline aligns with current repo platform settings (iOS 17+, watchOS 10+).
- User is the source of truth for real secret values; never in chat.

### Open Questions (non-blocking for current sprint)
- Exact watchOS UI depth for MVP (full parity vs quick controls only).
- P1 Siri language phrasing and localization strategy.
- Family-group iCloud sync roadmap timing.

## 4) User Stories
- As a parent, I can quickly start/stop left or right feeding timing so I can track accurately under time pressure.
- As a parent, I can see current side and total elapsed in real time so I can make immediate decisions.
- As a parent, I can edit/delete past sessions so historical records stay trustworthy.
- As a parent, I can control an active session from Dynamic Island quickly without navigating deep screens.
- As a parent, I can reopen app or ask Siri for current status hands-free.

## 5) Acceptance Criteria Table

| AC ID | Requirement | Verification Method | Priority | Owner |
|---|---|---|---|---|
| AC-MVP-01 | Repo and project bootstrap exists with reproducible structure. | CI checkout + project tree + README/docs evidence. | P0 | Developer |
| AC-MVP-02 | Config baseline exists with placeholder-only secret strategy and runtime config contract. | File checks + unit tests for config parser defaults. | P0 | Developer |
| AC-MVP-03 | Security boundary defined (no plaintext secret logging, clear auth/session boundaries). | Security design doc + static scan/lint checks. | P0 | Developer |
| AC-MVP-04 | Core domain model for feeding sessions is defined and test-covered. | Domain model tests + schema/version contract docs. | P0 | Developer |
| AC-MVP-05 | Session timer engine supports start/stop/pause/resume/switch side with correct elapsed aggregation. | Deterministic unit tests for time transitions and edge cases. | P0 | Developer |
| AC-MVP-06 | Active Session UI shows active side timer, inactive side accumulated time, and total elapsed live updates. | UI/integration evidence + simulator recording/screenshots. | P0 | Developer |
| AC-MVP-07 | History list displays completed sessions with key metrics (timestamp, side durations, total). | UI tests + sample data snapshot evidence. | P0 | Developer |
| AC-MVP-08 | User can edit any historical session side durations/notes and save changes safely. | Integration tests for edit flow + persistence verification. | P0 | Developer |
| AC-MVP-09 | User can delete a historical session with explicit confirmation and consistent list refresh. | UI tests + persistence re-read evidence. | P0 | Developer |
| AC-MVP-10 | Live Activity / Dynamic Island shows current session and exposes quick actions (start left/right, end session). | ActivityKit integration demo + manual test script evidence. | P0 | Developer |
| AC-MVP-11 | Main navigation includes at least Active Session and History pages; visual style is minimal/clean/cute with high interaction clarity. | UI review checklist + design acceptance screenshots. | P0 | Developer |
| AC-MVP-12 | Local persistence is durable across app restarts with migration/versioning strategy documented. | Restart/reload test + migration test case evidence. | P0 | Developer |
| AC-P1-13 | Siri shortcuts: open app, start tracking with side/default strategy, and read current side/total elapsed phrase. | AppIntents tests + Siri invocation script evidence. | P1 | Developer |

## 6) Non-Functional Requirements
- Performance: active timer UI refresh latency perceptibly real-time (target ~1s cadence), no visible lag in key interactions.
- Security: secrets never committed; no sensitive values in logs; clear boundary for local data handling.
- Reliability: no P0 crash/blocker in core flow; deterministic timer state transitions; persistence consistency guaranteed.
- Operability: CI must run lint/build/test gates; diagnostics/logs exportable for crash or flow failures.

## 7) Dependencies and Constraints
- Swift/SwiftUI + ActivityKit + AppIntents.
- iOS/watchOS SDK availability in CI and local Xcode toolchain.
- GitHub Actions secrets keys must exist (placeholder keys already scaffolded).
- Human-only steps limited to filling real secret values and one-time Apple auth/permission tasks.

## 8) Milestones (P0/P1 with dates)
- M0 (Done): AC-MVP-01..04 scaffold baseline — completed in repo bootstrap stage.
- M1 (Target: 2026-03-02): AC-MVP-05..08 (core timer + active UI + history + edit).
- M2 (Target: 2026-03-04): AC-MVP-09..12 (delete + live activity + nav polish + persistence hardening).
- M3 (Target: 2026-03-06): AC-P1-13 Siri shortcuts.
- Release readiness gate: compile/build pass, core flow tests pass, no P0 blocker, rollback point tagged.

## 9) Risk Register

| Risk | Probability | Impact | Trigger | Mitigation |
|---|---|---|---|---|
| Timer state bugs under rapid side switching | Medium | High | Inconsistent elapsed totals in tests | Build deterministic state machine + exhaustive transition tests |
| ActivityKit behavior drift across iOS versions | Medium | Medium | Live Activity actions fail/inconsistent | Add compatibility checks + fallback controls inside app |
| Local data corruption during edits/deletes | Low-Med | High | Edited/deleted records mismatch after restart | Transaction-safe repository + migration tests + backup snapshot in tests |
| watchOS scope creep | Medium | Medium | New parity asks during MVP | Keep watch scope assist-only in MVP, defer parity to post-MVP |
| CI placeholders not upgraded in time | Medium | Medium | Builds pass as placeholder but not real Xcode pipeline | Convert placeholders milestone-by-milestone with explicit checklists |

## 10) Developer Task Package (ready-to-implement checklist)

### Batch B3 (now): AC-MVP-05..08
- Implement `SessionTimerEngine` with explicit state machine and transition guards.
- Add domain entities/repository protocol updates required by edit/history flows.
- Build Active Session + History + Edit flow integration in iOS UI.
- Add unit/integration tests for timer transitions, edit persistence, and history rendering.
- Update AC evidence table in PR description for AC-MVP-05..08.

### Required Delivery Attachments per PR
- Acceptance checklist (AC-by-AC PASS/FAIL/BLOCKED with evidence links).
- Rollback point (commit/tag + exact rollback command).
- Risk notes (new debt/known gaps + mitigation plan).

### Done Condition for Batch B3
- AC-MVP-05..08 all PASS with evidence.
- No P0 crash/blocker in core timer flow.
- CI required checks green.
- PR opened with complete template fields.
