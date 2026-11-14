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
        with self.store.connection(write=True) as db:
            db.execute("UPDATE wallets SET credits=50 WHERE username=?", ("alice",))
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
        self.assertEqual(result["win"], int(10 * slots.GSC_PER_CREDIT * (sum(w["mult"] for w in result["wins"]) + slots.SCATTER[3])))
        self.assertEqual(result["scatter"]["free_spins"], 8)
        wild_run = slots.evaluate(grid_from_rows([["wild"] * 5, ["cherry", "lemon", "grape", "bell", "bar"], ["lemon", "grape", "bell", "bar", "cherry"]]), 2)
        self.assertEqual(wild_run["wins"][0]["symbol"], "wild")
        self.assertGreaterEqual(wild_run["win"], 2 * slots.GSC_PER_CREDIT * slots.PAY["wild"][2])  # 5 wilds on the middle line

    def test_return_to_player_including_the_egg_bonus_is_a_soft_sink(self):
        rng = random.Random(4)
        n, paid, bonuses = 120_000, 0, 0
        for _ in range(n):
            result = slots.play(1, rng)
            paid += result["win"]
            bonuses += result["bonus"] is not None
        rtp = paid / (n * slots.GSC_PER_CREDIT)
        self.assertGreater(rtp, 0.86)
        self.assertLess(rtp, 1.0)
        self.assertGreater(bonuses, n / 120, "the Egg Bonus must come around regularly")

    def test_egg_bonus_triples_wins_counts_retriggers_and_respects_the_cap(self):
        three_eggs = grid_from_rows([["egg", "cherry", "egg", "lemon", "egg"], ["bell", "bar", "grape", "lemon", "cherry"], ["grape", "lemon", "bell", "cherry", "bar"]])
        sevens = grid_from_rows([["seven"] * 5, ["cherry", "lemon", "grape", "bell", "bar"], ["lemon", "grape", "bell", "bar", "cherry"]])
        tripled = slots.evaluate(sevens, 1, slots.FREE_MULT)
        self.assertEqual(tripled["win"], int(slots.GSC_PER_CREDIT * slots.PAY["seven"][2] * slots.FREE_MULT))
        draws = iter([three_eggs] + [three_eggs] * 10 + [sevens] * 100)
        original = slots.draw
        slots.draw = lambda rng=None: next(draws)
        try:
            result = slots.play(2)
        finally:
            slots.draw = original
        bonus = result["bonus"]
        self.assertEqual(bonus["awarded"], slots.FREE_CAP)
        self.assertEqual(len(bonus["spins"]), slots.FREE_CAP)
        self.assertEqual(result["win"], result["base_win"] + bonus["win"])
        self.assertEqual(bonus["spins"][0]["extra_spins"], 8)

    def test_spin_costs_credits_pays_gsc_and_is_idempotent(self):
        slots.draw = lambda rng=None: [["seven", "cherry", "lemon"], ["seven", "bell", "bar"], ["seven", "cherry", "lemon"], ["seven", "bell", "bar"], ["seven", "cherry", "lemon"]]
        data = self.spin(bet=2, request_id="same-request-0001-aaaa").json()
        self.assertGreaterEqual(data["win"], 2 * slots.GSC_PER_CREDIT * slots.PAY["seven"][2])
        self.assertEqual(data["wallet"]["credits"], 48)
        self.assertEqual(data["wallet"]["gsc"], data["win"])
        self.assertEqual(data["wallet"]["chickens"], 500, "slots never touch Chickens directly")
        again = self.spin(bet=2, request_id="same-request-0001-aaaa").json()
        self.assertTrue(again["duplicate"])
        self.assertEqual(again["wallet"]["gsc"], data["wallet"]["gsc"], "replayed request must not pay twice")
        self.assertEqual(again["wallet"]["credits"], 48)

    def test_bets_and_credit_balance(self):
        self.assertEqual(self.spin(bet=7).status_code, 400)
        self.assertEqual(self.spin(user="bob", bet=1).status_code, 402, "bob has no credits")

    def test_losing_spin_only_costs_credits(self):
        # Reel 1 and reel 2 share no symbol, so no line can reach three in a row.
        slots.draw = lambda rng=None: [["cherry", "lemon", "grape"], ["bell", "bar", "seven"], ["cherry", "lemon", "grape"], ["bell", "bar", "seven"], ["cherry", "lemon", "grape"]]
        data = self.spin(bet=5).json()
        self.assertEqual(data["win"], 0)
        self.assertEqual(data["wallet"]["credits"], 45)
        self.assertEqual(data["wallet"]["gsc"], 0)

if __name__ == "__main__":
    unittest.main()
