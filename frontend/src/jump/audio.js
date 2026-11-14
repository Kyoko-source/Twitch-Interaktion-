// Chicken Jump sound: Kenney CC0 samples and the site's CC0 music tracks.
// [file, base gain, minimum gap in seconds]
const SAMPLES = {
  start: ["/audio/pinball/game-start.ogg", 0.55, 1],
  jump: ["/audio/pinball/flipper-up.ogg", 0.32, 0.06],
  double: ["/audio/pinball/sling.ogg", 0.45, 0.08],
  land: ["/audio/pinball/ball-click.ogg", 0.22, 0.08],
  "coin-1": ["/audio/pinball/coin-1.ogg", 0.4, 0.03],
  "coin-2": ["/audio/pinball/coin-2.ogg", 0.4, 0.03],
  "coin-3": ["/audio/pinball/coin-3.ogg", 0.4, 0.03],
  "coin-4": ["/audio/pinball/coin-4.ogg", 0.42, 0.03],
  "coin-5": ["/audio/pinball/coin-5.ogg", 0.45, 0.03],
  combo: ["/audio/pinball/combo.ogg", 0.45, 0.2],
  pass: ["/audio/pinball/lane.ogg", 0.18, 0.1],
  near: ["/audio/pinball/orbit.ogg", 0.5, 0.15],
  milestone: ["/audio/pinball/lanes-complete.ogg", 0.55, 0.5],
  powerup: ["/audio/pinball/extra-ball-lit.ogg", 0.6, 0.3],
  frenzy: ["/audio/pinball/multiball-fx.ogg", 0.5, 0.5],
  magnet: ["/audio/forceField_000.ogg", 0.35, 0.3],
  shield: ["/audio/impactBell_heavy_000.ogg", 0.4, 0.3],
  smash: ["/audio/impactWood_medium_000.ogg", 0.7, 0.1],
  save: ["/audio/pinball/ball-save.ogg", 0.6, 0.5],
  expire: ["/audio/pinball/drops-reset.ogg", 0.35, 0.3],
  crash: ["/audio/impactWood_medium_000.ogg", 0.8, 0.2],
  drain: ["/audio/pinball/drain.ogg", 0.6, 0.5],
  over: ["/audio/pinball/game-over.ogg", 0.5, 1],
  whoosh: ["/audio/pinball/launch-zap.ogg", 0.16, 0.4],
  "vo-go": ["/audio/pinball/vo-f-go.ogg", 0.85, 1],
  "vo-power": ["/audio/pinball/vo-f-power-up.ogg", 0.85, 1],
  "vo-level": ["/audio/pinball/vo-f-level-up.ogg", 0.85, 1],
  "vo-over": ["/audio/pinball/vo-f-game-over.ogg", 0.85, 1],
  "vo-record": ["/audio/pinball/vo-f-new-highscore.ogg", 0.9, 1],
  "vo-combo": ["/audio/pinball/vo-combo.ogg", 0.85, 1],
  "vo-flawless": ["/audio/pinball/vo-flawless.ogg", 0.85, 1],
};
const MUSIC = { run: "/music/pinball/play.mp3", frenzy: "/music/pinball/multiball.mp3" };
const STORE = "chicken-jump-audio";

export class JumpAudio {
  constructor() {
    this.ctx = null; this.buffers = new Map(); this.last = new Map(); this.track = null; this.rate = 1; this.voiceAt = 0; this.duckUntil = 0;
    this.muted = false; this.sfxVolume = 0.8; this.musicVolume = 0.6;
    try {
      const saved = JSON.parse(localStorage.getItem(STORE) || "{}");
      if (typeof saved.sfx === "number") this.sfxVolume = saved.sfx;
      if (typeof saved.music === "number") this.musicVolume = saved.music;
    } catch { /* optional */ }
  }
  save() { try { localStorage.setItem(STORE, JSON.stringify({ sfx: this.sfxVolume, music: this.musicVolume })); } catch { /* optional */ } }
  unlock() {
    if (this.muted) return;
    try {
      if (!this.ctx) {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        if (!Ctx) return;
        this.ctx = new Ctx();
        this.out = this.ctx.createGain(); this.out.gain.value = this.sfxVolume;
        const limiter = this.ctx.createDynamicsCompressor(); limiter.threshold.value = -12; limiter.ratio.value = 8;
        this.out.connect(limiter).connect(this.ctx.destination);
        for (const name of Object.keys(SAMPLES)) this.load(name);
      }
      if (this.ctx.state === "suspended") this.ctx.resume().catch(() => {});
    } catch { /* Audio is optional on browsers that block it. */ }
  }
  load(name) {
    if (!this.buffers.has(name)) {
      this.buffers.set(name, fetch(SAMPLES[name][0]).then((r) => (r.ok ? r.arrayBuffer() : null))
        .then((b) => (b ? this.ctx.decodeAudioData(b) : null)).catch(() => null));
    }
    return this.buffers.get(name);
  }
  async play(name, { gain = 1, rate = 1, delay = 0 } = {}) {
    if (this.muted || !this.ctx || this.ctx.state !== "running" || !SAMPLES[name]) return;
    const [, base, gap] = SAMPLES[name];
    const now = this.ctx.currentTime;
    if (now - (this.last.get(name) ?? -Infinity) < gap) return;
    this.last.set(name, now);
    const buffer = await this.load(name);
    if (!buffer || !this.ctx) return;
    const src = this.ctx.createBufferSource(), g = this.ctx.createGain();
    src.buffer = buffer; src.playbackRate.value = rate; g.gain.value = base * gain;
    src.connect(g).connect(this.out);
    src.start(this.ctx.currentTime + delay);
    src.onended = () => { src.disconnect(); g.disconnect(); };
  }
  voice(name, delay = 0) {
    const now = performance.now();
    if (now < this.voiceAt) return;
    this.voiceAt = now + 1800;
    this.play(name, { delay });
    this.duck(1.4);
  }
  musicLevel() { return this.muted ? 0 : (performance.now() < this.duckUntil ? 0.35 : 1) * 0.7 * this.musicVolume; }
  music(name) {
    if (this.track?.name === name) return;
    const old = this.track;
    if (old) this.fade(old.el, 0, 500, () => old.el.pause());
    if (!name) { this.track = null; return; }
    const el = new Audio(MUSIC[name]);
    el.loop = true; el.volume = 0; el.playbackRate = this.rate;
    this.track = { name, el };
    if (!this.muted) { el.play().catch(() => {}); this.fade(el, this.musicLevel(), 700); }
  }
  duck(seconds) {
    this.duckUntil = performance.now() + seconds * 1000;
    if (this.track) this.fade(this.track.el, this.musicLevel(), 120);
    clearTimeout(this.duckTimer);
    this.duckTimer = setTimeout(() => this.track && this.fade(this.track.el, this.musicLevel(), 600), seconds * 1000);
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
  setSfxVolume(v) { this.sfxVolume = Math.max(0, Math.min(1, v)); if (this.out) this.out.gain.value = this.sfxVolume; this.save(); }
  setMusicVolume(v) { this.musicVolume = Math.max(0, Math.min(1, v)); if (this.track) this.fade(this.track.el, this.musicLevel(), 120); this.save(); }
  setMuted(value) {
    this.muted = value;
    if (!this.track) return;
    if (value) this.fade(this.track.el, 0, 200, () => this.track?.el.pause());
    else { this.track.el.play().catch(() => {}); this.fade(this.track.el, this.musicLevel(), 400); }
  }
  pause(paused) {
    if (!this.track) return;
    if (paused) this.track.el.pause();
    else if (!this.muted) this.track.el.play().catch(() => {});
  }
  destroy() {
    clearTimeout(this.duckTimer);
    if (this.track) { clearInterval(this.track.el.__fade); this.track.el.pause(); this.track = null; }
    this.ctx?.close().catch(() => {});
    this.ctx = null;
  }
}
