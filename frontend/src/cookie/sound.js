// Santa's Cookie Crisis – sounds, made with WebAudio (no files). Landing cookies are clustered:
// at most ~10 single "plops" per second; above that a soft coin shimmer whose loudness follows
// the amount, so thousands of cookies per second never mean thousands of sounds.
export function createSound() {
  let ctx = null, master = null, hum = null, humGain = null, ovenGain = null;
  let muted = false;
  let musicOn = true;
  // "Gingerbread Workshop": very quiet background music, on unless the player switched it off.
  const music = typeof Audio === "function" ? new Audio("/music/cookie/gingerbread-workshop.mp3") : null;
  if (music) { music.loop = true; music.volume = 0.06; }
  let plopBudget = 0, landQueue = 0, lastCluster = 0, lastGear = 0;

  try {
    const saved = JSON.parse(localStorage.getItem("aviary_cookie_sound") || "{}");
    muted = Boolean(saved.muted); if (typeof saved.music === "boolean") musicOn = saved.music;
  } catch { /* defaults */ }

  function save() {
    try { localStorage.setItem("aviary_cookie_sound", JSON.stringify({ muted, music: musicOn })); } catch { /* optional */ }
  }

  function ensure() {
    if (ctx) { if (ctx.state === "suspended") ctx.resume(); return true; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    ctx = new AC();
    master = ctx.createGain(); master.gain.value = muted ? 0 : 0.5; master.connect(ctx.destination);
    // conveyor hum: filtered noise + low saw, volume follows the belt
    const buf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    hum = ctx.createBufferSource(); hum.buffer = buf; hum.loop = true;
    const lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 180;
    humGain = ctx.createGain(); humGain.gain.value = 0;
    hum.connect(lp); lp.connect(humGain); humGain.connect(master); hum.start();
    // oven: deep warm rumble
    const osc = ctx.createOscillator(); osc.type = "sawtooth"; osc.frequency.value = 46;
    const olp = ctx.createBiquadFilter(); olp.type = "lowpass"; olp.frequency.value = 90;
    ovenGain = ctx.createGain(); ovenGain.gain.value = 0;
    osc.connect(olp); olp.connect(ovenGain); ovenGain.connect(master); osc.start();
    return true;
  }

  function tone(freq, dur, { type = "sine", gain = 0.2, slide = 0, delay = 0 } = {}) {
    if (!ctx || muted) return;
    const t0 = ctx.currentTime + delay;
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = type; o.frequency.setValueAtTime(freq, t0);
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq + slide), t0 + dur);
    g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(gain, t0 + 0.008); g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g); g.connect(master); o.start(t0); o.stop(t0 + dur + 0.02);
  }

  function noise(dur, { freq = 1200, q = 1, gain = 0.2, type = "bandpass", delay = 0 } = {}) {
    if (!ctx || muted) return;
    const t0 = ctx.currentTime + delay;
    const buf = ctx.createBuffer(1, Math.ceil(ctx.sampleRate * dur), ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length);
    const src = ctx.createBufferSource(); src.buffer = buf;
    const f = ctx.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
    const g = ctx.createGain(); g.gain.value = gain;
    src.connect(f); f.connect(g); g.connect(master); src.start(t0);
  }

  const sfx = {
    take: () => { noise(0.25, { freq: 300, q: 0.5, gain: 0.3 }); tone(140, 0.15, { slide: -60, gain: 0.12 }); },
    portion: () => { noise(0.18, { freq: 400, gain: 0.25 }); tone(180, 0.12, { slide: -80, gain: 0.12 }); },
    roll: () => noise(0.22, { freq: 700, q: 0.6, gain: 0.18 }),
    rolled: () => { noise(0.25, { freq: 600, gain: 0.2 }); tone(520, 0.12, { gain: 0.06, type: "triangle" }); },
    crank: () => { for (let i = 0; i < 4; i++) noise(0.03, { freq: 3000, gain: 0.15, delay: i * 0.05 }); },
    cut: () => { noise(0.05, { freq: 2600, gain: 0.25 }); tone(140, 0.08, { gain: 0.15 }); },
    press: () => { tone(90, 0.18, { slide: -40, gain: 0.35 }); noise(0.08, { freq: 3200, gain: 0.2, delay: 0.03 }); },
    load: () => { noise(0.25, { freq: 900, q: 0.4, gain: 0.15 }); tone(330, 0.1, { gain: 0.05, type: "triangle", delay: 0.15 }); },
    push: () => { tone(110, 0.15, { gain: 0.2, type: "square" }); noise(0.2, { freq: 800, gain: 0.12 }); },
    blocked: () => tone(160, 0.12, { gain: 0.08, type: "square" }),
    buy: () => { tone(880, 0.15, { gain: 0.14, type: "triangle" }); tone(1320, 0.22, { gain: 0.12, type: "triangle", delay: 0.08 }); },
    machine: () => { [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.35, { gain: 0.13, type: "triangle", delay: i * 0.08 })); noise(0.4, { freq: 5000, gain: 0.05, delay: 0.3 }); },
    finale: () => { [523, 659, 784, 1047, 1319, 1568].forEach((f, i) => tone(f, 0.6, { gain: 0.15, type: "triangle", delay: i * 0.12 })); },
  };

  function plop(i) {
    tone(320 + Math.random() * 60, 0.09, { slide: -170, gain: 0.16, delay: i * 0.03 });
    tone(2100 + Math.random() * 500, 0.07, { gain: 0.05, type: "triangle", delay: i * 0.03 + 0.02 }); // the taler
  }

  return {
    // footsteps: crunchy snow outside, wooden floor inside
    step(outside) { if (!ctx || muted) return; if (outside) noise(0.16, { freq: 1800 + Math.random() * 600, q: 0.7, gain: 0.07 }); else { tone(110 + Math.random() * 30, 0.06, { gain: 0.05, type: "triangle" }); noise(0.05, { freq: 500, gain: 0.03 }); } },
    get muted() { return muted; },
    get music() { return musicOn; },
    unlock() { ensure(); if (musicOn && music) music.play().catch(() => {}); },
    toggleMute() { muted = !muted; save(); if (master) master.gain.value = muted ? 0 : 0.5; if (music) music.muted = muted; return muted; },
    toggleMusic() { musicOn = !musicOn; save(); if (music) { if (musicOn) { ensure(); music.play().catch(() => {}); } else music.pause(); } return musicOn; },
    handle(events) {
      if (!ctx) return;
      for (const e of events) {
        if (e.type === "land") landQueue += e.n;
        else if (sfx[e.type]) sfx[e.type]();
      }
    },
    // called every frame with the belt state
    update(dt, { belt = 0, oven = 0, machines = 0 } = {}) {
      if (!ctx || muted) return;
      plopBudget = Math.min(3, plopBudget + dt * 10);
      const now = ctx.currentTime;
      if (landQueue > 0) {
        if (landQueue <= 2 && plopBudget >= landQueue) { for (let i = 0; i < landQueue; i++) plop(i); plopBudget -= landQueue; landQueue = 0; }
        else if (now - lastCluster > 0.12) { // cluster: one shimmer for many cookies
          const loud = Math.min(0.18, 0.05 + Math.log10(landQueue + 1) * 0.05);
          for (let i = 0; i < 3; i++) tone(1800 + Math.random() * 1400, 0.09, { gain: loud, type: "triangle", delay: i * 0.025 });
          tone(260, 0.1, { slide: -120, gain: loud * 0.8 });
          landQueue = 0; lastCluster = now;
        }
      }
      if (machines > 0 && now - lastGear > Math.max(0.12, 0.6 - machines * 0.03)) { noise(0.02, { freq: 4000, gain: 0.03 }); lastGear = now; }
      humGain.gain.setTargetAtTime(belt ? Math.min(0.06, 0.02 + belt * 0.004) : 0, now, 0.3);
      ovenGain.gain.setTargetAtTime(oven ? 0.05 : 0, now, 0.5);
    },
    stop() { if (music) music.pause(); if (ctx) ctx.close().catch(() => {}); ctx = null; },
  };
}
