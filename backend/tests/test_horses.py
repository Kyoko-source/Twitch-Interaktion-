import random
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from fastapi import FastAPI, Header
from fastapi.testclient import TestClient

from app import auth, horses, ratelimit
from app.economy import EconomyStore


def position(race, horse, t):
    """Laps covered by `horse` at race time t, as the client computes it."""
    shape, finish = race["shapes"][horse], race["finish"][horse]
    u = min(1.0, t / finish) * (len(shape) - 1)
    i = min(int(u), len(shape) - 2)
    return race["laps"] * (shape[i] + (shape[i + 1] - shape[i]) * (u - i))


class HorseRaceTests(unittest.TestCase):
    def setUp(self):
        # Level-up payouts are covered in test_xp; here balances must stay exact.
        self._no_level_rewards = patch('app.xp.rewards_for', return_value={'chickens': 0, 'credits': 0})
        self._no_level_rewards.start()
        self.addCleanup(self._no_level_rewards.stop)
        ratelimit.reset()
        self.folder = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.folder.name) / "economy.sqlite3")
        self.store.mark_ready(["alice", "bob"])
        with self.store.connection(write=True) as db:
            db.execute("INSERT OR IGNORE INTO wallets(username) VALUES ('alice')")
            db.execute("UPDATE wallets SET credits=120 WHERE username='alice'")
        self._economy, self._race = horses.economy, horses.race
        horses.economy = lambda: self.store
        app = FastAPI(); app.include_router(horses.router)

        def fake(x_test_user: str = Header()):
            return {"username": x_test_user}
        app.dependency_overrides[auth.current_user] = fake
        self.client = TestClient(app)
        self.n = 0

    def tearDown(self):
        horses.economy, horses.race = self._economy, self._race
        self.folder.cleanup()

    def bet(self, horse=3, user="alice", request_id=None):
        self.n += 1
        return self.client.post("/api/horses/race", headers={"X-Test-User": user}, json={"horse": horse, "request_id": request_id or f"race-{self.n:04d}-abcdefghijkl"})

    def credits(self, user="alice"):
        with self.store.connection() as db:
            return self.store.wallet(db, user)["credits"]

    def test_script_winner_crosses_first_and_order_is_consistent(self):
        rng = random.Random(7)
        for _ in range(200):
            race = horses.race(rng.randrange(9), rng)
            winner = race["winner"]
            self.assertEqual(race["order"][0], winner)
            self.assertEqual(sorted(race["order"]), list(range(9)))
            finish = race["finish"]
            self.assertEqual(sorted(range(9), key=lambda h: finish[h]), race["order"])
            for shape in race["shapes"]:
                self.assertEqual(len(shape), horses.SEGMENTS + 1)
                self.assertEqual((shape[0], shape[-1]), (0.0, 1.0))
                self.assertTrue(all(b > a for a, b in zip(shape, shape[1:])))
            # Nobody has finished when the winner crosses the line.
            for h in range(9):
                if h != winner:
                    self.assertLess(position(race, h, finish[winner]), race["laps"])

    def test_races_have_lead_changes(self):
        rng = random.Random(11)
        changes = []
        for _ in range(100):
            race = horses.race(0, rng)
            leaders = [max(range(9), key=lambda h: position(race, h, t / 4)) for t in range(8, int(race["finish"][race["winner"]] * 4))]
            changes.append(sum(a != b for a, b in zip(leaders, leaders[1:])))
        self.assertGreater(sum(changes) / len(changes), 2)

    def test_winner_is_uniform(self):
        rng = random.Random(3)
        counts = [0] * 9
        for _ in range(9000):
            counts[horses.race(0, rng)["winner"]] += 1
        self.assertTrue(all(850 < c < 1150 for c in counts), counts)

    def test_win_doubles_stake_and_loss_costs_it(self):
        def fixed(winner):
            def scripted(chosen, rng=None):
                result = self._race(chosen, random.Random(1))
                order = [winner] + [h for h in result["order"] if h != winner]
                finish = sorted(result["finish"])
                return {**result, "winner": winner, "order": order, "finish": [finish[order.index(h)] for h in range(9)]}
            return scripted

        horses.race = fixed(3)
        win = self.bet(horse=3).json()
        self.assertTrue(win["won"])
        self.assertEqual((win["payout"], win["place"]), (100, 1))
        self.assertEqual(self.credits(), 120 - 50 + 100)
        horses.race = fixed(5)
        loss = self.bet(horse=3).json()
        self.assertFalse(loss["won"])
        self.assertEqual(loss["payout"], 0)
        self.assertGreater(loss["place"], 1)
        self.assertEqual(self.credits(), 120)
        stats = self.client.get("/api/horses", headers={"X-Test-User": "alice"}).json()["stats"]
        self.assertEqual((stats["races"], stats["won"]), (2, 1))
        self.assertEqual(stats["wins"], [0, 0, 0, 1, 0, 1, 0, 0, 0])
        self.assertAlmostEqual(stats["chance"], 1 / 9, places=4)

    def test_needs_fifty_credits(self):
        with self.store.connection(write=True) as db:
            db.execute("UPDATE wallets SET credits=49 WHERE username='alice'")
        response = self.bet()
        self.assertEqual(response.status_code, 402)
        self.assertEqual(self.credits(), 49)

    def test_request_id_books_once_and_belongs_to_one_player(self):
        first = self.bet(request_id="same-race-request-0001").json()
        again = self.bet(request_id="same-race-request-0001").json()
        self.assertTrue(again["duplicate"])
        self.assertEqual(first["winner"], again["winner"])
        self.assertEqual(self.credits(), 120 - 50 + first["payout"])
        with self.store.connection(write=True) as db:
            db.execute("INSERT OR IGNORE INTO wallets(username) VALUES ('bob')")
            db.execute("UPDATE wallets SET credits=100 WHERE username='bob'")
        self.assertEqual(self.bet(user="bob", request_id="same-race-request-0001").status_code, 409)

    def test_live_feed_is_public_and_lists_recent_races(self):
        first = self.bet(horse=4).json()
        self.bet(horse=7)
        feed = self.client.get("/api/horses/live").json()
        self.assertEqual(len(feed["races"]), 2)
        race = feed["races"][0]
        self.assertEqual((race["username"], race["horse"], race["winner"], race["laps"]), ("alice", 4, first["winner"], 5))
        self.assertEqual(len(race["shapes"]), 9)
        self.assertNotIn("request_id", race)
        self.assertEqual(race["flair"], {"crown": False, "champion": False, "phoenix": False})
        self.assertLess(feed["races"][0]["id"], feed["races"][1]["id"])
        with self.store.connection(write=True) as db:
            db.execute("UPDATE horse_races SET created = created - ?", (horses.LIVE_WINDOW + 5,))
        self.assertEqual(self.client.get("/api/horses/live").json()["races"], [])

    def test_invalid_horse_and_info(self):
        self.assertEqual(self.bet(horse=9).status_code, 422)
        self.bet(horse=1)
        info = self.client.get("/api/horses", headers={"X-Test-User": "alice"}).json()
        self.assertEqual((info["stake"], info["payout"], len(info["horses"])), (50, 100, 9))
        self.assertEqual(len(info["recent"]), 1)


if __name__ == "__main__":
    unittest.main()
