"""Chicken Jackpot: a 5x3 video slot. A spin costs Credits (bought with Chickens in the shop)
and pays Glücksspiel-Coins (GSC) - big numbers that only turn back into Chickens at the
casino cashier's steep rate.

All randomness and accounting happens here, inside one SQLite transaction on the economy
ledger: credits are debited, the reels are drawn with a CSPRNG, GSC are credited and the spin
is stored (idempotent by request id). Return to player is ~93% of the GSC stake value.

Three or more Golden Eggs anywhere start the Egg Bonus: 8/12/20 free spins that are drawn
right away in the same request, with every win tripled. Eggs during the bonus add more free
spins (capped). Roughly a third of the return comes from the bonus, so the base game is
leaner and the bonus is where the big numbers happen.
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
BETS = [1, 2, 5, 10]          # credits per spin
GSC_PER_CREDIT = 10_000       # stake value of one credit in Glücksspiel-Coins
REELS, ROWS = 5, 3
WEIGHTS = {"cherry": 20, "lemon": 18, "grape": 15, "bell": 10, "bar": 7, "seven": 4, "wild": 3, "egg": 3}
# Multiplier of the TOTAL bet for 3 / 4 / 5 matching from the leftmost reel.
PAY = {
    "cherry": (0.3, 1, 2.5), "lemon": (0.5, 1.3, 3.5), "grape": (0.7, 1.7, 5), "bell": (1.3, 3.5, 10),
    "bar": (1.7, 5, 17), "seven": (3.5, 13, 50), "wild": (4, 20, 200),
}
SCATTER = {3: 1, 4: 5, 5: 25}  # golden eggs anywhere, instant pay
FREE_SPINS = {3: 8, 4: 12, 5: 20}  # golden eggs start / extend the Egg Bonus
FREE_MULT = 3
FREE_CAP = 50
LINES = [
    [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
    [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0],
]
POOL = [s for s, w in WEIGHTS.items() for _ in range(w)]
_rng = secrets.SystemRandom()


def draw(rng=_rng) -> list[list[str]]:
    """grid[reel][row]"""
    return [[rng.choice(POOL) for _ in range(ROWS)] for _ in range(REELS)]


def evaluate(grid: list[list[str]], bet: int, mult: float = 1) -> dict[str, Any]:
    line_mult = mult
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
            wins.append({"line": index, "symbol": symbol, "count": count, "mult": mult, "win": int(bet * GSC_PER_CREDIT * mult * line_mult), "cells": [[r, line[r]] for r in range(count)]})
    eggs = [[r, row] for r in range(REELS) for row in range(ROWS) if grid[r][row] == "egg"]
    scatter = None
    if len(eggs) >= 3:
        pays = SCATTER[min(len(eggs), 5)]
        total += pays
        scatter = {"count": len(eggs), "mult": pays, "free_spins": FREE_SPINS[min(len(eggs), 5)], "cells": eggs}
    total *= line_mult
    win = int(bet * GSC_PER_CREDIT * total)  # paid in GSC
    return {"wins": wins, "scatter": scatter, "multiplier": total, "win": win}


def play_bonus(start: int, bet: int, rng=None) -> dict[str, Any]:
    """Draw the whole Egg Bonus. Retriggers add spins up to FREE_CAP in total."""
    spins = []
    awarded = left = min(start, FREE_CAP)
    while left > 0:
        left -= 1
        grid = draw(rng) if rng else draw()
        result = {"grid": grid, **evaluate(grid, bet, FREE_MULT)}
        extra = 0
        if result["scatter"]:
            extra = min(result["scatter"]["free_spins"], FREE_CAP - awarded)
            awarded += extra
            left += extra
        result["extra_spins"] = extra
        spins.append(result)
    return {"awarded": awarded, "mult": FREE_MULT, "spins": spins, "win": sum(spin["win"] for spin in spins)}


def play(bet: int, rng=None) -> dict[str, Any]:
    grid = draw(rng) if rng else draw()
    base = evaluate(grid, bet)
    bonus = play_bonus(base["scatter"]["free_spins"], bet, rng) if base["scatter"] else None
    total = base["win"] + (bonus["win"] if bonus else 0)
    return {"grid": grid, "bet": bet, **base, "base_win": base["win"], "bonus": bonus, "win": total}


def day_start(now: float) -> float:
    local = datetime.fromtimestamp(now, CET)
    return local.replace(hour=0, minute=0, second=0, microsecond=0).timestamp()


def ensure_table(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS slot_spins (
        request_id TEXT PRIMARY KEY, username TEXT NOT NULL, bet INTEGER NOT NULL CHECK(bet > 0),
        win INTEGER NOT NULL CHECK(win >= 0), created REAL NOT NULL, result TEXT NOT NULL)""")
    db.execute("CREATE INDEX IF NOT EXISTS slot_spins_user ON slot_spins(username, created)")


def won_today(db, username: str, now: float) -> int:
    return int(db.execute("SELECT COALESCE(SUM(win), 0) FROM slot_spins WHERE username=? AND created>=?", (username, day_start(now))).fetchone()[0])


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
        won = won_today(db, username, now)
    return {"bets": BETS, "gsc_per_credit": GSC_PER_CREDIT, "pay": PAY, "scatter": SCATTER, "free_spins": FREE_SPINS, "free_mult": FREE_MULT, "lines": LINES, "weights": WEIGHTS, "rtp": 0.93,
            "wallet": wallet, "today": {"won": won}}


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
            return {**result, "wallet": store.wallet(db, username), "today": {"won": won_today(db, username, now)}, "duplicate": True}
        if store.wallet(db, username)["credits"] < body.bet:
            raise HTTPException(402, "Nicht genug Credits. Credits gibt es im Shop (10 Chickens pro Credit).")
        result = play(body.bet)
        db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
        db.execute("UPDATE wallets SET credits = credits - ?, gsc = gsc + ? WHERE username=?", (body.bet, result["win"], username))
        db.execute("INSERT INTO slot_spins VALUES (?, ?, ?, ?, ?, ?)", (body.request_id, username, body.bet, result["win"], now, json.dumps(result)))
        return {**result, "wallet": store.wallet(db, username), "today": {"won": won_today(db, username, now)}, "duplicate": False}
