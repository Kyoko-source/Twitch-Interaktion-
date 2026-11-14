import test from "node:test";
import assert from "node:assert/strict";
import { SnakeEngine, DIRECTIONS } from "./SnakeEngine.mjs";

test("buffered corner inputs cannot reverse into the neck between simulation ticks", () => {
  const game = new SnakeEngine(); game.start();
  assert.equal(game.turn("left"), false);
  assert.equal(game.turn("up"), true);
  assert.equal(game.turn("down"), false);
  assert.equal(game.turn("left"), true);
  assert.equal(game.turn("down"), false); // At most two buffered corners.
  game.step(); assert.deepEqual(game.snake[0], { x: 8, y: 9 });
  game.step(); assert.deepEqual(game.snake[0], { x: 7, y: 9 });
  assert.equal(game.status, "playing");
});

test("eggs grow the snake; quick eggs build a combo multiplier and speed increases gradually", () => {
  const events = [];
  const game = new SnakeEngine({ onEvent: (event) => events.push(event), random: () => 0.99 }); game.start();
  for (let i = 0; i < 6; i++) game.step();
  assert.equal(game.score, 10); assert.equal(game.snake.length, 6);
  assert.equal(game.previous.length, 6); assert.equal(game.interval, 155);
  for (let i = 0; i < 4; i++) {
    game.food = { x: game.snake[0].x + 1, y: game.snake[0].y }; game.step();
  }
  // 10 + 20 + 30 + 40 + 50: every egg inside the combo window is worth more.
  assert.equal(game.level, 2); assert.equal(game.score, 150);
  assert.equal(game.interval, 148); assert.equal(game.combo, 5); assert.equal(game.bestCombo, 5);
  assert.equal(events.filter((event) => event.type === "level").length, 1);
  assert.deepEqual(events.filter((event) => event.type === "eat").map((event) => event.points), [10, 20, 30, 40, 50]);
});

test("a slow egg resets the combo", () => {
  const game = new SnakeEngine({ random: () => 0.99 }); game.start();
  game.food = { x: 9, y: 10 }; game.step();
  game.elapsed += 5000;
  game.food = { x: 10, y: 10 }; game.step();
  assert.equal(game.combo, 1); assert.equal(game.score, 20);
});

test("bonus items: rainbow doubles points, crystal slows time, star sheds the tail, all expire", () => {
  const events = [];
  const game = new SnakeEngine({ onEvent: (event) => events.push(event), random: () => 0.99 }); game.start();
  game.bonus = { kind: "rainbow", x: 9, y: 10, until: 7000 }; game.step();
  assert.equal(game.score, 50); assert.equal(game.frenzy, true);
  game.food = { x: 10, y: 10 }; game.step();
  assert.equal(game.score, 70, "frenzy doubles the egg");
  game.bonus = { kind: "crystal", x: 11, y: 10, until: 7000 }; game.step();
  assert.equal(game.slow, true); assert.equal(game.interval, Math.round(155 * 1.6));
  for (let i = 0; i < 4; i++) { game.food = { x: game.snake[0].x + 1, y: 10 }; game.step(); }
  const length = game.snake.length;
  game.bonus = { kind: "star", x: game.snake[0].x + 1, y: 10, until: game.elapsed + 7000 }; game.step();
  assert.equal(game.snake.length, length - 3);
  game.bonus = { kind: "star", x: 0, y: 0, until: game.elapsed + 100 };
  game.advance(150);
  assert.equal(game.bonus, null);
  assert.ok(events.some((event) => event.type === "bonusExpire"));
  game.frenzyUntil = game.elapsed + 10; game.advance(20);
  assert.ok(events.some((event) => event.type === "frenzyEnd"));
});

test("thorns grow from level three, never right in front of the head, and are deadly", () => {
  const events = [];
  const game = new SnakeEngine({ onEvent: (event) => events.push(event), random: () => 0.5 }); game.start();
  for (let i = 0; i < 10; i++) { game.food = { x: (game.snake[0].x + 1) % game.cols, y: game.snake[0].y }; game.step(); }
  assert.equal(game.level, 3);
  assert.equal(game.thorns.length, 2);
  const head = game.snake[0];
  for (const thorn of game.thorns) assert.ok(game.distance(thorn, head) >= 6);
  assert.ok(events.some((event) => event.type === "thorns"));
  game.thorns = [{ x: (head.x + 1) % game.cols, y: head.y }];
  game.food = { x: 0, y: 0 }; game.step();
  assert.equal(game.reason, "collision"); assert.equal(game.cause, "thorn");
});

test("portal wrapping stays safe and emits feedback without extra points", () => {
  const events = [];
  const game = new SnakeEngine({ onEvent: (event) => events.push(event) }); game.start();
  game.snake = [{ x: 35, y: 2 }, { x: 34, y: 2 }, { x: 33, y: 2 }];
  game.step();
  assert.deepEqual(game.snake[0], { x: 0, y: 2 });
  assert.equal(game.status, "playing"); assert.equal(game.score, 0);
  assert.equal(events[0].type, "portal");
});

test("moving into a departing tail is legal; a growing tail still collides", () => {
  const game = new SnakeEngine();
  const prepare = (food) => {
    game.start(); game.snake = [{ x: 1, y: 1 }, { x: 1, y: 2 }, { x: 2, y: 2 }, { x: 2, y: 1 }];
    game.direction = DIRECTIONS.right; game.food = food;
  };
  prepare({ x: 10, y: 10 }); game.step();
  assert.equal(game.status, "playing"); assert.deepEqual(game.snake[0], { x: 2, y: 1 });
  prepare({ x: 2, y: 1 }); game.step(); assert.equal(game.reason, "collision");
});

test("food always uses a free cell, even with repeated random values or an almost full board", () => {
  const game = new SnakeEngine({ cols: 3, rows: 2, random: () => 0 });
  game.snake = [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }];
  assert.deepEqual(game.spawnFood(), { x: 2, y: 1 });
  game.snake.push({ x: 2, y: 1 }); assert.equal(game.spawnFood(), null);
});

test("filling the entire garden finishes as a win without a food-spawning loop", () => {
  const game = new SnakeEngine({ cols: 3, rows: 2 }); game.start();
  game.snake = [{ x: 1, y: 0 }, { x: 0, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }, { x: 2, y: 1 }];
  game.direction = DIRECTIONS.right; game.food = { x: 2, y: 0 }; game.step();
  assert.equal(game.status, "ended"); assert.equal(game.reason, "won");
  assert.equal(game.score, 10); assert.equal(game.snake.length, 6); assert.equal(game.food, null);
});

test("pause freezes time and input, resume preserves the round, long frames have bounded catch-up", () => {
  const game = new SnakeEngine(); game.start(); game.advance(100);
  const cells = JSON.stringify(game.snake); game.pause();
  game.advance(60000); assert.equal(game.turn("up"), false);
  assert.equal(JSON.stringify(game.snake), cells); assert.equal(game.elapsed, 100);
  game.resume(); game.advance(55); assert.deepEqual(game.snake[0], { x: 9, y: 10 });
  game.advance(60000); assert.equal(game.elapsed, 405); // At most 250ms caught up.
  game.finish(); const score = game.score;
  game.advance(500); assert.equal(game.score, score); assert.equal(game.reason, "finished");
});

test("a real body collision ends once and does not award the food behind it", () => {
  const events = [];
  const game = new SnakeEngine({ onEvent: (event) => events.push(event) }); game.start();
  game.snake = [{ x: 1, y: 1 }, { x: 2, y: 1 }, { x: 2, y: 2 }, { x: 1, y: 2 }, { x: 0, y: 2 }];
  game.direction = DIRECTIONS.right; game.step(); game.step(); game.finish();
  assert.equal(game.reason, "collision"); assert.equal(game.cause, "self"); assert.equal(game.score, 0);
  assert.equal(events.filter((event) => event.type === "collision").length, 1);
});

test("existing records stay beatable: the garden can exceed the old board's maximum legal score", () => {
  const game = new SnakeEngine();
  const previousMaximum = (38 * 17 - 3) * 10;
  const gardenMaximum = (game.cols * game.rows - game.snake.length) * 10;
  assert.ok(gardenMaximum > previousMaximum);
});
