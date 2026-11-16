"""Public member profiles: stats from the local ledger (derby, slots, minigames, XP), badges,
an activity calendar and the profile look the member picked.

Everything is read from SQLite tables other modules own; tables that do not exist yet simply
count as empty, so a fresh install or a member who never played still gets a full profile.
"""
from __future__ import annotations

import json
import time
from datetime import datetime, timedelta, timezone
from typing import Any

from . import cookie as cookie_game
from . import xp as xp_levels

HORSE_NAMES = ["Donnerhuf", "Goldmähne", "Sturmwind", "Mitternacht", "Feuerfunke", "Silberpfeil", "Kleiner Keks", "Royal Gacker", "Nebelläufer"]
GAME_NAMES = {
    "chicken-jump": "Chicken Jump", "chicken-snake": "Chicken Snake", "chicken-flipper": "PEPPLE Pinball",
    "braincell-survivor": "Pepple Survivor", "chicken-defense": "Chicken Defense",
}
# Profile looks; some need a level.
THEMES = [
    {"id": "neon", "name": "Neon", "level": 1},
    {"id": "sunset", "name": "Sonnenuntergang", "level": 1},
    {"id": "ocean", "name": "Ozean", "level": 1},
    {"id": "forest", "name": "Wald", "level": 3},
    {"id": "candy", "name": "Zuckerwatte", "level": 5},
    {"id": "midnight", "name": "Mitternacht", "level": 10},
    {"id": "inferno", "name": "Inferno", "level": 20},
    {"id": "gold", "name": "Goldfeder", "level": 25},
]
HEATMAP_DAYS = 7 * 26


def _exists(db, name: str) -> bool:
    return bool(db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)).fetchone())


def ensure(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS profile_prefs (
        username TEXT PRIMARY KEY, theme TEXT NOT NULL DEFAULT 'neon', showcase TEXT NOT NULL DEFAULT '[]',
        updated REAL NOT NULL DEFAULT 0)""")
    columns = {row[1] for row in db.execute("PRAGMA table_info(profile_prefs)")}
    if "christmas" not in columns:
        db.execute("ALTER TABLE profile_prefs ADD COLUMN christmas TEXT NOT NULL DEFAULT 'ask'")


# Christmas look: "ask" (never answered), "declined" (said no, ask again next login), "on", "off" (switched off in the profile).
CHRISTMAS_MODES = {"ask", "declined", "on", "off"}


def christmas(db, username: str) -> str:
    if not _exists(db, "profile_prefs"):
        return "ask"
    columns = {row[1] for row in db.execute("PRAGMA table_info(profile_prefs)")}
    if "christmas" not in columns:
        return "ask"
    row = db.execute("SELECT christmas FROM profile_prefs WHERE username=?", (username,)).fetchone()
    return row[0] if row and row[0] in CHRISTMAS_MODES else "ask"


def set_christmas(db, username: str, mode: str, now: float | None = None) -> str:
    if mode not in CHRISTMAS_MODES - {"ask"}:
        raise ValueError("Unbekannter Modus.")
    ensure(db)
    db.execute("INSERT INTO profile_prefs(username, christmas, updated) VALUES (?, ?, ?) "
               "ON CONFLICT(username) DO UPDATE SET christmas=excluded.christmas, updated=excluded.updated",
               (username, mode, time.time() if now is None else now))
    return mode


def prefs(db, username: str) -> dict[str, Any]:
    if not _exists(db, "profile_prefs"):
        return {"theme": "neon", "showcase": []}
    row = db.execute("SELECT theme, showcase FROM profile_prefs WHERE username=?", (username,)).fetchone()
    if not row:
        return {"theme": "neon", "showcase": []}
    try:
        showcase = [str(b) for b in json.loads(row[1])][:3]
    except (TypeError, ValueError):
        showcase = []
    return {"theme": row[0], "showcase": showcase}


def save_prefs(db, username: str, theme: str, showcase: list[str], level: int, earned: set[str], now: float | None = None) -> dict[str, Any]:
    """Store theme + up to 3 showcased badges. Locked themes and unearned badges are refused."""
    known = {t["id"]: t for t in THEMES}
    if theme not in known:
        raise ValueError("Diesen Look gibt es nicht.")
    if level < known[theme]["level"]:
        raise ValueError(f"Der Look „{known[theme]['name']}“ wird ab Level {known[theme]['level']} frei.")
    picked = []
    for badge in showcase:
        if badge in earned and badge not in picked:
            picked.append(badge)
    picked = picked[:3]
    ensure(db)
    db.execute("INSERT INTO profile_prefs(username, theme, showcase, updated) VALUES (?, ?, ?, ?) "
               "ON CONFLICT(username) DO UPDATE SET theme=excluded.theme, showcase=excluded.showcase, updated=excluded.updated",
               (username, theme, json.dumps(picked), time.time() if now is None else now))
    return {"theme": theme, "showcase": picked}


def derby(db, username: str) -> dict[str, Any]:
    out = {"races": 0, "won": 0, "net": 0, "best_payout": 0, "favorite": None, "horses": [0] * 9, "streak": 0}
    if not _exists(db, "horse_races"):
        return out
    races, won, net, best = db.execute(
        "SELECT COUNT(*), COALESCE(SUM(payout > 0), 0), COALESCE(SUM(payout - stake), 0), COALESCE(MAX(payout), 0) FROM horse_races WHERE username=?",
        (username,)).fetchone()
    out.update(races=int(races), won=int(won), net=int(net), best_payout=int(best))
    picks = db.execute("SELECT horse, COUNT(*), COALESCE(SUM(payout > 0), 0) FROM horse_races WHERE username=? GROUP BY horse ORDER BY COUNT(*) DESC, horse",
                       (username,)).fetchall()
    for horse, count, wins in picks:
        if 0 <= int(horse) < 9:
            out["horses"][int(horse)] = int(count)
    if picks:
        horse, count, wins = picks[0]
        out["favorite"] = {"id": int(horse), "name": HORSE_NAMES[int(horse)] if 0 <= int(horse) < 9 else "?", "bets": int(count), "wins": int(wins)}
    # Longest run of won bets in a row.
    best_run = run = 0
    for (payout,) in db.execute("SELECT payout FROM horse_races WHERE username=? ORDER BY created", (username,)):
        run = run + 1 if payout > 0 else 0
        best_run = max(best_run, run)
    out["streak"] = best_run
    return out


def slots(db, username: str) -> dict[str, Any]:
    out = {"spins": 0, "wagered": 0, "won": 0, "best_win": 0, "best_mult": 0.0, "bonuses": 0, "best_wheel": 0}
    if not _exists(db, "slot_spins"):
        return out
    spins, wagered, won, best = db.execute(
        "SELECT COUNT(*), COALESCE(SUM(bet), 0), COALESCE(SUM(win), 0), COALESCE(MAX(win), 0) FROM slot_spins WHERE username=?", (username,)).fetchone()
    mult = db.execute("SELECT COALESCE(MAX(CAST(win AS REAL) / bet), 0) FROM slot_spins WHERE username=?", (username,)).fetchone()[0]
    out.update(spins=int(spins), wagered=int(wagered), won=int(won), best_win=int(best), best_mult=round(float(mult), 1))
    bonuses = wheel = 0
    for (result,) in db.execute("SELECT result FROM slot_spins WHERE username=? AND result LIKE '%\"awarded\"%'", (username,)):
        try:
            bonus = json.loads(result).get("bonus")
        except ValueError:
            continue
        if bonus:
            bonuses += 1
            wheel = max(wheel, int((bonus.get("wheel") or {}).get("value") or bonus.get("awarded") or 0))
    out.update(bonuses=bonuses, best_wheel=wheel)
    return out


def games(db, username: str) -> list[dict[str, Any]]:
    if not _exists(db, "runs"):
        return []
    out = []
    rows = db.execute("SELECT game, COUNT(*), MAX(score) FROM runs WHERE username=? AND completed IS NOT NULL GROUP BY game", (username,)).fetchall()
    for game, plays, best in rows:
        if best is None:
            continue
        place = 1 + int(db.execute(
            "SELECT COUNT(*) FROM (SELECT username, MAX(score) AS best FROM runs WHERE game=? AND completed IS NOT NULL GROUP BY username) WHERE best > ?",
            (game, best)).fetchone()[0])
        out.append({"game": game, "name": GAME_NAMES.get(game, game), "plays": int(plays), "best": int(best), "place": place})
    out.sort(key=lambda g: (g["place"], -g["plays"]))
    return out


def shop(db, username: str) -> list[dict[str, Any]]:
    if not _exists(db, "purchases"):
        return []
    return [{"name": r[0], "category": r[1], "created": r[2]}
            for r in db.execute("SELECT item_name, category, MIN(created) FROM purchases WHERE username=? GROUP BY item_name ORDER BY MIN(created) DESC LIMIT 40", (username,))]


def activity(db, username: str, now: float) -> dict[str, Any]:
    """XP per day for the activity calendar (last 26 weeks) plus the latest events."""
    today = datetime.fromtimestamp(now, timezone.utc).date()
    start = today - timedelta(days=HEATMAP_DAYS - 1)
    days: dict[str, int] = {}
    recent: list[dict[str, Any]] = []
    first = None
    if _exists(db, "xp_log"):
        for day, amount in db.execute("SELECT day, SUM(amount) FROM xp_log WHERE username=? AND day>=? GROUP BY day", (username, start.isoformat())):
            days[str(day)] = int(amount)
        recent = [dict(source=r[0], amount=int(r[1]), created=r[2]) for r in
                  db.execute("SELECT source, amount, created FROM xp_log WHERE username=? ORDER BY id DESC LIMIT 12", (username,))]
        row = db.execute("SELECT MIN(created) FROM xp_log WHERE username=?", (username,)).fetchone()
        first = row[0] if row else None
    active_days = 0
    if _exists(db, "xp_log"):
        active_days = int(db.execute("SELECT COUNT(DISTINCT day) FROM xp_log WHERE username=?", (username,)).fetchone()[0])
    return {"start": start.isoformat(), "days": days, "recent": recent, "active_days": active_days, "first_seen": first}


def xp_rank(db, username: str, xp: int) -> int:
    if not _exists(db, "xp"):
        return 1
    return 1 + int(db.execute("SELECT COUNT(*) FROM xp WHERE xp > ? AND username != ?", (xp, username)).fetchone()[0])


# Badges: id, name, text, icon (frontend key), tier (bronze/silver/gold/legend) and a test with progress.
def badges(level: dict[str, Any], d: dict[str, Any], s: dict[str, Any], g: list[dict[str, Any]], purchases: list, act: dict[str, Any], earned_chickens: int, cookie: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    best_place = min((x["place"] for x in g), default=0)
    plays = sum(x["plays"] for x in g)

    def b(id_, name, text, icon, tier, value, goal):
        return {"id": id_, "name": name, "text": text, "icon": icon, "tier": tier, "earned": value >= goal,
                "progress": min(1.0, value / goal) if goal else 1.0, "value": min(value, goal), "goal": goal}

    return [
        b("first-win", "Erster Zieleinlauf", "Eine Derby-Wette gewonnen.", "horse", "bronze", d["won"], 1),
        b("derby-regular", "Stammgast der Bahn", "50 Derby-Rennen gewettet.", "flag", "silver", d["races"], 50),
        b("hot-streak", "Glückssträhne", "3 Derby-Wetten in Folge gewonnen.", "flame", "gold", d["streak"], 3),
        b("slot-bonus", "Goldenes Ei", "Den Eier-Bonus im Chicken Jackpot ausgelöst.", "egg", "bronze", s["bonuses"], 1),
        b("high-roller", "High Roller", "Einen Slot-Gewinn von mindestens ×50 geholt.", "gem", "gold", int(s["best_mult"]), 50),
        b("wheel-50", "Glücksrad-Profi", "50+ Freispiele auf dem Freispiel-Rad gedreht.", "sparkles", "legend", s["best_wheel"], 50),
        b("gamer", "Spielkind", "100 Minispiel-Runden gespielt.", "gamepad", "silver", plays, 100),
        b("record", "Rekordhalter", "Platz 1 in einem Minispiel.", "trophy", "legend", 1 if best_place == 1 else 0, 1),
        b("podium", "Auf dem Treppchen", "Top 3 in einem Minispiel.", "medal", "silver", 1 if 0 < best_place <= 3 else 0, 1),
        b("shopper", "Sammler", "3 Dinge im Shop gekauft.", "bag", "bronze", len(purchases), 3),
        b("streak-7", "Treue Seele", "7 Tage am Stück vorbeigeschaut.", "calendar", "silver", int(level.get("streak") or 0), 7),
        b("active-30", "Hofbewohner", "An 30 verschiedenen Tagen aktiv.", "home", "gold", act["active_days"], 30),
        b("rich", "Goldgrube", "10.000 Chickens erspielt.", "coins", "gold", earned_chickens, 10000),
        b("level-12", "Federheld", "Level 12 erreicht.", "star", "silver", int(level["level"]), 12),
        b("phoenix", "Phönix", "Level 25: der Phönix-Hengst gehört dir.", "phoenix", "legend", int(level["level"]), 25),
    ] + ([b("cookie-master", cookie_game.TITLE, "Santa's Cookie Crisis: 1.000.000 Kekse gebacken.", "cookie", "legend", 1, 1)] if cookie and cookie.get("finished") else [])


def card(db, username: str, earned_chickens: int = 0, now: float | None = None) -> dict[str, Any]:
    now = time.time() if now is None else now
    level = xp_levels.summary(db, username)
    d, s, g, p = derby(db, username), slots(db, username), games(db, username), shop(db, username)
    act = activity(db, username, now)
    cookie = cookie_game.summary(db, username)
    badge_list = badges(level, d, s, g, p, act, earned_chickens, cookie)
    unlock_info = {u["id"]: u for u in xp_levels.UNLOCKS}
    return {
        "level": {**level, "xp_rank": xp_rank(db, username, int(level["xp"]))},
        "derby": d, "slots": s, "games": g, "shop": p, "activity": act, "badges": badge_list, "cookie": cookie,
        "unlocks": [{"id": uid, "name": unlock_info[uid]["name"], "text": unlock_info[uid]["text"], "level": unlock_info[uid]["level"], "skin": bool(unlock_info[uid].get("skin"))}
                    for uid in level["unlocks"] if uid in unlock_info],
        "next_unlock": next(({"name": u["name"], "level": u["level"]} for u in xp_levels.UNLOCKS if u["level"] > level["level"]), None),
        "prefs": prefs(db, username),
        "themes": [{**t, "unlocked": level["level"] >= t["level"]} for t in THEMES],
    }
