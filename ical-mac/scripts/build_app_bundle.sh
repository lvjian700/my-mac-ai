#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/ical-mac.app"
EXEC="$ROOT/.build/release/ical-mac"

if [[ ! -x "$EXEC" ]]; then
  echo "Missing release executable at $EXEC. Run make build first." >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXEC" "$APP/Contents/MacOS/ical-mac"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/ical-mac"
/usr/bin/codesign --force --sign - "$APP" >/dev/null

echo "$APP"
