#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/ical-mac.xcodeproj"

if command -v xed >/dev/null 2>&1; then
  xed "$PROJECT"
else
  open "$PROJECT"
fi
