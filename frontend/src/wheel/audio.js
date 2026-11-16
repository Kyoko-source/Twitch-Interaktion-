// Bestrafungsrad sound: the casino samples (jingles, voices, clicks) of Pinball/Derby/Stream
// Control plus synthesized drum roll, whoosh, crash, riser and heartbeat. Everything runs through
// the shared effects bus, so mute works for all of it.
import { StreamAudio } from "../stream/audio.js";

export class WheelAudio extends StreamAudio {
  constructor() {
    super();
    this.timers = [];
  }

  later(ms, fn) { const t = setTimeout(fn, ms); this.timers.push(t); }

  reset() {
    this.timers.forEach(clearTimeout); this.timers = [];
    this.stopRoll?.(); this.stopRoll = null;
    this.stopCoins?.(); this.stopCoins = null;
  }

  whoosh(dur = 0.8, from = 250, to = 3500, gain = 0.3) {
    const c = this.ensure();
    if (!c || !this.noise || c.state !== "running") return;
    const t = c.currentTime;
    const src = c.createBufferSource(); src.buffer = this.noise;
    const f = c.createBiquadFilter(); f.type = "bandpass"; f.Q.value = 1.4;
    f.frequency.setValueAtTime(from, t); f.frequency.exponentialRampToValueAtTime(to, t + dur);
    const g = c.createGain();
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(gain, t + dur * 0.7); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.connect(f).connect(g).connect(this.sfx);
    src.start(t, Math.random(), dur + 0.05);
    src.onended = () => { src.disconnect(); f.disconnect(); g.disconnect(); };
  }

  snare(gain) {
    this.burst({ freq: 1900, q: 0.6, gain, dur: 0.09 });
    this.burst({ freq: 220, type: "lowpass", gain: gain * 0.5, dur: 0.06 });
  }

  // Accelerating snare roll with a crescendo; launch() ends it with the crash.
  drumroll(seconds) {
    if (!this.ensure()) return;
    this.stopRoll?.();
    let alive = true;
    const start = performance.now();
    const step = () => {
      if (!alive) return;
      const k = Math.min(1, (performance.now() - start) / (seconds * 1000));
      this.snare(0.07 + k * 0.28);
      if (Math.random() < 0.2) this.burst({ freq: 120, type: "lowpass", gain: 0.15 + k * 0.35, dur: 0.16 });
      if (k < 1) setTimeout(step, 72 - k * 36);
    };
    step();
    this.stopRoll = () => { alive = false; };
  }

  crash() {
    this.burst({ freq: 6000, type: "highpass", gain: 0.45, dur: 1.8 });
    this.burst({ freq: 2600, q: 0.5, gain: 0.25, dur: 1.1 });
    this.sweep(95, 38, 0.7, { gain: 0.85 });
  }

  // -------------------------------------------------------------- timeline
  intro() {
    if (!this.ensure()) return;
    this.reset();
    this.play("game-start", { gain: 0.7, gap: 0 });
    this.whoosh(1.0, 180, 4200, 0.32);
    this.drumroll(2.0);
    this.setCrowd(0.25);
    this.voiceFree = 0; this.voice("vo-f-ready", 0.5);
  }

  launch() {
    this.stopRoll?.(); this.stopRoll = null;
    this.crash();
    this.play("launch", { gain: 0.9, gap: 0 });
    this.play("kickback", { gain: 0.6, gap: 0 });
    this.whoosh(0.6, 3000, 300, 0.35);
    this.roar(1.8);
    this.voiceFree = 0; this.voice("vo-f-go", 0.05);
    this.setCrowd(0.4);
  }

  // speed = pegs per second passing the pointer
  tick(speed) {
    const s = Math.min(1, speed / 28);
    this.play("ball-click", { gain: 0.5 - s * 0.2, rate: 0.85 + s * 0.9, gap: 0.03 });
    if (speed < 7) this.burst({ freq: 2800, q: 5, gain: 0.14, dur: 0.035 });
  }

  // Final seconds: rising synth and a heartbeat that speeds up.
  tension(seconds) {
    const c = this.ensure();
    if (!c || c.state !== "running") return;
    const t = c.currentTime;
    const o = c.createOscillator(), o2 = c.createOscillator(), f = c.createBiquadFilter(), g = c.createGain();
    o.type = "sawtooth"; o2.type = "sawtooth"; o2.detune.value = 14;
    for (const osc of [o, o2]) { osc.frequency.setValueAtTime(98, t); osc.frequency.exponentialRampToValueAtTime(392, t + seconds); }
    f.type = "lowpass"; f.frequency.setValueAtTime(260, t); f.frequency.exponentialRampToValueAtTime(3200, t + seconds);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.06, t + seconds * 0.92); g.gain.linearRampToValueAtTime(0, t + seconds + 0.04);
    o.connect(f); o2.connect(f); f.connect(g).connect(this.sfx);
    o.start(t); o2.start(t); o.stop(t + seconds + 0.1); o2.stop(t + seconds + 0.1);
    o.onended = () => { o.disconnect(); o2.disconnect(); f.disconnect(); g.disconnect(); };
    let at = 0, gap = 700;
    while (at < seconds * 1000 - 200) {
      this.later(at, () => { this.sweep(82, 44, 0.17, { gain: 0.75 }); this.sweep(72, 40, 0.17, { gain: 0.5, delay: 0.19 }); });
      at += gap; gap = Math.max(380, gap - 45);
    }
    this.setCrowd(0.75);
  }

  stop() {
    this.play("drop", { gain: 1, gap: 0 });
    this.fx("boom");
    this.burst({ freq: 140, type: "lowpass", gain: 0.9, dur: 0.6 });
    this.silence();
  }

  win() {
    this.play("super-jackpot", { gain: 0.9, gap: 0 });
    this.later(250, () => this.fanfare());
    this.roar(5);
    this.voiceFree = 0; this.voice("vo-sudden-death", 1.0);
    this.stopCoins = this.pulse(140, () => this.fx("coin"));
    this.later(2200, () => { this.stopCoins?.(); this.stopCoins = null; });
    this.later(3600, () => { this.play("combo", { gain: 0.6 }); this.roar(2.5); });
  }

  firework() { this.fx("firework"); }

  end() { this.reset(); this.silence(); }
}
