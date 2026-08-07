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

# Verify before building, so a broken config or a drifted simulation can never
# reach an upload.
echo "==> verifying"
node tools/check-meta.mjs
node tools/test-schema.mjs >/dev/null
"$GODOT" --headless --script res://tools/test_score.gd >/dev/null
"$GODOT" --headless --script res://tools/test_config.gd >/dev/null
"$GODOT" --headless --script res://tools/test_music.gd >/dev/null
echo "scoring, config, schema and music checks passed"
node tools/solve.mjs | tail -1
node tools/compare-trace.mjs | tail -1

rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT"

echo "==> exporting"
"$GODOT" --headless --export-release "Web" "$OUT/index.html"

# meta.json must sit at the top level of the ZIP, next to index.html — the
# console reads it from there to pre-fill the new-Minit draft form.
cp meta.json "$OUT/meta.json"

echo "==> packaging"
( cd "$OUT" && zip -qr "../../$ZIP" . )

# Pre-flight. The console rejects an archive that still looks like a project, so
# refuse to hand over one rather than finding out on upload.
echo "==> pre-flight"
listing=$(unzip -Z1 "$ZIP")
fail=0
for required in index.html meta.json; do
  grep -qx "$required" <<<"$listing" || { echo "MISSING at ZIP root: $required" >&2; fail=1; }
done
# A dotfile shipped inside an upload of the HTML5 build before its equivalent
# check existed.
forbidden=$(grep -E '(^|/)(src|tools)/|(^|/)\.|\.gd$|\.tscn$|\.import$|package\.json$|vite\.config\.' <<<"$listing" || true)
if [ -n "$forbidden" ]; then
  echo "FORBIDDEN entries in ZIP:" >&2
  echo "$forbidden" >&2
  fail=1
fi
[ "$fail" -eq 0 ] || { echo "pre-flight failed — not uploading this" >&2; exit 1; }
echo "index.html and meta.json at root, no project files, no dotfiles"

echo
echo "wrote $ZIP"
unzip -l "$ZIP"

echo
echo "Upload $ZIP at https://console.minit.games"
