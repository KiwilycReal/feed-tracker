# Manual Active Session Recovery (POSTREL-02)

## Goal
Verify crash-safe active session recovery behavior after force-kill/relaunch.

## Preconditions
- Build with POSTREL-02 changes.
- Start from clean install or ensure no unfinished recovery state exists.

## AC-POSTREL-02-01: restore after force-kill
1. Open app → Active tab.
2. Start a session on left side.
3. Let timer run for ~20s.
4. Force-kill app from app switcher.
5. Relaunch app.

Expected:
- Active session is restored automatically.
- State is still running on the previously active side.
- Elapsed time is continuous (includes background/offline interval).

## AC-POSTREL-02-02: no restore after end
1. Start and run a session.
2. End session normally.
3. Force-kill app.
4. Relaunch app.

Expected:
- No active session is restored.
- App opens in fresh startable state (`idle`).
- Completed session remains in history.

## AC-POSTREL-02-03: paused restore semantics
1. Start session and run ~15s.
2. Pause session.
3. Force-kill app.
4. Relaunch app.

Expected:
- Restored state is paused (not auto-running).
- Elapsed time does not drift while paused.
- Resume continues from paused value.

## Storage model
- Recovery payload stores timer engine state snapshot for non-terminal states (`running/paused/stopped`).
- Terminal states (`idle/ended`) clear recovery payload.
- Current app implementation stores payload in `UserDefaults` key:
  - `feedtracker.active_session_recovery.v1`

## Rollback note
- Revert commit for POSTREL-02 branch merge if needed:
  - `git revert <POSTREL-02-merge-commit>`
