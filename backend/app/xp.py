"""Level system: XP for everything members do on the site, levels with titles, rewards and unlocks.

XP lives in the economy database next to the wallets. Every award runs inside the caller's write
transaction, is idempotent per `ref`, and respects a daily cap per source so that nothing can be
farmed. Level-ups pay Chickens and Credits straight into the wallet; every fifth level is
announced in the stream through the existing alert queue.

Members who were active before the level system existed get their XP once, from their history
(completed rounds, earned Chickens, purchases, casino play), without retroactive rewards.
"""
from __future__ import annotations

import time
from datetime import datetime, timedelta, timezone
from typing import Any

LEVEL_CAP = 100

# Daily XP caps per source (UTC day).
CAPS = {"start": 60, "game": 400, "casino": 150, "shop": 200, "chat": 45, "daily": 80, "bonus": 1000}

TITLES = [
    (1, "Küken"), (3, "Junghenne"), (5, "Hofhenne"), (8, "Flinkes Huhn"), (12, "Federheld"),
    (16, "Eierwächter"), (20, "Hofmeister"), (25, "Goldfeder"), (30, "Hühnerbaron"),
    (40, "Legende vom Hof"), (50, "Mythisches Huhn"),
]

UNLOCKS = [
    {"level": 5, "id": "derby-crown", "name": "Derby-Krone", "text": "Dein Pferd trägt im Chicken Derby eine goldene Krone."},
    {"level": 10, "id": "jump-golden", "name": "Goldenes Huhn", "text": "Dein Huhn in Chicken Jump glänzt golden."},
    {"level": 15, "id": "defense-korn", "name": "Kornspeicher", "text": "Chicken Defense startet mit +40 Korn."},
    {"level": 20, "id": "derby-champion", "name": "Champion-Glanz", "text": "Dein Derby-Pferd zieht eine Spur aus Funken."},
    {"level": 25, "id": "derby-phoenix", "name": "Phönix-Hengst", "text": "Skin fürs Chicken Derby: Dein Pferd wird zum goldenen Phönix mit Feuermähne, Flammenflügeln und Feuerspur.", "skin": True},
    {"level": 25, "id": "jump-rainbow", "name": "Regenbogenspur", "text": "In Chicken Jump zieht dein Huhn eine Regenbogenspur."},
]


def need(level: int) -> int:
    """XP from `level` to `level + 1`."""
    return 100 + 40 * (level - 1)


def level_for(xp: int) -> tuple[int, int, int]:
    """(level, xp into this level, xp needed for the next one)."""
    level, rest = 1, max(0, int(xp))
    while level < LEVEL_CAP and rest >= need(level):
        rest -= need(level)
        level += 1
    return level, rest, need(level)


def title_for(level: int) -> str:
    return [name for at, name in TITLES if level >= at][-1]


def rewards_for(level: int) -> dict[str, int]:
    """What reaching `level` pays."""
    milestone = level % 5 == 0
    return {"chickens": 10 + 2 * level + (50 if milestone else 0), "credits": 2 + (10 if milestone else 0)}


def unlocks_for(level: int) -> list[str]:
    return [u["id"] for u in UNLOCKS if level >= u["level"]]


def tree() -> list[dict[str, Any]]:
    """Every level from 1 to LEVEL_CAP with the total XP it needs and what reaching it brings."""
    titles = dict(TITLES)
    total, levels = 0, []
    for level in range(1, LEVEL_CAP + 1):
        if level > 1:
            total += need(level - 1)
        levels.append({"level": level, "xp": total, "rewards": rewards_for(level) if level > 1 else None,
                       "title": titles.get(level), "unlocks": [u["id"] for u in UNLOCKS if u["level"] == level]})
    return levels


def day_of(now: float) -> str:
    return datetime.fromtimestamp(now, timezone.utc).date().isoformat()


def ensure(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS xp (
        username TEXT PRIMARY KEY, xp INTEGER NOT NULL DEFAULT 0, level INTEGER NOT NULL DEFAULT 1,
        streak INTEGER NOT NULL DEFAULT 0, last_day TEXT)""")
    db.execute("""CREATE TABLE IF NOT EXISTS xp_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL, source TEXT NOT NULL, amount INTEGER NOT NULL,
        ref TEXT UNIQUE, day TEXT NOT NULL, created REAL NOT NULL)""")
    db.execute("CREATE INDEX IF NOT EXISTS xp_log_user_day ON xp_log(username, day, source)")


def _table_exists(db, name: str) -> bool:
    return bool(db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)).fetchone())


def history_xp(db, username: str) -> int:
    """XP a member earned before the level system existed (read-only)."""
    total = 0
    row = db.execute("SELECT COUNT(*), COALESCE(SUM(reward), 0) FROM runs WHERE username=? AND completed IS NOT NULL", (username,)).fetchone()
    total += row[0] * 15 + row[1] * 2
    total += int(db.execute("SELECT COALESCE(SUM(price), 0) FROM purchases WHERE username=?", (username,)).fetchone()[0]) // 5
    if _table_exists(db, "slot_spins"):
        total += min(3000, 2 * int(db.execute("SELECT COALESCE(SUM(bet), 0) FROM slot_spins WHERE username=?", (username,)).fetchone()[0]))
    if _table_exists(db, "horse_races"):
        row = db.execute("SELECT COUNT(*), COALESCE(SUM(payout > 0), 0) FROM horse_races WHERE username=?", (username,)).fetchone()
        total += row[0] * 20 + row[1] * 20
    return total


def _row(db, username: str):
    row = db.execute("SELECT * FROM xp WHERE username=?", (username,)).fetchone()
    if row:
        return dict(row)
    xp = history_xp(db, username)
    return {"username": username, "xp": xp, "level": level_for(xp)[0], "streak": 0, "last_day": None, "_new": True}


def summary(db, username: str) -> dict[str, Any]:
    """Level fields for the wallet. Works on read-only connections (no row is written)."""
    if not _table_exists(db, "xp"):
        xp = history_xp(db, username)
        row = {"xp": xp, "streak": 0}
    else:
        row = _row(db, username)
    level, into, needed = level_for(row["xp"])
    nxt = next((at for at, _ in TITLES if at > level), None)
    return {"level": level, "xp": row["xp"], "level_progress": into, "level_target": needed, "level_title": title_for(level),
            "next_title_level": nxt, "streak": row.get("streak", 0), "unlocks": unlocks_for(level)}


def _store(db, row: dict) -> None:
    db.execute("INSERT INTO xp(username, xp, level, streak, last_day) VALUES (?, ?, ?, ?, ?) "
               "ON CONFLICT(username) DO UPDATE SET xp=excluded.xp, level=excluded.level, streak=excluded.streak, last_day=excluded.last_day",
               (row["username"], row["xp"], row["level"], row["streak"], row["last_day"]))


def award(db, username: str, source: str, amount: int, ref: str | None = None, now: float | None = None, queue_alert=None) -> dict[str, Any]:
    """Give XP inside the caller's write transaction. Returns {"amount", "levelups"}."""
    now = time.time() if now is None else now
    amount = int(amount)
    if amount <= 0 or not username:
        return {"amount": 0, "levelups": []}
    ensure(db)
    if ref and db.execute("SELECT 1 FROM xp_log WHERE ref=?", (ref,)).fetchone():
        return {"amount": 0, "levelups": []}
    day = day_of(now)
    cap = CAPS.get(source)
    if cap is not None:
        used = int(db.execute("SELECT COALESCE(SUM(amount), 0) FROM xp_log WHERE username=? AND day=? AND source=?", (username, day, source)).fetchone()[0])
        amount = min(amount, max(0, cap - used))
    if amount <= 0:
        return {"amount": 0, "levelups": []}
    row = _row(db, username)
    before = level_for(row["xp"])[0]
    row["xp"] += amount
    after = level_for(row["xp"])[0]
    row["level"] = after
    _store(db, row)
    db.execute("INSERT INTO xp_log(username, source, amount, ref, day, created) VALUES (?, ?, ?, ?, ?, ?)", (username, source, amount, ref, day, now))
    levelups = []
    for level in range(before + 1, after + 1):
        reward = rewards_for(level)
        db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
        db.execute("UPDATE wallets SET chickens=chickens+?, credits=credits+? WHERE username=?", (reward["chickens"], reward["credits"], username))
        unlocked = [u for u in UNLOCKS if u["level"] == level]
        new_title = next((name for at, name in TITLES if at == level), None)
        levelups.append({"level": level, "title": title_for(level), "new_title": new_title, "rewards": reward, "unlocks": unlocked})
        if level % 5 == 0 and queue_alert:
            queue_alert(db, f"levelup:{username}:{level}", username, f"LEVEL {level}", title_for(level), 0, now, kind="levelup", score=level)
    return {"amount": amount, "levelups": levelups}


def daily(db, username: str, now: float | None = None, queue_alert=None) -> dict[str, Any]:
    """First visit of the day: XP with a streak bonus (up to 10 days in a row)."""
    now = time.time() if now is None else now
    ensure(db)
    row = _row(db, username)
    today = day_of(now)
    if row["last_day"] == today:
        return {"amount": 0, "levelups": [], "streak": row["streak"]}
    yesterday = (datetime.fromtimestamp(now, timezone.utc).date() - timedelta(days=1)).isoformat()
    row["streak"] = row["streak"] + 1 if row["last_day"] == yesterday else 1
    row["last_day"] = today
    _store(db, row)
    result = award(db, username, "daily", 20 + 5 * min(row["streak"] - 1, 10), ref=f"daily:{username}:{today}", now=now, queue_alert=queue_alert)
    return {**result, "streak": row["streak"]}


def recent(db, username: str, limit: int = 12) -> list[dict[str, Any]]:
    ensure(db)
    return [dict(r) for r in db.execute("SELECT source, amount, created FROM xp_log WHERE username=? ORDER BY id DESC LIMIT ?", (username, limit))]


def leaderboard(db, limit: int = 20) -> list[dict[str, Any]]:
    ensure(db)
    return [{"username": r["username"], "xp": r["xp"], "level": level_for(r["xp"])[0], "level_title": title_for(level_for(r["xp"])[0])}
            for r in db.execute("SELECT username, xp FROM xp ORDER BY xp DESC LIMIT ?", (limit,))]
