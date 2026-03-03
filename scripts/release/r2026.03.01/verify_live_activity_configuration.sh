#!/usr/bin/env bash
set -euo pipefail

# Validate Live Activity configuration in built app/extension artifacts.
# Usage:
#   scripts/release/r2026.03.01/verify_live_activity_configuration.sh <derived-products-dir>
# Example:
#   scripts/release/r2026.03.01/verify_live_activity_configuration.sh ~/Library/Developer/Xcode/DerivedData/<...>/Build/Products/Debug-iphoneos

PRODUCTS_DIR="${1:-}"
if [[ -z "$PRODUCTS_DIR" ]]; then
  echo "usage: $0 <derived-products-dir>"
  exit 1
fi

APP_PLIST="$PRODUCTS_DIR/FeedTracker.app/Info.plist"
EXT_PLIST="$PRODUCTS_DIR/FeedTracker.app/PlugIns/FeedTrackerLiveActivityWidgetExtension.appex/Info.plist"

if [[ ! -f "$APP_PLIST" ]]; then
  echo "missing app Info.plist: $APP_PLIST"
  exit 2
fi
if [[ ! -f "$EXT_PLIST" ]]; then
  echo "missing extension Info.plist: $EXT_PLIST"
  exit 3
fi

supports_live_activities=$(/usr/libexec/PlistBuddy -c "Print :NSSupportsLiveActivities" "$APP_PLIST" 2>/dev/null || true)
ext_point=$(/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPointIdentifier" "$EXT_PLIST" 2>/dev/null || true)
ext_principal=$(/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPrincipalClass" "$EXT_PLIST" 2>/dev/null || true)

echo "NSSupportsLiveActivities=$supports_live_activities"
echo "NSExtensionPointIdentifier=$ext_point"
echo "NSExtensionPrincipalClass=$ext_principal"

[[ "$supports_live_activities" == "true" || "$supports_live_activities" == "YES" ]]
[[ "$ext_point" == "com.apple.widgetkit-extension" ]]
[[ "$ext_principal" == *"FeedTrackerLiveActivityWidgetBundle" ]]

echo "OK: Live Activity configuration is present in app + widget extension."
