# Rollback Plan — r2026.03.01

## Rollback triggers
- TestFlight crash rate regression after rollout
- Live Activity action parity causes state corruption
- Blocking QA failure in release acceptance checklist

## Fast rollback options

### Option A: Revert release branch commits
```bash
git checkout release/r2026.03.01
git pull --ff-only
git revert <release_versioning_commit_sha>
git push origin release/r2026.03.01
```
Then re-run release workflow from release branch.

### Option B: Roll back main via PR reverts (if already merged)
```bash
git checkout -b revert/r2026.03.01
# revert merged MVP PR commits
git revert dc1402286d315095971b6d3be1b7cb836c63585d 9670c6d3ba1bdffb61df935d6dc7feb47f8cea30
git push -u origin revert/r2026.03.01
```
Open PR and merge after validation.

## Data safety notes
- Session persistence format unchanged; rollback is code-path based.
- No destructive migration rollback required for this release.

## Operational note
- If rollback changes release workflow inputs, keep `ref=release/r2026.03.01` explicit during re-run.
