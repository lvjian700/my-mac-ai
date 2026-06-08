#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
pkill -x "ical-mac" >/dev/null 2>&1 || true
make app
/usr/bin/open -n .build/ical-mac.app
