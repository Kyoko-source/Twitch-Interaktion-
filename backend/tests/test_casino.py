import tempfile
import unittest
from pathlib import Path

from fastapi import FastAPI, Header
from fastapi.testclient import TestClient

from app import auth, casino, ratelimit
from app.economy import EconomyStore


class CasinoTests(unittest.TestCase):
    def setUp(self):
        ratelimit.reset()
        self.folder = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.folder.name) / "economy.sqlite3")
        self.store.mark_ready(["alice"])
        self.store.adjust("alice", 300)
        self._economy = casino.economy
        casino.economy = lambda: self.store
        app = FastAPI(); app.include_router(casino.router)

        def fake(x_test_user: str = Header()):
            return {"username": x_test_user}
        app.dependency_overrides[auth.current_user] = fake
        self.client = TestClient(app)
        self.n = 0

    def tearDown(self):
        casino.economy = self._economy
        self.folder.cleanup()

    def post(self, path, body, request_id=None):
        self.n += 1
        return self.client.post(f"/api/casino{path}", headers={"X-Test-User": "alice"}, json={**body, "request_id": request_id or f"cash-{self.n:04d}-abcdefghijk"})

    def set_gsc(self, amount):
        with self.store.connection(write=True) as db:
            db.execute("UPDATE wallets SET gsc=? WHERE username=?", (amount, "alice"))

    def test_buy_credits_for_chickens_once(self):
        data = self.post("/credits", {"count": 5}, request_id="credit-buy-0001-xxxx").json()
        self.assertEqual((data["wallet"]["chickens"], data["wallet"]["credits"]), (250, 5))
        again = self.post("/credits", {"count": 5}, request_id="credit-buy-0001-xxxx").json()
        self.assertEqual((again["wallet"]["chickens"], again["wallet"]["credits"]), (250, 5), "replay does not charge twice")
        self.assertEqual(self.post("/credits", {"count": 3}).status_code, 400)
        self.assertEqual(self.post("/credits", {"count": 25}).status_code, 200)
        self.assertEqual(self.post("/credits", {"count": 1}).status_code, 400, "not enough Chickens left")
        history = self.store.wallet_history("alice")["transactions"]
        self.assertTrue(any(t["kind"] == "casino" and t["amount"] == -50 for t in history))

    def test_gsc_exchange_is_steep_and_capped_per_day(self):
        self.set_gsc(10_000_000)
        data = self.post("/exchange", {"chickens": 100}).json()
        self.assertEqual(data["wallet"]["gsc"], 10_000_000 - 100 * casino.GSC_PER_CHICKEN)
        self.assertEqual(data["wallet"]["chickens"], 400)
        self.assertEqual(self.post("/exchange", {"chickens": 10}).status_code, 429, "daily cap reached")
        self.assertEqual(self.post("/exchange", {"chickens": 7}).status_code, 400)

    def test_exchange_needs_enough_gsc(self):
        self.assertEqual(self.post("/exchange", {"chickens": 10}).status_code, 400)


if __name__ == "__main__":
    unittest.main()
