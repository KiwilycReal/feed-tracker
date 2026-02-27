#!/usr/bin/env bash
set -euo pipefail

SHORTCUT_OPEN=${SHORTCUT_OPEN:-"Open Feed Tracker"}
SHORTCUT_START=${SHORTCUT_START:-"Start Feed Tracking"}
SHORTCUT_READ=${SHORTCUT_READ:-"Read Feed Tracking Status"}

if ! command -v shortcuts >/dev/null 2>&1; then
  echo "shortcuts CLI not found. Run this on macOS with the Shortcuts app installed."
  exit 1
fi

echo "Running Siri Shortcut flow via shortcuts CLI..."
echo "1) ${SHORTCUT_OPEN}"
shortcuts run "${SHORTCUT_OPEN}" || echo "::warning::Open shortcut failed (check app install / intent donation)."

echo "2) ${SHORTCUT_START}"
shortcuts run "${SHORTCUT_START}" || echo "::warning::Start shortcut failed (check AppIntents registration)."

echo "3) ${SHORTCUT_READ}"
shortcuts run "${SHORTCUT_READ}" || echo "::warning::Read shortcut failed (check AppIntents registration)."

echo "Done. Validate spoken/dialog output and in-app session state manually."
