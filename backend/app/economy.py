"""Transactional Chicken wallet, game rewards and stream-alert outbox.

All currency changes live in the existing persistent /data volume. Supabase
continues to own identity and the catalog; its old currency columns are retired.
"""
import json
import math
import os
import sqlite3
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException

DAILY_CAP = 120
ROUND_CAP = 25
MIN_RUN_SECONDS = 15
LEVEL_SIZE = 250
SCORE_DIVISORS = {"chicken-jump": 100, "chicken-snake": 10, "chicken-flipper": 2500, "braincell-survivor": 200}
GAME_TITLES = {"chicken-jump": "Chicken Jump", "chicken-snake": "Chicken Snake", "chicken-flipper": "PEPPLE Pinball", "braincell-survivor": "Pepple Survivor"}
PUNISHMENT_CATEGORIES = {"Bestrafungs Ideen", "Idee Bestrafungsrad"}


def utc_now(timestamp=None):
    return datetime.fromtimestamp(time.time() if timestamp is None else timestamp, timezone.utc).isoformat()


class EconomyStore:
    def __init__(self, path: Path):
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        with self.connection() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS wallets (
                    username TEXT PRIMARY KEY, chickens INTEGER NOT NULL DEFAULT 0 CHECK(chickens >= 0),
                    earned INTEGER NOT NULL DEFAULT 0 CHECK(earned >= 0));
                CREATE TABLE IF NOT EXISTS runs (
                    id TEXT PRIMARY KEY, username TEXT NOT NULL, game TEXT NOT NULL, started REAL NOT NULL,
                    completed REAL, score INTEGER, payload TEXT, reward INTEGER NOT NULL DEFAULT 0,
                    reward_day TEXT, is_highscore INTEGER NOT NULL DEFAULT 0);
                CREATE INDEX IF NOT EXISTS runs_user_day ON runs(username, reward_day);
                CREATE INDEX IF NOT EXISTS runs_game_score ON runs(game, score DESC);
                CREATE TABLE IF NOT EXISTS purchases (
                    id TEXT PRIMARY KEY, username TEXT NOT NULL, item_id TEXT NOT NULL, item_name TEXT NOT NULL,
                    category TEXT NOT NULL, price INTEGER NOT NULL CHECK(price >= 0), style TEXT,
                    created REAL NOT NULL, balance_after INTEGER NOT NULL);
                CREATE INDEX IF NOT EXISTS purchases_username ON purchases(username);
                CREATE TABLE IF NOT EXISTS alerts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id TEXT UNIQUE NOT NULL,
                    username TEXT NOT NULL, item_name TEXT NOT NULL, category TEXT NOT NULL,
                    price INTEGER NOT NULL, starts REAL NOT NULL, ends REAL NOT NULL,
                    kind TEXT NOT NULL DEFAULT 'purchase', game TEXT, score INTEGER);
                CREATE INDEX IF NOT EXISTS alerts_ends ON alerts(ends);
                CREATE TABLE IF NOT EXISTS adjustments (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL, delta INTEGER NOT NULL,
                    created REAL NOT NULL);
            """)
        # Additive upgrade of the live ledger; existing balances/events are retained.
        with self.connection(write=True) as db:
            for table, fields in {
                "runs": {"is_highscore": "INTEGER NOT NULL DEFAULT 0"},
                "alerts": {"kind": "TEXT NOT NULL DEFAULT 'purchase'", "game": "TEXT", "score": "INTEGER"},
            }.items():
                existing = {row["name"] for row in db.execute(f"PRAGMA table_info({table})")}
                for field, definition in fields.items():
                    if field not in existing:
                        db.execute(f"ALTER TABLE {table} ADD COLUMN {field} {definition}")

    @contextmanager
    def connection(self, *, write=False):
        db = sqlite3.connect(self.path, timeout=30, isolation_level=None)
        db.row_factory = sqlite3.Row
        try:
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("PRAGMA busy_timeout=30000")
            if write:
                db.execute("BEGIN IMMEDIATE")
            yield db
            if write:
                db.commit()
        except BaseException:
            if write:
                db.rollback()
            raise
        finally:
            db.close()

    @staticmethod
    def require_ready(db):
        if not db.execute("SELECT 1 FROM metadata WHERE key='chickens-v1-ready'").fetchone():
            raise HTTPException(503, "Die Chicken-Umstellung wird gerade vorbereitet. Bitte kurz warten.")

    @staticmethod
    def wallet(db, username):
        row = db.execute("SELECT chickens, earned FROM wallets WHERE username=?", (username,)).fetchone()
        balance, earned = (row["chickens"], row["earned"]) if row else (0, 0)
        return {"chickens": balance, "chickens_earned": earned, "level": earned // LEVEL_SIZE + 1,
                "level_progress": earned % LEVEL_SIZE, "level_target": LEVEL_SIZE}

    def balances(self):
        with self.connection() as db:
            return {row["username"]: self.wallet(db, row["username"]) for row in db.execute("SELECT username FROM wallets")}

    def balance(self, username):
        with self.connection() as db:
            return self.wallet(db, username)

    def mark_ready(self, usernames):
        """One-time cutover; restarting or rerunning never wipes earned funds."""
        with self.connection(write=True) as db:
            if db.execute("SELECT 1 FROM metadata WHERE key='chickens-v1-ready'").fetchone():
                return False
            db.executemany("INSERT OR IGNORE INTO wallets(username) VALUES (?)", [(name,) for name in usernames])
            db.execute("INSERT INTO metadata VALUES ('chickens-v1-ready', ?)", (utc_now(),))
            return True

    def start_run(self, username, game, now=None):
        if game not in SCORE_DIVISORS:
            raise HTTPException(404, "Spiel nicht gefunden")
        now = time.time() if now is None else now
        with self.connection(write=True) as db:
            self.require_ready(db)
            # One active earning round per account, even across tabs or games.
            db.execute("DELETE FROM runs WHERE username=? AND completed IS NULL", (username,))
            run_id = str(uuid4())
            db.execute("INSERT INTO runs(id, username, game, started) VALUES (?, ?, ?, ?)", (run_id, username, game, now))
            return {"run_id": run_id, "minimum_seconds": MIN_RUN_SECONDS, "daily_cap": DAILY_CAP, "round_cap": ROUND_CAP}

    def complete_run(self, username, game, run_id, payload, now=None, legacy_best=None):
        now = time.time() if now is None else now
        with self.connection(write=True) as db:
            self.require_ready(db)
            run = db.execute("SELECT * FROM runs WHERE id=? AND username=? AND game=?", (run_id, username, game)).fetchone()
            if not run:
                raise HTTPException(409, "Diese Runde ist nicht mehr aktiv. Bitte starte eine neue Runde.")
            if run["completed"] is not None:
                if json.loads(run["payload"]) != payload:
                    raise HTTPException(409, "Diese Runde wurde bereits mit einem anderen Ergebnis eingereicht.")
                return self._score_result(db, username, run["reward"], duplicate=True, is_highscore=bool(run["is_highscore"]))
            elapsed = now - run["started"]
            if not math.isfinite(elapsed) or elapsed < 0 or elapsed > 7200:
                raise HTTPException(409, "Diese Runde ist abgelaufen. Bitte starte eine neue Runde.")
            day = datetime.fromtimestamp(now, timezone.utc).date().isoformat()
            earned_today = db.execute("SELECT COALESCE(SUM(reward),0) FROM runs WHERE username=? AND reward_day=?", (username, day)).fetchone()[0]
            score = payload["score"]
            # The local comparison and announcement share the score transaction.
            # Unknown legacy history must never produce a false record claim.
            local_best = db.execute("SELECT COALESCE(MAX(score),0) FROM runs WHERE game=? AND completed IS NOT NULL", (game,)).fetchone()[0]
            is_highscore = legacy_best is not None and score > max(0, legacy_best, local_best)
            skill_reward = score // SCORE_DIVISORS[game]
            time_reward = int(elapsed // 10)
            reward = min(ROUND_CAP, skill_reward, time_reward, max(0, DAILY_CAP - earned_today)) if elapsed >= MIN_RUN_SECONDS else 0
            if game == "braincell-survivor" and payload.get("seconds_survived", 0) > elapsed + 5:
                raise HTTPException(400, "Die angegebene Spielzeit passt nicht zu dieser Runde.")
            db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
            db.execute("UPDATE wallets SET chickens=chickens+?, earned=earned+? WHERE username=?", (reward, reward, username))
            db.execute("UPDATE runs SET completed=?, score=?, payload=?, reward=?, reward_day=?, is_highscore=? WHERE id=?", (now, score, json.dumps(payload, sort_keys=True), reward, day, int(is_highscore), run_id))
            if is_highscore:
                self._queue_alert(db, f"highscore:{run_id}", username, GAME_TITLES[game], "Highscore", 0, now, kind="highscore", game=game, score=score)
            return self._score_result(db, username, reward, daily_remaining=max(0, DAILY_CAP - earned_today - reward), is_highscore=is_highscore)

    def _score_result(self, db, username, reward, duplicate=False, daily_remaining=None, is_highscore=False):
        message = "Diese Runde wurde bereits gewertet." if duplicate else (f"Score gespeichert. +{reward} Chickens!" if reward else "Score gespeichert. Für Chickens: mindestens 15 Sekunden spielen und Punkte sammeln; Tageslimit 120.")
        if is_highscore and not duplicate:
            message = f"Neuer Highscore! Dein Rekord erscheint im Stream. +{reward} Chickens." if reward else "Neuer Highscore! Dein Rekord erscheint im Stream."
        return {"message": message, "chickens_awarded": 0 if duplicate else reward,
                "daily_remaining": daily_remaining, "wallet": self.wallet(db, username), "duplicate": duplicate,
                "is_highscore": is_highscore, "highscore_alert_queued": is_highscore and not duplicate}

    def scores(self, game):
        with self.connection() as db:
            result = db.execute("SELECT username, score, payload, completed FROM runs WHERE game=? AND completed IS NOT NULL ORDER BY score DESC, completed ASC LIMIT 100", (game,)).fetchall()
            return [{**json.loads(row["payload"]), "username": row["username"], "created_at": utc_now(row["completed"])} for row in result]

    def owned_names(self, username):
        with self.connection() as db:
            return {row[0] for row in db.execute("SELECT item_name FROM purchases WHERE username=?", (username,))}

    def buy(self, username, item, request_id, owned=False, now=None):
        now = time.time() if now is None else now
        item_id = str(item["id"])
        price = int(item.get("price") or 0)
        if price < 0:
            raise HTTPException(400, "Ungültiger Preis")
        with self.connection(write=True) as db:
            self.require_ready(db)
            previous = db.execute("SELECT * FROM purchases WHERE id=?", (request_id,)).fetchone()
            if previous:
                if previous["username"] != username or previous["item_id"] != item_id:
                    raise HTTPException(409, "Diese Kaufanfrage gehört zu einem anderen Kauf.")
                return {"message": "Kauf bereits abgeschlossen.", "purchase_id": request_id, "wallet": self.wallet(db, username), "duplicate": True}
            if item.get("style") and (owned or db.execute("SELECT 1 FROM purchases WHERE username=? AND style=?", (username, item["style"])).fetchone()):
                raise HTTPException(409, "Diese Chat-Animation besitzt du bereits.")
            wallet = self.wallet(db, username)
            if wallet["chickens"] < price:
                raise HTTPException(400, "Nicht genug Chickens. Spiele Minispiele, um weitere zu verdienen.")
            db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
            db.execute("UPDATE wallets SET chickens=chickens-? WHERE username=?", (price, username))
            category = str(item.get("category") or "In Stream Rewards").strip()
            db.execute("INSERT INTO purchases VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", (request_id, username, item_id, item["name"], category, price, item.get("style"), now, wallet["chickens"] - price))
            alert = category in PUNISHMENT_CATEGORIES
            if alert:
                self._queue_alert(db, request_id, username, item["name"], category, price, now)
            return {"message": "Gekauft! Deine Bestrafung erscheint im Stream." if alert else "Item gekauft.",
                    "purchase_id": request_id, "wallet": self.wallet(db, username), "stream_alert": alert, "duplicate": False}

    def _queue_alert(self, db, event_key, username, title, category, price, now, kind="purchase", game=None, score=None):
        settings = self._settings(db)
        last_end = db.execute("SELECT MAX(ends) FROM alerts WHERE ends>?", (now,)).fetchone()[0]
        starts = max(now, last_end + 1 if last_end else now)
        db.execute("INSERT INTO alerts(purchase_id, username, item_name, category, price, starts, ends, kind, game, score) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                   (event_key, username, title, category, price, starts, starts + settings["duration_seconds"], kind, game, score))

    @staticmethod
    def _settings(db):
        row = db.execute("SELECT value FROM metadata WHERE key='alert-settings'").fetchone()
        return json.loads(row[0]) if row else {"duration_seconds": 10}

    def settings(self, values=None):
        with self.connection(write=values is not None) as db:
            if values is not None:
                db.execute("INSERT OR REPLACE INTO metadata VALUES ('alert-settings', ?)", (json.dumps(values),))
            return self._settings(db)

    def alerts(self, now=None, include_highscores=True):
        now = time.time() if now is None else now
        with self.connection() as db:
            events = db.execute("SELECT * FROM alerts WHERE ends>? AND (? OR kind='purchase') ORDER BY starts, id LIMIT 50", (now, int(include_highscores))).fetchall()
            return {"server_time": now, "events": [dict(row) for row in events]}

    def recent_purchases(self):
        with self.connection() as db:
            return [dict(row) for row in db.execute("SELECT id, username, item_name, category, price, created FROM purchases ORDER BY created DESC LIMIT 30")]

    def adjust(self, username, delta):
        with self.connection(write=True) as db:
            self.require_ready(db)
            db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
            if self.wallet(db, username)["chickens"] + delta < 0:
                raise HTTPException(400, "Der Kontostand darf nicht negativ werden.")
            db.execute("UPDATE wallets SET chickens=chickens+? WHERE username=?", (delta, username))
            db.execute("INSERT INTO adjustments(username, delta, created) VALUES (?, ?, ?)", (username, delta, time.time()))
            return self.wallet(db, username)


@lru_cache
def economy():
    return EconomyStore(Path(os.getenv("AVIARY_ECONOMY_DB", "/data/economy.sqlite3")))
