// Pinball sound: CC0 Kenney samples for every mechanical part, short jingles for big moments,
// and three CC0 music tracks (switchable) that duck under the jingles. No synthesized tones.
const SFX = [
  "flipper-up", "flipper-down", "bumper-thump", "bumper-ping", "sling", "drop", "drops-reset", "lane", "spinner", "ramp",
  "rail-exit", "ramp-fail", "orbit", "scoop-in", "scoop-out", "lock", "multiball-fx", "multiball", "jackpot", "super-jackpot",
  "skill-shot", "mission-start", "mission-complete", "mission-fail", "extra-ball", "extra-ball-lit", "combo", "ball-save",
  "drain", "game-over", "tilt", "tilt-warning", "kickback", "launch", "plunger", "rail-clack", "ball-click", "bonus-step",
  "bonus-total", "vip-lit", "bumper-level", "lanes-complete", "mission-lit", "ball-search", "new-ball", "game-start", "wizard", "launch-zap",
];
const MUSIC = { attract: "/music/pinball/attract.mp3", play: "/music/pinball/play.mp3", multiball: "/music/pinball/multiball.mp3" };
const JINGLES = new Set(["multiball", "jackpot", "super-jackpot", "skill-shot", "mission-start", "mission-complete", "extra-ball", "game-over", "bonus-total", "new-ball", "game-start", "wizard"]);

export class PinballAudio {
  constructor() {
    this.sfxOn = true;
    this.musicOn = true;
    this.buffers = new Map();
    this.last = new Map();
    this.voices = 0;
    this.track = null;
    this.duckUntil = 0;
  }

  ensure() {
    if (this.ctx) { if (this.ctx.state === "suspended") this.ctx.resume().catch(() => {}); return this.ctx; }
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    this.ctx = new Ctx();
    const c = this.ctx;
    this.master = c.createGain(); this.master.gain.value = 0.8;
    const limiter = c.createDynamicsCompressor();
    limiter.threshold.value = -10; limiter.knee.value = 14; limiter.ratio.value = 10; limiter.attack.value = 0.002; limiter.release.value = 0.12;
    this.master.connect(limiter).connect(c.destination);
    this.sfx = c.createGain(); this.sfx.gain.value = this.sfxOn ? 1 : 0; this.sfx.connect(this.master);
    for (const name of SFX) this.load(name);
    return c;
  }

  load(name) {
    if (!this.buffers.has(name)) {
      this.buffers.set(name, fetch(`/audio/pinball/${name}.ogg`).then((r) => (r.ok ? r.arrayBuffer() : null))
        .then((b) => (b ? this.ctx.decodeAudioData(b) : null)).catch(() => null));
    }
    return this.buffers.get(name);
  }

  async play(name, { gain = 1, rate = 1, gap = 0.04, pan = 0, delay = 0 } = {}) {
    if (!this.ctx || !this.sfxOn) return;
    const now = this.ctx.currentTime;
    if (now - (this.last.get(name) ?? -9) < gap) return;
    this.last.set(name, now);
    const buffer = await this.load(name);
    if (!buffer || this.voices > 24 || this.ctx.state !== "running") return;
    const src = this.ctx.createBufferSource(), g = this.ctx.createGain();
    src.buffer = buffer; src.playbackRate.value = rate; g.gain.value = gain;
    let out = g;
    if (pan && this.ctx.createStereoPanner) { const p = this.ctx.createStereoPanner(); p.pan.value = Math.max(-1, Math.min(1, pan)); g.connect(p); out = p; }
    out.connect(this.sfx);
    src.connect(g);
    this.voices++;
    src.onended = () => { this.voices--; src.disconnect(); g.disconnect(); if (out !== g) out.disconnect(); };
    src.start(now + delay);
    if (JINGLES.has(name)) this.duck(buffer.duration);
  }

  // Rolling is deliberately silent (no synthesized loops); rail and ball clacks carry the motion.
  setRolling() {}

  // ------------------------------------------------------------- music
  music(name) {
    if (this.track?.name === name) return;
    const old = this.track;
    if (old) this.fade(old.el, 0, 700, () => old.el.pause());
    if (!name) { this.track = null; return; }
    const el = new Audio(MUSIC[name]);
    el.loop = true; el.volume = 0; el.preload = "auto";
    this.track = { name, el };
    if (this.musicOn) { el.play().catch(() => {}); this.fade(el, this.musicLevel(), 900); }
  }
  musicLevel() { return !this.musicOn ? 0 : performance.now() < this.duckUntil ? 0.12 : 0.42; }
  duck(seconds) {
    this.duckUntil = performance.now() + seconds * 1000;
    if (this.track) this.fade(this.track.el, this.musicLevel(), 120);
    clearTimeout(this.duckTimer);
    this.duckTimer = setTimeout(() => this.track && this.fade(this.track.el, this.musicLevel(), 900), seconds * 1000);
  }
  fade(el, to, ms, done) {
    const from = el.volume, start = performance.now();
    clearInterval(el.__fade);
    el.__fade = setInterval(() => {
      const k = Math.min(1, (performance.now() - start) / ms);
      el.volume = Math.max(0, Math.min(1, from + (to - from) * k));
      if (k >= 1) { clearInterval(el.__fade); done?.(); }
    }, 30);
  }

  setSfx(on) { this.sfxOn = on; if (this.sfx) this.sfx.gain.value = on ? 1 : 0; }
  setMusic(on) {
    this.musicOn = on;
    if (!this.track) return;
    if (on) { this.track.el.play().catch(() => {}); this.fade(this.track.el, this.musicLevel(), 500); }
    else this.fade(this.track.el, 0, 300, () => this.track?.el.pause());
  }
  pauseAll(paused) {
    if (paused) { this.track?.el.pause(); this.ctx?.suspend().catch(() => {}); }
    else { if (this.musicOn) this.track?.el.play().catch(() => {}); this.ctx?.resume().catch(() => {}); }
  }

  // Map engine events to sounds.
  handle(type, d = {}) {
    const panOf = (x) => (x === undefined ? 0 : (x - 4.65) / 6);
    switch (type) {
      case "flipper": this.play(d.up ? "flipper-up" : "flipper-down", { gain: d.up ? 0.7 : 0.35, rate: d.up ? 1.05 : 0.9, pan: d.side === "left" ? -0.3 : 0.3, gap: 0.02 }); break;
      case "bumper": this.play("bumper-thump", { gain: 0.85, rate: 0.95 + d.index * 0.06, pan: panOf(d.x), gap: 0.03 }); this.play("bumper-ping", { gain: 0.25, rate: 1 + d.index * 0.12, gap: 0.03 }); break;
      case "sling": this.play("sling", { gain: 0.75, pan: panOf(d.x) }); break;
      case "drop": this.play("drop", { gain: 0.8, rate: 1 + d.index * 0.08 }); break;
      case "dropsReset": this.play("drops-reset", { gain: 0.5 }); break;
      case "lane": this.play("lane", { gain: 0.4, rate: 1 + d.index * 0.15 }); break;
      case "rollover": this.play("lane", { gain: 0.25, rate: 0.8 }); break;
      case "spinner": for (let i = 0; i < Math.min(d.spins, 14); i++) this.play("spinner", { gain: 0.35, rate: 1.4 - i * 0.03, gap: 0, delay: i * (0.035 + i * 0.006), pan: -0.6 }); break;
      case "ramp": this.play("ramp", { gain: 0.45 }); break;
      case "railExit": this.play("rail-exit", { gain: 0.5 }); break;
      case "rampFail": this.play("ramp-fail", { gain: 0.5 }); break;
      case "major": if (d.shot.startsWith("orbit")) this.play("orbit", { gain: 0.4 }); break;
      case "scoopIn": this.play("scoop-in", { gain: 0.8 }); break;
      case "scoopOut": this.play("scoop-out", { gain: 0.8 }); break;
      case "lock": this.play("lock", { gain: 0.7 }); break;
      case "multiball": this.play("multiball", { gain: 0.9 }); this.play("multiball-fx", { gain: 0.5 }); this.music("multiball"); break;
      case "multiballEnd": this.music("play"); break;
      case "wizard": this.play("wizard", { gain: 0.9 }); this.play("multiball-fx", { gain: 0.6 }); this.music("multiball"); break;
      case "jackpot": this.play(d.wizard ? "super-jackpot" : "jackpot", { gain: 0.9 }); break;
      case "superJackpot": this.play("super-jackpot", { gain: 1 }); break;
      case "superLit": case "vipLit": this.play("vip-lit", { gain: 0.6 }); break;
      case "skillShot": this.play("skill-shot", { gain: 0.9 }); break;
      case "missionStart": this.play("mission-start", { gain: 0.8 }); break;
      case "missionComplete": this.play("mission-complete", { gain: 0.9 }); break;
      case "missionFail": this.play("mission-fail", { gain: 0.6 }); break;
      case "missionLit": this.play("mission-lit", { gain: 0.6 }); break;
      case "extraBall": this.play("extra-ball", { gain: 0.95 }); break;
      case "extraBallLit": this.play("extra-ball-lit", { gain: 0.6 }); break;
      case "combo": this.play("combo", { gain: 0.6, rate: 0.9 + Math.min(d.count, 8) * 0.12 }); break;
      case "ballSave": this.play("ball-save", { gain: 0.7 }); break;
      case "drain": this.play("drain", { gain: 0.6 }); break;
      case "gameOver": this.play("game-over", { gain: 0.8 }); this.music("attract"); break;
      case "tilt": this.play("tilt", { gain: 0.8 }); break;
      case "tiltWarning": this.play("tilt-warning", { gain: 0.7 }); break;
      case "kickback": this.play("kickback", { gain: 0.9 }); break;
      case "launch": this.play("launch", { gain: 0.5 + d.charge * 0.4 }); if (d.charge > 0.7) this.play("launch-zap", { gain: 0.2 }); break;
      case "plunger": this.play("plunger", { gain: 0.4 }); break;
      case "collide": if (d.kind === "ball") this.play("ball-click", { gain: Math.min(0.5, d.speed / 30), gap: 0.05 }); else if (d.kind === "rail" || d.kind === "cabinet" || d.kind === "guide" || d.kind === "rampWall") this.play("rail-clack", { gain: Math.min(0.45, d.speed / 40), rate: 0.9 + Math.random() * 0.3, pan: panOf(d.x), gap: 0.05 }); break;
      case "bonusStep": this.play("bonus-step", { gain: 0.5 }); break;
      case "bonusTotal": this.play("bonus-total", { gain: 0.8 }); break;
      case "bumperLevel": this.play("bumper-level", { gain: 0.5 }); break;
      case "lanesComplete": this.play("lanes-complete", { gain: 0.7 }); break;
      case "ballSearch": this.play("ball-search", { gain: 0.6 }); break;
      case "newBall": case "shootAgain": this.play("new-ball", { gain: 0.7 }); break;
      case "gameStart": this.play("game-start", { gain: 0.8 }); this.music("play"); break;
      default: break;
    }
  }

  dispose() {
    this.track?.el.pause();
    this.track = null;
    clearTimeout(this.duckTimer);
    this.ctx?.close().catch(() => {});
  }
}
