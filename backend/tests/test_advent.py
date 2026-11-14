import os
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import FastAPI, Header
from fastapi.testclient import TestClient

from app import advent, ratelimit

CET = timezone(timedelta(hours=1))


class AdventTests(unittest.TestCase):
    def setUp(self):
        ratelimit.reset()
        self.folder = tempfile.TemporaryDirectory()
        os.environ["AVIARY_ADVENT_FILE"] = str(Path(self.folder.name) / "advent.json")
        os.environ["AVIARY_ADVENT_VIRUS_PASSWORD"] = "test-secret"
        self.now = datetime(2026, 11, 30, 23, 59, tzinfo=CET)
        self._utcnow, self._admin, self._pub = advent.utcnow, advent.is_site_admin, advent.is_publisher
        advent.utcnow = lambda: self.now.astimezone(timezone.utc)
        advent.is_site_admin = lambda user: bool(user) and user["username"] in ("boss", "pub")
        advent.is_publisher = lambda user: bool(user) and user["username"] == "pub"
        app = FastAPI(); app.include_router(advent.router)

        def fake(x_test_user: str | None = Header(default=None)):
            return {"username": x_test_user} if x_test_user else None
        app.dependency_overrides[advent.optional_user] = fake
        self.client = TestClient(app)

    def tearDown(self):
        advent.utcnow, advent.is_site_admin, advent.is_publisher = self._utcnow, self._admin, self._pub
        os.environ.pop("AVIARY_ADVENT_FILE", None)
        os.environ.pop("AVIARY_ADVENT_VIRUS_PASSWORD", None)
        self.folder.cleanup()

    def get(self, user=None):
        return self.client.get("/api/advent", headers={"X-Test-User": user} if user else {})

    def post(self, path, user=None, **kw):
        return self.client.post(f"/api/advent{path}", headers={"X-Test-User": user} if user else {}, **kw)

    def test_contents_stay_hidden_until_opened(self):
        data = self.get().json()
        self.assertEqual(len(data["doors"]), 24)
        self.assertTrue(all("item" not in d for d in data["doors"]))
        self.assertFalse(data["doors"][0]["unlocked"])
        self.assertFalse(data["can_open"])
        self.assertTrue(self.get("boss").json()["can_open"])

    def test_door_one_is_the_virus_and_unlocks_at_midnight(self):
        self.assertEqual(self.post("/1/open", "boss").status_code, 409)
        self.now = datetime(2026, 12, 1, 0, 0, tzinfo=CET)
        self.assertEqual(self.post("/1/open", "anna").status_code, 403)
        self.assertEqual(self.post("/1/open").status_code, 401)
        data = self.post("/1/open", "boss").json()
        door = data["doors"][0]
        self.assertEqual(door["item"]["id"], "punish-virus")
        self.assertEqual(door["opened_by"], "boss")
        self.assertEqual(data["virus"]["deadline"][:10], "2027-06-01")
        self.assertEqual(self.post("/1/open", "boss").status_code, 409)
        self.assertEqual(self.post("/2/open", "boss").status_code, 409, "door 2 waits for 2 December")
        self.assertTrue("item" in self.get().json()["doors"][0], "opened doors are public")

    def test_rest_is_shuffled_and_stable(self):
        order = advent.load_state(2026)["order"]
        self.assertEqual(order[0], "punish-virus")
        self.assertEqual(sorted(order), sorted(i["id"] for i in advent.ITEMS))
        self.assertEqual(advent.load_state(2026)["order"], order)
        self.assertNotEqual(advent.shuffled_order("a")[1:], advent.shuffled_order("b")[1:])

    def test_zeitmanagement_takes_a_month_off(self):
        state = advent.load_state(2026)
        day = state["order"].index("punish-time") + 1
        self.now = datetime(2026, 12, 24, 12, 0, tzinfo=CET)
        self.post("/1/open", "boss")
        data = self.post(f"/{day}/open", "boss").json()
        self.assertEqual(data["virus"]["months"], 5)

    def test_virus_only_switches_off_with_the_password(self):
        self.now = datetime(2026, 12, 1, 9, 0, tzinfo=CET)
        self.assertEqual(self.post("/virus/off", json={"password": "test-secret"}).status_code, 409)
        self.post("/1/open", "boss")
        self.assertEqual(self.post("/virus/off", "boss", json={"password": "falsch"}).status_code, 403)
        data = self.post("/virus/off", json={"password": "test-secret"}).json()
        self.assertTrue(data["virus"]["off"])
        os.environ["AVIARY_ADVENT_VIRUS_PASSWORD"] = ""
        self.assertEqual(self.post("/virus/off", json={"password": ""}).status_code, 422)

    def test_password_guessing_is_rate_limited(self):
        self.now = datetime(2026, 12, 1, 9, 0, tzinfo=CET)
        self.post("/1/open", "boss")
        codes = [self.post("/virus/off", json={"password": f"x{i}"}).status_code for i in range(10)]
        self.assertIn(429, codes)

    def test_publisher_test_mode_is_separate_and_resettable(self):
        self.assertEqual(self.client.get("/api/advent/test").status_code, 401)
        self.assertEqual(self.client.get("/api/advent/test", headers={"X-Test-User": "anna"}).status_code, 403)
        self.assertEqual(self.client.get("/api/advent/test", headers={"X-Test-User": "boss"}).status_code, 403, "admins are not publishers")
        self.assertEqual(self.post("/test/1/open", "boss").status_code, 403)
        self.assertFalse(self.get("boss").json()["can_test"])
        self.assertTrue(self.get("pub").json()["can_test"])
        self.assertTrue(self.get("pub").json()["can_open"], "publisher keeps every admin right")
        data = self.client.get("/api/advent/test", headers={"X-Test-User": "pub"}).json()
        self.assertTrue(data["test"])
        self.assertTrue(all(d["unlocked"] for d in data["doors"]), "every door is unlocked in test mode, even in November")
        for day in range(1, 25):
            self.assertEqual(self.post(f"/test/{day}/open", "pub").status_code, 200)
        data = self.post("/test/virus/off", "pub", json={"password": "test-secret"}).json()
        self.assertEqual(sum(d["opened"] for d in data["doors"]), 24)
        self.assertEqual(data["virus"]["months"], 5)
        self.assertTrue(data["virus"]["off"])
        live = self.get().json()
        self.assertFalse(any(d["opened"] for d in live["doors"]), "the real calendar is untouched")
        self.assertIsNone(live["virus"])
        self.assertEqual(self.post("/test/reset", "anna").status_code, 403)
        data = self.post("/test/reset", "pub").json()
        self.assertFalse(any(d["opened"] for d in data["doors"]))
        self.assertEqual(self.post("/test/1/open", "anna").status_code, 403)



if __name__ == "__main__":
    unittest.main()
