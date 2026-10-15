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

test("eggs grow the snake and keep the historical ten-point scale; speed increases gradually", () => {
  const events = [];
  const game = new SnakeEngine({ onEvent: (event) => events.push(event), random: () => 0 }); game.start();
  for (let i = 0; i < 6; i++) game.step();
  assert.equal(game.score, 10); assert.equal(game.snake.length, 6);
  assert.equal(game.previous.length, 6); assert.equal(game.interval, 155);
  for (let i = 0; i < 4; i++) {
    game.food = { x: game.snake[0].x + 1, y: game.snake[0].y }; game.step();
  }
  assert.equal(game.level, 2); assert.equal(game.score, 50);
  assert.equal(game.interval, 148); assert.equal(game.combo, 5);
  assert.equal(events.filter((event) => event.type === "level").length, 1);
  assert.equal(events.filter((event) => event.type === "eat").length, 5);
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
  assert.equal(game.reason, "collision"); assert.equal(game.score, 0);
  assert.equal(events.filter((event) => event.type === "collision").length, 1);
});

test("existing records stay beatable: the garden can exceed the old board's maximum legal score", () => {
  const game = new SnakeEngine();
  const previousMaximum = (38 * 17 - 3) * 10;
  const gardenMaximum = (game.cols * game.rows - game.snake.length) * 10;
  assert.ok(gardenMaximum > previousMaximum);
});
