"""Admin Stream Control: admins fire live effects (confetti cannon, noir rain, ads, ...) from the
admin area; a full-screen OBS browser source (/stream/control) polls the public feed and plays
each new event once. The feed only carries effect names and timings, nothing personal."""
from __future__ import annotations

import time
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, Field

from . import ratelimit
from .auth import require_admin
from .economy import economy

router = APIRouter()
FEED_WINDOW = 60          # seconds an event stays in the public feed
# Keep in sync with frontend/src/stream/effects.js (a frontend test compares both lists).
EFFECTS = frozenset("""
confetti-cannon confetti-rain fireworks balloons gold-rain money-rain stars hearts applause disco rainbow hype
noir-rain thunderstorm snow fog sandstorm autumn sakura underwater fire frost sunset night-vision
vhs glitch matrix old-film crt-off shockwave glass-crack spotlight dizzy hypno
chicken-run egg-rain feathers popcorn pizza laugh horror sunglasses
gg rip respect clutch fail wow countdown ad stop
""".split())
VIDEOS = {"marelle-trailer": "Marelle Trailer", "after-play": "After Play Trailer"}


class Fire(BaseModel):
    effect: str = Field(max_length=32)
    duration: int = Field(default=10, ge=3, le=60)
    video: str | None = Field(default=None, max_length=32)


def ensure_table(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS stream_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT, effect TEXT NOT NULL, duration INTEGER NOT NULL,
        video TEXT, created REAL NOT NULL)""")


def row(r) -> dict[str, Any]:
    return {"id": r["id"], "effect": r["effect"], "duration": r["duration"], "video": r["video"], "created": r["created"]}


@router.get("/api/stream-control")
def feed(response: Response) -> dict[str, Any]:
    response.headers["Cache-Control"] = "no-store"
    now = time.time()
    with economy().connection(write=True) as db:
        ensure_table(db)
        rows = db.execute("SELECT * FROM stream_events WHERE created >= ? ORDER BY id DESC LIMIT 40", (now - FEED_WINDOW,)).fetchall()
        last = db.execute("SELECT COALESCE(MAX(id), 0) FROM stream_events").fetchone()[0]
    return {"server_time": now, "last_id": last, "events": [row(r) for r in reversed(rows)]}


@router.post("/api/admin/stream-control", dependencies=[Depends(require_admin)])
def fire(body: Fire, request: Request) -> dict[str, Any]:
    ratelimit.hit(request, "stream-control", 90, 60)
    if body.effect not in EFFECTS:
        raise HTTPException(400, "Diesen Effekt gibt es nicht.")
    if body.effect == "ad" and body.video not in VIDEOS:
        raise HTTPException(400, "Bitte ein Werbevideo auswählen.")
    with economy().connection(write=True) as db:
        ensure_table(db)
        cur = db.execute("INSERT INTO stream_events(effect, duration, video, created) VALUES (?, ?, ?, ?)",
                         (body.effect, body.duration, body.video if body.effect == "ad" else None, time.time()))
        event = row(db.execute("SELECT * FROM stream_events WHERE id=?", (cur.lastrowid,)).fetchone())
    label = VIDEOS.get(body.video or "", "") if body.effect == "ad" else ""
    return {"event": event, "message": "Alle Effekte gestoppt." if body.effect == "stop" else f"Läuft im Stream{': ' + label if label else ''}."}
