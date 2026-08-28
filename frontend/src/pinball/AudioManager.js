export class AudioManager {
  constructor(enabledRef) {
    this.enabledRef = enabledRef;
    this.ctx = null;
    this.master = null;
    this.rollGain = null;
    this.rollOsc = null;
  }

  ensure() {
    if (!this.enabledRef.current) return null;
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return null;
    if (!this.ctx) {
      this.ctx = new AudioCtx();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.18;
      this.master.connect(this.ctx.destination);
      this.rollGain = this.ctx.createGain();
      this.rollGain.gain.value = 0.0001;
      this.rollOsc = this.ctx.createOscillator();
      this.rollOsc.type = "sawtooth";
      this.rollOsc.frequency.value = 46;
      this.rollOsc.connect(this.rollGain).connect(this.master);
      this.rollOsc.start();
    }
    if (this.ctx.state === "suspended") this.ctx.resume();
    return this.ctx;
  }

  tone(freq, dur = 0.05, type = "triangle", vol = 0.08, delay = 0) {
    const ctx = this.ensure();
    if (!ctx) return;
    const now = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(vol, now + 0.006);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    osc.connect(gain).connect(this.master);
    osc.start(now);
    osc.stop(now + dur + 0.03);
  }

  play(kind, power = 1) {
    const p = Math.max(0.15, Math.min(1.8, power));
    if (kind === "flipper") this.tone(118, 0.035, "square", 0.12 * p);
    else if (kind === "flipperDown") this.tone(72, 0.025, "square", 0.05);
    else if (kind === "plunger") [130, 260, 540].forEach((f, i) => this.tone(f, 0.05, "triangle", 0.08, i * 0.025));
    else if (kind === "bumper") [540, 880, 1320].forEach((f, i) => this.tone(f, 0.052, "triangle", 0.11 * p, i * 0.026));
    else if (kind === "sling") this.tone(360, 0.04, "sawtooth", 0.1 * p);
    else if (kind === "target") this.tone(740, 0.04, "triangle", 0.075 * p);
    else if (kind === "ramp") [440, 660, 990, 1320].forEach((f, i) => this.tone(f, 0.05, "triangle", 0.07, i * 0.035));
    else if (kind === "lock") [220, 440, 880].forEach((f, i) => this.tone(f, 0.09, "square", 0.1, i * 0.05));
    else if (kind === "jackpot") [520, 780, 1040, 1560, 2080].forEach((f, i) => this.tone(f, 0.08, "square", 0.12, i * 0.045));
    else if (kind === "drain") [180, 120, 72].forEach((f, i) => this.tone(f, 0.12, "sawtooth", 0.08, i * 0.06));
    else if (kind === "tilt") this.tone(54, 0.35, "sawtooth", 0.13);
  }

  setRolling(speed) {
    const ctx = this.ensure();
    if (!ctx || !this.rollGain || !this.rollOsc) return;
    const target = Math.min(0.045, Math.max(0.0001, speed * 0.004));
    this.rollGain.gain.setTargetAtTime(target, ctx.currentTime, 0.05);
    this.rollOsc.frequency.setTargetAtTime(38 + speed * 15, ctx.currentTime, 0.05);
  }

  dispose() {
    if (this.rollOsc) {
      try { this.rollOsc.stop(); } catch {}
    }
    if (this.ctx) this.ctx.close();
  }
}
