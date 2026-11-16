import json
import tempfile
import time
import unittest
from pathlib import Path

from app import horses, profiles, slots, xp
from app.economy import EconomyStore


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.folder.name) / "economy.sqlite3")
        self.store.mark_ready(["alice", "bob"])

    def tearDown(self):
        self.folder.cleanup()

    def test_empty_member_gets_a_full_profile(self):
        with self.store.connection() as db:
            card = profiles.card(db, "alice")
        self.assertEqual(card["derby"]["races"], 0)
        self.assertIsNone(card["derby"]["favorite"])
        self.assertEqual(card["slots"]["spins"], 0)
        self.assertEqual(card["games"], [])
        self.assertEqual(card["prefs"], {"theme": "neon", "showcase": []})
        self.assertFalse(any(b["earned"] for b in card["badges"]))
        self.assertEqual(len(card["activity"]["days"]), 0)

    def test_derby_slots_games_and_badges(self):
        now = time.time()
        with self.store.connection(write=True) as db:
            horses.ensure_table(db)
            slots.ensure_table(db)
            for i, (horse, payout) in enumerate([(4, 100), (4, 100), (4, 100), (2, 0), (4, 0)]):
                db.execute("INSERT INTO horse_races VALUES (?, 'alice', ?, 0, 50, ?, ?, '{}')", (f"h{i}", horse, payout, now + i))
            db.execute("INSERT INTO slot_spins VALUES ('s1', 'alice', 2, 120, ?, ?)", (now, json.dumps({"win": 120, "bonus": {"wheel": {"value": 64}, "awarded": 64}})))
            db.execute("INSERT INTO slot_spins VALUES ('s2', 'alice', 5, 0, ?, ?)", (now, json.dumps({"win": 0, "bonus": None})))
            for i, (user, score) in enumerate([("alice", 900), ("alice", 300), ("bob", 500)]):
                db.execute("INSERT INTO runs(id, username, game, started, completed, score, payload) VALUES (?, ?, 'chicken-jump', ?, ?, ?, '{}')", (f"r{i}", user, now, now, score))
            xp.award(db, "alice", "game", 50, now=now)
            card = profiles.card(db, "alice", 12000, now=now)
        d = card["derby"]
        self.assertEqual((d["races"], d["won"], d["streak"], d["best_payout"]), (5, 3, 3, 100))
        self.assertEqual(d["favorite"], {"id": 4, "name": "Feuerfunke", "bets": 4, "wins": 3})
        self.assertEqual(d["net"], 3 * 50 - 2 * 50)
        s = card["slots"]
        self.assertEqual((s["spins"], s["best_win"], s["best_mult"], s["bonuses"], s["best_wheel"]), (2, 120, 60.0, 1, 64))
        self.assertEqual(card["games"], [{"game": "chicken-jump", "name": "Chicken Jump", "plays": 2, "best": 900, "place": 1}])
        earned = {b["id"] for b in card["badges"] if b["earned"]}
        self.assertTrue({"first-win", "hot-streak", "slot-bonus", "high-roller", "wheel-50", "record", "podium", "rich"} <= earned)
        self.assertNotIn("phoenix", earned)
        self.assertGreater(sum(card["activity"]["days"].values()), 0)
        self.assertEqual(card["level"]["xp_rank"], 1)

    def test_look_is_checked_against_level_and_badges(self):
        with self.store.connection(write=True) as db:
            with self.assertRaises(ValueError):
                profiles.save_prefs(db, "alice", "gold", [], 3, set())
            with self.assertRaises(ValueError):
                profiles.save_prefs(db, "alice", "nope", [], 99, set())
            saved = profiles.save_prefs(db, "alice", "sunset", ["record", "fake", "record", "a", "b", "c"], 3, {"record", "a", "b", "c"})
            self.assertEqual(saved, {"theme": "sunset", "showcase": ["record", "a", "b"]})
            self.assertEqual(profiles.prefs(db, "alice"), saved)

    def test_christmas_mode_is_stored_per_member_and_keeps_the_look(self):
        with self.store.connection(write=True) as db:
            self.assertEqual(profiles.christmas(db, "alice"), "ask")
            profiles.save_prefs(db, "alice", "sunset", [], 3, set())
            self.assertEqual(profiles.set_christmas(db, "alice", "declined"), "declined")
            self.assertEqual(profiles.christmas(db, "alice"), "declined")
            profiles.set_christmas(db, "alice", "on")
            self.assertEqual(profiles.christmas(db, "alice"), "on")
            self.assertEqual(profiles.prefs(db, "alice")["theme"], "sunset", "switching Christmas keeps the profile look")
            profiles.save_prefs(db, "alice", "ocean", [], 3, set())
            self.assertEqual(profiles.christmas(db, "alice"), "on", "saving the look keeps Christmas")
            self.assertEqual(profiles.christmas(db, "bob"), "ask")
            with self.assertRaises(ValueError):
                profiles.set_christmas(db, "alice", "ask")


if __name__ == "__main__":
    unittest.main()
