"""Statistik: privacy-friendly traffic tracking plus activity numbers for the admin dashboard.

Tracking stores no IP address and no cookie: the browser sends a random visitor id from
localStorage, the page it shows and (once per visit) the external referrer domain. Logged-in
members are recognised by their session token. A "ping" every minute while the tab is visible
measures time on the site. Rows older than 400 days are deleted.

Activity numbers (rounds, purchases, derby, slots, active members) come from the existing
ledgers, so those charts have history from day one.
"""
from __future__ import annotations

import random
import re
import time
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from typing import Any, Literal
from urllib.parse import urlparse
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header, Request, Response
from jose import JWTError, jwt
from pydantic import BaseModel, Field

from . import ratelimit
from .auth import TOKEN_ALGORITHM, require_admin
from .config import get_settings
from .economy import GAME_TITLES, economy

router = APIRouter()
TZ = ZoneInfo("Europe/Berlin")
RETENTION_DAYS = 400
ONLINE_WINDOW = 180
OWN_HOSTS = {"my-aviary.de", "www.my-aviary.de", "62.238.49.219", "localhost", "127.0.0.1"}


class Track(BaseModel):
    visitor: str = Field(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9-]+$")
    path: str = Field(default="home", max_length=80)
    kind: Literal["view", "ping"] = "view"
    ref: str = Field(default="", max_length=300)
    width: int = Field(default=0, ge=0, le=20000)


def ensure_table(db) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS pageviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT, ts REAL NOT NULL, kind TEXT NOT NULL, path TEXT NOT NULL,
        visitor TEXT NOT NULL, username TEXT, device TEXT NOT NULL, browser TEXT NOT NULL, referrer TEXT)""")
    db.execute("CREATE INDEX IF NOT EXISTS pageviews_ts ON pageviews(ts)")


def clean_path(path: str) -> str:
    parts = [p for p in re.split(r"[/#?]+", path.strip().lower()) if p][:2]
    parts = [re.sub(r"[^a-z0-9_-]", "", p)[:32] for p in parts]
    if parts and parts[0] == "u":
        return "u"          # profile pages: never store whose profile was opened
    return "/".join(p for p in parts if p) or "home"


def device_of(width: int, agent: str) -> str:
    if re.search(r"ipad|tablet", agent, re.I) or 700 <= width < 1100 and re.search(r"android|mobile", agent, re.I):
        return "Tablet"
    if re.search(r"mobi|iphone|android", agent, re.I) or 0 < width < 700:
        return "Smartphone"
    return "Desktop"


def browser_of(agent: str) -> str:
    for pattern, name in ((r"OBS|Streamlabs", "OBS / Streamlabs"), (r"Edg/", "Edge"), (r"OPR/|Opera", "Opera"), (r"Firefox/", "Firefox"),
                          (r"Chrome/|CriOS", "Chrome"), (r"Safari/", "Safari")):
        if re.search(pattern, agent):
            return name
    return "Andere"


def referrer_of(ref: str) -> str | None:
    try:
        host = (urlparse(ref).hostname or "").lower()
    except ValueError:
        return None
    if not host or host in OWN_HOSTS:
        return None
    return host[4:] if host.startswith("www.") else host[:80]


def user_of(authorization: str | None) -> str | None:
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    try:
        payload = jwt.decode(authorization.split(" ", 1)[1], get_settings().jwt_secret, algorithms=[TOKEN_ALGORITHM])
    except JWTError:
        return None
    return str(payload.get("sub") or "").strip()[:32] or None


@router.post("/api/track")
def track(body: Track, request: Request, response: Response, authorization: str | None = Header(default=None)) -> dict[str, bool]:
    response.headers["Cache-Control"] = "no-store"
    ratelimit.hit(request, "track", 90, 60)
    agent = request.headers.get("user-agent", "")[:400]
    now = time.time()
    with economy().connection(write=True) as db:
        ensure_table(db)
        db.execute("INSERT INTO pageviews(ts, kind, path, visitor, username, device, browser, referrer) VALUES (?,?,?,?,?,?,?,?)",
                   (now, body.kind, clean_path(body.path), body.visitor, user_of(authorization), device_of(body.width, agent),
                    browser_of(agent), referrer_of(body.ref) if body.kind == "view" else None))
        if random.random() < 0.005:
            db.execute("DELETE FROM pageviews WHERE ts < ?", (now - RETENTION_DAYS * 86400,))
    return {"ok": True}


# ---------------------------------------------------------------------------------------- report
def local(ts: float) -> datetime:
    return datetime.fromtimestamp(ts, TZ)


def by_day(ts: float) -> str:
    return local(ts).date().isoformat()


def by_hour(ts: float) -> str:
    return local(ts).strftime("%Y-%m-%dT%H")


def buckets(days: int, now: float) -> tuple[list[str], Any]:
    """Chart buckets ending with the day of `now`: hours for a single day, otherwise days."""
    today = local(now).date()
    if days == 1:
        return [f"{today.isoformat()}T{h:02d}" for h in range(24)], by_hour
    return [(today - timedelta(days=days - 1 - i)).isoformat() for i in range(days)], by_day


def per_day(rows, keys, bucket=by_day, value=lambda r: 1) -> list[int]:
    out = dict.fromkeys(keys, 0)
    for r in rows:
        k = bucket(r["created"])
        if k in out:
            out[k] += value(r)
    return [out[k] for k in keys]


def traffic(rows, keys, bucket=by_day) -> dict[str, Any]:
    views = [r for r in rows if r["kind"] == "view"]
    visitors = {r["visitor"] for r in rows}
    members = {r["username"] for r in rows if r["username"]}
    daily: dict[str, dict[str, Any]] = {k: {"views": 0, "v": set(), "m": set(), "minutes": 0} for k in keys}
    heat = [[0] * 24 for _ in range(7)]
    pages: dict[str, dict[str, Any]] = defaultdict(lambda: {"views": 0, "v": set(), "minutes": 0})
    visitor_device: dict[str, str] = {}
    browsers_by_visitor: dict[str, str] = {}
    refs: Counter = Counter()
    for r in rows:
        when = local(r["ts"])
        d = daily.get(bucket(r["ts"]))
        if d is not None:
            d["v"].add(r["visitor"])
            if r["username"]:
                d["m"].add(r["username"])
        visitor_device[r["visitor"]] = r["device"]
        browsers_by_visitor[r["visitor"]] = r["browser"]
        page = pages[r["path"]]
        if r["kind"] == "view":
            page["views"] += 1
            page["v"].add(r["visitor"])
            heat[when.weekday()][when.hour] += 1
            if d is not None:
                d["views"] += 1
            if r["referrer"]:
                refs[r["referrer"]] += 1
        else:
            page["minutes"] += 1
            if d is not None:
                d["minutes"] += 1
    minutes = sum(1 for r in rows if r["kind"] == "ping")
    return {
        "views": len(views), "visitors": len(visitors), "members": len(members), "minutes": minutes,
        "daily": [{"day": k, "views": daily[k]["views"], "visitors": len(daily[k]["v"]), "members": len(daily[k]["m"]),
                   "minutes": daily[k]["minutes"]} for k in keys],
        "heat": heat,
        "pages": sorted(({"path": p, "views": v["views"], "visitors": len(v["v"]), "minutes": v["minutes"]} for p, v in pages.items()),
                        key=lambda x: (-x["views"], -x["minutes"]))[:14],
        "devices": Counter(visitor_device.values()).most_common(),
        "browsers": Counter(browsers_by_visitor.values()).most_common(6),
        "referrers": refs.most_common(8),
    }


def activity(db, since: float, until: float, keys: list[str], bucket=by_day) -> dict[str, Any]:
    def q(sql):
        try:
            return db.execute(sql, (since, until)).fetchall()
        except Exception:      # a table that a feature creates lazily may not exist yet
            return []
    runs = q("SELECT username, game, completed AS created, reward FROM runs WHERE completed >= ? AND completed < ?")
    buys = q("SELECT username, item_name, category, price, created FROM purchases WHERE created >= ? AND created < ?")
    races = q("SELECT username, created FROM horse_races WHERE created >= ? AND created < ?")
    spins = q("SELECT username, created FROM slot_spins WHERE created >= ? AND created < ?")
    xp = q("SELECT username, created FROM xp_log WHERE created >= ? AND created < ?")
    active: dict[str, set] = {k: set() for k in keys}
    for r in [*xp, *runs, *buys]:
        k = bucket(r["created"])
        if k in active:
            active[k].add(r["username"])
    games = Counter(GAME_TITLES.get(r["game"], r["game"]) for r in runs)
    if races:
        games["Chicken Derby"] += len(races)
    if spins:
        games["Chicken Jackpot"] += len(spins)
    players = Counter(r["username"] for r in [*runs, *races, *spins])
    items = Counter(r["item_name"] for r in buys)
    return {
        "active_daily": [len(active[k]) for k in keys],
        "active_total": len({r["username"] for r in [*xp, *runs, *buys]}),
        "rounds_daily": per_day(runs, keys, bucket),
        "casino_daily": per_day([*races, *spins], keys, bucket),
        "purchases_daily": per_day(buys, keys, bucket),
        "earned_daily": per_day(runs, keys, bucket, lambda r: r["reward"] or 0),
        "spent_daily": per_day(buys, keys, bucket, lambda r: r["price"] or 0),
        "rounds": len(runs) + len(races) + len(spins),
        "purchases": len(buys),
        "spent": sum(r["price"] or 0 for r in buys),
        "earned": sum(r["reward"] or 0 for r in runs),
        "games": games.most_common(),
        "players": players.most_common(8),
        "items": items.most_common(8),
    }


def report(days: int, now: float | None = None) -> dict[str, Any]:
    now = time.time() if now is None else now
    keys, bucket = buckets(days, now)
    start = datetime.fromisoformat(keys[0][:10]).replace(tzinfo=TZ).timestamp()
    prev_start = start - days * 86400
    prev_keys, _ = buckets(days, start - 1)
    with economy().connection(write=True) as db:
        ensure_table(db)
        rows = db.execute("SELECT ts, kind, path, visitor, username, device, browser, referrer FROM pageviews WHERE ts >= ? ORDER BY ts", (prev_start,)).fetchall()
        current = [r for r in rows if r["ts"] >= start]
        previous = [r for r in rows if r["ts"] < start]
        now_rows = [r for r in current if r["ts"] >= now - ONLINE_WINDOW]
        first = db.execute("SELECT MIN(ts) FROM pageviews").fetchone()[0]
        act = activity(db, start, now + 1, keys, bucket)
        prev_act = activity(db, prev_start, start, prev_keys, bucket)
    t, p = traffic(current, keys, bucket), traffic(previous, prev_keys, bucket)
    for d in t["daily"]:
        d["guests"] = max(0, d["visitors"] - d["members"])
    latest: dict[str, Any] = {}
    for r in now_rows:
        latest[r["visitor"]] = r
    online = [{"user": r["username"] or "Gast", "path": r["path"], "device": r["device"]} for r in latest.values()]
    prev_rounds = prev_act["rounds"]
    return {
        "days": days, "keys": keys, "hourly": days == 1, "now": now, "tracking_since": first,
        "kpis": {
            "visitors": [t["visitors"], p["visitors"]],
            "views": [t["views"], p["views"]],
            "members": [t["members"], p["members"]],
            "minutes_per_visitor": [round(t["minutes"] / t["visitors"], 1) if t["visitors"] else 0, round(p["minutes"] / p["visitors"], 1) if p["visitors"] else 0],
            "active_members": [act["active_total"], prev_act["active_total"]],
            "rounds": [act["rounds"], prev_rounds],
            "purchases": [act["purchases"], prev_act["purchases"]],
            "spent": [act["spent"], prev_act["spent"]],
        },
        "online": sorted(online, key=lambda o: (o["user"] == "Gast", o["user"].casefold())),
        "traffic": {k: t[k] for k in ("daily", "heat", "pages", "devices", "browsers", "referrers")},
        "activity": act,
    }


@router.get("/api/admin/stats", dependencies=[Depends(require_admin)])
def stats(response: Response, days: int = 30) -> dict[str, Any]:
    response.headers["Cache-Control"] = "no-store"
    return report(days if days in (1, 7, 30, 90) else 30)
