import test from "node:test";
import assert from "node:assert/strict";
import { PinballEngine, MISSIONS } from "./engine.js";
import { LAYOUT } from "./table.js";

function seeded(seed = 3) { return () => (seed = (seed * 16807) % 2147483647) / 2147483647; }
function run(e, seconds) { for (let t = 0; t < seconds; t += 1 / 120) e.update(1 / 120); }
function launched() {
  const e = new PinballEngine({ random: seeded() });
  e.start();
  const b = e.world.balls[0];
  e.status = "play";
  e.switchHit();
  return { e, b };
}
const events = (e) => { const list = []; e.on((type) => list.push(type)); return list; };

test("a full plunge leaves the shooter lane and circles the top orbit", () => {
  const e = new PinballEngine({ random: seeded() });
  const seen = events(e);
  e.start();
  e.setPlunger(true);
  run(e, 1.5);
  e.setPlunger(false);
  run(e, 1.2);
  assert.equal(e.status, "play");
  assert.ok(seen.includes("launch"));
  assert.ok(e.world.balls[0].y < 18, "ball left the plunger lane");
});

test("drop targets open the VIP scoop; three locks start a three-ball multiball", () => {
  const { e, b } = launched();
  const seen = events(e);
  for (let lock = 1; lock <= 3; lock++) {
    for (const d of e.table.drops) e.dropHit(d);
    assert.equal(e.vipLit, true);
    e.scoop(b);
    if (lock < 3) {
      assert.equal(e.locks, lock);
      run(e, 1.6);
      assert.equal(b.held, null, "virtual lock kicks the ball back out");
      b.x = 3; b.y = 12; b.vx = 0; b.vy = 0; b.ignoreScoopUntil = 0;
      run(e, 0.1);
      e.dropsResetPending = false; e.raiseDrops();
    }
  }
  assert.equal(e.multiball, true);
  run(e, 3);
  assert.equal(e.world.balls.length, 3);
  assert.ok(seen.includes("multiball"));
});

test("all four jackpots light the super jackpot at the scoop", () => {
  const { e, b } = launched();
  e.startMultiball();
  run(e, 2.5);
  const before = e.score;
  for (const shot of ["rampL", "rampR", "orbitL", "orbitR"]) { e.lastMajorAt = -99; e.major(shot, 1000, shot); }
  assert.equal(e.stats.jackpots, 4);
  assert.equal(e.superLit, true);
  b.held = null; e.scoop(b);
  assert.equal(e.superLit, false);
  assert.ok(e.score - before >= 500_000 * 4 + 500_000 * 4, "four jackpots plus a 4x super jackpot");
});

test("missions: orbits light them, the left ramp starts them, five completed start LAST CALL", () => {
  const { e, b } = launched();
  const seen = events(e);
  for (let i = 0; i < 2; i++) { e.orbitStart = { id: "orbitL", at: e.time }; e.orbitSensor("orbitR", 1); }
  assert.equal(e.missionLit, true);
  for (let n = 0; n < MISSIONS.length; n++) {
    e.missionLit = true;
    e.startRamp(b, "rampL");
    b.rail = null;
    assert.equal(e.mission?.id, MISSIONS[n].id, `mission ${n} started`);
    e.progressMission(MISSIONS[n].id, MISSIONS[n].goal);
    assert.equal(e.mission, null);
  }
  assert.ok(seen.includes("missionComplete"));
  assert.equal(e.extraBallLit, true);
  run(e, 3.2);
  assert.equal(e.wizard, true);
  run(e, 3);
  assert.ok(e.world.balls.length >= 3);
});

test("a timed mission runs out and can be restarted", () => {
  const { e, b } = launched();
  e.missionLit = true;
  e.startRamp(b, "rampL");
  b.rail = null; b.x = 3; b.y = 12;
  e.mission.until = e.time + 0.05;
  e.ballSaveUntil = e.time + 99;
  run(e, 0.2);
  assert.equal(e.mission, null);
  assert.equal(e.missionLit, true);
});

test("extra ball is collected at the right ramp and played after the drain", () => {
  const { e, b } = launched();
  e.extraBallLit = true;
  e.startRamp(b, "rampR");
  assert.equal(e.extraBalls, 1);
  b.rail = null;
  e.ballSaveUntil = 0; e.ballSaveArmed = false;
  e.drain(b);
  run(e, 8);
  assert.equal(e.status, "ready");
  assert.equal(e.ball, 1, "shoot again keeps the ball number");
  assert.equal(e.extraBalls, 0);
});

test("ball save re-serves a quickly drained ball", () => {
  const { e, b } = launched();
  const seen = events(e);
  e.drain(b);
  run(e, 1.2);
  assert.ok(seen.includes("ballSave"));
  assert.equal(e.world.balls.length, 1);
  assert.equal(e.ball, 1);
});

test("three nudges in a row tilt the machine: dead flippers, no bonus", () => {
  const { e, b } = launched();
  e.ballStats.ramps = 5;
  for (let i = 0; i < 3; i++) { e.nudge(1); run(e, 0.4); }
  assert.equal(e.tilted, true);
  e.setFlipper("left", true);
  assert.equal(e.table.flipL.pressed, false);
  const before = e.score;
  e.ballSaveUntil = 0;
  e.drain(b);
  run(e, 6);
  assert.equal(e.score, before, "tilted ball scores no bonus");
  assert.equal(e.ball, 2);
});

test("end of ball bonus is multiplied by the BAR lanes bonus multiplier", () => {
  const { e, b } = launched();
  e.skillActive = false;
  for (let i = 0; i < 3; i++) e.lane(i);
  assert.equal(e.bonusX, 2);
  e.ballStats = { ramps: 2, orbits: 0, bumpers: 0, drops: 0, spins: 0 };
  e.ballSaveUntil = 0; e.ballSaveArmed = false;
  const before = e.score;
  e.drain(b);
  run(e, 6);
  assert.equal(e.score - before, 2 * 10_000 * 2);
});

test("three balls and the game is over", () => {
  const e = new PinballEngine({ random: seeded() });
  e.start();
  for (let n = 0; n < 3; n++) {
    e.status = "play"; e.ballSaveUntil = 0; e.ballSaveArmed = false;
    e.drain(e.world.balls[0]);
    run(e, 6);
  }
  assert.equal(e.status, "gameover");
});

test("a ball resting on the raised flipper rolls down and can be shot", () => {
  const e = new PinballEngine({ random: seeded() });
  e.start(); e.status = "play";
  const b = e.world.balls[0];
  b.x = 1.5; b.y = 13.9; b.vx = 0.6; b.vy = 6;
  e.setFlipper("left", true);
  run(e, 2);
  e.setFlipper("left", false);
  run(e, 0.3);
  e.setFlipper("left", true);
  run(e, 0.15);
  assert.ok(b.vy < -10, "ball was shot upward");
  assert.ok(b.x > LAYOUT.wallL && b.x < LAYOUT.wallR);
});
