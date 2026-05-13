# Twitch-Interaktion-

## Supabase Datenbank

Falls du die neue Gast-Registrierung nutzen möchtest, lege in der Supabase-Tabelle `users` die Spalte `password_hash` an.

Du kannst dazu den SQL-Editor in Supabase verwenden und folgenden Befehl ausführen:

```sql
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS password_hash text;
```

Alternativ findest du die gleiche Migration in der Datei `add_password_hash_column.sql`.
