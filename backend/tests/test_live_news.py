import asyncio
import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import FastAPI
from pydantic import ValidationError

from app import live_news
from app.live_news import LiveNewsSettings, LiveNewsStore


class LiveNewsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = LiveNewsStore(Path(self.directory.name) / "news.json")
        self.store_patch = patch.object(live_news, "store", self.store)
        self.store_patch.start()
        self.auth_patch = patch("app.auth.get_settings", return_value=SimpleNamespace(admin_password="test-only-password"))
        self.auth_patch.start()
        self.app = FastAPI()
        self.app.include_router(live_news.router)

    def tearDown(self):
        self.auth_patch.stop()
        self.store_patch.stop()
        self.directory.cleanup()

    def request(self, method, path, payload=None, admin=False):
        async def run():
            output = []
            body = json.dumps(payload).encode() if payload is not None else b""
            headers = [(b"content-type", b"application/json")]
            if admin:
                headers.append((b"x-admin-password", b"test-only-password"))

            async def receive():
                return {"type": "http.request", "body": body, "more_body": False}

            async def send(message):
                output.append(message)

            await self.app({
                "type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
                "scheme": "http", "method": method, "path": path, "raw_path": path.encode(),
                "query_string": b"", "root_path": "", "headers": headers,
                "client": ("127.0.0.1", 1234), "server": ("test", 80),
            }, receive, send)
            start = next(item for item in output if item["type"] == "http.response.start")
            response_body = b"".join(item.get("body", b"") for item in output if item["type"] == "http.response.body")
            return start["status"], json.loads(response_body), dict(start["headers"])
        return asyncio.run(run())

    def test_public_is_read_only_and_admin_requires_password(self):
        status, state, headers = self.request("GET", "/api/live-news")
        self.assertEqual(status, 200)
        self.assertFalse(state["enabled"])
        self.assertEqual(headers[b"cache-control"], b"no-store")
        for method in ["GET", "PUT", "PATCH"]:
            self.assertEqual(self.request(method, "/api/admin/live-news", {})[0], 403)
        self.assertEqual(self.request("PUT", "/api/live-news", {})[0], 405)

    def test_publish_visibility_and_persistence(self):
        status, state, _ = self.request("PUT", "/api/admin/live-news", {
            "message": "  Hallo\n Community!  ", "kind": "community", "speed": 120, "enabled": True,
        }, admin=True)
        self.assertEqual(status, 200)
        self.assertEqual(state["message"], "Hallo Community!")
        self.assertEqual(state["revision"], 1)
        self.assertTrue(state["updated_at"])
        self.assertEqual(LiveNewsStore(self.store.path).read().model_dump(), state)
        status, hidden, _ = self.request("PATCH", "/api/admin/live-news", {"enabled": False}, admin=True)
        self.assertEqual(status, 200)
        self.assertFalse(hidden["enabled"])
        self.assertEqual(hidden["message"], state["message"])
        self.assertEqual(hidden["revision"], 2)
        self.assertEqual(self.request("GET", "/api/live-news")[1], hidden)
        self.assertEqual(self.request("PATCH", "/api/admin/live-news", {"enabled": True}, admin=True)[0], 200)

    def test_invalid_payloads_never_change_publication(self):
        for payload in [
            {"message": "   ", "enabled": True}, {"message": "a" * 1001},
            {"kind": "invalid"}, {"speed": 0}, {"speed": 221}, {"speed": 99.5},
            {"enabled": "yes"}, {"admin_password": "no"},
            {"playback_mode": "forever"}, {"repeat_count": 0}, {"repeat_count": 21},
            {"repeat_count": 1.5}, {"duration_seconds": 4}, {"duration_seconds": 3601},
            {"cycle_seconds": 0}, {"cycle_seconds": True}, {"cycle_seconds": "NaN"},
            {"volume": -1}, {"volume": 101}, {"sound_enabled": "yes"},
        ]:
            self.assertEqual(self.request("PUT", "/api/admin/live-news", payload, admin=True)[0], 422)
        self.assertEqual(self.request("PATCH", "/api/admin/live-news", {"enabled": True}, admin=True)[0], 422)
        self.assertEqual(self.store.read().revision, 0)

    def test_duration_expires_without_browser_or_write_and_can_restart(self):
        _, state, _ = self.request("PUT", "/api/admin/live-news", {
            "message": "Nur kurz live", "enabled": True, "playback_mode": "duration",
            "duration_seconds": 5, "sound_enabled": False, "volume": 35,
        }, admin=True)
        start = datetime.fromisoformat(state["updated_at"])
        self.assertEqual(datetime.fromisoformat(state["ends_at"]) - start, timedelta(seconds=5))
        with patch("app.live_news.datetime", wraps=datetime) as clock:
            clock.now.return_value = start + timedelta(seconds=6)
            self.assertFalse(self.request("GET", "/api/live-news")[1]["enabled"])
            self.assertFalse(LiveNewsStore(self.store.path).read().enabled)
            _, restarted, _ = self.request("PATCH", "/api/admin/live-news", {"enabled": True}, admin=True)
        self.assertTrue(restarted["enabled"])
        self.assertEqual(restarted["playback_mode"], "duration")
        self.assertEqual(restarted["duration_seconds"], 5)
        self.assertFalse(restarted["sound_enabled"])
        self.assertEqual(restarted["volume"], 35)
        self.assertGreater(restarted["ends_at"], state["ends_at"])

    def test_exact_loop_deadline_identical_republish_and_legacy_migration(self):
        settings = LiveNewsSettings(message="Zweimal", enabled=True, repeat_count=2, cycle_seconds=7.5)
        state = self.store.write(settings)
        start = datetime.fromisoformat(state.updated_at)
        self.assertEqual(datetime.fromisoformat(state.ends_at) - start, timedelta(seconds=15))
        with patch("app.live_news.datetime", wraps=datetime) as clock:
            clock.now.return_value = start + timedelta(seconds=14.99)
            self.assertTrue(self.store.read().enabled)
            clock.now.return_value = start + timedelta(seconds=15)
            self.assertFalse(self.store.read().enabled)
            again = self.store.write(settings)
            self.assertEqual(again.revision, state.revision + 1)
            self.assertTrue(again.enabled)
            self.assertGreater(again.ends_at, state.ends_at)
        self.store.path.write_text(json.dumps({
            "message": "Alte Nachricht", "enabled": True,
            "updated_at": (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat(),
        }), encoding="utf-8")
        legacy = self.store.read()
        self.assertFalse(legacy.enabled)
        self.assertEqual(legacy.repeat_count, 3)
        self.assertTrue(legacy.ends_at)

    def test_atomic_concurrent_writes_and_corrupt_storage(self):
        with ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(lambda index: self.store.write(LiveNewsSettings(message=f"News {index}")), range(25)))
        self.assertEqual(self.store.read().revision, 25)
        self.assertEqual(list(self.store.path.parent.iterdir()), [self.store.path])
        self.store.path.write_text("broken", encoding="utf-8")
        with self.assertLogs("app.live_news", level="ERROR"):
            self.assertEqual(self.request("GET", "/api/live-news")[0], 503)
        with self.assertRaises(ValidationError):
            self.store.write(LiveNewsSettings(message="Do not overwrite corrupted state"))
        self.assertEqual(self.store.path.read_text(), "broken")


if __name__ == "__main__":
    unittest.main()
