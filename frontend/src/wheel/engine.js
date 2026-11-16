// Bestrafungsrad canvas scene. Pure drawing + timeline; React only passes entries/spins in.
// The timeline is driven by the server spin record (created, start/final angle), so the admin tab
// and the OBS source show the same frame at the same moment.
// Older Chromium (Streamlabs/OBS): no roundRect, no ctx.filter, no newer APIs.
export const TAU = Math.PI * 2;
const PEGS = 24;

const PALETTE = [
  ["#ff4d6a", "#a3102c", false], ["#ffc53d", "#c06a00", true], ["#9b6bff", "#4316b0", false], ["#1fd8bb", "#06705f", true],
  ["#ff6ac1", "#a3125f", false], ["#ff8a3d", "#a83800", false], ["#4d97ff", "#1238a0", false], ["#8ce64a", "#2b7d0a", true],
  ["#ffe066", "#b08000", true], ["#e45cff", "#7d0d97", false],
];

// Neighbours never share a colour, including the last and the first segment.
export function colorFor(idx, count) {
  let ci = idx % PALETTE.length;
  if (idx === count - 1 && count > 1 && ci === 0) ci = 3;
  const [light, dark, textDark] = PALETTE[ci];
  return { light, dark, textDark };
}

// Velocity profile: quick spin-up, then a long, slowing crawl. Integrated once into a lookup table.
const N = 2000;
const CUM = new Float32Array(N + 1);
(() => {
  let s = 0;
  for (let i = 1; i <= N; i++) { const p = (i - 0.5) / N; s += Math.min(1, p / 0.045) * Math.pow(1 - p, 1.9); CUM[i] = s; }
  for (let i = 0; i <= N; i++) CUM[i] /= s;
})();
export function ease(p) {
  if (p <= 0) return 0;
  if (p >= 1) return 1;
  const x = p * N, i = Math.floor(x);
  return CUM[i] + (CUM[i + 1] - CUM[i]) * (x - i);
}

export function angleAt(spin, t) {
  const a0 = spin.start_angle, a1 = spin.final_angle;
  if (t < spin.intro) { const q = (t - (spin.intro - 0.9)) / 0.9; return a0 - (q > 0 ? 0.34 * Math.sin(Math.PI * q) : 0); }
  return a0 + (a1 - a0) * ease((t - spin.intro) / spin.spin);
}

export function spans(entries) {
  const total = entries.reduce((s, e) => s + e.weight, 0) || 1;
  let at = 0;
  return entries.map((e, i) => { const size = (e.weight / total) * TAU; const span = { i, from: at, to: at + size, chance: e.weight / total }; at += size; return span; });
}

export function indexUnderPointer(segs, angle) {
  const pos = ((-angle % TAU) + TAU) % TAU;
  for (const s of segs) if (pos >= s.from && pos < s.to) return s.i;
  return segs.length - 1;
}

const rand = (a, b) => a + Math.random() * (b - a);
const backOut = (x) => { const c = 1.9; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2); };
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));

export class WheelScene {
  constructor(canvas, { opaque = false, sound = () => {}, onState = () => {} } = {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.opaque = opaque;
    this.sound = sound;
    this.onState = onState;
    this.entries = [];
    this.spin = null;
    this.offset = 0;
    this.hold = false;
    this.parts = [];
    this.flap = 0; this.flapV = 0;
    this.chase = 0; this.rays = 0;
    this.shake = 0; this.flash = 0;
    this.lastPeg = null; this.lastT = null; this.lastAngle = null;
    this.fired = new Set();
    this.faceKey = ""; this.face = null;
    this.state = {};
    this.W = 1; this.H = 1;
    this.frame = this.frame.bind(this);
    this.prev = performance.now();
    this.raf = requestAnimationFrame(this.frame);
  }

  dispose() { cancelAnimationFrame(this.raf); }

  resize(w, h) {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    this.W = Math.max(1, w); this.H = Math.max(1, h); this.dpr = dpr;
    this.canvas.width = Math.round(this.W * dpr); this.canvas.height = Math.round(this.H * dpr);
    this.faceKey = "";
  }

  setEntries(entries) { this.entries = entries || []; }
  setSpin(spin, offset = this.offset) {
    if (spin?.id !== this.spin?.id) { this.lastT = null; this.lastPeg = null; this.parts = []; this.fired = new Set(); }
    this.spin = spin; this.offset = offset;
  }
  setHold(hold) { this.hold = hold; }
  now() { return Date.now() / 1000 + this.offset; }

  // ------------------------------------------------------------------ face cache
  layout() {
    const R = Math.min(this.W * 0.27, this.H * 0.37);
    return { R, cx: this.W * 0.42, cy: this.H * 0.54 };
  }

  buildFace(entries, R) {
    const key = `${R}|${this.dpr}|${entries.map((e) => `${e.key}:${e.weight}`).join(",")}`;
    if (key === this.faceKey) return;
    this.faceKey = key;
    const size = Math.ceil(R * 2 * this.dpr) + 4;
    const face = this.face || document.createElement("canvas");
    face.width = size; face.height = size;
    const g = face.getContext("2d");
    g.setTransform(this.dpr, 0, 0, this.dpr, size / 2, size / 2);
    g.clearRect(-size, -size, size * 2, size * 2);
    const segs = spans(entries);
    this.segs = segs;
    if (!entries.length) {
      const grad = g.createRadialGradient(0, 0, R * 0.1, 0, 0, R);
      grad.addColorStop(0, "#3a2a5c"); grad.addColorStop(1, "#1a1030");
      g.fillStyle = grad; g.beginPath(); g.arc(0, 0, R, 0, TAU); g.fill();
    }
    segs.forEach((s, idx) => {
      const { light, dark, textDark } = colorFor(idx, segs.length);
      s.color = light; s.dark = dark; s.textDark = textDark;
      const a0 = -Math.PI / 2 + s.from, a1 = -Math.PI / 2 + s.to;
      const grad = g.createRadialGradient(0, 0, R * 0.12, 0, 0, R);
      grad.addColorStop(0, dark); grad.addColorStop(0.45, light); grad.addColorStop(0.9, light); grad.addColorStop(1, dark);
      g.fillStyle = grad;
      g.beginPath(); g.moveTo(0, 0); g.arc(0, 0, R, a0, a1); g.closePath(); g.fill();
      // soft inner bevel
      g.strokeStyle = "rgba(255,255,255,0.18)"; g.lineWidth = R * 0.01;
      g.beginPath(); g.arc(0, 0, R * 0.985, a0 + 0.004, a1 - 0.004); g.stroke();
    });
    // separators
    if (segs.length > 1) {
      g.strokeStyle = "#ffe7a3"; g.lineWidth = R * 0.009; g.shadowColor = "rgba(0,0,0,0.5)"; g.shadowBlur = R * 0.02;
      for (const s of segs) { const a = -Math.PI / 2 + s.from; g.beginPath(); g.moveTo(Math.cos(a) * R * 0.18, Math.sin(a) * R * 0.18); g.lineTo(Math.cos(a) * R, Math.sin(a) * R); g.stroke(); }
      g.shadowBlur = 0;
    }
    // labels
    for (const s of segs) {
      const e = entries[s.i], span = s.to - s.from;
      const mid = -Math.PI / 2 + (s.from + s.to) / 2;
      let font = Math.min(R * 0.072, R * 0.62 * span * 0.5);
      if (font < R * 0.02) continue;
      g.save(); g.rotate(mid);
      const maxLen = R * 0.6;
      let text = e.name;
      g.font = `900 ${font}px Inter, system-ui, sans-serif`;
      while (g.measureText(text).width > maxLen && font > R * 0.034) { font *= 0.92; g.font = `900 ${font}px Inter, system-ui, sans-serif`; }
      if (g.measureText(text).width > maxLen) { while (text.length > 2 && g.measureText(`${text}…`).width > maxLen) text = text.slice(0, -1); text += "…"; }
      g.textAlign = "right"; g.textBaseline = "middle";
      g.lineWidth = font * 0.22; g.strokeStyle = s.textDark ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.55)"; g.lineJoin = "round";
      g.strokeText(text, R * 0.9, 0);
      g.fillStyle = s.textDark ? "#2a1400" : "#fff";
      g.fillText(text, R * 0.9, 0);
      if (e.weight > 1 && span > 0.12) {
        const r = Math.min(R * 0.05, font * 0.85);
        g.fillStyle = "rgba(0,0,0,0.45)"; g.beginPath(); g.arc(R * 0.27, 0, r, 0, TAU); g.fill();
        g.strokeStyle = "#ffe7a3"; g.lineWidth = R * 0.006; g.stroke();
        g.fillStyle = "#ffe7a3"; g.textAlign = "center"; g.font = `900 ${r * 0.95}px Inter, system-ui, sans-serif`;
        g.save(); g.rotate(Math.PI / 2); g.fillText(`×${e.weight}`, 0, -R * 0.27 + r * 0.05); g.restore();
      }
      g.restore();
    }
    // pegs
    for (let i = 0; i < PEGS; i++) {
      const a = -Math.PI / 2 + (i / PEGS) * TAU;
      const x = Math.cos(a) * R * 0.955, y = Math.sin(a) * R * 0.955;
      const pg = g.createRadialGradient(x - R * 0.004, y - R * 0.004, 0, x, y, R * 0.016);
      pg.addColorStop(0, "#fffbe6"); pg.addColorStop(0.5, "#f2c14e"); pg.addColorStop(1, "#7a4a00");
      g.fillStyle = pg; g.beginPath(); g.arc(x, y, R * 0.015, 0, TAU); g.fill();
    }
    this.face = face;
    this.faceSize = size;
  }

  // ------------------------------------------------------------------ particles
  burst(x, y, n, kind, power = 1) {
    const colors = kind === "spark" ? ["#fff6c8", "#ffd84a", "#ff9a3d"] : ["#ff4d6a", "#ffc53d", "#9b6bff", "#1fd8bb", "#ff6ac1", "#4d97ff", "#fff"];
    for (let i = 0; i < n; i++) {
      const a = rand(0, TAU), v = rand(0.2, 1) * power;
      this.parts.push({
        kind, x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - (kind === "confetti" ? power * 0.35 : 0),
        life: 0, max: kind === "spark" ? rand(0.25, 0.6) : kind === "firework" ? rand(0.9, 1.6) : rand(2.2, 3.6),
        size: kind === "confetti" ? rand(0.6, 1.3) : rand(0.25, 0.6), color: colors[(Math.random() * colors.length) | 0],
        rot: rand(0, TAU), vr: rand(-12, 12),
      });
    }
  }

  coinRain(n) {
    for (let i = 0; i < n; i++) this.parts.push({ kind: "coin", x: rand(0, this.W), y: rand(-this.H * 0.6, -20), vx: rand(-0.02, 0.02), vy: rand(0.1, 0.35), life: 0, max: 4, size: rand(0.9, 1.5), rot: rand(0, TAU), vr: rand(4, 10) });
  }

  stepParts(dt, u) {
    const g = 1.6 * u;
    this.parts = this.parts.filter((p) => {
      p.life += dt;
      if (p.life > p.max) return false;
      const drag = p.kind === "confetti" ? 0.985 : p.kind === "firework" ? 0.97 : 0.95;
      p.vx *= drag; p.vy = p.vy * drag + (p.kind === "spark" ? 0.4 : p.kind === "firework" ? 0.25 : 0.55) * g * dt / u;
      if (p.kind === "confetti") p.vx += Math.sin(p.life * 6 + p.rot) * 0.002;
      p.x += p.vx * u * 60 * dt; p.y += p.vy * u * 60 * dt; p.rot += p.vr * dt;
      return p.y < this.H + 60;
    });
  }

  drawParts(c, u) {
    for (const p of this.parts) {
      const fade = Math.min(1, (p.max - p.life) / 0.5);
      c.globalAlpha = fade;
      if (p.kind === "confetti") {
        c.save(); c.translate(p.x, p.y); c.rotate(p.rot); c.scale(1, Math.abs(Math.cos(p.rot * 1.3)) + 0.15);
        c.fillStyle = p.color; c.fillRect(-u * p.size * 0.6, -u * p.size * 0.35, u * p.size * 1.2, u * p.size * 0.7); c.restore();
      } else if (p.kind === "coin") {
        c.save(); c.translate(p.x, p.y); c.scale(Math.abs(Math.cos(p.rot)) + 0.08, 1);
        c.fillStyle = "#ffcf3a"; c.beginPath(); c.arc(0, 0, u * p.size, 0, TAU); c.fill();
        c.strokeStyle = "#a86a00"; c.lineWidth = u * 0.18; c.stroke();
        c.fillStyle = "#fff3b0"; c.beginPath(); c.arc(-u * p.size * 0.3, -u * p.size * 0.3, u * p.size * 0.28, 0, TAU); c.fill(); c.restore();
      } else {
        c.fillStyle = p.color; c.beginPath(); c.arc(p.x, p.y, u * p.size * (p.kind === "firework" ? 1.1 : 1), 0, TAU); c.fill();
      }
    }
    c.globalAlpha = 1;
  }

  // ------------------------------------------------------------------ main loop
  emit(name, data) { try { this.sound(name, data); } catch { /* sound must never break the scene */ } }

  timeline(spin, t) {
    // Each moment fires once per spin, and only when it is crossed live (no replay on reload).
    // A spin seen within its first 1.5 s (admin click, overlay poll) still gets its intro.
    const prev = this.lastT === null ? (t < 1.5 ? -0.01 : t) : this.lastT;
    this.lastT = t;
    const stopAt = spin.intro + spin.spin;
    const cross = (at) => prev < at && t >= at;
    if (cross(0)) this.emit("intro");
    if (cross(spin.intro)) { this.emit("launch"); this.flash = 0.25; }
    if (cross(stopAt - 2.8)) this.emit("tension", 2.8);
    if (cross(stopAt)) this.emit("stop");
    if (cross(stopAt + 0.15)) this.emit("win");
    for (let k = 0; k < 7; k++) if (cross(stopAt + 0.6 + k * 0.55)) this.emit("firework", k);
    if (cross(spin.intro + spin.spin + spin.reveal)) this.emit("end");
  }

  frame(ts) {
    this.raf = requestAnimationFrame(this.frame);
    const dt = Math.min(0.05, (ts - this.prev) / 1000 || 0);
    this.prev = ts;
    const c = this.ctx, W = this.W, H = this.H, u = Math.min(W, H) / 100;
    const { R, cx, cy } = this.layout();
    const spin = this.spin;
    const t = spin ? this.now() - spin.created : Infinity;
    const total = spin ? spin.intro + spin.spin + spin.reveal : 0;
    const stopAt = spin ? spin.intro + spin.spin : 0;
    const live = spin && t >= -0.2 && t < total + 1;
    const showResult = spin && t >= stopAt && (t < total || this.hold);
    if (spin) this.timeline(spin, t);

    let phase = "idle";
    if (live) phase = t < 0 ? "idle" : t < spin.intro ? "intro" : t < stopAt ? "spin" : t < total ? "result" : "out";
    else if (showResult) phase = "result";

    const entries = (live || showResult) && spin ? spin.entries : this.entries;
    const angle = spin ? (t < 0 ? spin.start_angle : t >= stopAt ? spin.final_angle : angleAt(spin, t)) : 0;

    // visibility (stream overlay is invisible outside a spin)
    let alpha = 1;
    if (!this.opaque) {
      if (!live || t < 0) alpha = 0;
      else if (t < 0.5) alpha = t / 0.5;
      else if (t > total) alpha = Math.max(0, 1 - (t - total) / 0.8);
    }
    c.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    c.clearRect(0, 0, W, H);
    if (alpha <= 0) { this.report({ phase: "hidden", index: -1 }); return; }
    c.globalAlpha = alpha;

    this.buildFace(entries, R);
    const segs = this.segs || [];

    // speed + pegs
    const dA = this.lastAngle === null ? 0 : angle - this.lastAngle;
    this.lastAngle = angle;
    const omega = dt > 0 ? Math.abs(dA) / dt : 0;           // rad/s
    const pegPos = Math.floor(((-angle % TAU) + TAU) % TAU / (TAU / PEGS));
    if (this.lastPeg !== null && pegPos !== this.lastPeg && (phase === "spin" || phase === "intro")) {
      const pegsPerSec = omega / (TAU / PEGS);
      this.emit("tick", pegsPerSec);
      this.flap = -clamp(0.18 + pegsPerSec * 0.012, 0.18, 0.5);
      if (pegsPerSec < 30) this.burst(cx + R * 0.04, cy - R * 0.95, 3 + (pegsPerSec > 10 ? 4 : 0), "spark", 0.5 * u / 8);
    }
    this.lastPeg = pegPos;
    this.flapV += (-this.flap * 320 - this.flapV * 16) * dt;
    this.flap += this.flapV * dt;

    // background
    const spinBoost = phase === "spin" ? clamp(omega / 6, 0.3, 3) : phase === "result" ? 0.6 : 0.15;
    this.rays += dt * 0.12 * spinBoost;
    if (this.opaque) {
      const bg = c.createRadialGradient(cx, cy, R * 0.3, W / 2, H / 2, Math.max(W, H) * 0.75);
      bg.addColorStop(0, "#3b1468"); bg.addColorStop(0.55, "#1a0838"); bg.addColorStop(1, "#07020f");
      c.fillStyle = bg; c.fillRect(0, 0, W, H);
    } else {
      const bg = c.createRadialGradient(cx, cy, R * 0.6, W / 2, H / 2, Math.max(W, H) * 0.7);
      bg.addColorStop(0, "rgba(40,10,70,0.78)"); bg.addColorStop(1, "rgba(5,0,12,0.9)");
      c.fillStyle = bg; c.fillRect(0, 0, W, H);
    }
    c.save(); c.translate(cx, cy); c.rotate(this.rays);
    const rayCount = 18;
    for (let i = 0; i < rayCount; i++) {
      const a = (i / rayCount) * TAU;
      const rg = c.createRadialGradient(0, 0, R * 0.8, 0, 0, Math.max(W, H));
      rg.addColorStop(0, phase === "result" ? "rgba(255,210,80,0.22)" : "rgba(255,200,90,0.11)"); rg.addColorStop(1, "rgba(255,200,90,0)");
      c.fillStyle = rg;
      c.beginPath(); c.moveTo(0, 0); c.arc(0, 0, Math.max(W, H), a, a + TAU / rayCount / 2); c.closePath(); c.fill();
    }
    c.restore();

    // camera: intro pop, slow push-in during the final crawl, shake on stop
    let scale = 1;
    if (phase === "intro" && live) scale = 0.2 + 0.8 * backOut(clamp(t / 1.0, 0, 1));
    if (phase === "spin") { const p = (t - spin.intro) / spin.spin; scale = 1 + 0.07 * clamp((p - 0.6) / 0.4, 0, 1) ** 2; }
    if (phase === "result" && live) scale = 1.07 - 0.07 * clamp((t - stopAt) / 0.6, 0, 1);
    this.shake = Math.max(0, this.shake - dt * 2.2);
    if (spin && this.fired && !this.fired.has("shake") && t >= stopAt && t < stopAt + 0.3 && live) { this.fired.add("shake"); this.shake = 1; this.flash = 0.7; this.burst(cx, cy - R, 60, "spark", u * 0.18); }
    const sx = (Math.random() - 0.5) * this.shake * u * 2.2, sy = (Math.random() - 0.5) * this.shake * u * 2.2;
    const introSpin = phase === "intro" && live ? (1 - backOut(clamp(t / 1.0, 0, 1))) * -1.6 : 0;

    c.save();
    c.translate(cx + sx, cy + sy + (scale - 1) * R * 0.9);
    c.scale(scale, scale);

    // drop shadow + outer glow
    c.save();
    c.shadowColor = phase === "result" ? "rgba(255,200,60,0.9)" : "rgba(160,80,255,0.7)"; c.shadowBlur = R * (phase === "result" ? 0.35 : 0.2);
    c.fillStyle = "#1a0b2e"; c.beginPath(); c.arc(0, 0, R * 1.1, 0, TAU); c.fill();
    c.restore();

    // rotating face with motion blur at speed
    const drawFace = (a, al) => { c.save(); c.globalAlpha = alpha * al; c.rotate(a + introSpin); c.drawImage(this.face, -this.faceSize / 2 / this.dpr, -this.faceSize / 2 / this.dpr, this.faceSize / this.dpr, this.faceSize / this.dpr); c.restore(); };
    const blur = clamp(omega / 18, 0, 1);
    if (blur > 0.05) { for (let k = 3; k >= 1; k--) drawFace(angle - dA * k * 0.6, 0.22 * blur); }
    drawFace(angle, 1);
    c.globalAlpha = alpha;

    // result: dim the losers, make the winner glow
    if (showResult && spin) {
      const wIndex = spin.entries.findIndex((e) => e.key === spin.winner);
      const pulse = 0.5 + 0.5 * Math.sin(t * 7);
      c.save(); c.rotate(angle);
      for (const s of segs) {
        const a0 = -Math.PI / 2 + s.from, a1 = -Math.PI / 2 + s.to;
        c.beginPath(); c.moveTo(0, 0); c.arc(0, 0, R, a0, a1); c.closePath();
        if (s.i !== wIndex) { c.fillStyle = `rgba(5,0,15,${0.62 * clamp((t - stopAt) / 0.5, 0, 1)})`; c.fill(); }
        else { c.shadowColor = "#ffd84a"; c.shadowBlur = R * (0.12 + pulse * 0.12); c.strokeStyle = `rgba(255,240,170,${0.7 + pulse * 0.3})`; c.lineWidth = R * 0.03; c.stroke(); c.shadowBlur = 0; c.fillStyle = `rgba(255,255,220,${0.08 + pulse * 0.1})`; c.fill(); }
      }
      c.restore();
    }

    // metal rim with chasing bulbs
    const rim = c.createLinearGradient(-R, -R, R, R);
    rim.addColorStop(0, "#fff1b8"); rim.addColorStop(0.25, "#e0a526"); rim.addColorStop(0.5, "#7a4a00"); rim.addColorStop(0.75, "#f6c445"); rim.addColorStop(1, "#8a5600");
    c.lineWidth = R * 0.1; c.strokeStyle = rim; c.beginPath(); c.arc(0, 0, R * 1.05, 0, TAU); c.stroke();
    c.lineWidth = R * 0.012; c.strokeStyle = "#3a2200"; c.beginPath(); c.arc(0, 0, R * 1.0, 0, TAU); c.stroke();
    c.strokeStyle = "rgba(255,250,220,0.8)"; c.lineWidth = R * 0.006; c.beginPath(); c.arc(0, 0, R * 1.1, 0, TAU); c.stroke();
    const bulbs = 36;
    this.chase += dt * (phase === "spin" ? 6 + omega * 1.5 : phase === "intro" ? 14 : 2.2);
    const blink = Math.floor((spin ? t : ts / 1000) * 4) % 2;
    for (let i = 0; i < bulbs; i++) {
      const a = (i / bulbs) * TAU;
      const x = Math.cos(a) * R * 1.05, y = Math.sin(a) * R * 1.05;
      let on;
      if (phase === "result") on = (i % 2) === blink;
      else if (phase === "spin" || phase === "intro") on = (i + Math.floor(this.chase)) % 3 === 0;
      else on = Math.sin(i * 0.7 + this.chase) > 0.3;
      c.beginPath(); c.arc(x, y, R * 0.021, 0, TAU);
      if (on) { c.shadowColor = phase === "result" ? "#fff2a8" : "#ffd84a"; c.shadowBlur = R * 0.07; c.fillStyle = "#fffbe0"; c.fill(); c.shadowBlur = 0; }
      else { c.fillStyle = "#5c3a08"; c.fill(); c.strokeStyle = "rgba(255,220,140,0.35)"; c.lineWidth = R * 0.004; c.stroke(); }
    }

    // hub
    const hub = c.createRadialGradient(-R * 0.05, -R * 0.06, R * 0.01, 0, 0, R * 0.19);
    hub.addColorStop(0, "#fff7d1"); hub.addColorStop(0.45, "#f0b52c"); hub.addColorStop(1, "#6b3f00");
    c.shadowColor = "rgba(0,0,0,0.6)"; c.shadowBlur = R * 0.06;
    c.fillStyle = hub; c.beginPath(); c.arc(0, 0, R * 0.18, 0, TAU); c.fill(); c.shadowBlur = 0;
    c.fillStyle = "#2a0f45"; c.beginPath(); c.arc(0, 0, R * 0.135, 0, TAU); c.fill();
    c.strokeStyle = "#ffe7a3"; c.lineWidth = R * 0.008; c.stroke();
    c.save();
    c.rotate(phase === "spin" ? Math.sin(t * 9) * 0.12 : 0);
    c.font = `${R * 0.15}px "Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji", sans-serif`;
    c.textAlign = "center"; c.textBaseline = "middle";
    c.fillText(phase === "result" ? "😈" : "🐔", 0, R * 0.012);
    c.restore();

    // glare (does not rotate)
    const gl = c.createLinearGradient(-R, -R, R * 0.2, R * 0.2);
    gl.addColorStop(0, "rgba(255,255,255,0.2)"); gl.addColorStop(0.45, "rgba(255,255,255,0.04)"); gl.addColorStop(0.5, "rgba(255,255,255,0)");
    c.fillStyle = gl; c.beginPath(); c.arc(0, 0, R, 0, TAU); c.fill();

    // pointer (flapper on a pivot above the wheel)
    c.save();
    c.translate(0, -R * 1.13); c.rotate(this.flap);
    c.shadowColor = "rgba(0,0,0,0.6)"; c.shadowBlur = R * 0.05; c.shadowOffsetY = R * 0.015;
    const pg = c.createLinearGradient(-R * 0.07, 0, R * 0.07, 0);
    pg.addColorStop(0, "#ff7a8a"); pg.addColorStop(0.5, "#e0102e"); pg.addColorStop(1, "#7a0014");
    c.fillStyle = pg;
    c.beginPath(); c.moveTo(-R * 0.075, -R * 0.02); c.lineTo(R * 0.075, -R * 0.02); c.lineTo(0, R * 0.26); c.closePath(); c.fill();
    c.shadowBlur = 0; c.shadowOffsetY = 0;
    c.strokeStyle = "#ffe7a3"; c.lineWidth = R * 0.012; c.lineJoin = "round"; c.stroke();
    const kg = c.createRadialGradient(-R * 0.01, -R * 0.015, 0, 0, 0, R * 0.06);
    kg.addColorStop(0, "#fffbe6"); kg.addColorStop(0.6, "#f0b52c"); kg.addColorStop(1, "#6b3f00");
    c.fillStyle = kg; c.beginPath(); c.arc(0, 0, R * 0.055, 0, TAU); c.fill();
    c.restore();

    c.restore();

    // fireworks + confetti on the result
    if (spin && live && this.fired) {
      const fire = (name, at, fn) => { if (!this.fired.has(name) && t >= at && t < at + 0.5) { this.fired.add(name); fn(); } };
      fire("confetti", stopAt + 0.1, () => { this.burst(cx, cy - R * 0.2, 220, "confetti", u * 0.32); this.coinRain(70); });
      for (let k = 0; k < 7; k++) fire(`fw${k}`, stopAt + 0.6 + k * 0.55, () => this.burst(rand(W * 0.1, W * 0.9), rand(H * 0.12, H * 0.5), 80, "firework", u * 0.13));
    }
    this.stepParts(dt, u);
    this.drawParts(c, u);

    // flash
    if (this.flash > 0) { c.fillStyle = `rgba(255,248,220,${this.flash})`; c.fillRect(0, 0, W, H); this.flash = Math.max(0, this.flash - dt * 1.6); }
    c.globalAlpha = 1;

    const index = segs.length ? indexUnderPointer(segs, angle) : -1;
    this.report({ phase, index, scale });
  }

  report(state) {
    if (state.phase !== this.state.phase || state.index !== this.state.index) { this.state = state; this.onState(state); }
  }

  // Wheel geometry for DOM overlays (percent of the stage).
  geometry() { const { R, cx, cy } = this.layout(); return { R: R / Math.min(this.W, this.H) * 100, cx: cx / this.W * 100, cy: cy / this.H * 100 }; }
}
