# QA Checklist — r2026.03.01

## Build/install
- [ ] Confirm app reports version `0.2.0` and build `20260304073001`
- [ ] Launch on iOS 17+ device (Dynamic Island capable preferred)

## MVP-01 checks
- [ ] Active session survives background and relaunch
- [ ] Compact/minimal island timer is continuous and monotonic
- [ ] Ending session dismisses Live Activity

## MVP-02 checks
- [ ] Expanded island supports switch side / pause / terminate
- [ ] Lock screen supports switch side / pause / terminate
- [ ] Repeated stale actions after terminate do not mutate terminal state

## Data integrity
- [ ] Completed session persists to history
- [ ] History edit/delete still work as expected
- [ ] No duplicate session record created by repeated terminate actions

## Regression sweep
- [ ] Diagnostics export still generates redacted JSON
- [ ] Active-session recovery semantics unchanged (running restores, ended not restored)

## Evidence attachments
- [ ] `docs/releases/r2026.03.01/evidence/manual-live-activity-lifecycle.md`
- [ ] `docs/releases/r2026.03.01/evidence/dynamic-island-compact-timer.md`
- [ ] `docs/releases/r2026.03.01/evidence/dynamic-island-expanded-actions.md`
- [ ] `docs/releases/r2026.03.01/evidence/lockscreen-actions.md`
