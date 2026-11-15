import test from "node:test";
import assert from "node:assert/strict";
import { MISSIONS, STAGES, buyUpgrade, completedBy, fillMissions, freshMeta, loadMeta, pickWeighted, rankFor, saveMeta, settleRun, stageAt } from "./meta.js";

const memory = () => { const m = new Map(); return { getItem: (k) => m.get(k) ?? null, setItem: (k, v) => m.set(k, v) }; };

test("stages follow each other and repeat as a faster lap", () => {
  assert.equal(stageAt(0).name, "Morgenwiese");
  assert.equal(stageAt(399).index, 0);
  assert.equal(stageAt(400).name, "Bisonweide");
  const cycle = STAGES.reduce((n, s) => n + s.length, 0);
  assert.equal(stageAt(cycle - 1).name, "Gewitternacht");
  const again = stageAt(cycle + 10);
  assert.equal(again.name, "Morgenwiese");
  assert.equal(again.lap, 1);
  assert.equal(again.number, STAGES.length + 1);
  assert.ok(STAGES[1].mix.bull > 0, "bulls appear in the second stage");
});

test("weighted pick respects the mix", () => {
  let seed = 3; const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
  const counts = {};
  for (let i = 0; i < 6000; i += 1) { const k = pickWeighted({ a: 1, b: 3 }, rnd); counts[k] = (counts[k] || 0) + 1; }
  assert.ok(counts.b > counts.a * 2.5 && counts.b < counts.a * 3.5, JSON.stringify(counts));
});

test("three missions are always active; finishing them banks rewards and feathers", () => {
  const storage = memory();
  const meta = loadMeta(storage);
  assert.equal(meta.missions.length, 3);
  const first = MISSIONS.find((m) => m.id === meta.missions[0]);
  const stats = { feathers: 12, [first.stat]: first.goal };
  assert.deepEqual(completedBy(meta, stats).map((m) => m.id), [first.id]);
  const { meta: next, earned, missions } = settleRun(meta, stats);
  assert.equal(missions.length, 1);
  assert.equal(earned, (first.stat === "feathers" ? first.goal : 12) + first.reward);
  assert.equal(next.bank, earned);
  assert.equal(next.missions.length, 3);
  assert.ok(!next.missions.includes(first.id));
  saveMeta(next, storage);
  assert.equal(loadMeta(storage).bank, earned);
});

test("missions start over once every mission is done", () => {
  const meta = fillMissions({ ...freshMeta(), done: MISSIONS.map((m) => m.id) });
  assert.equal(meta.missions.length, 3);
});

test("upgrades cost feathers and stop at their max level", () => {
  let meta = { ...freshMeta(), bank: 1000 };
  meta = buyUpgrade(meta, "magnet"); assert.equal(meta.bank, 920);
  meta = buyUpgrade(meta, "magnet"); meta = buyUpgrade(meta, "magnet");
  assert.equal(meta.upgrades.magnet, 3);
  assert.equal(buyUpgrade(meta, "magnet"), null);
  assert.equal(buyUpgrade({ ...freshMeta(), bank: 10 }, "revive"), null);
});

test("ranks grow with lifetime feathers", () => {
  assert.equal(rankFor(0).name, "Küken");
  assert.equal(rankFor(650).name, "Hofhenne");
  assert.ok(rankFor(100).progress > 0 && rankFor(100).progress < 1);
});
