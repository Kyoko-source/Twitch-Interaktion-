# Hetzner Deployment

Diese App ist eine Streamlit-Webseite mit Supabase als externer Datenbank. Der Hetzner-Server hostet die Webseite, Supabase bleibt dabei weiterhin deine Datenbank.

## Server kaufen

Empfohlen fuer den Start:

- Hetzner Cloud Server: `CX23`
- Standort: Deutschland, z. B. `NBG1` oder `FSN1`
- Image: Ubuntu 24.04
- Netzwerk: IPv4 und IPv6 aktivieren
- Backups: aktivieren

Wenn du spaeter auch die Datenbank auf den Server umziehen willst, nimm eher `CX33`.

## Domain vorbereiten

Lege bei deinem Domain-Anbieter einen DNS-Eintrag an:

- Typ: `A`
- Name: `@` oder Subdomain, z. B. `app`
- Wert: die IPv4-Adresse deines Hetzner-Servers

Optional fuer IPv6:

- Typ: `AAAA`
- Wert: die IPv6-Adresse deines Hetzner-Servers

## Server vorbereiten

Auf dem frischen Ubuntu-Server:

```bash
apt update
apt install -y ca-certificates curl git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## App deployen

Repository auf den Server holen:

```bash
mkdir -p /opt/twitch-interaktion
cd /opt/twitch-interaktion
git clone <DEIN-GIT-REPO-URL> .
```

Environment-Datei anlegen:

```bash
cp deploy/.env.example deploy/.env
nano deploy/.env
```

Trage dort deine echten Werte ein. Ohne Domain kannst du zuerst `SITE_ADDRESS=:80` und `TWITCH_REDIRECT_URI=http://deine-server-ip` verwenden. Mit Domain setzt du spaeter z. B. `SITE_ADDRESS=deine-domain.de` und `TWITCH_REDIRECT_URI=https://deine-domain.de`.

Starten:

```bash
docker compose -f deploy/docker-compose.hetzner.yml --env-file deploy/.env up -d --build
docker compose -f deploy/docker-compose.hetzner.yml --env-file deploy/.env ps
```

Caddy holt automatisch HTTPS-Zertifikate, sobald `SITE_ADDRESS` eine echte Domain ist und die Domain korrekt auf den Server zeigt. Bei `SITE_ADDRESS=:80` laeuft die App zunaechst nur ueber HTTP.

## Updates

Bei spaeteren Aenderungen:

```bash
cd /opt/twitch-interaktion
git pull --ff-only
docker compose -f deploy/docker-compose.hetzner.yml --env-file deploy/.env up -d --build
docker compose -f deploy/docker-compose.hetzner.yml --env-file deploy/.env ps
```

## Pruefen

```bash
docker compose -f deploy/docker-compose.hetzner.yml --env-file deploy/.env logs --tail=100 app
curl -I https://deine-domain.de
```
