#!/usr/bin/env bash
# Uploads the Godot web build to the server (served at /standalone/cookie-crisis/ via a read-only volume).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/games/cookie-crisis/build/web"
test -s "$WEB/index.wasm" || { echo "build first: tools/build-cookie-crisis.sh"; exit 1; }
tar -czf - -C "$WEB" . | ssh -i "$USERPROFILE/.ssh/hetzner_twitch_interaktion" root@62.238.49.219 \
  'set -e; cd /opt/twitch-interaktion; mkdir -p game-releases/cookie-crisis/web; find game-releases/cookie-crisis/web -mindepth 1 -delete; tar -xzf - -C game-releases/cookie-crisis/web; ls game-releases/cookie-crisis/web'
