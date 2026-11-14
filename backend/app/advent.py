"""Marelles Adventskalender.

24 doors, one unlocks per day from 1 December 00:00 (German time, always CET in December).
Only site admins can open a door. Contents stay on the server until their door is opened,
so nobody can read ahead in the page source. Door 1 is always the VIRUS punishment (a six-month
countdown to a 24-hour stream); the other 23 are shuffled once per year and persisted. The
countdown can only be switched off with a password kept in the server environment.
"""
from __future__ import annotations

import json
import hmac
import os
import random
import secrets
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from . import auth, ratelimit

router = APIRouter(prefix="/api/advent", tags=["advent"])
CET = timezone(timedelta(hours=1))
DAYS = 24
VIRUS_MONTHS = 6
LOCK = threading.Lock()

STEAM = "https://store.steampowered.com/app/"
ITEMS: list[dict[str, str]] = [
    {"id": "gift-1plus1", "kind": "gift", "title": "1+1=?", "text": "Du bekommst das Spiel „1+1=?“. Es muss 20 Minuten gespielt werden – JETZT!", "link": STEAM + "3376520/11/"},
    {"id": "gift-hidden-pets", "kind": "gift", "title": "Hidden Pets: 101 Cats in Vietnam", "text": "Du bekommst das Spiel „Hidden Pets: 101 Cats in Vietnam“. Schaffe eine Runde – JETZT!", "link": STEAM + "4017210/Hidden_Pets_101_Cats_in_Vietnam/"},
    {"id": "gift-garbage-truck", "kind": "gift", "title": "Garbage Truck Driving Simulator", "text": "Du bekommst das Spiel „Garbage Truck Driving Simulator“. 20 Minuten – JETZT!", "link": STEAM + "2477070/Garbage_Truck_Driving_Simulator/"},
    {"id": "gift-sakura-mirror", "kind": "gift", "title": "Sakura Mirror", "text": "Du bekommst das Spiel „Sakura Mirror“. 20 Minuten – JETZT!", "link": STEAM + "2235610/Sakura_Mirror/"},
    {"id": "gift-queen-td", "kind": "gift", "title": "Queen of Tower Defense", "text": "Du bekommst das Spiel „Queen of Tower Defense“. 20 Minuten – JETZT!", "link": STEAM + "1692900/Queen_of_Tower_Defense"},
    {"id": "gift-the-hotel", "kind": "gift", "title": "The Hotel", "text": "Du bekommst das Spiel „The Hotel“. 20 Minuten – JETZT!", "link": STEAM + "1831870/The_Hotel/"},
    {"id": "punish-after-play", "kind": "punishment", "title": "OH NEIN", "text": "Schaffe im Spiel „After Play“ 13 Runden und schließe Ende 1 ab."},
    {"id": "punish-virus", "kind": "punishment", "title": "VIRUS", "text": "Auf deiner Webseite läuft nun ein Countdown von genau 6 Monaten! Innerhalb dieser Zeit MUSS ein 24-Stunden-Stream geschehen sein. (Kein Schummeln – deine Webseite trackt die Zeit in Echtzeit.)"},
    {"id": "punish-fanservice", "kind": "punishment", "title": "FANSERVICE", "text": "Ein Stream im Maid-Outfit. (Falls du keins hast: Ich kenne da jemanden, der welche hat.)"},
    {"id": "punish-fame", "kind": "punishment", "title": "FAME FAME FAME", "text": "Erstelle ein TikTok-Tanzvideo zu dem Song „Tokyo“ von Leat'eq."},
    {"id": "punish-time", "kind": "punishment", "title": "ZEITMANAGEMENT", "text": "Von deinem 6-Monats-Countdown wird 1 Monat abgezogen."},
    {"id": "punish-irl", "kind": "punishment", "title": "VERÄNDERUNGEN", "text": "Ich mache meinen ersten IRL-Stream."},
    {"id": "task-minecraft", "kind": "task", "title": "Minecraft Hardcore", "text": "Spiele Minecraft Hardcore und besiege den Enderdrachen. (Du darfst eine Person dazuholen.)"},
    {"id": "task-pinball", "kind": "task", "title": "PEPPLE Pinball", "text": "Brich auf deiner eigenen Webseite den PEPPLE-Pinball-Highscore oder ziehe 60 Minuten durch."},
    {"id": "task-poppy", "kind": "task", "title": "Poppy Playtime", "text": "Spiele Poppy Playtime 1 durch. 1× erschrecken = gleich Reset!"},
    {"id": "task-draw-my-life", "kind": "task", "title": "DRAW MY LIFE", "text": "Male „Life“ on Stream: Alle deine Mods wohnen für eine Woche bei dir. Male sie alle mit ihrer eigenen Aufgabe im Haus."},
    {"id": "task-rotkohl", "kind": "task", "title": "Rotkohl", "text": "Iss ein Glas Rotkohl. Guten Appetit!"},
    {"id": "task-noble", "kind": "task", "title": "Vornehm", "text": "Rede 15 Minuten vornehm und zuvorkommend mit deinen Chattern."},
    {"id": "task-no-english", "kind": "task", "title": "Kein Englisch", "text": "Kein Englisch für 20 Minuten."},
    {"id": "task-gloves", "kind": "task", "title": "Fäustlinge", "text": "Spiele ein Spiel deiner Wahl, aber mit richtigen Winterhandschuhen („Fäustlinge“)."},
    {"id": "task-free-choice", "kind": "task", "title": "Freie Wahl", "text": "Spiele ein Spiel deiner Wahl, aber …"},
    {"id": "task-irl-activity", "kind": "task", "title": "IRL-Aktivität", "text": "Plane eine IRL-Aktivität für deinen Stream: Kochstream, Puzzeln, Weihnachtsgeschenke einpacken usw."},
    {"id": "task-only-up", "kind": "task", "title": "Only Up", "text": "Spiele 60 Minuten Only Up."},
    {"id": "task-poem", "kind": "task", "title": "Weihnachtsgedicht", "text": "Schreibe ein Gedicht über deine Viewer und trag es live vor."},
]
assert len(ITEMS) == DAYS


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def season_year(now: datetime | None = None) -> int:
    local = (now or utcnow()).astimezone(CET)
    # January still shows last December's calendar.
    return local.year - 1 if local.month == 1 else local.year


def unlock_at(year: int, day: int) -> datetime:
    return datetime(year, 12, day, 0, 0, tzinfo=CET)


def data_file() -> Path:
    return Path(os.getenv("AVIARY_ADVENT_FILE", "/data/advent.json"))


def shuffled_order(seed: str) -> list[str]:
    rng = random.Random(seed)
    rest = [item["id"] for item in ITEMS if item["id"] != "punish-virus"]
    rng.shuffle(rest)
    return ["punish-virus", *rest]


def load_state(year: int) -> dict[str, Any]:
    path = data_file()
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        state = {}
    if state.get("year") != year or len(state.get("order", [])) != DAYS:
        state = {"year": year, "order": shuffled_order(secrets.token_hex(16)), "opened": {}, "virus_off": None}
        save_state(state)
    return state


def save_state(state: dict[str, Any]) -> None:
    path = data_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def add_months(moment: datetime, months: int) -> datetime:
    month = moment.month - 1 + months
    year, month = moment.year + month // 12, month % 12 + 1
    days = [31, 29 if year % 4 == 0 and (year % 100 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
    return moment.replace(year=year, month=month, day=min(moment.day, days))


def is_site_admin(user: dict | None) -> bool:
    if not user:
        return False
    return site_role(user) in ("admin", "publisher")


def site_role(user: dict | None) -> str:
    if not user:
        return "member"
    from .main import user_role  # late import: main imports this module
    return user_role(str(user.get("username") or ""), user.get("role"))


def is_publisher(user: dict | None) -> bool:
    return site_role(user) == "publisher"


def optional_user(authorization: str | None = Header(default=None)) -> dict | None:
    if not authorization:
        return None
    try:
        return auth.current_user(authorization)
    except HTTPException:
        return None


def test_box(state: dict[str, Any]) -> dict[str, Any]:
    """Admin-only sandbox: same contents and order, separate opened/virus state."""
    box = state.setdefault("test", {})
    box.setdefault("opened", {})
    box.setdefault("virus_off", None)
    return box


def view(state: dict[str, Any], user: dict | None, now: datetime, test: bool = False) -> dict[str, Any]:
    year = state["year"]
    by_id = {item["id"]: item for item in ITEMS}
    admin = is_site_admin(user)
    src = test_box(state) if test else state
    doors = []
    for day in range(1, DAYS + 1):
        opened = src["opened"].get(str(day))
        door = {"day": day, "unlocks_at": unlock_at(year, day).isoformat(), "unlocked": test or now >= unlock_at(year, day), "opened": bool(opened)}
        if opened:
            door.update(opened_at=opened["at"], opened_by=opened["by"], item=by_id[state["order"][day - 1]])
        doors.append(door)
    virus = None
    opened_ids = {state["order"][int(day) - 1]: info for day, info in src["opened"].items()}
    if "punish-virus" in opened_ids:
        start = datetime.fromisoformat(opened_ids["punish-virus"]["at"]).astimezone(CET)
        months = VIRUS_MONTHS - (1 if "punish-time" in opened_ids else 0)
        virus = {"started_at": start.isoformat(), "deadline": add_months(start, months).isoformat(), "months": months, "off": src.get("virus_off")}
    return {"year": year, "now": now.isoformat(), "starts_at": unlock_at(year, 1).isoformat(), "doors": doors, "can_open": admin, "can_test": is_publisher(user), "virus": virus, "test": test}


def require_admin_user(user: dict | None) -> dict:
    if not user:
        raise HTTPException(401, "Nicht angemeldet")
    if not is_site_admin(user):
        raise HTTPException(403, "Nur Admins dürfen Türchen öffnen.")
    return user


def require_publisher(user: dict | None) -> dict:
    require_admin_user(user)
    if not is_publisher(user):
        raise HTTPException(403, "Den Testmodus darf nur die Rolle Publisher benutzen.")
    return user


def do_open(day: int, user: dict | None, test: bool) -> dict[str, Any]:
    if test:
        require_publisher(user)
    require_admin_user(user)
    if not 1 <= day <= DAYS:
        raise HTTPException(404, "Dieses Türchen gibt es nicht.")
    now = utcnow()
    with LOCK:
        state = load_state(season_year(now))
        src = test_box(state) if test else state
        if not test and now < unlock_at(state["year"], day):
            raise HTTPException(409, f"Türchen {day} darf erst am {day}.12. geöffnet werden.")
        if str(day) in src["opened"]:
            raise HTTPException(409, "Dieses Türchen ist schon offen.")
        src["opened"][str(day)] = {"at": now.isoformat(), "by": str(user["username"])}
        save_state(state)
    return view(state, user, now, test)


class VirusOff(BaseModel):
    password: str = Field(min_length=1, max_length=200)


def do_virus_off(body: VirusOff, request: Request, user: dict | None, test: bool) -> dict[str, Any]:
    ratelimit.hit(request, "advent-virus", 8, 15 * 60)
    secret = os.getenv("AVIARY_ADVENT_VIRUS_PASSWORD", "")
    if not secret or not hmac.compare_digest(body.password.encode(), secret.encode()):
        raise HTTPException(403, "Falsches Passwort. Der Countdown läuft weiter.")
    now = utcnow()
    with LOCK:
        state = load_state(season_year(now))
        src = test_box(state) if test else state
        opened_ids = {state["order"][int(d) - 1] for d in src["opened"]}
        if "punish-virus" not in opened_ids:
            raise HTTPException(409, "Der VIRUS-Countdown läuft noch gar nicht.")
        if not src.get("virus_off"):
            src["virus_off"] = {"at": now.isoformat(), "by": str(user["username"]) if user else "Passwort"}
            save_state(state)
    return view(state, user, now, test)


@router.get("")
def calendar(user: dict | None = Depends(optional_user)) -> dict[str, Any]:
    now = utcnow()
    with LOCK:
        state = load_state(season_year(now))
    return view(state, user, now)


@router.post("/{day}/open")
def open_door(day: int, user: dict | None = Depends(optional_user)) -> dict[str, Any]:
    return do_open(day, user, test=False)


@router.post("/virus/off")
def virus_off(body: VirusOff, request: Request, user: dict | None = Depends(optional_user)) -> dict[str, Any]:
    return do_virus_off(body, request, user, test=False)


# ------------------------------------------------------------------ admin test mode

@router.get("/test")
def test_calendar(user: dict | None = Depends(optional_user)) -> dict[str, Any]:
    require_publisher(user)
    now = utcnow()
    with LOCK:
        state = load_state(season_year(now))
    return view(state, user, now, test=True)


@router.post("/test/reset")
def test_reset(user: dict | None = Depends(optional_user)) -> dict[str, Any]:
    require_publisher(user)
    now = utcnow()
    with LOCK:
        state = load_state(season_year(now))
        state["test"] = {"opened": {}, "virus_off": None}
        save_state(state)
    return view(state, user, now, test=True)


@router.post("/test/{day}/open")
def test_open(day: int, user: dict | None = Depends(optional_user)) -> dict[str, Any]:
    return do_open(day, user, test=True)


@router.post("/test/virus/off")
def test_virus_off(body: VirusOff, request: Request, user: dict | None = Depends(optional_user)) -> dict[str, Any]:
    require_publisher(user)
    return do_virus_off(body, request, user, test=True)
