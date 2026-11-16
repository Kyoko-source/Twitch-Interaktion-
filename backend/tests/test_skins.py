import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from fastapi import HTTPException

from app import horses, main
from app.economy import EconomyStore


class SkinTests(unittest.TestCase):
    def setUp(self):
        patch('app.xp.rewards_for', return_value={'chickens': 0, 'credits': 0}).start()
        self.directory = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.directory.name) / "economy.sqlite3")
        self.store.mark_ready(["alice"])
        self.store.adjust("alice", 30000)
        patch("app.horses.economy", return_value=self.store).start()
        self.addCleanup(patch.stopall)
        self.addCleanup(self.directory.cleanup)

    def item(self, key):
        return next(i for i in horses.SKIN_SHOP_ITEMS if i["skin"] == key)

    def test_unicorn_costs_10000_and_is_listed_in_the_shop(self):
        unicorn = self.item("unicorn")
        self.assertEqual((unicorn["price"], unicorn["category"]), (10000, "Derby Skins"))
        self.assertIn(unicorn["id"], {i["id"] for i in main.BUILTIN_SHOP_ITEMS})
        self.assertGreaterEqual(len([i for i in main.CHAT_STYLE_SHOP_ITEMS]), 14)
        self.assertEqual(len(main.chat_style_ids()), len(main.CHAT_STYLE_SHOP_ITEMS) + 1)

    def test_buying_owning_choosing_and_overlay_flair(self):
        self.store.buy("alice", self.item("zebra"), str(uuid4()), now=100)
        self.store.buy("alice", self.item("unicorn"), str(uuid4()), now=200)
        with self.assertRaises(HTTPException) as again:
            self.store.buy("alice", self.item("unicorn"), str(uuid4()), now=300)
        self.assertEqual(again.exception.status_code, 409)
        self.assertEqual(self.store.balance("alice")["chickens"], 30000 - 13000)
        with self.store.connection(write=True) as db:
            self.assertEqual(horses.owned_skins(db, "alice"), ["zebra", "unicorn"])
            self.assertEqual(horses.active_skin(db, "alice"), "unicorn")          # newest by default
            self.assertEqual(horses.derby_flair(db, "alice")["skin"], "unicorn")
        user = {"username": "alice"}
        self.assertEqual(horses.choose_skin(horses.SkinChoice(skin="zebra"), user)["skins"]["active"], "zebra")
        self.assertIsNone(horses.choose_skin(horses.SkinChoice(skin="none"), user)["skins"]["active"])
        with self.assertRaises(HTTPException) as locked:
            horses.choose_skin(horses.SkinChoice(skin="ghost"), user)
        self.assertEqual(locked.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
