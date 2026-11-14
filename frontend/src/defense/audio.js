// Chicken Defense sound: Kenney CC0 samples and the site's CC0 music tracks.
// Each sample has a minimum gap so 40 towers firing never turn into noise.
const SAMPLES = {
  gatling: ["/audio/pinball/ball-click.ogg", 0.22, 0.05],
  frost: ["/audio/impactGeneric_light_000.ogg", 0.35, 0.1],
  mortar: ["/audio/pinball/launch.ogg", 0.35, 0.12],
  sniper: ["/audio/laserLarge_000.ogg", 0.45, 0.12],
  wizard: ["/audio/forceField_000.ogg", 0.3, 0.12],
  tesla: ["/audio/laserLarge_001.ogg", 0.35, 0.1],
  rocket: ["/audio/thrusterFire_000.ogg", 0.3, 0.12],
  pulse: ["/audio/forceField_003.ogg", 0.35, 0.15],
  beam: ["/audio/laserSmall_002.ogg", 0.16, 0.2],
  freeze: ["/audio/impactBell_heavy_000.ogg", 0.3, 0.15],
  shield: ["/audio/impactMetal_light_000.ogg", 0.6, 0.1],
  revive: ["/audio/pinball/extra-ball.ogg", 0.9, 1],
  crit: ["/audio/impactMetal_heavy_000.ogg", 0.45, 0.1],
  boom: ["/audio/explosionCrunch_000.ogg", 0.45, 0.09],
  zap: ["/audio/laserLarge_001.ogg", 0.35, 0.1],
  laser: ["/audio/laserSmall_002.ogg", 0.18, 0.16],
  kill: ["/audio/pinball/bumper-ping.ogg", 0.25, 0.04],
  coin: ["/audio/pinball/coin-2.ogg", 0.4, 0.05],
  leak: ["/audio/pinball/tilt-warning.ogg", 0.6, 0.3],
  build: ["/audio/pinball/drop.ogg", 0.6, 0.05],
  upgrade: ["/audio/pinball/bumper-level.ogg", 0.6, 0.05],
  sell: ["/audio/pinball/coin-4.ogg", 0.6, 0.05],
  wave: ["/audio/pinball/mission-start.ogg", 0.6, 0.5],
  clear: ["/audio/pinball/mission-complete.ogg", 0.6, 0.5],
  boss: ["/audio/pinball/wizard.ogg", 0.7, 1],
  bossDown: ["/audio/pinball/super-jackpot.ogg", 0.8, 1],
  rumble: ["/audio/lowFrequency_explosion_000.ogg", 0.8, 0.5],
  chaos: ["/audio/pinball/multiball-fx.ogg", 0.6, 0.5],
  over: ["/audio/pinball/game-over.ogg", 0.7, 1],
  start: ["/audio/pinball/game-start.ogg", 0.6, 1],
  "vo-fight": ["/audio/pinball/vo-fight.ogg", 0.9, 1],
  "vo-sudden-death": ["/audio/pinball/vo-sudden-death.ogg", 0.9, 1],
  "vo-hurry": ["/audio/pinball/vo-f-hurry-up.ogg", 0.9, 1],
  "vo-over": ["/audio/pinball/vo-f-game-over.ogg", 0.9, 1],
  "vo-flawless": ["/audio/pinball/vo-flawless.ogg", 0.9, 1],
  "vo-ready": ["/audio/pinball/vo-f-ready.ogg", 0.9, 1],
};
const MUSIC = { calm: "/music/pinball/attract.mp3", battle: "/music/pinball/play.mp3", chaos: "/music/pinball/multiball.mp3" };

export class DefenseAudio {
  constructor() { this.ctx = null; this.buffers = new Map(); this.last = new Map(); this.sfxOn = true; this.musicOn = true; this.track = null; this.voiceAt = 0; }
  unlock() {
    try {
      if (!this.ctx) {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        if (!Ctx) return;
        this.ctx = new Ctx();
        this.out = this.ctx.createGain(); this.out.gain.value = 0.8;
        const limiter = this.ctx.createDynamicsCompressor(); limiter.threshold.value = -12; limiter.ratio.value = 8;
        this.out.connect(limiter).connect(this.ctx.destination);
        for (const name of Object.keys(SAMPLES)) this.load(name);
      }
      if (this.ctx.state === "suspended") this.ctx.resume().catch(() => {});
    } catch { /* optional */ }
  }
  load(name) {
    if (!this.buffers.has(name)) {
      this.buffers.set(name, fetch(SAMPLES[name][0]).then((r) => (r.ok ? r.arrayBuffer() : null)).then((b) => (b ? this.ctx.decodeAudioData(b) : null)).catch(() => null));
    }
    return this.buffers.get(name);
  }
  async play(name, { gain = 1, rate = 1 } = {}) {
    if (!this.sfxOn || !this.ctx || this.ctx.state !== "running" || !SAMPLES[name]) return;
    const [, base, gap] = SAMPLES[name];
    const now = this.ctx.currentTime;
    if (now - (this.last.get(name) ?? -9) < gap) return;
    this.last.set(name, now);
    const buffer = await this.load(name);
    if (!buffer) return;
    const src = this.ctx.createBufferSource(), g = this.ctx.createGain();
    src.buffer = buffer; src.playbackRate.value = rate * (0.94 + Math.random() * 0.12); g.gain.value = base * gain;
    src.connect(g).connect(this.out); src.start();
    src.onended = () => { src.disconnect(); g.disconnect(); };
  }
  voice(name) {
    const now = performance.now();
    if (now < this.voiceAt) return;
    this.voiceAt = now + 1800;
    this.play(name);
  }
  music(name) {
    if (this.track?.name === name) return;
    const old = this.track;
    if (old) this.fade(old.el, 0, 900, () => old.el.pause());
    if (!name) { this.track = null; return; }
    const el = new Audio(MUSIC[name]); el.loop = true; el.volume = 0;
    this.track = { name, el };
    if (this.musicOn) { el.play().catch(() => {}); this.fade(el, 0.38, 1200); }
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
  setSfx(on) { this.sfxOn = on; }
  setMusic(on) {
    this.musicOn = on;
    if (!this.track) return;
    if (on) { this.track.el.play().catch(() => {}); this.fade(this.track.el, 0.38, 400); }
    else this.fade(this.track.el, 0, 300, () => this.track?.el.pause());
  }
  pause(p) { if (!this.track) return; if (p) this.track.el.pause(); else if (this.musicOn) this.track.el.play().catch(() => {}); }
  dispose() { this.music(null); this.ctx?.close().catch(() => {}); }
}
