import json
import tempfile
import unittest
from pathlib import Path

from fastapi import FastAPI, Header
from fastapi.testclient import TestClient

from app import auth, cookie, profiles
from app.economy import EconomyStore


def save(**over):
    base = {"v": 1, "t": 100.0, "dough": 1_000_000 - 30, "ball": 8, "sheet": 2, "tray": 3, "queue": 2, "exit": 1,
            "belt": [[3.5, 4], [1.0, 2]], "falling": [[101.0, 1]], "baked": 7, "earned": 7, "talers": 5, "spent": 2, "levels": {}}
    base.update(over)
    return json.dumps(base)


class CookieSaveTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.folder.name) / "economy.sqlite3")
        self._economy = cookie.economy
        cookie.economy = lambda: self.store
        app = FastAPI(); app.include_router(cookie.router)

        def fake(x_test_user: str = Header()):
            return {"username": x_test_user}
        app.dependency_overrides[auth.current_user] = fake
        self.client = TestClient(app)

    def tearDown(self):
        cookie.economy = self._economy
        self.folder.cleanup()

    def put(self, data, user="alice", reset=False):
        return self.client.put("/api/cookie/save", json={"data": data, "reset": reset}, headers={"x-test-user": user})

    def test_save_and_load_round_trip(self):
        self.assertEqual(self.client.get("/api/cookie/save", headers={"x-test-user": "alice"}).json()["save"], None)
        self.assertEqual(self.put(save()).status_code, 200)
        got = self.client.get("/api/cookie/save", headers={"x-test-user": "alice"}).json()
        self.assertEqual(json.loads(got["save"])["baked"], 7)
        self.assertEqual(self.client.get("/api/cookie/save", headers={"x-test-user": "bob"}).json()["save"], None)

    def test_dough_must_add_up_and_talers_match(self):
        self.assertEqual(self.put(save(dough=1_000_000)).status_code, 400)  # 30 cookies made out of nothing
        self.assertEqual(self.put(save(talers=500)).status_code, 400)
        self.assertEqual(self.put(save(v=2)).status_code, 400)
        self.assertEqual(self.put("not json").status_code, 400)

    def test_an_old_tab_cannot_overwrite_progress_but_a_reset_can(self):
        self.assertEqual(self.put(save()).status_code, 200)
        older = save(dough=1_000_000 - 23, baked=0, earned=0, talers=0, spent=0)
        self.assertEqual(self.put(older).status_code, 409)
        self.assertEqual(self.put(older, reset=True).status_code, 200)

    def test_finale_needs_a_million_and_real_play_time(self):
        self.assertEqual(self.client.post("/api/cookie/finale", headers={"x-test-user": "alice"}).status_code, 400)
        done = dict(dough=0, ball=0, sheet=0, tray=0, queue=0, exit=0, belt=[], falling=[], baked=1_000_000, earned=1_000_000, talers=10, spent=999_990)
        self.assertEqual(self.put(save(t=60, **done)).status_code, 200)
        self.assertEqual(self.client.post("/api/cookie/finale", headers={"x-test-user": "alice"}).status_code, 400)
        self.assertEqual(self.put(save(t=4 * 3600, **done)).status_code, 200)
        r = self.client.post("/api/cookie/finale", headers={"x-test-user": "alice"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["title"], "Oberster Keksmeister des Nordpols")
        with self.store.connection() as db:
            card = profiles.card(db, "alice")
        self.assertTrue(card["cookie"]["finished"])
        self.assertTrue(next(b for b in card["badges"] if b["id"] == "cookie-master")["earned"])


if __name__ == "__main__":
    unittest.main()
