# Twitch-Interaktion-

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
