// Tiny canvas particle system for the slot machine: spinning gold coins, drifting purple
// feathers, bright sparks and stars. Runs only while particles are alive.
const TAU = Math.PI * 2;

export class SlotFx {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.parts = [];
    this.rains = [];
    this.frame = 0;
    this.last = 0;
    this.reduced = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
    this.resize = this.resize.bind(this);
    this.tick = this.tick.bind(this);
    this.resize();
    if (typeof ResizeObserver === "function") { this.ro = new ResizeObserver(this.resize); this.ro.observe(canvas); }
  }

  resize() {
    const r = this.canvas.getBoundingClientRect();
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    this.w = r.width; this.h = r.height;
    this.canvas.width = Math.max(1, Math.round(r.width * dpr));
    this.canvas.height = Math.max(1, Math.round(r.height * dpr));
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  // x, y in 0..1 of the canvas.
  burst(kind, x, y, n = 20, power = 1) {
    if (this.reduced) n = Math.min(n, 6);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * TAU, v = (120 + Math.random() * 420) * power;
      this.add(kind, x * this.w, y * this.h, Math.cos(a) * v, Math.sin(a) * v - (kind === "coin" ? 260 * power : 80));
    }
    this.start();
  }

  fountain(n = 40, power = 1) {
    for (let i = 0; i < n; i++) {
      const x = this.w * (0.2 + Math.random() * 0.6);
      this.add("coin", x, this.h + 20, (Math.random() - 0.5) * 520, -(520 + Math.random() * 520) * power, Math.random() * 0.9);
    }
    this.start();
  }

  // Continuous rain from the top for `seconds`.
  rain(kind, perSecond, seconds) {
    this.rains.push({ kind, perSecond: this.reduced ? perSecond / 6 : perSecond, until: performance.now() + seconds * 1000, acc: 0 });
    this.start();
  }

  stopRain() { this.rains = []; }

  add(kind, x, y, vx, vy, delay = 0) {
    const base = { kind, x, y, vx, vy, delay, age: 0, rot: Math.random() * TAU, vr: (Math.random() - 0.5) * 12 };
    if (kind === "coin") Object.assign(base, { size: 9 + Math.random() * 9, life: 2.6, g: 900, flip: Math.random() * TAU });
    else if (kind === "feather") Object.assign(base, { size: 12 + Math.random() * 12, life: 4.5, g: 60, sway: Math.random() * TAU, hue: 270 + Math.random() * 50 });
    else if (kind === "star") Object.assign(base, { size: 6 + Math.random() * 8, life: 1.3, g: 120, hue: 40 + Math.random() * 280 });
    else Object.assign(base, { size: 2 + Math.random() * 3, life: 0.6 + Math.random() * 0.5, g: 500, hue: 35 + Math.random() * 25 });
    this.parts.push(base);
    if (this.parts.length > 700) this.parts.splice(0, this.parts.length - 700);
  }

  start() {
    if (this.frame) return;
    this.last = performance.now();
    this.frame = requestAnimationFrame(this.tick);
  }

  tick(now) {
    const dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    for (const r of this.rains) {
      r.acc += r.perSecond * dt;
      while (r.acc >= 1) {
        r.acc -= 1;
        this.add(r.kind, Math.random() * this.w, -20, (Math.random() - 0.5) * 80, r.kind === "coin" ? 80 + Math.random() * 160 : 20 + Math.random() * 40);
      }
    }
    this.rains = this.rains.filter((r) => r.until > now);
    const c = this.ctx;
    c.clearRect(0, 0, this.w, this.h);
    for (const p of this.parts) {
      if (p.delay > 0) { p.delay -= dt; continue; }
      p.age += dt;
      p.vy += p.g * dt;
      if (p.kind === "feather") { p.sway += dt * 3; p.vx = Math.sin(p.sway) * 60; p.vy = Math.min(p.vy, 70); }
      p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
      const fade = Math.max(0, 1 - Math.max(0, p.age - p.life * 0.7) / (p.life * 0.3));
      c.save();
      c.globalAlpha = fade;
      c.translate(p.x, p.y);
      if (p.kind === "coin") this.drawCoin(c, p, now);
      else if (p.kind === "feather") this.drawFeather(c, p);
      else if (p.kind === "star") this.drawStar(c, p);
      else { c.globalCompositeOperation = "lighter"; c.fillStyle = `hsl(${p.hue} 100% 70%)`; c.beginPath(); c.arc(0, 0, p.size, 0, TAU); c.fill(); }
      c.restore();
    }
    this.parts = this.parts.filter((p) => p.age < p.life && p.y < this.h + 80);
    if (this.parts.length || this.rains.length) this.frame = requestAnimationFrame(this.tick);
    else { this.frame = 0; c.clearRect(0, 0, this.w, this.h); }
  }

  drawCoin(c, p, now) {
    const squash = Math.abs(Math.cos(p.flip + now / 120));
    c.rotate(p.rot * 0.2);
    c.scale(Math.max(0.12, squash), 1);
    const g = c.createRadialGradient(-p.size * 0.3, -p.size * 0.3, 1, 0, 0, p.size);
    g.addColorStop(0, "#fff8d8"); g.addColorStop(0.4, "#ffd34a"); g.addColorStop(1, "#b8740a");
    c.fillStyle = g;
    c.beginPath(); c.arc(0, 0, p.size, 0, TAU); c.fill();
    c.strokeStyle = "#8a5200"; c.lineWidth = 1.5; c.stroke();
    c.strokeStyle = "#fff6"; c.beginPath(); c.arc(0, 0, p.size * 0.65, 0, TAU); c.stroke();
  }

  drawFeather(c, p) {
    c.rotate(p.rot * 0.3);
    const s = p.size;
    c.fillStyle = `hsl(${p.hue} 90% 72%)`;
    c.beginPath();
    c.moveTo(0, -s); c.quadraticCurveTo(s * 0.55, 0, 0, s); c.quadraticCurveTo(-s * 0.55, 0, 0, -s);
    c.fill();
    c.strokeStyle = "#fff9"; c.lineWidth = 1.2;
    c.beginPath(); c.moveTo(0, -s); c.lineTo(0, s * 1.2); c.stroke();
  }

  drawStar(c, p) {
    c.rotate(p.rot);
    c.globalCompositeOperation = "lighter";
    c.fillStyle = `hsl(${p.hue} 100% 75%)`;
    const s = p.size;
    c.beginPath();
    for (let i = 0; i < 8; i++) {
      const r = i % 2 ? s * 0.3 : s;
      c.lineTo(Math.cos((i / 8) * TAU) * r, Math.sin((i / 8) * TAU) * r);
    }
    c.closePath(); c.fill();
  }

  dispose() {
    cancelAnimationFrame(this.frame);
    this.ro?.disconnect();
    this.parts = []; this.rains = [];
  }
}
