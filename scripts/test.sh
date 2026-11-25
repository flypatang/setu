#!/usr/bin/env bash
# Quality gate 2 (DESIGN §10): run every gdUnit4 suite headless (works on display-less CI runners).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a res://tests -rd reports "$@"
code=$?
"$GODOT" --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd -rd reports >/dev/null 2>&1 || true
exit $code
