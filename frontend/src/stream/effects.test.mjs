import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { CATEGORIES, EFFECTS, VIDEOS } from "./effects.js";
import { HANDLERS } from "./engine.js";

test("fifty effects, unique ids, every one with a category and a canvas handler", () => {
  assert.equal(EFFECTS.length, 50);
  assert.equal(new Set(EFFECTS.map((e) => e.id)).size, 50);
  for (const e of EFFECTS) {
    assert.ok(CATEGORIES.some((c) => c.id === e.cat), e.id);
    assert.ok(HANDLERS[e.id], `handler for ${e.id}`);
  }
});

test("the backend accepts exactly these effects and videos", () => {
  const py = fs.readFileSync(new URL("../../../backend/app/stream_control.py", import.meta.url), "utf8");
  const block = py.match(/EFFECTS = frozenset\("""([\s\S]*?)"""/)[1].split(/\s+/).filter(Boolean);
  assert.deepEqual(new Set(block), new Set([...EFFECTS.map((e) => e.id), "stop"]));
  for (const v of VIDEOS) assert.ok(py.includes(`"${v.id}"`), v.id);
});
