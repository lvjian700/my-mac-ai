#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$("$ROOT/scripts/ensure_xcode_workspace.sh")"

if command -v xed >/dev/null 2>&1; then
  xed "$WORKSPACE"
else
  open "$WORKSPACE"
fi
