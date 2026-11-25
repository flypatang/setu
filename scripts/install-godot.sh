#!/usr/bin/env bash
# Download, verify (SHA-512) and install a Godot release plus its export templates.
# Usage: scripts/install-godot.sh [version] [--no-templates]   (default 4.7.2)
# Set GODOT_DIR to choose the install folder (default: <repo>/tools/godot).
set -euo pipefail
VER="${1:-4.7.2}"; NO_TPL="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="${GODOT_DIR:-$ROOT/tools/godot}"; mkdir -p "$T"; cd "$T"
B="https://github.com/godotengine/godot/releases/download/${VER}-stable"
BIN="Godot_v${VER}-stable_linux.x86_64"
TPZ="Godot_v${VER}-stable_export_templates.tpz"
FILES=(SHA512-SUMS.txt "$BIN.zip"); [ "$NO_TPL" = "--no-templates" ] || FILES+=("$TPZ")
for f in "${FILES[@]}"; do
  [ -f "$f" ] || curl -fsSL --retry 4 -o "$f" "$B/$f"
done
grep -E " (${BIN}\.zip|${TPZ})$" SHA512-SUMS.txt | sha512sum -c --ignore-missing -
unzip -oq "$BIN.zip" && ln -sf "$BIN" godot
if [ "$NO_TPL" != "--no-templates" ]; then
TD="$HOME/.local/share/godot/export_templates/${VER}.stable"; mkdir -p "$TD"
TMP="$(mktemp -d)"; unzip -oq "$TPZ" -d "$TMP" && cp -r "$TMP"/templates/* "$TD"/ && rm -rf "$TMP" "$TPZ"
fi
./godot --headless --version
