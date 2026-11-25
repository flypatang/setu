#!/usr/bin/env bash
# Quality gate 1 (DESIGN §10): import the project, then parse and type-check every game script.
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --import >/dev/null 2>&1 || true
fail=0
while IFS= read -r f; do
  out="$("$GODOT" --headless --check-only --script "res://$f" 2>&1)"
  if [ $? -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|ERROR:" <<<"$out"; then
    echo "FAIL $f"; echo "$out" | grep -E "ERROR|Error" | head -5; fail=1
  else
    echo "ok   $f"
  fi
done < <(find . -name '*.gd' -not -path './addons/*' -not -path './.godot/*' | sed 's#^\./##' | sort)
exit $fail
