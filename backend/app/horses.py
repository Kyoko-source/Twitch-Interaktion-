"""Chicken Derby: a nine-horse race over five laps. Starting a race costs 50 Credits, the player
bets them on one horse and a win doubles them (100 Credits back).

The server decides everything inside one SQLite transaction: the stake is debited, the winner is
drawn with a CSPRNG (every horse has the same 1/9 chance), the whole race is scripted and the
payout is credited. The client only plays the script back, so a race cannot be steered or
replayed from the browser. Each request id books at most one race.

The script gives every horse a finish time and a "shape": its share of the total distance at
evenly spaced points of its own race time. Shapes come from a mean-reverting random walk with
surges and slumps, so the lead changes during the race. The drawn winner gets the earliest finish
time, which guarantees it crosses the line first however the shapes look.
"""
from __future__ import annotations

import json
import secrets
import time
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, Field

from . import ratelimit
from .auth import current_user
from .economy import economy
from . import xp as xp_levels

router = APIRouter(prefix="/api/horses", tags=["horses"])
STAKE = 50                  # credits per race
PAYOUT = 100                # credits back when the chosen horse wins (stake doubled)
LAPS = 5
SEGMENTS = 50               # shape resolution
COUNTDOWN = 10             # seconds between booking and the start, as the client shows it
LIVE_WINDOW = 15 * 60      # seconds a race stays on the stream overlay's list
HORSES = [
    {"id": 0, "name": "Donnerhuf"},
    {"id": 1, "name": "Goldmähne"},
    {"id": 2, "name": "Sturmwind"},
    {"id": 3, "name": "Mitternacht"},
    {"id": 4, "name": "Feuerfunke"},
    {"id": 5, "name": "Silberpfeil"},
    {"id": 6, "name": "Kleiner Keks"},
    {"id": 7, "name": "Royal Gacker"},
    {"id": 8, "name": "Nebelläufer"},
]
_rng = secrets.SystemRandom()


def _shape(rng, style: str) -> list[float]:
    """Cumulative distance share (0..1) at SEGMENTS + 1 evenly spaced points of the horse's race."""
    speeds, v, burst, burst_left = [], 1.0, 0.0, 0
    for k in range(SEGMENTS):
        u = k / (SEGMENTS - 1)
        v += rng.gauss(0, 0.038)
        v = v * 0.82 + 0.18                       # pull back towards normal pace
        if burst_left <= 0 and rng.random() < 0.09:
            burst, burst_left = rng.choice([1, -1]) * rng.uniform(0.09, 0.2), rng.randint(2, 4)
        speed = v + (burst if burst_left > 0 else 0)
        burst_left -= 1
        if style == "comeback":                   # hangs back, then storms home
            speed *= 0.9 if 0.25 < u < 0.6 else 1.16 if u > 0.72 else 1
        elif style == "frontrunner":              # leads early, pays for it late
            speed *= 1.13 if u < 0.4 else 0.9 if u > 0.75 else 1
        elif style == "fade":                     # in front late on, then runs out of steam
            speed *= 1.1 if 0.45 < u < 0.82 else 0.82 if u > 0.88 else 1
        speeds.append(min(1.6, max(0.55, speed)))
    total, run, shape = sum(speeds), 0.0, [0.0]
    for speed in speeds:
        run += speed
        shape.append(round(run / total, 5))
    shape[-1] = 1.0
    return shape


def race(chosen: int, rng=None) -> dict[str, Any]:
    rng = rng or _rng
    winner = rng.randrange(len(HORSES))
    others = [h["id"] for h in HORSES if h["id"] != winner]
    rng.shuffle(others)
    order = [winner, *others]
    finish = [0.0] * len(HORSES)
    t = rng.uniform(66.0, 73.0)
    finish[winner] = round(t, 3)
    t += rng.uniform(0.04, 0.5)                   # second place is always close
    for place, horse in enumerate(others):
        finish[horse] = round(t, 3)
        t += rng.uniform(0.06, 0.35 if place < 3 else 0.6)
    styles = ["normal"] * len(HORSES)
    styles[winner] = rng.choice(["comeback", "comeback", "normal", "frontrunner"])
    styles[order[1]] = rng.choice(["frontrunner", "normal", "fade"])
    if chosen != winner and rng.random() < 0.35:
        styles[chosen] = "fade"                   # leads late on, then breaks your heart
    shapes = [_shape(rng, styles[h["id"]]) for h in HORSES]
    return {"winner": winner, "order": order, "finish": finish, "shapes": shapes, "laps": LAPS}


def ensure_table(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS horse_races (
        request_id TEXT PRIMARY KEY, username TEXT NOT NULL, horse INTEGER NOT NULL,
        winner INTEGER NOT NULL, stake INTEGER NOT NULL, payout INTEGER NOT NULL,
        created REAL NOT NULL, result TEXT NOT NULL)""")
    db.execute("CREATE INDEX IF NOT EXISTS horse_races_created ON horse_races(created)")


def recent_winners(db, limit: int = 10) -> list[int]:
    return [int(r[0]) for r in db.execute("SELECT winner FROM horse_races ORDER BY created DESC LIMIT ?", (limit,)).fetchall()]


def stats(db) -> dict[str, Any]:
    """All races ever: how often each horse won, how many races there were and how many bets won."""
    wins = [0] * len(HORSES)
    for winner, count in db.execute("SELECT winner, COUNT(*) FROM horse_races GROUP BY winner").fetchall():
        if 0 <= int(winner) < len(HORSES):
            wins[int(winner)] = int(count)
    races, won = db.execute("SELECT COUNT(*), COALESCE(SUM(payout > 0), 0) FROM horse_races").fetchone()
    return {"races": int(races), "won": int(won), "wins": wins, "chance": round(1 / len(HORSES), 5)}


# Skins for the player's own horse. Phönix comes with level 25; the others are bought in the shop.
SKINS = {
    "phoenix": {"name": "Phönix-Hengst", "level": 25, "text": "Goldener Phönix mit Feuermähne, Flammenflügeln und Feuerspur."},
    "zebra": {"name": "Zebra-Blitz", "price": 3000, "text": "Schwarz-weiß gestreift mit elektrisch blauer Mähne und Blitzfunken in der Spur."},
    "ghost": {"name": "Geisterross", "price": 6000, "text": "Halb durchsichtig, eisig leuchtend und mit Nebelschwaden, die hinter ihm herwehen."},
    "unicorn": {"name": "Regenbogen-Einhorn", "price": 10000, "text": "Schneeweißes Einhorn mit goldenem Horn, Regenbogenmähne und einer Spur aus Regenbogen-Sternen."},
}
SKIN_SHOP_ITEMS = [
    {"id": f"derby-skin-{key}", "name": f"Derby-Skin: {skin['name']}", "description": skin["text"], "price": skin["price"], "category": "Derby Skins", "skin": key}
    for key, skin in SKINS.items() if "price" in skin
]
SKIN_ITEM_IDS = {item["id"]: item["skin"] for item in SKIN_SHOP_ITEMS}


def ensure_skin_table(db) -> None:
    db.execute("CREATE TABLE IF NOT EXISTS derby_skin_prefs (username TEXT PRIMARY KEY, skin TEXT NOT NULL, updated REAL NOT NULL)")


def owned_skins(db, username: str) -> list[str]:
    """Skins this member may use: bought ones (oldest purchase first) plus the level-25 Phönix."""
    marks = ",".join("?" * len(SKIN_ITEM_IDS))
    bought = [SKIN_ITEM_IDS[row[0]] for row in db.execute(
        f"SELECT item_id FROM purchases WHERE username=? AND item_id IN ({marks}) ORDER BY created", (username, *SKIN_ITEM_IDS))]
    try:
        phoenix = "derby-phoenix" in xp_levels.summary(db, username)["unlocks"]
    except Exception:  # the level system must never take the skins down
        phoenix = False
    return list(dict.fromkeys([*(["phoenix"] if phoenix else []), *bought]))


def active_skin(db, username: str, owned: list[str] | None = None) -> str | None:
    """The chosen skin; without a choice the newest bought skin, else the Phönix."""
    owned = owned_skins(db, username) if owned is None else owned
    ensure_skin_table(db)
    row = db.execute("SELECT skin FROM derby_skin_prefs WHERE username=?", (username,)).fetchone()
    if row and row[0] == "none":
        return None
    if row and row[0] in owned:
        return row[0]
    return owned[-1] if owned else None


def select_skin(db, username: str, skin: str) -> None:
    ensure_skin_table(db)
    db.execute("INSERT INTO derby_skin_prefs VALUES (?, ?, ?) ON CONFLICT(username) DO UPDATE SET skin=excluded.skin, updated=excluded.updated",
               (username, skin, time.time()))


def skin_state(db, username: str) -> dict[str, Any]:
    owned = owned_skins(db, username)
    return {"active": active_skin(db, username, owned), "owned": owned,
            "catalog": [{"id": key, "owned": key in owned, **skin} for key, skin in SKINS.items()]}


def derby_flair(db, username: str) -> dict[str, Any]:
    """Level rewards and the skin the bettor's horse shows on the stream overlay."""
    try:
        unlocks = xp_levels.summary(db, username)["unlocks"]
        skin = active_skin(db, username)
    except Exception:  # an overlay must never fail over the level system
        return {"crown": False, "champion": False, "phoenix": False, "skin": None}
    return {"crown": "derby-crown" in unlocks, "champion": "derby-champion" in unlocks, "phoenix": skin == "phoenix", "skin": skin}


def live_races(db, now: float) -> list[dict[str, Any]]:
    """Races of the last minutes for the stream overlay, oldest first."""
    rows = db.execute("SELECT rowid, username, created, result FROM horse_races WHERE created >= ? ORDER BY created DESC LIMIT 12", (now - LIVE_WINDOW,)).fetchall()
    races, flair = [], {}
    for row in reversed(rows):
        r = json.loads(row["result"])
        if row["username"] not in flair:
            flair[row["username"]] = derby_flair(db, row["username"])
        races.append({"id": int(row["rowid"]), "username": row["username"], "created": row["created"], "flair": flair[row["username"]],
                      **{k: r[k] for k in ("horse", "winner", "order", "finish", "shapes", "laps", "won", "stake", "payout", "place")}})
    return races


class Bet(BaseModel):
    horse: int = Field(ge=0, le=len(HORSES) - 1)
    request_id: str = Field(min_length=16, max_length=64, pattern=r"^[a-zA-Z0-9-]+$")


@router.get("")
def info(user: dict = Depends(current_user)) -> dict[str, Any]:
    store = economy()
    with store.connection(write=True) as db:
        ensure_table(db)
        return {"stake": STAKE, "payout": PAYOUT, "laps": LAPS, "horses": HORSES,
                "wallet": store.wallet(db, str(user["username"])), "recent": recent_winners(db), "stats": stats(db),
                "skins": skin_state(db, str(user["username"]))}


class SkinChoice(BaseModel):
    skin: str = Field(max_length=32)


@router.put("/skin")
def choose_skin(body: SkinChoice, user: dict = Depends(current_user)) -> dict[str, Any]:
    username = str(user["username"])
    with economy().connection(write=True) as db:
        if body.skin != "none" and body.skin not in owned_skins(db, username):
            raise HTTPException(403, "Diesen Skin besitzt du noch nicht. Es gibt ihn im Shop.")
        select_skin(db, username, body.skin)
        return {"skins": skin_state(db, username), "message": "Skin aktiviert." if body.skin != "none" else "Skin abgelegt."}


@router.get("/live")
def live(response: Response) -> dict[str, Any]:
    """Public, read-only feed for the OBS overlay: the latest races with their scripts."""
    response.headers["Cache-Control"] = "no-store"
    store = economy()
    with store.connection(write=True) as db:
        ensure_table(db)
        now = time.time()
        return {"server_time": now, "countdown": COUNTDOWN, "races": live_races(db, now)}


@router.post("/race")
def start_race(body: Bet, request: Request, user: dict = Depends(current_user)) -> dict[str, Any]:
    ratelimit.hit(request, "horse-race", 20, 60)
    username, now, store = str(user["username"]), time.time(), economy()
    with store.connection(write=True) as db:
        store.require_ready(db)
        ensure_table(db)
        previous = db.execute("SELECT username, result FROM horse_races WHERE request_id=?", (body.request_id,)).fetchone()
        if previous:
            if previous["username"] != username:
                raise HTTPException(409, "Diese Anfrage gehört zu einem anderen Spieler.")
            return {**json.loads(previous["result"]), "wallet": store.wallet(db, username), "duplicate": True}
        db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
        if store.wallet(db, username)["credits"] < STAKE:
            raise HTTPException(402, f"Ein Rennen kostet {STAKE} Credits. Credits gibt es im Shop (10 Chickens pro Credit).")
        result = race(body.horse)
        won = result["winner"] == body.horse
        payout = PAYOUT if won else 0
        result.update({"horse": body.horse, "won": won, "stake": STAKE, "payout": payout,
                       "place": result["order"].index(body.horse) + 1})
        db.execute("UPDATE wallets SET credits = credits - ? + ? WHERE username=?", (STAKE, payout, username))
        db.execute("INSERT INTO casino_ledger VALUES (?, ?, 'horse-race', 0, ?, 0, ?)", (f"horse:{body.request_id}", username, payout - STAKE, now))
        db.execute("INSERT INTO horse_races VALUES (?, ?, ?, ?, ?, ?, ?, ?)", (body.request_id, username, body.horse, result["winner"], STAKE, payout, now, json.dumps(result)))
        xp_levels.award(db, username, "casino", 20 + (20 if won else 0), ref=f"horse:{body.request_id}", now=now, queue_alert=store._queue_alert)
        return {**result, "wallet": store.wallet(db, username), "duplicate": False}
