// Chicken Derby sound: the casino samples, voices and music from Pinball, plus a few things
// no sample pack has: a crowd bed that swells with the race, hoof thunder, the starting bell
// and a bugle fanfare. Everything runs through the shared effects bus, so the sliders and
// mute work for all of it.
import { PinballAudio } from "../pinball/audio.js";

export class DerbyAudio extends PinballAudio {
  ensure() {
    const c = super.ensure();
    if (c && !this.noise) this.buildSynth();
    return c;
  }

  buildSynth() {
    const c = this.ctx;
    const len = c.sampleRate * 2;
    const buf = c.createBuffer(1, len, c.sampleRate);
    const d = buf.getChannelData(0);
    let b0 = 0, b1 = 0, b2 = 0;
    for (let i = 0; i < len; i++) {
      const w = Math.random() * 2 - 1;
      b0 = 0.99765 * b0 + w * 0.099046; b1 = 0.963 * b1 + w * 0.2965164; b2 = 0.57 * b2 + w * 1.0526913;
      d[i] = (b0 + b1 + b2 + w * 0.1848) * 0.16;
    }
    this.noise = buf;
    // Crowd bed: two band-passed noise loops at different speeds give a murmur that is never static.
    this.crowdGain = c.createGain(); this.crowdGain.gain.value = 0;
    this.crowdFilter = c.createBiquadFilter(); this.crowdFilter.type = "bandpass"; this.crowdFilter.frequency.value = 600; this.crowdFilter.Q.value = 0.6;
    this.crowdFilter.connect(this.crowdGain).connect(this.sfx);
    for (const rate of [1, 0.83]) {
      const src = c.createBufferSource(); src.buffer = buf; src.loop = true; src.playbackRate.value = rate;
      src.connect(this.crowdFilter); src.start();
    }
    this.hoofAcc = 0;
    this.crowdLevel = 0;
  }

  setCrowd(level) {
    if (!this.crowdGain || !this.ctx) return;
    if (Math.abs(level - this.crowdLevel) < 0.01) return;
    this.crowdLevel = level;
    const t = this.ctx.currentTime;
    this.crowdGain.gain.setTargetAtTime(0.04 + level * 0.42, t, 0.3);
    this.crowdFilter.frequency.setTargetAtTime(480 + level * 1100, t, 0.35);
  }

  roar(seconds = 2.2) {
    if (!this.crowdGain) return;
    const t = this.ctx.currentTime, g = this.crowdGain.gain;
    g.cancelScheduledValues(t); g.setValueAtTime(g.value, t);
    g.linearRampToValueAtTime(0.75, t + 0.25); g.setTargetAtTime(0.04 + this.crowdLevel * 0.42, t + seconds * 0.5, 0.6);
  }

  hoof(gain) {
    const c = this.ctx;
    if (!c || !this.noise || c.state !== "running") return;
    const t = c.currentTime + Math.random() * 0.02;
    const src = c.createBufferSource(); src.buffer = this.noise; src.playbackRate.value = 0.6 + Math.random() * 0.3;
    const lp = c.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 180 + Math.random() * 120;
    const g = c.createGain();
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(gain, t + 0.006); g.gain.exponentialRampToValueAtTime(0.001, t + 0.09);
    src.connect(lp).connect(g).connect(this.sfx);
    src.start(t, Math.random() * 1.5, 0.11);
    src.onended = () => { src.disconnect(); lp.disconnect(); g.disconnect(); };
  }

  // Galloping pack: irregular thunder, denser and louder with intensity (0..1).
  hooves(dt, intensity) {
    if (!this.ctx || intensity <= 0) { this.hoofAcc = 0; return; }
    this.hoofAcc += dt * (10 + intensity * 16);
    while (this.hoofAcc >= 1) { this.hoofAcc -= 1 + Math.random() * 0.5; this.hoof((0.35 + Math.random() * 0.3) * intensity); }
  }

  tone(freq, start, dur, { type = "sine", gain = 0.2, cutoff = 4000, vibrato = 0 } = {}) {
    const c = this.ctx;
    if (!c) return;
    const o = c.createOscillator(), g = c.createGain(), f = c.createBiquadFilter();
    o.type = type; o.frequency.value = freq; f.type = "lowpass"; f.frequency.value = cutoff;
    if (vibrato) { const l = c.createOscillator(), lg = c.createGain(); l.frequency.value = 5.5; lg.gain.value = vibrato; l.connect(lg).connect(o.frequency); l.start(start); l.stop(start + dur + 0.05); }
    g.gain.setValueAtTime(0, start); g.gain.linearRampToValueAtTime(gain, start + 0.02); g.gain.setValueAtTime(gain, start + dur * 0.75); g.gain.exponentialRampToValueAtTime(0.001, start + dur);
    o.connect(f).connect(g).connect(this.sfx);
    o.start(start); o.stop(start + dur + 0.05);
    o.onended = () => { o.disconnect(); f.disconnect(); g.disconnect(); };
  }

  fanfare() {
    if (!this.ensure() || !this.sfxOn) return;
    const t = this.ctx.currentTime + 0.05;
    const notes = [[392, 0.16], [523, 0.16], [659, 0.16], [784, 0.34], [659, 0.16], [784, 0.7]];
    let at = t;
    for (const [f, d] of notes) {
      this.tone(f, at, d, { type: "sawtooth", gain: 0.11, cutoff: 2400, vibrato: 3 });
      this.tone(f * 2, at, d, { type: "square", gain: 0.025, cutoff: 3200 });
      at += d + 0.03;
    }
    this.duck(at - t + 0.3);
  }

  bell() {
    if (!this.ctx || !this.sfxOn) return;
    const t = this.ctx.currentTime;
    for (let i = 0; i < 14; i++) { this.tone(1480, t + i * 0.07, 0.09, { gain: 0.12 }); this.tone(2960, t + i * 0.07, 0.06, { gain: 0.03 }); }
  }

  count(n) {
    this.ensure();
    if (n >= 2 && n <= 10) { this.voiceFree = 0; this.voice(`vo-num-${n}`); }
    this.play("ball-click", { gain: 0.6, rate: 0.8 + (10 - n) * 0.05 });
    if (n === 1) this.play("mission-lit", { gain: 0.7 });
  }

  go() {
    this.bell();
    this.play("kickback", { gain: 0.8 });
    this.voiceFree = 0; this.voice("vo-f-go", 0.15);
    this.roar(3);
  }

  call(c) {
    switch (c.sound) {
      case "lead": this.play("lane", { gain: 0.6, rate: 1.1 }); break;
      case "mine": this.play("vip-lit", { gain: 0.7 }); this.play("combo", { gain: 0.5 }); this.roar(1.5); break;
      case "lap": this.play("lanes-complete", { gain: 0.7 }); this.roar(1.6); break;
      case "final": this.play("extra-ball-lit", { gain: 0.8 }); this.voice("vo-f-hurry-up", 0.2); this.roar(2.5); break;
      case "hot": this.play("combo", { gain: 0.55, rate: 1.2 }); break;
      case "sad": this.play("drain", { gain: 0.35 }); break;
      case "hype": this.play("bumper-ping", { gain: 0.35, rate: 1.2 }); break;
      case "photo": this.play("flipper-up", { gain: 0.9, rate: 0.7 }); this.play("tilt-warning", { gain: 0.4 }); break;
      case "win": this.play("jackpot", { gain: 0.7 }); this.roar(4); break;
      case "go": default: break;
    }
  }
}
