#!/usr/bin/env bash
set -euo pipefail

# Best-effort helper to capture simulator screenshots for lifecycle checkpoints.
# Usage:
#   scripts/release/r2026.03.01/record_live_activity_scenes.sh <simulator-udid> <output-dir>

SIM_UDID="${1:-}"
OUT_DIR="${2:-docs/releases/r2026.03.01/evidence/artifacts}"

if [[ -z "$SIM_UDID" ]]; then
  echo "usage: $0 <simulator-udid> <output-dir>"
  exit 1
fi

mkdir -p "$OUT_DIR"

stamp() {
  date +%Y%m%d-%H%M%S
}

capture() {
  local name="$1"
  xcrun simctl io "$SIM_UDID" screenshot "$OUT_DIR/${name}-$(stamp).png"
  echo "captured: $name"
}

echo "[1/4] capture foreground"
capture "ac-r2026.03.01-foreground"

echo "[2/4] Please home/background app, then press Enter"
read -r _
capture "ac-r2026.03.01-background"

echo "[3/4] Please terminate + relaunch app, then press Enter"
read -r _
capture "ac-r2026.03.01-relaunch"

echo "[4/4] Please end session in app, then press Enter"
read -r _
capture "ac-r2026.03.01-ended"

echo "done. artifacts under: $OUT_DIR"
