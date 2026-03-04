# Secrets Manifest (Final CI Contract)

Release is executed through a single readonly workflow path.
No Apple ID/session/password secrets are used by CI release.

## Required Secrets
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APPLE_TEAM_ID`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`
- `KEYCHAIN_PASSWORD`

## Required Vars
- `MATCH_GIT_URL`
- `CI_XCODE_SCHEME`
- `CI_XCODE_PROJECT` (or `CI_XCODE_WORKSPACE`)
- `CI_SIGNING_CONFIG_PATH` (optional; default `ci/signing-targets.json`)

## Placeholder Convention
Use `__FILL_BY_USER__` for placeholder manifests.
