// Sound for Admin Stream Control: the casino sample pack (jingles, voices, coins) plus synthesized
// weather loops (rain, wind, fire, hum) and one-shots (thunder, boom, glass, claps, clucks, horn).
import { DerbyAudio } from "../horses/audio.js";

const rand = (a, b) => a + Math.random() * (b - a);

export class StreamAudio extends DerbyAudio {
  constructor() {
    super();
    this.loops = new Map();   // effect key -> stop()
  }

  // Crowd swell that dies away completely (the derby keeps a murmur, the stream must not).
  roar(seconds = 2.2) {
    this.ensure();
    if (!this.crowdGain) return;
    const t = this.ctx.currentTime, g = this.crowdGain.gain;
    g.cancelScheduledValues(t); g.setValueAtTime(g.value, t);
    g.linearRampToValueAtTime(0.6, t + 0.25); g.setTargetAtTime(0, t + seconds * 0.6, 0.5);
  }

  // Filtered noise bed; returns a stop function with a soft release.
  noiseLoop({ type = "bandpass", freq = 1000, q = 0.7, gain = 0.2, rate = 1, lfo = 0 }) {
    const c = this.ensure();
    if (!c || !this.noise) return () => {};
    const src = c.createBufferSource(); src.buffer = this.noise; src.loop = true; src.playbackRate.value = rate;
    const f = c.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
    const g = c.createGain(); g.gain.value = 0;
    src.connect(f).connect(g).connect(this.sfx);
    src.start();
    g.gain.setTargetAtTime(gain, c.currentTime, 0.4);
    let osc;
    if (lfo) { osc = c.createOscillator(); const lg = c.createGain(); osc.frequency.value = lfo; lg.gain.value = gain * 0.6; osc.connect(lg).connect(g.gain); osc.start(); }
    return () => { const t = c.currentTime; g.gain.cancelScheduledValues(t); g.gain.setTargetAtTime(0, t, 0.35); setTimeout(() => { try { src.stop(); osc?.stop(); } catch { /* already stopped */ } src.disconnect(); f.disconnect(); g.disconnect(); }, 2000); };
  }

  burst({ freq = 800, type = "bandpass", q = 1, gain = 0.4, dur = 0.12, delay = 0, rate = 1 }) {
    const c = this.ctx;
    if (!c || !this.noise || c.state !== "running") return;
    const t = c.currentTime + delay;
    const src = c.createBufferSource(); src.buffer = this.noise; src.playbackRate.value = rate;
    const f = c.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
    const g = c.createGain();
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(gain, t + 0.005); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.connect(f).connect(g).connect(this.sfx);
    src.start(t, Math.random(), dur + 0.05);
    src.onended = () => { src.disconnect(); f.disconnect(); g.disconnect(); };
  }

  sweep(from, to, dur, { type = "sine", gain = 0.4, delay = 0 } = {}) {
    const c = this.ctx;
    if (!c) return;
    const t = c.currentTime + delay;
    const o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.setValueAtTime(from, t); o.frequency.exponentialRampToValueAtTime(to, t + dur);
    g.gain.setValueAtTime(gain, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g).connect(this.sfx); o.start(t); o.stop(t + dur + 0.05);
    o.onended = () => { o.disconnect(); g.disconnect(); };
  }

  // One-shots requested by the canvas engine.
  fx(name) {
    switch (name) {
      case "cannon": this.play("kickback", { gain: 0.9, gap: 0 }); this.burst({ freq: 140, type: "lowpass", gain: 0.9, dur: 0.5 }); this.burst({ freq: 3000, type: "highpass", gain: 0.3, dur: 0.25 }); break;
      case "firework": this.burst({ freq: 200, type: "lowpass", gain: 0.6, dur: 0.6 }); for (let i = 0; i < 8; i++) this.burst({ freq: 4000, type: "highpass", gain: 0.08, dur: 0.04, delay: 0.25 + i * rand(0.04, 0.09) }); break;
      case "coin": this.play(`coin-${1 + Math.floor(Math.random() * 5)}`, { gain: 0.3, rate: rand(0.9, 1.3), gap: 0.05 }); break;
      case "thunder": this.burst({ freq: 3000, type: "lowpass", gain: 0.5, dur: 0.15 }); this.burst({ freq: 110, type: "lowpass", gain: 1, dur: 3.2, rate: 0.5, delay: 0.05 }); break;
      case "thunder-far": this.burst({ freq: 90, type: "lowpass", gain: 0.8, dur: 3.5, rate: 0.4, delay: 0.6 }); break;
      case "boom": this.sweep(120, 35, 0.7, { gain: 0.9 }); this.burst({ freq: 150, type: "lowpass", gain: 0.6, dur: 0.4 }); break;
      case "glass": this.burst({ freq: 5000, type: "highpass", gain: 0.6, dur: 0.6 }); for (let i = 0; i < 10; i++) this.sweep(rand(2500, 6000), rand(1800, 4000), 0.15, { type: "triangle", gain: 0.06, delay: rand(0, 0.4) }); this.burst({ freq: 300, type: "lowpass", gain: 0.5, dur: 0.2 }); break;
      case "cluck": { const f = rand(500, 750); this.sweep(f, f * 1.6, 0.06, { type: "square", gain: 0.05 }); this.sweep(f * 1.2, f * 0.8, 0.09, { type: "square", gain: 0.05, delay: 0.08 }); break; }
      case "splat": this.burst({ freq: 600, type: "bandpass", q: 0.8, gain: 0.35, dur: 0.18 }); break;
      case "pop": this.sweep(rand(500, 900), rand(200, 300), 0.06, { type: "sine", gain: 0.25 }); this.burst({ freq: 2000, gain: 0.15, dur: 0.03 }); break;
      default: break;
    }
  }

  clapLoop(seconds) {
    const c = this.ensure(); if (!c) return () => {};
    let alive = true;
    const tick = () => {
      if (!alive) return;
      for (let i = 0; i < 6; i++) this.burst({ freq: rand(900, 2200), q: 1.2, gain: rand(0.12, 0.3), dur: 0.07, delay: rand(0, 0.12) });
      setTimeout(tick, 90);
    };
    tick();
    const t = setTimeout(() => { alive = false; }, seconds * 1000);
    return () => { alive = false; clearTimeout(t); };
  }

  pulse(ms, fn) { let alive = true; const run = () => { if (!alive) return; fn(); setTimeout(run, typeof ms === "function" ? ms() : ms); }; run(); return () => { alive = false; }; }

  sadTrombone() {
    const c = this.ensure(); if (!c) return;
    const t = c.currentTime;
    [[392, 0.35], [370, 0.35], [349, 0.35], [330, 1.1]].reduce((at, [f, d]) => { this.tone(f, t + at, d, { type: "sawtooth", gain: 0.14, cutoff: 1400, vibrato: d > 1 ? 9 : 2 }); return at + d + 0.05; }, 0);
  }

  // Start the sound for an effect; returns a stop function (or nothing for one-shots).
  start(id, dur) {
    this.ensure();
    switch (id) {
      case "confetti-rain": this.play("bonus-step", { gain: 0.6 }); this.roar(2); break;
      case "fireworks": this.roar(2); break;
      case "balloons": this.play("lane", { gain: 0.6 }); break;
      case "money-rain": this.play("jackpot", { gain: 0.6 }); return this.pulse(160, () => this.fx("coin"));
      case "stars": this.play("vip-lit", { gain: 0.7 }); break;
      case "hearts": this.play("mission-complete", { gain: 0.6 }); break;
      case "applause": this.roar(dur); return this.clapLoop(dur);
      case "disco": this.music("multiball"); return () => this.music(null);
      case "rainbow": this.play("extra-ball-lit", { gain: 0.8 }); break;
      case "hype": this.play("super-jackpot", { gain: 0.9 }); this.voiceFree = 0; this.voice("vo-fight", 0.3); this.roar(4); break;
      case "noir-rain": return this.noiseLoop({ type: "highpass", freq: 900, gain: 0.35 });
      case "thunderstorm": return this.noiseLoop({ type: "highpass", freq: 600, gain: 0.5 });
      case "snow": return this.noiseLoop({ type: "bandpass", freq: 400, q: 0.5, gain: 0.08, lfo: 0.15 });
      case "fog": return this.noiseLoop({ type: "lowpass", freq: 300, gain: 0.12, lfo: 0.1 });
      case "sandstorm": return this.noiseLoop({ type: "bandpass", freq: 900, q: 0.4, gain: 0.4, lfo: 0.35 });
      case "autumn": case "sakura": case "feathers": return this.noiseLoop({ type: "bandpass", freq: 600, q: 0.5, gain: 0.1, lfo: 0.2 });
      case "underwater": { const stop = this.noiseLoop({ type: "lowpass", freq: 260, gain: 0.35 }); const blub = this.pulse(() => rand(150, 500), () => this.sweep(rand(300, 600), rand(900, 1400), 0.08, { gain: 0.08 })); return () => { stop(); blub(); }; }
      case "fire": { const stop = this.noiseLoop({ type: "lowpass", freq: 500, gain: 0.3 }); const crack = this.pulse(() => rand(30, 140), () => this.burst({ freq: rand(1500, 4000), q: 2, gain: rand(0.05, 0.2), dur: 0.02 })); return () => { stop(); crack(); }; }
      case "frost": for (let i = 0; i < 12; i++) this.sweep(rand(1800, 4200), rand(2400, 5200), 0.4, { type: "sine", gain: 0.04, delay: i * 0.12 }); return this.noiseLoop({ type: "bandpass", freq: 2500, q: 0.5, gain: 0.05, lfo: 0.2 });
      case "sunset": { const c = this.ctx; const t = c?.currentTime || 0; [220, 277, 330, 415].forEach((f) => this.tone(f, t, 4, { type: "sine", gain: 0.05 })); break; }
      case "night-vision": this.sweep(1800, 1800, 0.12, { type: "square", gain: 0.05 }); return this.noiseLoop({ type: "highpass", freq: 3000, gain: 0.05 });
      case "vhs": this.play("game-start", { gain: 0.5, rate: 0.7 }); return this.noiseLoop({ type: "highpass", freq: 5000, gain: 0.07 });
      case "glitch": return this.pulse(() => rand(40, 200), () => this.burst({ freq: rand(400, 6000), q: 3, gain: 0.25, dur: rand(0.02, 0.12) }));
      case "matrix": return this.pulse(() => rand(60, 220), () => this.sweep(rand(800, 2400), rand(800, 2400), 0.04, { type: "square", gain: 0.03 }));
      case "old-film": { const tick = this.pulse(55, () => this.burst({ freq: 1500, q: 2, gain: 0.05, dur: 0.015 })); const hiss = this.noiseLoop({ type: "highpass", freq: 4000, gain: 0.05 }); return () => { tick(); hiss(); }; }
      case "crt-off": this.sweep(4000, 60, 0.45, { type: "sawtooth", gain: 0.12 }); this.burst({ freq: 3000, type: "highpass", gain: 0.2, dur: 0.3 }); setTimeout(() => this.sweep(60, 3000, 0.4, { type: "sawtooth", gain: 0.08 }), Math.max(0, (dur - 0.6) * 1000)); break;
      case "spotlight": this.play("mission-lit", { gain: 0.8 }); this.burst({ freq: 120, type: "lowpass", gain: 0.6, dur: 0.4 }); break;
      case "dizzy": return this.pulse(260, () => this.sweep(rand(1800, 2600), rand(2600, 3400), 0.08, { type: "sine", gain: 0.06 }));
      case "hypno": { const c = this.ctx; if (c) this.tone(440, c.currentTime, Math.max(1, dur), { type: "sine", gain: 0.06, vibrato: 30 }); break; }
      case "laugh": this.play("combo", { gain: 0.7 }); this.roar(2); break;
      case "pizza": this.play("drop", { gain: 0.6 }); break;
      case "horror": { const beat = this.pulse(900, () => { this.sweep(70, 45, 0.18, { gain: 0.8 }); this.sweep(65, 40, 0.18, { gain: 0.6, delay: 0.24 }); }); const drone = this.noiseLoop({ type: "lowpass", freq: 120, gain: 0.25 }); return () => { beat(); drone(); }; }
      case "sunglasses": this.play("drop", { gain: 0.8 }); this.voiceFree = 0; this.voice("vo-flawless", 1.1); break;
      case "gg": this.play("super-jackpot", { gain: 0.8 }); this.voiceFree = 0; this.voice("vo-winner", 0.4); this.roar(3); break;
      case "rip": this.play("game-over", { gain: 0.8 }); break;
      case "respect": this.play("mission-complete", { gain: 0.7 }); break;
      case "clutch": this.play("skill-shot", { gain: 0.9 }); this.voiceFree = 0; this.voice("vo-combo-breaker", 0.4); this.roar(3); return this.pulse(() => rand(350, 800), () => this.fx("thunder"));
      case "fail": this.sadTrombone(); break;
      case "wow": this.play("jackpot", { gain: 0.8 }); this.roar(2); break;
      case "countdown": { this.voiceFree = 0; this.voice("vo-num-3"); [["vo-num-2", 1000]].forEach(([v, ms]) => setTimeout(() => { this.voiceFree = 0; this.voice(v); }, ms)); [0, 1000, 2000].forEach((ms) => setTimeout(() => this.play("ball-click", { gain: 0.8, gap: 0 }), ms)); setTimeout(() => this.play("mission-lit", { gain: 0.8 }), 2000); setTimeout(() => { this.voiceFree = 0; this.voice("vo-f-go"); this.play("kickback", { gain: 0.8 }); }, 3000); break; }
      default: break;
    }
    return null;
  }
}
