"""Persistent two-person rooms with independent bomb/manual projections."""
import hashlib
import hmac
import json
import re
import secrets
import time
from datetime import datetime, timezone
from functools import lru_cache
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Response
from pydantic import BaseModel, Field
from .auth import current_user
from .economy import economy, DAILY_CAP, MIN_RUN_SECONDS
from .nullsignal_puzzles import MISSIONS, generate, apply_action

GRACE = 15
LIFETIME = 7200
CALM_SECONDS = 30
SCARE_SECONDS = 1.2


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


class NullsignalStore:
    def __init__(self, ledger):
        self.ledger = ledger
        with ledger.connection() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS nullsignal_rooms(id TEXT PRIMARY KEY,owner TEXT NOT NULL,invite TEXT NOT NULL,guest_hash TEXT,expires REAL NOT NULL,state TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS nullsignal_owner ON nullsignal_rooms(owner,expires);
                CREATE TABLE IF NOT EXISTS nullsignal_actions(room_id TEXT NOT NULL,request_id TEXT NOT NULL,signature TEXT NOT NULL,PRIMARY KEY(room_id,request_id));
                CREATE TABLE IF NOT EXISTS nullsignal_creations(owner TEXT NOT NULL,request_id TEXT NOT NULL,mission TEXT NOT NULL,room_id TEXT NOT NULL,PRIMARY KEY(owner,request_id));
                CREATE TABLE IF NOT EXISTS nullsignal_records(round_id TEXT PRIMARY KEY,room_id TEXT NOT NULL,host TEXT NOT NULL,expert TEXT NOT NULL,mission TEXT NOT NULL,outcome TEXT NOT NULL,score INTEGER NOT NULL,remaining REAL NOT NULL,played REAL NOT NULL,strikes INTEGER NOT NULL,reward INTEGER NOT NULL,created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS nullsignal_rank ON nullsignal_records(mission,outcome,score DESC);
            """)

    @staticmethod
    def new_state(mission, now, host, guest="", version=1):
        return {"mission": mission, "round_id": uuid4().hex, "status": "lobby", "version": version,
                "host_name": host, "expert_name": guest, "expert_ready": False, "host_seen": now,
                "expert_seen": now if guest else 0, "remaining": MISSIONS[mission]["seconds"],
                "deadline": None, "active_since": None, "played": 0, "strikes": 0,
                "pause_reason": "", "event": None, "finalized": False, "reward": 0,
                "bomb": generate(mission), "pills_remaining": 2, "calm_until_played": 0,
                "scare_at_played": None}

    @staticmethod
    def atmosphere(state, now):
        """Active-play clock only: pause/reconnect cannot advance stress or outages."""
        played = state["played"] + (max(0, now-state["active_since"]) if state["active_since"] is not None else 0)
        calm_until = state.get("calm_until_played", 0)
        scare_at = state.get("scare_at_played")
        return {"played": played, "untreated": max(0, played-calm_until),
                "outage_start": 40+int(state["round_id"][:4], 16) % 11,
                "scare_id": state["round_id"] if scare_at is not None else None,
                "scare_remaining": max(0, SCARE_SECONDS-(played-scare_at)) if scare_at is not None and played >= calm_until else 0}

    def load(self, db, room_id, now):
        row = db.execute("SELECT * FROM nullsignal_rooms WHERE id=?", (room_id,)).fetchone()
        if not row or row["expires"] <= now:
            raise HTTPException(404, "Diese Lobby ist abgelaufen oder existiert nicht mehr.")
        room = dict(row)
        room["state"] = json.loads(room["state"])
        # Existing unstarted lobbies adopt the current mission length as well.
        if room["state"]["status"] == "lobby":
            room["state"]["remaining"] = MISSIONS[room["state"]["mission"]]["seconds"]
        return room

    @staticmethod
    def save(db, room):
        db.execute("UPDATE nullsignal_rooms SET invite=?,guest_hash=?,expires=?,state=? WHERE id=?",
                   (room["invite"], room["guest_hash"], room["expires"], json.dumps(room["state"]), room["id"]))

    @staticmethod
    def authorize(room, role, credential):
        if role == "host":
            valid = room["owner"] == credential
        else:
            valid = bool(credential and room["guest_hash"] and hmac.compare_digest(room["guest_hash"], digest(credential)))
        if not valid:
            raise HTTPException(404 if role == "host" else 401, "Du hast keinen Zugang zu dieser Lobby. Öffne deinen Einladungslink erneut.")

    @staticmethod
    def stop_clock(state, now):
        if state["deadline"] is not None:
            state["remaining"] = max(0, state["deadline"]-now)
        if state["active_since"] is not None:
            state["played"] += max(0, now-state["active_since"])
        state["deadline"] = None
        state["active_since"] = None

    def finish(self, db, room, now):
        state = room["state"]
        if state["finalized"] or state["status"] not in {"defused", "exploded"}:
            return
        state["finalized"] = True
        score = max(0, int(state["remaining"]*100)-state["strikes"]*1000) if state["status"] == "defused" else 0
        day = datetime.fromtimestamp(now, timezone.utc).date().isoformat()
        reward = 0
        ready = db.execute("SELECT 1 FROM metadata WHERE key='chickens-v1-ready'").fetchone()
        if ready and state["status"] == "defused" and state["played"] >= MIN_RUN_SECONDS:
            earned = db.execute("SELECT COALESCE(SUM(reward),0) FROM runs WHERE username=? AND reward_day=?", (room["owner"], day)).fetchone()[0]
            reward = min(MISSIONS[state["mission"]]["reward"], max(0, DAILY_CAP-earned))
        state["reward"] = reward
        best = db.execute("SELECT COALESCE(MAX(score),0) FROM nullsignal_records WHERE mission=? AND outcome='defused'", (state["mission"],)).fetchone()[0]
        record = state["status"] == "defused" and score > best
        db.execute("INSERT INTO nullsignal_records VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                   (state["round_id"], room["id"], room["owner"], state["expert_name"], state["mission"], state["status"], score, state["remaining"], state["played"], state["strikes"], reward, now))
        # Server-confirmed defusals share the existing daily cap and audit trail.
        # There is deliberately no client score-submission endpoint for this game.
        if state["status"] == "defused":
            db.execute("INSERT OR IGNORE INTO wallets(username) VALUES (?)", (room["owner"],))
            db.execute("UPDATE wallets SET chickens=chickens+?,earned=earned+? WHERE username=?", (reward, reward, room["owner"]))
            payload = {"score": score, "mission": state["mission"], "expert": state["expert_name"], "strikes": state["strikes"]}
            db.execute("INSERT INTO runs(id,username,game,started,completed,score,payload,reward,reward_day,is_highscore) VALUES (?,?,?,?,?,?,?,?,?,?)",
                       (f"nullsignal:{state['round_id']}", room["owner"], "nullsignal", now-state["played"], now, score, json.dumps(payload), reward, day, int(record)))
            if record:
                self.ledger._queue_alert(db, f"nullsignal:{state['round_id']}", room["owner"], f"NULLSIGNAL · {MISSIONS[state['mission']]['name']}", "Highscore", 0, now, kind="highscore", game="nullsignal", score=score)

    def advance(self, db, room, now):
        state = room["state"]
        if state["status"] == "running":
            disconnected_at = min(state["host_seen"], state["expert_seen"])+GRACE
            if state["deadline"] <= now and state["deadline"] <= disconnected_at:
                self.stop_clock(state, state["deadline"])
                state["status"] = "exploded"
                state["event"] = {"id": uuid4().hex, "kind": "exploded", "message": "Zeit abgelaufen."}
                state["version"] += 1
            elif disconnected_at <= now:
                self.stop_clock(state, disconnected_at)
                state["status"] = "paused"
                state["pause_reason"] = "connection"
                state["version"] += 1
            if state["status"] == "running" and state.get("scare_at_played") is None:
                atmosphere = self.atmosphere(state, now)
                if state["deadline"]-now <= 50 and atmosphere["untreated"] >= 85:
                    state["scare_at_played"] = atmosphere["played"]
                    state["version"] += 1
        self.finish(db, room, now)

    def project(self, db, room, role, now):
        state = room["state"]
        result = {key: state[key] for key in ["round_id", "status", "version", "host_name", "expert_name", "expert_ready", "remaining", "deadline", "strikes", "pause_reason", "event"]}
        result.update(room_id=room["id"], mission=MISSIONS[state["mission"]], server_time=now,
                      host_online=now-state["host_seen"] < GRACE, expert_online=bool(room["guest_hash"]) and now-state["expert_seen"] < GRACE,
                      expires=room["expires"], solved=sum(m["solved"] for m in state["bomb"]["modules"]))
        if role == "host":
            result["atmosphere"] = self.atmosphere(state, now)
            played = state["played"] + (max(0, now-state["active_since"]) if state["active_since"] is not None else 0)
            result["calm"] = {"pills_remaining": state.get("pills_remaining", 2),
                              "seconds_remaining": max(0, state.get("calm_until_played", 0)-played)}
            result["invite_token"] = room["invite"]
            result["bomb"] = {key: state["bomb"][key] for key in ["serial", "voltage", "coolant"]}
            result["bomb"]["modules"] = [{key: module[key] for key in ["id", "kind", "name", "data", "solved", "progress"]} for module in state["bomb"]["modules"]]
            if state["finalized"]:
                result.update(chickens_awarded=state["reward"], wallet=self.ledger.wallet(db, room["owner"]))
        else:
            result["manual"] = [{key: module[key] for key in ["id", "kind", "name", "manual", "solved"]} for module in state["bomb"]["modules"]]
        if state["finalized"]:
            result["result"] = dict(db.execute("SELECT score,remaining,played,strikes,reward FROM nullsignal_records WHERE round_id=?", (state["round_id"],)).fetchone())
        return result

    def create(self, username, mission, now=None, request_id=None):
        now = time.time() if now is None else now
        with self.ledger.connection(write=True) as db:
            previous = db.execute("SELECT mission,room_id FROM nullsignal_creations WHERE owner=? AND request_id=?", (username, request_id)).fetchone() if request_id else None
            if previous:
                if previous["mission"] != mission:
                    raise HTTPException(409, "Diese Lobby-Anfrage gehört zu einer anderen Mission.")
                room = self.load(db, previous["room_id"], now)
                self.advance(db, room, now)
                room["state"]["host_seen"] = now
                self.save(db, room)
                return self.project(db, room, "host", now)
            db.execute("DELETE FROM nullsignal_rooms WHERE expires<=?", (now,))
            db.execute("DELETE FROM nullsignal_actions WHERE room_id NOT IN (SELECT id FROM nullsignal_rooms)")
            db.execute("DELETE FROM nullsignal_creations WHERE room_id NOT IN (SELECT id FROM nullsignal_rooms)")
            count = db.execute("SELECT COUNT(*) FROM nullsignal_rooms WHERE owner=? AND json_extract(state,'$.status') NOT IN ('closed','defused','exploded')", (username,)).fetchone()[0]
            if count >= 3:
                raise HTTPException(409, "Du hast bereits drei offene Lobbys. Schließe zuerst eine davon.")
            room = {"id": uuid4().hex, "owner": username, "invite": secrets.token_urlsafe(24), "guest_hash": None, "expires": now+LIFETIME, "state": self.new_state(mission, now, username)}
            db.execute("INSERT INTO nullsignal_rooms VALUES (?,?,?,?,?,?)", (room["id"], username, room["invite"], None, room["expires"], json.dumps(room["state"])))
            if request_id:
                db.execute("INSERT INTO nullsignal_creations VALUES (?,?,?,?)", (username, request_id, mission, room["id"]))
            return self.project(db, room, "host", now)

    def active(self, username, now=None):
        now = time.time() if now is None else now
        with self.ledger.connection(write=True) as db:
            row = db.execute("SELECT id FROM nullsignal_rooms WHERE owner=? AND expires>? AND json_extract(state,'$.status')!='closed' ORDER BY expires DESC LIMIT 1", (username, now)).fetchone()
            if not row:
                return None
            room = self.load(db, row["id"], now)
            self.advance(db, room, now)
            room["state"]["host_seen"] = now
            self.save(db, room)
            return self.project(db, room, "host", now)

    def get(self, room_id, role, credential, now=None):
        now = time.time() if now is None else now
        with self.ledger.connection(write=True) as db:
            room = self.load(db, room_id, now)
            self.authorize(room, role, credential)
            self.advance(db, room, now)
            room["state"][f"{role}_seen" if role == "host" else "expert_seen"] = now
            self.save(db, room)
            return self.project(db, room, role, now)

    def join(self, room_id, invitation, name, resume=None, now=None):
        now = time.time() if now is None else now
        name = name.strip()
        if len(name) < 2 or any(ord(char) < 32 for char in name):
            raise HTTPException(400, "Bitte einen Namen mit mindestens zwei Zeichen eingeben.")
        if resume and not re.fullmatch(r"[A-Za-z0-9_-]{32,64}", resume):
            raise HTTPException(400, "Ungültiger Zugangsschlüssel. Öffne die Einladung erneut.")
        with self.ledger.connection(write=True) as db:
            room = self.load(db, room_id, now)
            if not hmac.compare_digest(room["invite"], invitation) or room["state"]["status"] == "closed":
                raise HTTPException(404, "Dieser Einladungslink ist nicht mehr gültig.")
            if room["guest_hash"]:
                if not resume or not hmac.compare_digest(room["guest_hash"], digest(resume)):
                    raise HTTPException(409, "Der Expertenplatz ist bereits belegt. Bitte den Streamer um eine neue Einladung bitten.")
                token = resume
            else:
                if room["state"]["status"] != "lobby":
                    raise HTTPException(409, "Diese Runde nimmt gerade keine neuen Mitspieler an.")
                # The browser persists a cryptographically random capability
                # before claiming. A lost join response can therefore reconnect.
                token = resume or secrets.token_urlsafe(32)
                room["guest_hash"] = digest(token)
                room["state"].update(expert_name=name, expert_ready=False)
            self.advance(db, room, now)
            room["state"]["expert_seen"] = now
            room["state"]["version"] += 1
            self.save(db, room)
            return {**self.project(db, room, "expert", now), "guest_token": token}

    def ready(self, room_id, token, ready, now=None):
        now = time.time() if now is None else now
        with self.ledger.connection(write=True) as db:
            room = self.load(db, room_id, now)
            self.authorize(room, "expert", token)
            self.advance(db, room, now)
            if room["state"]["status"] not in {"lobby", "paused"}:
                raise HTTPException(409, "Die Mission läuft bereits oder ist beendet.")
            room["state"].update(expert_ready=ready, expert_seen=now)
            room["state"]["version"] += 1
            self.save(db, room)
            return self.project(db, room, "expert", now)

    def control(self, room_id, username, command, mission=None, now=None):
        now = time.time() if now is None else now
        with self.ledger.connection(write=True) as db:
            room = self.load(db, room_id, now)
            self.authorize(room, "host", username)
            self.advance(db, room, now)
            state = room["state"]
            state["host_seen"] = now
            if command == "start":
                if state["status"] not in {"lobby", "paused"}:
                    raise HTTPException(409, "Diese Mission kann gerade nicht gestartet werden.")
                if not room["guest_hash"] or not state["expert_ready"] or now-state["expert_seen"] >= GRACE:
                    raise HTTPException(409, "Dein Experte muss verbunden und bereit sein.")
                state.update(status="running", deadline=now+state["remaining"], active_since=now, pause_reason="")
            elif command == "pause":
                if state["status"] == "running":
                    self.stop_clock(state, now)
                    state.update(status="paused", pause_reason="manual")
            elif command in {"reset", "replace"}:
                if state["status"] == "running":
                    raise HTTPException(409, "Pausiere die Mission zuerst.")
                guest = state["expert_name"] if command == "reset" else ""
                room["state"] = self.new_state(mission or state["mission"], now, username, guest, state["version"])
                room["expires"] = now+LIFETIME
                if command == "reset":
                    # A replacement round must not invent an online heartbeat.
                    room["state"]["expert_seen"] = state["expert_seen"]
                if command == "replace":
                    room["guest_hash"] = None
                    room["invite"] = secrets.token_urlsafe(24)
                db.execute("DELETE FROM nullsignal_actions WHERE room_id=?", (room_id,))
                state = room["state"]
            elif command == "close":
                self.stop_clock(state, now)
                state["status"] = "closed"
                room["guest_hash"] = None
            else:
                raise HTTPException(400, "Unbekannter Lobby-Befehl.")
            state["version"] += 1
            self.save(db, room)
            return self.project(db, room, "host", now)

    def action(self, room_id, username, request_id, round_id, module_id, operation, value, now=None):
        now = time.time() if now is None else now
        signature = json.dumps([round_id, module_id, operation, value])
        with self.ledger.connection(write=True) as db:
            room = self.load(db, room_id, now)
            self.authorize(room, "host", username)
            self.advance(db, room, now)
            state = room["state"]
            previous = db.execute("SELECT signature FROM nullsignal_actions WHERE room_id=? AND request_id=?", (room_id, request_id)).fetchone()
            if previous:
                if previous[0] != signature:
                    raise HTTPException(409, "Diese Aktion wurde bereits anders verwendet.")
                state["host_seen"] = now
                self.save(db, room)
                return self.project(db, room, "host", now)
            if state["status"] != "running" or state["round_id"] != round_id:
                raise HTTPException(409, "Die Runde läuft nicht. Aktualisiere die Ansicht oder setze die Mission fort.")
            module = next((m for m in state["bomb"]["modules"] if m["id"] == module_id), None)
            if not module:
                raise HTTPException(404, "Modul nicht gefunden.")
            if not module["solved"]:
                try:
                    outcome = apply_action(module, operation, value)
                except (ValueError, TypeError) as exc:
                    raise HTTPException(400, str(exc)) from exc
                if outcome == "bad":
                    state["strikes"] += 1
                    state["deadline"] -= 8
                    message = "Fehler. Acht Sekunden verloren."
                    if state["strikes"] >= 3 or state["deadline"] <= now:
                        self.stop_clock(state, now)
                        state["status"] = "exploded"
                        outcome, message = "exploded", "Drei Fehler oder keine Zeit mehr. Die Verbindung ist verloren."
                elif outcome == "good":
                    message = f"{module['name']} gesichert."
                    if all(m["solved"] for m in state["bomb"]["modules"]):
                        self.stop_clock(state, now)
                        state["status"] = "defused"
                        outcome, message = "defused", "Alle Module gesichert. Gemeinsam geschafft!"
                else:
                    message = "Eingabe übernommen."
                state["event"] = {"id": request_id, "kind": outcome, "module": module_id, "message": message}
            state["host_seen"] = now
            state["version"] += 1
            db.execute("INSERT INTO nullsignal_actions VALUES (?,?,?)", (room_id, request_id, signature))
            self.finish(db, room, now)
            self.save(db, room)
            return self.project(db, room, "host", now)

    def calm(self, room_id, username, request_id, round_id, now=None):
        now = time.time() if now is None else now
        signature = json.dumps([round_id, "calm"])
        with self.ledger.connection(write=True) as db:
            room = self.load(db, room_id, now)
            self.authorize(room, "host", username)
            self.advance(db, room, now)
            state = room["state"]
            previous = db.execute("SELECT signature FROM nullsignal_actions WHERE room_id=? AND request_id=?", (room_id, request_id)).fetchone()
            if previous:
                if previous[0] != signature:
                    raise HTTPException(409, "Diese Anfrage wurde bereits anders verwendet.")
                state["host_seen"] = now
                self.save(db, room)
                return self.project(db, room, "host", now)
            if state["status"] != "running" or state["round_id"] != round_id:
                raise HTTPException(409, "Eine Beruhigungspille ist nur in der laufenden Runde verfügbar.")
            played = state["played"] + max(0, now-state["active_since"])
            if state.get("pills_remaining", 2) <= 0:
                raise HTTPException(409, "Du hast beide Beruhigungspillen dieser Runde verbraucht.")
            if state.get("calm_until_played", 0) > played:
                raise HTTPException(409, "Die Beruhigungspille wirkt noch.")
            state["pills_remaining"] = state.get("pills_remaining", 2)-1
            state["calm_until_played"] = played+CALM_SECONDS
            state["host_seen"] = now
            state["version"] += 1
            state["event"] = {"id": request_id, "kind": "calm", "message": "Beruhigungspille genommen. 30 Sekunden klare Sicht."}
            db.execute("INSERT INTO nullsignal_actions VALUES (?,?,?)", (room_id, request_id, signature))
            self.save(db, room)
            return self.project(db, room, "host", now)

    def records(self, mission):
        with self.ledger.connection() as db:
            return [dict(row) for row in db.execute("SELECT host,expert,score,remaining,strikes,created FROM nullsignal_records WHERE outcome='defused' AND mission=? ORDER BY score DESC,created ASC LIMIT 20", (mission,))]


@lru_cache
def store():
    return NullsignalStore(economy())


router = APIRouter(prefix="/api/nullsignal", tags=["nullsignal"])


class CreateRoom(BaseModel):
    mission: str = Field(default="contact", pattern="^(contact|incident|blackout)$")
    request_id: str | None = Field(default=None, min_length=16, max_length=64, pattern="^[A-Za-z0-9_-]+$")


class JoinRoom(BaseModel):
    invite_token: str = Field(min_length=20, max_length=64, pattern="^[A-Za-z0-9_-]+$")
    name: str = Field(min_length=2, max_length=24)


class Ready(BaseModel):
    ready: bool


class Calm(BaseModel):
    request_id: str = Field(min_length=16, max_length=64, pattern="^[A-Za-z0-9_-]+$")
    round_id: str = Field(min_length=32, max_length=32)


class Control(BaseModel):
    command: str = Field(pattern="^(start|pause|reset|replace|close)$")
    mission: str | None = Field(default=None, pattern="^(contact|incident|blackout)$")


class Action(BaseModel):
    request_id: str = Field(min_length=16, max_length=64, pattern="^[A-Za-z0-9_-]+$")
    round_id: str = Field(min_length=32, max_length=32)
    module_id: str = Field(max_length=16)
    operation: str = Field(max_length=16)
    value: int | list[int] | None = None


def private(response: Response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"


@router.get("/catalog")
def catalog():
    return list(MISSIONS.values())


@router.get("/records/{mission}")
def records(mission: str):
    if mission not in MISSIONS:
        raise HTTPException(404, "Mission nicht gefunden.")
    return store().records(mission)


@router.post("/rooms")
def create(payload: CreateRoom, response: Response, user=Depends(current_user)):
    private(response)
    return store().create(user["username"], payload.mission, request_id=payload.request_id)


@router.get("/rooms/active")
def active(response: Response, user=Depends(current_user)):
    private(response)
    return store().active(user["username"])


@router.get("/rooms/{room_id}/host")
def host(room_id: str, response: Response, user=Depends(current_user)):
    private(response)
    return store().get(room_id, "host", user["username"])


@router.get("/rooms/{room_id}/expert")
def expert(room_id: str, response: Response, x_nullsignal_token: str | None = Header(default=None)):
    private(response)
    return store().get(room_id, "expert", x_nullsignal_token)


@router.post("/rooms/{room_id}/join")
def join(room_id: str, payload: JoinRoom, response: Response, x_nullsignal_token: str | None = Header(default=None)):
    private(response)
    return store().join(room_id, payload.invite_token, payload.name, x_nullsignal_token)


@router.post("/rooms/{room_id}/ready")
def ready(room_id: str, payload: Ready, response: Response, x_nullsignal_token: str | None = Header(default=None)):
    private(response)
    return store().ready(room_id, x_nullsignal_token, payload.ready)


@router.post("/rooms/{room_id}/control")
def control(room_id: str, payload: Control, response: Response, user=Depends(current_user)):
    private(response)
    return store().control(room_id, user["username"], payload.command, payload.mission)


@router.post("/rooms/{room_id}/action")
def action(room_id: str, payload: Action, response: Response, user=Depends(current_user)):
    private(response)
    return store().action(room_id, user["username"], payload.request_id, payload.round_id, payload.module_id, payload.operation, payload.value)


@router.post("/rooms/{room_id}/calm")
def calm(room_id: str, payload: Calm, response: Response, user=Depends(current_user)):
    private(response)
    return store().calm(room_id, user["username"], payload.request_id, payload.round_id)
