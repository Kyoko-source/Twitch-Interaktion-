import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app import auth, config, main, ratelimit


class SettingsTests(unittest.TestCase):
    def test_no_published_defaults(self):
        with patch.dict("os.environ", {}, clear=True):
            settings = config.Settings()
        self.assertEqual(settings.admin_password, "")
        self.assertNotEqual(settings.jwt_secret, "change-me-in-production")
        self.assertGreaterEqual(len(settings.jwt_secret), 32)

    def test_known_weak_admin_password_is_rejected(self):
        with patch.dict("os.environ", {"AVIARY_ADMIN_PASSWORD": "einsmarello", "AVIARY_JWT_SECRET": "x" * 40}, clear=True):
            self.assertEqual(config.Settings().admin_password, "")
        with patch.dict("os.environ", {"AVIARY_ADMIN_PASSWORD": "a-long-private-pass", "AVIARY_JWT_SECRET": "x" * 40}, clear=True):
            settings = config.Settings()
        self.assertEqual((settings.admin_password, settings.jwt_secret), ("a-long-private-pass", "x" * 40))


class GuardTests(unittest.TestCase):
    def setUp(self):
        ratelimit.reset()
        self.client = TestClient(main.app)

    def tearDown(self):
        ratelimit.reset()
        main.app.dependency_overrides.clear()

    def test_admin_disabled_without_configured_password(self):
        with patch("app.auth.get_settings", return_value=SimpleNamespace(admin_password="")):
            response = self.client.get("/api/admin/purchase-alerts", headers={"X-Admin-Password": ""})
        self.assertEqual(response.status_code, 403)

    def test_admin_password_guessing_is_throttled_per_client(self):
        with patch("app.auth.get_settings", return_value=SimpleNamespace(admin_password="correct-horse-battery")):
            me = {"X-Forwarded-For": "203.0.113.7, 172.18.0.5"}
            codes = [self.client.get("/api/admin/purchase-alerts", headers={**me, "X-Admin-Password": f"guess{i}"}).status_code for i in range(auth.ADMIN_FAIL_LIMIT + 1)]
            self.assertEqual(codes[:-1], [403] * auth.ADMIN_FAIL_LIMIT)
            self.assertEqual(codes[-1], 429)
            # Even the right password waits out the lock; other clients are unaffected.
            self.assertEqual(self.client.get("/api/admin/purchase-alerts", headers={**me, "X-Admin-Password": "correct-horse-battery"}).status_code, 429)
            other = {"X-Forwarded-For": "198.51.100.9, 172.18.0.5", "X-Admin-Password": "wrong"}
            self.assertEqual(self.client.get("/api/admin/purchase-alerts", headers=other).status_code, 403)

    def test_login_failures_are_throttled_and_legacy_hash_upgraded(self):
        legacy = auth.hashlib.sha256(f"pw-123456{auth.LEGACY_PASSWORD_SALT}".encode()).hexdigest()
        db = MagicMock()
        economy = MagicMock()
        economy.access.return_value = {"banned": False, "session_version": 0, "reason": ""}
        economy.balance.return_value = {}
        with patch.object(main, "single_user", return_value={"username": "alice", "password_hash": legacy}), \
             patch.object(main, "supabase", return_value=db), patch.object(main, "economy", return_value=economy), \
             patch("app.auth.economy", return_value=economy), patch.object(main, "user_role", return_value="member"):
            ok = self.client.post("/api/auth/login", json={"username": "alice", "password": "pw-123456"})
            self.assertEqual(ok.status_code, 200)
            path, payload = db.patch.call_args.args
            self.assertEqual(path, "users?username=eq.alice")
            self.assertTrue(payload["password_hash"].startswith("$pbkdf2-sha256$"))
            codes = [self.client.post("/api/auth/login", json={"username": "alice", "password": "nope"}).status_code for _ in range(main.LOGIN_FAIL_LIMIT + 1)]
        self.assertEqual(codes[-2:], [401, 429])

    def test_chat_storage_survives_corruption_and_keeps_private_history(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "chat.json"
            with patch.object(main, "CHAT_MESSAGES_FILE", file), patch.object(main, "CHAT_GLOBAL_KEEP", 3):
                main.store_chat_message("private", "alice", "secret", "bob")
                for i in range(10):
                    main.store_chat_message("global", "bob", f"hi {i}")
                stored = json.loads(file.read_text(encoding="utf-8"))
                self.assertEqual([m["body"] for m in stored], ["secret", "hi 7", "hi 8", "hi 9"])
                file.write_text("{broken", encoding="utf-8")
                with self.assertRaises(Exception):
                    main.store_chat_message("global", "bob", "would wipe")
                self.assertEqual(file.read_text(encoding="utf-8"), "{broken")


if __name__ == "__main__":
    unittest.main()
