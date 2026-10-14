import asyncio
import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
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
        ]:
            self.assertEqual(self.request("PUT", "/api/admin/live-news", payload, admin=True)[0], 422)
        self.assertEqual(self.request("PATCH", "/api/admin/live-news", {"enabled": True}, admin=True)[0], 422)
        self.assertEqual(self.store.read().revision, 0)

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
