import tempfile
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from uuid import uuid4

from app import analytics
from app.economy import EconomyStore


class FakeRequest:
    def __init__(self, agent="Mozilla/5.0 (Windows NT 10.0) Chrome/130 Safari/537"):
        self.headers = {"user-agent": agent}
        self.client = SimpleNamespace(host="test")


class AnalyticsTests(unittest.TestCase):
    def setUp(self):
        patch('app.xp.rewards_for', return_value={'chickens': 0, 'credits': 0}).start()
        self.directory = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.directory.name) / "economy.sqlite3")
        self.store.mark_ready(["alice"])
        patch("app.analytics.economy", return_value=self.store).start()
        patch("app.analytics.ratelimit.hit").start()
        self.addCleanup(patch.stopall)
        self.addCleanup(self.directory.cleanup)

    def send(self, visitor, path, kind="view", ref="", width=1920, agent=None):
        analytics.track(analytics.Track(visitor=visitor, path=path, kind=kind, ref=ref, width=width),
                        FakeRequest(agent) if agent else FakeRequest(), analytics.Response(), None)

    def test_paths_are_cleaned_and_profiles_stay_anonymous(self):
        self.assertEqual(analytics.clean_path("games/chicken-jump/extra"), "games/chicken-jump")
        self.assertEqual(analytics.clean_path("u/SomeUser"), "u")
        self.assertEqual(analytics.clean_path(""), "home")
        self.assertIsNone(analytics.referrer_of("https://my-aviary.de/#shop"))
        self.assertEqual(analytics.referrer_of("https://www.twitch.tv/somechannel"), "twitch.tv")

    def test_report_counts_visitors_views_minutes_and_activity(self):
        self.send("visitor-aaaa", "home", ref="https://www.twitch.tv/x")
        self.send("visitor-aaaa", "shop")
        self.send("visitor-aaaa", "shop", kind="ping")
        self.send("visitor-bbbb", "games/chicken-jump", width=390, agent="Mozilla/5.0 (iPhone) Mobile Safari/604")
        self.store.buy("alice", {"id": 1, "name": "3 Squats", "category": "Bestrafungs Ideen", "price": 0}, str(uuid4()))
        result = analytics.report(7)
        self.assertEqual(result["kpis"]["visitors"][0], 2)
        self.assertEqual(result["kpis"]["views"][0], 3)
        self.assertEqual(result["kpis"]["minutes_per_visitor"][0], 0.5)
        self.assertEqual([tuple(r) for r in result["traffic"]["referrers"]], [("twitch.tv", 1)])
        self.assertEqual(dict(result["traffic"]["devices"]), {"Desktop": 1, "Smartphone": 1})
        self.assertEqual(result["traffic"]["daily"][-1]["views"], 3)
        self.assertEqual(len(result["online"]), 2)
        self.assertEqual(result["activity"]["purchases"], 1)
        self.assertEqual(result["activity"]["active_daily"][-1], 1)
        self.assertEqual(sum(map(sum, result["traffic"]["heat"])), 3)
        today = analytics.report(1)
        self.assertEqual(len(today["keys"]), 24)
        self.assertEqual(sum(d["views"] for d in today["traffic"]["daily"]), 3)
        self.assertEqual(sum(today["activity"]["purchases_daily"]), 1)
        self.assertEqual(today["kpis"]["purchases"], [1, 0])


if __name__ == "__main__":
    unittest.main()
