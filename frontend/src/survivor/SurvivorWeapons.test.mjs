import test from "node:test";
import assert from "node:assert/strict";
import { updateSpecialWeapons, steerComet, explodeComet, distanceToSegment, evolutionMultiplier } from "./SurvivorWeapons.mjs";

const make = () => ({ player: { x: 0, y: 0 }, weapons: { rail: 1, comet: 0 }, timers: { rail: 0, comet: 0 }, beams: [], shots: [], enemies: [
  { x: 100, y: 0, hp: 200, radius: 10 }, { x: 250, y: 0, hp: 200, radius: 10 }, { x: 200, y: 90, hp: 200, radius: 10 },
] });
const effects = () => ({ visible: (enemies) => enemies, damageMult: 1, cooldownMult: 1, burst() {}, ring() {}, sound() {} });

test("railgun pierces a real row, misses off-axis enemies and respects cooldown", () => {
  const state = make(); updateSpecialWeapons(state, 16, effects());
  assert.equal(state.enemies[0].hp, 115); assert.equal(state.enemies[1].hp, 115); assert.equal(state.enemies[2].hp, 200);
  assert.equal(state.beams.length, 1); assert.equal(state.beams[0].type, "rail");
  updateSpecialWeapons(state, 16, effects()); assert.equal(state.beams.length, 1);
});
test("obstacle-filtered targets receive no rail damage", () => {
  const state = make(), helpers = effects(); helpers.visible = (enemies) => enemies.filter((enemy) => enemy.x < 200);
  updateSpecialWeapons(state, 16, helpers); assert.equal(state.enemies[1].hp, 200);
});
test("weapon evolutions at levels four and eight have actual damage gains", () => {
  assert.equal(evolutionMultiplier(3), 1); assert.equal(evolutionMultiplier(4), 1.22); assert.equal(evolutionMultiplier(8), 1.5);
  const state = make(); state.weapons.rail = 4; state.enemies.forEach((enemy) => { enemy.hp = 1000; });
  updateSpecialWeapons(state, 16, effects()); assert.equal(state.enemies[0].hp, 1000 - 145 * 1.22);
});
test("comet salvo fires only at visible live targets and homing reacquires after target death", () => {
  const state = make(); state.weapons.rail = 0; state.weapons.comet = 4;
  updateSpecialWeapons(state, 16, effects()); assert.equal(state.shots.length, 3);
  const shot = state.shots[0]; shot.target.hp = 0;
  steerComet(shot, state.enemies, 16);
  assert.equal(shot.target, state.enemies[2]); assert.ok(Number.isFinite(shot.vx) && Number.isFinite(shot.vy));
});
test("comet explosion applies radial damage once, even when several collision callbacks overlap", () => {
  const state = make(), shot = { x: 100, y: 0, damage: 50, blastRadius: 70, life: 100 };
  explodeComet(shot, state, effects()); explodeComet(shot, state, effects());
  assert.equal(state.enemies[0].hp, 150); assert.equal(state.enemies[1].hp, 200); assert.equal(state.enemies[2].hp, 200);
  assert.equal(shot.life, 0);
});
test("zero-length beam and empty targets remain finite without spawning phantom projectiles", () => {
  assert.equal(distanceToSegment({ x: 3, y: 4 }, { x: 0, y: 0 }, { x: 0, y: 0 }), 5);
  const state = make(); state.enemies = []; state.weapons.comet = 8; updateSpecialWeapons(state, 16, effects());
  assert.equal(state.shots.length, 0); assert.equal(state.beams.length, 0);
});
