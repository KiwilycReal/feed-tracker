# TestFlight Zero-Touch CI/CD Architecture (HF3)

## Status
- Owner: Release Engineering
- Scope: `r2026.03.01` hotfix hardening
- Objective: After one-time bootstrap, normal release is **click run only** (no Apple ID session / no portal mutation)

---

## 1) Decision Summary

We split signing+release into two deterministic pipelines:

1. **Bootstrap/Provision pipeline** (rare, human-invoked)
   - Workflow: `.github/workflows/signing-bootstrap.yml`
   - Lane: `fastlane ios signing_bootstrap`
   - Permissions: may mutate Apple Developer portal resources
   - Uses: `APPLE_ID` + `FASTLANE_SESSION`

2. **Release pipeline** (normal, CI readonly)
   - Workflow: `.github/workflows/release.yml` → `deploy` via `_tool_deploy.yml`
   - Lane: `fastlane ios testflight_release`
   - Permissions: readonly signing sync only (`match readonly=true`)
   - **No FASTLANE_SESSION required**
   - No `produce` / portal-create calls

This removes non-deterministic interactive dependencies from normal release CI.

---

## 2) Source of Truth

### Signing target source of truth
- File: `ci/signing-targets.json`
- Contains:
  - project/scheme
  - primary app bundle id
  - dynamic target list (`target`, `bundle_id`, `profile_name`)

This allows extension targets to scale from config (not hardcoded in lane logic).

### Why this is robust
- New extension/capability work updates **one config file**.
- Preflight script validates project target bundle IDs against this config before release.
- Drift becomes deterministic and actionable.

---

## 3) Signing / Provisioning Strategy

## Bootstrap lane (`ios signing_bootstrap`)
- Validates bootstrap secrets + vars.
- Ensures portal App IDs exist for all configured bundle IDs.
- Runs `match` with `readonly=false` for all configured bundle IDs to create/refresh profiles.
- Runs profile readiness checks before exit.

## Release lane (`ios testflight_release`)
- Validates release contract + signing config.
- Runs `match` with `readonly=true` only.
- Verifies installed profiles/entitlements readiness before build.
- Builds and uploads to TestFlight.
- Never calls `produce` and never requires `FASTLANE_SESSION`.

---

## 4) Capability Drift Detection Strategy

Script: `scripts/ci/check_signing_readiness.py`

Modes:
- `--mode config`
  - discovers iOS app/app-extension bundle IDs from Xcode build settings
  - compares against `ci/signing-targets.json`
  - fails fast if config is missing new targets or contains stale entries

- `--mode profiles`
  - verifies provisioning profiles exist for each configured bundle ID
  - verifies profile names match expected mapping
  - verifies declared entitlements keys are present in provisioning profile entitlements

Failure format is a deterministic one-line error:
`ERROR_ONE_LINE: <what failed> | ACTION: <exact next step>`

This ensures capability additions fail early with precise remediation.

---

## 5) Failure Modes & Deterministic Remediation

1. **New target added, config not updated**
   - Signal: `bundle IDs exist in project but missing in signing config`
   - Action: add bundle IDs to `ci/signing-targets.json`, run bootstrap once.

2. **New capability added but profile not updated**
   - Signal: `entitlement '<key>' ... not present in provisioning profile`
   - Action: run `signing-bootstrap` workflow once.

3. **Missing CI secrets/vars**
   - Signal from `scripts/ci/validate_release_contract.sh`
   - Action: set listed key in GitHub environment once.

4. **Release lane attempts mutable signing behavior**
   - Guard: `MATCH_READONLY=true` enforced in release lane.
   - Action: use bootstrap lane for mutations.

---

## 6) One-Time Human Bootstrap Inputs (exact contract)

Set once in GitHub environment (`prod`):

### Secrets
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APPLE_TEAM_ID`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`
- `KEYCHAIN_PASSWORD`
- `APPLE_ID` (**bootstrap only**)
- `FASTLANE_SESSION` (**bootstrap only**)

### Vars
- `CI_XCODE_WORKSPACE` (optional if project used)
- `CI_XCODE_PROJECT` (required if workspace not provided)
- `CI_XCODE_SCHEME`
- `MATCH_GIT_URL`
- `CI_SIGNING_CONFIG_PATH` (default: `ci/signing-targets.json`)
- `MATCH_READONLY=true` (for release)

Recurring operation after this setup:
- **Release:** click run `release.yml`
- **When capabilities/targets changed:** click run `signing-bootstrap.yml` once, then release again.

---

## 7) Migration Steps from Previous Flow

1. Add `ci/signing-targets.json`.
2. Add/enable scripts:
   - `scripts/ci/validate_release_contract.sh`
   - `scripts/ci/check_signing_readiness.py`
3. Upgrade Fastlane:
   - add `signing_bootstrap` lane
   - change release lane to `testflight_release` readonly-only
4. Update workflows:
   - deploy default command -> `bundle exec fastlane ios testflight_release`
   - remove `FASTLANE_SESSION` dependency from release deploy job
   - add `signing-bootstrap.yml` workflow
5. Run `signing-bootstrap.yml` once.
6. Run `release.yml` for normal release.

---

## 8) Rollback Plan

If HF3 causes CI regressions:
1. Revert this hotfix PR.
2. Restore previous release lane command (`bundle exec fastlane ios testflight`).
3. Re-run release workflow with old path.

Git rollback command pattern:
```bash
git revert <hf3-merge-commit>
```

---

## 9) Proof Requirements

For PR acceptance, attach:
- Bootstrap workflow run URL (if executed)
- Release workflow run URL proving readonly release path
- CI logs proving no FASTLANE_SESSION dependency in release deploy step
