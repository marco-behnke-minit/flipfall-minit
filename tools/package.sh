#!/usr/bin/env bash
# Build the Web export and package the Creator Console upload ZIP.
#
#   tools/package.sh
#
# The console wants a self-contained archive whose ROOT is index.html, with
# meta.json beside it — not a dist/ folder, no project files. Godot's exporter
# emits the web build; meta.json is a project file, so it is copied in here.
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="build/web"
ZIP="build/flipfall-godot.zip"

if [ ! -x "$GODOT" ]; then
  echo "Godot not found at $GODOT — set GODOT=/path/to/Godot" >&2
  exit 1
fi

# The Web export templates are a one-time editor install:
#   Editor > Manage Export Templates > Download and Install
if ! find "$HOME/Library/Application Support/Godot/export_templates" \
     -name 'web_nothreads_release.zip' -print -quit 2>/dev/null | grep -q .; then
  echo "Web export templates are not installed." >&2
  echo "Install them in the editor: Editor > Manage Export Templates > Download and Install." >&2
  exit 1
fi

rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT"

echo "==> exporting"
"$GODOT" --headless --export-release "Web" "$OUT/index.html"

# meta.json must sit at the top level of the ZIP, next to index.html — the
# console reads it from there to pre-fill the new-Minit draft form.
cp meta.json "$OUT/meta.json"

echo "==> packaging"
( cd "$OUT" && zip -qr "../../$ZIP" . )

echo
echo "wrote $ZIP"
unzip -l "$ZIP"

echo
echo "Upload $ZIP at https://console.minit.games"
