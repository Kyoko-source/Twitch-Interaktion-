import test from "node:test";
import assert from "node:assert/strict";
import { BLOCKED, DefenseEngine, ENEMIES, PATH_DATA, START_EGGS, START_KORN, TOWERS, TOWER_ORDER, branchCost, hpScale, makeWave, pickMods, towerStats, upgradeCost } from "./engine.mjs";

const seeded = (seed = 7) => () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
const run = (game, seconds, step = 1 / 60) => { for (let t = 0; t < seconds; t += step) game.update(step); };

test("all ten towers exist with three upgrade branches each", () => {
  assert.equal(TOWER_ORDER.length, 10);
  for (const kind of TOWER_ORDER) assert.equal(Object.keys(TOWERS[kind].branches).length, 3, kind);
});

test("towers cost Korn, cannot stand on the path or on each other, upgrade to a branch and sell for 70 %", () => {
  const game = new DefenseEngine(); game.start();
  assert.equal(game.korn, START_KORN);
  assert.ok(BLOCKED.has("4,5"), "path tile");
  assert.equal(game.build("gatling", 4, 5), null);
  const t = game.build("gatling", 5, 5);
  assert.ok(t); assert.equal(game.korn, START_KORN - TOWERS.gatling.cost);
  assert.equal(game.build("gatling", 5, 5), null, "occupied");
  assert.equal(game.build("dark", 6, 5), null, "dark matter is locked until wave 12");
  game.korn = 5000;
  assert.equal(game.upgrade(t.id), true); assert.equal(t.level, 2);
  assert.equal(game.upgrade(t.id), true); assert.equal(t.level, 3);
  assert.equal(game.upgrade(t.id), false, "level 3 needs a branch choice");
  const before = game.korn;
  assert.equal(game.upgrade(t.id, "rapid"), true);
  assert.equal(t.branch, "rapid"); assert.equal(game.korn, before - branchCost("gatling"));
  assert.equal(game.upgrade(t.id, "mutation"), false, "only one branch");
  assert.equal(game.sell(t.id), Math.floor(t.spent * 0.7));
  assert.equal(game.towers.length, 0);
  assert.equal(upgradeCost("gatling", 1), Math.round(60 * 0.8));
});

test("levels and branches change the stats the way their cards promise", () => {
  const one = towerStats("gatling", 1), three = towerStats("gatling", 3);
  assert.ok(three.damage > one.damage * 2.5);
  assert.ok(towerStats("gatling", 4, "rapid").rate > three.rate * 2);
  assert.ok(towerStats("gatling", 4, "mutation").poison > 0);
  assert.equal(towerStats("sniper", 4, "pierce").pierce, true);
  assert.equal(towerStats("frost", 4, "blizzard").type, "pulse");
  assert.equal(towerStats("dark", 4, "void").type, "beam");
  assert.equal(towerStats("mortar", 4, "barrage").volley, 3);
  assert.equal(towerStats("rocket", 4, "homing").multi, 3);
  assert.ok(towerStats("golden", 4, "rich").income > towerStats("golden", 3).income * 2);
});

test("enemies walk the path, leaks steal eggs and the game ends at zero", () => {
  const events = [];
  const game = new DefenseEngine({ onEvent: (e) => events.push(e.type), random: seeded() }); game.start();
  const fox = game.spawn("fox", "a");
  assert.deepEqual([fox.x, fox.y], [-1, 2]);
  run(game, 3);
  assert.ok(fox.x > 1);
  fox.d = PATH_DATA.a.length - 0.01; run(game, 0.2);
  assert.equal(game.eggs, START_EGGS - ENEMIES.fox.steal);
  assert.ok(events.includes("leak"));
  game.eggs = 1; game.spawn("badger", "a", PATH_DATA.a.length - 0.01); run(game, 0.2);
  assert.equal(game.status, "ended"); assert.ok(events.includes("gameOver"));
});

test("medic shields block thieves and the revival nest saves the game once", () => {
  const events = [];
  const game = new DefenseEngine({ onEvent: (e) => events.push(e.type), random: seeded() }); game.start();
  game.wave = 9; game.korn = 99999;
  const m = game.build("medic", 5, 5);
  game.upgrade(m.id); game.upgrade(m.id); game.upgrade(m.id, "shield");
  game.startWave();
  game.queue = [];
  game.spawn("fox", "a", PATH_DATA.a.length - 0.01); run(game, 0.1);
  assert.equal(game.eggs, START_EGGS); assert.ok(events.includes("shielded"));
  const r = game.build("medic", 5, 7);
  game.upgrade(r.id); game.upgrade(r.id); game.upgrade(r.id, "revive");
  game.shields = 0; game.eggs = 1;
  game.spawn("fox", "a", PATH_DATA.a.length - 0.01); run(game, 0.1);
  assert.equal(game.eggs, 10); assert.equal(game.status, "playing"); assert.ok(events.includes("revive"));
});

test("golden chickens pay Korn after a wave, medics buff nearby towers", () => {
  const game = new DefenseEngine({ random: seeded() }); game.start();
  game.wave = 5; game.korn = 1000;
  game.build("golden", 5, 5);
  const gun = game.build("gatling", 6, 5);
  game.waveActive = true;
  const before = game.korn;
  game.clearWave();
  assert.equal(game.korn, before + 20 + 5 * 4 + TOWERS.golden.income);
  assert.equal(game.buffFor(gun), 1);
  game.wave = 9; game.build("medic", 7, 5);
  assert.ok(game.buffFor(gun) > 1);
});

test("a tower shoots, kills pay Korn and score, a cleared wave pays a bonus", () => {
  const events = [];
  const game = new DefenseEngine({ onEvent: (e) => events.push(e), random: seeded(3) }); game.start();
  game.korn = 2000;
  for (const [c, r] of [[3, 3], [5, 3], [3, 5], [5, 7], [8, 8], [10, 5]]) game.build("gatling", c, r);
  game.startWave();
  run(game, 60);
  assert.equal(game.waveActive, false);
  assert.ok(game.kills >= makeWave(1, seeded(3)).length - 1);
  assert.ok(game.score > 0);
  assert.ok(events.some((e) => e.type === "waveClear"));
  assert.equal(game.eggs, START_EGGS);
});

test("calling the next wave early pays a bonus", () => {
  const game = new DefenseEngine({ random: seeded(5) }); game.start();
  game.startWave(); run(game, 30);
  game.spawn("badger", "a");
  const before = game.korn;
  assert.equal(game.startWave(), true);
  assert.ok(game.korn > before);
});

test("escalation: exponential hit points, bosses every ten waves, second path at 12, chaos from 15", () => {
  assert.ok(hpScale(10) > 2 && hpScale(10) < 3, "gentle start");
  assert.ok(hpScale(30) > 60);
  assert.ok(makeWave(10, seeded()).some((s) => s.kind === "wolf"));
  assert.ok(!makeWave(9, seeded()).some((s) => s.kind === "wolf"));
  assert.ok(makeWave(25, seeded()).length > makeWave(5, seeded()).length * 2.5);
  assert.ok(makeWave(12, seeded()).some((s) => s.path === "b"));
  assert.ok(!makeWave(11, seeded()).some((s) => s.path === "b"));
  assert.deepEqual(pickMods(14, seeded()), []);
  assert.equal(pickMods(15, seeded()).length, 1);
  assert.ok(pickMods(40, seeded()).length >= 3);
});

test("rat kings split, shells skip crows, frost slows, poison ticks, sniper pierce ignores armor", () => {
  const game = new DefenseEngine({ random: seeded() }); game.start();
  const king = game.spawn("ratking", "a", 5);
  game.damage(king, 1e9);
  assert.equal(game.enemies.filter((e) => e.kind === "rat").length, ENEMIES.ratking.split);
  const fox = game.spawn("fox", "a", 8), crow = game.spawn("crow", "a", 0);
  crow.x = fox.x; crow.y = fox.y;
  const crowHp = crow.hp, foxHp = fox.hp;
  game.explode({ kind: "shell", x: fox.x, y: fox.y, splash: 1, damage: 10 });
  assert.ok(fox.hp < foxHp); assert.equal(crow.hp, crowHp);
  game.explode({ kind: "frost", x: fox.x, y: fox.y, splash: 1, damage: 1, slow: 0.45, slowTime: 2 });
  assert.ok(fox.slowUntil > game.time);
  game.applyEffects(fox, { poison: 30, poisonTime: 2 });
  const hp = fox.hp; run(game, 0.5);
  assert.ok(fox.hp < hp - 10);
  const badger = game.spawn("badger", "a", 2);
  const a = game.damage(badger, 10, null), b = game.damage(badger, 10, null, { pierce: true });
  assert.ok(b > a);
});
