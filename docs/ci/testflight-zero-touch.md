# TestFlight Zero-Touch CI/CD (Final)

## Objective
After one-time GitHub setup, release operation is **click run only**:
- run `release.yml`
- CI performs readonly signing sync + build + TestFlight upload
- no Apple ID session/password in CI

---

## 1) Single-path Architecture

### Release (only path)
- Workflow: `.github/workflows/release.yml`
- Deploy worker: `.github/workflows/_tool_deploy.yml`
- Fastlane lane: `ios testflight_release`

### Key constraints
- `match` is hardcoded readonly in release lane.
- No portal-create/`produce` in release lane.
- Release uses only the minimal contract listed below.

---

## 2) Source of Truth

File: `ci/signing-targets.json`

Defines:
- project/scheme defaults
- primary app bundle id
- all signable targets (app/extensions) with bundle id + profile mapping

Why:
- extension targets are config-driven (not hardcoded lane logic)
- capability/target drift is detectable pre-build

---

## 3) Validation Tooling

### Contract check
`scripts/ci/validate_release_contract.sh`
- validates required release secrets/vars at job start
- fails fast with one-line remediation

### Signing readiness check
`scripts/ci/check_signing_readiness.py`
- `--mode config`: project bundle IDs vs signing config drift
- `--mode profiles`: installed profile presence/name + entitlement key readiness
- deterministic failure format:
  - `ERROR_ONE_LINE: ... | ACTION: ...`

---

## 4) Required Setup (One-time)

### Secrets
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APPLE_TEAM_ID`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`
- `KEYCHAIN_PASSWORD`

### Vars
- `MATCH_GIT_URL`
- `CI_XCODE_SCHEME`
- `CI_XCODE_PROJECT` (or `CI_XCODE_WORKSPACE`)
- `CI_SIGNING_CONFIG_PATH` (optional, default `ci/signing-targets.json`)

---

## 5) Failure Modes and Deterministic Actions

1. **Project target drift**
   - Error: bundle ID missing in signing config
   - Action: update `ci/signing-targets.json`

2. **Provisioning/capability not ready**
   - Error: profile missing or entitlement key absent
   - Action: provision/update profiles/capabilities outside CI, then rerun `release.yml`

3. **Missing CI contract key**
   - Error from contract script
   - Action: set missing secret/var once

---

## 6) Migration / Cleanup Outcome

Removed legacy CI bootstrap path and related workflow dependencies.
Release path is now a single readonly workflow with explicit fail-fast checks.

---

## 7) Rollback

If this architecture regresses:
```bash
git revert <merge_commit_sha>
```
Then rerun release using prior workflow state.
