import math
import random
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from fastapi import HTTPException

from app import wheel
from app.economy import EconomyStore


class FakeRequest:
    client = type("C", (), {"host": "test"})()
    headers = {}


class WheelTests(unittest.TestCase):
    def setUp(self):
        self._no_level_rewards = patch('app.xp.rewards_for', return_value={'chickens': 0, 'credits': 0})
        self._no_level_rewards.start()
        self.addCleanup(self._no_level_rewards.stop)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.store = EconomyStore(Path(self.directory.name) / "economy.sqlite3")
        self.store.mark_ready(["alice", "bob"])
        self.store.adjust("alice", 5000)
        self.store.adjust("bob", 5000)
        patcher = patch("app.wheel.economy", return_value=self.store)
        patcher.start()
        self.addCleanup(patcher.stop)
        patch("app.wheel.ratelimit.hit").start()
        self.addCleanup(patch.stopall)

    def buy(self, user, name, category="Bestrafungs Ideen"):
        self.store.buy(user, {"id": name, "name": name, "category": category, "price": 100}, str(uuid4()))

    def test_same_punishment_stacks_weight_and_other_items_stay_off(self):
        self.buy("alice", "10 Squats")
        self.buy("bob", "10  squats")
        self.buy("bob", "Kein Englisch", "Idee Bestrafungsrad")
        self.buy("alice", "Emote", "In Stream Rewards")
        state = wheel.admin_state(wheel.Response())
        self.assertEqual([(e["name"], e["weight"]) for e in state["entries"]], [("10 Squats", 2), ("Kein Englisch", 1)])
        self.assertEqual(state["total"], 3)
        self.assertEqual({b["username"] for b in state["entries"][0]["buyers"]}, {"alice", "bob"})

    def test_final_angle_lands_inside_the_winning_segment(self):
        entries = [{"key": "a", "weight": 1}, {"key": "b", "weight": 3}, {"key": "c", "weight": 2}]
        rng = random.Random(7)
        hits = {"a": 0, "b": 0, "c": 0}
        for _ in range(600):
            start = rng.uniform(0, math.tau)
            winner, final = wheel.draw(entries, start, rng)
            hits[winner] += 1
            lo, hi = wheel.segment_span(entries, winner)
            under_pointer = (-final) % math.tau
            self.assertTrue(lo < under_pointer < hi)
            self.assertGreater(final - start, 5 * math.tau)
        self.assertGreater(hits["b"], hits["a"] * 2)

    def test_spin_resolve_done_removes_all_copies(self):
        self.buy("alice", "10 Squats")
        self.buy("bob", "10 Squats")
        result = wheel.spin(FakeRequest())["spin"]
        self.assertEqual(result["winner"], "10 squats")
        with self.assertRaises(HTTPException) as busy:
            wheel.spin(FakeRequest())
        self.assertEqual(busy.exception.status_code, 409)
        wheel.resolve(result["id"], wheel.Resolve(action="done"))
        self.assertEqual(wheel.admin_state(wheel.Response())["entries"], [])
        feed = wheel.stream_state(wheel.Response())
        self.assertEqual(feed["spin"]["status"], "done")
        self.assertNotIn("purchase_id", str(feed))

    def test_remove_single_purchase_and_empty_wheel(self):
        with self.assertRaises(HTTPException):
            wheel.spin(FakeRequest())
        self.buy("alice", "10 Squats")
        self.buy("bob", "10 Squats")
        entry = wheel.admin_state(wheel.Response())["entries"][0]
        wheel.remove(wheel.RemoveEntries(purchase_ids=[entry["buyers"][0]["purchase_id"]]))
        self.assertEqual(wheel.admin_state(wheel.Response())["entries"][0]["weight"], 1)


if __name__ == "__main__":
    unittest.main()
