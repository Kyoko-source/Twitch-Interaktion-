// Deterministic 2D pinball physics. Table units: x 0..10 left to right, y 0..20 top to bottom,
// gravity pulls toward +y. Everything is swept with small fixed sub-steps, so a 45 u/s ball
// never moves more than a fraction of its radius per step and cannot tunnel through rails.

export const BALL_R = 0.24;
export const SUBSTEP = 1 / 960;
export const MAX_SPEED = 46;

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

export function closestOnSegment(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy || 1e-9;
  const t = clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0, 1);
  return { x: ax + dx * t, y: ay + dy * t, t };
}

function segmentsCross(p, q, a, b) {
  const d = (q.x - p.x) * (b.y - a.y) - (q.y - p.y) * (b.x - a.x);
  if (Math.abs(d) < 1e-12) return false;
  const t = ((a.x - p.x) * (b.y - a.y) - (a.y - p.y) * (b.x - a.x)) / d;
  const u = ((a.x - p.x) * (q.y - p.y) - (a.y - p.y) * (q.x - p.x)) / d;
  return t >= 0 && t <= 1 && u >= 0 && u <= 1;
}

export class World {
  constructor() {
    this.gravity = 25;
    this.balls = [];
    this.segs = [];
    this.circles = [];
    this.flippers = [];
    this.sensors = [];
    this.zones = [];
    this.time = 0;
    this.listeners = {};
    this.nextBallId = 1;
    this.random = Math.random;
  }

  on(type, fn) { (this.listeners[type] ||= []).push(fn); }
  emit(type, ...args) { for (const fn of this.listeners[type] || []) fn(...args); }

  seg(a, b, opts = {}) {
    const s = { a: { x: a[0], y: a[1] }, b: { x: b[0], y: b[1] }, r: 0.06, e: 0.42, f: 0.08, enabled: true, kind: "rail", ...opts };
    this.segs.push(s);
    return s;
  }
  // A polyline of rails; returns the created segments.
  path(points, opts = {}) {
    const out = [];
    for (let i = 1; i < points.length; i++) out.push(this.seg(points[i - 1], points[i], opts));
    return out;
  }
  arc(cx, cy, radius, from, to, steps, opts = {}) {
    const pts = [];
    for (let i = 0; i <= steps; i++) {
      const a = from + ((to - from) * i) / steps;
      pts.push([cx + Math.cos(a) * radius, cy + Math.sin(a) * radius]);
    }
    return this.path(pts, opts);
  }
  circle(x, y, r, opts = {}) {
    const c = { x, y, r, e: 0.5, f: 0.05, enabled: true, kind: "post", ...opts };
    this.circles.push(c);
    return c;
  }
  flipper(px, py, len, side, opts = {}) {
    // side 1 = left flipper (points right), -1 = right flipper (points left).
    const rest = side === 1 ? 0.52 : Math.PI - 0.52;
    const up = side === 1 ? -0.5 : Math.PI + 0.5;
    const f = { px, py, len, side, rest, up, angle: rest, omega: 0, pressed: false, r0: 0.25, r1: 0.12, e: 0.38, upSpeed: 26, downSpeed: 17, enabled: true, kind: "flipper", ...opts };
    this.flippers.push(f);
    return f;
  }
  lineSensor(a, b, opts = {}) {
    const s = { type: "line", a: { x: a[0], y: a[1] }, b: { x: b[0], y: b[1] }, enabled: true, ...opts };
    this.sensors.push(s);
    return s;
  }
  circleSensor(x, y, r, opts = {}) {
    const s = { type: "circle", x, y, r, enabled: true, inside: new Set(), ...opts };
    this.sensors.push(s);
    return s;
  }
  // Rectangular area with extra downhill gravity (ramps) – x0,y0,x1,y1.
  zone(x0, y0, x1, y1, extra, opts = {}) {
    const z = { x0, y0, x1, y1, extra, ...opts };
    this.zones.push(z);
    return z;
  }

  addBall(x, y, vx = 0, vy = 0) {
    const b = { id: this.nextBallId++, x, y, vx, vy, px: x, py: y, held: false, rail: null, spin: 0, lastMove: this.time, anchorX: x, anchorY: y, height: 0, hitCooldown: new Map() };
    this.balls.push(b);
    return b;
  }
  removeBall(b) { this.balls = this.balls.filter((o) => o !== b); for (const s of this.sensors) s.inside?.delete(b.id); }

  flipperTip(f) { return { x: f.px + Math.cos(f.angle) * f.len, y: f.py + Math.sin(f.angle) * f.len }; }

  stepFlippers(dt) {
    for (const f of this.flippers) {
      const target = f.pressed && f.enabled ? f.up : f.rest;
      const diff = target - f.angle;
      if (Math.abs(diff) < 1e-6) { f.omega = 0; continue; }
      const speed = f.pressed && f.enabled ? f.upSpeed : f.downSpeed;
      const step = Math.sign(diff) * Math.min(Math.abs(diff), speed * dt);
      f.angle += step;
      f.omega = step / dt;
    }
  }

  step(dt) {
    this.time += dt;
    this.stepFlippers(dt);
    for (const b of this.balls) {
      if (b.held || b.rail) continue;
      b.px = b.x; b.py = b.y;
      let g = this.gravity;
      for (const z of this.zones) if (b.x > z.x0 && b.x < z.x1 && b.y > z.y0 && b.y < z.y1) g += z.extra;
      b.vy += g * dt;
      const sp = Math.hypot(b.vx, b.vy);
      if (sp > MAX_SPEED) { b.vx *= MAX_SPEED / sp; b.vy *= MAX_SPEED / sp; }
      b.vx *= 1 - 0.06 * dt; b.vy *= 1 - 0.06 * dt; // rolling resistance
      b.x += b.vx * dt; b.y += b.vy * dt;
      for (let pass = 0; pass < 2; pass++) {
        for (const s of this.segs) if (s.enabled) this.collideSeg(b, s);
        for (const c of this.circles) if (c.enabled) this.collideCircle(b, c);
        for (const f of this.flippers) this.collideFlipper(b, f);
      }
      this.checkSensors(b);
    }
    this.collideBalls();
  }

  resolve(b, nx, ny, depth, sx, sy, e, fr, item) {
    b.x += nx * depth; b.y += ny * depth;
    const rvx = b.vx - sx, rvy = b.vy - sy;
    const vn = rvx * nx + rvy * ny;
    if (vn >= 0) return 0;
    const rest = -vn < 0.9 ? 0 : e; // no micro-bounces while rolling along a rail
    const j = -(1 + rest) * vn;
    b.vx += j * nx; b.vy += j * ny;
    // Coulomb-style tangential friction.
    const tvx = rvx - vn * nx, tvy = rvy - vn * ny;
    const tl = Math.hypot(tvx, tvy);
    if (tl > 1e-6) {
      const drop = Math.min(tl, fr * j);
      b.vx -= (tvx / tl) * drop; b.vy -= (tvy / tl) * drop;
    }
    if (item && -vn > 0.25) this.emit("hit", b, item, -vn, nx, ny);
    return -vn;
  }

  collideSeg(b, s) {
    if (s.layer !== undefined && s.layer !== (b.layer || 0)) return;
    const c = closestOnSegment(b.x, b.y, s.a.x, s.a.y, s.b.x, s.b.y);
    let dx = b.x - c.x, dy = b.y - c.y;
    const d = Math.hypot(dx, dy), min = BALL_R + s.r;
    if (d >= min) return;
    if (s.oneWay) {
      // Only blocks a ball that sits on (and moves into) the solid side of the gate.
      const side = (b.px - s.a.x) * s.oneWay.x + (b.py - s.a.y) * s.oneWay.y;
      if (side < 0) return;
    }
    let nx, ny;
    if (d > 1e-6) { nx = dx / d; ny = dy / d; } else { nx = -(s.b.y - s.a.y); ny = s.b.x - s.a.x; const l = Math.hypot(nx, ny); nx /= l; ny /= l; }
    const impact = this.resolve(b, nx, ny, min - d, 0, 0, s.e, s.f, s);
    if (s.kick && impact > s.kickMin) {
      // Slingshot / kicker: drive the ball away along the face normal.
      const base = s.kickNormal || { x: nx, y: ny };
      if (base.x * nx + base.y * ny > 0.3) {
        // Real slingshots never fire identically: jitter strength and angle a little so
        // the ball cannot settle into an endless sling-to-sling ping-pong.
        const jitter = (this.random() - 0.5) * 0.3, cs = Math.cos(jitter), sn = Math.sin(jitter);
        const kn = { x: base.x * cs - base.y * sn, y: base.x * sn + base.y * cs };
        const kick = s.kick * (0.85 + this.random() * 0.3);
        const vn = b.vx * kn.x + b.vy * kn.y;
        if (vn < kick) { b.vx += kn.x * (kick - vn); b.vy += kn.y * (kick - vn); }
        this.emit("kick", b, s);
      }
    }
  }

  collideCircle(b, c) {
    let dx = b.x - c.x, dy = b.y - c.y;
    const d = Math.hypot(dx, dy), min = BALL_R + c.r;
    if (d >= min) return;
    const nx = d > 1e-6 ? dx / d : 0, ny = d > 1e-6 ? dy / d : -1;
    const impact = this.resolve(b, nx, ny, min - d, 0, 0, c.e, c.f, c);
    if (c.kick && impact > (c.kickMin ?? 0.4)) {
      const vn = b.vx * nx + b.vy * ny;
      const kick = c.kick * (0.9 + this.random() * 0.2);
      if (vn < kick) { b.vx += nx * (kick - vn); b.vy += ny * (kick - vn); }
      this.emit("kick", b, c);
    }
  }

  collideFlipper(b, f) {
    const tip = this.flipperTip(f);
    const c = closestOnSegment(b.x, b.y, f.px, f.py, tip.x, tip.y);
    const r = f.r0 + (f.r1 - f.r0) * c.t;
    let dx = b.x - c.x, dy = b.y - c.y;
    const d = Math.hypot(dx, dy), min = BALL_R + r;
    if (d >= min) return;
    const nx = d > 1e-6 ? dx / d : 0, ny = d > 1e-6 ? dy / d : -1;
    // Surface velocity of the rotating bat at the contact point.
    const cx = c.x + nx * r, cy = c.y + ny * r;
    const sx = -f.omega * (cy - f.py), sy = f.omega * (cx - f.px);
    this.resolve(b, nx, ny, min - d, sx, sy, f.e, 0.12, f);
  }

  checkSensors(b) {
    const p = { x: b.px, y: b.py }, q = { x: b.x, y: b.y };
    for (const s of this.sensors) {
      if (!s.enabled) continue;
      if (s.type === "line") {
        if (segmentsCross(p, q, s.a, s.b)) {
          // dir > 0 when crossing toward the left-hand normal of a->b.
          const nx = -(s.b.y - s.a.y), ny = s.b.x - s.a.x;
          const dir = Math.sign((q.x - p.x) * nx + (q.y - p.y) * ny);
          this.emit("sensor", b, s, dir, Math.hypot(b.vx, b.vy));
        }
      } else {
        const inside = Math.hypot(b.x - s.x, b.y - s.y) < s.r;
        if (inside && !s.inside.has(b.id)) { s.inside.add(b.id); this.emit("sensor", b, s, 1, Math.hypot(b.vx, b.vy)); }
        else if (!inside && s.inside.has(b.id)) { s.inside.delete(b.id); this.emit("sensorExit", b, s); }
      }
    }
  }

  collideBalls() {
    const list = this.balls.filter((b) => !b.held && !b.rail);
    for (let i = 0; i < list.length; i++)
      for (let k = i + 1; k < list.length; k++) {
        const a = list[i], c = list[k];
        const dx = c.x - a.x, dy = c.y - a.y, d = Math.hypot(dx, dy);
        if (d >= BALL_R * 2 || d < 1e-6) continue;
        const nx = dx / d, ny = dy / d, push = (BALL_R * 2 - d) / 2;
        a.x -= nx * push; a.y -= ny * push; c.x += nx * push; c.y += ny * push;
        const rel = (c.vx - a.vx) * nx + (c.vy - a.vy) * ny;
        if (rel < 0) {
          const j = -rel * 0.95;
          a.vx -= j * nx; a.vy -= j * ny; c.vx += j * nx; c.vy += j * ny;
          if (-rel > 1) this.emit("ballClick", a, -rel);
        }
      }
  }
}
