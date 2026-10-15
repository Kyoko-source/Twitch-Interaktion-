# HTTPS für die React-Webseite auf Hetzner

Für `docker-compose.web.yml` bleibt `SITE_ADDRESS=:80` der HTTP-Eingang.
`Caddyfile.web` leitet Besucher mit HTTP 308 auf `https://62.238.49.219`
weiter. Pfad, Query und die Browser-Hashroute (z. B. `#games/quatschfarm`)
bleiben erhalten. Besucher müssen HTTPS nicht selbst eintippen.

Caddy verwaltet das öffentliche IP-Zertifikat über das Let's-Encrypt-Profil
`shortlived` und erneuert es automatisch. Die Volumes `caddy_data` und
`caddy_config` müssen erhalten bleiben. `FARM_TLS_IP` hat in der Konfiguration
den Standardwert `62.238.49.219`; bei einem Serverwechsel müssen TLS-Adresse
und Weiterleitungsziel gemeinsam angepasst werden.

Bestehende OBS-Browserquellen bleiben auch unter HTTP erreichbar:

- `/overlays/*` (HTML, JavaScript, CSS und Sounds)
- `GET /api/live-news`
- `GET /api/purchase-alerts` (einschließlich Highscore-Alerts)

Alle anderen HTTP-Anfragen gehen auf HTTPS. Neue OBS-URLs aus dem Adminbereich
verwenden automatisch die sichere Adresse der Webseite.

HTTP und HTTPS haben getrennte Browser-Sitzungen. Wer bisher über HTTP
angemeldet war, meldet sich einmal auf der HTTPS-Seite erneut an. Konto,
Tierstimmen, Tiere und Guthaben bleiben erhalten. Mikrofonaufnahmen benötigen
weiterhin die Freigabe des Besuchers; ein bloßer Seitenaufruf fragt sie nicht an.

Nach einer Änderung zuerst im Caddy-Container validieren und dann ohne
Unterbrechung neu laden. Die Datei vorher in den Container kopieren: Ein
Git-Update kann die Hostdatei ersetzen, während ein bestehender Datei-Bind-Mount
noch die alte Datei zeigt. Nach einer Container-Neuerstellung liest der normale
Start wieder die aktuelle Hostdatei ein.

```sh
docker compose -f deploy/docker-compose.web.yml --env-file deploy/.env cp deploy/Caddyfile.web caddy:/tmp/Caddyfile.next
docker compose -f deploy/docker-compose.web.yml --env-file deploy/.env exec -T caddy caddy validate --config /tmp/Caddyfile.next --adapter caddyfile < /dev/null
docker compose -f deploy/docker-compose.web.yml --env-file deploy/.env exec -T caddy caddy reload --config /tmp/Caddyfile.next --adapter caddyfile < /dev/null
```

Prüfen: HTTP-Startseite und `/index.html?test=1` antworten mit 308 und dem
HTTPS-Ziel. Im Browser muss `http://62.238.49.219/#games/quatschfarm` direkt
auf derselben HTTPS-Spielroute landen (`isSecureContext === true`). HTTPS
antwortet ohne weitere Weiterleitung; beide alten HTTP-OBS-Quellen und ihre
Polling-Endpunkte liefern weiterhin 200.
