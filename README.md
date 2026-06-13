# Twitch-Interaktion-

## Railway Deployment

Das Repository enthält ein `Dockerfile` und eine `railway.json` für Railway.
Folgende Variablen müssen im Railway-Service gesetzt werden:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_KEY`
- `TWITCH_CLIENT_ID`
- `TWITCH_CLIENT_SECRET`
- `TWITCH_REDIRECT_URI`

`TWITCH_REDIRECT_URI` muss auf die öffentliche Railway-Domain zeigen. Railway setzt
`PORT` automatisch; der Container startet Streamlit auf diesem Port.

## Supabase Datenbank

Falls du die neue Gast-Registrierung nutzen möchtest, lege in der Supabase-Tabelle `users` die Spalte `password_hash` an.

Du kannst dazu den SQL-Editor in Supabase verwenden und folgenden Befehl ausführen:

```sql
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS password_hash text;
```

Alternativ findest du die gleiche Migration in der Datei `add_password_hash_column.sql`.

## Daily Rewards

Für die täglichen Login-Belohnungen muss zusätzlich die Tabelle `daily_rewards` angelegt werden.
Die Migration liegt in `add_daily_rewards_table.sql` und kann im Supabase SQL-Editor ausgeführt werden.

## News, Patch Notes, Shop-Kategorien und Bestrafungsrad

Für den News-Reiter muss `add_news_posts_table.sql` ausgeführt werden.
Für bearbeitbare Patch Notes im Admin-Bereich muss `add_patch_notes_table.sql` ausgeführt werden.
Für Shop-Kategorien, Kaufstatus und das Bestrafungsrad muss `add_shop_categories_and_wheel.sql` ausgeführt werden.

## Chicken-Markt

Für den Kurs-Reiter mit Marktgegenständen, Käufen, Verkäufen und Profil-Inventar muss `add_market_tables.sql` ausgeführt werden.

## Dungeons and Dragons

Für den Dungeons-and-Dragons-Reiter mit Lobbys, Party und Würfelchronik muss `add_dnd_tables.sql` ausgeführt werden.
