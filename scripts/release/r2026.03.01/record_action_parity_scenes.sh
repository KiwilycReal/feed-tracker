#!/usr/bin/env bash
set -euo pipefail

# Capture helper for MVP-02 manual evidence (expanded + lock screen action parity)
# Usage:
#   scripts/release/r2026.03.01/record_action_parity_scenes.sh <simulator-udid> <output-dir>

SIM_UDID="${1:-}"
OUT_DIR="${2:-docs/releases/r2026.03.01/evidence/artifacts}"

if [[ -z "$SIM_UDID" ]]; then
  echo "usage: $0 <simulator-udid> <output-dir>"
  exit 1
fi

mkdir -p "$OUT_DIR"

ts() { date +%Y%m%d-%H%M%S; }
cap() {
  local name="$1"
  xcrun simctl io "$SIM_UDID" screenshot "$OUT_DIR/${name}-$(ts).png"
  echo "captured: $name"
}

echo "[1/6] Start active session, expand Dynamic Island and trigger switch side, then Enter"
read -r _
cap "ac-r2026.03.01-03-expanded-switch"

echo "[2/6] Trigger pause in expanded view, then Enter"
read -r _
cap "ac-r2026.03.01-03-expanded-pause"

echo "[3/6] Trigger terminate in expanded view, then Enter"
read -r _
cap "ac-r2026.03.01-03-expanded-terminate"

echo "[4/6] Restart active session, lock screen, trigger switch side, then Enter"
read -r _
cap "ac-r2026.03.01-04-lock-switch"

echo "[5/6] Trigger pause on lock screen, wait 20s, then Enter"
read -r _
cap "ac-r2026.03.01-04-lock-pause"

echo "[6/6] Trigger terminate on lock screen, then Enter"
read -r _
cap "ac-r2026.03.01-04-lock-terminate"

echo "done: $OUT_DIR"
