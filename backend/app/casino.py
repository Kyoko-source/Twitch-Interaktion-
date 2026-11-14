"""Casino cashier: Chickens -> Credits (one credit = one Pinball round or one slot spin) and
Glücksspiel-Coins (GSC) -> Chickens at a deliberately steep rate with a daily cap."""
from __future__ import annotations

import time
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from . import ratelimit
from .auth import current_user
from .economy import economy
from .slots import day_start

router = APIRouter(prefix="/api/casino", tags=["casino"])
CREDIT_PRICE = 10                    # Chickens per credit
CREDIT_PACKS = [1, 5, 10, 25]
GSC_PER_CHICKEN = 25_000             # 100 Chickens = 2.500.000 GSC
EXCHANGE_PACKS = [10, 50, 100]       # Chickens you can buy with GSC
DAILY_EXCHANGE_CAP = 100             # Chickens per day from GSC


class BuyCredits(BaseModel):
    count: int
    request_id: str = Field(min_length=16, max_length=64, pattern=r"^[a-zA-Z0-9-]+$")


class Exchange(BaseModel):
    chickens: int
    request_id: str = Field(min_length=16, max_length=64, pattern=r"^[a-zA-Z0-9-]+$")


def exchanged_today(db, username: str, now: float) -> int:
    return int(db.execute("SELECT COALESCE(SUM(chickens),0) FROM casino_ledger WHERE username=? AND kind='exchange' AND created>=?", (username, day_start(now))).fetchone()[0])


def state(db, username: str, now: float) -> dict[str, Any]:
    store = economy()
    return {
        "wallet": store.wallet(db, username),
        "credit_price": CREDIT_PRICE, "credit_packs": CREDIT_PACKS,
        "gsc_per_chicken": GSC_PER_CHICKEN, "exchange_packs": [{"chickens": c, "gsc": c * GSC_PER_CHICKEN} for c in EXCHANGE_PACKS],
        "exchange_today": exchanged_today(db, username, now), "exchange_cap": DAILY_EXCHANGE_CAP,
    }


def replay(db, username: str, request_id: str, kind: str):
    row = db.execute("SELECT username, kind FROM casino_ledger WHERE request_id=?", (request_id,)).fetchone()
    if row and (row["username"] != username or row["kind"] != kind):
        raise HTTPException(409, "Diese Anfrage gehört zu einer anderen Buchung.")
    return bool(row)


@router.get("")
def cashier(user: dict = Depends(current_user)) -> dict[str, Any]:
    with economy().connection() as db:
        return state(db, str(user["username"]), time.time())


@router.post("/credits")
def buy_credits(body: BuyCredits, request: Request, user: dict = Depends(current_user)) -> dict[str, Any]:
    ratelimit.hit(request, "casino", 60, 60)
    if body.count not in CREDIT_PACKS:
        raise HTTPException(400, "Dieses Credit-Paket gibt es nicht.")
    username, now, store = str(user["username"]), time.time(), economy()
    cost = body.count * CREDIT_PRICE
    with store.connection(write=True) as db:
        store.require_ready(db)
        if not replay(db, username, body.request_id, "credits"):
            db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
            if store.wallet(db, username)["chickens"] < cost:
                raise HTTPException(400, f"Nicht genug Chickens: {body.count} Credits kosten {cost} Chickens.")
            db.execute("UPDATE wallets SET chickens=chickens-?, credits=credits+? WHERE username=?", (cost, body.count, username))
            db.execute("INSERT INTO casino_ledger VALUES (?, ?, 'credits', ?, ?, 0, ?)", (body.request_id, username, -cost, body.count, now))
        return {**state(db, username, now), "message": f"{body.count} Credit{'s' if body.count != 1 else ''} gekauft – viel Glück!"}


@router.post("/exchange")
def exchange(body: Exchange, request: Request, user: dict = Depends(current_user)) -> dict[str, Any]:
    ratelimit.hit(request, "casino", 60, 60)
    if body.chickens not in EXCHANGE_PACKS:
        raise HTTPException(400, "Dieses Tausch-Paket gibt es nicht.")
    username, now, store = str(user["username"]), time.time(), economy()
    price = body.chickens * GSC_PER_CHICKEN
    with store.connection(write=True) as db:
        store.require_ready(db)
        if not replay(db, username, body.request_id, "exchange"):
            if exchanged_today(db, username, now) + body.chickens > DAILY_EXCHANGE_CAP:
                raise HTTPException(429, f"Tageslimit: Pro Tag kannst du höchstens {DAILY_EXCHANGE_CAP} Chickens mit GSC kaufen.")
            db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (username,))
            if store.wallet(db, username)["gsc"] < price:
                raise HTTPException(400, f"Nicht genug GSC: {body.chickens} Chickens kosten {price:,} GSC.".replace(",", "."))
            db.execute("UPDATE wallets SET gsc=gsc-?, chickens=chickens+? WHERE username=?", (price, body.chickens, username))
            db.execute("INSERT INTO casino_ledger VALUES (?, ?, 'exchange', ?, 0, ?, ?)", (body.request_id, username, body.chickens, -price, now))
        return {**state(db, username, now), "message": f"{body.chickens} Chickens gekauft!"}
