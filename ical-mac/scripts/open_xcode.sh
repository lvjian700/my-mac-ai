#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/ensure_xcode_workspace.sh" >/dev/null

if command -v xed >/dev/null 2>&1; then
  xed "$ROOT"
else
  open "$ROOT/.swiftpm/xcode/package.xcworkspace"
fi
