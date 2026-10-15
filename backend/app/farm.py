"""Private, persistent microphone farm. Farm coins never touch Chicken wallets."""
import hashlib
import io
import json
import math
import time
import wave
from functools import lru_cache
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, Field
from .auth import current_user
from .economy import economy

CATALOG = [
    {"id": "sheep", "name": "Schaf", "plural": "Schafe", "income": 1, "interval": 8, "base_price": 40, "art": 0},
    {"id": "chicken", "name": "Huhn", "plural": "Hühner", "income": 2, "interval": 9, "base_price": 110, "art": 1},
    {"id": "duck", "name": "Ente", "plural": "Enten", "income": 4, "interval": 10, "base_price": 280, "art": 2},
    {"id": "pig", "name": "Schwein", "plural": "Schweine", "income": 8, "interval": 11, "base_price": 700, "art": 3},
    {"id": "cow", "name": "Kuh", "plural": "Kühe", "income": 16, "interval": 12, "base_price": 1800, "art": 4},
    {"id": "alpaca", "name": "Alpaka", "plural": "Alpakas", "income": 32, "interval": 13, "base_price": 4500, "art": 5},
]
SPECIES = {entry["id"]: entry for entry in CATALOG}
MAX_VOICE_BYTES = 128044


class FarmStore:
    def __init__(self, ledger):
        self.ledger = ledger
        with ledger.connection() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS farms(username TEXT PRIMARY KEY,coins INTEGER NOT NULL DEFAULT 0 CHECK(coins>=0),earned INTEGER NOT NULL DEFAULT 0,active_until REAL NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS farm_animals(id TEXT PRIMARY KEY,username TEXT NOT NULL,species TEXT NOT NULL,name TEXT NOT NULL,voice_id TEXT,next_call REAL NOT NULL DEFAULT 0,calls INTEGER NOT NULL DEFAULT 0,created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS farm_animals_owner ON farm_animals(username);
                CREATE TABLE IF NOT EXISTS farm_voices(id TEXT PRIMARY KEY,username TEXT NOT NULL,name TEXT NOT NULL,audio BLOB NOT NULL,duration REAL NOT NULL,created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS farm_voices_owner ON farm_voices(username);
                CREATE TABLE IF NOT EXISTS farm_requests(id TEXT PRIMARY KEY,username TEXT NOT NULL,kind TEXT NOT NULL,signature TEXT NOT NULL,result TEXT NOT NULL);
            """)

    @staticmethod
    def ensure(db, username):
        if not db.execute("SELECT 1 FROM farms WHERE username=?", (username,)).fetchone():
            db.execute("INSERT INTO farms(username) VALUES (?)", (username,))
            db.execute("INSERT INTO farm_animals(id,username,species,name,created) VALUES (?,?,?,?,?)", (uuid4().hex,username,"sheep","Schaf 1",time.time()))

    @staticmethod
    def state(db, username, now=None):
        now = time.time() if now is None else now
        farm = dict(db.execute("SELECT coins,earned,active_until FROM farms WHERE username=?", (username,)).fetchone())
        animals = [dict(row) for row in db.execute("SELECT id,species,name,voice_id,next_call,calls FROM farm_animals WHERE username=? ORDER BY created,id", (username,))]
        voices = [dict(row) for row in db.execute("SELECT id,name,duration FROM farm_voices WHERE username=? ORDER BY created DESC", (username,))]
        counts = {entry["id"]: sum(a["species"] == entry["id"] for a in animals) for entry in CATALOG}
        catalog = [{**entry, "owned": counts[entry["id"]], "price": math.ceil(entry["base_price"] * 1.16 ** max(0, counts[entry["id"]] - (1 if entry["id"] == "sheep" else 0)))} for entry in CATALOG]
        return {"coins":farm["coins"],"earned":farm["earned"],"running":farm["active_until"]>now,"animals":animals,"voices":voices,"catalog":catalog,"capacity":100,"server_time":now}

    def get(self, username):
        with self.ledger.connection(write=True) as db:
            self.ensure(db,username)
            return self.state(db,username)

    @staticmethod
    def previous(db, request_id, username, kind, signature):
        row = db.execute("SELECT * FROM farm_requests WHERE id=?", (request_id,)).fetchone()
        if not row:
            return None
        if (row["username"],row["kind"],row["signature"]) != (username,kind,signature):
            raise HTTPException(409,"Diese Anfrage wurde bereits für eine andere Aktion verwendet.")
        return json.loads(row["result"])

    @staticmethod
    def remember(db, request_id, username, kind, signature, result):
        db.execute("INSERT INTO farm_requests VALUES (?,?,?,?,?)", (request_id,username,kind,signature,json.dumps(result)))

    def start(self, username, now=None):
        now = time.time() if now is None else now
        with self.ledger.connection(write=True) as db:
            self.ensure(db,username)
            if not db.execute("SELECT 1 FROM farm_animals WHERE username=? AND voice_id IS NOT NULL", (username,)).fetchone():
                raise HTTPException(400,"Gib zuerst deinem Schaf eine Stimme.")
            farm=db.execute("SELECT active_until FROM farms WHERE username=?",(username,)).fetchone()
            if farm["active_until"] <= now:
                for index,animal in enumerate(db.execute("SELECT id,species FROM farm_animals WHERE username=? ORDER BY created,id",(username,)).fetchall()):
                    interval=SPECIES[animal["species"]]["interval"]
                    # Stagger the first chorus without letting pause/start shorten
                    # an animal's minimum earning interval.
                    db.execute("UPDATE farm_animals SET next_call=? WHERE id=?",(now+interval+1.5*((index*0.61803398875)%1),animal["id"]))
            db.execute("UPDATE farms SET active_until=? WHERE username=?",(now+20,username))
            return self.state(db,username,now)

    def pause(self, username):
        with self.ledger.connection(write=True) as db:
            self.ensure(db,username)
            db.execute("UPDATE farms SET active_until=0 WHERE username=?",(username,))
            return self.state(db,username)

    def tick(self, username, now=None):
        now=time.time() if now is None else now
        with self.ledger.connection(write=True) as db:
            self.ensure(db,username)
            active=db.execute("SELECT active_until FROM farms WHERE username=?",(username,)).fetchone()[0]>now
            events=[]
            if active:
                for animal in db.execute("SELECT * FROM farm_animals WHERE username=? AND voice_id IS NOT NULL AND next_call<=? ORDER BY next_call,id",(username,now)).fetchall():
                    species=SPECIES[animal["species"]]
                    events.append({"id":f"{animal['id']}:{animal['calls']+1}","animal_id":animal["id"],"voice_id":animal["voice_id"],"amount":species["income"]})
                    db.execute("UPDATE farm_animals SET calls=calls+1,next_call=? WHERE id=?",(now+species["interval"],animal["id"]))
                income=sum(event["amount"] for event in events)
                db.execute("UPDATE farms SET coins=coins+?,earned=earned+?,active_until=? WHERE username=?",(income,income,now+20,username))
            return {**self.state(db,username,now),"events":events}

    def buy(self, username, species, voice_id, request_id, now=None):
        now=time.time() if now is None else now
        if species not in SPECIES:
            raise HTTPException(400,"Unbekannte Tierart.")
        signature=json.dumps([species,voice_id])
        with self.ledger.connection(write=True) as db:
            self.ensure(db,username)
            previous=self.previous(db,request_id,username,"buy",signature)
            if previous is not None:
                return {**self.state(db,username,now),"bought_id":previous["animal_id"]}
            state=self.state(db,username,now)
            if len(state["animals"])>=100:
                raise HTTPException(400,"Deine Weide ist mit 100 Tieren voll.")
            if voice_id and not db.execute("SELECT 1 FROM farm_voices WHERE id=? AND username=?",(voice_id,username)).fetchone():
                raise HTTPException(404,"Stimme nicht gefunden.")
            item=next(item for item in state["catalog"] if item["id"]==species)
            if state["coins"]<item["price"]:
                raise HTTPException(400,"Dafür fehlen dir noch Farm-Coins.")
            animal_id=uuid4().hex
            db.execute("UPDATE farms SET coins=coins-? WHERE username=?",(item["price"],username))
            db.execute("INSERT INTO farm_animals(id,username,species,name,voice_id,next_call,created) VALUES (?,?,?,?,?,?,?)",(animal_id,username,species,f"{item['name']} {item['owned']+1}",voice_id,now+item["interval"],now))
            self.remember(db,request_id,username,"buy",signature,{"animal_id":animal_id})
            return {**self.state(db,username,now),"bought_id":animal_id}

    def save_voice(self, username, audio, name, animal_id, all_species, request_id):
        try:
            with wave.open(io.BytesIO(audio),"rb") as clip:
                if clip.getnchannels()!=1 or clip.getsampwidth()!=2 or clip.getframerate()!=16000 or clip.getcomptype()!="NONE":
                    raise ValueError()
                frames=clip.getnframes()
                if not 1600<=frames<=64000 or len(clip.readframes(frames))!=frames*2:
                    raise ValueError()
                duration=frames/16000
        except (wave.Error,EOFError,ValueError):
            raise HTTPException(400,"Bitte eine gültige Aufnahme von 0,1 bis 4 Sekunden speichern.")
        signature=hashlib.sha256(audio+json.dumps([name,animal_id,all_species]).encode()).hexdigest()
        with self.ledger.connection(write=True) as db:
            self.ensure(db,username)
            previous=self.previous(db,request_id,username,"voice",signature)
            if previous is not None:
                return {**self.state(db,username),"saved_voice_id":previous["voice_id"]}
            animal=db.execute("SELECT species FROM farm_animals WHERE id=? AND username=?",(animal_id,username)).fetchone()
            if not animal:
                raise HTTPException(404,"Tier nicht gefunden.")
            if db.execute("SELECT COUNT(*) FROM farm_voices WHERE username=?",(username,)).fetchone()[0]>=100:
                raise HTTPException(400,"Du hast bereits 100 Stimmen. Lösche zuerst eine alte Aufnahme.")
            voice_id=uuid4().hex
            db.execute("INSERT INTO farm_voices VALUES (?,?,?,?,?,?)",(voice_id,username,name,audio,duration,time.time()))
            if all_species:
                db.execute("UPDATE farm_animals SET voice_id=? WHERE username=? AND species=?",(voice_id,username,animal["species"]))
            else:
                db.execute("UPDATE farm_animals SET voice_id=? WHERE id=?",(voice_id,animal_id))
            self.remember(db,request_id,username,"voice",signature,{"voice_id":voice_id})
            return {**self.state(db,username),"saved_voice_id":voice_id}

    def change_animal(self, username, animal_id, name, voice_id, all_species=False):
        with self.ledger.connection(write=True) as db:
            self.ensure(db,username)
            animal=db.execute("SELECT species FROM farm_animals WHERE id=? AND username=?",(animal_id,username)).fetchone()
            if not animal:
                raise HTTPException(404,"Tier nicht gefunden.")
            if voice_id and not db.execute("SELECT 1 FROM farm_voices WHERE id=? AND username=?",(voice_id,username)).fetchone():
                raise HTTPException(404,"Stimme nicht gefunden.")
            db.execute("UPDATE farm_animals SET name=?,voice_id=? WHERE id=?",(name,voice_id,animal_id))
            if all_species:
                db.execute("UPDATE farm_animals SET voice_id=? WHERE username=? AND species=?",(voice_id,username,animal["species"]))
            return self.state(db,username)

    def delete_voice(self, username, voice_id):
        with self.ledger.connection(write=True) as db:
            if not db.execute("SELECT 1 FROM farm_voices WHERE id=? AND username=?",(voice_id,username)).fetchone():
                raise HTTPException(404,"Stimme nicht gefunden.")
            db.execute("UPDATE farm_animals SET voice_id=NULL WHERE username=? AND voice_id=?",(username,voice_id))
            db.execute("DELETE FROM farm_voices WHERE id=? AND username=?",(voice_id,username))
            return self.state(db,username)


@lru_cache
def farm_store():
    return FarmStore(economy())


router=APIRouter(prefix="/api/farm",tags=["farm"])
class Purchase(BaseModel):
    species: str
    voice_id: str | None = None
    request_id: str = Field(min_length=16,max_length=64,pattern=r"^[a-zA-Z0-9-]+$")

class AnimalUpdate(BaseModel):
    name: str = Field(min_length=1,max_length=40)
    voice_id: str | None = None
    all_species: bool = False

class VoiceParams(BaseModel):
    name: str = Field(min_length=1,max_length=40)
    animal_id: str = Field(min_length=32,max_length=32,pattern=r"^[a-f0-9]+$")
    all_species: bool = False
    request_id: str = Field(min_length=16,max_length=64,pattern=r"^[a-zA-Z0-9-]+$")

@router.get("")
def farm(user=Depends(current_user)):
    return farm_store().get(str(user["username"]))

@router.post("/start")
def start(user=Depends(current_user)):
    return farm_store().start(str(user["username"]))

@router.post("/pause")
def pause(user=Depends(current_user)):
    return farm_store().pause(str(user["username"]))

@router.post("/tick")
def tick(user=Depends(current_user)):
    return farm_store().tick(str(user["username"]))

@router.post("/buy")
def buy(payload: Purchase,user=Depends(current_user)):
    return farm_store().buy(str(user["username"]),payload.species,payload.voice_id,payload.request_id)

@router.patch("/animals/{animal_id}")
def change_animal(animal_id: str,payload: AnimalUpdate,user=Depends(current_user)):
    return farm_store().change_animal(str(user["username"]),animal_id,payload.name.strip() or "Mein Tier",payload.voice_id,payload.all_species)

@router.post("/voices")
async def voice(request: Request,params: VoiceParams=Depends(),user=Depends(current_user)):
    chunks=[]; size=0
    async for chunk in request.stream():
        size+=len(chunk)
        if size>MAX_VOICE_BYTES:
            raise HTTPException(413,"Die Aufnahme ist zu groß. Maximal 4 Sekunden.")
        chunks.append(chunk)
    return farm_store().save_voice(str(user["username"]),b"".join(chunks),params.name.strip() or "Meine Stimme",params.animal_id,params.all_species,params.request_id)

@router.get("/voices/{voice_id}")
def get_voice(voice_id: str,user=Depends(current_user)):
    with farm_store().ledger.connection() as db:
        row=db.execute("SELECT audio FROM farm_voices WHERE id=? AND username=?",(voice_id,str(user["username"]))).fetchone()
        if not row:
            raise HTTPException(404,"Stimme nicht gefunden.")
        return Response(bytes(row["audio"]),media_type="audio/wav",headers={"Cache-Control":"no-store","X-Content-Type-Options":"nosniff"})

@router.delete("/voices/{voice_id}")
def delete_voice(voice_id: str,user=Depends(current_user)):
    return farm_store().delete_voice(str(user["username"]),voice_id)
