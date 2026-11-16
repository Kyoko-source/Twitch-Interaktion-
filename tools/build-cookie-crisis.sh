#!/usr/bin/env bash
# Builds Santa's Cookie Crisis (Godot) for the web: import, self-test, export.
# The self-test fails the build if the GDScript economy differs from frontend/src/cookie/sim.js.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/tools/godot-portable/Godot_v4.6.2-stable_win64_console.exe"
GAME="$ROOT/games/cookie-crisis"
node "$GAME/tests/make-fixture.mjs" >/dev/null
"$GODOT" --headless --path "$GAME" --editor --import --quit >/dev/null 2>&1 || true
out="$("$GODOT" --headless --path "$GAME" -- --self-test 2>&1)"; echo "$out" | grep "self-test"
echo "$out" | grep -q "self-test: OK" || { echo "self-test failed"; exit 1; }
mkdir -p "$GAME/build/web"
"$GODOT" --headless --path "$GAME" --export-release "Web" >/dev/null 2>&1
test -s "$GAME/build/web/index.wasm" && test -s "$GAME/build/web/index.pck"
sed -i 's/<html lang="en">/<html lang="de">/' "$GAME/build/web/index.html"
mkdir -p "$ROOT/frontend/public/standalone/cookie-crisis"
cp -r "$GAME/build/web/." "$ROOT/frontend/public/standalone/cookie-crisis/"
echo "built: $(du -sh "$GAME/build/web" | cut -f1)"
