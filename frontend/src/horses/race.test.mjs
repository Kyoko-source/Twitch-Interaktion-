import test from "node:test";
import assert from "node:assert/strict";
import { Commentator, lapsAt, raceEnd, standings } from "./race.mjs";

const seeded = (seed = 7) => () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };

// A small stand-in for the server script: horse 4 wins, horse 1 leads early.
function script() {
  const n = 32, shapes = [];
  for (let h = 0; h < 9; h++) {
    const s = [0];
    for (let k = 1; k <= n; k++) {
      const u = k / n;
      s.push(h === 1 ? Math.min(1, u ** 0.85) : h === 4 ? u ** 1.15 : u);
    }
    s[n] = 1;
    shapes.push(s);
  }
  const finish = [42.6, 41.2, 43.0, 43.3, 41.0, 42.0, 42.2, 42.9, 43.6];
  const order = [...finish.keys()].sort((a, b) => finish[a] - finish[b]);
  return { laps: 3, shapes, finish, order, winner: order[0] };
}
const names = ["Donnerhuf", "Goldmähne", "Sturmwind", "Mitternacht", "Feuerfunke", "Silberpfeil", "Kleiner Keks", "Royal Gacker", "Nebelläufer"];

test("positions run from 0 to the full distance and the winner crosses first", () => {
  const race = script();
  assert.equal(lapsAt(race, 0, 0), 0);
  for (let h = 0; h < 9; h++) assert.ok(Math.abs(lapsAt(race, h, race.finish[h]) - 3) < 1e-9);
  assert.equal(standings(race, race.finish[4])[0], 4);
  assert.deepEqual(standings(race, raceEnd(race) + 1), race.order, "after the race the standings are the finish order");
});

test("commentator calls start, lead change, laps, home straight and the winner", () => {
  const race = script();
  const c = new Commentator(race, 2, names, seeded());
  const calls = [];
  for (let t = -1; t < raceEnd(race) + 1; t += 1 / 30) calls.push(...c.update(t).map((x) => x.text));
  assert.equal(calls[0], "UND AB GEHT DIE POST!");
  assert.ok(calls.includes("RUNDE 2 VON 3!"));
  assert.ok(calls.includes("LETZTE RUNDE!!!"));
  assert.ok(calls.some((x) => x.startsWith("ZIELGERADE")));
  assert.ok(calls.some((x) => x.includes("GOLDMÄHNE")), "early leader is named");
  assert.equal(calls.filter((x) => x.endsWith("GEWINNT!")).length, 1);
  assert.ok(calls.includes("FEUERFUNKE GEWINNT!"));
});

test("a winning bet gets its own callout", () => {
  const race = script();
  const c = new Commentator(race, 4, names, seeded());
  const calls = [];
  for (let t = -1; t < raceEnd(race) + 1; t += 1 / 30) calls.push(...c.update(t));
  assert.ok(calls.some((x) => x.text === "DEIN PFERD FEUERFUNKE GEWINNT!!!" && x.tone === "win"));
});
