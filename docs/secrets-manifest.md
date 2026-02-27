# Secrets Manifest (Bootstrap)

This project uses placeholder keys only at bootstrap stage. Real values must be set in GitHub Actions Secrets and never shared in chat.

## Required Secret Keys

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APPLE_TEAM_ID`
- `APPLE_ID`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`
- `KEYCHAIN_PASSWORD`
- `FASTLANE_SESSION`

## Placeholder Convention

Use `__FILL_BY_USER__` for all local/bootstrap manifests.
