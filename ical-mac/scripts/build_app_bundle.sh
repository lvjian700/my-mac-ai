#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/ical-mac.app"
EXEC="$ROOT/.build/release/ical-mac"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Apple Development: lv jian (2JH6SCB777)}"
CODESIGN_OPTIONS="${CODESIGN_OPTIONS:-}"
CODESIGN_TIMESTAMP="${CODESIGN_TIMESTAMP:-0}"

if [[ ! -x "$EXEC" ]]; then
  echo "Missing release executable at $EXEC. Run make build first." >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXEC" "$APP/Contents/MacOS/ical-mac"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/ical-mac"
codesign_args=(--force --sign "$CODESIGN_IDENTITY")
if [[ -n "$CODESIGN_OPTIONS" ]]; then
  codesign_args+=(--options "$CODESIGN_OPTIONS")
fi
if [[ "$CODESIGN_TIMESTAMP" == "1" ]]; then
  codesign_args+=(--timestamp)
fi
/usr/bin/codesign "${codesign_args[@]}" "$APP" >/dev/null

echo "$APP"
