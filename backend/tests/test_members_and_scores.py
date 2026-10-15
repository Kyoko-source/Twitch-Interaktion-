import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch
from uuid import uuid4

from fastapi import HTTPException
from pydantic import ValidationError
from app import main, auth
from app.economy import EconomyStore
import test_economy


class MembersAndScoresTests(unittest.TestCase):
    request = staticmethod(test_economy.EconomyTests.request)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = EconomyStore(Path(self.directory.name) / "ledger.sqlite3")
        self.store.mark_ready(["alice", "bob"])

    def tearDown(self):
        main.app.dependency_overrides.clear()
        self.directory.cleanup()

    def test_missing_pinball_legacy_table_does_not_hide_saved_scores_or_block_new_records(self):
        main.app.dependency_overrides[auth.current_user] = lambda: {"username": "alice"}
        with patch.object(main, "economy", return_value=self.store), patch.object(main, "rows", side_effect=HTTPException(404, "PGRST205 missing retired table")):
            run = self.store.start_run("alice", "chicken-flipper", now=1000)
            with patch("app.economy.time.time", return_value=1189):
                status, result = self.request("POST", "/api/scores", {"game": "chicken-flipper", "run_id": run["run_id"], "score": 557750})
            self.assertEqual(status, 200)
            self.assertEqual(result["wallet"]["chickens"], 18)
            self.assertTrue(result["highscore_alert_queued"])
            status, rows = self.request("GET", "/api/scores/chicken-flipper")
            self.assertEqual(status, 200)
            self.assertEqual((rows[0]["username"], rows[0]["score"]), ("alice", 557750))
            self.assertEqual(self.request("GET", "/api/scores/not-a-game")[0], 404)

    def test_history_outage_preserves_local_scores_but_does_not_invent_empty_history(self):
        run = self.store.start_run("alice", "chicken-snake", now=1000)
        self.store.complete_run("alice", "chicken-snake", run["run_id"], {"score": 200}, now=1030)
        with patch.object(main, "economy", return_value=self.store), patch.object(main, "rows", side_effect=HTTPException(503, "offline")):
            self.assertEqual(self.request("GET", "/api/scores/chicken-snake")[1][0]["score"], 200)
            self.assertEqual(self.request("GET", "/api/scores/chicken-jump")[0], 503)

    def test_1118_is_explained_by_real_bookings_without_changing_earned_leaderboard_points(self):
        self.store.adjust("alice", 700, str(uuid4()))
        self.store.adjust("alice", 700, str(uuid4()))
        run = self.store.start_run("alice", "chicken-flipper", now=1000)
        self.store.complete_run("alice", "chicken-flipper", run["run_id"], {"score": 557750}, now=1189)
        self.store.buy("alice", {"id": 1, "name": "kein Englisch", "category": "Bestrafungs Ideen", "price": 300}, str(uuid4()), now=1190)
        history = self.store.wallet_history("alice")
        self.assertEqual(history["wallet"]["chickens"], 1118)
        self.assertEqual(history["summary"], {"earned": 18, "adjustments": 1400, "spent": 300})
        self.assertEqual(sum(entry["amount"] for entry in history["transactions"]), 1118)
        self.assertEqual(self.store.balance("alice")["chickens_earned"], 18)

    def test_admin_booking_retries_credit_once_and_conflicting_reuse_is_rejected(self):
        key = str(uuid4())
        self.store.adjust("alice", 700, key)
        self.store.adjust("alice", 700, key)
        self.assertEqual(self.store.balance("alice")["chickens"], 700)
        self.assertEqual(len(self.store.wallet_history("alice")["transactions"]), 1)
        for username, amount in [("bob", 700), ("alice", 701)]:
            with self.assertRaises(HTTPException): self.store.adjust(username, amount, key)

    def test_kick_revokes_all_old_tokens_but_allows_new_login_and_invalidates_active_round(self):
        with patch.object(auth, "economy", return_value=self.store), patch.object(auth, "get_user", return_value={"username": "alice"}):
            token = auth.create_access_token("alice")
            self.assertEqual(auth.current_user(f"Bearer {token}")["username"], "alice")
            run = self.store.start_run("alice", "chicken-snake")
            key = str(uuid4())
            self.store.moderate("alice", "kick", "", key)
            self.store.moderate("alice", "kick", "", key)
            self.assertEqual(self.store.access("ALICE")["session_version"], 1)
            with self.assertRaises(HTTPException) as caught: auth.current_user(f"Bearer {token}")
            self.assertEqual(caught.exception.status_code, 401)
            fresh = auth.create_access_token("alice")
            self.assertEqual(auth.current_user(f"Bearer {fresh}")["username"], "alice")
            with self.assertRaises(HTTPException): self.store.complete_run("alice", "chicken-snake", run["run_id"], {"score": 200})

    def test_ban_blocks_existing_sessions_and_login_unban_never_restores_old_tokens(self):
        with patch.object(auth, "economy", return_value=self.store), patch.object(main, "economy", return_value=self.store), patch.object(auth, "get_user", return_value={"username": "alice"}), patch.object(main, "single_user", return_value={"username": "alice"}), patch.object(main, "verify_password", return_value=True):
            original = auth.create_access_token("alice")
            self.store.moderate("alice", "ban", "Spam", str(uuid4()))
            self.assertTrue(self.store.access("alice")["banned"])
            with self.assertRaises(HTTPException) as caught: auth.current_user(f"Bearer {original}")
            self.assertEqual(caught.exception.status_code, 403)
            self.assertEqual(self.request("POST", "/api/auth/login", {"username": "alice", "password": "test"})[0], 403)
            self.store.moderate("alice", "unban", "", str(uuid4()))
            with self.assertRaises(HTTPException): auth.current_user(f"Bearer {original}")
            fresh = auth.create_access_token("alice")
            self.assertEqual(auth.current_user(f"Bearer {fresh}")["username"], "alice")

    def test_admin_routes_require_master_password_and_validated_actions(self):
        self.assertEqual(self.request("POST", "/api/admin/members/alice/action", {"action": "ban", "request_id": str(uuid4())})[0], 403)
        main.app.dependency_overrides[auth.require_admin] = lambda: None
        client = MagicMock()
        with patch.object(main, "economy", return_value=self.store), patch.object(main, "single_user", return_value={"username": "alice"}), patch.object(main, "supabase", return_value=client):
            self.assertEqual(self.request("POST", "/api/admin/members/alice/action", {"action": "delete", "request_id": str(uuid4())})[0], 422)
            self.assertEqual(self.request("POST", "/api/admin/members/alice/action", {"action": "ban", "request_id": str(uuid4())})[0], 200)
            self.assertTrue(self.store.access("alice")["banned"])
        with self.assertRaises(ValidationError): main.RoleUpdate(username="alice", role="unknown")

    def test_removing_a_role_overrides_legacy_role_even_when_supabase_update_fails(self):
        client = MagicMock(); client.patch.side_effect = HTTPException(503, "offline")
        with patch.object(main, "USER_ROLES_FILE", Path(self.directory.name) / "roles.json"), patch.object(main, "single_user", return_value={"username": "alice", "role": "moderator"}), patch.object(main, "supabase", return_value=client):
            main.admin_role(main.RoleUpdate(username="alice", role="member"))
            self.assertEqual(main.user_role("alice", "moderator"), "member")

    def test_private_wallet_history_requires_login_and_never_reads_a_supplied_other_username(self):
        self.store.adjust("bob", 999)
        self.assertEqual(self.request("GET", "/api/wallet/history")[0], 401)
        main.app.dependency_overrides[auth.current_user] = lambda: {"username": "alice"}
        with patch.object(main, "economy", return_value=self.store):
            status, result = self.request("GET", "/api/wallet/history?username=bob")
            self.assertEqual(status, 200)
            self.assertEqual(result["wallet"]["chickens"], 0)
            self.assertEqual(result["transactions"], [])


if __name__ == "__main__": unittest.main()
