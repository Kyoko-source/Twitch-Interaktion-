import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient

from app import auth, main


class ChatUnreadTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        base = Path(self.directory.name)
        self.patches = [
            patch.object(main, "CHAT_MESSAGES_FILE", base / "chat.json"),
            patch.object(main, "CHAT_READS_FILE", base / "reads.json"),
            patch.object(main, "CHAT_STYLES_FILE", base / "styles.json"),
            patch.object(main, "single_user", side_effect=lambda name: {"username": name}),
            patch.object(main, "rows", return_value=[]),
        ]
        for item in self.patches:
            item.start()
        self.client = TestClient(main.app)
        self.as_user("bob")

    def tearDown(self):
        for item in self.patches:
            item.stop()
        main.app.dependency_overrides.clear()
        self.directory.cleanup()

    def as_user(self, name):
        main.app.dependency_overrides[auth.current_user] = lambda: {"username": name}

    def test_private_messages_count_as_unread_until_the_conversation_is_opened(self):
        self.as_user("alice")
        self.client.post("/api/chat/private/bob", json={"body": "Hallo Bob"})
        self.client.post("/api/chat/private/bob", json={"body": "Bist du da?"})
        self.client.post("/api/chat/global", json={"body": "Global zählt nicht"})

        # The sender has nothing unread.
        self.assertEqual(self.client.get("/api/chat/unread").json()["total"], 0)

        self.as_user("bob")
        summary = self.client.get("/api/chat/unread").json()
        self.assertEqual(summary["total"], 2)
        self.assertEqual(summary["conversations"][0]["username"], "alice")
        self.assertEqual(summary["conversations"][0]["last_body"], "Bist du da?")

        self.client.get("/api/chat/private/alice")
        self.assertEqual(self.client.get("/api/chat/unread").json()["total"], 0)

        # Replying does not mark anything for alice as read.
        self.client.post("/api/chat/private/alice", json={"body": "Ja!"})
        self.as_user("alice")
        self.assertEqual(self.client.get("/api/chat/unread").json()["total"], 1)

    def test_long_previews_are_shortened(self):
        self.as_user("alice")
        self.client.post("/api/chat/private/bob", json={"body": "x" * 500})
        self.as_user("bob")
        preview = self.client.get("/api/chat/unread").json()["conversations"][0]["last_body"]
        self.assertEqual(len(preview), 141)


if __name__ == "__main__":
    unittest.main()
