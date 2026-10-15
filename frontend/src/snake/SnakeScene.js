import { SnakeEngine } from "./SnakeEngine.mjs";

const WIDTH = 1120, HEIGHT = 640, TILE = 26;
const FIELD = { x: 92, y: 60, width: 936, height: 520 };
const TAU = Math.PI * 2;
const cellPoint = ({ x, y }) => ({ x: FIELD.x + (x + 0.5) * TILE, y: FIELD.y + (y + 0.5) * TILE });

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("Die Spielgrafik konnte nicht geladen werden. Bitte versuche es erneut."));
    img.src = src;
  });
}

class SnakeAudio {
  constructor() { this.muted = false; this.context = null; }
  unlock() {
    if (this.muted) return;
    try {
      const Audio = window.AudioContext || window.webkitAudioContext;
      if (!Audio) return;
      this.context ||= new Audio();
      this.context.resume().catch(() => {});
    } catch { /* Audio is optional on browsers that block it. */ }
  }
  note(frequency, delay, duration = 0.16, type = "sine", volume = 0.055) {
    if (this.muted || this.context?.state !== "running") return;
    const start = this.context.currentTime + delay;
    const oscillator = this.context.createOscillator(), gain = this.context.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, start);
    gain.gain.setValueAtTime(0, start);
    gain.gain.linearRampToValueAtTime(volume, start + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    oscillator.connect(gain); gain.connect(this.context.destination);
    oscillator.start(start); oscillator.stop(start + duration + 0.02);
    oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
  }
  play(type) {
    if (type === "eat") [660, 990, 1320].forEach((f, i) => this.note(f, i * 0.035));
    if (type === "level") [523, 659, 784, 1047].forEach((f, i) => this.note(f, i * 0.08, 0.3));
    if (type === "start") [392, 523, 784].forEach((f, i) => this.note(f, i * 0.075));
    if (type === "collision") [220, 165, 110].forEach((f, i) => this.note(f, i * 0.09, 0.22, "triangle"));
    if (type === "portal") this.note(440, 0, 0.12, "triangle", 0.025);
  }
  destroy() { this.context?.close().catch(() => {}); }
}

export async function mountSnakeGame(canvas, onChange, onFeedback) {
  const [garden, sprites] = await Promise.all([
    loadImage("/assets/snake/night-garden.png"), loadImage("/assets/snake/jade-sprites.png"),
  ]);
  return new SnakeScene(canvas, garden, sprites, onChange, onFeedback);
}

class SnakeScene {
  constructor(canvas, garden, sprites, onChange, onFeedback) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    if (!this.ctx) throw new Error("Dein Browser unterstützt dieses Spielfeld leider nicht.");
    this.sprites = sprites;
    this.audio = new SnakeAudio();
    this.effects = [];
    this.shake = 0;
    this.flash = 0;
    this.destroyed = false;
    this.onFeedback = onFeedback;
    this.motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    this.reducedMotion = this.motionQuery.matches;
    this.onMotion = (event) => { this.reducedMotion = event.matches; };
    this.motionQuery.addEventListener("change", this.onMotion);
    this.engine = new SnakeEngine({ onChange, onEvent: (event) => this.event(event) });
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = WIDTH * this.dpr; canvas.height = HEIGHT * this.dpr;
    this.backdrop = document.createElement("canvas");
    this.backdrop.width = canvas.width; this.backdrop.height = canvas.height;
    const bg = this.backdrop.getContext("2d");
    bg.scale(this.dpr, this.dpr);
    bg.drawImage(garden, 0, 0, WIDTH, HEIGHT);
    for (let y = 0; y < this.engine.rows; y++) {
      for (let x = 0; x < this.engine.cols; x++) {
        bg.fillStyle = (x + y) % 2 ? "rgba(78, 184, 170, 0.045)" : "rgba(0, 9, 14, 0.065)";
        bg.fillRect(FIELD.x + x * TILE, FIELD.y + y * TILE, TILE, TILE);
      }
    }
    bg.strokeStyle = "rgba(91, 198, 182, 0.065)"; bg.lineWidth = 1;
    bg.beginPath();
    for (let x = 0; x <= this.engine.cols; x++) {
      bg.moveTo(FIELD.x + x * TILE, FIELD.y); bg.lineTo(FIELD.x + x * TILE, FIELD.y + FIELD.height);
    }
    for (let y = 0; y <= this.engine.rows; y++) {
      bg.moveTo(FIELD.x, FIELD.y + y * TILE); bg.lineTo(FIELD.x + FIELD.width, FIELD.y + y * TILE);
    }
    bg.stroke();
    this.fireflies = Array.from({ length: 26 }, (_, index) => ({
      x: 65 + ((index * 197) % 990), y: 40 + ((index * 113) % 560), phase: index * 2.4,
    }));
    // Inspection entry point, consistent with the other arcade games.
    canvas.__snakeGame = this;
    this.lastTime = performance.now();
    this.frame = requestAnimationFrame((time) => this.loop(time));
  }

  start() {
    this.audio.unlock(); this.audio.play("start");
    this.effects = []; this.shake = 0; this.flash = 0;
    this.lastTime = performance.now(); this.engine.start();
  }
  togglePause() {
    if (this.engine.status === "paused") { this.lastTime = performance.now(); this.audio.unlock(); this.engine.resume(); }
    else this.engine.pause();
  }
  turn(direction) { return this.engine.turn(direction); }
  setMuted(value) { this.audio.muted = value; if (!value) this.audio.unlock(); }

  event(event) {
    this.audio.play(event.type);
    if (event.type === "eat" || event.type === "portal") {
      const point = cellPoint(event.cell);
      const count = this.reducedMotion ? 0 : event.type === "eat" ? 18 : 10;
      for (let i = 0; i < count; i++) {
        const angle = (i / count) * TAU, speed = 35 + Math.random() * 90;
        this.effects.push({ type: "spark", x: point.x, y: point.y, vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed, age: 0, life: 0.45 + Math.random() * 0.4,
          color: event.type === "eat" ? "#ffe2a0" : "#85f9e4" });
      }
      if (event.type === "eat") this.effects.push({ type: "text", x: point.x, y: point.y - 20,
        vy: -28, vx: 0, age: 0, life: 0.95, color: "#ffe2a0", text: "+10" });
      if (event.type === "portal") this.flash = 0.28;
    }
    if (event.type === "collision") this.shake = this.reducedMotion ? 0 : 0.24;
    if (event.type === "level") this.flash = 0.6;
    this.onFeedback(event);
  }

  sprite(kind, x, y, size, angle = 0, alpha = 1) {
    const col = kind === "body" || kind === "tail" ? 1 : 0;
    const row = kind === "egg" || kind === "tail" ? 1 : 0;
    const sw = this.sprites.width / 2, sh = this.sprites.height / 2;
    const ctx = this.ctx;
    ctx.save(); ctx.translate(x, y); ctx.rotate(angle); ctx.globalAlpha = alpha;
    ctx.drawImage(this.sprites, col * sw, row * sh, sw, sh, -size / 2, -size / 2, size, size);
    ctx.restore();
  }

  egg(point, time, size = TILE * 1.5) {
    const ctx = this.ctx;
    const bob = this.reducedMotion ? 0 : Math.sin(time * 3.2) * 2;
    const radius = size * (0.8 + Math.sin(time * 2) * 0.06);
    const glow = ctx.createRadialGradient(point.x, point.y, 2, point.x, point.y, radius);
    glow.addColorStop(0, "rgba(255, 204, 89, 0.23)"); glow.addColorStop(1, "rgba(255, 204, 89, 0)");
    ctx.fillStyle = glow; ctx.fillRect(point.x - radius, point.y - radius, radius * 2, radius * 2);
    this.sprite("egg", point.x, point.y + bob, size);
  }

  serpent(points, scale = 1, headAngle = 0, alpha = 1) {
    const tail = points.at(-1), beforeTail = points.at(-2) || tail;
    this.sprite("tail", tail.x, tail.y, TILE * 1.5 * scale,
      Math.atan2(beforeTail.y - tail.y, beforeTail.x - tail.x), alpha);
    for (let i = points.length - 2; i >= 0; i--) {
      const a = points[i + 1], b = points[i];
      // Disconnected points occur at portals; never draw a line across the board.
      if (Math.abs(a.x - b.x) > TILE * 2 || Math.abs(a.y - b.y) > TILE * 2) continue;
      const steps = Math.max(1, Math.ceil(Math.hypot(b.x - a.x, b.y - a.y) / (TILE * 0.42)));
      const angle = Math.atan2(b.y - a.y, b.x - a.x);
      for (let j = 0; j < steps; j++) {
        const amount = j / steps;
        this.sprite("body", a.x + (b.x - a.x) * amount, a.y + (b.y - a.y) * amount,
          TILE * 1.42 * scale, angle, alpha);
      }
    }
    this.sprite("head", points[0].x, points[0].y, TILE * 1.9 * scale, headAngle, alpha);
  }

  drawReady(time) {
    const points = [];
    for (let i = 0; i < 34; i++) {
      const progress = i / 33;
      points.push({ x: 247 + Math.sin(progress * Math.PI * 2.1 + 0.2) * 53,
        y: 435 - progress * 265 });
    }
    const breath = this.reducedMotion ? 1 : 1 + Math.sin(time * 1.9) * 0.018;
    this.serpent(points, (52.8 / TILE) * breath, 0.22);
    this.egg({ x: 865, y: 320 }, time, 75);
  }

  drawPlaying(time) {
    const engine = this.engine;
    if (engine.food) this.egg(cellPoint(engine.food), time);
    const amount = this.reducedMotion ? 1 : Math.min(1, engine.accumulator / engine.interval);
    const points = engine.snake.map((cell, index) => {
      const old = engine.previous[index] || cell;
      let dx = cell.x - old.x, dy = cell.y - old.y;
      if (Math.abs(dx) > engine.cols / 2) dx -= Math.sign(dx) * engine.cols;
      if (Math.abs(dy) > engine.rows / 2) dy -= Math.sign(dy) * engine.rows;
      const x = ((old.x + dx * amount + 0.5 + engine.cols) % engine.cols) - 0.5;
      const y = ((old.y + dy * amount + 0.5 + engine.rows) % engine.rows) - 0.5;
      return cellPoint({ x, y });
    });
    const angle = Math.atan2(engine.direction.y, engine.direction.x);
    const ctx = this.ctx;
    ctx.save(); ctx.beginPath(); ctx.rect(FIELD.x - 10, FIELD.y - 10, FIELD.width + 20, FIELD.height + 20); ctx.clip();
    this.serpent(points, 1, angle, engine.reason === "collision" ? 0.65 : 1);
    ctx.restore();
  }

  loop(now) {
    if (this.destroyed) return;
    const dt = Math.min(50, Math.max(0, now - this.lastTime)); this.lastTime = now;
    if (!document.hidden) {
      this.engine.advance(dt);
      this.draw(now / 1000, dt / 1000);
    }
    this.frame = requestAnimationFrame((time) => this.loop(time));
  }

  draw(time, dt) {
    const ctx = this.ctx;
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.clearRect(0, 0, WIDTH, HEIGHT);
    ctx.save();
    if (this.shake > 0) {
      ctx.translate(Math.sin(time * 112) * this.shake * 13, Math.cos(time * 91) * this.shake * 9);
      this.shake = Math.max(0, this.shake - dt);
    }
    ctx.drawImage(this.backdrop, 0, 0, WIDTH, HEIGHT);
    if (this.flash > 0) {
      ctx.strokeStyle = `rgba(129,244,211,${this.flash * 0.6})`; ctx.lineWidth = 3;
      ctx.strokeRect(FIELD.x, FIELD.y, FIELD.width, FIELD.height); this.flash = Math.max(0, this.flash - dt);
    }
    if (this.engine.status === "ready") this.drawReady(time);
    else this.drawPlaying(time);
    if (!this.reducedMotion) this.fireflies.forEach((fly) => {
      const x = fly.x + Math.sin(time * 0.3 + fly.phase) * 7, y = fly.y + Math.cos(time * 0.4 + fly.phase) * 9;
      const alpha = 0.15 + ((Math.sin(time * 1.3 + fly.phase) + 1) / 2) * 0.55;
      ctx.fillStyle = `rgba(255,224,148,${alpha})`;
      ctx.beginPath(); ctx.arc(x, y, 1.6, 0, TAU); ctx.fill();
    });
    this.effects = this.effects.filter((effect) => effect.age < effect.life);
    this.effects.forEach((effect) => {
      effect.age += dt; effect.x += effect.vx * dt; effect.y += effect.vy * dt;
      ctx.save(); ctx.globalAlpha = Math.max(0, 1 - effect.age / effect.life);
      ctx.fillStyle = effect.color;
      if (effect.type === "text") {
        ctx.font = "bold 23px Segoe UI, sans-serif"; ctx.textAlign = "center";
        ctx.shadowColor = "#061c21"; ctx.shadowBlur = 8;
        ctx.fillText(effect.text, effect.x, effect.y);
      } else {
        ctx.translate(effect.x, effect.y); ctx.rotate(effect.age * 2);
        ctx.beginPath(); ctx.moveTo(0, -3); ctx.lineTo(2, 0); ctx.lineTo(0, 3); ctx.lineTo(-2, 0); ctx.fill();
      }
      ctx.restore();
    });
    ctx.restore();
  }

  destroy() {
    this.destroyed = true;
    cancelAnimationFrame(this.frame);
    this.motionQuery.removeEventListener("change", this.onMotion);
    this.audio.destroy();
    delete this.canvas.__snakeGame;
  }
}
