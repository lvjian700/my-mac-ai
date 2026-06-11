#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/ical-mac.xcodeproj"
SCHEME="ical-mac"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/.build/DerivedData}"
APP="$ROOT/.build/ical-mac.app"
BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/ical-mac.app"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
CODESIGN_OPTIONS="${CODESIGN_OPTIONS:-runtime}"
CODESIGN_TIMESTAMP="${CODESIGN_TIMESTAMP:-0}"
ENTITLEMENTS="$ROOT/Resources/ical-mac.entitlements"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination 'platform=macOS' \
  build

rm -rf "$APP"
/usr/bin/ditto "$BUILT_APP" "$APP"
codesign_args=(--force --sign "$CODESIGN_IDENTITY")
if [[ -f "$ENTITLEMENTS" ]]; then
  codesign_args+=(--entitlements "$ENTITLEMENTS")
fi
if [[ -n "$CODESIGN_OPTIONS" ]]; then
  codesign_args+=(--options "$CODESIGN_OPTIONS")
fi
if [[ "$CODESIGN_TIMESTAMP" == "1" ]]; then
  codesign_args+=(--timestamp)
fi
/usr/bin/codesign "${codesign_args[@]}" "$APP" >/dev/null

echo "$APP"
