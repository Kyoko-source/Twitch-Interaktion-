import { SnakeEngine } from "./SnakeEngine.mjs";

const WIDTH = 1120, HEIGHT = 640, TILE = 26;
const FIELD = { x: 92, y: 60, width: 936, height: 520 };
const TAU = Math.PI * 2;
const cellPoint = ({ x, y }) => ({ x: FIELD.x + (x + 0.5) * TILE, y: FIELD.y + (y + 0.5) * TILE });
const easeOutBack = (t) => { const c = 1.9; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); };
const LEVEL_HUES = [168, 190, 265, 300, 330, 20, 45];
const COMBO_COLORS = ["#ffe2a0", "#ffe2a0", "#8dffcf", "#7ad8ff", "#c79bff", "#ff7ad9"];
const BONUS_STYLE = {
  rainbow: { label: "REGENBOGEN-EI", color: "#ff7ad9" },
  crystal: { label: "ZEITKRISTALL", color: "#7ad8ff" },
  star: { label: "HÄUTUNGS-STERN", color: "#ffe066" },
};

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("Die Spielgrafik konnte nicht geladen werden. Bitte versuche es erneut."));
    img.src = src;
  });
}

// --------------------------------------------------------------------------------- audio
// Real samples (Kenney, CC0) and two CC0 music tracks. Music speeds up a little per level
// and switches to the faster track during the rainbow frenzy.
const SFX = ["game-start", "coin-1", "coin-2", "coin-3", "coin-4", "coin-5", "bumper-ping", "combo", "mission-complete",
  "extra-ball-lit", "multiball-fx", "jackpot", "vip-lit", "skill-shot", "drops-reset", "launch-zap", "tilt-warning", "drain",
  "game-over", "mission-fail", "vo-combo", "vo-f-level-up", "vo-f-power-up", "vo-f-game-over", "vo-f-new-highscore", "vo-flawless", "vo-f-go"];
const MUSIC = { main: "/music/pinball/play.mp3", frenzy: "/music/pinball/multiball.mp3" };

class SnakeAudio {
  constructor() {
    this.muted = false; this.musicOn = true; this.ctx = null; this.buffers = new Map(); this.track = null; this.rate = 1; this.voiceAt = 0;
  }
  unlock() {
    if (this.muted) return;
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      if (!this.ctx) {
        this.ctx = new Ctx();
        this.out = this.ctx.createGain(); this.out.gain.value = 0.75; this.out.connect(this.ctx.destination);
        for (const name of SFX) this.load(name);
      }
      this.ctx.resume().catch(() => {});
    } catch { /* Audio is optional on browsers that block it. */ }
  }
  load(name) {
    if (!this.buffers.has(name)) {
      this.buffers.set(name, fetch(`/audio/pinball/${name}.ogg`).then((r) => (r.ok ? r.arrayBuffer() : null))
        .then((b) => (b ? this.ctx.decodeAudioData(b) : null)).catch(() => null));
    }
    return this.buffers.get(name);
  }
  async play(name, { gain = 0.6, rate = 1, delay = 0 } = {}) {
    if (this.muted || !this.ctx || this.ctx.state !== "running") return;
    const buffer = await this.load(name);
    if (!buffer) return;
    const src = this.ctx.createBufferSource(), g = this.ctx.createGain();
    src.buffer = buffer; src.playbackRate.value = rate; g.gain.value = gain;
    src.connect(g).connect(this.out);
    src.start(this.ctx.currentTime + delay);
    src.onended = () => { src.disconnect(); g.disconnect(); };
  }
  voice(name, delay = 0) {
    const now = performance.now();
    if (now < this.voiceAt) return;
    this.voiceAt = now + 1600;
    this.play(name, { gain: 0.85, delay });
    this.duck(1.4);
  }
  music(name) {
    if (this.track?.name === name) return;
    const old = this.track;
    if (old) this.fade(old.el, 0, 600, () => old.el.pause());
    if (!name) { this.track = null; return; }
    const el = new Audio(MUSIC[name]);
    el.loop = true; el.volume = 0; el.playbackRate = this.rate;
    this.track = { name, el };
    if (this.musicOn && !this.muted) { el.play().catch(() => {}); this.fade(el, this.level(), 700); }
  }
  level() { return !this.musicOn || this.muted ? 0 : performance.now() < this.duckUntil ? 0.14 : 0.42; }
  duck(seconds) {
    this.duckUntil = performance.now() + seconds * 1000;
    if (this.track) this.fade(this.track.el, this.level(), 120);
    clearTimeout(this.duckTimer);
    this.duckTimer = setTimeout(() => this.track && this.fade(this.track.el, this.level(), 700), seconds * 1000);
  }
  fade(el, to, ms, done) {
    const from = el.volume, start = performance.now();
    clearInterval(el.__fade);
    el.__fade = setInterval(() => {
      const t = Math.min(1, (performance.now() - start) / ms);
      el.volume = Math.max(0, Math.min(1, from + (to - from) * t));
      if (t >= 1) { clearInterval(el.__fade); done?.(); }
    }, 30);
  }
  setRate(rate) { this.rate = rate; if (this.track) this.track.el.playbackRate = rate; }
  setMuted(value) {
    this.muted = value;
    if (this.track) { if (value) this.fade(this.track.el, 0, 200, () => this.track?.el.pause()); else if (this.musicOn) { this.track.el.play().catch(() => {}); this.fade(this.track.el, this.level(), 400); } }
  }
  setMusic(on) {
    this.musicOn = on;
    if (!this.track) return;
    if (on && !this.muted) { this.track.el.play().catch(() => {}); this.fade(this.track.el, this.level(), 400); }
    else this.fade(this.track.el, 0, 250, () => this.track?.el.pause());
  }
  pause(paused) { if (this.track) { if (paused) this.track.el.pause(); else if (this.musicOn && !this.muted) this.track.el.play().catch(() => {}); } }
  destroy() { this.music(null); this.ctx?.close().catch(() => {}); }
}

export async function mountSnakeGame(canvas, onChange, onFeedback) {
  const [garden, sprites] = await Promise.all([
    loadImage("/assets/snake/night-garden.png"), loadImage("/assets/snake/jade-sprites.png"),
  ]);
  return new SnakeScene(canvas, garden, sprites, onChange, onFeedback);
}

// --------------------------------------------------------------------------------- scene
class SnakeScene {
  constructor(canvas, garden, sprites, onChange, onFeedback) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    if (!this.ctx) throw new Error("Dein Browser unterstützt dieses Spielfeld leider nicht.");
    this.sprites = sprites;
    this.audio = new SnakeAudio();
    this.effects = [];
    this.banners = [];
    this.bulges = [];
    this.thornBorn = new Map();
    this.shake = 0;
    this.flash = 0;
    this.flashColor = "129,244,211";
    this.foodBorn = 0;
    this.foodKey = "";
    this.comboPop = 0;
    this.headAngle = 0;
    this.destroyed = false;
    this.onFeedback = onFeedback;
    this.motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    this.reducedMotion = this.motionQuery.matches;
    this.onMotion = (event) => { this.reducedMotion = event.matches; };
    this.motionQuery.addEventListener("change", this.onMotion);
    this.engine = new SnakeEngine({ onChange: (snap) => { this.syncStatus(snap); onChange(snap); }, onEvent: (event) => this.event(event) });
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = WIDTH * this.dpr; canvas.height = HEIGHT * this.dpr;
    this.backdrop = this.paintBackdrop(garden);
    this.fireflies = Array.from({ length: 46 }, (_, index) => ({
      x: 40 + ((index * 197) % 1040), y: 30 + ((index * 113) % 580), phase: index * 2.4, size: 1.2 + (index % 3) * 0.7,
    }));
    // Inspection entry point, consistent with the other arcade games.
    canvas.__snakeGame = this;
    this.lastTime = performance.now();
    this.frame = requestAnimationFrame((time) => this.loop(time));
  }

  paintBackdrop(garden) {
    const canvas = document.createElement("canvas");
    canvas.width = this.canvas.width; canvas.height = this.canvas.height;
    const bg = canvas.getContext("2d");
    bg.scale(this.dpr, this.dpr);
    bg.drawImage(garden, 0, 0, WIDTH, HEIGHT);
    for (let y = 0; y < this.engine.rows; y++) {
      for (let x = 0; x < this.engine.cols; x++) {
        bg.fillStyle = (x + y) % 2 ? "rgba(78, 184, 170, 0.05)" : "rgba(0, 9, 14, 0.08)";
        bg.fillRect(FIELD.x + x * TILE, FIELD.y + y * TILE, TILE, TILE);
      }
    }
    // Soft inner frame and vignette.
    const v = bg.createRadialGradient(WIDTH / 2, HEIGHT / 2, HEIGHT * 0.35, WIDTH / 2, HEIGHT / 2, WIDTH * 0.62);
    v.addColorStop(0, "rgba(0,0,0,0)"); v.addColorStop(1, "rgba(0,4,10,0.55)");
    bg.fillStyle = v; bg.fillRect(0, 0, WIDTH, HEIGHT);
    bg.strokeStyle = "rgba(133, 249, 228, 0.18)"; bg.lineWidth = 2;
    bg.strokeRect(FIELD.x - 1, FIELD.y - 1, FIELD.width + 2, FIELD.height + 2);
    return canvas;
  }

  syncStatus(snap) {
    if (snap.status === "paused") this.audio.pause(true);
    else if (snap.status === "playing") this.audio.pause(false);
  }

  start() {
    this.audio.unlock();
    this.audio.play("game-start", { gain: 0.6 });
    this.audio.voice("vo-f-go", 0.35);
    this.audio.setRate(1);
    this.audio.music("main");
    this.effects = []; this.banners = []; this.bulges = []; this.thornBorn.clear();
    this.shake = 0; this.flash = 0; this.comboPop = 0;
    this.lastTime = performance.now(); this.engine.start();
    this.banner("LOS!", "Sammle goldene Eier", "#8dffcf", 1.1);
  }
  togglePause() {
    if (this.engine.status === "paused") { this.lastTime = performance.now(); this.audio.unlock(); this.engine.resume(); }
    else this.engine.pause();
  }
  turn(direction) { return this.engine.turn(direction); }
  setMuted(value) { this.audio.setMuted(value); if (!value) this.audio.unlock(); }
  setMusic(value) { this.audio.setMusic(value); }

  banner(text, sub, color, life = 1.4, big = 1) { this.banners.push({ text, sub, color, life, age: 0, big }); }
  burst(point, count, colors, speed = 1, kind = "spark") {
    if (this.reducedMotion) count = Math.min(count, 4);
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * TAU, v = (40 + Math.random() * 150) * speed;
      this.effects.push({ type: kind, x: point.x, y: point.y, vx: Math.cos(angle) * v, vy: Math.sin(angle) * v - (kind === "leaf" ? 30 : 0),
        age: 0, life: 0.5 + Math.random() * 0.6, color: colors[i % colors.length], spin: (Math.random() - 0.5) * 8, size: 2 + Math.random() * 3 });
    }
  }
  ring(point, color, size = 60, life = 0.55) { this.effects.push({ type: "ring", x: point.x, y: point.y, vx: 0, vy: 0, age: 0, life, color, size }); }
  text(point, text, color, size = 24, life = 1) { this.effects.push({ type: "text", x: point.x, y: point.y - 18, vx: 0, vy: -36, age: 0, life, color, text, size }); }

  event(event) {
    const e = this.engine;
    switch (event.type) {
      case "eat": {
        const point = cellPoint(event.cell), color = event.frenzy ? "#ff7ad9" : COMBO_COLORS[event.combo];
        this.audio.play(`coin-${Math.min(5, event.combo)}`, { gain: 0.55, rate: 1 + (event.combo - 1) * 0.07 });
        this.audio.play("bumper-ping", { gain: 0.25, rate: 1 + event.combo * 0.1 });
        if (event.combo >= 3) this.audio.play("combo", { gain: 0.45, rate: 0.9 + event.combo * 0.1 });
        if (event.combo === 5) this.audio.voice("vo-combo");
        this.burst(point, 22, ["#ffe2a0", "#fff6c4", color], 1.1);
        this.burst(point, 6, ["#7fe7b8", "#c6ffda"], 0.7, "leaf");
        this.ring(point, color, 46 + event.combo * 8);
        this.text(point, `+${event.points}`, color, 22 + event.combo * 3);
        this.bulges.push({ born: e.elapsed });
        this.comboPop = 1;
        if (!this.reducedMotion) this.shake = Math.max(this.shake, 0.04 + event.combo * 0.012);
        if (event.combo >= 2) this.banner(`×${event.combo}`, event.combo === 5 ? "MAXI-COMBO!" : "COMBO", color, 0.8, 0.75 + event.combo * 0.08);
        break;
      }
      case "level": {
        this.audio.play("mission-complete", { gain: 0.7 });
        this.audio.voice("vo-f-level-up", 0.25);
        this.audio.setRate(Math.min(1.14, 1 + (event.level - 1) * 0.02));
        this.flash = 0.8; this.flashColor = "129,244,211";
        this.banner(`LEVEL ${event.level}`, event.level >= 3 ? "Vorsicht: Dornen wachsen!" : "Das Tempo steigt!", "#8dffcf", 1.8, 1.3);
        break;
      }
      case "thorns":
        this.audio.play("tilt-warning", { gain: 0.35, rate: 0.8 });
        for (const cell of event.cells) { this.thornBorn.set(`${cell.x},${cell.y}`, performance.now()); this.burst(cellPoint(cell), 8, ["#b14cff", "#4a1a6a"], 0.6, "leaf"); }
        break;
      case "bonusSpawn": {
        const style = BONUS_STYLE[event.kind];
        this.audio.play("extra-ball-lit", { gain: 0.5 });
        this.ring(cellPoint(event.cell), style.color, 80, 0.8);
        break;
      }
      case "bonus": {
        const point = cellPoint(event.cell), style = BONUS_STYLE[event.kind];
        this.burst(point, 40, [style.color, "#ffffff", "#ffe2a0"], 1.6);
        this.ring(point, style.color, 120, 0.8); this.ring(point, "#ffffff", 70, 0.5);
        this.text(point, `+${event.points}`, style.color, 30, 1.2);
        this.flash = 0.7; this.flashColor = event.kind === "rainbow" ? "255,122,217" : event.kind === "crystal" ? "122,216,255" : "255,224,102";
        if (event.kind === "rainbow") {
          this.audio.play("multiball-fx", { gain: 0.6 }); this.audio.play("jackpot", { gain: 0.6 }); this.audio.voice("vo-f-power-up", 0.2);
          this.audio.music("frenzy");
          this.banner("FIEBER!", "8 Sekunden doppelte Punkte", "#ff7ad9", 1.8, 1.4);
        } else if (event.kind === "crystal") {
          this.audio.play("vip-lit", { gain: 0.7 }); this.audio.setRate(0.85);
          this.banner("ZEITLUPE", "Alles wird langsamer …", "#7ad8ff", 1.6, 1.2);
        } else {
          this.audio.play("skill-shot", { gain: 0.6 });
          this.banner("HÄUTUNG!", "Dein Schwanz wird kürzer", "#ffe066", 1.6, 1.2);
        }
        if (!this.reducedMotion) this.shake = 0.12;
        break;
      }
      case "bonusExpire":
        this.burst(cellPoint(event.cell), 10, ["#ffffff88"], 0.5);
        break;
      case "frenzyEnd":
        this.audio.play("drops-reset", { gain: 0.4 }); this.audio.music("main");
        break;
      case "slowEnd":
        this.audio.setRate(Math.min(1.14, 1 + (e.level - 1) * 0.02));
        break;
      case "portal": {
        this.audio.play("launch-zap", { gain: 0.18, rate: 1.3 });
        this.ring(cellPoint(event.cell), "#85f9e4", 40, 0.4);
        if (event.from) this.ring(cellPoint(event.from), "#85f9e4", 40, 0.4);
        this.flash = Math.max(this.flash, 0.25); this.flashColor = "133,249,228";
        break;
      }
      case "collision": {
        this.audio.play("drain", { gain: 0.8 }); this.audio.play("game-over", { gain: 0.55, delay: 0.25 });
        this.audio.voice("vo-f-game-over", 0.7);
        this.audio.music(null);
        this.shake = this.reducedMotion ? 0 : 0.5;
        this.flash = 1; this.flashColor = "255,70,90";
        // The whole snake bursts into scales.
        e.snake.forEach((cell, i) => { if (i % 2 === 0) this.burst(cellPoint(cell), 4, ["#48d28a", "#c6ffda", "#ffd36b"], 0.9, "leaf"); });
        this.banner(event.cause === "thorn" ? "AUTSCH!" : "VERKNOTET!", event.cause === "thorn" ? "Die Dornen haben dich erwischt" : "Deine Spur war schneller", "#ff5a7a", 1.8, 1.3);
        break;
      }
      case "finish":
        this.audio.play("mission-fail", { gain: 0.4 }); this.audio.music(null);
        break;
      default: break;
    }
    this.onFeedback(event);
  }

  // ------------------------------------------------------------------ drawing helpers
  sprite(kind, x, y, size, angle = 0, alpha = 1) {
    const col = kind === "body" || kind === "tail" ? 1 : 0;
    const row = kind === "egg" || kind === "tail" ? 1 : 0;
    const sw = this.sprites.width / 2, sh = this.sprites.height / 2;
    const ctx = this.ctx;
    ctx.save(); ctx.translate(x, y); ctx.rotate(angle); ctx.globalAlpha = alpha;
    ctx.drawImage(this.sprites, col * sw, row * sh, sw, sh, -size / 2, -size / 2, size, size);
    ctx.restore();
  }

  egg(point, time, size = TILE * 1.5, born = 0) {
    const ctx = this.ctx;
    const pop = born ? Math.min(1, (performance.now() - born) / 420) : 1;
    const scale = this.reducedMotion ? 1 : easeOutBack(pop);
    const bob = this.reducedMotion ? 0 : Math.sin(time * 3.2) * 2;
    const radius = size * (0.95 + Math.sin(time * 2) * 0.08);
    const glow = ctx.createRadialGradient(point.x, point.y, 2, point.x, point.y, radius);
    glow.addColorStop(0, "rgba(255, 204, 89, 0.35)"); glow.addColorStop(1, "rgba(255, 204, 89, 0)");
    ctx.fillStyle = glow; ctx.fillRect(point.x - radius, point.y - radius, radius * 2, radius * 2);
    if (!this.reducedMotion) {
      for (let i = 0; i < 3; i++) {
        const a = time * 2.2 + (i * TAU) / 3, r = size * 0.55;
        ctx.fillStyle = `rgba(255,240,190,${0.5 + Math.sin(time * 5 + i) * 0.3})`;
        ctx.beginPath(); ctx.arc(point.x + Math.cos(a) * r, point.y + Math.sin(a) * r * 0.6 + bob, 1.8, 0, TAU); ctx.fill();
      }
    }
    this.sprite("egg", point.x, point.y + bob, size * scale);
  }

  bonusItem(bonus, time) {
    const ctx = this.ctx, p = cellPoint(bonus), e = this.engine;
    const left = Math.max(0, (bonus.until - e.elapsed) / 7000);
    if (left < 0.28 && Math.floor(time * 8) % 2 === 0) return; // blink before it vanishes
    const bob = this.reducedMotion ? 0 : Math.sin(time * 4) * 2.5;
    const style = BONUS_STYLE[bonus.kind];
    ctx.save();
    const g = ctx.createRadialGradient(p.x, p.y, 2, p.x, p.y, TILE * 1.6);
    g.addColorStop(0, `${style.color}66`); g.addColorStop(1, `${style.color}00`);
    ctx.fillStyle = g; ctx.fillRect(p.x - TILE * 1.6, p.y - TILE * 1.6, TILE * 3.2, TILE * 3.2);
    // timer ring
    ctx.strokeStyle = style.color; ctx.lineWidth = 2.5; ctx.globalAlpha = 0.85;
    ctx.beginPath(); ctx.arc(p.x, p.y, TILE * 0.95, -Math.PI / 2, -Math.PI / 2 + TAU * left); ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.translate(p.x, p.y + bob);
    if (bonus.kind === "rainbow") {
      ctx.filter = `hue-rotate(${(time * 240) % 360}deg) saturate(1.8)`;
      ctx.drawImage(this.sprites, 0, this.sprites.height / 2, this.sprites.width / 2, this.sprites.height / 2, -TILE * 0.85, -TILE * 0.85, TILE * 1.7, TILE * 1.7);
      ctx.filter = "none";
    } else if (bonus.kind === "crystal") {
      ctx.rotate(Math.sin(time * 2) * 0.15);
      const s = TILE * 0.62;
      const cg = ctx.createLinearGradient(0, -s, 0, s);
      cg.addColorStop(0, "#e8fbff"); cg.addColorStop(0.5, "#7ad8ff"); cg.addColorStop(1, "#2a6aff");
      ctx.fillStyle = cg; ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(0, -s); ctx.lineTo(s * 0.62, -s * 0.2); ctx.lineTo(0, s); ctx.lineTo(-s * 0.62, -s * 0.2); ctx.closePath(); ctx.fill(); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(-s * 0.62, -s * 0.2); ctx.lineTo(s * 0.62, -s * 0.2); ctx.moveTo(0, -s); ctx.lineTo(0, s); ctx.globalAlpha = 0.5; ctx.stroke();
    } else {
      ctx.rotate(time * 1.5);
      const s = TILE * 0.66;
      ctx.fillStyle = "#ffe066"; ctx.strokeStyle = "#a86a00"; ctx.lineWidth = 2;
      ctx.beginPath();
      for (let i = 0; i < 10; i++) { const r = i % 2 ? s * 0.45 : s; ctx.lineTo(Math.cos((i / 10) * TAU - Math.PI / 2) * r, Math.sin((i / 10) * TAU - Math.PI / 2) * r); }
      ctx.closePath(); ctx.fill(); ctx.stroke();
    }
    ctx.restore();
  }

  thorn(cell, time) {
    const ctx = this.ctx, p = cellPoint(cell);
    const born = this.thornBorn.get(`${cell.x},${cell.y}`) || 0;
    const grow = born ? Math.min(1, (performance.now() - born) / 700) : 1;
    const s = TILE * 0.62 * (this.reducedMotion ? 1 : easeOutBack(grow));
    ctx.save(); ctx.translate(p.x, p.y);
    const glow = ctx.createRadialGradient(0, 0, 1, 0, 0, TILE);
    glow.addColorStop(0, `rgba(177,76,255,${0.25 + Math.sin(time * 3 + cell.x) * 0.1})`); glow.addColorStop(1, "rgba(177,76,255,0)");
    ctx.fillStyle = glow; ctx.fillRect(-TILE, -TILE, TILE * 2, TILE * 2);
    ctx.fillStyle = "#2a0f3a"; ctx.strokeStyle = "#b14cff"; ctx.lineWidth = 1.2;
    ctx.beginPath();
    for (let i = 0; i < 14; i++) { const a = (i / 14) * TAU + cell.x, r = i % 2 ? s * 0.45 : s * (0.9 + ((i * 7 + cell.y) % 3) * 0.08); ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r); }
    ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#ff3b6b";
    for (let i = 0; i < 3; i++) { const a = i * 2.1 + cell.y; ctx.beginPath(); ctx.arc(Math.cos(a) * s * 0.25, Math.sin(a) * s * 0.25, 2.2, 0, TAU); ctx.fill(); }
    ctx.restore();
  }

  bulgeScale(position) {
    if (this.reducedMotion) return 1;
    const e = this.engine;
    let scale = 1;
    for (const b of this.bulges) {
      const at = (e.elapsed - b.born) / e.interval;
      const d = position - at;
      scale += 0.38 * Math.exp(-(d * d) / 0.9);
    }
    return scale;
  }

  serpent(points, scale = 1, headAngle = 0, alpha = 1, time = 0) {
    const ctx = this.ctx, e = this.engine;
    const frenzy = e.status !== "ready" && e.frenzy;
    // Glow pass under the body.
    if (!this.reducedMotion && points.length > 1) {
      ctx.save();
      ctx.lineCap = "round"; ctx.lineJoin = "round";
      ctx.strokeStyle = frenzy ? `hsla(${(time * 300) % 360},100%,65%,0.35)` : e.slow ? "rgba(122,216,255,0.28)" : "rgba(72,210,138,0.22)";
      ctx.lineWidth = TILE * 1.25 * scale; ctx.shadowColor = ctx.strokeStyle; ctx.shadowBlur = 18;
      ctx.beginPath();
      points.forEach((p, i) => {
        const prev = points[i - 1];
        if (!prev || Math.abs(prev.x - p.x) > TILE * 2 || Math.abs(prev.y - p.y) > TILE * 2) ctx.moveTo(p.x, p.y); else ctx.lineTo(p.x, p.y);
      });
      ctx.stroke(); ctx.restore();
    }
    if (frenzy) ctx.filter = `hue-rotate(${(time * 300) % 360}deg) saturate(1.6) brightness(1.1)`;
    const tail = points.at(-1), beforeTail = points.at(-2) || tail;
    this.sprite("tail", tail.x, tail.y, TILE * 1.65 * scale * this.bulgeScale(points.length - 1),
      Math.atan2(beforeTail.y - tail.y, beforeTail.x - tail.x), alpha);
    for (let i = points.length - 2; i >= 0; i--) {
      const a = points[i + 1], b = points[i];
      // Disconnected points occur at portals; never draw a line across the board.
      if (Math.abs(a.x - b.x) > TILE * 2 || Math.abs(a.y - b.y) > TILE * 2) continue;
      const steps = Math.max(1, Math.ceil(Math.hypot(b.x - a.x, b.y - a.y) / (TILE * 0.42)));
      const angle = Math.atan2(b.y - a.y, b.x - a.x);
      for (let j = 0; j < steps; j++) {
        const amount = j / steps;
        const wave = this.reducedMotion || e.status === "ready" ? 1 : 1 + Math.sin(time * 6 - (i + 1 - amount) * 0.7) * 0.035;
        this.sprite("body", a.x + (b.x - a.x) * amount, a.y + (b.y - a.y) * amount,
          TILE * 1.62 * scale * wave * this.bulgeScale(i + 1 - amount), angle, alpha);
      }
    }
    const head = points[0];
    // Tongue flick.
    if (!this.reducedMotion && (time % 2.6) < 0.28 && alpha === 1) {
      const t = (time % 2.6) / 0.28, len = TILE * (0.6 + Math.sin(t * Math.PI) * 0.45) * scale;
      ctx.save(); ctx.translate(head.x, head.y); ctx.rotate(headAngle);
      ctx.strokeStyle = "#ff3b6b"; ctx.lineWidth = 2.2 * scale; ctx.lineCap = "round";
      ctx.beginPath(); ctx.moveTo(TILE * 0.8 * scale, 0); ctx.lineTo(TILE * 0.8 * scale + len, 0);
      ctx.lineTo(TILE * 0.8 * scale + len + 5 * scale, -4 * scale); ctx.moveTo(TILE * 0.8 * scale + len, 0); ctx.lineTo(TILE * 0.8 * scale + len + 5 * scale, 4 * scale);
      ctx.stroke(); ctx.restore();
    }
    this.sprite("head", head.x, head.y, TILE * 2.1 * scale * this.bulgeScale(0), headAngle, alpha);
    ctx.filter = "none";
  }

  drawReady(time) {
    const points = [];
    for (let i = 0; i < 34; i++) {
      const progress = i / 33;
      points.push({ x: 247 + Math.sin(progress * Math.PI * 2.1 + 0.2 + (this.reducedMotion ? 0 : time * 0.8)) * 53,
        y: 435 - progress * 265 });
    }
    const breath = this.reducedMotion ? 1 : 1 + Math.sin(time * 1.9) * 0.018;
    this.serpent(points, (52.8 / TILE) * breath, 0.22, 1, time);
    this.egg({ x: 865, y: 320 }, time, 75);
  }

  drawPlaying(time) {
    const engine = this.engine;
    for (const cell of engine.thorns) this.thorn(cell, time);
    if (engine.food) {
      const key = `${engine.food.x},${engine.food.y}`;
      if (key !== this.foodKey) { this.foodKey = key; this.foodBorn = performance.now(); }
      this.egg(cellPoint(engine.food), time, TILE * 1.5, this.foodBorn);
    }
    if (engine.bonus) this.bonusItem(engine.bonus, time);
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
    // Smoothly turn the head instead of snapping 90 degrees.
    const target = Math.atan2(engine.direction.y, engine.direction.x);
    let diff = target - this.headAngle;
    while (diff > Math.PI) diff -= TAU;
    while (diff < -Math.PI) diff += TAU;
    this.headAngle += this.reducedMotion ? diff : diff * 0.35;
    const ctx = this.ctx;
    ctx.save(); ctx.beginPath(); ctx.rect(FIELD.x - 10, FIELD.y - 10, FIELD.width + 20, FIELD.height + 20); ctx.clip();
    this.serpent(points, 1, this.headAngle, engine.reason === "collision" ? 0.35 : 1, time);
    ctx.restore();
    // Frenzy sparkles trail from the tail.
    if (engine.frenzy && engine.status === "playing" && !this.reducedMotion && Math.random() < 0.6) {
      const tail = points.at(-1);
      this.effects.push({ type: "spark", x: tail.x, y: tail.y, vx: (Math.random() - 0.5) * 40, vy: (Math.random() - 0.5) * 40, age: 0, life: 0.6, color: `hsl(${(time * 300) % 360},100%,70%)`, spin: 3, size: 3 });
    }
    this.bulges = this.bulges.filter((b) => (engine.elapsed - b.born) / engine.interval < engine.snake.length + 2);
  }

  drawCombo(time, dt) {
    const e = this.engine;
    if (e.status !== "playing" && e.status !== "paused") return;
    const ctx = this.ctx;
    this.comboPop = Math.max(0, this.comboPop - dt * 3);
    const chips = [];
    if (e.combo >= 2 && e.comboLeft > 0) chips.push({ text: `×${e.combo}`, color: COMBO_COLORS[e.combo], left: e.comboLeft, big: true });
    if (e.frenzy) chips.push({ text: "FIEBER ×2", color: "#ff7ad9", left: (e.frenzyUntil - e.elapsed) / 8000 });
    if (e.slow) chips.push({ text: "ZEITLUPE", color: "#7ad8ff", left: (e.slowUntil - e.elapsed) / 6000 });
    let x = FIELD.x + FIELD.width / 2 - (chips.length - 1) * 75;
    for (const chip of chips) {
      ctx.save();
      ctx.translate(x, FIELD.y + 28);
      const s = chip.big ? 1 + this.comboPop * 0.5 : 1;
      ctx.scale(s, s);
      ctx.fillStyle = "rgba(4,18,22,0.72)"; ctx.strokeStyle = chip.color; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.roundRect(-62, -18, 124, 36, 18); ctx.fill(); ctx.stroke();
      ctx.fillStyle = chip.color; ctx.font = `900 ${chip.big ? 22 : 15}px Inter, Segoe UI, sans-serif`; ctx.textAlign = "center"; ctx.textBaseline = "middle";
      ctx.shadowColor = chip.color; ctx.shadowBlur = 10;
      ctx.fillText(chip.text, 0, -1);
      ctx.shadowBlur = 0;
      ctx.fillStyle = chip.color; ctx.globalAlpha = 0.8;
      ctx.fillRect(-48, 11, 96 * Math.max(0, Math.min(1, chip.left)), 3);
      ctx.restore();
      x += 150;
    }
  }

  drawBanners(dt) {
    const ctx = this.ctx;
    this.banners = this.banners.filter((b) => b.age < b.life);
    // Only the newest banner is drawn so they never pile up.
    const b = this.banners.at(-1);
    for (const other of this.banners) other.age += dt;
    if (!b) return;
    const t = b.age / b.life;
    const appear = Math.min(1, b.age / 0.28);
    const scale = (this.reducedMotion ? 1 : 2.4 - 1.4 * easeOutBack(appear)) * b.big;
    ctx.save();
    ctx.globalAlpha = t > 0.75 ? Math.max(0, 1 - (t - 0.75) / 0.25) : 1;
    ctx.translate(WIDTH / 2, HEIGHT / 2 - 30);
    ctx.scale(scale, scale);
    ctx.rotate(-0.05);
    ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.font = "italic 900 64px Inter, Segoe UI, sans-serif";
    ctx.lineWidth = 10; ctx.strokeStyle = "rgba(3,16,20,0.9)"; ctx.strokeText(b.text, 0, 0);
    ctx.shadowColor = b.color; ctx.shadowBlur = 26;
    ctx.fillStyle = b.color; ctx.fillText(b.text, 0, 0);
    ctx.shadowBlur = 0;
    ctx.fillStyle = "#ffffff"; ctx.globalAlpha *= 0.35; ctx.fillText(b.text, 0, -3);
    if (b.sub) {
      ctx.globalAlpha = t > 0.75 ? Math.max(0, 1 - (t - 0.75) / 0.25) : Math.min(1, b.age / 0.4);
      ctx.font = "800 17px Inter, Segoe UI, sans-serif"; ctx.lineWidth = 5; ctx.strokeText(b.sub, 0, 46);
      ctx.fillStyle = "#f2fff9"; ctx.fillText(b.sub, 0, 46);
    }
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
    const ctx = this.ctx, e = this.engine;
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.clearRect(0, 0, WIDTH, HEIGHT);
    ctx.save();
    if (this.shake > 0) {
      ctx.translate(Math.sin(time * 112) * this.shake * 26, Math.cos(time * 91) * this.shake * 18);
      this.shake = Math.max(0, this.shake - dt * 1.4);
    }
    ctx.drawImage(this.backdrop, 0, 0, WIDTH, HEIGHT);
    // Each level tints the garden differently; frenzy and slow-motion paint their own mood.
    if (e.status === "playing" || e.status === "paused") {
      const hue = e.frenzy ? (time * 120) % 360 : e.slow ? 200 : LEVEL_HUES[(e.level - 1) % LEVEL_HUES.length];
      const strength = e.frenzy ? 0.16 : e.slow ? 0.14 : Math.min(0.12, 0.03 + e.level * 0.015);
      const g = ctx.createRadialGradient(WIDTH / 2, HEIGHT / 2, 60, WIDTH / 2, HEIGHT / 2, WIDTH * 0.6);
      g.addColorStop(0, `hsla(${hue},90%,60%,${strength * 0.4})`); g.addColorStop(1, `hsla(${hue},90%,50%,${strength})`);
      ctx.save(); ctx.globalCompositeOperation = "screen"; ctx.fillStyle = g; ctx.fillRect(0, 0, WIDTH, HEIGHT); ctx.restore();
    }
    if (this.flash > 0) {
      ctx.strokeStyle = `rgba(${this.flashColor},${this.flash * 0.8})`; ctx.lineWidth = 5;
      ctx.shadowColor = `rgba(${this.flashColor},1)`; ctx.shadowBlur = 24;
      ctx.strokeRect(FIELD.x, FIELD.y, FIELD.width, FIELD.height);
      ctx.shadowBlur = 0;
      ctx.fillStyle = `rgba(${this.flashColor},${this.flash * 0.08})`; ctx.fillRect(0, 0, WIDTH, HEIGHT);
      this.flash = Math.max(0, this.flash - dt * 1.6);
    }
    if (e.status === "ready") this.drawReady(time);
    else this.drawPlaying(time);
    if (!this.reducedMotion) this.fireflies.forEach((fly) => {
      const speed = e.frenzy ? 3 : 1;
      const x = fly.x + Math.sin(time * 0.3 * speed + fly.phase) * 9, y = fly.y + Math.cos(time * 0.4 * speed + fly.phase) * 11;
      const alpha = 0.15 + ((Math.sin(time * 1.3 + fly.phase) + 1) / 2) * 0.6;
      ctx.fillStyle = e.frenzy ? `hsla(${(fly.phase * 40 + time * 200) % 360},100%,75%,${alpha})` : `rgba(255,224,148,${alpha})`;
      ctx.beginPath(); ctx.arc(x, y, fly.size, 0, TAU); ctx.fill();
    });
    this.effects = this.effects.filter((effect) => effect.age < effect.life);
    this.effects.forEach((effect) => {
      effect.age += dt; effect.x += effect.vx * dt; effect.y += effect.vy * dt;
      if (effect.type === "spark" || effect.type === "leaf") { effect.vx *= 0.96; effect.vy = effect.vy * 0.96 + (effect.type === "leaf" ? 60 : 20) * dt; }
      const k = effect.age / effect.life;
      ctx.save(); ctx.globalAlpha = Math.max(0, 1 - k);
      if (effect.type === "text") {
        const pop = Math.min(1, effect.age / 0.18);
        ctx.translate(effect.x, effect.y); ctx.scale(0.6 + 0.5 * easeOutBack(pop), 0.6 + 0.5 * easeOutBack(pop));
        ctx.font = `italic 900 ${effect.size}px Inter, Segoe UI, sans-serif`; ctx.textAlign = "center";
        ctx.lineWidth = 5; ctx.strokeStyle = "#061c21"; ctx.strokeText(effect.text, 0, 0);
        ctx.fillStyle = effect.color; ctx.shadowColor = effect.color; ctx.shadowBlur = 12;
        ctx.fillText(effect.text, 0, 0);
      } else if (effect.type === "ring") {
        ctx.strokeStyle = effect.color; ctx.lineWidth = 4 * (1 - k) + 1;
        ctx.beginPath(); ctx.arc(effect.x, effect.y, 6 + effect.size * k, 0, TAU); ctx.stroke();
      } else if (effect.type === "leaf") {
        ctx.translate(effect.x, effect.y); ctx.rotate(effect.age * effect.spin);
        ctx.fillStyle = effect.color;
        ctx.beginPath(); ctx.ellipse(0, 0, effect.size * 1.4, effect.size * 0.7, 0, 0, TAU); ctx.fill();
      } else {
        ctx.translate(effect.x, effect.y); ctx.rotate(effect.age * (effect.spin || 2));
        ctx.fillStyle = effect.color; ctx.globalCompositeOperation = "lighter";
        const s = effect.size || 3;
        ctx.beginPath(); ctx.moveTo(0, -s); ctx.lineTo(s * 0.66, 0); ctx.lineTo(0, s); ctx.lineTo(-s * 0.66, 0); ctx.fill();
      }
      ctx.restore();
    });
    ctx.restore();
    this.drawCombo(time, dt);
    this.drawBanners(dt);
  }

  destroy() {
    this.destroyed = true;
    cancelAnimationFrame(this.frame);
    this.motionQuery.removeEventListener("change", this.onMotion);
    this.audio.destroy();
    delete this.canvas.__snakeGame;
  }
}

