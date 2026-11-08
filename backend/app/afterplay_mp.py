"""After Play spectator multiplayer.

Player 1 runs the Windows game and opens "Multiplayer": the game creates a
session here and shows a six-digit code. Player 2 enters that code on the
website, plans all thirteen rounds (an anomaly or nothing for each) and
saves; the game then starts the shift with that plan. While player 1 plays,
the game posts its live state and the current security-camera frame, which
player 2 watches on the website.

Sessions live in memory only and expire after a few hours; no account is
needed. Each side gets its own secret token, so knowing the code alone lets
nobody post frames or overwrite a saved plan.
"""
import secrets
import time
from threading import RLock
from typing import Literal

from fastapi import APIRouter, Header, HTTPException, Request, Response
from pydantic import BaseModel, ConfigDict, Field

router = APIRouter(prefix="/api/afterplay/mp", tags=["afterplay-multiplayer"])

ROUNDS = 13
SESSION_TTL = 4 * 3600
IDLE_TTL = 45 * 60
MAX_SESSIONS = 400
MAX_FRAME_BYTES = 350_000
MAX_EVENTS = 40


class Anomaly(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9_]+$")
    name: str = Field(min_length=1, max_length=200)
    zone: str = Field(default="", max_length=60)


class CreateSession(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: str = Field(default="", max_length=20)
    catalog: list[Anomaly] = Field(min_length=1, max_length=200)
    cameras: list[str] = Field(default_factory=list, max_length=24)


class Plan(BaseModel):
    model_config = ConfigDict(extra="forbid")
    rounds: list[str] = Field(min_length=ROUNDS, max_length=ROUNDS)


class LiveState(BaseModel):
    model_config = ConfigDict(extra="forbid")
    phase: str = Field(default="", max_length=32)
    round: int = Field(default=0, ge=0, le=14)
    streak: int = Field(default=0, ge=0, le=13)
    zone: str = Field(default="", max_length=60)
    camera: str = Field(default="", max_length=60)
    current: str = Field(default="", max_length=64)
    events: list[str] = Field(default_factory=list, max_length=10)


class Session:
    def __init__(self, code: str, body: CreateSession):
        now = time.time()
        self.code = code
        self.host_token = secrets.token_urlsafe(24)
        self.viewer_token: str | None = None
        self.catalog = [a.model_dump() for a in body.catalog]
        self.cameras = list(body.cameras)
        self.version = body.version
        self.plan: list[str] | None = None
        self.state: dict = {"phase": "waiting", "round": 0, "streak": 0, "zone": "", "camera": "", "current": ""}
        self.events: list[dict] = []
        self.frame: bytes | None = None
        self.frame_at = 0.0
        self.frame_seq = 0
        self.created = now
        self.touched = now

    def public(self) -> dict:
        return {"code": self.code, "version": self.version, "catalog": self.catalog, "cameras": self.cameras,
                "plan": self.plan, "state": self.state, "events": self.events[-MAX_EVENTS:],
                "frame_seq": self.frame_seq, "frame_age": round(time.time() - self.frame_at, 1) if self.frame else None,
                "joined": self.viewer_token is not None}


class Store:
    def __init__(self):
        self.lock = RLock()
        self.sessions: dict[str, Session] = {}

    def _expire(self) -> None:
        now = time.time()
        for code in [c for c, s in self.sessions.items() if now - s.created > SESSION_TTL or now - s.touched > IDLE_TTL]:
            del self.sessions[code]

    def create(self, body: CreateSession) -> Session:
        with self.lock:
            self._expire()
            if len(self.sessions) >= MAX_SESSIONS:
                raise HTTPException(503, "Zu viele offene Multiplayer-Sitzungen. Bitte später erneut versuchen.")
            for _ in range(50):
                code = f"{secrets.randbelow(1_000_000):06d}"
                if code not in self.sessions:
                    session = Session(code, body)
                    self.sessions[code] = session
                    return session
            raise HTTPException(503, "Kein freier Code verfügbar.")

    def get(self, code: str) -> Session:
        with self.lock:
            self._expire()
            session = self.sessions.get(code)
            if not session:
                raise HTTPException(404, "Diesen Code gibt es nicht oder er ist abgelaufen.")
            session.touched = time.time()
            return session


store = Store()


def _host(code: str, token: str | None) -> Session:
    session = store.get(code)
    if not token or not secrets.compare_digest(token, session.host_token):
        raise HTTPException(403, "Ungültiger Spiel-Schlüssel.")
    return session


def _viewer(code: str, token: str | None) -> Session:
    session = store.get(code)
    if not token or not session.viewer_token or not secrets.compare_digest(token, session.viewer_token):
        raise HTTPException(403, "Ungültiger Zuschauer-Schlüssel.")
    return session


@router.post("/sessions")
def create_session(body: CreateSession):
    session = store.create(body)
    return {"code": session.code, "host_token": session.host_token, "expires_in": SESSION_TTL}


@router.post("/sessions/{code}/join")
def join_session(code: str):
    if not code.isdigit() or len(code) != 6:
        raise HTTPException(400, "Der Code hat sechs Ziffern.")
    session = store.get(code)
    with store.lock:
        if session.viewer_token is not None:
            raise HTTPException(409, "Diesem Spiel ist schon jemand beigetreten.")
        session.viewer_token = secrets.token_urlsafe(24)
        session.events.append({"t": time.time(), "text": "Spieler 2 ist beigetreten."})
    return {"viewer_token": session.viewer_token, **session.public()}


@router.put("/sessions/{code}/plan")
def save_plan(code: str, body: Plan, x_viewer_token: str | None = Header(default=None)):
    session = _viewer(code, x_viewer_token)
    valid = {a["id"] for a in session.catalog} | {"none"}
    if any(r not in valid for r in body.rounds):
        raise HTTPException(400, "Unbekannte Anomalie im Plan.")
    with store.lock:
        if session.plan is not None:
            raise HTTPException(409, "Der Plan ist schon gespeichert und das Spiel läuft.")
        session.plan = list(body.rounds)
        session.events.append({"t": time.time(), "text": "Plan gespeichert. Die Schicht beginnt."})
    return {"ok": True}


@router.get("/sessions/{code}/host")
def host_poll(code: str, x_host_token: str | None = Header(default=None)):
    session = _host(code, x_host_token)
    return {"joined": session.viewer_token is not None, "plan": session.plan}


@router.post("/sessions/{code}/state")
def post_state(code: str, body: LiveState, x_host_token: str | None = Header(default=None)):
    session = _host(code, x_host_token)
    with store.lock:
        session.state = body.model_dump(exclude={"events"})
        now = time.time()
        for text in body.events:
            session.events.append({"t": now, "text": text[:200]})
        del session.events[:-MAX_EVENTS]
    return {"ok": True}


@router.put("/sessions/{code}/frame")
async def post_frame(code: str, request: Request, x_host_token: str | None = Header(default=None)):
    session = _host(code, x_host_token)
    data = await request.body()
    if len(data) > MAX_FRAME_BYTES or not data.startswith(b"\xff\xd8"):
        raise HTTPException(400, "Kamerabild ungültig.")
    with store.lock:
        session.frame = data; session.frame_at = time.time(); session.frame_seq += 1
    return {"seq": session.frame_seq}


@router.get("/sessions/{code}/view")
def view(code: str, x_viewer_token: str | None = Header(default=None)):
    return _viewer(code, x_viewer_token).public()


@router.get("/sessions/{code}/frame.jpg")
def frame(code: str, token: str = "", seq: int = 0):
    session = _viewer(code, token)
    if not session.frame:
        return Response(status_code=204)
    return Response(session.frame, media_type="image/jpeg", headers={"Cache-Control": "no-store"})
