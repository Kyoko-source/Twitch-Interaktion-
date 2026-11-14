export const DIRECTIONS = Object.freeze({
  up: { x: 0, y: -1 }, down: { x: 0, y: 1 },
  left: { x: -1, y: 0 }, right: { x: 1, y: 0 },
});

// Timings in milliseconds of game time.
export const COMBO_WINDOW = 4500;
export const BONUS_LIFETIME = 7000;
export const FRENZY_TIME = 8000;
export const SLOW_TIME = 6000;
export const BONUS_KINDS = ["rainbow", "crystal", "star"];
export const THORN_START_LEVEL = 3;

const sameCell = (a, b) => a.x === b.x && a.y === b.y;
const copyCells = (cells) => cells.map((cell) => ({ ...cell }));

/** Grid rules are independent of rendering, frame rate and the reward API. */
export class SnakeEngine {
  constructor({ cols = 36, rows = 20, random = Math.random, onChange = () => {}, onEvent = () => {} } = {}) {
    this.cols = cols;
    this.rows = rows;
    this.random = random;
    this.onChange = onChange;
    this.onEvent = onEvent;
    this.reset("ready");
  }

  reset(status) {
    const x = Math.min(8, this.cols - 2), y = Math.floor(this.rows / 2);
    this.snake = Array.from({ length: Math.min(5, x + 1) }, (_, index) => ({ x: x - index, y }));
    this.previous = copyCells(this.snake);
    this.direction = DIRECTIONS.right;
    this.queue = [];
    this.food = { x: Math.min(x + 6, this.cols - 1), y };
    this.bonus = null;          // { kind, x, y, until }
    this.thorns = [];           // deadly bramble cells, from level 3
    this.frenzyUntil = 0;       // double points
    this.slowUntil = 0;         // slower ticks
    this.score = 0;
    this.eggs = 0;
    this.level = 1;
    this.combo = 0;
    this.bestCombo = 0;
    this.lastEggAt = -Infinity;
    this.elapsed = 0;
    this.accumulator = 0;
    this.status = status;
    this.reason = "";
    this.cause = "";
    this.emit();
  }

  get frenzy() { return this.elapsed < this.frenzyUntil; }
  get slow() { return this.elapsed < this.slowUntil; }
  get baseInterval() { return Math.max(78, 155 - (this.level - 1) * 7); }
  get interval() { return Math.round(this.baseInterval * (this.slow ? 1.6 : 1)); }
  /** 0..1 of the combo window that is left. */
  get comboLeft() { return this.combo > 0 ? Math.max(0, 1 - (this.elapsed - this.lastEggAt) / COMBO_WINDOW) : 0; }

  snapshot() {
    return { status: this.status, score: this.score, eggs: this.eggs, level: this.level,
      length: this.snake.length, combo: this.combo, bestCombo: this.bestCombo, reason: this.reason, cause: this.cause,
      frenzy: this.frenzy, slow: this.slow };
  }

  emit() { this.onChange(this.snapshot()); }
  start() { this.reset("playing"); }

  turn(name) {
    if (this.status !== "playing") return false;
    const next = DIRECTIONS[name];
    if (!next || this.queue.length >= 2) return false;
    const last = this.queue.at(-1) || this.direction;
    if (sameCell(next, last) || (next.x + last.x === 0 && next.y + last.y === 0)) return false;
    this.queue.push(next);
    return true;
  }

  pause() {
    if (this.status !== "playing") return;
    this.status = "paused";
    this.emit();
  }

  resume() {
    if (this.status !== "paused") return;
    this.status = "playing";
    this.emit();
  }

  finish(reason = "finished", cause = "") {
    if (this.status !== "playing" && this.status !== "paused") return;
    this.status = "ended";
    this.reason = reason;
    this.cause = cause;
    this.onEvent({ type: reason === "collision" ? "collision" : "finish", score: this.score, cause });
    this.emit();
  }

  blocked() {
    const set = new Set(this.snake.map(({ x, y }) => y * this.cols + x));
    for (const { x, y } of this.thorns) set.add(y * this.cols + x);
    if (this.food) set.add(this.food.y * this.cols + this.food.x);
    if (this.bonus) set.add(this.bonus.y * this.cols + this.bonus.x);
    return set;
  }

  // Pick from free cells instead of retrying random positions: always terminates,
  // including on an almost full board and with a deterministic random source.
  freeCell(extra = () => true) {
    const occupied = this.blocked();
    const free = [];
    for (let index = 0; index < this.cols * this.rows; index++) {
      if (occupied.has(index)) continue;
      const cell = { x: index % this.cols, y: Math.floor(index / this.cols) };
      if (extra(cell)) free.push(cell);
    }
    if (!free.length) return null;
    return free[Math.min(free.length - 1, Math.max(0, Math.floor(this.random() * free.length)))];
  }

  spawnFood() {
    const food = this.food;
    this.food = null; // the old egg was just eaten; its cell is free again
    const next = this.freeCell();
    this.food = food;
    return next;
  }

  // Distance on the wrapping board.
  distance(a, b) {
    const dx = Math.abs(a.x - b.x), dy = Math.abs(a.y - b.y);
    return Math.min(dx, this.cols - dx) + Math.min(dy, this.rows - dy);
  }

  growThorns() {
    const target = Math.min(14, (this.level - THORN_START_LEVEL + 1) * 2);
    const head = this.snake[0], dir = this.direction;
    const added = [];
    while (this.thorns.length < target) {
      // Never right in front of the head and never too close to it.
      const cell = this.freeCell((c) => this.distance(c, head) >= 6 && !(Math.sign(c.x - head.x) === dir.x && dir.x !== 0 && c.y === head.y) && !(Math.sign(c.y - head.y) === dir.y && dir.y !== 0 && c.x === head.x));
      if (!cell) break;
      this.thorns.push(cell);
      added.push(cell);
    }
    if (added.length) this.onEvent({ type: "thorns", cells: added });
  }

  maybeSpawnBonus() {
    if (this.bonus || this.eggs < 3 || this.eggs % 3 !== 0) return;
    if (this.random() > 0.75) return;
    const kind = BONUS_KINDS[Math.floor(this.random() * BONUS_KINDS.length) % BONUS_KINDS.length];
    const cell = this.freeCell((c) => this.distance(c, this.snake[0]) >= 4);
    if (!cell) return;
    this.bonus = { kind, ...cell, until: this.elapsed + BONUS_LIFETIME };
    this.onEvent({ type: "bonusSpawn", kind, cell });
  }

  advance(delta) {
    if (this.status !== "playing") return;
    const dt = Math.min(250, Math.max(0, delta));
    const wasFrenzy = this.frenzy, wasSlow = this.slow;
    this.elapsed += dt;
    this.accumulator += dt;
    if (wasFrenzy && !this.frenzy) { this.onEvent({ type: "frenzyEnd" }); this.emit(); }
    if (wasSlow && !this.slow) { this.onEvent({ type: "slowEnd" }); this.emit(); }
    if (this.bonus && this.elapsed >= this.bonus.until) { this.onEvent({ type: "bonusExpire", kind: this.bonus.kind, cell: { x: this.bonus.x, y: this.bonus.y } }); this.bonus = null; }
    while (this.accumulator >= this.interval && this.status === "playing") {
      this.accumulator -= this.interval;
      this.step();
    }
  }

  step() {
    if (this.status !== "playing") return;
    if (this.queue.length) this.direction = this.queue.shift();
    const head = this.snake[0];
    const raw = { x: head.x + this.direction.x, y: head.y + this.direction.y };
    const next = { x: (raw.x + this.cols) % this.cols, y: (raw.y + this.rows) % this.rows };
    const eating = this.food && sameCell(next, this.food);
    if (this.thorns.some((cell) => sameCell(next, cell))) { this.finish("collision", "thorn"); return; }
    // A departing tail is safe to enter on a non-growing move.
    const body = eating ? this.snake : this.snake.slice(0, -1);
    if (body.some((cell) => sameCell(next, cell))) { this.finish("collision", "self"); return; }
    this.previous = copyCells(this.snake);
    this.snake.unshift(next);
    if (raw.x !== next.x || raw.y !== next.y) this.onEvent({ type: "portal", cell: next, from: { ...head } });
    if (this.bonus && sameCell(next, this.bonus)) this.collectBonus(next);
    if (eating) {
      this.previous.push({ ...this.previous.at(-1) });
      this.eggs++;
      this.combo = this.elapsed - this.lastEggAt <= COMBO_WINDOW ? Math.min(5, this.combo + 1) : 1;
      this.bestCombo = Math.max(this.bestCombo, this.combo);
      this.lastEggAt = this.elapsed;
      const points = 10 * this.combo * (this.frenzy ? 2 : 1);
      this.score += points;
      const level = 1 + Math.floor(this.eggs / 5);
      this.onEvent({ type: "eat", cell: next, combo: this.combo, points, frenzy: this.frenzy, score: this.score });
      if (level !== this.level) {
        this.level = level;
        this.onEvent({ type: "level", level });
        if (level >= THORN_START_LEVEL) this.growThorns();
      }
      this.food = this.spawnFood();
      if (!this.food) { this.finish("won"); return; }
      this.maybeSpawnBonus();
      this.emit();
    } else this.snake.pop();
  }

  collectBonus(cell) {
    const { kind } = this.bonus;
    this.bonus = null;
    let points = 0;
    if (kind === "rainbow") { points = 50; this.frenzyUntil = this.elapsed + FRENZY_TIME; }
    if (kind === "crystal") { points = 25; this.slowUntil = this.elapsed + SLOW_TIME; }
    if (kind === "star") {
      points = 30;
      // Shed skin: drop up to three tail segments, but never below five.
      const drop = Math.max(0, Math.min(3, this.snake.length - 5));
      if (drop) { this.snake.splice(-drop); this.previous.splice(-drop); }
    }
    this.score += points;
    this.onEvent({ type: "bonus", kind, cell, points, score: this.score });
    this.emit();
  }
}
