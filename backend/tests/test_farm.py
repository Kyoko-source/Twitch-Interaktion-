import io
import asyncio
import json
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4
from urllib.parse import urlencode
from concurrent.futures import ThreadPoolExecutor
from fastapi import HTTPException
from app.economy import EconomyStore
from app.farm import FarmStore, CATALOG
from app import farm, main, auth
import test_economy


def recording(seconds=1):
    out=io.BytesIO()
    with wave.open(out,"wb") as clip:
        clip.setnchannels(1);clip.setsampwidth(2);clip.setframerate(16000)
        clip.writeframes(b"\x00\x10"*int(16000*seconds))
    return out.getvalue()


class FarmTests(unittest.TestCase):
    request=staticmethod(test_economy.EconomyTests.request)
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory()
        self.ledger=EconomyStore(Path(self.directory.name)/"farm.sqlite3")
        self.ledger.mark_ready(["alice","bob"])
        self.store=FarmStore(self.ledger)
        self.alice=self.store.get("alice")
        self.animal=self.alice["animals"][0]["id"]

    def tearDown(self):
        main.app.dependency_overrides.clear();self.directory.cleanup()

    def voice(self,username="alice",animal=None):
        return self.store.save_voice(username,recording(),"Meine Stimme",animal or self.animal,False,uuid4().hex)["saved_voice_id"]

    def fund(self,coins):
        with self.ledger.connection(write=True) as db:
            db.execute("UPDATE farms SET coins=? WHERE username='alice'",(coins,))

    def test_one_free_sheep_zero_farm_coins_and_no_chicken_changes(self):
        self.assertEqual((self.alice["coins"],len(self.alice["animals"]),self.alice["animals"][0]["species"]),(0,1,"sheep"))
        self.assertEqual(self.alice["catalog"][0]["price"],40)
        self.store.get("alice")
        self.assertEqual(len(self.store.get("alice")["animals"]),1)
        self.assertEqual(self.ledger.balances()["alice"]["chickens"],0)
        with self.assertRaises(HTTPException):self.store.start("alice",100)

    def test_calls_pay_once_per_real_interval_across_tabs_and_pause(self):
        voice=self.voice();self.store.start("alice",now=100)
        self.assertEqual(self.store.tick("alice",107)["coins"],0)
        tick=self.store.tick("alice",108)
        self.assertEqual(tick["coins"],1);self.assertEqual(tick["events"][0]["voice_id"],voice)
        self.assertEqual(self.store.tick("alice",108)["events"],[])
        self.assertEqual(self.store.tick("alice",115)["coins"],1)
        self.assertEqual(self.store.tick("alice",116)["coins"],2)
        self.store.pause("alice")
        self.assertEqual(self.store.tick("alice",125)["coins"],2)

    def test_expired_session_never_mints_offline_or_catch_up_income(self):
        self.voice();self.store.start("alice",100)
        tick=self.store.tick("alice",10000)
        self.assertFalse(tick["running"]);self.assertEqual(tick["coins"],0);self.assertEqual(tick["events"],[])
        self.store.start("alice",10000)
        self.assertEqual(self.store.tick("alice",10007)["coins"],0)
        self.assertEqual(self.store.tick("alice",10008)["coins"],1)

    def test_buy_is_atomic_idempotent_price_grows_and_wallet_stays_separate(self):
        voice=self.voice();self.fund(100)
        key=uuid4().hex
        bought=self.store.buy("alice","sheep",voice,key,100)
        self.assertEqual((bought["coins"],len(bought["animals"]),bought["catalog"][0]["price"]),(60,2,47))
        repeat=self.store.buy("alice","sheep",voice,key,100)
        self.assertEqual((repeat["coins"],len(repeat["animals"]),repeat["bought_id"]),(60,2,bought["bought_id"]))
        with self.assertRaises(HTTPException) as caught:self.store.buy("alice","chicken",voice,key,100)
        self.assertEqual(caught.exception.status_code,409)
        with self.assertRaises(HTTPException):self.store.buy("alice","cow",voice,uuid4().hex,100)
        self.assertEqual(self.store.get("alice")["coins"],60)
        self.assertEqual(self.ledger.balances()["alice"]["chickens"],0)

    def test_all_six_species_have_real_income_and_capacity_stops_at_100(self):
        voice=self.voice();self.fund(10**10)
        for index in range(99):self.store.buy("alice",CATALOG[index%6]["id"],voice,uuid4().hex,100)
        full=self.store.get("alice");self.assertEqual(len(full["animals"]),100)
        self.assertEqual(len({animal["species"] for animal in full["animals"]}),6)
        with self.assertRaises(HTTPException):self.store.buy("alice","sheep",voice,uuid4().hex,100)
        self.store.start("alice",100)
        # Move all schedules to a shared actual due instant for this accounting test.
        with self.ledger.connection(write=True) as db:db.execute("UPDATE farm_animals SET next_call=108 WHERE username='alice'")
        result=self.store.tick("alice",108)
        expected=sum(next(s["income"] for s in CATALOG if s["id"]==a["species"]) for a in full["animals"])
        self.assertEqual(len(result["events"]),100);self.assertEqual(result["coins"]-full["coins"],expected)

    def test_private_voices_cannot_be_assigned_or_edited_by_other_users(self):
        voice=self.voice();bob=self.store.get("bob");self.fund(100)
        with self.assertRaises(HTTPException):self.store.buy("bob","sheep",voice,uuid4().hex)
        with self.assertRaises(HTTPException):self.store.change_animal("bob",self.animal,"Stolen",None)
        with self.assertRaises(HTTPException):self.store.change_animal("bob",bob["animals"][0]["id"],"Bob",voice)
        with self.assertRaises(HTTPException):self.store.delete_voice("bob",voice)
        self.assertEqual(self.store.get("alice")["voices"][0]["id"],voice)

    def test_voice_save_is_repeat_safe_assigns_all_species_and_deletion_unassigns(self):
        self.fund(100);self.store.buy("alice","sheep",None,uuid4().hex)
        key=uuid4().hex;audio=recording()
        saved=self.store.save_voice("alice",audio,"Baa",self.animal,True,key)
        again=self.store.save_voice("alice",audio,"Baa",self.animal,True,key)
        self.assertEqual(len(again["voices"]),1);self.assertEqual(saved["saved_voice_id"],again["saved_voice_id"])
        self.assertTrue(all(a["voice_id"]==saved["saved_voice_id"] for a in again["animals"]))
        removed=self.store.delete_voice("alice",saved["saved_voice_id"])
        self.assertEqual(removed["voices"],[]);self.assertTrue(all(a["voice_id"] is None for a in removed["animals"]))

    def test_bad_or_oversized_wav_never_persists(self):
        for audio in [b'<script>no audio</script>',recording(5),recording(.01),recording()[:-40]]:
            with self.assertRaises(HTTPException):self.store.save_voice("alice",audio,"Bad",self.animal,False,uuid4().hex)
        self.assertEqual(self.store.get("alice")["voices"],[])

    def test_progress_and_private_blob_persist_when_store_reopens(self):
        voice=self.voice();self.fund(100);self.store.buy("alice","sheep",voice,uuid4().hex)
        reopened=FarmStore(self.ledger)
        self.assertEqual((reopened.get("alice")["coins"],len(reopened.get("alice")["animals"])),(60,2))
        with reopened.ledger.connection() as db:self.assertEqual(bytes(db.execute("SELECT audio FROM farm_voices WHERE id=?",(voice,)).fetchone()[0]),recording())

    def test_http_authentication_and_no_cross_account_progress(self):
        with patch.object(farm,"farm_store",return_value=self.store):
            self.assertEqual(self.request("GET","/api/farm")[0],401)
            main.app.dependency_overrides[auth.current_user]=lambda:{"username":"alice"}
            self.assertEqual(self.request("GET","/api/farm?username=bob")[1]["animals"][0]["id"],self.animal)
            self.assertEqual(self.request("POST","/api/farm/start",{})[0],400)
            voice=self.voice();self.assertEqual(self.request("POST","/api/farm/start",{})[0],200)
            main.app.dependency_overrides[auth.current_user]=lambda:{"username":"bob"}
            self.assertEqual(self.request("GET",f"/api/farm/voices/{voice}")[0],404)
            self.assertEqual(self.request("PATCH",f"/api/farm/animals/{self.animal}",{"name":"Stolen"})[0],404)

    def test_concurrent_tabs_cannot_double_credit_the_same_call(self):
        self.voice();self.store.start("alice",100)
        with ThreadPoolExecutor(max_workers=8) as pool:
            results=list(pool.map(lambda _:self.store.tick("alice",108),range(8)))
        self.assertEqual(sum(len(result["events"]) for result in results),1)
        self.assertEqual(self.store.get("alice")["coins"],1)

    def test_real_binary_upload_route_validates_stream_and_returns_private_playable_wav(self):
        async def request(method,path,body=b"",query=""):
            messages=[]
            async def receive():return {"type":"http.request","body":body,"more_body":False}
            async def send(message):messages.append(message)
            await main.app({"type":"http","asgi":{"version":"3.0"},"http_version":"1.1","method":method,"scheme":"http","path":path,"raw_path":path.encode(),"query_string":query.encode(),"root_path":"","headers":[(b"content-type",b"audio/wav")],"server":("test",80),"client":("test",1)},receive,send)
            return next(message["status"] for message in messages if message["type"]=="http.response.start"),b"".join(message.get("body",b"") for message in messages if message["type"]=="http.response.body")
        main.app.dependency_overrides[auth.current_user]=lambda:{"username":"alice"}
        with patch.object(farm,"farm_store",return_value=self.store):
            query=urlencode({"name":"Meine Stimme","animal_id":self.animal,"request_id":uuid4().hex,"all_species":"false"})
            status,body=asyncio.run(request("POST","/api/farm/voices",recording(),query))
            self.assertEqual(status,200,body)
            voice=json.loads(body)["saved_voice_id"]
            status,body=asyncio.run(request("GET",f"/api/farm/voices/{voice}"))
            self.assertEqual((status,body),(200,recording()))
            self.assertEqual(asyncio.run(request("POST","/api/farm/voices",b"x"*129000,query))[0],413)
