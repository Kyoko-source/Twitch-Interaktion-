import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient

from app import auth, main
from app.economy import EconomyStore


class DefenseScoreTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.directory.name) / "ledger.sqlite3")
        self.store.mark_ready(["alice"])
        main.app.dependency_overrides[auth.current_user] = lambda: {"username": "alice"}
        self.client = TestClient(main.app)

    def tearDown(self):
        main.app.dependency_overrides.clear()
        self.directory.cleanup()

    def test_chicken_defense_runs_pay_chickens_and_list_scores_without_a_supabase_table(self):
        def no_supabase(*args, **kwargs):
            raise AssertionError("chicken-defense must not query Supabase score tables")

        with patch.object(main, "economy", return_value=self.store), patch.object(main, "rows", side_effect=no_supabase), \
                patch("app.economy.time.time", return_value=1000):
            run = self.store.start_run("alice", "chicken-defense", now=1000)
            with patch("app.economy.time.time", return_value=1300):
                result = self.client.post("/api/scores", json={"game": "chicken-defense", "run_id": run["run_id"], "score": 12000, "level": 9, "kills": 140, "seconds_survived": 300})
            self.assertEqual(result.status_code, 200, result.text)
            self.assertEqual(result.json()["wallet"]["chickens"], 25)
            board = self.client.get("/api/scores/chicken-defense").json()
        self.assertEqual(board[0]["username"], "alice")
        self.assertEqual(board[0]["score"], 12000)


if __name__ == "__main__":
    unittest.main()
