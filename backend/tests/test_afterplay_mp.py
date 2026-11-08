import unittest

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import afterplay_mp

CATALOG = [{"id": "clown_lunge", "name": "Der Clown springt.", "zone": "Küche"},
           {"id": "balls_float", "name": "Bälle schweben.", "zone": "Bällebad"}]
JPEG = b"\xff\xd8\xff\xe0" + b"0" * 64


class AfterPlayMultiplayerTests(unittest.TestCase):
    def setUp(self):
        afterplay_mp.store.sessions.clear()
        app = FastAPI(); app.include_router(afterplay_mp.router)
        self.client = TestClient(app)

    def create(self):
        response = self.client.post("/api/afterplay/mp/sessions", json={"version": "4.3.4", "catalog": CATALOG, "cameras": ["Empfang"]})
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertRegex(body["code"], r"^\d{6}$")
        return body["code"], body["host_token"]

    def test_full_flow(self):
        code, host = self.create()
        self.assertEqual(self.client.get(f"/api/afterplay/mp/sessions/{code}/host", headers={"X-Host-Token": host}).json(), {"joined": False, "plan": None})
        joined = self.client.post(f"/api/afterplay/mp/sessions/{code}/join").json()
        viewer = joined["viewer_token"]
        self.assertEqual([a["id"] for a in joined["catalog"]], ["clown_lunge", "balls_float"])
        # Only one spectator per game.
        self.assertEqual(self.client.post(f"/api/afterplay/mp/sessions/{code}/join").status_code, 409)
        plan = ["none"] * 13; plan[2] = "clown_lunge"; plan[7] = "balls_float"
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/plan", json={"rounds": plan}, headers={"X-Viewer-Token": viewer}).status_code, 200)
        self.assertEqual(self.client.get(f"/api/afterplay/mp/sessions/{code}/host", headers={"X-Host-Token": host}).json()["plan"], plan)
        # A saved plan cannot be swapped mid-shift.
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/plan", json={"rounds": ["none"] * 13}, headers={"X-Viewer-Token": viewer}).status_code, 409)
        state = {"phase": "play", "round": 3, "streak": 2, "zone": "Küche", "camera": "Küche", "current": "clown_lunge", "events": ["Grüne Tür: falsch"]}
        self.assertEqual(self.client.post(f"/api/afterplay/mp/sessions/{code}/state", json=state, headers={"X-Host-Token": host}).status_code, 200)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/frame", content=JPEG, headers={"X-Host-Token": host}).json(), {"seq": 1})
        view = self.client.get(f"/api/afterplay/mp/sessions/{code}/view", headers={"X-Viewer-Token": viewer}).json()
        self.assertEqual(view["state"]["round"], 3)
        self.assertEqual(view["frame_seq"], 1)
        self.assertIn("Grüne Tür: falsch", [e["text"] for e in view["events"]])
        frame = self.client.get(f"/api/afterplay/mp/sessions/{code}/frame.jpg", params={"token": viewer})
        self.assertEqual(frame.content, JPEG)

    def test_tokens_and_validation(self):
        code, host = self.create()
        viewer = self.client.post(f"/api/afterplay/mp/sessions/{code}/join").json()["viewer_token"]
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/plan", json={"rounds": ["none"] * 13}, headers={"X-Viewer-Token": host}).status_code, 403)
        self.assertEqual(self.client.post(f"/api/afterplay/mp/sessions/{code}/state", json={}, headers={"X-Host-Token": viewer}).status_code, 403)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/plan", json={"rounds": ["evil"] * 13}, headers={"X-Viewer-Token": viewer}).status_code, 400)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/plan", json={"rounds": ["none"] * 12}, headers={"X-Viewer-Token": viewer}).status_code, 422)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/frame", content=b"not a jpeg", headers={"X-Host-Token": host}).status_code, 400)
        self.assertEqual(self.client.post("/api/afterplay/mp/sessions/000000/join").status_code in (404, 409), True)
        self.assertEqual(self.client.post("/api/afterplay/mp/sessions/12ab/join").status_code, 400)


if __name__ == "__main__":
    unittest.main()
