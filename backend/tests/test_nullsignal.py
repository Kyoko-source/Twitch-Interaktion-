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
from app.nullsignal_puzzles import generate, apply_action, MISSIONS, MODULES
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
    if kind == "capacitors":
        order = sorted(range(4), key=lambda i: data["cells"][i], reverse=rules[f"v{facts['voltage']}"] == "descending")
        return [("press", i) for i in order]
    if kind == "compass":
        row = next(row for row in rules["rows"] if row["mark"] == data["mark"])
        return [("press", (direction+data["facing"]) % 4) for direction in row["directions"]]
    raise AssertionError(kind)


class NullsignalTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.ledger = EconomyStore(Path(self.directory.name)/"nullsignal.sqlite3")
        self.ledger.mark_ready(["alice", "bob"])
        self.store = NullsignalStore(self.ledger)
        self.now = 100000
        # Stable fixture includes the particular wire/frequency modules used below.
        with patch("app.nullsignal.generate", side_effect=lambda mission: generate(mission, 3)):
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
        seen = set()
        for seed in range(100):
            bomb = generate("blackout", seed)
            for module in bomb["modules"]:
                seen.add(module["kind"])
                with self.subTest(seed=seed, kind=module["kind"]):
                    visible = {key: copy.deepcopy(module[key]) for key in ["id", "kind", "data"]}
                    steps = solution(visible, {"manual": module["manual"]}, bomb)
                    for operation, value in steps:
                        self.assertNotEqual(apply_action(module, operation, value), "bad")
                    self.assertTrue(module["solved"])
        self.assertEqual(seen, {kind for kind, _ in MODULES})

    def test_all_missions_randomize_unique_module_selection_and_order(self):
        for mission, spec in MISSIONS.items():
            samples = [generate(mission, seed) for seed in range(100)]
            combinations = set()
            for bomb in samples:
                ids = [module["id"] for module in bomb["modules"]]
                self.assertEqual(len(ids), spec["modules"])
                self.assertEqual(len(ids), len(set(ids)))
                combinations.add(tuple(sorted(ids)))
            self.assertGreater(len(combinations), 10)
            self.assertEqual({m["kind"] for b in samples for m in b["modules"]}, {kind for kind, _ in MODULES})
            self.assertEqual(generate(mission, 42), generate(mission, 42))

    def test_new_sequence_modules_reject_wrong_input_and_reset_progress(self):
        for kind in ("capacitors", "compass"):
            module = next(m for seed in range(100) for m in generate("blackout", seed)["modules"] if m["kind"] == kind)
            correct = module["answer"]
            self.assertEqual(apply_action(module, "press", correct[0]), "neutral")
            self.assertEqual(apply_action(module, "press", (correct[1]+1) % 4), "bad")
            self.assertEqual(module["progress"], [])
            for value in correct:
                apply_action(module, "press", value)
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
        wire = next(m for m in self.host["bomb"]["modules"] if m["kind"] == "wires")
        manual = next(m for m in self.store.get(self.id, "expert", self.token, self.now)["manual"] if m["kind"] == "wires")
        correct = solution(wire, manual, self.host["bomb"])[0][1]
        wrong = (correct+1) % len(wire["data"]["wires"])
        key = uuid4().hex
        with ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(lambda _:self.store.action(self.id,"alice",key,self.host["round_id"],"wires","cut",wrong,self.now),range(6)))
        host = self.store.get(self.id,"host","alice",self.now)
        self.assertEqual(host["strikes"],1)
        self.assertEqual(host["deadline"],self.now+MISSIONS["blackout"]["seconds"]-8)
        with self.assertRaises(HTTPException):
            self.act("wires","cut",correct,key=key)

    def test_three_mistakes_explode_and_do_not_pay_or_record_win(self):
        self.start()
        frequency = next(m for m in self.host["bomb"]["modules"] if m["kind"] == "frequency")
        expert = self.store.get(self.id,"expert",self.token,self.now)
        correct = solution(frequency,next(m for m in expert["manual"] if m["kind"] == "frequency"),self.host["bomb"])[0][1]
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
        self.assertEqual((paused["status"],paused["remaining"],paused["pause_reason"]),("paused",MISSIONS["blackout"]["seconds"]-GRACE,"connection"))
        self.assertIsNone(paused["deadline"])
        self.store.get(self.id,"expert",self.token,self.now+40)
        resumed = self.store.control(self.id,"alice","start",now=self.now+40)
        self.assertEqual(resumed["deadline"],self.now+40+MISSIONS["blackout"]["seconds"]-GRACE)

    def test_timer_expiry_is_authoritative_when_both_players_are_present(self):
        self.start()
        for offset in range(5,MISSIONS["blackout"]["seconds"],5):
            self.touch(self.now+offset)
        result = self.store.get(self.id,"host","alice",self.now+MISSIONS["blackout"]["seconds"])
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
        self.assertEqual(next(m for m in current["bomb"]["modules"] if m["kind"] == "wires")["data"]["cut"],[])

    def test_two_pills_per_round_idempotent_consumption_and_rematch_refill(self):
        self.start()
        key = uuid4().hex
        first = self.store.calm(self.id, "alice", key, self.host["round_id"], self.now+1)
        self.assertEqual(first["calm"], {"pills_remaining": 1, "seconds_remaining": 30})
        duplicate = self.store.calm(self.id, "alice", key, self.host["round_id"], self.now+2)
        self.assertEqual(duplicate["calm"]["pills_remaining"], 1)
        with self.assertRaises(HTTPException):
            self.store.calm(self.id, "alice", uuid4().hex, self.host["round_id"], self.now+3)
        for offset in range(5, 65, 5):
            self.touch(self.now+offset)
            if offset == 35:
                second = self.store.calm(self.id, "alice", uuid4().hex, self.host["round_id"], self.now+offset)
                self.assertEqual(second["calm"]["pills_remaining"], 0)
        self.touch(self.now+66)
        with self.assertRaises(HTTPException):
            self.store.calm(self.id, "alice", uuid4().hex, self.host["round_id"], self.now+66)
        self.store.control(self.id, "alice", "pause", now=self.now+67)
        new = self.store.control(self.id, "alice", "reset", now=self.now+68)
        self.assertEqual(new["calm"], {"pills_remaining": 2, "seconds_remaining": 0})
        self.assertEqual(self.ledger.balance("alice")["chickens"], 0)

    def test_pill_duration_freezes_during_pause_and_survives_reload(self):
        self.start()
        self.store.calm(self.id, "alice", uuid4().hex, self.host["round_id"], self.now+1)
        paused = self.store.control(self.id, "alice", "pause", now=self.now+5)
        self.assertEqual(paused["calm"]["seconds_remaining"], 26)
        reopened = NullsignalStore(self.ledger)
        restored = reopened.get(self.id, "host", "alice", self.now+500)
        self.assertEqual(restored["calm"], paused["calm"])
        reopened.get(self.id, "expert", self.token, self.now+500)
        resumed = reopened.control(self.id, "alice", "start", now=self.now+500)
        self.assertEqual(resumed["calm"]["seconds_remaining"], 26)
        self.assertEqual(reopened.get(self.id, "host", "alice", self.now+501)["calm"]["seconds_remaining"], 25)

    def test_pills_require_owner_running_current_round_and_support_existing_rooms(self):
        with self.assertRaises(HTTPException):
            self.store.calm(self.id, "alice", uuid4().hex, self.host["round_id"], self.now)
        self.start()
        for owner, round_id in [("bob", self.host["round_id"]), ("alice", uuid4().hex)]:
            with self.assertRaises(HTTPException):
                self.store.calm(self.id, owner, uuid4().hex, round_id, self.now+1)
        with self.ledger.connection(write=True) as db:
            state = json.loads(db.execute("SELECT state FROM nullsignal_rooms WHERE id=?", (self.id,)).fetchone()[0])
            state.pop("pills_remaining")
            state.pop("calm_until_played")
            db.execute("UPDATE nullsignal_rooms SET state=? WHERE id=?", (json.dumps(state), self.id))
        self.assertEqual(self.store.get(self.id, "host", "alice", self.now+1)["calm"]["pills_remaining"], 2)
        self.assertEqual(self.store.calm(self.id, "alice", uuid4().hex, self.host["round_id"], self.now+1)["calm"]["pills_remaining"], 1)
        self.assertNotIn("calm", self.store.get(self.id, "expert", self.token, self.now+1))

    def test_concurrent_retries_only_consume_one_pill(self):
        self.start()
        key = uuid4().hex
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(lambda _: self.store.calm(self.id, "alice", key, self.host["round_id"], self.now+1), range(2)))
        self.assertEqual([response["calm"]["pills_remaining"] for response in responses], [1, 1])

    def test_atmosphere_clock_is_private_persistent_and_frozen_during_pause(self):
        self.start()
        for offset in range(5, 46, 5):
            self.touch(self.now+offset)
        current = self.store.get(self.id, "host", "alice", self.now+45)
        self.assertEqual(current["atmosphere"]["played"], 45)
        self.assertEqual(current["atmosphere"]["untreated"], 45)
        self.assertTrue(40 <= current["atmosphere"]["outage_start"] <= 50)
        self.assertNotIn("atmosphere", self.store.get(self.id, "expert", self.token, self.now+45))
        paused = self.store.control(self.id, "alice", "pause", now=self.now+46)
        restored = NullsignalStore(self.ledger).get(self.id, "host", "alice", self.now+1000)
        self.assertEqual(restored["atmosphere"], paused["atmosphere"])

    def test_no_scare_near_deadline_and_legacy_saved_scares_are_ignored(self):
        self.start()
        for offset in range(5, 310, 5):
            self.touch(self.now+offset)
        first = self.store.get(self.id, "host", "alice", self.now+310)
        self.assertIsNone(first["atmosphere"]["scare_id"])
        self.assertEqual(first["atmosphere"]["scare_remaining"], 0)
        self.assertEqual(first["event"], self.host["event"])
        self.assertEqual(first["strikes"], 0)
        with self.ledger.connection(write=True) as db:
            state = json.loads(db.execute("SELECT state FROM nullsignal_rooms WHERE id=?", (self.id,)).fetchone()[0])
            state["scare_at_played"] = 310
            db.execute("UPDATE nullsignal_rooms SET state=? WHERE id=?", (json.dumps(state), self.id))
        later = NullsignalStore(self.ledger).get(self.id, "host", "alice", self.now+310.1)
        self.assertEqual(later["atmosphere"]["scare_remaining"], 0)
        self.assertEqual(later["atmosphere"]["scare_id"], first["atmosphere"]["scare_id"])
        self.store.control(self.id, "alice", "pause", now=self.now+313)
        reset = self.store.control(self.id, "alice", "reset", now=self.now+314)
        self.assertIsNone(reset["atmosphere"]["scare_id"])
        self.assertEqual(reset["atmosphere"]["played"], 0)

    def test_pill_delays_untreated_stress_without_any_scare(self):
        self.start()
        for offset in range(5, 310, 5):
            self.touch(self.now+offset)
            if offset == 290:
                self.store.calm(self.id, "alice", uuid4().hex, self.host["round_id"], self.now+offset)
        self.touch(self.now+310)
        self.assertIsNone(self.store.get(self.id, "host", "alice", self.now+310)["atmosphere"]["scare_id"])
        self.assertEqual(self.store.get(self.id, "host", "alice", self.now+310)["atmosphere"]["untreated"], 0)
        # The short mission stays free of scares at its former trigger point.
        self.store.control(self.id, "alice", "pause", now=self.now+311)
        self.host = self.store.control(self.id, "alice", "reset", "contact", self.now+312)
        self.now += 312
        self.store.ready(self.id, self.token, True, self.now)
        self.host = self.store.control(self.id, "alice", "start", now=self.now)
        for offset in range(5, 135, 5):
            self.touch(self.now+offset)
        cancelled = self.store.calm(self.id, "alice", uuid4().hex, self.host["round_id"], self.now+130.1)
        self.assertEqual(cancelled["atmosphere"]["scare_remaining"], 0)
        self.assertEqual(cancelled["atmosphere"]["untreated"], 0)

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
            pill = {"round_id": expert["round_id"], "request_id": uuid4().hex}
            self.assertEqual(self.request("POST",base+"/calm",pill,guest)[0],401)
            status, calm, headers = self.request("POST",base+"/calm",pill,host)
            self.assertEqual(status,200)
            self.assertEqual(calm["calm"]["pills_remaining"],1)
            self.assertEqual(headers[b"cache-control"],b"no-store")
            bob={"Authorization":f"Bearer {auth.create_access_token('bob')}"}
            self.assertEqual(self.request("GET",base+"/host",headers=bob)[0],404)
            self.assertEqual(self.request("POST",base+"/action",{"round_id":expert["round_id"],"request_id":uuid4().hex,"module_id":"wires","operation":"cut","value":0},guest)[0],401)


if __name__ == "__main__":
    unittest.main()
