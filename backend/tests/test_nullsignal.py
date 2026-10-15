import asyncio
import copy
import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from fastapi import HTTPException
from app.economy import EconomyStore
from app.nullsignal import NullsignalStore, GRACE
from app.nullsignal_puzzles import generate, apply_action, MISSIONS
from app import main, auth, nullsignal


def solution(module, manual, facts):
    """Solve only from the host's visible facts and expert's public instructions."""
    kind, data, rules = module["kind"], module["data"], manual["manual"]
    if kind == "wires":
        wires, p, s = data["wires"], rules["priority"], rules["secondary"]
        if len(wires) >= 5 and wires.count(p) >= 2:
            target = len(wires)-1-wires[::-1].index(p)
        elif int(facts["serial"][-1]) % 2 and s in wires:
            target = wires.index(s)
        elif "red" not in wires:
            target = 1
        else:
            target = len(wires)-1
        return [("cut", target)]
    if kind == "glyphs":
        columns = [column for column in rules["columns"] if set(data["keys"]).issubset(column)]
        assert len(columns) == 1
        return [("press", data["keys"].index(key)) for key in columns[0] if key in data["keys"]]
    if kind == "frequency":
        channel = next(row["frequency"] for row in rules["channels"] if row["pattern"] == data["pattern"])
        return [("tune", data["channels"].index(channel)), ("submit", None)]
    if kind == "sequence":
        positions = []
        for step, display in enumerate(data["displays"]):
            rule = rules["stages"][step][display-1]
            if rule["rule"] == "position":
                position = rule["value"]-1
            elif rule["rule"] == "label":
                position = data["keys"].index(rule["value"])
            else:
                position = positions[rule["value"]-1]
            positions.append(position)
        return [("press", position) for position in positions]
    if kind == "relays":
        target = next(row for row in rules["rows"] if row["pattern"] == data["pattern"])[f"v{facts['voltage']}"]
        return [("toggle", i) for i in range(3) if data["switches"][i] != target[i]]+[("submit", None)]
    if kind == "sliders":
        target = next(row["values"] for row in rules["rows"] if row["mark"] == data["mark"])
        if data["polarity"] != "+":
            target = [4-value for value in target]
        return [("slide", [i, value]) for i, value in enumerate(target)]+[("submit", None)]
    if kind == "pipes":
        cells = rules["north" if facts["coolant"] == "KALT" else "south"]
        route = [(ord(cell[0])-65, int(cell[1])-1) for cell in cells]
        actions = []
        for step, (x, y) in enumerate(route):
            neighbours = [(-1, y) if step == 0 else route[step-1], (3, y) if step == len(route)-1 else route[step+1]]
            target = 0
            for nx, ny in neighbours:
                target |= {(-1, 0): 8, (1, 0): 2, (0, -1): 1, (0, 1): 4}[(nx-x, ny-y)]
            index = y*3+x
            turn = data["rotations"][index]
            for extra in range(4):
                n = (turn+extra) % 4
                mask = data["tiles"][index]
                rotated = ((mask << n) | (mask >> (4-n))) & 15
                if rotated == target:
                    actions += [("rotate", index)]*extra
                    break
            else:
                raise AssertionError("Manual route cannot be built")
        return actions+[("submit", None)]
    if kind == "vectors":
        a, b, c = data["numbers"]
        s = int(facts["serial"][-1])
        w = rules["weights"]
        code = [w[0]*a+b, w[1]*b+c, w[2]*c+a, w[3]*s+b]
        return [("digit", number % 10) for number in code]+[("submit", None)]
    raise AssertionError(kind)


class NullsignalTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.ledger = EconomyStore(Path(self.directory.name)/"nullsignal.sqlite3")
        self.ledger.mark_ready(["alice", "bob"])
        self.store = NullsignalStore(self.ledger)
        self.now = 100000
        self.host = self.store.create("alice", "blackout", self.now)
        self.id = self.host["room_id"]

    def tearDown(self):
        main.app.dependency_overrides.clear()
        self.directory.cleanup()

    def join(self):
        expert = self.store.join(self.id, self.host["invite_token"], "Guest", now=self.now)
        self.token = expert["guest_token"]
        return expert

    def start(self):
        self.join()
        self.store.ready(self.id, self.token, True, self.now)
        self.host = self.store.control(self.id, "alice", "start", now=self.now)

    def touch(self, now):
        self.store.get(self.id, "host", "alice", now)
        return self.store.get(self.id, "expert", self.token, now)

    def act(self, module, operation, value=None, key=None, now=None, round_id=None):
        self.host = self.store.action(self.id, "alice", key or uuid4().hex, round_id or self.host["round_id"], module, operation, value, now or self.now)
        return self.host

    def defuse(self, seconds=20):
        for t in range(5, seconds+1, 5):
            self.touch(self.now+t)
        expert = self.store.get(self.id, "expert", self.token, self.now+seconds)
        for visible in copy.deepcopy(self.host["bomb"]["modules"]):
            instructions = next(m for m in expert["manual"] if m["id"] == visible["id"])
            for operation, value in solution(visible, instructions, self.host["bomb"]):
                self.act(visible["id"], operation, value, now=self.now+seconds)
        return self.host

    def test_every_module_is_solvable_from_manual_across_100_seeds(self):
        for seed in range(100):
            bomb = generate("blackout", seed)
            for module in bomb["modules"]:
                with self.subTest(seed=seed, kind=module["kind"]):
                    visible = {key: copy.deepcopy(module[key]) for key in ["id", "kind", "data"]}
                    steps = solution(visible, {"manual": module["manual"]}, bomb)
                    for operation, value in steps:
                        self.assertNotEqual(apply_action(module, operation, value), "bad")
                    self.assertTrue(module["solved"])

    def test_guest_without_account_gets_only_manual_host_never_gets_rules_or_answers(self):
        expert = self.join()
        self.assertNotIn("bomb", expert)
        for module in expert["manual"]:
            self.assertEqual(set(module), {"id", "kind", "name", "manual", "solved"})
        for module in self.host["bomb"]["modules"]:
            self.assertEqual(set(module), {"id", "kind", "name", "data", "solved", "progress"})
        for field in ["answer", "guest_hash", "invite_token", "wallet"]:
            self.assertNotIn(field, json.dumps(expert))
        self.assertNotIn(self.host["bomb"]["serial"], json.dumps(expert))
        self.assertEqual(self.ledger.balances()["alice"]["chickens"], 0)

    def test_only_owner_and_claimed_guest_can_read_role_state(self):
        self.join()
        for role, credential, code in [("host", "bob", 404), ("expert", None, 401), ("expert", "wrong", 401)]:
            with self.assertRaises(HTTPException) as caught:
                self.store.get(self.id, role, credential, self.now)
            self.assertEqual(caught.exception.status_code, code)

    def test_creation_retries_and_lost_guest_join_response_do_not_create_extra_slots(self):
        key=uuid4().hex
        first=self.store.create("bob","contact",self.now,request_id=key)
        second=self.store.create("bob","contact",self.now+1,request_id=key)
        self.assertEqual(first["room_id"],second["room_id"])
        with self.assertRaises(HTTPException):
            self.store.create("bob","incident",self.now+1,request_id=key)
        credential=uuid4().hex+uuid4().hex
        joined=self.store.join(self.id,self.host["invite_token"],"Guest",credential,self.now)
        recovered=self.store.join(self.id,self.host["invite_token"],"Guest",credential,self.now+1)
        self.assertEqual(joined["guest_token"],credential)
        self.assertEqual(recovered["guest_token"],credential)

    def test_single_guest_slot_is_atomic_and_rejoin_requires_existing_token(self):
        def attempt(index):
            try:
                return self.store.join(self.id, self.host["invite_token"], f"Guest {index}", now=self.now)
            except HTTPException as error:
                return error.status_code
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(attempt, range(8)))
        winners = [result for result in results if isinstance(result, dict)]
        self.assertEqual(len(winners), 1)
        self.assertEqual(results.count(409), 7)
        token = winners[0]["guest_token"]
        resumed = self.store.join(self.id, self.host["invite_token"], "Changed", token, self.now)
        self.assertEqual(resumed["guest_token"], token)
        self.assertEqual(resumed["expert_name"], winners[0]["expert_name"])

    def test_cannot_start_until_guest_is_ready_and_online(self):
        for joined in [False, True]:
            if joined:
                self.join()
            with self.assertRaises(HTTPException):
                self.store.control(self.id, "alice", "start", now=self.now)
        self.store.ready(self.id, self.token, True, self.now)
        with self.assertRaises(HTTPException):
            self.store.control(self.id, "alice", "start", now=self.now+GRACE)

    def test_duplicate_wrong_action_strikes_once_even_concurrently(self):
        self.start()
        wire = self.host["bomb"]["modules"][0]
        manual = self.store.get(self.id, "expert", self.token, self.now)["manual"][0]
        correct = solution(wire, manual, self.host["bomb"])[0][1]
        wrong = (correct+1) % len(wire["data"]["wires"])
        key = uuid4().hex
        with ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(lambda _:self.store.action(self.id,"alice",key,self.host["round_id"],"wires","cut",wrong,self.now),range(6)))
        host = self.store.get(self.id,"host","alice",self.now)
        self.assertEqual(host["strikes"],1)
        self.assertEqual(host["deadline"],self.now+540-8)
        with self.assertRaises(HTTPException):
            self.act("wires","cut",correct,key=key)

    def test_three_mistakes_explode_and_do_not_pay_or_record_win(self):
        self.start()
        frequency = self.host["bomb"]["modules"][2]
        expert = self.store.get(self.id,"expert",self.token,self.now)
        correct = solution(frequency,expert["manual"][2],self.host["bomb"])[0][1]
        self.act("frequency","tune",(correct+1)%9)
        for _ in range(3):
            self.act("frequency","submit")
        self.assertEqual(self.host["status"],"exploded")
        self.assertEqual(self.host["chickens_awarded"],0)
        self.assertEqual(self.store.records("blackout"),[])
        with self.assertRaises(HTTPException):
            self.act("frequency","tune",correct)

    def test_all_eight_modules_defuse_save_reward_and_alert_once(self):
        self.start()
        result = self.defuse()
        self.assertEqual((result["status"],result["solved"],result["chickens_awarded"]),("defused",8,18))
        self.assertEqual(self.store.get(self.id,"host","alice",self.now+21)["wallet"]["chickens"],18)
        self.assertEqual(len(self.store.records("blackout")),1)
        with self.ledger.connection() as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM runs WHERE game='nullsignal'").fetchone()[0],1)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM alerts WHERE game='nullsignal'").fetchone()[0],1)
        self.assertEqual(self.ledger.wallet_history("alice")["transactions"][0]["label"],"NULLSIGNAL")

    def test_global_daily_chicken_cap_and_minimum_active_time(self):
        with self.ledger.connection(write=True) as db:
            db.execute("INSERT INTO runs(id,username,game,started,completed,score,payload,reward,reward_day) VALUES ('prior','alice','chicken-jump',99900,99999,1,'{}',116,'1970-01-02')")
        self.start()
        self.assertEqual(self.defuse()["chickens_awarded"],4)
        self.store.control(self.id,"alice","reset",now=self.now+21)
        self.now += 21
        self.host = self.store.get(self.id,"host","alice",self.now)
        self.store.ready(self.id,self.token,True,self.now)
        self.host = self.store.control(self.id,"alice","start",now=self.now)
        self.assertEqual(self.defuse(seconds=5)["chickens_awarded"],0)

    def test_connection_loss_pauses_at_grace_instant_and_reconnect_does_not_restart_clock(self):
        self.start()
        self.store.get(self.id,"host","alice",self.now+10)
        paused = self.store.get(self.id,"host","alice",self.now+30)
        self.assertEqual((paused["status"],paused["remaining"],paused["pause_reason"]),("paused",525,"connection"))
        self.assertIsNone(paused["deadline"])
        self.store.get(self.id,"expert",self.token,self.now+40)
        resumed = self.store.control(self.id,"alice","start",now=self.now+40)
        self.assertEqual(resumed["deadline"],self.now+40+525)

    def test_timer_expiry_is_authoritative_when_both_players_are_present(self):
        self.start()
        for offset in range(5,540,5):
            self.touch(self.now+offset)
        result = self.store.get(self.id,"host","alice",self.now+540)
        self.assertEqual(result["status"],"exploded")
        self.assertEqual(result["remaining"],0)

    def test_pause_rematch_replaces_rules_and_rejects_late_previous_round_actions(self):
        self.start()
        old = self.host["round_id"]
        self.store.control(self.id,"alice","pause",now=self.now+3)
        self.host = self.store.control(self.id,"alice","reset","contact",self.now+4)
        self.assertEqual(self.host["status"],"lobby")
        self.assertNotEqual(self.host["round_id"],old)
        self.assertEqual(len(self.host["bomb"]["modules"]),3)
        self.assertFalse(self.host["expert_ready"])
        self.store.ready(self.id,self.token,True,self.now+4)
        self.host = self.store.control(self.id,"alice","start",now=self.now+4)
        with self.assertRaises(HTTPException):
            self.act("wires","cut",0,round_id=old,now=self.now+4)

    def test_replacing_guest_invalidates_both_old_link_and_token(self):
        self.join()
        updated = self.store.control(self.id,"alice","replace",now=self.now)
        self.assertNotEqual(updated["invite_token"],self.host["invite_token"])
        with self.assertRaises(HTTPException):
            self.store.get(self.id,"expert",self.token,self.now)
        with self.assertRaises(HTTPException):
            self.store.join(self.id,self.host["invite_token"],"Another",now=self.now)
        self.assertEqual(self.store.join(self.id,updated["invite_token"],"Another",now=self.now)["expert_name"],"Another")

    def test_persistence_room_expiry_and_creation_cap_preserve_wallets(self):
        self.join()
        reopened = NullsignalStore(self.ledger)
        self.assertEqual(reopened.get(self.id,"expert",self.token,self.now)["expert_name"],"Guest")
        self.store.create("alice","contact",self.now)
        self.store.create("alice","incident",self.now)
        with self.assertRaises(HTTPException):
            self.store.create("alice","contact",self.now)
        with self.assertRaises(HTTPException):
            self.store.get(self.id,"host","alice",self.now+7200)
        fresh = self.store.create("alice","contact",self.now+7201)
        self.assertEqual(fresh["status"],"lobby")
        self.assertEqual(self.ledger.balance("alice")["chickens"],0)

    def test_invalid_operations_do_not_mutate_progress_or_strikes(self):
        self.start()
        for operation,value in [("cut",999),("cut",-1),("cut",[1]),("unknown",1)]:
            with self.assertRaises(HTTPException):
                self.act("wires",operation,value)
        current = self.store.get(self.id,"host","alice",self.now)
        self.assertEqual(current["strikes"],0)
        self.assertEqual(current["bomb"]["modules"][0]["data"]["cut"],[])

    def request(self,method,path,payload=None,headers=None):
        async def run():
            messages=[];body=json.dumps(payload).encode() if payload is not None else b""
            async def receive():return {"type":"http.request","body":body,"more_body":False}
            async def send(message):messages.append(message)
            await main.app({"type":"http","asgi":{"version":"3.0"},"http_version":"1.1","method":method,"scheme":"http","path":path,"raw_path":path.encode(),"query_string":b"","root_path":"","headers":[(b"content-type",b"application/json")]+[(k.lower().encode(),v.encode()) for k,v in (headers or {}).items()],"server":("test",80),"client":("test",1)},receive,send)
            start=next(m for m in messages if m["type"]=="http.response.start")
            content=b"".join(m.get("body",b"") for m in messages if m["type"]=="http.response.body")
            return start["status"],json.loads(content),dict(start["headers"])
        return asyncio.run(run())

    def test_real_http_guest_join_without_login_cannot_control_bomb_and_private_headers(self):
        self.host = self.store.create("alice", "contact")
        self.id = self.host["room_id"]
        with patch.object(nullsignal,"store",return_value=self.store),patch.object(auth,"economy",return_value=self.ledger),patch.object(auth,"get_user",side_effect=lambda username:{"username":username}):
            base=f"/api/nullsignal/rooms/{self.id}"
            self.assertEqual(self.request("POST","/api/nullsignal/rooms",{"mission":"contact"})[0],401)
            status,expert,headers=self.request("POST",base+"/join",{"invite_token":self.host["invite_token"],"name":"Browser guest"})
            self.assertEqual(status,200)
            self.assertEqual(headers[b"cache-control"],b"no-store")
            guest={"X-Nullsignal-Token":expert["guest_token"]}
            self.assertEqual(self.request("POST",base+"/control",{"command":"start"},guest)[0],401)
            self.assertEqual(self.request("GET",base+"/host",headers=guest)[0],401)
            self.assertEqual(self.request("GET",base+"/expert",headers=guest)[0],200)
            self.assertNotIn("bomb",expert)
            host={"Authorization":f"Bearer {auth.create_access_token('alice')}"}
            self.assertEqual(self.request("POST",base+"/ready",{"ready":True},guest)[0],200)
            self.assertEqual(self.request("POST",base+"/control",{"command":"start"},host)[0],200)
            bob={"Authorization":f"Bearer {auth.create_access_token('bob')}"}
            self.assertEqual(self.request("GET",base+"/host",headers=bob)[0],404)
            self.assertEqual(self.request("POST",base+"/action",{"round_id":expert["round_id"],"request_id":uuid4().hex,"module_id":"wires","operation":"cut","value":0},guest)[0],401)


if __name__ == "__main__":
    unittest.main()
