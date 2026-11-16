"""Santa's Cookie Crisis: the save game per member and the finale award.

The game runs in the browser; the server keeps the newest save so it follows the member to
other devices. A save is only accepted when its dough adds up to exactly 1,000,000 cookies
(25 g each) and it does not fall behind the stored one (an old tab cannot overwrite progress).
The title "Oberster Keksmeister des Nordpols" is granted once a stored save has baked all
1,000,000 cookies.
"""
from __future__ import annotations

import json
import time
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from .auth import current_user
from .economy import economy

router = APIRouter(prefix="/api/cookie", tags=["cookie"])

GOAL = 1_000_000
MAX_SAVE = 400_000
MIN_FINALE_SECONDS = 45 * 60  # a real run takes hours; this only stops obviously forged saves
TITLE = "Oberster Keksmeister des Nordpols"


def ensure(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS cookie_saves (
        username TEXT PRIMARY KEY, data TEXT NOT NULL, baked INTEGER NOT NULL, play REAL NOT NULL,
        saved REAL NOT NULL, finished REAL)""")


def _exists(db) -> bool:
    return bool(db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='cookie_saves'").fetchone())


def check(data: dict[str, Any]) -> tuple[int, float]:
    """Validate a save. Returns (baked, play seconds)."""
    if not isinstance(data, dict) or data.get("v") != 1:
        raise ValueError("Unbekannter Spielstand.")
    try:
        counts = {k: int(data.get(k) or 0) for k in ("dough", "carry", "ball", "sheet", "tray", "queue", "exit", "baked", "talers", "earned", "spent")}
        belt = sum(int(b[1]) for b in data.get("belt") or [])
        falling = sum(int(b[1]) for b in data.get("falling") or [])
        play = float(data.get("t") or 0)
    except (TypeError, ValueError, IndexError) as error:
        raise ValueError("Spielstand ist beschädigt.") from error
    if any(v < 0 for v in counts.values()) or belt < 0 or falling < 0:
        raise ValueError("Spielstand ist beschädigt.")
    total = counts["dough"] + counts["carry"] + counts["ball"] + counts["sheet"] + counts["tray"] + counts["queue"] + belt + counts["exit"] + falling + counts["baked"]
    if total != GOAL:
        raise ValueError("Die Teigbilanz stimmt nicht.")
    if counts["earned"] != counts["baked"] or counts["talers"] + counts["spent"] != counts["earned"]:
        raise ValueError("Die Schokotaler passen nicht zu den gebackenen Keksen.")
    return counts["baked"], play


def summary(db, username: str) -> dict[str, Any] | None:
    """Progress for the profile page."""
    if not _exists(db):
        return None
    row = db.execute("SELECT baked, play, finished FROM cookie_saves WHERE username=?", (username,)).fetchone()
    if not row:
        return None
    return {"baked": int(row[0]), "play": float(row[1]), "finished": row[2], "title": TITLE if row[2] else None}


class SaveBody(BaseModel):
    data: str = Field(min_length=2, max_length=MAX_SAVE)
    reset: bool = False


@router.get("/save")
def load(user: dict = Depends(current_user)) -> dict[str, Any]:
    with economy().connection() as db:
        if not _exists(db):
            return {"save": None}
        row = db.execute("SELECT data, saved, finished FROM cookie_saves WHERE username=?", (str(user["username"]),)).fetchone()
    return {"save": row[0] if row else None, "saved": row[1] if row else None, "finished": row[2] if row else None}


@router.put("/save")
def store(body: SaveBody, user: dict = Depends(current_user)) -> dict[str, Any]:
    username = str(user["username"])
    try:
        data = json.loads(body.data)
        baked, play = check(data)
    except ValueError as error:
        raise HTTPException(400, str(error)) from error
    now = time.time()
    with economy().connection(write=True) as db:
        ensure(db)
        row = db.execute("SELECT baked, finished FROM cookie_saves WHERE username=?", (username,)).fetchone()
        if row and not body.reset and baked < int(row[0]):
            raise HTTPException(409, "Auf dem Server liegt ein neuerer Spielstand.")
        finished = None if body.reset else (row[1] if row else None)
        db.execute("INSERT INTO cookie_saves(username, data, baked, play, saved, finished) VALUES (?, ?, ?, ?, ?, ?) "
                   "ON CONFLICT(username) DO UPDATE SET data=excluded.data, baked=excluded.baked, play=excluded.play, saved=excluded.saved, finished=excluded.finished",
                   (username, body.data, baked, play, now, finished))
    return {"saved": now, "baked": baked}


@router.post("/finale")
def finale(user: dict = Depends(current_user)) -> dict[str, Any]:
    username = str(user["username"])
    with economy().connection(write=True) as db:
        ensure(db)
        row = db.execute("SELECT baked, play, finished FROM cookie_saves WHERE username=?", (username,)).fetchone()
        if not row or int(row[0]) < GOAL:
            raise HTTPException(400, "Erst alle 1.000.000 Kekse backen und speichern.")
        if float(row[1]) < MIN_FINALE_SECONDS:
            raise HTTPException(400, "Dieser Spielstand ist zu schnell für eine Million Kekse.")
        finished = row[2] or time.time()
        db.execute("UPDATE cookie_saves SET finished=? WHERE username=?", (finished, username))
    return {"title": TITLE, "finished": finished}
