# Twitch-Interaktion – Community-Webseite

Community-Seite rund um den Twitch-Kanal: Mitglieder, Chat, Hühner-Wirtschaft
mit Shop, Ranglisten, Events, Hall of Fame, Minispiele und OBS-Overlays für den
Stream. Live unter `https://62.238.49.219`.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `frontend/` | React/Vite-Webseite. Seiten liegen in `src/pages/`, die Minispiele in eigenen Ordnern (`snake/`, `jump/`, `pinball/`, `survivor/`, `farm/`, `nullsignal/`, `nachtwache/`). |
| `backend/` | FastAPI. `app/main.py` enthält die Community-Endpunkte, Wirtschaft (`economy.py`), Live-News, Kaufalarme, Quatschfarm, Nullsignal und After-Play-Multiplayer liegen in eigenen Modulen. |
| `deploy/` | Docker Compose (Backend, Frontend/nginx, Caddy mit HTTPS) und Veröffentlichungsskripte. |
| `database/supabase/` | SQL-Skripte, mit denen die Supabase-Tabellen angelegt wurden. |
| `games/kinderparadies/` | Das Godot-Spiel *After Play* (eigene README). |
| `assets/` | Original-Musik und Kanaltrailer. |
| `docs/` | Notizen zu einzelnen Bereichen (Hühner/Shop, Nachtwache, Nullsignal). |

Daten: Konten, News, Shop-Katalog, Events und Galerie liegen in Supabase. Das
Hühner-Guthaben, Spielrunden, Käufe und Alarme liegen transaktional in SQLite
unter `/data` im Backend-Container, ebenso Chat, Rollen und Systematik.

## Lokal starten

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload

cd ../frontend
npm install
npm run dev
```

Das Backend braucht dieselben Umgebungsvariablen wie auf dem Server (siehe
`deploy/.env.example`).

## Tests

```bash
cd backend && PYTHONPATH=tests python -m unittest discover -s tests
cd frontend && npm run build && npx playwright test
```

## Server

Ubuntu-Server mit Docker. Repository in `/opt/twitch-interaktion`, Zugangsdaten
in `deploy/.env` (Vorlage: `deploy/.env.example`, die echte Datei ist nie in
Git). **`AVIARY_JWT_SECRET` und `AVIARY_ADMIN_PASSWORD` müssen gesetzt sein**:
Das Repository ist öffentlich, es gibt deshalb keine eingebauten Standardwerte.

Erstinstallation (einmalig):

```bash
apt update && apt install -y ca-certificates curl git
curl -fsSL https://get.docker.com | sh
git clone https://github.com/Kyoko-source/Twitch-Interaktion-.git /opt/twitch-interaktion
cd /opt/twitch-interaktion && cp deploy/.env.example deploy/.env && nano deploy/.env
docker compose -f deploy/docker-compose.web.yml --env-file deploy/.env up -d --build
```

Update nach einem Push auf `main`:

```bash
cd /opt/twitch-interaktion
git pull --ff-only
docker compose -f deploy/docker-compose.web.yml --env-file deploy/.env up -d --build backend frontend
```

HTTPS und die HTTP-Ausnahmen für OBS-Overlays: `deploy/WEB-HTTPS.md`.
After-Play-Releases (Spiel-ZIP und Webseite): `docs/NACHTWACHE.md` und
`deploy/publish-kinderparadies.ps1`.
