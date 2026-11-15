import tempfile
import unittest
from pathlib import Path

from app import xp
from app.economy import EconomyStore

DAY = 86400


class LevelTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.folder.name) / "economy.sqlite3")
        self.store.mark_ready(["alice", "bob"])

    def tearDown(self):
        self.folder.cleanup()

    def test_curve_titles_and_rewards(self):
        self.assertEqual(xp.level_for(0), (1, 0, 100))
        self.assertEqual(xp.level_for(99)[0], 1)
        self.assertEqual(xp.level_for(100), (2, 0, 140))
        self.assertEqual(xp.level_for(100 + 140 + 30), (3, 30, 180))
        self.assertEqual(xp.title_for(1), "Küken")
        self.assertEqual(xp.title_for(12), "Federheld")
        self.assertEqual(xp.rewards_for(4), {"chickens": 18, "credits": 2})
        self.assertEqual(xp.rewards_for(5), {"chickens": 70, "credits": 12})
        self.assertEqual(xp.unlocks_for(10), ["derby-crown", "jump-golden"])

    def test_award_levels_up_pays_rewards_and_is_idempotent(self):
        with self.store.connection(write=True) as db:
            first = xp.award(db, "alice", "bonus", 250, ref="a1", now=1000)
            again = xp.award(db, "alice", "bonus", 250, ref="a1", now=1000)
        self.assertEqual(first["amount"], 250)
        self.assertEqual([l["level"] for l in first["levelups"]], [2, 3])
        self.assertEqual(again["amount"], 0)
        wallet = self.store.balance("alice")
        self.assertEqual(wallet["level"], 3)
        self.assertEqual(wallet["chickens"], xp.rewards_for(2)["chickens"] + xp.rewards_for(3)["chickens"])
        self.assertEqual(wallet["credits"], 4)
        self.assertEqual(wallet["level_title"], "Junghenne")

    def test_daily_caps_per_source(self):
        with self.store.connection(write=True) as db:
            total = sum(xp.award(db, "alice", "chat", 3, ref=f"c{i}", now=1000)["amount"] for i in range(30))
            later = xp.award(db, "alice", "chat", 3, ref="next-day", now=1000 + DAY)["amount"]
        self.assertEqual(total, xp.CAPS["chat"])
        self.assertEqual(later, 3)

    def test_daily_login_streak(self):
        with self.store.connection(write=True) as db:
            d1 = xp.daily(db, "alice", now=1000)
            same = xp.daily(db, "alice", now=1000 + 60)
            d2 = xp.daily(db, "alice", now=1000 + DAY)
            gap = xp.daily(db, "alice", now=1000 + 4 * DAY)
        self.assertEqual((d1["amount"], d1["streak"]), (20, 1))
        self.assertEqual(same["amount"], 0)
        self.assertEqual((d2["amount"], d2["streak"]), (25, 2))
        self.assertEqual(gap["streak"], 1)

    def test_every_fifth_level_is_announced_in_the_stream(self):
        with self.store.connection(write=True) as db:
            xp.award(db, "bob", "bonus", sum(xp.need(l) for l in range(1, 5)), ref="b", now=1000, queue_alert=self.store._queue_alert)
        events = self.store.alerts(now=1000)["events"]
        self.assertEqual([(e["kind"], e["item_name"], e["username"]) for e in events], [("levelup", "LEVEL 5", "bob")])

    def test_history_counts_once_without_paying_old_levels(self):
        for i in range(10):
            run = self.store.start_run("alice", "chicken-jump", now=1000 + i * 1000)
            self.store.complete_run("alice", "chicken-jump", run["run_id"], {"score": 100000}, now=1000 + i * 1000 + 300)
        wallet = self.store.balance("alice")
        self.assertGreater(wallet["xp"], 300)
        self.assertGreaterEqual(wallet["level"], 3)

    def test_finished_round_gives_xp_and_says_so(self):
        run = self.store.start_run("bob", "chicken-snake", now=5000)
        result = self.store.complete_run("bob", "chicken-snake", run["run_id"], {"score": 5000}, now=5000 + 120)
        self.assertGreater(result["xp_awarded"], 10)
        self.assertIn("XP", result["message"])
        self.assertEqual(result["wallet"]["xp"], 5 + result["xp_awarded"])


if __name__ == "__main__":
    unittest.main()
