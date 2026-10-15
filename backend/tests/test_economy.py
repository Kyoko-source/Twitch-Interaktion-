import asyncio
import json
import sqlite3
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
            with patch.object(main, "economy", return_value=self.store), patch.object(purchase_alerts, "economy", return_value=self.store), patch.object(main, "rows", side_effect=lambda path: [{"score": 1000000}] if "select=score" in path else [self.item]):
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

    def test_highscore_compares_legacy_and_local_records_strictly_and_only_once(self):
        def submit(score, legacy=1000, start=100000):
            run = self.store.start_run("alice", "chicken-jump", now=start)["run_id"]
            return run, self.store.complete_run("alice", "chicken-jump", run, {"score": score}, now=start + 30, legacy_best=legacy)
        self.assertFalse(submit(900)[1]["is_highscore"])
        self.assertFalse(submit(1000)[1]["is_highscore"])
        run, result = submit(1001)
        self.assertTrue(result["is_highscore"])
        self.assertTrue(result["highscore_alert_queued"])
        self.assertIn("Neuer Highscore", result["message"])
        self.assertFalse(submit(1001)[1]["is_highscore"])
        self.assertFalse(submit(950)[1]["is_highscore"])
        duplicate = self.store.complete_run("alice", "chicken-jump", run, {"score": 1001}, now=100031, legacy_best=1000)
        self.assertTrue(duplicate["is_highscore"])
        self.assertFalse(duplicate["highscore_alert_queued"])
        self.assertEqual(duplicate["chickens_awarded"], 0)
        events = self.store.alerts(now=100030)["events"]
        self.assertEqual(len(events), 1)
        self.assertEqual((events[0]["username"], events[0]["kind"], events[0]["item_name"], events[0]["score"]), ("alice", "highscore", "Chicken Jump", 1001))

    def test_records_are_independent_per_game_and_unknown_legacy_is_not_announced(self):
        for index, game in enumerate(SCORE_DIVISORS):
            run = self.store.start_run("alice", game, now=100000)["run_id"]
            result = self.store.complete_run("alice", game, run, {"score": 100}, now=100030, legacy_best=0)
            self.assertTrue(result["is_highscore"])
        self.assertEqual(len(self.store.alerts(now=100030)["events"]), 4)
        run = self.store.start_run("bob", "chicken-jump", now=100000)["run_id"]
        result = self.store.complete_run("bob", "chicken-jump", run, {"score": 100000}, now=100030, legacy_best=None)
        self.assertFalse(result["is_highscore"])
        self.assertEqual(len(self.store.alerts(now=100030)["events"]), 4)

    def test_concurrent_tied_record_saves_only_schedule_one_announcement(self):
        runs = [(user, self.store.start_run(user, "chicken-jump", now=100000)["run_id"]) for user in ["alice", "bob"]]
        def submit(pair):
            user, run = pair
            return self.store.complete_run(user, "chicken-jump", run, {"score": 1000}, now=100030, legacy_best=500)
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(submit, runs))
        self.assertEqual(sum(result["is_highscore"] for result in results), 1)
        self.assertEqual(len(self.store.alerts(now=100030)["events"]), 1)

    def test_record_and_purchase_share_queue_and_failed_alert_rolls_back_score_and_reward(self):
        self.store.adjust("alice", 300)
        self.store.buy("alice", self.item, str(uuid4()), now=100030)
        run = self.store.start_run("alice", "chicken-jump", now=100000)["run_id"]
        with patch.object(self.store, "_settings", side_effect=RuntimeError("storage unavailable")):
            with self.assertRaises(RuntimeError):
                self.store.complete_run("alice", "chicken-jump", run, {"score": 2000}, now=100030, legacy_best=1000)
        self.assertEqual(self.store.balance("alice")["chickens"], 150)
        self.assertEqual(self.store.scores("chicken-jump"), [])
        self.store.complete_run("alice", "chicken-jump", run, {"score": 2000}, now=100030, legacy_best=1000)
        events = self.store.alerts(now=100030)["events"]
        self.assertEqual([event["kind"] for event in events], ["purchase", "highscore"])
        self.assertGreater(events[1]["starts"], events[0]["ends"])
        self.assertEqual(len(self.store.alerts(now=100030, include_highscores=False)["events"]), 1)

    def test_additive_schema_upgrade_preserves_wallets_and_existing_alerts(self):
        old_path = Path(self.directory.name) / "previous-ledger.sqlite3"
        with sqlite3.connect(old_path) as db:
            db.executescript("""
                CREATE TABLE wallets (username TEXT PRIMARY KEY, chickens INTEGER NOT NULL DEFAULT 0, earned INTEGER NOT NULL DEFAULT 0);
                INSERT INTO wallets VALUES ('alice', 42, 60);
                CREATE TABLE alerts (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id TEXT UNIQUE NOT NULL, username TEXT NOT NULL, item_name TEXT NOT NULL, category TEXT NOT NULL, price INTEGER NOT NULL, starts REAL NOT NULL, ends REAL NOT NULL);
                INSERT INTO alerts VALUES (1, 'old-purchase', 'alice', '3 Squats', 'Bestrafungs Ideen', 150, 1000, 1010);
                CREATE TABLE runs (id TEXT PRIMARY KEY, username TEXT NOT NULL, game TEXT NOT NULL, started REAL NOT NULL, completed REAL, score INTEGER, payload TEXT, reward INTEGER NOT NULL DEFAULT 0, reward_day TEXT);
            """)
        upgraded = EconomyStore(old_path)
        self.assertEqual(upgraded.balance("alice")["chickens"], 42)
        self.assertEqual(upgraded.balance("alice")["chickens_earned"], 60)
        self.assertEqual(upgraded.alerts(now=1001)["events"][0]["kind"], "purchase")
        EconomyStore(old_path)
        self.assertEqual(upgraded.balance("alice")["chickens"], 42)

    def test_http_record_history_failures_and_legacy_overlay_compatibility(self):
        main.app.dependency_overrides[current_user] = lambda: {"username": "alice"}
        try:
            with patch.object(main, "economy", return_value=self.store), patch.object(purchase_alerts, "economy", return_value=self.store):
                _, run = self.request("POST", "/api/game-runs", {"game": "chicken-jump"})
                with patch.object(main, "rows", return_value=[{"score": 1000}]):
                    status, result = self.request("POST", "/api/scores", {"game": "chicken-jump", "run_id": run["run_id"], "score": 1001})
                self.assertEqual(status, 200)
                self.assertTrue(result["highscore_alert_queued"])
                self.assertEqual(self.request("GET", "/api/purchase-alerts")[1]["events"], [])
                self.assertEqual(self.request("GET", "/api/purchase-alerts?include_highscores=true")[1]["events"][0]["kind"], "highscore")
                self.assertEqual(len(self.store.alerts()["events"]), 1)
                _, run = self.request("POST", "/api/game-runs", {"game": "chicken-snake"})
                with patch.object(main, "rows", side_effect=HTTPException(503, "offline")):
                    status, result = self.request("POST", "/api/scores", {"game": "chicken-snake", "run_id": run["run_id"], "score": 2000})
                self.assertEqual(status, 200)
                self.assertFalse(result["is_highscore"])
                self.assertEqual(len(self.store.scores("chicken-snake")), 1)
        finally:
            main.app.dependency_overrides.clear()

    @staticmethod
    def request(method, path, payload=None):
        path, _, query = path.partition("?")
        async def run():
            messages = []
            body = json.dumps(payload).encode() if payload is not None else b""
            async def receive():
                return {"type": "http.request", "body": body, "more_body": False}
            async def send(message):
                messages.append(message)
            await main.app({"type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1", "method": method, "scheme": "http", "path": path, "raw_path": path.encode(), "query_string": query.encode(), "root_path": "", "headers": [(b"content-type", b"application/json")], "server": ("test", 80), "client": ("test", 1)}, receive, send)
            status = next(message["status"] for message in messages if message["type"] == "http.response.start")
            content = b"".join(message.get("body", b"") for message in messages if message["type"] == "http.response.body")
            return status, json.loads(content)
        return asyncio.run(run())


if __name__ == "__main__":
    unittest.main()
