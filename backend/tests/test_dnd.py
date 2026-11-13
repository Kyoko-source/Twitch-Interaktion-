import tempfile
import unittest
from pathlib import Path

from fastapi import FastAPI, Header
from fastapi.testclient import TestClient

from app import auth, dnd, ratelimit


class DndTableTests(unittest.TestCase):
    def setUp(self):
        ratelimit.reset()
        self.folder = tempfile.TemporaryDirectory()
        dnd._store = dnd.Store(Path(self.folder.name) / "dnd.sqlite3")
        app = FastAPI(); app.include_router(dnd.router)
        app.dependency_overrides[auth.current_user] = lambda x_test_user: {"username": x_test_user}
        # FastAPI needs the header declared on the override itself.
        def fake(x_test_user: str = Header()): return {"username": x_test_user}
        app.dependency_overrides[auth.current_user] = fake
        self.client = TestClient(app)
        self.code = self.as_("dm").post("/api/dnd/rooms", json={"name": "Grotte"}).json()["code"]

    def tearDown(self):
        dnd._store = None
        self.folder.cleanup()

    def as_(self, user):
        client = self.client
        class Bound:
            def get(_, url, **kw): return client.get(url, headers={"X-Test-User": user}, **kw)
            def post(_, url, **kw): return client.post(url, headers={"X-Test-User": user}, **kw)
        return Bound()

    def act(self, user, **action):
        return self.as_(user).post(f"/api/dnd/rooms/{self.code}/action", json=action)

    def test_dice_expressions(self):
        for _ in range(200):
            r = dnd.roll_expression("2d6+3")
            self.assertTrue(5 <= r["total"] <= 15)
            r = dnd.roll_expression("1d100")
            self.assertTrue(1 <= r["total"] <= 100)
            r = dnd.roll_expression("4d6kh3")
            self.assertEqual(len(r["parts"][0]["kept"]), 3)
            r = dnd.roll_expression("d20+5", "adv")
            self.assertEqual(len(r["parts"][0]["rolls"]), 2)
            self.assertEqual(r["total"] - 5, max(r["parts"][0]["rolls"]))
            r = dnd.roll_expression("1d20", "dis")
            self.assertEqual(r["total"], min(r["parts"][0]["rolls"]))
        self.assertEqual(dnd.roll_expression(" 2d6 + 3 ")["parts"][1]["value"], 3)
        for bad in ["", "d", "2d6++", "1000d6", "1d1", "abc", "2d6 3"]:
            with self.assertRaises(Exception):
                dnd.roll_expression(bad)

    def test_players_characters_and_permissions(self):
        self.assertEqual(self.as_("anna").get(f"/api/dnd/rooms/{self.code}").status_code, 403)
        self.assertEqual(self.as_("anna").post(f"/api/dnd/rooms/{self.code}/join", json={"role": "player"}).status_code, 200)
        self.as_("ben").post(f"/api/dnd/rooms/{self.code}/join", json={"role": "player"})
        sheet = {"name": "Lyra", "char_class": "Magier", "species": "Elf", "max_hp": 8, "hp": 8, "abilities": {"dex": 14, "int": 17}}
        view = self.act("anna", type="character.save", character=sheet).json()
        lyra = next(iter(view["characters"].values()))
        self.assertEqual((lyra["owner"], lyra["name"]), ("anna", "Lyra"))
        self.assertEqual(self.act("anna", type="character.save", character=sheet).status_code, 409)
        # Ben may neither edit nor move Lyra; Anna and the DM may.
        self.assertEqual(self.act("ben", type="token.move", ref=f"c:{lyra['id']}", x=3, y=3).status_code, 403)
        self.assertEqual(self.act("anna", type="token.move", ref=f"c:{lyra['id']}", x=999, y=-4).json()["characters"][lyra["id"]]["x"], 23)
        self.assertEqual(self.act("ben", type="hp.change", ref=f"c:{lyra['id']}", delta=-3).status_code, 403)
        self.assertEqual(self.act("dm", type="hp.change", ref=f"c:{lyra['id']}", delta=-30).json()["characters"][lyra["id"]]["hp"], 0)
        # Players cannot use DM tools.
        self.assertEqual(self.act("anna", type="creature.add", name="Goblin").status_code, 403)

    def test_creatures_hidden_hp_secret_rolls_and_initiative(self):
        self.as_("anna").post(f"/api/dnd/rooms/{self.code}/join", json={"role": "player"})
        self.act("anna", type="character.save", character={"name": "Brom", "max_hp": 12, "hp": 12})
        view = self.act("dm", type="creature.add", name="Goblin", max_hp=7, ac=15, init_bonus=2, count=3).json()
        self.assertEqual(sorted(c["name"] for c in view["creatures"].values()), ["Goblin 1", "Goblin 2", "Goblin 3"])
        gid = next(iter(view["creatures"]))
        self.act("dm", type="hp.change", ref=f"m:{gid}", delta=-4)
        player = self.as_("anna").get(f"/api/dnd/rooms/{self.code}").json()
        seen = player["creatures"][gid]
        self.assertIsNone(seen["hp"]); self.assertIsNone(seen["ac"])
        self.assertEqual(seen["health"], "Schwer verletzt")  # 3 of 7
        self.assertFalse(any("7 → 3" in e["text"] for e in player["log"]))
        dm_view = self.as_("dm").get(f"/api/dnd/rooms/{self.code}").json()
        self.assertEqual(dm_view["creatures"][gid]["hp"], 3)
        self.assertTrue(any("7 → 3" in e["text"] for e in dm_view["log"]))
        # Invisible creatures and secret DM rolls stay hidden from players.
        self.act("dm", type="creature.add", name="Mimik", max_hp=58, visible=False)
        self.act("dm", type="roll", expr="1d20+4", label="Heimlich", secret=True)
        player = self.as_("anna").get(f"/api/dnd/rooms/{self.code}").json()
        self.assertNotIn("Mimik", [c["name"] for c in player["creatures"].values()])
        self.assertFalse(any(e.get("label") == "Heimlich" for e in player["log"]))
        # Initiative covers the character and the three visible goblins.
        view = self.act("dm", type="initiative.roll").json()
        self.assertEqual(len(view["initiative"]["order"]), 4)
        self.assertEqual(self.act("dm", type="turn.next").json()["initiative"]["turn"], 1)

    def test_polling_since_version(self):
        first = self.as_("dm").get(f"/api/dnd/rooms/{self.code}").json()
        self.assertEqual(self.as_("dm").get(f"/api/dnd/rooms/{self.code}", params={"since": first["version"]}).json(), {"unchanged": True, "version": first["version"]})
        self.act("dm", type="chat.say", text="Willkommen!")
        self.assertIn("log", self.as_("dm").get(f"/api/dnd/rooms/{self.code}", params={"since": first["version"]}).json())

    def test_listing_lock_and_leave(self):
        self.assertEqual([r["code"] for r in self.as_("zoe").get("/api/dnd/rooms").json()], [self.code])
        self.act("dm", type="room.update", locked=True)
        self.assertEqual(self.as_("zoe").get("/api/dnd/rooms").json(), [])
        self.assertEqual(self.as_("zoe").post(f"/api/dnd/rooms/{self.code}/join", json={"role": "player"}).status_code, 403)
        self.as_("dm").post(f"/api/dnd/rooms/{self.code}/leave")
        self.assertEqual(self.as_("dm").get(f"/api/dnd/rooms/{self.code}").status_code, 404)


if __name__ == "__main__":
    unittest.main()
