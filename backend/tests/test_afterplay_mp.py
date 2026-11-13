import unittest

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import afterplay_mp

CATALOG = [{"id": "clown_lunge", "name": "Der Clown springt.", "zone": "Küche"},
           {"id": "balls_float", "name": "Bälle schweben.", "zone": "Bällebad"}]
MAP = {"walls": [[0, 0, 4, 0, 4, .2, 0, .2], [0, 0, .2, 0, .2, 6, 0, 6]], "rooms": [{"name": "Küche", "x": 2, "z": 3}], "bounds": [0, 0, 4, 6]}


class AfterPlayMultiplayerTests(unittest.TestCase):
    def setUp(self):
        afterplay_mp.store.sessions.clear()
        app = FastAPI(); app.include_router(afterplay_mp.router)
        self.client = TestClient(app)

    def create(self):
        response = self.client.post("/api/afterplay/mp/sessions", json={"version": "4.4.1", "catalog": CATALOG})
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
        self.assertEqual(self.client.get(f"/api/afterplay/mp/sessions/{code}/map", headers={"X-Viewer-Token": viewer}).status_code, 404)
        state = {"phase": "play", "round": 3, "streak": 2, "zone": "Küche", "current": "clown_lunge", "x": 1.5, "z": -2.25, "yaw": .5, "events": ["Grüne Tür: falsch"]}
        self.assertEqual(self.client.post(f"/api/afterplay/mp/sessions/{code}/state", json=state, headers={"X-Host-Token": host}).status_code, 200)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/map", json=MAP, headers={"X-Host-Token": host}).status_code, 200)
        view = self.client.get(f"/api/afterplay/mp/sessions/{code}/view", headers={"X-Viewer-Token": viewer}).json()
        self.assertEqual(view["state"]["round"], 3)
        self.assertEqual((view["state"]["x"], view["state"]["z"]), (1.5, -2.25))
        self.assertTrue(view["has_map"])
        self.assertIn("Grüne Tür: falsch", [e["text"] for e in view["events"]])
        self.assertEqual(self.client.get(f"/api/afterplay/mp/sessions/{code}/map", headers={"X-Viewer-Token": viewer}).json()["walls"], MAP["walls"])

    def test_old_game_builds_still_connect(self):
        response = self.client.post("/api/afterplay/mp/sessions", json={"version": "4.4.0", "catalog": CATALOG, "cameras": ["Empfang"]})
        self.assertEqual(response.status_code, 200)
        code, host = response.json()["code"], response.json()["host_token"]
        old = {"phase": "play", "round": 1, "streak": 0, "zone": "Empfang", "camera": "01 / EMPFANG", "current": "", "events": []}
        self.assertEqual(self.client.post(f"/api/afterplay/mp/sessions/{code}/state", json=old, headers={"X-Host-Token": host}).status_code, 200)

    def test_tokens_and_validation(self):
        code, host = self.create()
        viewer = self.client.post(f"/api/afterplay/mp/sessions/{code}/join").json()["viewer_token"]
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/plan", json={"rounds": ["none"] * 13}, headers={"X-Viewer-Token": host}).status_code, 403)
        self.assertEqual(self.client.post(f"/api/afterplay/mp/sessions/{code}/state", json={}, headers={"X-Host-Token": viewer}).status_code, 403)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/plan", json={"rounds": ["evil"] * 13}, headers={"X-Viewer-Token": viewer}).status_code, 400)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/plan", json={"rounds": ["none"] * 12}, headers={"X-Viewer-Token": viewer}).status_code, 422)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/map", json={**MAP, "walls": [[1, 2, 3]]}, headers={"X-Host-Token": host}).status_code, 400)
        self.assertEqual(self.client.put(f"/api/afterplay/mp/sessions/{code}/map", json=MAP, headers={"X-Host-Token": viewer}).status_code, 403)
        self.assertEqual(self.client.post("/api/afterplay/mp/sessions/000000/join").status_code in (404, 409), True)
        self.assertEqual(self.client.post("/api/afterplay/mp/sessions/12ab/join").status_code, 400)


if __name__ == "__main__":
    unittest.main()
