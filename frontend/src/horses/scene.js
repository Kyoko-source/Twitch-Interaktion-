// Chicken Derby race course on a 2D canvas: a floodlit oval with nine lanes in a slight
// top-down perspective, grandstands full of fans, a starting gate, a finish post and a TV-style
// camera that follows the pack. The race itself comes from race.mjs; this file only shows it.
import { LOOKS, drawHorse } from "./horse.js";
import { Commentator, lapsAt, raceEnd, speedAt, standings } from "./race.mjs";

const TAU = Math.PI * 2;
export const WORLD_W = 1600, WORLD_H = 900;
const CX = 800, CY = 468;
const L = 760;                 // straight length
const R0 = 150, LW = 22, LANES = 9;
const RM = R0 + 4.5 * LW;      // reference radius for distances
const FX = L / 2 - 120;        // finish line on the home straight
const SEG = [L / 2 - FX, Math.PI * RM, L, Math.PI * RM, L / 2 + FX];
const LAP = SEG.reduce((a, b) => a + b, 0);
const OUTER = R0 + LANES * LW;
const COUNTDOWN = 10;

const laneR = (lane) => R0 + (lane + 0.5) * LW;

// Ground point on the oval at radius r and distance s from the finish line. dir = screen-x heading.
export function trackPoint(r, s) {
  s = ((s % LAP) + LAP) % LAP;
  if (s < SEG[0]) return { X: FX + s, Z: r, dir: 1 };
  s -= SEG[0];
  if (s < SEG[1]) { const th = Math.PI / 2 - Math.PI * (s / SEG[1]); return { X: L / 2 + r * Math.cos(th), Z: r * Math.sin(th), dir: Math.sin(th) }; }
  s -= SEG[1];
  if (s < SEG[2]) return { X: L / 2 - s, Z: -r, dir: -1 };
  s -= SEG[2];
  if (s < SEG[3]) { const th = -Math.PI / 2 - Math.PI * (s / SEG[3]); return { X: -L / 2 + r * Math.cos(th), Z: r * Math.sin(th), dir: Math.sin(th) }; }
  s -= SEG[3];
  return { X: -L / 2 + s, Z: r, dir: 1 };
}

export function project(X, Z) { return { x: CX + X * (1 + Z * 0.00022), y: CY + Z * 0.5 }; }
const depthScale = (Z) => 0.5 + 0.2 * ((Z + OUTER) / (2 * OUTER));

function ovalPath(c, r) {
  for (let i = 0; i <= 200; i++) {
    const p = trackPoint(r, (i / 200) * LAP), q = project(p.X, p.Z);
    if (i) c.lineTo(q.x, q.y); else c.moveTo(q.x, q.y);
  }
  c.closePath();
}

function rng(seed) { return () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }; }
const FAN_COLORS = ["#ef4444", "#f59e0b", "#facc15", "#22c55e", "#06b6d4", "#3b82f6", "#a855f7", "#ec4899", "#f8fafc", "#fb923c", "#14b8a6"];
const SKIN = ["#f1c9a5", "#e0ac83", "#c68a5c", "#8d5a3b", "#ffdbbd"];

export class DerbyScene {
  constructor(canvas, { audio, names, onEvent, onHud }) {
    Object.assign(this, { canvas, audio, names, onEvent, onHud });
    this.ctx = canvas.getContext("2d");
    this.phase = "lobby";
    this.chosen = -1;
    this.race = null;
    this.t = -COUNTDOWN;
    this.time = 0;
    this.cam = { x: CX, y: WORLD_H / 2, z: 1 };
    this.horses = LOOKS.map((look, i) => ({ look, i, phase: Math.random(), facing: 1, gait: 0, x: 0, y: 0, z: 0 }));
    this.dust = [];
    this.flashes = [];
    this.flash = 0;
    this.freeze = 0;
    this.excite = 0.1;
    this.gateOut = 0;
    this.gateOpen = 0;
    this.lastCount = COUNTDOWN + 1;
    this.hudAt = 0;
    this.reduced = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
    const r = rng(42);
    this.jumpers = Array.from({ length: 140 }, () => ({ x: 70 + r() * 1460, row: Math.floor(r() * 4), back: r() < 0.35, col: FAN_COLORS[Math.floor(r() * FAN_COLORS.length)], skin: SKIN[Math.floor(r() * SKIN.length)], ph: r() * TAU, flag: r() < 0.25 }));
    this.resize = this.resize.bind(this);
    this.frame = this.frame.bind(this);
    this.resize();
    if (typeof ResizeObserver === "function") { this.ro = new ResizeObserver(this.resize); this.ro.observe(canvas); }
    this.buildStatic();
    document.fonts?.ready?.then(() => { if (!this.dead) this.buildStatic(); });
    this.last = performance.now();
    this.raf = requestAnimationFrame(this.frame);
  }

  dispose() { this.dead = true; cancelAnimationFrame(this.raf); this.ro?.disconnect(); }

  resize() {
    const r = this.canvas.getBoundingClientRect();
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    this.cw = Math.max(1, Math.round(r.width * dpr));
    this.ch = Math.max(1, Math.round(r.height * dpr));
    this.canvas.width = this.cw; this.canvas.height = this.ch;
    this.narrow = r.width < 640;
  }

  setChosen(h) { this.chosen = h; }

  // `at` seeks into the timeline (race seconds, countdown is negative) so a viewer who joins
  // late, like the stream overlay, sees the same moment as the player.
  start(race, chosen, at = -COUNTDOWN) {
    this.race = race; this.chosen = chosen;
    this.t = Math.max(-COUNTDOWN, at);
    this.phase = this.t < 0 ? "countdown" : "race";
    this.lastCount = this.t < 0 ? Math.ceil(-this.t) + 1 : 0;
    this.commentator = new Commentator(race, chosen, this.names);
    this.gateOut = this.t > 3.2 ? 1 : 0; this.gateOpen = this.t > 0 ? 1 : 0;
    this.freeze = 0; this.flash = 0; this.doneSent = false;
    this.crossed = this.t >= race.finish[race.winner];
    for (let t = 0; t < this.t; t += 0.1) this.commentator.update(t);   // silently catch up
    this.dust = [];
    for (const h of this.horses) { h.gait = this.t > 0 ? 1 : 0; h.phase = Math.random(); }
    if (this.t < -COUNTDOWN + 1) this.audio?.fanfare();
  }

  reset() { this.phase = "lobby"; this.race = null; this.t = -COUNTDOWN; this.gateOut = 0; this.gateOpen = 0; this.excite = 0.1; }

  // ---------------------------------------------------------------- static layer
  buildStatic() {
    const q = 2;
    const can = this.staticCanvas || document.createElement("canvas");
    can.width = WORLD_W * q; can.height = WORLD_H * q;
    const c = can.getContext("2d");
    c.setTransform(q, 0, 0, q, 0, 0);
    const r = rng(7);

    // Night sky with a warm glow over the stands.
    const sky = c.createLinearGradient(0, 0, 0, 280);
    sky.addColorStop(0, "#0b1030"); sky.addColorStop(0.55, "#2b1850"); sky.addColorStop(1, "#7a3a5c");
    c.fillStyle = sky; c.fillRect(0, 0, WORLD_W, 300);
    for (let i = 0; i < 120; i++) { c.fillStyle = `rgba(255,255,255,${0.2 + r() * 0.6})`; c.fillRect(r() * WORLD_W, r() * 140, 1.4, 1.4); }

    // Back grandstand
    c.fillStyle = "#151827"; c.fillRect(90, 118, 1420, 30);
    c.fillStyle = "#262a40";
    c.beginPath(); c.moveTo(70, 150); c.lineTo(1530, 150); c.lineTo(1510, 262); c.lineTo(90, 262); c.closePath(); c.fill();
    for (let row = 0; row < 7; row++) {
      const y = 160 + row * 14;
      c.fillStyle = row % 2 ? "#2e3350" : "#343a5c"; c.fillRect(92, y + 6, 1416, 8);
      for (let x = 100 + (row % 2) * 5; x < 1500; x += 10) {
        if (r() < 0.12) continue;
        c.fillStyle = FAN_COLORS[Math.floor(r() * FAN_COLORS.length)]; c.fillRect(x - 3.5, y + 3, 7, 7);
        c.fillStyle = SKIN[Math.floor(r() * SKIN.length)]; c.beginPath(); c.arc(x, y + 1, 3, 0, TAU); c.fill();
      }
    }
    // Roof lights
    for (let x = 110; x < 1500; x += 46) { c.fillStyle = "#fff6d0"; c.fillRect(x, 140, 18, 4); }
    // Facade with the course name
    c.fillStyle = "#0f3d2b"; c.fillRect(80, 258, 1440, 22);
    c.fillStyle = "#f7d774"; c.font = "800 15px 'Space Grotesk', Inter, sans-serif"; c.textAlign = "center"; c.textBaseline = "middle";
    c.fillText("AVIARY DOWNS  ·  CHICKEN DERBY  ·  AVIARY DOWNS  ·  CHICKEN DERBY  ·  AVIARY DOWNS", 800, 270);

    // Floodlight masts
    for (const x of [46, 1554]) {
      c.fillStyle = "#3a3f55"; c.fillRect(x - 4, 40, 8, 250);
      c.fillStyle = "#20243a"; c.fillRect(x - 30, 22, 60, 30);
      for (let i = 0; i < 8; i++) { c.fillStyle = "#fffbe6"; c.fillRect(x - 27 + (i % 4) * 14, 25 + Math.floor(i / 4) * 14, 11, 11); }
      const glow = c.createRadialGradient(x, 37, 4, x, 37, 140);
      glow.addColorStop(0, "rgba(255,250,220,0.75)"); glow.addColorStop(1, "rgba(255,250,220,0)");
      c.fillStyle = glow; c.fillRect(x - 140, -100, 280, 280);
    }

    // Grass apron
    const grass = c.createLinearGradient(0, 280, 0, 700);
    grass.addColorStop(0, "#1f5a2c"); grass.addColorStop(1, "#2f7a38");
    c.fillStyle = grass; c.fillRect(0, 280, WORLD_W, 420);

    // Dirt track with texture
    c.save();
    c.beginPath(); ovalPath(c, OUTER + 10); ovalPath(c, R0 - 10);
    const dirt = c.createLinearGradient(0, 280, 0, 680);
    dirt.addColorStop(0, "#a8723f"); dirt.addColorStop(1, "#c98d52");
    c.fillStyle = dirt; c.fill("evenodd");
    c.clip("evenodd");
    for (let i = 0; i < 9000; i++) { c.fillStyle = r() < 0.5 ? "rgba(90,52,22,0.22)" : "rgba(255,220,170,0.16)"; c.fillRect(r() * WORLD_W, 280 + r() * 420, 2, 1.2); }
    // Hoof-worn racing line
    c.strokeStyle = "rgba(110,64,28,0.25)"; c.lineWidth = 30;
    c.beginPath(); ovalPath(c, R0 + 2.5 * LW); c.stroke();
    c.restore();
    // Lane lines
    c.strokeStyle = "rgba(255,248,230,0.28)"; c.lineWidth = 1;
    for (let k = 1; k < LANES; k++) { c.beginPath(); ovalPath(c, R0 + k * LW); c.stroke(); }

    // Infield: striped lawn, pond, flower letters
    c.save();
    c.beginPath(); ovalPath(c, R0 - 12); c.clip();
    c.fillStyle = "#2f8a3d"; c.fillRect(0, 300, WORLD_W, 400);
    for (let x = 0; x < WORLD_W; x += 40) { c.fillStyle = "rgba(255,255,255,0.05)"; c.fillRect(x, 300, 20, 400); }
    const pond = c.createRadialGradient(560, 470, 4, 560, 470, 90);
    pond.addColorStop(0, "#4cc3e6"); pond.addColorStop(1, "#1b6e93");
    c.fillStyle = pond; c.beginPath(); c.ellipse(560, 472, 92, 26, 0, 0, TAU); c.fill();
    c.strokeStyle = "rgba(255,255,255,0.35)"; c.lineWidth = 1.5;
    c.beginPath(); c.ellipse(560, 472, 60, 14, 0, 0, TAU); c.stroke();
    for (let i = 0; i < 160; i++) { const a = r() * TAU, d = 30 + r() * 20; c.fillStyle = FAN_COLORS[i % 9]; c.beginPath(); c.arc(1190 + Math.cos(a) * d * 1.6, 472 + Math.sin(a) * d * 0.5, 2.2, 0, TAU); c.fill(); }
    c.fillStyle = "#1f6f2e"; c.beginPath(); c.ellipse(1190, 472, 24, 8, 0, 0, TAU); c.fill();
    c.restore();

    // Inner rail (front half; the back half is drawn over the horses)
    this.rail(c, R0 - 6, 0, LAP, (z) => z > 0, 7);
    // Outer rail back half
    this.rail(c, OUTER + 6, 0, LAP, (z) => z < 0, 8);

    // Finish line chequers across the home straight
    for (let k = 0; k < 20; k++) {
      for (let j = 0; j < 2; j++) {
        const z0 = R0 - 6 + ((OUTER - R0 + 12) * k) / 20, z1 = R0 - 6 + ((OUTER - R0 + 12) * (k + 1)) / 20;
        const a = project(FX + j * 5, z0), b = project(FX + j * 5 + 5, z0), cc = project(FX + j * 5 + 5, z1), d = project(FX + j * 5, z1);
        c.fillStyle = (k + j) % 2 ? "#111" : "#fafafa";
        c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(b.x, b.y); c.lineTo(cc.x, cc.y); c.lineTo(d.x, d.y); c.closePath(); c.fill();
      }
    }

    // Front grandstand
    c.fillStyle = "#1a1d30"; c.fillRect(0, 700, WORLD_W, 200);
    c.fillStyle = "#0f3d2b"; c.fillRect(0, 692, WORLD_W, 20);
    const boards = ["GACKER-BRÄU", "EIERLIKÖR DELUXE", "KORNKAMMER", "FEDERLEICHT", "HÜHNERHOF FM", "GOLDEI-BANK"];
    c.font = "800 12px 'Space Grotesk', Inter, sans-serif";
    for (let i = 0; i < 12; i++) { c.fillStyle = i % 2 ? "#f7d774" : "#ffffff"; c.fillText(boards[i % boards.length], 66 + i * 134, 703); }
    for (let row = 0; row < 8; row++) {
      const y = 726 + row * 22, size = 5 + row * 0.6;
      c.fillStyle = row % 2 ? "#23273f" : "#2a2f4b"; c.fillRect(0, y + size, WORLD_W, 10);
      for (let x = 8 + (row % 2) * 8; x < WORLD_W; x += 16 + row) {
        if (r() < 0.1) continue;
        c.fillStyle = FAN_COLORS[Math.floor(r() * FAN_COLORS.length)];
        c.beginPath(); c.ellipse(x, y + size * 1.7, size * 1.2, size * 1.1, 0, Math.PI, TAU); c.fill();
        c.fillRect(x - size * 1.2, y + size * 1.7, size * 2.4, size);
        c.fillStyle = SKIN[Math.floor(r() * SKIN.length)]; c.beginPath(); c.arc(x, y + size * 0.4, size * 0.85, 0, TAU); c.fill();
      }
    }
    this.staticCanvas = can;
  }

  rail(c, r, from, to, keep, height) {
    c.strokeStyle = "#f4f4f0"; c.lineWidth = 2.4; c.lineCap = "round";
    let open = false;
    c.beginPath();
    for (let i = 0; i <= 240; i++) {
      const p = trackPoint(r, from + ((to - from) * i) / 240);
      if (!keep(p.Z)) { open = false; continue; }
      const q = project(p.X, p.Z);
      if (open) c.lineTo(q.x, q.y - height); else { c.moveTo(q.x, q.y - height); open = true; }
    }
    c.stroke();
    c.lineWidth = 1.4;
    for (let i = 0; i < 120; i++) {
      const p = trackPoint(r, from + ((to - from) * i) / 120);
      if (!keep(p.Z)) continue;
      const q = project(p.X, p.Z);
      c.beginPath(); c.moveTo(q.x, q.y); c.lineTo(q.x, q.y - height); c.stroke();
    }
  }

  // ---------------------------------------------------------------- loop
  frame(now) {
    if (this.dead) return;
    this.raf = requestAnimationFrame(this.frame);
    let dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    if (this.paused) return;   // hidden overlay: no work, no sound
    this.time += dt;
    this.update(dt);
    this.draw();
  }

  timeScale() {
    const race = this.race;
    if (!race || this.phase !== "race") return 1;
    if (this.freeze > 0) return 0;
    const tw = race.finish[race.winner];
    const close = race.finish[race.order[1]] - tw < 0.45;
    if (!this.reduced && close && this.t > tw - 1.1 && this.t < tw + 0.15) return 0.32;
    return 1;
  }

  update(dt) {
    const race = this.race;
    if (this.freeze > 0) this.freeze -= dt;
    this.flash = Math.max(0, this.flash - dt * 2.2);
    if (this.phase === "countdown" || this.phase === "race" || this.phase === "done") {
      const scale = this.timeScale();
      this.t += dt * scale;
      if (this.phase === "countdown") {
        const n = Math.ceil(-this.t);
        if (n < this.lastCount && n >= 1) { this.lastCount = n; this.onEvent?.({ type: "count", n }); this.audio?.count(n); }
        if (this.t >= 0) {
          this.phase = "race";
          this.onEvent?.({ type: "go" });
          this.audio?.go();
          this.flash = 0.5;
        }
      }
      if (this.t >= 0) {
        this.gateOpen = Math.min(1, this.gateOpen + dt * 5);
        if (this.t > 1.2) this.gateOut = Math.min(1, this.gateOut + dt * 0.5);
      }
      if (this.phase !== "countdown" && this.commentator) {
        for (const call of this.commentator.update(this.t)) { this.onEvent?.({ type: "call", ...call }); this.audio?.call(call); }
      }
      if (race && !this.crossed && this.t >= race.finish[race.winner]) {
        this.crossed = true;
        const photo = race.finish[race.order[1]] - race.finish[race.winner] < 0.2;
        if (photo && !this.reduced) { this.freeze = 0.55; this.flash = 1; }
        else this.flash = 0.6;
        for (let i = 0; i < 26; i++) this.flashes.push({ x: Math.random() * WORLD_W, y: 700 + Math.random() * 190, life: 0.3 + Math.random() * 1.6 });
        this.onEvent?.({ type: "cross", winner: race.winner, photo });
      }
      if (race && this.phase === "race" && this.t > raceEnd(race) + 1.4 && !this.doneSent) {
        this.doneSent = true; this.phase = "done";
        this.onEvent?.({ type: "done" });
      }
    }

    // Horses
    const raceT = Math.max(0, this.t);
    const running = race && this.t > 0;
    let near = 0;
    for (const h of this.horses) {
      let s = 0, speed = 0;
      if (race) {
        s = lapsAt(race, h.i, raceT) * LAP;
        speed = speedAt(race, h.i, raceT);
      }
      const p = trackPoint(laneR(h.i), s - 18);
      const q = project(p.X, p.Z);
      h.x = q.x; h.y = q.y; h.z = p.Z; h.s = s;
      h.facing += (p.dir - h.facing) * Math.min(1, dt * 10);
      const targetGait = running ? Math.min(1, 0.35 + speed / 0.07 * 0.65) : this.phase === "countdown" ? 0.12 : 0;
      h.gait += (targetGait - h.gait) * Math.min(1, dt * (running ? 6 : 3));
      const stride = running ? 2.2 * Math.max(0.35, speed / 0.072) : this.phase === "countdown" ? 1.4 : 0.5;
      h.phase = (h.phase + dt * stride * (this.freeze > 0 ? 0 : this.timeScale())) % 1;
      if (running && speed > 0.03 && Math.random() < dt * 22 * this.timeScale()) {
        const sc = depthScale(p.Z);
        this.dust.push({ x: h.x - Math.sign(h.facing || 1) * 30 * sc, y: h.y - 2, vx: -Math.sign(h.facing || 1) * (20 + Math.random() * 30), vy: -8 - Math.random() * 12, r: 3 * sc, life: 0, max: 0.6 + Math.random() * 0.5 });
      }
      if (running) near += Math.min(1, speed / 0.07);
    }
    this.dust = this.dust.filter((d) => { const k = dt * this.timeScale(); d.life += k; d.x += d.vx * k; d.y += d.vy * k; d.vy += 10 * k; d.r += 14 * k; return d.life < d.max; });
    if (this.dust.length > 260) this.dust.splice(0, this.dust.length - 260);
    this.flashes = this.flashes.filter((f) => (f.life -= dt) > 0);

    // Crowd excitement follows the action.
    let target = this.phase === "lobby" ? 0.12 : this.phase === "countdown" ? 0.25 + 0.3 * (1 - Math.max(0, -this.t) / COUNTDOWN) : 0.5;
    if (race && this.phase !== "lobby" && this.t > 0) {
      const lead = lapsAt(race, standings(race, raceT)[0], raceT);
      target = 0.45 + 0.4 * Math.max(0, (lead - (race.laps - 1)) / 1) + (this.t > race.finish[race.winner] ? 0.3 : 0);
      if (this.phase === "done") target = 0.35;
    }
    this.excite += (Math.min(1, target) - this.excite) * Math.min(1, dt * 1.5);
    this.audio?.setCrowd(this.excite);
    this.audio?.hooves(dt * this.timeScale(), running ? Math.min(1, near / 9) * (this.cam.z > 1.3 ? 1 : 0.7) : 0);

    this.updateCamera(dt);

    if (this.onHud && this.time - this.hudAt > 0.12) {
      this.hudAt = this.time;
      if (race && this.t >= 0) {
        const order = standings(race, raceT);
        const lead = lapsAt(race, order[0], raceT);
        this.onHud({ order, lap: Math.min(race.laps, Math.floor(lead) + 1), myRank: order.indexOf(this.chosen) + 1, progress: Math.min(1, lead / race.laps) });
      }
    }
  }

  updateCamera(dt) {
    const race = this.race;
    let tx = CX, ty = WORLD_H / 2, tz = 1;
    const zoomRace = this.narrow ? 2.7 : 1.6;
    if (this.phase === "countdown") {
      const g = project(FX, R0 + LANES * LW / 2);
      const k = 1 - Math.max(0, -this.t) / COUNTDOWN;
      tx = g.x - 170 / ((this.narrow ? 2.6 : 1.7) + 0.5 * k); ty = g.y - 50; tz = (this.narrow ? 2.6 : 1.7) + 0.5 * k;
    } else if (race && (this.phase === "race" || this.phase === "done")) {
      const raceT = Math.max(0, this.t);
      const order = standings(race, raceT);
      const lead = this.horses[order[0]];
      let mx = 0, my = 0;
      for (const id of order.slice(0, 6)) { mx += this.horses[id].x; my += this.horses[id].y; }
      mx /= 6; my /= 6;
      tx = lead.x * 0.55 + mx * 0.45; ty = (lead.y * 0.55 + my * 0.45) - 40; tz = zoomRace;
      const lp = lapsAt(race, order[0], raceT);
      if (lp > race.laps - 0.22 && this.t < race.finish[race.winner] + 1.5) { tz = zoomRace + 0.35; const f = project(FX, R0 + LANES * LW / 2); tx = (tx + f.x) / 2; }
      if (this.t > race.finish[race.winner] + 1.5) { const f = project(FX, R0 + LANES * LW / 2); tx = f.x - 120; ty = f.y - 60; tz = this.narrow ? 2 : 1.3; }
    }
    const k = 1 - Math.exp(-dt * (this.phase === "race" ? 2.6 : 1.6));
    this.cam.x += (tx - this.cam.x) * k; this.cam.y += (ty - this.cam.y) * k; this.cam.z += (tz - this.cam.z) * k;
    const aspect = this.ch / this.cw;
    const viewW = WORLD_W / this.cam.z, viewH = (WORLD_W * aspect) / this.cam.z;
    this.cam.x = Math.max(viewW / 2, Math.min(WORLD_W - viewW / 2, this.cam.x));
    this.cam.y = Math.max(Math.min(WORLD_H / 2, viewH / 2), Math.min(WORLD_H - viewH / 2, this.cam.y));
  }

  // ---------------------------------------------------------------- draw
  draw() {
    const c = this.ctx;
    const k = (this.cw / WORLD_W) * this.cam.z;
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.fillStyle = "#0b1030"; c.fillRect(0, 0, this.cw, this.ch);
    c.setTransform(k, 0, 0, k, this.cw / 2 - this.cam.x * k, this.ch / 2 - this.cam.y * k);
    if (this.staticCanvas) c.drawImage(this.staticCanvas, 0, 0, WORLD_W, WORLD_H);

    this.drawCrowd(c, true);
    this.drawScreen(c);
    this.drawFinishPost(c);

    // Back half of the inner rail sits in front of the back-straight horses, so it is drawn
    // after them; everything with depth is sorted back to front.
    const items = [];
    for (const h of this.horses) items.push({ z: h.z, draw: () => this.drawHorse(c, h) });
    if (this.gateOut < 1) for (let lane = 0; lane < LANES; lane++) { items.push({ z: laneR(lane) - 0.5, draw: () => this.drawGateStall(c, lane, true) }); items.push({ z: laneR(lane) + 0.5, draw: () => this.drawGateStall(c, lane, false) }); }
    items.sort((a, b) => a.z - b.z);
    let railDone = false;
    for (const it of items) {
      if (!railDone && it.z > -R0 + 6) { this.rail(c, R0 - 6, 0, LAP, (z) => z <= 0, 7); railDone = true; }
      it.draw();
    }
    if (!railDone) this.rail(c, R0 - 6, 0, LAP, (z) => z <= 0, 7);
    for (const d of this.dust) {
      const a = 0.32 * (1 - d.life / d.max);
      c.fillStyle = `rgba(214,170,118,${a})`;
      c.beginPath(); c.arc(d.x, d.y, d.r, 0, TAU); c.fill();
    }
    this.rail(c, OUTER + 6, 0, LAP, (z) => z >= 0, 8);
    this.drawCrowd(c, false);
    for (const f of this.flashes) {
      if (Math.random() < 0.5) continue;
      const g = c.createRadialGradient(f.x, f.y, 0, f.x, f.y, 14);
      g.addColorStop(0, "rgba(255,255,255,0.95)"); g.addColorStop(1, "rgba(255,255,255,0)");
      c.fillStyle = g; c.fillRect(f.x - 14, f.y - 14, 28, 28);
    }

    c.setTransform(1, 0, 0, 1, 0, 0);
    // Broadcast vignette and flash
    const v = c.createRadialGradient(this.cw / 2, this.ch / 2, this.cw * 0.3, this.cw / 2, this.ch / 2, this.cw * 0.75);
    v.addColorStop(0, "rgba(0,0,0,0)"); v.addColorStop(1, "rgba(0,0,0,0.45)");
    c.fillStyle = v; c.fillRect(0, 0, this.cw, this.ch);
    if (this.flash > 0) { c.fillStyle = `rgba(255,255,255,${Math.min(0.9, this.flash)})`; c.fillRect(0, 0, this.cw, this.ch); }
  }

  drawCrowd(c, back) {
    const ex = this.excite;
    for (const j of this.jumpers) {
      if (j.back !== back) continue;
      const hop = Math.max(0, Math.sin(this.time * (4 + ex * 7) + j.ph)) * (2 + ex * (back ? 6 : 12));
      if (ex < 0.2 && j.ph > 2) continue;
      if (back) {
        const y = 160 + j.row * 14 - hop;
        c.fillStyle = j.col; c.fillRect(j.x - 3.5, y + 3, 7, 7);
        c.fillStyle = j.skin; c.beginPath(); c.arc(j.x, y + 1, 3, 0, TAU); c.fill();
        if (ex > 0.45) { c.strokeStyle = j.skin; c.lineWidth = 1.6; c.beginPath(); c.moveTo(j.x - 3, y + 4); c.lineTo(j.x - 6, y - 5 - hop * 0.3); c.moveTo(j.x + 3, y + 4); c.lineTo(j.x + 6, y - 5 - hop * 0.3); c.stroke(); }
      } else {
        const size = 6 + j.row * 0.8, y = 726 + j.row * 22 - hop;
        c.fillStyle = j.col;
        c.beginPath(); c.ellipse(j.x, y + size * 1.7, size * 1.2, size * 1.1, 0, Math.PI, TAU); c.fill();
        c.fillStyle = j.skin; c.beginPath(); c.arc(j.x, y + size * 0.4, size * 0.85, 0, TAU); c.fill();
        if (ex > 0.35) {
          c.strokeStyle = j.skin; c.lineWidth = 2.4; c.lineCap = "round";
          const wave = Math.sin(this.time * 9 + j.ph) * 3;
          c.beginPath(); c.moveTo(j.x - size, y + size * 1.4); c.lineTo(j.x - size * 1.6 + wave, y - size * 1.2); c.moveTo(j.x + size, y + size * 1.4); c.lineTo(j.x + size * 1.6 - wave, y - size * 1.2); c.stroke();
          if (j.flag) {
            const fx = j.x + size * 1.6 - wave, fy = y - size * 1.2;
            c.strokeStyle = "#ddd"; c.lineWidth = 1.2; c.beginPath(); c.moveTo(fx, fy); c.lineTo(fx, fy - 18); c.stroke();
            c.fillStyle = j.col; c.beginPath(); c.moveTo(fx, fy - 18); c.lineTo(fx + 14, fy - 14 + Math.sin(this.time * 12 + j.ph) * 2); c.lineTo(fx, fy - 9); c.closePath(); c.fill();
          }
        }
      }
    }
  }

  drawScreen(c) {
    // Infield video wall with the live leader.
    const x = 800, y = 445, w = 250, h = 62;
    c.fillStyle = "#3a3f55"; c.fillRect(x - 4, y + h / 2, 8, 40); c.fillRect(x - w / 2 + 20, y + h / 2, 6, 40); c.fillRect(x + w / 2 - 26, y + h / 2, 6, 40);
    c.fillStyle = "#0a0c16"; c.fillRect(x - w / 2 - 6, y - h / 2 - 6, w + 12, h + 12);
    c.fillStyle = "#121a35"; c.fillRect(x - w / 2, y - h / 2, w, h);
    c.textAlign = "center"; c.textBaseline = "middle";
    const race = this.race;
    let top = "CHICKEN DERBY", sub = "50 CREDITS · SIEG = ×2";
    if (this.phase === "countdown") { top = `START IN ${Math.max(1, Math.ceil(-this.t))}`; sub = "DIE PFERDE SIND IN DEN BOXEN"; }
    else if (race && this.t >= 0) {
      const order = standings(race, this.t);
      const lp = lapsAt(race, order[0], this.t);
      top = this.t >= race.finish[race.winner] ? `SIEGER: ${this.names[race.winner].toUpperCase()}` : `FÜHRUNG: ${this.names[order[0]].toUpperCase()}`;
      sub = this.t >= race.finish[race.winner] ? "WAS FÜR EIN RENNEN!" : `RUNDE ${Math.min(race.laps, Math.floor(lp) + 1)} / ${race.laps}`;
    }
    c.fillStyle = "#ffd36b"; c.font = "800 20px 'Space Grotesk', Inter, sans-serif"; c.fillText(top, x, y - 10);
    c.fillStyle = "#7ff3ff"; c.font = "700 12px 'Space Grotesk', Inter, sans-serif"; c.fillText(sub, x, y + 15);
    c.fillStyle = "rgba(255,255,255,0.05)"; for (let i = 0; i < h; i += 3) c.fillRect(x - w / 2, y - h / 2 + i, w, 1);
  }

  drawFinishPost(c) {
    const base = project(FX, R0 - 16);
    c.fillStyle = "#f5f5f5"; c.fillRect(base.x - 3, base.y - 120, 6, 120);
    c.fillStyle = "#e11d48"; c.beginPath(); c.arc(base.x, base.y - 124, 15, 0, TAU); c.fill();
    c.fillStyle = "#fff"; c.beginPath(); c.arc(base.x, base.y - 124, 9, 0, TAU); c.fill();
    c.fillStyle = "#e11d48"; c.beginPath(); c.arc(base.x, base.y - 124, 4, 0, TAU); c.fill();
    c.fillStyle = "#111"; c.fillRect(base.x - 22, base.y - 104, 44, 16);
    c.fillStyle = "#ffd36b"; c.font = "800 12px 'Space Grotesk', Inter, sans-serif"; c.textAlign = "center"; c.textBaseline = "middle";
    c.fillText("ZIEL", base.x, base.y - 96);
    // Photo-finish camera tower across the track
    const cam = project(FX, OUTER + 34);
    c.fillStyle = "#2b3047"; c.fillRect(cam.x - 12, cam.y - 70, 24, 70);
    c.fillStyle = "#111"; c.fillRect(cam.x - 16, cam.y - 84, 32, 16);
    c.fillStyle = "#7ff3ff"; c.fillRect(cam.x - 12, cam.y - 80, 8, 8);
  }

  drawGateStall(c, lane, back) {
    const out = this.gateOut;
    if (out >= 1) return;
    const shift = out * out * 300;
    const r0 = R0 + lane * LW + shift, r1 = r0 + LW;
    const x0 = FX - 74, x1 = FX + 34;
    const sc = depthScale(r0);
    const h = 78 * sc;
    c.save();
    c.globalAlpha = 1 - out * 0.9;
    const P = (x, z, up = 0) => { const q = project(x, z); return [q.x, q.y - up]; };
    const quad = (pts, fill) => { c.fillStyle = fill; c.beginPath(); pts.forEach(([x, y], i) => (i ? c.lineTo(x, y) : c.moveTo(x, y))); c.closePath(); c.fill(); };
    if (back) {
      // Roof plank over the stall, behind the jockey
      quad([P(x0, r0, h), P(x1, r0, h), P(x1, r1, h), P(x0, r1, h)], lane % 2 ? "rgba(26,120,64,0.92)" : "rgba(34,140,74,0.92)");
      c.restore();
      return;
    }
    // Side rails of the stall (the partition between this lane and the next one in front)
    c.strokeStyle = "#2fbf6a"; c.lineCap = "round";
    c.lineWidth = 3 * sc;
    for (const up of [h, h * 0.55]) { const [ax, ay] = P(x0, r1, up), [bx, by] = P(x1, r1, up); c.beginPath(); c.moveTo(ax, ay); c.lineTo(bx, by); c.stroke(); }
    c.lineWidth = 4 * sc;
    for (const x of [x0, x1]) { const [ax, ay] = P(x, r1), [bx, by] = P(x, r1, h); c.beginPath(); c.moveTo(ax, ay); c.lineTo(bx, by); c.stroke(); }
    // Front doors (red and white), swinging open at the bell
    const open = this.gateOpen;
    const mid = r0 + (LW / 2) * (1 - open * 0.92);
    const mid2 = r1 - (LW / 2) * (1 - open * 0.92);
    quad([P(x1, r0, h * 0.85), P(x1, mid, h * 0.85), P(x1, mid, h * 0.25), P(x1, r0, h * 0.25)], "#e11d48");
    quad([P(x1, mid2, h * 0.85), P(x1, r1, h * 0.85), P(x1, r1, h * 0.25), P(x1, mid2, h * 0.25)], "#f8fafc");
    // Number plate in the lane colour
    const [nx, ny] = P(x1 - 10, (r0 + r1) / 2, h + 9 * sc);
    c.fillStyle = LOOKS[lane].silk; c.strokeStyle = "#fff"; c.lineWidth = 1.5;
    c.beginPath(); c.arc(nx, ny, 8 * sc + 2, 0, TAU); c.fill(); c.stroke();
    c.fillStyle = "#fff"; c.font = `800 ${Math.round(9 * sc + 3)}px 'Space Grotesk', Inter, sans-serif`; c.textAlign = "center"; c.textBaseline = "middle";
    c.fillText(String(lane + 1), nx, ny + 0.5);
    c.restore();
  }

  drawHorse(c, h) {
    const sc = depthScale(h.z) * (this.chosen === h.i ? 1.04 : 1);
    const f = h.facing;
    const flip = (f < 0 ? -1 : 1) * (0.3 + 0.7 * Math.min(1, Math.abs(f)));
    c.save();
    c.translate(h.x, h.y);
    c.scale(flip * sc, sc);
    drawHorse(c, { look: h.look, number: h.i + 1, phase: h.phase, gait: h.gait, time: this.time + h.i, glow: this.chosen === h.i ? "#ffd36b" : null });
    c.restore();
    if (this.chosen === h.i) {
      const y = h.y - 118 * sc + Math.sin(this.time * 5) * 3;
      c.fillStyle = "#ffd36b";
      c.beginPath(); c.moveTo(h.x - 7, y); c.lineTo(h.x + 7, y); c.lineTo(h.x, y + 9); c.closePath(); c.fill();
      const label = this.markLabel || "DU";
      c.font = "800 10px 'Space Grotesk', Inter, sans-serif"; c.textAlign = "center"; c.textBaseline = "middle";
      const w = Math.max(30, c.measureText(label).width + 14);
      c.fillStyle = "#111"; c.strokeStyle = "#ffd36b"; c.lineWidth = 1.5;
      c.beginPath(); c.roundRect?.(h.x - w / 2, y - 17, w, 15, 7); if (!c.roundRect) c.rect(h.x - w / 2, y - 17, w, 15); c.fill(); c.stroke();
      c.fillStyle = "#ffd36b";
      c.fillText(label, h.x, y - 9.5);
    }
  }
}
