#!/usr/bin/env bash
set -euo pipefail

# Validates required CI contract for readonly TestFlight release lane.
# Fails fast with one-line actionable remediation.

required_secrets=(
  APP_STORE_CONNECT_API_KEY_ID
  APP_STORE_CONNECT_API_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_BASE64
  APPLE_TEAM_ID
  MATCH_PASSWORD
  MATCH_GIT_BASIC_AUTHORIZATION
  KEYCHAIN_PASSWORD
)

required_vars=(
  CI_XCODE_SCHEME
  MATCH_GIT_URL
)

missing=()
for key in "${required_secrets[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    missing+=("$key")
  fi
done

for key in "${required_vars[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    missing+=("$key")
  fi
done

workspace="${CI_XCODE_WORKSPACE:-}"
project="${CI_XCODE_PROJECT:-}"
if [[ -z "$workspace" && -z "$project" ]]; then
  missing+=("CI_XCODE_WORKSPACE|CI_XCODE_PROJECT")
fi

if (( ${#missing[@]} > 0 )); then
  echo "ERROR_ONE_LINE: Missing release contract keys: ${missing[*]} | ACTION: set them once in GitHub environment secrets/vars, then re-run release workflow."
  exit 1
fi

config_path="${CI_SIGNING_CONFIG_PATH:-ci/signing-targets.json}"
if [[ ! -f "$config_path" ]]; then
  echo "ERROR_ONE_LINE: Signing config not found at '$config_path' | ACTION: add config file and point CI_SIGNING_CONFIG_PATH to it."
  exit 1
fi

echo "Release contract validation passed for readonly release lane."
