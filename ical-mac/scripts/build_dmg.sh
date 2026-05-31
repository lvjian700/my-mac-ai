#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ical-mac"
APP="$ROOT/.build/$APP_NAME.app"
INFO_PLIST="$ROOT/Resources/Info.plist"
DIST_DIR="$ROOT/dist"
DMG_ROOT="$ROOT/.build/dmg-root"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
ALLOW_NON_DEVELOPER_ID_DMG="${ALLOW_NON_DEVELOPER_ID_DMG:-0}"

if [[ -z "$CODESIGN_IDENTITY" ]]; then
  echo "CODESIGN_IDENTITY must be set to a Developer ID Application identity." >&2
  echo 'Example: CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make dmg' >&2
  exit 1
fi

if [[ "$CODESIGN_IDENTITY" != Developer\ ID\ Application:* && "$ALLOW_NON_DEVELOPER_ID_DMG" != "1" ]]; then
  echo "Refusing to build a distribution DMG with non-Developer ID identity: $CODESIGN_IDENTITY" >&2
  echo "Set ALLOW_NON_DEVELOPER_ID_DMG=1 only for local packaging tests." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
DMG="$DIST_DIR/$APP_NAME-$VERSION.dmg"

export CODESIGN_IDENTITY
export CODESIGN_OPTIONS="${CODESIGN_OPTIONS:-runtime}"
export CODESIGN_TIMESTAMP="${CODESIGN_TIMESTAMP:-1}"

"$ROOT/scripts/build_app_bundle.sh" >/dev/null
/usr/bin/codesign --verify --strict --verbose=2 "$APP" >/dev/null

rm -rf "$DMG_ROOT" "$DMG"
mkdir -p "$DIST_DIR" "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null

/usr/bin/hdiutil verify "$DMG" >/dev/null

echo "$DMG"
