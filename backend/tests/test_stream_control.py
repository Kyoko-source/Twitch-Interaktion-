import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import ratelimit, stream_control
from app.economy import EconomyStore

ADMIN = {"X-Admin-Password": "test-only-password"}


class StreamControlTests(unittest.TestCase):
    def setUp(self):
        ratelimit.reset()
        self.folder = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.folder.name) / "economy.sqlite3")
        self.patches = [patch.object(stream_control, "economy", lambda: self.store),
                        patch("app.auth.get_settings", return_value=SimpleNamespace(admin_password="test-only-password"))]
        for p in self.patches:
            p.start()
        app = FastAPI(); app.include_router(stream_control.router)
        self.client = TestClient(app)

    def tearDown(self):
        for p in self.patches:
            p.stop()
        self.folder.cleanup()

    def test_fifty_effects_plus_stop(self):
        self.assertEqual(len(stream_control.EFFECTS - {"stop"}), 50)

    def test_admin_fires_and_the_public_feed_lists_events_in_order(self):
        first = self.client.post("/api/admin/stream-control", headers=ADMIN, json={"effect": "confetti-cannon", "duration": 8})
        self.assertEqual(first.status_code, 200)
        self.client.post("/api/admin/stream-control", headers=ADMIN, json={"effect": "noir-rain", "duration": 20})
        feed = self.client.get("/api/stream-control")
        self.assertEqual(feed.headers["cache-control"], "no-store")
        events = feed.json()["events"]
        self.assertEqual([e["effect"] for e in events], ["confetti-cannon", "noir-rain"])
        self.assertEqual(events[1]["duration"], 20)
        self.assertEqual(feed.json()["last_id"], events[1]["id"])

    def test_only_admins_can_fire(self):
        self.assertEqual(self.client.post("/api/admin/stream-control", json={"effect": "gg"}).status_code, 403)
        self.assertEqual(self.client.post("/api/admin/stream-control", headers={"X-Admin-Password": "wrong"}, json={"effect": "gg"}).status_code, 403)
        self.assertEqual(self.client.get("/api/stream-control").json()["events"], [])

    def test_unknown_effects_durations_and_ads_without_video_are_rejected(self):
        self.assertEqual(self.client.post("/api/admin/stream-control", headers=ADMIN, json={"effect": "nuke"}).status_code, 400)
        self.assertEqual(self.client.post("/api/admin/stream-control", headers=ADMIN, json={"effect": "gg", "duration": 600}).status_code, 422)
        self.assertEqual(self.client.post("/api/admin/stream-control", headers=ADMIN, json={"effect": "ad"}).status_code, 400)
        self.assertEqual(self.client.post("/api/admin/stream-control", headers=ADMIN, json={"effect": "ad", "video": "anything"}).status_code, 400)
        ok = self.client.post("/api/admin/stream-control", headers=ADMIN, json={"effect": "ad", "video": "after-play"}).json()
        self.assertEqual(ok["event"]["video"], "after-play")

    def test_old_events_leave_the_feed(self):
        self.client.post("/api/admin/stream-control", headers=ADMIN, json={"effect": "gg"})
        with self.store.connection(write=True) as db:
            db.execute("UPDATE stream_events SET created = created - ?", (stream_control.FEED_WINDOW + 1,))
        feed = self.client.get("/api/stream-control").json()
        self.assertEqual(feed["events"], [])
        self.assertEqual(feed["last_id"], 1)


if __name__ == "__main__":
    unittest.main()
