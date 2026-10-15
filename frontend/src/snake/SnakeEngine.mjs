export const DIRECTIONS = Object.freeze({
  up: { x: 0, y: -1 }, down: { x: 0, y: 1 },
  left: { x: -1, y: 0 }, right: { x: 1, y: 0 },
});

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
    this.score = 0;
    this.eggs = 0;
    this.level = 1;
    this.combo = 0;
    this.lastEggAt = -Infinity;
    this.elapsed = 0;
    this.accumulator = 0;
    this.status = status;
    this.reason = "";
    this.emit();
  }

  get interval() { return Math.max(78, 155 - (this.level - 1) * 7); }

  snapshot() {
    return { status: this.status, score: this.score, eggs: this.eggs, level: this.level,
      length: this.snake.length, combo: this.combo, reason: this.reason };
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

  finish(reason = "finished") {
    if (this.status !== "playing" && this.status !== "paused") return;
    this.status = "ended";
    this.reason = reason;
    this.onEvent({ type: reason === "collision" ? "collision" : "finish", score: this.score });
    this.emit();
  }

  spawnFood() {
    // Pick from free cells instead of retrying random positions: always terminates,
    // including on an almost full board and with a deterministic random source.
    const occupied = new Set(this.snake.map(({ x, y }) => y * this.cols + x));
    const free = this.cols * this.rows - occupied.size;
    if (free === 0) return null;
    let target = Math.min(free - 1, Math.max(0, Math.floor(this.random() * free)));
    for (let index = 0; index < this.cols * this.rows; index++) {
      if (!occupied.has(index) && target-- === 0) return { x: index % this.cols, y: Math.floor(index / this.cols) };
    }
    return null;
  }

  advance(delta) {
    if (this.status !== "playing") return;
    const dt = Math.min(250, Math.max(0, delta));
    this.elapsed += dt;
    this.accumulator += dt;
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
    // A departing tail is safe to enter on a non-growing move.
    const body = eating ? this.snake : this.snake.slice(0, -1);
    if (body.some((cell) => sameCell(next, cell))) { this.finish("collision"); return; }
    this.previous = copyCells(this.snake);
    this.snake.unshift(next);
    if (raw.x !== next.x || raw.y !== next.y) this.onEvent({ type: "portal", cell: next });
    if (eating) {
      this.previous.push({ ...this.previous.at(-1) });
      this.eggs++;
      this.score += 10;
      this.combo = this.elapsed - this.lastEggAt <= 4500 ? Math.min(5, this.combo + 1) : 1;
      this.lastEggAt = this.elapsed;
      const level = 1 + Math.floor(this.eggs / 5);
      this.onEvent({ type: "eat", cell: next, combo: this.combo, score: this.score });
      if (level !== this.level) this.onEvent({ type: "level", level });
      this.level = level;
      this.food = this.spawnFood();
      if (!this.food) this.finish("won");
      else this.emit();
    } else this.snake.pop();
  }
}
