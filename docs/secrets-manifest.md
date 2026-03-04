# Secrets Manifest (CI/CD)

This project uses a split CI/CD model:
- **Bootstrap lane** (rare, portal mutation)
- **Release lane** (normal, readonly)

Real values must be set in GitHub Actions environment and never committed.

## Release Lane Required (readonly)

### Secrets
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APPLE_TEAM_ID`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`
- `KEYCHAIN_PASSWORD`

### Vars
- `CI_XCODE_WORKSPACE` (optional)
- `CI_XCODE_PROJECT` (required if workspace omitted)
- `CI_XCODE_SCHEME`
- `MATCH_GIT_URL`
- `CI_SIGNING_CONFIG_PATH` (default `ci/signing-targets.json`)
- `MATCH_READONLY=true`

## Bootstrap Lane Additional Requirements (one-time / occasional)
- `APPLE_ID` (secret)
- `FASTLANE_SESSION` (secret)

## Placeholder Convention
Use `__FILL_BY_USER__` for placeholder manifests.
