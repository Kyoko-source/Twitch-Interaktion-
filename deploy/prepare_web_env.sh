#!/usr/bin/env sh
set -eu

ENV_FILE="${1:-/opt/twitch-interaktion/deploy/.env}"
SERVER_IP="${2:-62.238.49.219}"

touch "$ENV_FILE"

python3 - "$ENV_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8-sig")
text = text.replace("\r\n", "\n").replace("\r", "\n")
text = "\n".join(
    line.replace("nAVIARY_JWT_SECRET=", "AVIARY_JWT_SECRET=", 1)
    for line in text.split("\n")
)
path.write_text(text.strip() + "\n", encoding="utf-8")
PY

append_if_missing() {
  key="$1"
  value="$2"
  if ! grep -q "^${key}=" "$ENV_FILE"; then
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

append_if_missing "AVIARY_JWT_SECRET" "$(openssl rand -hex 32)"
append_if_missing "AVIARY_ADMIN_PASSWORD" "einsmarello"
append_if_missing "PUBLIC_BASE_URL" "http://${SERVER_IP}"
append_if_missing "CORS_ORIGINS" "http://localhost:5173,http://${SERVER_IP}"

chmod 600 "$ENV_FILE"
