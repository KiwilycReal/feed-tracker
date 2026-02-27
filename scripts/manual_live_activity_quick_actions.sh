#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Run this on macOS with Xcode command line tools installed."
  exit 1
fi

echo "Sending Live Activity quick-action deep links to booted simulator..."
for action in start_left start_right end_session; do
  url="feedtracker://live-activity?action=${action}"
  echo " -> ${url}"
  xcrun simctl openurl booted "${url}"
done

echo "Done. Validate state transitions in app and history list."
