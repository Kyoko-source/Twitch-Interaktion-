"""Chicken Jackpot: a 5x3 video slot played with the site's virtual Chickens.

All randomness and money handling happens here, inside one SQLite transaction on the
economy ledger: the bet is debited, the reels are drawn with a CSPRNG, the win is credited
and the spin is stored (idempotent by request id). Return to player is ~93% (verified by
simulation), so the slot is a soft Chicken sink. A daily net-win cap keeps lucky streaks from
draining the stream shop.
"""
from __future__ import annotations

import json
import secrets
import time
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from . import ratelimit
from .auth import current_user
from .economy import economy

router = APIRouter(prefix="/api/slots", tags=["slots"])
CET = timezone(timedelta(hours=1))
BETS = [2, 5, 10, 20, 50]
DAILY_NET_WIN_CAP = 300
REELS, ROWS = 5, 3
WEIGHTS = {"cherry": 20, "lemon": 18, "grape": 15, "bell": 10, "bar": 7, "seven": 4, "wild": 3, "egg": 3}
# Multiplier of the TOTAL bet for 3 / 4 / 5 matching from the leftmost reel.
PAY = {
    "cherry": (0.5, 1.5, 4), "lemon": (0.75, 2, 5), "grape": (1, 2.5, 7.5), "bell": (2, 5, 15),
    "bar": (2.5, 7.5, 25), "seven": (5, 20, 75), "wild": (6, 30, 300),
}
SCATTER = {3: 2, 4: 10, 5: 50}  # golden eggs anywhere
LINES = [
    [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
    [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0],
]
POOL = [s for s, w in WEIGHTS.items() for _ in range(w)]
_rng = secrets.SystemRandom()


def draw(rng=_rng) -> list[list[str]]:
    """grid[reel][row]"""
    return [[rng.choice(POOL) for _ in range(ROWS)] for _ in range(REELS)]


def evaluate(grid: list[list[str]], bet: int) -> dict[str, Any]:
    wins = []
    total = 0.0
    for index, line in enumerate(LINES):
        syms = [grid[r][line[r]] for r in range(REELS)]
        best = None
        first = next((s for s in syms if s != "wild"), "wild")
        if first != "egg":
            n = 0
            for s in syms:
                if s == first or s == "wild":
                    n += 1
                else:
                    break
            if n >= 3:
                best = (first, n, PAY[first][n - 3])
        wn = 0
        for s in syms:
            if s != "wild":
                break
            wn += 1
        if wn >= 3 and (best is None or PAY["wild"][wn - 3] > best[2]):
            best = ("wild", wn, PAY["wild"][wn - 3])
        if best:
            symbol, count, mult = best
            total += mult
            wins.append({"line": index, "symbol": symbol, "count": count, "mult": mult, "cells": [[r, line[r]] for r in range(count)]})
    eggs = [[r, row] for r in range(REELS) for row in range(ROWS) if grid[r][row] == "egg"]
    scatter = None
    if len(eggs) >= 3:
        mult = SCATTER[min(len(eggs), 5)]
        total += mult
        scatter = {"count": len(eggs), "mult": mult, "cells": eggs}
    win = int(bet * total)  # whole Chickens only
    return {"wins": wins, "scatter": scatter, "multiplier": total, "win": win}


def day_start(now: float) -> float:
    local = datetime.fromtimestamp(now, CET)
    return local.replace(hour=0, minute=0, second=0, microsecond=0).timestamp()


def ensure_table(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS slot_spins (
        request_id TEXT PRIMARY KEY, username TEXT NOT NULL, bet INTEGER NOT NULL CHECK(bet > 0),
        win INTEGER NOT NULL CHECK(win >= 0), created REAL NOT NULL, result TEXT NOT NULL)""")
    db.execute("CREATE INDEX IF NOT EXISTS slot_spins_user ON slot_spins(username, created)")


def net_today(db, username: str, now: float) -> int:
    return int(db.execute("SELECT COALESCE(SUM(win - bet), 0) FROM slot_spins WHERE username=? AND created>=?", (username, day_start(now))).fetchone()[0])


class Spin(BaseModel):
    bet: int
    request_id: str = Field(min_length=16, max_length=64, pattern=r"^[a-zA-Z0-9-]+$")


@router.get("")
def info(user: dict = Depends(current_user)) -> dict[str, Any]:
    username = str(user["username"])
    now = time.time()
    store = economy()
    with store.connection(write=True) as db:
        ensure_table(db)
        wallet = store.wallet(db, username)
        net = net_today(db, username, now)
    return {"bets": BETS, "pay": PAY, "scatter": SCATTER, "lines": LINES, "weights": WEIGHTS, "rtp": 0.93,
            "wallet": wallet, "today": {"net": net, "cap": DAILY_NET_WIN_CAP}}


@router.post("/spin")
def spin(body: Spin, request: Request, user: dict = Depends(current_user)) -> dict[str, Any]:
    ratelimit.hit(request, "slots-spin", 90, 60)
    if body.bet not in BETS:
        raise HTTPException(400, "Ungültiger Einsatz.")
    username = str(user["username"])
    now = time.time()
    store = economy()
    with store.connection(write=True) as db:
        store.require_ready(db)
        ensure_table(db)
        previous = db.execute("SELECT username, result FROM slot_spins WHERE request_id=?", (body.request_id,)).fetchone()
        if previous:
            if previous["username"] != username:
                raise HTTPException(409, "Diese Anfrage gehört zu einem anderen Spieler.")
            result = json.loads(previous["result"])
            return {**result, "wallet": store.wallet(db, username), "today": {"net": net_today(db, username, now), "cap": DAILY_NET_WIN_CAP}, "duplicate": True}
        if net_today(db, username, now) >= DAILY_NET_WIN_CAP:
            raise HTTPException(429, f"Glückssträhne! Du hast heute schon {DAILY_NET_WIN_CAP} Chickens am Automaten gewonnen. Morgen geht's weiter.")
        if store.wallet(db, username)["chickens"] < body.bet:
            raise HTTPException(400, "Nicht genug Chickens für diesen Einsatz.")
        grid = draw()
        result = {"grid": grid, "bet": body.bet, **evaluate(grid, body.bet)}
        db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
        db.execute("UPDATE wallets SET chickens = chickens - ? + ? WHERE username=?", (body.bet, result["win"], username))
        db.execute("INSERT INTO slot_spins VALUES (?, ?, ?, ?, ?, ?)", (body.request_id, username, body.bet, result["win"], now, json.dumps(result)))
        return {**result, "wallet": store.wallet(db, username), "today": {"net": net_today(db, username, now), "cap": DAILY_NET_WIN_CAP}, "duplicate": False}
