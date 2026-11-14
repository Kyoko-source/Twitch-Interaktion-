"""Free online tabletop for fifth-edition fantasy roleplay.

One room = one table: a Dungeon Master, up to eight players and spectators.
The whole table lives in one JSON document per room (SQLite on /data) with a
version counter; browsers poll with ?since=<version> and only receive a new
view when something changed. Every change is an action the server checks:
the DM may do everything, players only touch their own character, and all
dice are rolled here with a cryptographic RNG so nobody can fake a natural 20.

Rules content (classes, species, monsters) used by the frontend comes from
the System Reference Document 5.2 (CC-BY-4.0).
"""
import builtins
import json
import os
import re
import secrets
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path
from threading import Lock
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

from .auth import current_user
from . import ratelimit

router = APIRouter(prefix="/api/dnd", tags=["dnd"])

MAX_PLAYERS = 8
MAX_CREATURES = 60
LOG_KEEP = 300
ROOM_IDLE_DAYS = 30
ABILITIES = ("str", "dex", "con", "int", "wis", "cha")
CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
CONDITIONS = {"Blind", "Bezaubert", "Taub", "Erschöpft", "Verängstigt", "Gepackt", "Kampfunfähig", "Unsichtbar",
              "Gelähmt", "Versteinert", "Vergiftet", "Liegend", "Festgesetzt", "Betäubt", "Bewusstlos", "Konzentration"}
COLOR_RE = r"^#[0-9a-fA-F]{6}$"


# ---------------------------------------------------------------- storage

class Store:
    def __init__(self, path: Path):
        self.path = path
        self.lock = Lock()
        path.parent.mkdir(parents=True, exist_ok=True)
        with self.db() as db:
            db.execute("""CREATE TABLE IF NOT EXISTS rooms (
                code TEXT PRIMARY KEY, name TEXT NOT NULL, dm TEXT NOT NULL, created REAL NOT NULL,
                updated REAL NOT NULL, version INTEGER NOT NULL, state TEXT NOT NULL)""")

    @contextmanager
    def db(self):
        db = sqlite3.connect(self.path, timeout=30, isolation_level=None)
        try:
            db.execute("PRAGMA journal_mode=WAL")
            yield db
        finally:
            db.close()

    def load(self, code: str) -> tuple[dict, int]:
        with self.db() as db:
            row = db.execute("SELECT state, version FROM rooms WHERE code=?", (code,)).fetchone()
        if not row:
            raise HTTPException(404, "Diesen Spieltisch gibt es nicht.")
        return json.loads(row[0]), row[1]

    def version(self, code: str) -> int:
        with self.db() as db:
            row = db.execute("SELECT version FROM rooms WHERE code=?", (code,)).fetchone()
        if not row:
            raise HTTPException(404, "Diesen Spieltisch gibt es nicht.")
        return row[0]

    def create(self, state: dict) -> str:
        with self.lock, self.db() as db:
            for _ in range(40):
                code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(6))
                if not db.execute("SELECT 1 FROM rooms WHERE code=?", (code,)).fetchone():
                    now = time.time()
                    state["code"] = code
                    db.execute("INSERT INTO rooms VALUES (?,?,?,?,?,?,?)", (code, state["name"], state["dm"], now, now, 1, json.dumps(state)))
                    return code
        raise HTTPException(503, "Kein freier Tisch-Code. Bitte nochmal versuchen.")

    def mutate(self, code: str, change) -> tuple[dict, int]:
        """Load, apply `change(state)` and save atomically."""
        with self.lock, self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            try:
                row = db.execute("SELECT state, version FROM rooms WHERE code=?", (code,)).fetchone()
                if not row:
                    raise HTTPException(404, "Diesen Spieltisch gibt es nicht.")
                state = json.loads(row[0])
                result = change(state)
                if result == "delete":
                    db.execute("DELETE FROM rooms WHERE code=?", (code,))
                    db.execute("COMMIT")
                    return state, -1
                version = row[1] + 1
                db.execute("UPDATE rooms SET state=?, version=?, updated=?, name=? WHERE code=?",
                           (json.dumps(state), version, time.time(), state["name"], code))
                db.execute("COMMIT")
                return state, version
            except BaseException:
                db.execute("ROLLBACK")
                raise

    def listing(self, username: str, admin: bool = False) -> list[dict]:
        cutoff = time.time() - ROOM_IDLE_DAYS * 86400
        with self.db() as db:
            rows = db.execute("SELECT state, updated FROM rooms WHERE updated > ? ORDER BY updated DESC LIMIT 200", (cutoff,)).fetchall()
        out = []
        for raw, updated in rows:
            state = json.loads(raw)
            member = state["members"].get(username)
            if not member and state.get("locked") and not admin:
                continue
            players = [u for u, m in state["members"].items() if m["role"] == "player"]
            out.append({"code": state["code"], "name": state["name"], "dm": state["dm"], "players": len(players),
                        "max_players": MAX_PLAYERS, "locked": bool(state.get("locked")), "my_role": member["role"] if member else None,
                        "updated": updated, "scene": state.get("scene", {}).get("title", ""),
                        "can_close": admin or state["dm"] == username})
        return out


_store: Store | None = None


def get_store() -> Store:
    global _store
    if _store is None:
        _store = Store(Path(os.getenv("AVIARY_DND_DB", "/data/dnd.sqlite3")))
    return _store


# ---------------------------------------------------------------- dice

DICE_TERM = re.compile(r"([+-]?)\s*(?:(\d{0,3})d(\d{1,4})(?:(kh|kl)(\d{1,3}))?|(\d{1,5}))", re.I)


def roll_expression(expr: str, mode: str = "normal") -> dict:
    """Roll e.g. '2d6+3', 'd20', '4d6kh3', '1d100-5'. Advantage/disadvantage
    turn the first single d20 into 2d20 keep highest/lowest."""
    if re.search(r"[\dd]\s+[\dd]", expr.lower()):
        raise HTTPException(400, "Zwischen Würfeln fehlt + oder -.")
    text = re.sub(r"\s+", "", expr.lower())
    if not text or len(text) > 60:
        raise HTTPException(400, "Würfelformel ungültig.")
    pos, total, parts, dice_count, adv_used = 0, 0, [], 0, False
    while pos < len(text):
        m = DICE_TERM.match(text, pos)
        if not m or m.end() == pos:
            raise HTTPException(400, "Würfelformel ungültig. Beispiel: 1d20+5 oder 2d6+3")
        sign = -1 if m.group(1) == "-" else 1
        if pos and not m.group(1):
            raise HTTPException(400, "Zwischen Würfeln fehlt + oder -.")
        if m.group(6) is not None:
            value = int(m.group(6))
            total += sign * value
            parts.append({"type": "mod", "value": sign * value})
        else:
            count = int(m.group(2) or 1)
            sides = int(m.group(3))
            if not 1 <= count <= 100 or not 2 <= sides <= 1000:
                raise HTTPException(400, "Zu viele Würfel oder unmögliche Würfelseiten.")
            dice_count += count
            if dice_count > 200:
                raise HTTPException(400, "Höchstens 200 Würfel pro Wurf.")
            keep_mode, keep = m.group(4), int(m.group(5)) if m.group(5) else None
            if mode in ("adv", "dis") and not adv_used and sides == 20 and count == 1 and not keep_mode:
                count, keep_mode, keep, adv_used = 2, "kh" if mode == "adv" else "kl", 1, True
            rolls = [secrets.randbelow(sides) + 1 for _ in range(count)]
            kept = list(range(count))
            if keep_mode:
                keep = max(1, min(keep or 1, count))
                order = sorted(range(count), key=lambda i: rolls[i], reverse=keep_mode == "kh")
                kept = sorted(order[:keep])
            subtotal = sum(rolls[i] for i in kept)
            total += sign * subtotal
            parts.append({"type": "dice", "sides": sides, "rolls": rolls, "kept": kept, "sign": sign, "subtotal": sign * subtotal})
        pos = m.end()
    d20 = [p for p in parts if p["type"] == "dice" and p["sides"] == 20]
    natural = None
    if len(d20) == 1 and len(d20[0]["kept"]) == 1:
        natural = d20[0]["rolls"][d20[0]["kept"][0]]
    return {"expr": expr.strip()[:60], "total": total, "parts": parts, "mode": mode if adv_used else "normal",
            "crit": natural == 20, "fumble": natural == 1}


# ---------------------------------------------------------------- models

class Abilities(BaseModel):
    model_config = ConfigDict(extra="forbid")
    str: builtins.int = Field(10, ge=1, le=30)
    dex: builtins.int = Field(10, ge=1, le=30)
    con: builtins.int = Field(10, ge=1, le=30)
    int: builtins.int = Field(10, ge=1, le=30)
    wis: builtins.int = Field(10, ge=1, le=30)
    cha: builtins.int = Field(10, ge=1, le=30)


class Character(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=40)
    species: str = Field("Mensch", max_length=40)
    char_class: str = Field("Kämpfer", max_length=40)
    subclass: str = Field("", max_length=60)
    level: int = Field(1, ge=1, le=20)
    background: str = Field("", max_length=60)
    alignment: str = Field("", max_length=40)
    abilities: Abilities = Abilities()
    max_hp: int = Field(10, ge=1, le=999)
    hp: int = Field(10, ge=0, le=999)
    temp_hp: int = Field(0, ge=0, le=999)
    ac: int = Field(10, ge=1, le=40)
    speed: int = Field(30, ge=0, le=200)
    skills: list[str] = Field(default_factory=list, max_length=18)
    saves: list[str] = Field(default_factory=list, max_length=6)
    inventory: str = Field("", max_length=3000)
    features: str = Field("", max_length=4000)
    spells: str = Field("", max_length=4000)
    notes: str = Field("", max_length=3000)
    color: str = Field("#b56cff", pattern=COLOR_RE)
    avatar_url: str = Field("", max_length=500)
    gold: int = Field(0, ge=0, le=10_000_000)
    death_saves: dict[str, int] = Field(default_factory=lambda: {"ok": 0, "fail": 0})


class CreatureIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=40)
    max_hp: int = Field(10, ge=1, le=5000)
    ac: int = Field(10, ge=1, le=40)
    init_bonus: int = Field(0, ge=-10, le=20)
    color: str = Field("#ff4f6d", pattern=COLOR_RE)
    size: Literal[1, 2, 3, 4] = 1
    hidden_hp: bool = True
    visible: bool = True
    notes: str = Field("", max_length=2000)
    art: str = Field("", pattern=r"^[a-z0-9-]{0,32}$")
    image_url: str = Field("", max_length=500)
    count: int = Field(1, ge=1, le=12)

    @field_validator("image_url")
    @classmethod
    def https_only(cls, value: str) -> str:
        value = value.strip()
        if value and not value.startswith("https://"):
            raise ValueError("Kreaturenbilder bitte als https-Link.")
        return value


class Action(BaseModel):
    model_config = ConfigDict(extra="allow")
    type: str = Field(max_length=40)


# ---------------------------------------------------------------- helpers

def modifier(score: int) -> int:
    return (int(score) - 10) // 2


def new_state(name: str, dm: str) -> dict:
    return {"name": name, "dm": dm, "locked": False, "members": {dm: {"role": "dm", "joined": time.time()}},
            "characters": {}, "creatures": {}, "map": {"cols": 24, "rows": 16, "theme": "dungeon", "image_url": ""},
            "scene": {"title": "Die Reise beginnt", "text": ""},
            "initiative": {"order": [], "turn": 0, "round": 0}, "log": [], "seq": 0}


def log(state: dict, kind: str, user: str, text: str, **extra) -> dict:
    state["seq"] = state.get("seq", 0) + 1
    entry = {"id": state["seq"], "t": time.time(), "kind": kind, "user": user, "text": text[:500], **extra}
    state["log"].append(entry)
    del state["log"][:-LOG_KEEP]
    return entry


def role_of(state: dict, username: str) -> str | None:
    member = state["members"].get(username)
    return member["role"] if member else None


def require_member(state: dict, username: str) -> str:
    role = role_of(state, username)
    if not role:
        raise HTTPException(403, "Du sitzt nicht an diesem Tisch.")
    return role


def require_dm(state: dict, username: str) -> None:
    if role_of(state, username) != "dm":
        raise HTTPException(403, "Das darf nur der Dungeon Master.")


def character_of(state: dict, username: str) -> tuple[str, dict] | tuple[None, None]:
    for cid, char in state["characters"].items():
        if char["owner"] == username:
            return cid, char
    return None, None


def entity(state: dict, ref: str) -> dict:
    kind, _, key = ref.partition(":")
    pool = state["characters"] if kind == "c" else state["creatures"] if kind == "m" else None
    if pool is None or key not in pool:
        raise HTTPException(404, "Figur nicht gefunden.")
    return pool[key]


def may_control(state: dict, username: str, ref: str) -> bool:
    if role_of(state, username) == "dm":
        return True
    return ref.startswith("c:") and entity(state, ref).get("owner") == username


def clamp_pos(state: dict, x: Any, y: Any) -> tuple[int, int]:
    try:
        x, y = int(x), int(y)
    except (TypeError, ValueError) as error:
        raise HTTPException(400, "Position ungültig.") from error
    return max(0, min(state["map"]["cols"] - 1, x)), max(0, min(state["map"]["rows"] - 1, y))


def free_spot(state: dict, size: int = 1) -> tuple[int, int]:
    """First spot where a size×size token overlaps no other token."""
    taken = set()
    for pool in (state["characters"], state["creatures"]):
        for e in pool.values():
            n = int(e.get("size", 1) or 1)
            taken.update((e["x"] + dx, e["y"] + dy) for dx in range(n) for dy in range(n))
    cols, rows = state["map"]["cols"], state["map"]["rows"]
    for y in range(1, rows - size + 1):
        for x in range(1, cols - size + 1):
            if all((x + dx, y + dy) not in taken for dx in range(size) for dy in range(size)):
                return x, y
    return 0, 0


def health_word(hp: int, max_hp: int) -> str:
    if hp <= 0:
        return "Besiegt"
    ratio = hp / max(1, max_hp)
    return "Unverletzt" if ratio >= 1 else "Angeschlagen" if ratio > .5 else "Schwer verletzt" if ratio > .25 else "Kurz vor dem Ende"


def view(state: dict, version: int, username: str) -> dict:
    role = role_of(state, username)
    dm = role == "dm"
    creatures = {}
    for cid, c in state["creatures"].items():
        if not dm and not c.get("visible", True):
            continue
        shown = dict(c)
        if not dm and c.get("hidden_hp"):
            bucket = 0 if c["hp"] <= 0 else max(1, round(c["hp"] / max(1, c["max_hp"]) * 4))
            shown.update(hp=None, max_hp=None, ac=None, notes="", hp_pct=bucket * 25, health=health_word(c["hp"], c["max_hp"]))
        else:
            shown["hp_pct"] = round(max(0, c["hp"]) / max(1, c["max_hp"]) * 100)
        if not dm:
            shown.pop("notes", None)
        creatures[cid] = shown
    visible_refs = {f"m:{k}" for k in creatures} | {f"c:{k}" for k in state["characters"]}
    entries = []
    for e in state["log"]:
        if e.get("secret") and not dm:
            continue
        if e.get("private") and not dm and e["user"] != username:
            continue
        entries.append(e)
    initiative = dict(state["initiative"])
    initiative["order"] = [o for o in initiative["order"] if o["ref"] in visible_refs]
    return {"version": version, "code": state["code"], "name": state["name"], "dm": state["dm"], "locked": state.get("locked", False),
            "me": username, "role": role, "members": state["members"], "characters": state["characters"], "creatures": creatures,
            "map": state["map"], "scene": state["scene"], "initiative": initiative, "log": entries[-150:]}


# ---------------------------------------------------------------- actions

def apply(state: dict, username: str, a: dict) -> None:
    kind = a.get("type")
    role = require_member(state, username)
    dm = role == "dm"

    if kind == "character.save":
        sheet = Character.model_validate(a.get("character") or {}).model_dump()
        sheet["hp"] = min(sheet["hp"], sheet["max_hp"])
        target = a.get("id")
        if target:
            if target not in state["characters"]:
                raise HTTPException(404, "Charakter nicht gefunden.")
            current = state["characters"][target]
            if not dm and current["owner"] != username:
                raise HTTPException(403, "Das ist nicht dein Charakter.")
            current.update(sheet)
            return
        if role == "spectator":
            raise HTTPException(403, "Zuschauer haben keinen Charakter. Tritt als Spieler bei.")
        if not dm and character_of(state, username)[0]:
            raise HTTPException(409, "Du hast an diesem Tisch schon einen Charakter.")
        cid = secrets.token_hex(4)
        x, y = free_spot(state)
        state["characters"][cid] = {**sheet, "id": cid, "owner": username, "x": x, "y": y, "conditions": []}
        log(state, "system", username, f"{sheet['name']} ({sheet['species']} {sheet['char_class']} {sheet['level']}) betritt den Tisch.")
        return

    if kind == "character.delete":
        cid = str(a.get("id", ""))
        char = state["characters"].get(cid)
        if not char or (not dm and char["owner"] != username):
            raise HTTPException(403, "Das ist nicht dein Charakter.")
        del state["characters"][cid]
        state["initiative"]["order"] = [o for o in state["initiative"]["order"] if o["ref"] != f"c:{cid}"]
        return

    if kind == "token.move":
        ref = str(a.get("ref", ""))
        if not may_control(state, username, ref):
            raise HTTPException(403, "Diese Figur darfst du nicht bewegen.")
        ent = entity(state, ref)
        ent["x"], ent["y"] = clamp_pos(state, a.get("x"), a.get("y"))
        return

    if kind == "hp.change":
        ref = str(a.get("ref", ""))
        if not may_control(state, username, ref):
            raise HTTPException(403, "Diese Lebenspunkte darfst du nicht ändern.")
        ent = entity(state, ref)
        try:
            delta = int(a.get("delta", 0))
        except (TypeError, ValueError) as error:
            raise HTTPException(400, "Wert ungültig.") from error
        delta = max(-5000, min(5000, delta))
        if delta < 0 and ent.get("temp_hp"):
            absorbed = min(ent["temp_hp"], -delta)
            ent["temp_hp"] -= absorbed
            delta += absorbed
        before = ent["hp"]
        ent["hp"] = max(0, min(ent["max_hp"], ent["hp"] + delta))
        name = ent["name"]
        if ref.startswith("m:") and ent.get("hidden_hp"):
            # Players learn that something hit, not the exact numbers.
            log(state, "system", username, f"{name} {'erleidet Schaden' if delta < 0 else 'wird geheilt'}." + (" Besiegt!" if ent["hp"] == 0 and before > 0 else ""))
            log(state, "system", username, f"{name}: {before} → {ent['hp']} TP ({'+' if delta >= 0 else ''}{delta})", secret=True)
        else:
            log(state, "system", username, f"{name}: {before} → {ent['hp']} TP ({'+' if delta >= 0 else ''}{delta})" + (" — bewusstlos!" if ent["hp"] == 0 and before > 0 and ref.startswith("c:") else ""))
        return

    if kind == "condition.toggle":
        ref = str(a.get("ref", ""))
        cond = str(a.get("condition", ""))
        if cond not in CONDITIONS:
            raise HTTPException(400, "Unbekannter Zustand.")
        if not may_control(state, username, ref):
            raise HTTPException(403, "Diese Figur darfst du nicht ändern.")
        ent = entity(state, ref)
        conds = ent.setdefault("conditions", [])
        if cond in conds:
            conds.remove(cond)
        else:
            conds.append(cond)
        return

    if kind == "roll":
        mode = a.get("mode") if a.get("mode") in ("adv", "dis") else "normal"
        result = roll_expression(str(a.get("expr", "")), mode)
        label = str(a.get("label", ""))[:60]
        secret = bool(a.get("secret")) and dm
        private = bool(a.get("private")) and not secret
        who = str(a.get("as", ""))[:40] or username
        log(state, "roll", username, label or result["expr"], roll=result, label=label, as_name=who, secret=secret, private=private)
        return

    if kind == "chat.say":
        text = str(a.get("text", "")).strip()
        if not text:
            raise HTTPException(400, "Nachricht ist leer.")
        log(state, "chat", username, text[:500], ic=bool(a.get("in_character")), as_name=str(a.get("as", ""))[:40])
        return

    # ---- Dungeon Master only from here on
    require_dm(state, username)

    if kind == "creature.add":
        body = CreatureIn.model_validate({k: v for k, v in a.items() if k != "type"})
        if len(state["creatures"]) + body.count > MAX_CREATURES:
            raise HTTPException(400, f"Höchstens {MAX_CREATURES} Kreaturen pro Tisch.")
        same = sum(1 for c in state["creatures"].values() if c["base"] == body.name)
        for i in range(body.count):
            cid = secrets.token_hex(4)
            x, y = free_spot(state, body.size)
            label = body.name if body.count == 1 and same == 0 else f"{body.name} {same + i + 1}"
            state["creatures"][cid] = {"id": cid, "name": label, "base": body.name, "hp": body.max_hp, "max_hp": body.max_hp, "ac": body.ac,
                                       "init_bonus": body.init_bonus, "color": body.color, "size": body.size, "hidden_hp": body.hidden_hp,
                                       "visible": body.visible, "notes": body.notes, "art": body.art, "image_url": body.image_url, "x": x, "y": y, "conditions": []}
        log(state, "system", username, f"{body.count}× {body.name} {'erscheint' if body.count == 1 else 'erscheinen'}." if body.visible else f"{body.count}× {body.name} versteckt platziert.", secret=not body.visible)
        return

    if kind == "creature.update":
        cid = str(a.get("id", ""))
        if cid not in state["creatures"]:
            raise HTTPException(404, "Kreatur nicht gefunden.")
        c = state["creatures"][cid]
        fields = a.get("fields") or {}
        merged = CreatureIn.model_validate({**{k: c.get(k, "") for k in ("name", "max_hp", "ac", "init_bonus", "color", "size", "hidden_hp", "visible", "notes", "art", "image_url")},
                                            **{k: v for k, v in fields.items() if k in CreatureIn.model_fields and k != "count"}})
        was_visible = c["visible"]
        c.update({k: v for k, v in merged.model_dump().items() if k != "count"})
        if "hp" in fields:
            c["hp"] = max(0, min(c["max_hp"], int(fields["hp"])))
        c["hp"] = min(c["hp"], c["max_hp"])
        if c["visible"] and not was_visible:
            log(state, "system", username, f"{c['name']} taucht auf!")
        return

    if kind == "creature.remove":
        cid = str(a.get("id", ""))
        if state["creatures"].pop(cid, None) is None:
            raise HTTPException(404, "Kreatur nicht gefunden.")
        state["initiative"]["order"] = [o for o in state["initiative"]["order"] if o["ref"] != f"m:{cid}"]
        return

    if kind == "initiative.roll":
        order = []
        for cid, ch in state["characters"].items():
            r = roll_expression(f"1d20{modifier(ch['abilities']['dex']):+d}")
            order.append({"ref": f"c:{cid}", "value": r["total"], "tie": ch["abilities"]["dex"]})
        for cid, cr in state["creatures"].items():
            if cr["hp"] > 0 and cr.get("visible", True):
                r = roll_expression(f"1d20{cr['init_bonus']:+d}")
                order.append({"ref": f"m:{cid}", "value": r["total"], "tie": 10 + cr["init_bonus"] * 2})
        order.sort(key=lambda o: (o["value"], o["tie"], secrets.randbelow(1000)), reverse=True)
        state["initiative"] = {"order": order, "turn": 0, "round": 1}
        first = entity(state, order[0]["ref"])["name"] if order else "niemand"
        log(state, "system", username, f"Initiative gewürfelt! Runde 1 — {first} beginnt.")
        return

    if kind == "initiative.set":
        ref, value = str(a.get("ref", "")), int(a.get("value", 0))
        entity(state, ref)
        order = [o for o in state["initiative"]["order"] if o["ref"] != ref]
        order.append({"ref": ref, "value": max(-20, min(60, value)), "tie": 0})
        order.sort(key=lambda o: (o["value"], o["tie"]), reverse=True)
        state["initiative"]["order"] = order
        state["initiative"]["round"] = max(1, state["initiative"]["round"])
        return

    if kind == "turn.next":
        ini = state["initiative"]
        if not ini["order"]:
            raise HTTPException(400, "Erst Initiative würfeln.")
        ini["turn"] += 1
        if ini["turn"] >= len(ini["order"]):
            ini["turn"], ini["round"] = 0, ini["round"] + 1
        log(state, "system", username, f"Runde {ini['round']}: {entity(state, ini['order'][ini['turn']]['ref'])['name']} ist am Zug.")
        return

    if kind == "initiative.clear":
        state["initiative"] = {"order": [], "turn": 0, "round": 0}
        log(state, "system", username, "Kampf beendet.")
        return

    if kind == "map.set":
        cols, rows = int(a.get("cols", state["map"]["cols"])), int(a.get("rows", state["map"]["rows"]))
        theme = a.get("theme", state["map"]["theme"])
        if theme not in ("dungeon", "forest", "tavern", "cave", "castle", "plain"):
            raise HTTPException(400, "Unbekanntes Kartenthema.")
        image = str(a.get("image_url", state["map"].get("image_url", "")))[:500]
        if image and not image.startswith("https://"):
            raise HTTPException(400, "Kartenbilder bitte als https-Link.")
        state["map"] = {"cols": max(8, min(40, cols)), "rows": max(6, min(30, rows)), "theme": theme, "image_url": image}
        for pool in (state["characters"], state["creatures"]):
            for e in pool.values():
                e["x"], e["y"] = clamp_pos(state, e["x"], e["y"])
        return

    if kind == "scene.set":
        state["scene"] = {"title": str(a.get("title", ""))[:80], "text": str(a.get("text", ""))[:2000]}
        log(state, "scene", username, state["scene"]["title"] or "Neue Szene", body=state["scene"]["text"])
        return

    if kind == "room.update":
        name = str(a.get("name", state["name"])).strip()[:60]
        if name:
            state["name"] = name
        state["locked"] = bool(a.get("locked", state.get("locked")))
        return

    if kind == "member.kick":
        who = str(a.get("username", ""))
        if who == state["dm"] or who not in state["members"]:
            raise HTTPException(400, "Dieses Mitglied kann nicht entfernt werden.")
        del state["members"][who]
        for cid in [k for k, c in state["characters"].items() if c["owner"] == who]:
            del state["characters"][cid]
        state["initiative"]["order"] = [o for o in state["initiative"]["order"] if o["ref"][2:] in state["characters"] or o["ref"].startswith("m:")]
        log(state, "system", username, f"{who} hat den Tisch verlassen.")
        return

    raise HTTPException(400, "Unbekannte Aktion.")


# ---------------------------------------------------------------- routes

class RoomCreate(BaseModel):
    name: str = Field(min_length=2, max_length=60)


class JoinRequest(BaseModel):
    role: Literal["player", "spectator"] = "player"


def is_site_admin(user: dict) -> bool:
    from .main import user_role  # late import: main imports this module
    return user_role(str(user.get("username") or ""), user.get("role")) == "admin"


@router.get("/rooms")
def list_rooms(user: dict = Depends(current_user)):
    return get_store().listing(str(user["username"]), is_site_admin(user))


@router.post("/rooms")
def create_room(body: RoomCreate, request: Request, user: dict = Depends(current_user)):
    ratelimit.hit(request, "dnd-create", 10, 3600)
    username = str(user["username"])
    state = new_state(body.name.strip(), username)
    log(state, "system", username, f"{username} eröffnet den Tisch als Dungeon Master.")
    code = get_store().create(state)
    return {"code": code}


@router.post("/rooms/{code}/join")
def join_room(code: str, body: JoinRequest, user: dict = Depends(current_user)):
    username = str(user["username"])

    def change(state):
        if username in state["members"]:
            return
        if state.get("locked"):
            raise HTTPException(403, "Der Dungeon Master hat den Tisch geschlossen.")
        if body.role == "player" and sum(1 for m in state["members"].values() if m["role"] == "player") >= MAX_PLAYERS:
            raise HTTPException(409, f"Der Tisch ist voll ({MAX_PLAYERS} Spieler). Du kannst zuschauen.")
        state["members"][username] = {"role": body.role, "joined": time.time()}
        log(state, "system", username, f"{username} setzt sich {'an den Tisch' if body.role == 'player' else 'als Zuschauer dazu'}.")

    state, version = get_store().mutate(code.upper(), change)
    return view(state, version, username)


@router.post("/rooms/{code}/leave")
def leave_room(code: str, user: dict = Depends(current_user)):
    username = str(user["username"])

    def change(state):
        if username == state["dm"]:
            return "delete"
        if username in state["members"]:
            apply(state, state["dm"], {"type": "member.kick", "username": username})

    get_store().mutate(code.upper(), change)
    return {"ok": True}


@router.post("/rooms/{code}/close")
def close_room(code: str, user: dict = Depends(current_user)):
    username = str(user["username"])
    admin = is_site_admin(user)

    def change(state):
        if username != state["dm"] and not admin:
            raise HTTPException(403, "Nur der Dungeon Master oder ein Admin kann diesen Tisch beenden.")
        return "delete"

    get_store().mutate(code.upper(), change)
    return {"ok": True}


@router.get("/rooms/{code}")
def get_room(code: str, since: int = 0, user: dict = Depends(current_user)):
    code = code.upper()
    if since and get_store().version(code) == since:
        return {"unchanged": True, "version": since}
    state, version = get_store().load(code)
    username = str(user["username"])
    require_member(state, username)
    return view(state, version, username)


@router.post("/rooms/{code}/action")
def room_action(code: str, body: Action, request: Request, user: dict = Depends(current_user)):
    ratelimit.hit(request, "dnd-action", 240, 60)
    username = str(user["username"])
    try:
        state, version = get_store().mutate(code.upper(), lambda s: apply(s, username, body.model_dump()))
    except ValidationError as exc:
        first = exc.errors()[0] if exc.errors() else {}
        message = str(first.get("msg", "Ungültige Eingabe.")).removeprefix("Value error, ")
        field = ".".join(str(p) for p in first.get("loc", ()))
        raise HTTPException(422, f"{field}: {message}" if field else message) from None
    return view(state, version, username)
