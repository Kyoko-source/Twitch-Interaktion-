import random
import tempfile
import unittest
from pathlib import Path

from fastapi import FastAPI, Header
from fastapi.testclient import TestClient

from app import auth, ratelimit, slots
from app.economy import EconomyStore


def grid_from_rows(rows):
    """rows[row][reel] -> grid[reel][row]"""
    return [[rows[r][c] for r in range(3)] for c in range(5)]


class SlotTests(unittest.TestCase):
    def setUp(self):
        ratelimit.reset()
        self.folder = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.folder.name) / "economy.sqlite3")
        self.store.mark_ready(["alice", "bob"])
        self.store.adjust("alice", 500)
        self._economy, self._draw = slots.economy, slots.draw
        slots.economy = lambda: self.store
        app = FastAPI(); app.include_router(slots.router)

        def fake(x_test_user: str = Header()):
            return {"username": x_test_user}
        app.dependency_overrides[auth.current_user] = fake
        self.client = TestClient(app)
        self.n = 0

    def tearDown(self):
        slots.economy, slots.draw = self._economy, self._draw
        self.folder.cleanup()

    def spin(self, user="alice", bet=10, request_id=None):
        self.n += 1
        return self.client.post("/api/slots/spin", headers={"X-Test-User": user}, json={"bet": bet, "request_id": request_id or f"req-{self.n:04d}-abcdefghijkl"})

    def test_line_wins_wilds_and_scatter(self):
        grid = grid_from_rows([
            ["lemon", "bell", "grape", "egg", "cherry"],
            ["seven", "wild", "seven", "seven", "bar"],
            ["egg", "cherry", "lemon", "grape", "egg"],
        ])
        result = slots.evaluate(grid, 10)
        middle = next(w for w in result["wins"] if w["line"] == 0)
        self.assertEqual((middle["symbol"], middle["count"]), ("seven", 4))
        self.assertEqual(result["scatter"]["count"], 3)
        self.assertEqual(result["win"], int(10 * sum(w["mult"] for w in result["wins"]) + 10 * 2))
        self.assertGreaterEqual(result["win"], 220)
        wild_run = slots.evaluate(grid_from_rows([["wild"] * 5, ["cherry", "lemon", "grape", "bell", "bar"], ["lemon", "grape", "bell", "bar", "cherry"]]), 2)
        self.assertEqual(wild_run["wins"][0]["symbol"], "wild")
        self.assertGreaterEqual(wild_run["win"], 600)  # 5 wilds on the middle line = 300x (plus any side lines)

    def test_return_to_player_is_a_soft_sink(self):
        rng = random.Random(4)
        n, paid = 60_000, 0.0
        for _ in range(n):
            paid += slots.evaluate(slots.draw(rng), 10)["multiplier"]
        self.assertGreater(paid / n, 0.88)
        self.assertLess(paid / n, 0.98)

    def test_spin_moves_chickens_and_is_idempotent(self):
        slots.draw = lambda rng=None: [["seven", "cherry", "lemon"], ["seven", "bell", "bar"], ["seven", "cherry", "lemon"], ["seven", "bell", "bar"], ["seven", "cherry", "lemon"]]
        data = self.spin(bet=10, request_id="same-request-0001-aaaa").json()
        self.assertGreaterEqual(data["win"], 750)
        self.assertEqual(data["wallet"]["chickens"], 500 - 10 + data["win"])
        again = self.spin(bet=10, request_id="same-request-0001-aaaa").json()
        self.assertTrue(again["duplicate"])
        self.assertEqual(again["wallet"]["chickens"], data["wallet"]["chickens"], "replayed request must not pay twice")
        self.assertEqual(self.store.wallet_history("alice")["transactions"][0]["kind"], "slots")

    def test_bets_balance_and_daily_cap(self):
        self.assertEqual(self.spin(bet=7).status_code, 400)
        self.assertEqual(self.spin(user="bob", bet=2).status_code, 400, "bob has no Chickens")
        slots.draw = lambda rng=None: grid_from_rows([["wild"] * 5] * 3)
        first = self.spin(bet=2)
        self.assertEqual(first.status_code, 200)
        self.assertGreaterEqual(first.json()["today"]["net"], slots.DAILY_NET_WIN_CAP)
        self.assertEqual(self.spin(bet=2).status_code, 429)

    def test_losing_spin_only_costs_the_bet(self):
        # Reel 1 and reel 2 share no symbol, so no line can reach three in a row.
        slots.draw = lambda rng=None: [["cherry", "lemon", "grape"], ["bell", "bar", "seven"], ["cherry", "lemon", "grape"], ["bell", "bar", "seven"], ["cherry", "lemon", "grape"]]
        data = self.spin(bet=20).json()
        self.assertEqual(data["win"], 0)
        self.assertEqual(data["wallet"]["chickens"], 480)
        self.assertEqual(data["today"]["net"], -20)


if __name__ == "__main__":
    unittest.main()
