import asyncio
import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch, MagicMock
from uuid import uuid4

from fastapi import HTTPException
from pydantic import ValidationError

from app.economy import EconomyStore, SCORE_DIVISORS
from app import main, purchase_alerts, migrate_chickens
from app.auth import current_user


class EconomyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.directory.name) / "economy.sqlite3")
        self.store.mark_ready(["alice", "bob"])
        self.item = {"id": 4, "name": "3 Squats", "category": "Bestrafungs Ideen", "price": 150}

    def tearDown(self):
        self.directory.cleanup()

    def run_score(self, game="chicken-jump", username="alice", start=100000, seconds=300, score=100000):
        run = self.store.start_run(username, game, now=start)
        return self.store.complete_run(username, game, run["run_id"], {"score": score}, now=start + seconds)

    def test_all_games_credit_only_chickens_and_time_and_score_bound_rewards(self):
        for index, (game, divisor) in enumerate(SCORE_DIVISORS.items()):
            result = self.run_score(game, start=100000 + index * 1000, seconds=35, score=divisor * 10)
            self.assertEqual(result["chickens_awarded"], 3)
        self.assertEqual(self.store.balance("alice")["chickens"], 12)
        self.assertEqual(self.store.balance("alice")["chickens_earned"], 12)
        self.assertEqual(self.run_score(seconds=14)["chickens_awarded"], 0)
        self.assertEqual(self.run_score(seconds=30, score=99)["chickens_awarded"], 0)

    def test_repeat_submission_is_idempotent_and_tampering_cannot_recredit(self):
        run = self.store.start_run("alice", "chicken-jump", now=100000)["run_id"]
        result = self.store.complete_run("alice", "chicken-jump", run, {"score": 10000}, now=100300)
        self.assertEqual(result["chickens_awarded"], 25)
        repeated = self.store.complete_run("alice", "chicken-jump", run, {"score": 10000}, now=100301)
        self.assertEqual(repeated["chickens_awarded"], 0)
        self.assertTrue(repeated["duplicate"])
        with self.assertRaises(HTTPException):
            self.store.complete_run("alice", "chicken-jump", run, {"score": 99999}, now=100302)
        self.assertEqual(len(self.store.scores("chicken-jump")), 1)

    def test_daily_limit_resets_on_new_utc_day(self):
        rewards = [self.run_score(start=100000 + i * 400)["chickens_awarded"] for i in range(6)]
        self.assertEqual(rewards, [25, 25, 25, 25, 20, 0])
        self.assertEqual(self.run_score(start=200000)["chickens_awarded"], 25)

    def test_other_user_old_round_expired_round_and_false_survival_rejected(self):
        first = self.store.start_run("alice", "chicken-jump", now=1000)["run_id"]
        self.store.start_run("alice", "chicken-snake", now=1001)
        with self.assertRaises(HTTPException):
            self.store.complete_run("alice", "chicken-jump", first, {"score": 10000}, now=1300)
        current = self.store.start_run("alice", "braincell-survivor", now=1000)["run_id"]
        for username, now, payload in [("bob", 1300, {"score": 1000}), ("alice", 9000, {"score": 1000}), ("alice", 1300, {"score": 1000, "seconds_survived": 400})]:
            with self.assertRaises(HTTPException):
                self.store.complete_run(username, "braincell-survivor", current, payload, now=now)

    def test_purchase_and_alert_are_atomic_duplicate_safe_and_persisted(self):
        self.store.adjust("alice", 500)
        key = str(uuid4())
        result = self.store.buy("alice", self.item, key, now=1000)
        self.assertEqual(result["wallet"]["chickens"], 350)
        self.assertTrue(result["stream_alert"])
        self.store.buy("alice", self.item, key, now=1001)
        self.assertEqual(self.store.balance("alice")["chickens"], 350)
        reopened = EconomyStore(self.store.path)
        self.assertEqual(len(reopened.recent_purchases()), 1)
        event = reopened.alerts(now=1001)["events"][0]
        self.assertEqual((event["username"], event["item_name"], event["price"]), ("alice", "3 Squats", 150))
        self.assertEqual(reopened.alerts(now=1010)["events"], [])
        self.assertFalse(reopened.mark_ready(["alice"]))
        self.assertEqual(reopened.balance("alice")["chickens"], 350)

    def test_insufficient_funds_and_rolled_back_alert_create_nothing(self):
        with self.assertRaises(HTTPException):
            self.store.buy("alice", self.item, str(uuid4()), now=1000)
        self.assertEqual(self.store.recent_purchases(), [])
        self.assertEqual(self.store.alerts(now=1000)["events"], [])
        self.store.adjust("alice", 500)
        with patch.object(self.store, "_settings", side_effect=RuntimeError("storage failed")):
            with self.assertRaises(RuntimeError):
                self.store.buy("alice", self.item, str(uuid4()), now=1000)
        self.assertEqual(self.store.balance("alice")["chickens"], 500)
        self.assertEqual(self.store.recent_purchases(), [])

    def test_concurrent_purchases_never_overspend_and_queue_never_overlaps(self):
        self.store.adjust("alice", 300)
        def buy(index):
            try:
                return self.store.buy("alice", self.item, f"purchase-request-{index}", now=1000)
            except HTTPException as error:
                return error.status_code
        with ThreadPoolExecutor(max_workers=8) as pool:
            result = list(pool.map(buy, range(8)))
        self.assertEqual(sum(isinstance(row, dict) for row in result), 2)
        self.assertEqual(self.store.balance("alice")["chickens"], 0)
        events = self.store.alerts(now=1000)["events"]
        self.assertEqual(len(events), 2)
        self.assertGreater(events[1]["starts"], events[0]["ends"])

    def test_non_punishment_has_no_alert_and_styles_cannot_be_bought_twice(self):
        self.store.adjust("alice", 1000)
        item = {"id": "chat-style", "name": "Chat Animation", "category": "Chat Animation", "price": 300, "style": "sparkle"}
        self.store.buy("alice", item, str(uuid4()), now=1000)
        with self.assertRaises(HTTPException):
            self.store.buy("alice", item, str(uuid4()), now=1001)
        self.assertEqual(self.store.alerts(now=1000)["events"], [])
        self.assertEqual(self.store.balance("alice")["chickens"], 700)

    def test_reset_is_backed_up_repeat_safe_and_prices_not_retripled(self):
        store = EconomyStore(Path(self.directory.name) / "fresh.sqlite3")
        client = MagicMock()
        users = [{"username": "alice", "chickens": 9999, "braincells": 50}]
        client.get.side_effect = [users, [self.item], []]
        backup = Path(self.directory.name) / "backup.json"
        with patch.object(migrate_chickens, "economy", return_value=store), patch.object(migrate_chickens, "supabase", return_value=client), patch.dict("os.environ", {"CHICKEN_RESET_BACKUP": str(backup)}):
            migrate_chickens.migrate(apply=True)
            migrate_chickens.migrate(apply=True)
        self.assertEqual(json.loads(backup.read_text())["users"][0]["chickens"], 9999)
        self.assertEqual(store.balance("alice")["chickens"], 0)
        self.assertEqual(client.patch.call_count, 2)
        self.assertEqual(client.patch.call_args_list[0].args[1], {"price": 450})

    def test_api_authorization_validation_and_retired_currency(self):
        for score in [-1, True, 1.5, 1000000001]:
            with self.assertRaises(ValidationError):
                main.ScoreCreate(game="chicken-jump", run_id=str(uuid4()), score=score)
        with patch.object(main, "economy", return_value=self.store):
            user = main.public_user({"username": "alice", "braincells": 9999, "chickens": 9999, "password_hash": "secret"})
        self.assertNotIn("braincells", user)
        self.assertNotIn("password_hash", user)
        self.assertEqual(user["chickens"], 0)
        with self.assertRaises(HTTPException) as caught:
            main.daily_reward({"username": "alice"})
        self.assertEqual(caught.exception.status_code, 410)
        for path in ["/api/game-runs", "/api/shop/purchase", "/api/scores"]:
            self.assertEqual(self.request("POST", path, {})[0], 401)
        self.assertEqual(self.request("PUT", "/api/admin/purchase-alerts", {"duration_seconds": 10})[0], 403)
        with patch.object(purchase_alerts, "economy", return_value=self.store):
            status, state = self.request("GET", "/api/purchase-alerts")
        self.assertEqual(status, 200)
        self.assertEqual(state["events"], [])

    def test_http_round_credit_purchase_and_public_alert_use_the_same_wallet(self):
        main.app.dependency_overrides[current_user] = lambda: {"username": "alice", "chickens": 99999}
        try:
            with patch.object(main, "economy", return_value=self.store), patch.object(purchase_alerts, "economy", return_value=self.store), patch.object(main, "rows", return_value=[self.item]):
                request = {"item_id": "4", "request_id": str(uuid4())}
                self.assertEqual(self.request("POST", "/api/shop/purchase", request)[0], 400)
                with patch("app.economy.time.time", return_value=1000):
                    status, run = self.request("POST", "/api/game-runs", {"game": "chicken-jump"})
                self.assertEqual(status, 200)
                with patch("app.economy.time.time", return_value=1300):
                    status, result = self.request("POST", "/api/scores", {"game": "chicken-jump", "run_id": run["run_id"], "score": 10000})
                self.assertEqual(status, 200)
                self.assertEqual(result["chickens_awarded"], 25)
                self.store.adjust("alice", 125)
                status, result = self.request("POST", "/api/shop/purchase", request)
                self.assertEqual(status, 200)
                self.assertEqual(result["wallet"]["chickens"], 0)
                status, repeated = self.request("POST", "/api/shop/purchase", request)
                self.assertEqual(status, 200)
                self.assertTrue(repeated["duplicate"])
                status, alerts = self.request("GET", "/api/purchase-alerts")
                self.assertEqual(status, 200)
                self.assertEqual(len(alerts["events"]), 1)
                self.assertEqual(alerts["events"][0]["username"], "alice")
        finally:
            main.app.dependency_overrides.clear()

    @staticmethod
    def request(method, path, payload=None):
        async def run():
            messages = []
            body = json.dumps(payload).encode() if payload is not None else b""
            async def receive():
                return {"type": "http.request", "body": body, "more_body": False}
            async def send(message):
                messages.append(message)
            await main.app({"type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1", "method": method, "scheme": "http", "path": path, "raw_path": path.encode(), "query_string": b"", "root_path": "", "headers": [(b"content-type", b"application/json")], "server": ("test", 80), "client": ("test", 1)}, receive, send)
            status = next(message["status"] for message in messages if message["type"] == "http.response.start")
            content = b"".join(message.get("body", b"") for message in messages if message["type"] == "http.response.body")
            return status, json.loads(content)
        return asyncio.run(run())


if __name__ == "__main__":
    unittest.main()
