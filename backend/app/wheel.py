"""Bestrafungsrad: every punishment bought in the shop lands on a wheel of fortune.

The same punishment bought twice is one segment with twice the weight, so it is simply more
likely. The server draws the winner (weighted, cryptographically random) and stores the spin with
a snapshot of the wheel and its final angle; the admin tab and the stream overlay
(/stream/wheel) both animate from that record, so they always land on the same segment.
"""
from __future__ import annotations

import json
import math
import secrets
import time
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, Field

from . import ratelimit
from .auth import require_admin
from .economy import PUNISHMENT_CATEGORIES, economy

router = APIRouter()
INTRO = 2.2          # seconds: the wheel flies in, drum roll
SPIN = 11.0          # seconds of spinning
REVEAL = 9.0         # seconds the result stays on the stream
TOTAL = INTRO + SPIN + REVEAL
TAU = math.tau


class Resolve(BaseModel):
    action: Literal["done", "keep"]


class RemoveEntries(BaseModel):
    purchase_ids: list[str] = Field(min_length=1, max_length=500)


def ensure_tables(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS wheel_spins (
        id INTEGER PRIMARY KEY AUTOINCREMENT, created REAL NOT NULL, entries TEXT NOT NULL,
        winner TEXT NOT NULL, start_angle REAL NOT NULL, final_angle REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'open')""")
    # Purchases taken off the wheel (done or removed by an admin). Purchases themselves stay untouched.
    db.execute("""CREATE TABLE IF NOT EXISTS wheel_removed (
        purchase_id TEXT PRIMARY KEY, reason TEXT NOT NULL, spin_id INTEGER, created REAL NOT NULL)""")


def key_of(name: str) -> str:
    return " ".join(str(name).split()).casefold()


def current_entries(db) -> list[dict[str, Any]]:
    """Segments in purchase order of their first buyer; weight = number of open purchases."""
    marks = ",".join("?" * len(PUNISHMENT_CATEGORIES))
    rows = db.execute(f"""SELECT p.id, p.username, p.item_name, p.price, p.created FROM purchases p
        WHERE p.category IN ({marks}) AND p.id NOT IN (SELECT purchase_id FROM wheel_removed)
        ORDER BY p.created, p.id""", tuple(sorted(PUNISHMENT_CATEGORIES))).fetchall()
    groups: dict[str, dict[str, Any]] = {}
    for row in rows:
        key = key_of(row["item_name"])
        if not key:
            continue
        group = groups.setdefault(key, {"key": key, "name": " ".join(row["item_name"].split()), "weight": 0, "buyers": []})
        group["weight"] += 1
        group["buyers"].append({"purchase_id": row["id"], "username": row["username"], "price": row["price"], "created": row["created"]})
    return list(groups.values())


def public_entries(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """What the stream may show: punishment, weight and buyer names (as on the purchase alert)."""
    out = []
    for entry in entries:
        counts: dict[str, int] = {}
        for buyer in entry["buyers"]:
            counts[buyer["username"]] = counts.get(buyer["username"], 0) + 1
        out.append({"key": entry["key"], "name": entry["name"], "weight": entry["weight"],
                    "buyers": [{"username": name, "count": count} for name, count in counts.items()]})
    return out


def segment_span(entries: list[dict[str, Any]], key: str) -> tuple[float, float]:
    total = sum(e["weight"] for e in entries)
    at = 0.0
    for entry in entries:
        size = entry["weight"] / total * TAU
        if entry["key"] == key:
            return at, at + size
        at += size
    raise ValueError(key)


def spin_row(row) -> dict[str, Any]:
    return {"id": row["id"], "created": row["created"], "entries": json.loads(row["entries"]), "winner": row["winner"],
            "start_angle": row["start_angle"], "final_angle": row["final_angle"], "status": row["status"],
            "intro": INTRO, "spin": SPIN, "reveal": REVEAL}


def latest(db):
    return db.execute("SELECT * FROM wheel_spins ORDER BY id DESC LIMIT 1").fetchone()


def draw(entries: list[dict[str, Any]], start_angle: float, rng=secrets.SystemRandom()) -> tuple[str, float]:
    """Weighted pick; the final angle puts the pointer (top) somewhere inside the winning segment.

    The wheel rotates by +angle (clockwise on screen); the pointer sits at the top, so the wheel
    position under the pointer is (-angle) mod tau.
    """
    total = sum(e["weight"] for e in entries)
    ticket = rng.randrange(total)
    for entry in entries:
        ticket -= entry["weight"]
        if ticket < 0:
            winner = entry["key"]
            break
    lo, hi = segment_span(entries, winner)
    margin = (hi - lo) * 0.12
    target = rng.uniform(lo + margin, hi - margin)        # point of the wheel that ends under the pointer
    rest = (-target - start_angle) % TAU
    turns = 6 + rng.randrange(3)
    return winner, start_angle + turns * TAU + rest


@router.get("/api/admin/wheel", dependencies=[Depends(require_admin)])
def admin_state(response: Response) -> dict[str, Any]:
    response.headers["Cache-Control"] = "no-store"
    with economy().connection(write=True) as db:
        ensure_tables(db)
        entries = current_entries(db)
        history = db.execute("SELECT * FROM wheel_spins ORDER BY id DESC LIMIT 12").fetchall()
    return {"server_time": time.time(), "entries": entries, "total": sum(e["weight"] for e in entries),
            "history": [spin_row(r) for r in history]}


@router.post("/api/admin/wheel/spin", dependencies=[Depends(require_admin)])
def spin(request: Request) -> dict[str, Any]:
    ratelimit.hit(request, "wheel-spin", 20, 60)
    now = time.time()
    with economy().connection(write=True) as db:
        ensure_tables(db)
        last = latest(db)
        if last and now < last["created"] + INTRO + SPIN + 1:
            raise HTTPException(409, "Das Rad dreht sich noch.")
        entries = current_entries(db)
        if not entries:
            raise HTTPException(400, "Auf dem Rad ist noch keine Bestrafung. Sie kommen über Käufe im Shop.")
        if last and last["status"] == "open":
            db.execute("UPDATE wheel_spins SET status='kept' WHERE id=?", (last["id"],))
        start = (last["final_angle"] % TAU) if last else 0.0
        shown = public_entries(entries)
        winner, final = draw(shown, start)
        cur = db.execute("INSERT INTO wheel_spins(created, entries, winner, start_angle, final_angle) VALUES (?, ?, ?, ?, ?)",
                         (now, json.dumps(shown), winner, start, final))
        row = db.execute("SELECT * FROM wheel_spins WHERE id=?", (cur.lastrowid,)).fetchone()
    return {"spin": spin_row(row), "server_time": now}


@router.post("/api/admin/wheel/spins/{spin_id}/resolve", dependencies=[Depends(require_admin)])
def resolve(spin_id: int, body: Resolve) -> dict[str, Any]:
    now = time.time()
    with economy().connection(write=True) as db:
        ensure_tables(db)
        row = db.execute("SELECT * FROM wheel_spins WHERE id=?", (spin_id,)).fetchone()
        if not row:
            raise HTTPException(404, "Diese Drehung gibt es nicht.")
        if row["status"] == "done":
            return {"message": "Schon erledigt."}
        removed = 0
        if body.action == "done":
            # Every open purchase of that punishment comes off the wheel: done once is done.
            for entry in current_entries(db):
                if entry["key"] == row["winner"]:
                    for buyer in entry["buyers"]:
                        db.execute("INSERT OR IGNORE INTO wheel_removed VALUES (?, 'done', ?, ?)", (buyer["purchase_id"], spin_id, now))
                        removed += 1
        db.execute("UPDATE wheel_spins SET status=? WHERE id=?", ("done" if body.action == "done" else "kept", spin_id))
    return {"message": f"Erledigt und vom Rad genommen ({removed}×)." if body.action == "done" else "Bleibt auf dem Rad."}


@router.post("/api/admin/wheel/remove", dependencies=[Depends(require_admin)])
def remove(body: RemoveEntries) -> dict[str, Any]:
    now = time.time()
    with economy().connection(write=True) as db:
        ensure_tables(db)
        open_ids = {b["purchase_id"] for e in current_entries(db) for b in e["buyers"]}
        ids = [pid for pid in dict.fromkeys(body.purchase_ids) if pid in open_ids]
        db.executemany("INSERT OR IGNORE INTO wheel_removed VALUES (?, 'removed', NULL, ?)", [(pid, now) for pid in ids])
    return {"message": f"{len(ids)}× vom Rad genommen." if ids else "Nichts zu entfernen."}


@router.get("/api/stream/wheel")
def stream_state(response: Response) -> dict[str, Any]:
    """Public feed for the OBS source: the current wheel and the latest spin."""
    response.headers["Cache-Control"] = "no-store"
    with economy().connection(write=True) as db:
        ensure_tables(db)
        entries = public_entries(current_entries(db))
        last = latest(db)
    return {"server_time": time.time(), "entries": entries, "spin": spin_row(last) if last else None}
