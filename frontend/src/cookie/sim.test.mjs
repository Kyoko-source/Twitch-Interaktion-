import test from "node:test";
import assert from "node:assert/strict";
import {
  FALL_TIME, GOAL, GRAMS_PER_COOKIE, OVEN_SLOTS, UPGRADES, actCut, actLoad, actPortion, actRoll, buy, createState, derive,
  deserialize, phaseOf, recommended, serialize, step, throughput, totalDough, upgradeCost,
} from "./sim.js";
import { play } from "./bot.mjs";

function bakeFirstCookieByHand(s) {
  actPortion(s);                         // 8 cookies' worth of dough on the table
  for (let i = 0; i < 3; i++) actRoll(s); // three strokes with the small rolling pin
  actCut(s);                             // one star
  actLoad(s);                            // onto the oven belt
}

test("25 t of dough are exactly one million cookies of 25 g", () => {
  const s = createState();
  assert.equal(s.dough * GRAMS_PER_COOKIE, 25_000_000);
  assert.equal(GOAL, 1_000_000);
  assert.equal(totalDough(s), GOAL);
});

test("the first cookie is made by hand and pays one taler exactly when it lands in the chute", () => {
  const s = createState();
  bakeFirstCookieByHand(s);
  assert.equal(s.dough, GOAL - 8);
  assert.equal(s.sheet, 7, "seven cookies' worth of rolled dough is left to cut");
  assert.equal(s.queue, 1);
  const d = derive(s.levels);
  const travel = OVEN_SLOTS / d.speed;
  step(s, travel - 0.05);
  assert.equal(s.talers, 0, "still in the oven");
  step(s, 0.2);
  assert.equal(s.exit + s.falling.reduce((a, b) => a + b[1], 0), 1, "left the oven, falling");
  assert.equal(s.talers, 0, "no taler before landing");
  step(s, FALL_TIME + 0.05);
  assert.equal(s.talers, 1);
  assert.equal(s.baked, 1);
  assert.equal(totalDough(s), GOAL);
});

test("nothing can be done without the step before; a full tray blocks cutting (no dough lost)", () => {
  const s = createState();
  assert.equal(actRoll(s), 0);
  assert.equal(actCut(s), 0);
  assert.equal(actLoad(s), 0);
  actPortion(s);
  for (let i = 0; i < 3; i++) actRoll(s);
  for (let i = 0; i < 6; i++) actCut(s);
  assert.equal(s.tray, 6);
  assert.equal(actCut(s), 0, "tray full");
  assert.equal(s.sheet, 2);
  assert.equal(totalDough(s), GOAL);
});

test("buying costs talers, respects phases and max levels", () => {
  const s = createState();
  s.talers = 10_000; s.earned = 500;
  const form = UPGRADES.find((u) => u.id === "form");
  assert.equal(buy(s, "form"), true);
  assert.equal(s.talers, 10_000 - upgradeCost(form, 0));
  assert.equal(buy(s, "portionierer"), false, "phase 2 is still locked");
  for (let i = 0; i < 5; i++) buy(s, "form");
  assert.equal(s.levels.form, form.max);
  s.earned = 2_000;
  assert.equal(phaseOf(s), 2);
  assert.equal(buy(s, "portionierer"), true);
  assert.ok(derive(s.levels).autoPortion > 0);
});

test("save and load keep cookies in flight – no taler twice, none lost", () => {
  const a = createState();
  for (let i = 0; i < 4; i++) bakeFirstCookieByHand(a);
  for (let i = 0; i < 20; i++) { actCut(a); actLoad(a); }
  step(a, 6);
  const b = deserialize(serialize(a));
  step(a, 60); step(b, 60);
  assert.equal(a.talers, b.talers);
  assert.equal(a.baked, b.baked);
  assert.equal(totalDough(b), GOAL);
  assert.throws(() => deserialize({ ...JSON.parse(serialize(a)), talers: 5, dough: 999 }), /Teigbilanz/);
});

test("machines alone keep producing and the line shows a backlog when the oven is slower", () => {
  const s = createState();
  s.talers = 1e9; s.earned = 400_000;
  for (const id of ["portionierer", "steuerung", "transport", "blechschieber"]) buy(s, id);
  step(s, 30);
  const d = derive(s.levels);
  assert.ok(d.autoCut > d.ovenRate, "cutting is faster than the oven");
  assert.ok(s.queue > 0 || s.tray > 0, "cookies wait in front of the oven");
  assert.ok(s.baked > 0);
  assert.equal(totalDough(s), GOAL);
});

test("the recommendation always points at something that helps", () => {
  const s = createState();
  const r = recommended(s);
  assert.ok(r);
  const before = throughput(derive(s.levels));
  const after = throughput(derive({ ...s.levels, [r.id]: 1 }));
  assert.ok(after > before, `${r.id} should raise ${before}`);
});

test("a full game: the bot reaches exactly one million cookies in a few hours, dough runs out exactly", () => {
  const r = play({ clicksPerSecond: 2.5 });
  assert.equal(r.baked, GOAL);
  assert.equal(r.state.dough, 0);
  assert.equal(r.state.earned, GOAL);
  assert.equal(r.state.talers + r.state.spent, GOAL);
  assert.ok(r.state.finished != null);
  assert.ok(r.hours >= 2.2 && r.hours <= 4, `took ${r.hours} h`);
  assert.ok(r.phaseAt[2] > 5 * 60 && r.phaseAt[2] < 20 * 60, "first machines after some minutes of hand work");
});
