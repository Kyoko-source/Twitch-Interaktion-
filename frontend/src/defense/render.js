import { BLOCKED, COLS, DECOR, ENEMIES, NEST, PATHS, ROWS, SECOND_PATH_WAVE, towerStats } from "./engine.mjs";
import { drawTower, muzzle } from "./towers.js";

export const T = 48;
export const W = COLS * T, H = ROWS * T;
const TAU = Math.PI * 2;
const px = (v) => (v + 0.5) * T;
const easeOutBack = (t) => { const c = 1.9; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); };

function seeded(seed) { return () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }; }

export { drawTower, TOWER_COLORS, BRANCH_STYLE, branchIcon, towerArtReady, SPRITE_TOWERS } from "./towers.js";

// ------------------------------------------------------------------ enemy art (sprite atlas)
const ATLAS = { runner: [0, 32, 192, 160], spider: [192, 19, 192, 173], fox: [384, 24, 192, 168], raccoon: [576, 32, 192, 160], knight: [768, 32, 192, 160], pilot: [0, 246, 192, 138], robohawk: [192, 266, 192, 118], slime: [384, 226, 192, 158], chicks: [576, 251, 192, 133], bomber: [768, 195, 192, 189], healer: [0, 415, 192, 161], shadow: [192, 408, 192, 168], ice: [384, 434, 192, 142], boar: [576, 441, 192, 135], toxic: [768, 429, 192, 147], golem: [0, 586, 192, 182], hydra: [194, 576, 187, 192], lava: [384, 593, 192, 175], mech: [576, 586, 192, 182], dragon: [768, 621, 192, 147] };
export const ENEMY_ATLAS_URL = "/assets/defense/enemies.webp";
const KILL_COLORS = {
  runner: ["#fff4e0", "#ff3b3b"], fox: ["#ff8a2a", "#fff1dc"], chicks: ["#ffd34a", "#fff4b0"], spider: ["#d8c8a8", "#ffd34a"], pilot: ["#fff4e0", "#8a5a2a"],
  slime: ["#7aff3a", "#c8ff8a"], slimelet: ["#7aff3a", "#c8ff8a"], knight: ["#a8b0c0", "#ffcf4a"], raccoon: ["#6a6a72", "#ffd34a"], healer: ["#c8b890", "#5dff8c"],
  bomber: ["#ff6a2a", "#ffe066"], boar: ["#e08a90", "#8a8a96"], shadow: ["#5a2a8a", "#c48bff"], robohawk: ["#5a5a66", "#ff3a3a"], ice: ["#bff1ff", "#ffffff"],
  toxic: ["#7aff3a", "#d8d0c0"], mech: ["#7a7a86", "#ffcf4a"], hydra: ["#e8dcc8", "#a04aff"], golem: ["#7a7a80", "#ff9a2a"], lava: ["#ff6a1a", "#3a2a2a"], dragon: ["#d82a2a", "#ffcf4a"],
};
export function enemyColors(kind) { return KILL_COLORS[kind] || ["#ffffff", "#cccccc"]; }

function drawEnemy(ctx, e, time, atlas, visible = true) {
  const spec = ENEMIES[e.kind];
  const key = spec.sprite || e.kind;
  const box = ATLAS[key];
  const h = spec.size * T * 1.15;
  const w = box ? h * (box[2] / box[3]) : h;
  const face = e.dx < 0 ? -1 : 1;
  const now = e.engineTime || 0;
  const frozen = e.frozenUntil > now, stunned = e.stunUntil > now && !(e.danceUntil > now), dancing = e.danceUntil > now;
  const step = frozen || stunned ? 0 : Math.sin(time * 11 * Math.min(2, e.speed) + e.id);
  ctx.save();
  ctx.translate(px(e.x), px(e.y));
  // shadow
  ctx.fillStyle = "rgba(0,0,0,0.3)";
  ctx.beginPath(); ctx.ellipse(e.flying ? 8 : 0, h * 0.32 + (e.flying ? 14 : 0), w * 0.38, h * 0.12, 0, 0, TAU); ctx.fill();
  if (spec.boss) {
    const aura = ctx.createRadialGradient(0, 0, 2, 0, 0, h * 0.95);
    aura.addColorStop(0, e.kind === "dragon" ? "rgba(255,120,30,0.4)" : e.kind === "lava" ? "rgba(255,80,20,0.4)" : "rgba(255,40,60,0.32)"); aura.addColorStop(1, "rgba(255,40,60,0)");
    ctx.fillStyle = aura; ctx.beginPath(); ctx.arc(0, 0, h * (0.95 + Math.sin(time * 4) * 0.05), 0, TAU); ctx.fill();
  }
  if (spec.heal) { ctx.strokeStyle = `rgba(93,255,140,${0.35 + Math.sin(time * 4 + e.id) * 0.2})`; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(0, 0, 1.6 * T * ((time * 0.8 + e.id * 0.1) % 1), 0, TAU); ctx.stroke(); }
  if (spec.jam) { ctx.strokeStyle = "rgba(122,255,58,0.35)"; ctx.setLineDash([5, 5]); ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(0, 0, spec.jam.radius * T, time, time + TAU); ctx.stroke(); ctx.setLineDash([]); }
  // body motion
  let lift = 0, sx = 1, sy = 1, rot = 0;
  if (e.flying) { lift = -12 + Math.sin(time * 5 + e.id) * 4; rot = Math.sin(time * 3 + e.id) * 0.08; }
  else if (e.kind === "slime" || e.kind === "slimelet") { sx = 1 + Math.sin(time * 7 + e.id) * 0.08; sy = 2 - sx; }
  else { lift = -Math.abs(step) * 3; sy = 1 + Math.abs(step) * 0.05; sx = 2 - sy; rot = step * 0.05; }
  if (dancing) { rot = Math.sin(time * 14 + e.id) * 0.35; lift -= Math.abs(Math.sin(time * 14 + e.id)) * 6; }
  ctx.translate(0, lift);
  ctx.rotate(rot);
  ctx.scale(face * sx, sy);
  if (!visible) ctx.globalAlpha = 0.28 + Math.sin(time * 6 + e.id) * 0.08;
  if (atlas?.complete && box) {
    ctx.drawImage(atlas, box[0], box[1], box[2], box[3], -w / 2, -h * 0.62, w, h);
    const hit = e.hitAt !== undefined && now - e.hitAt < 0.07;
    if (hit) { ctx.globalCompositeOperation = "lighter"; ctx.globalAlpha = 0.45; ctx.drawImage(atlas, box[0], box[1], box[2], box[3], -w / 2, -h * 0.62, w, h); }
  } else {
    ctx.fillStyle = enemyColors(e.kind)[0]; ctx.beginPath(); ctx.ellipse(0, -h * 0.15, w * 0.4, h * 0.38, 0, 0, TAU); ctx.fill();
  }
  ctx.restore();
  if (spec.bomb) { // burning fuse
    ctx.fillStyle = Math.sin(time * 30) > 0 ? "#ffe066" : "#ff6a2a";
    ctx.beginPath(); ctx.arc(px(e.x) - face * w * 0.12, px(e.y) - h * 0.62 + lift, 2.5, 0, TAU); ctx.fill();
  }
  // status + hp bar (not mirrored)
  ctx.save(); ctx.translate(px(e.x), px(e.y) + lift * 0.5);
  const s = h * 0.45;
  if (e.slowUntil > now) { ctx.fillStyle = "rgba(122,216,255,0.3)"; ctx.beginPath(); ctx.ellipse(0, -h * 0.1, w * 0.48, h * 0.42, 0, 0, TAU); ctx.fill(); }
  if (dancing) { ctx.fillStyle = ["#ff7ad9", "#7ad8ff", "#ffe066"][Math.floor(time * 3) % 3]; ctx.font = "900 14px 'Segoe UI Symbol', sans-serif"; ctx.fillText("♪", w * 0.35, -h * 0.7 + Math.sin(time * 8) * 4); }
  if (e.markUntil > now) { ctx.fillStyle = "rgba(255,58,184,0.85)"; for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(-w * 0.2 + i * w * 0.2, -h * 0.3 + (i % 2) * 6, 3.5, 0, TAU); ctx.fill(); } }
  if (e.dots?.length) { ctx.fillStyle = "rgba(120,255,90,0.28)"; ctx.beginPath(); ctx.ellipse(0, -h * 0.1, w * 0.45, h * 0.4, 0, 0, TAU); ctx.fill(); }
  if (frozen) {
    ctx.fillStyle = "rgba(200,240,255,0.55)"; ctx.strokeStyle = "rgba(255,255,255,0.9)"; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(-w * 0.5, -h * 0.6, w, h * 0.95, 5); ctx.fill(); ctx.stroke();
  } else if (stunned) {
    ctx.fillStyle = "#ffe066";
    for (let i = 0; i < 3; i++) { const a = now * 6 + (i * TAU) / 3; ctx.beginPath(); ctx.arc(Math.cos(a) * s * 0.8, -h * 0.68 + Math.sin(a) * 3, 2.4, 0, TAU); ctx.fill(); }
  }
  if (e.hp < e.maxHp) {
    const bw = spec.boss ? 64 : 30, k = Math.max(0, e.hp / e.maxHp);
    ctx.fillStyle = "rgba(0,0,0,0.6)"; ctx.fillRect(-bw / 2, -h * 0.72, bw, 5);
    ctx.fillStyle = k > 0.5 ? "#5dff8c" : k > 0.25 ? "#ffd34a" : "#ff4a5a"; ctx.fillRect(-bw / 2 + 1, -h * 0.72 + 1, (bw - 2) * k, 3);
  }
  ctx.restore();
}

// ------------------------------------------------------------------ renderer
export class DefenseRenderer {
  constructor(canvas, engine) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.engine = engine;
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = W * this.dpr; canvas.height = H * this.dpr;
    this.fx = []; this.banners = []; this.bolts = []; this.shake = 0; this.flash = 0; this.flashColor = "255,255,255";
    this.recoil = new Map(); this.nestShake = 0; this.towerBorn = new Map(); this.levelUp = new Map();
    this.reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
    this.ground = this.paintGround(false);
    this.groundOpen = null;
    this.ui = { hover: null, placing: null, selected: null };
    this.cards = [];
    this.atlas = new Image();
    this.atlas.src = ENEMY_ATLAS_URL;
  }

  paintGround(withB) {
    const c = document.createElement("canvas");
    c.width = W * this.dpr; c.height = H * this.dpr;
    const g = c.getContext("2d");
    g.scale(this.dpr, this.dpr);
    const rnd = seeded(42);
    const base = g.createLinearGradient(0, 0, W, H);
    base.addColorStop(0, "#4a9a3e"); base.addColorStop(0.5, "#5aa848"); base.addColorStop(1, "#448a3a");
    g.fillStyle = base; g.fillRect(0, 0, W, H);
    // soft grass patches in several tones
    for (let i = 0; i < 260; i++) {
      const x = rnd() * W, y = rnd() * H, r = 20 + rnd() * 60;
      const tone = rnd();
      g.fillStyle = tone < 0.4 ? "rgba(120,200,90,0.10)" : tone < 0.75 ? "rgba(40,100,40,0.10)" : "rgba(170,210,90,0.08)";
      g.beginPath(); g.ellipse(x, y, r, r * (0.5 + rnd() * 0.5), rnd() * 3, 0, TAU); g.fill();
    }
    // mowing stripes
    for (let x = 0; x < COLS; x += 2) { g.fillStyle = "rgba(255,255,255,0.025)"; g.fillRect(x * T, 0, T, H); }
    // grass blades
    for (let i = 0; i < 4200; i++) {
      const x = rnd() * W, y = rnd() * H, h = 3 + rnd() * 7;
      g.strokeStyle = rnd() < 0.5 ? "rgba(150,225,110,0.55)" : "rgba(30,90,35,0.5)"; g.lineWidth = 1;
      g.beginPath(); g.moveTo(x, y); g.quadraticCurveTo(x + (rnd() - 0.5) * 4, y - h * 0.6, x + (rnd() - 0.5) * 5, y - h); g.stroke();
    }
    const drawPath = (pts, open) => {
      const line = (w, color, dash) => {
        g.strokeStyle = color; g.lineWidth = w; g.lineCap = "round"; g.lineJoin = "round"; g.setLineDash(dash || []);
        g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(px(x), px(y)) : g.moveTo(px(x), px(y)))); g.stroke(); g.setLineDash([]);
      };
      if (!open) { line(T * 0.9, "rgba(70,110,50,0.55)"); line(T * 0.6, "rgba(90,130,60,0.5)"); return; }
      line(T * 1.08, "rgba(40,30,20,0.35)");       // drop shadow
      line(T * 1.02, "#7a7a80");                     // stone border
      line(T * 0.96, "#9a9aa2", [7, 5]);              // individual border stones
      line(T * 0.84, "#8a5e34");
      line(T * 0.74, "#b7864e");
      line(T * 0.5, "#c99a64");
      line(4, "rgba(110,70,30,0.35)", [12, 18]);     // wheel ruts
    };
    drawPath(PATHS.a, true);
    drawPath(PATHS.b, withB);
    // pebbles
    for (let i = 0; i < 700; i++) {
      const x = Math.floor(rnd() * COLS), y = Math.floor(rnd() * ROWS);
      if (!BLOCKED.has(`${x},${y}`)) continue;
      g.fillStyle = rnd() < 0.5 ? "rgba(90,60,30,0.45)" : "rgba(240,215,170,0.45)";
      g.beginPath(); g.arc(x * T + rnd() * T, y * T + rnd() * T, 0.8 + rnd() * 2, 0, TAU); g.fill();
    }
    // flowers, mushrooms, rocks on free tiles
    for (let i = 0; i < 220; i++) {
      const x = rnd() * W, y = rnd() * H;
      if (BLOCKED.has(`${Math.floor(x / T)},${Math.floor(y / T)}`)) continue;
      const k = rnd();
      if (k < 0.7) {
        const colr = ["#ffe066", "#ff8ac8", "#ffffff", "#b48cff", "#ff6a5a"][Math.floor(rnd() * 5)];
        g.strokeStyle = "rgba(40,110,40,0.8)"; g.lineWidth = 1; g.beginPath(); g.moveTo(x, y + 2); g.lineTo(x, y + 7); g.stroke();
        g.fillStyle = colr; for (let j = 0; j < 5; j++) { const a = (j / 5) * TAU; g.beginPath(); g.arc(x + Math.cos(a) * 2.6, y + Math.sin(a) * 2.6, 2, 0, TAU); g.fill(); }
        g.fillStyle = "#ffb000"; g.beginPath(); g.arc(x, y, 1.6, 0, TAU); g.fill();
      } else if (k < 0.82) {
        g.fillStyle = "#f0e8dc"; g.fillRect(x - 1, y, 2, 4); g.fillStyle = "#d8402a"; g.beginPath(); g.arc(x, y, 4, Math.PI, TAU); g.fill();
        g.fillStyle = "#fff"; g.beginPath(); g.arc(x - 1.5, y - 2, 0.8, 0, TAU); g.arc(x + 1.5, y - 1.5, 0.7, 0, TAU); g.fill();
      } else {
        g.fillStyle = "rgba(0,0,0,0.2)"; g.beginPath(); g.ellipse(x + 2, y + 3, 8, 3, 0, 0, TAU); g.fill();
        g.fillStyle = "#8a8e98"; g.beginPath(); g.ellipse(x, y, 6 + rnd() * 5, 4 + rnd() * 3, rnd(), 0, TAU); g.fill();
        g.fillStyle = "rgba(255,255,255,0.3)"; g.beginPath(); g.ellipse(x - 1.5, y - 1.5, 2.5, 1.4, 0, 0, TAU); g.fill();
      }
    }
    // fences along the top and bottom borders
    const fence = (y) => {
      g.strokeStyle = "#8a5a2a"; g.lineWidth = 3;
      g.beginPath(); g.moveTo(0, y - 6); g.lineTo(W, y - 6); g.moveTo(0, y - 1); g.lineTo(W, y - 1); g.stroke();
      g.fillStyle = "#a8743a"; for (let x = 6; x < W; x += 34) { g.fillRect(x, y - 12, 5, 14); g.fillStyle = "#6a4420"; g.fillRect(x, y - 12, 5, 2); g.fillStyle = "#a8743a"; }
    };
    fence(10); fence(H - 1);
    // static scenery
    for (const d of DECOR) {
      const x = d.c * T, y = d.r * T, w = d.w * T, h = d.h * T;
      if (d.kind === "barn") {
        g.fillStyle = "rgba(0,0,0,0.25)"; g.beginPath(); g.ellipse(x + w / 2 + 6, y + h - 6, w * 0.48, 12, 0, 0, TAU); g.fill();
        g.fillStyle = "#c8302a"; g.fillRect(x + 14, y + 44, w - 28, h - 56);
        g.fillStyle = "#8a1a14"; g.beginPath(); g.moveTo(x + 6, y + 48); g.lineTo(x + w / 2, y + 8); g.lineTo(x + w - 6, y + 48); g.closePath(); g.fill();
        g.fillStyle = "#5a2a18"; g.fillRect(x + 4, y + 44, w - 8, 6);
        g.fillStyle = "#ffffff"; g.fillRect(x + w / 2 - 18, y + 70, 36, h - 82);
        g.strokeStyle = "#ffffff"; g.lineWidth = 3; g.strokeRect(x + w / 2 - 18, y + 70, 36, h - 82);
        g.strokeStyle = "#c8302a"; g.beginPath(); g.moveTo(x + w / 2 - 16, y + 72); g.lineTo(x + w / 2 + 16, y + h - 14); g.moveTo(x + w / 2 + 16, y + 72); g.lineTo(x + w / 2 - 16, y + h - 14); g.stroke();
        g.fillStyle = "#fff4dc"; g.beginPath(); g.arc(x + w / 2, y + 32, 9, 0, TAU); g.fill();
        g.fillStyle = "#ff3b3b"; g.beginPath(); g.arc(x + w / 2 - 2, y + 25, 3, 0, TAU); g.fill();
        // hay stack
        g.fillStyle = "#e8c050"; g.beginPath(); g.ellipse(x + 22, y + h - 16, 18, 12, 0, 0, TAU); g.fill();
        g.strokeStyle = "#b08a30"; g.lineWidth = 1; for (let k = 0; k < 6; k++) { g.beginPath(); g.moveTo(x + 8 + k * 5, y + h - 22); g.lineTo(x + 10 + k * 5, y + h - 8); g.stroke(); }
      } else if (d.kind === "windmill") {
        g.fillStyle = "rgba(0,0,0,0.25)"; g.beginPath(); g.ellipse(x + w / 2 + 6, y + h - 8, 34, 10, 0, 0, TAU); g.fill();
        g.fillStyle = "#e8dcc8"; g.beginPath(); g.moveTo(x + w / 2 - 22, y + h - 8); g.lineTo(x + w / 2 - 12, y + 40); g.lineTo(x + w / 2 + 12, y + 40); g.lineTo(x + w / 2 + 22, y + h - 8); g.closePath(); g.fill();
        g.strokeStyle = "#a89a80"; g.lineWidth = 1.5; g.stroke();
        g.fillStyle = "#8a4a2a"; g.beginPath(); g.moveTo(x + w / 2 - 16, y + 42); g.lineTo(x + w / 2, y + 22); g.lineTo(x + w / 2 + 16, y + 42); g.fill();
        g.fillStyle = "#6a3a1a"; g.fillRect(x + w / 2 - 7, y + h - 34, 14, 26);
      } else if (d.kind === "pond") {
        g.fillStyle = "#2a6a3a"; g.beginPath(); g.ellipse(x + w / 2, y + h / 2 + 6, w * 0.48, h * 0.4, 0, 0, TAU); g.fill();
        const water = g.createRadialGradient(x + w / 2 - 10, y + h / 2, 4, x + w / 2, y + h / 2 + 6, w * 0.45);
        water.addColorStop(0, "#7ad8ff"); water.addColorStop(1, "#2a7ab8");
        g.fillStyle = water; g.beginPath(); g.ellipse(x + w / 2, y + h / 2 + 6, w * 0.44, h * 0.35, 0, 0, TAU); g.fill();
        g.fillStyle = "#3a9a3a"; for (const [lx, ly] of [[-24, 4], [18, 14], [6, -8]]) { g.beginPath(); g.arc(x + w / 2 + lx, y + h / 2 + 6 + ly, 7, 0.4, TAU); g.lineTo(x + w / 2 + lx, y + h / 2 + 6 + ly); g.fill(); }
        g.fillStyle = "#ff8ac8"; g.beginPath(); g.arc(x + w / 2 + 18, y + h / 2 + 18, 3, 0, TAU); g.fill();
        for (let k = 0; k < 10; k++) { g.fillStyle = "#3a8a3a"; g.fillRect(x + 8 + k * 13, y + h - 14 - (k % 3) * 3, 2, 10 + (k % 2) * 4); }
      } else if (d.kind === "hay") {
        g.fillStyle = "rgba(0,0,0,0.25)"; g.beginPath(); g.ellipse(x + w / 2 + 4, y + h - 8, 18, 6, 0, 0, TAU); g.fill();
        g.fillStyle = "#e8c050"; g.beginPath(); g.roundRect(x + 8, y + 14, w - 16, h - 22, 6); g.fill();
        g.strokeStyle = "#a8742a"; g.lineWidth = 2; g.beginPath(); g.moveTo(x + 8, y + 24); g.lineTo(x + w - 8, y + 24); g.moveTo(x + 8, y + h - 18); g.lineTo(x + w - 8, y + h - 18); g.stroke();
      } else if (d.kind === "tree") {
        g.fillStyle = "rgba(0,0,0,0.28)"; g.beginPath(); g.ellipse(x + w / 2 + 6, y + h - 6, 22, 8, 0, 0, TAU); g.fill();
        g.fillStyle = "#6a4420"; g.fillRect(x + w / 2 - 4, y + h - 22, 8, 18);
      }
    }
    // dens at the entrances
    const den = (x, y) => { g.fillStyle = "#3a2a18"; g.beginPath(); g.ellipse(x, y, 28, 22, 0, 0, TAU); g.fill(); g.fillStyle = "#0a0604"; g.beginPath(); g.ellipse(x + 4, y + 2, 18, 14, 0, 0, TAU); g.fill(); g.fillStyle = "#6a6e78"; for (let k = 0; k < 7; k++) { const a = Math.PI * 0.9 + (k / 6) * Math.PI * 1.2; g.beginPath(); g.ellipse(x + Math.cos(a) * 26, y + Math.sin(a) * 20, 6, 4, a, 0, TAU); g.fill(); } };
    den(px(-0.25), px(2));
    if (withB) den(px(6), px(12.3));
    // warm sunlight from the top left, vignette towards the edges
    const sun = g.createRadialGradient(W * 0.15, -H * 0.1, 40, W * 0.15, -H * 0.1, W * 0.9);
    sun.addColorStop(0, "rgba(255,240,180,0.22)"); sun.addColorStop(1, "rgba(255,240,180,0)");
    g.fillStyle = sun; g.fillRect(0, 0, W, H);
    const v = g.createRadialGradient(W / 2, H / 2, H * 0.32, W / 2, H / 2, W * 0.66);
    v.addColorStop(0, "rgba(0,0,0,0)"); v.addColorStop(1, "rgba(0,0,0,0.38)");
    g.fillStyle = v; g.fillRect(0, 0, W, H);
    return c;
  }

  // ----------------------------------------------------------------- ambient life
  drawAmbient(time, dt) {
    const ctx = this.ctx, wave = this.engine.wave;
    // trees with swaying canopies and the turning windmill
    for (const d of DECOR) {
      if (d.kind === "tree") {
        const x = d.c * T + T / 2, y = d.r * T + T - 18, sway = Math.sin(time * 1.3 + d.c) * 2;
        for (const [ox, oy, r, col] of [[-10, -6, 15, "#2f7a2f"], [10, -8, 14, "#2f7a2f"], [0, -20, 18, "#3a9a3a"], [-4, -24, 10, "#5ab84a"]]) {
          ctx.fillStyle = col; ctx.beginPath(); ctx.arc(x + ox + sway * (1 - oy / 40), y + oy, r, 0, TAU); ctx.fill();
        }
        ctx.fillStyle = "#ff4a3a"; for (const [ax, ay] of [[-8, -14], [8, -22], [2, -8]]) { ctx.beginPath(); ctx.arc(x + ax + sway, y + ay, 2.4, 0, TAU); ctx.fill(); }
      } else if (d.kind === "windmill") {
        const cx = d.c * T + d.w * T / 2, cy = d.r * T + 38;
        ctx.save(); ctx.translate(cx, cy); ctx.rotate(time * (0.8 + Math.min(2, wave * 0.05)));
        for (let i = 0; i < 4; i++) {
          ctx.rotate(TAU / 4);
          ctx.fillStyle = "#f4ecdc"; ctx.strokeStyle = "#8a6a4a"; ctx.lineWidth = 1.2;
          ctx.beginPath(); ctx.rect(3, -5, 38, 10); ctx.fill(); ctx.stroke();
          ctx.beginPath(); ctx.moveTo(3, 0); ctx.lineTo(41, 0); ctx.stroke();
        }
        ctx.fillStyle = "#6a4420"; ctx.beginPath(); ctx.arc(0, 0, 5, 0, TAU); ctx.fill();
        ctx.restore();
      } else if (d.kind === "pond") {
        const cx = d.c * T + d.w * T / 2, cy = d.r * T + d.h * T / 2 + 6;
        ctx.strokeStyle = `rgba(255,255,255,${0.25 + Math.sin(time * 2) * 0.1})`; ctx.lineWidth = 1.2;
        const r = ((time * 14) % 30);
        ctx.beginPath(); ctx.ellipse(cx - 12, cy - 4, r, r * 0.4, 0, 0, TAU); ctx.stroke();
      }
    }
    // drifting cloud shadows
    if (!this.reduced) for (let i = 0; i < 3; i++) {
      const x = ((time * (12 + i * 4) + i * 420) % (W + 400)) - 200, y = 90 + i * 190;
      ctx.fillStyle = "rgba(10,30,20,0.09)";
      ctx.beginPath(); ctx.ellipse(x, y, 150, 60, 0.2, 0, TAU); ctx.ellipse(x + 90, y + 20, 110, 50, 0, 0, TAU); ctx.fill();
    }
    // day: butterflies; night: fireflies; storms later
    const night = wave >= 9;
    if (!this.reduced) for (let i = 0; i < (night ? 30 : 8); i++) {
      const bx = (i * 173 + time * (night ? 8 : 26) * (i % 2 ? 1 : -1)) % W, x = bx < 0 ? bx + W : bx;
      const y = (i * 97 + Math.sin(time * 0.9 + i) * 40) % H;
      if (night) {
        const a = 0.25 + ((Math.sin(time * 2.2 + i * 1.7) + 1) / 2) * 0.65;
        ctx.fillStyle = `rgba(255,236,140,${a})`; ctx.beginPath(); ctx.arc(x, y, 2, 0, TAU); ctx.fill();
        ctx.fillStyle = `rgba(255,236,140,${a * 0.25})`; ctx.beginPath(); ctx.arc(x, y, 6, 0, TAU); ctx.fill();
      } else {
        const flap = Math.abs(Math.sin(time * 14 + i));
        ctx.fillStyle = ["#ffe066", "#ff8ac8", "#9ad8ff", "#ffffff"][i % 4];
        ctx.beginPath(); ctx.ellipse(x - 3 * flap, y, 3.5 * flap + 0.5, 2.6, -0.4, 0, TAU); ctx.ellipse(x + 3 * flap, y, 3.5 * flap + 0.5, 2.6, 0.4, 0, TAU); ctx.fill();
      }
    }
    if (wave >= 12 && !this.reduced) {
      const heavy = wave >= 20;
      ctx.strokeStyle = heavy ? "rgba(200,220,255,0.35)" : "rgba(200,220,255,0.22)"; ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 0; i < (heavy ? 160 : 70); i++) {
        const x = (i * 61.7 + time * 140) % (W + 40) - 20, y = (i * 37.3 + time * 620) % (H + 40) - 20;
        ctx.moveTo(x, y); ctx.lineTo(x - 4, y + 12);
      }
      ctx.stroke();
      if (wave >= 15 && Math.random() < dt * 0.25) { this.flash = 0.9; this.flashColor = "220,230,255"; }
    }
  }

  // ----------------------------------------------------------------- in-field HUD (also visible in fullscreen)
  hudAnchor() { return { x: 26, y: 26 }; }
  drawHud(time, dt) {
    const ctx = this.ctx, e = this.engine;
    if (e.status === "ready") return;
    this.hudPulse = Math.max(0, (this.hudPulse || 0) - dt * 3);
    this.kornShown = this.kornShown === undefined ? e.korn : this.kornShown + (e.korn - this.kornShown) * Math.min(1, dt * 10);
    ctx.save();
    ctx.translate(10, 10);
    ctx.fillStyle = "rgba(255,244,220,0.94)"; ctx.strokeStyle = "#7a4a24"; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.roundRect(0, 0, 286, 36, 12); ctx.fill(); ctx.stroke();
    ctx.textBaseline = "middle"; ctx.font = "900 17px Inter, Segoe UI, sans-serif";
    // Korn
    const s = 1 + this.hudPulse * 0.25;
    ctx.save(); ctx.translate(16, 18); ctx.scale(s, s);
    const coin = ctx.createRadialGradient(-2, -2, 1, 0, 0, 9); coin.addColorStop(0, "#fff8d0"); coin.addColorStop(1, "#d89a00");
    ctx.fillStyle = coin; ctx.beginPath(); ctx.arc(0, 0, 9, 0, TAU); ctx.fill(); ctx.strokeStyle = "#8a5200"; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.restore();
    ctx.fillStyle = "#4a2a12"; ctx.fillText(Math.round(this.kornShown).toLocaleString("de-DE"), 30, 19);
    // eggs
    ctx.fillStyle = e.eggs <= 5 ? `rgba(255,${Math.round(80 + Math.sin(time * 8) * 60)},90,1)` : "#fff1d0";
    ctx.beginPath(); ctx.ellipse(118, 18, 7, 9, 0, 0, TAU); ctx.fill(); ctx.strokeStyle = "#a07a40"; ctx.lineWidth = 1.2; ctx.stroke();
    ctx.fillStyle = e.eggs <= 5 ? "#d8202a" : "#4a2a12"; ctx.fillText(String(e.eggs), 132, 19);
    // wave
    ctx.fillStyle = "#d8402a"; ctx.font = "900 12px Inter, sans-serif"; ctx.fillText("WELLE", 172, 19);
    ctx.font = "900 17px Inter, sans-serif"; ctx.fillStyle = "#4a2a12"; ctx.fillText(String(e.wave), 222, 19);
    if (e.shields) { ctx.fillStyle = "#2ab84a"; ctx.font = "900 12px Inter, sans-serif"; ctx.fillText(`◈${e.shields}`, 252, 19); }
    ctx.restore();
  }

  // ----------------------------------------------------------------- effects api
  banner(text, sub, color, life = 1.8, big = 1) { this.banners.push({ text, sub, color, life, age: 0, big }); }
  burst(x, y, n, colors, speed = 1, kind = "spark", size = 3) {
    if (this.reduced) n = Math.min(n, 5);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * TAU, v = (40 + Math.random() * 160) * speed;
      this.fx.push({ kind, x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - (kind === "pop" ? 120 : 0), age: 0, life: 0.5 + Math.random() * 0.6, color: colors[i % colors.length], size: size * (0.6 + Math.random() * 0.8), spin: (Math.random() - 0.5) * 10 });
    }
    if (this.fx.length > 900) this.fx.splice(0, this.fx.length - 900);
  }
  ring(x, y, color, size, life = 0.45) { this.fx.push({ kind: "ring", x, y, vx: 0, vy: 0, age: 0, life, color, size }); }
  text(x, y, text, color, size = 15) { this.fx.push({ kind: "text", x, y, vx: 0, vy: -40, age: 0, life: 0.9, color, text, size }); }

  event(ev) {
    const e = this.engine;
    switch (ev.type) {
      case "shoot": {
        const t = ev.tower;
        this.recoil.set(t.id, 1);
        const m = muzzle(t.kind, Math.min(t.level, 3), t.angle);
        const mx = px(t.x) + m.x, my = px(t.y) - 4 + m.y;
        this.fx.push({ kind: "flash", x: mx, y: my, vx: 0, vy: 0, age: 0, life: 0.07, size: t.kind === "gatling" ? 7 : 11, color: t.kind === "frost" ? "#bff1ff" : t.kind === "wizard" ? "#e0b0ff" : "#ffe066", angle: t.angle });
        if (t.kind === "gatling" && Math.random() < 0.6) this.fx.push({ kind: "casing", x: px(t.x), y: px(t.y) - 6, vx: (Math.random() - 0.5) * 60, vy: -80 - Math.random() * 40, age: 0, life: 0.6, size: 2, spin: 20 });
        if (t.kind === "mortar" || t.kind === "rocket") this.fx.push({ kind: "smoke", x: mx, y: my, vx: 0, vy: -14, age: 0, life: 0.6, size: 7 });
        break;
      }
      case "hit": {
        const color = ev.kind === "frost" ? "#bff1ff" : ev.kind === "wizard" ? "#d08aff" : ev.branch === "mutation" ? "#7aff5a" : "#ffe066";
        this.burst(px(ev.x), px(ev.y), ev.kind === "gatling" ? 2 : 6, [color, "#ffffff"], 0.5);
        break;
      }
      case "explode": {
        const x = px(ev.x), y = px(ev.y), r = ev.radius * T;
        if (ev.kind === "shell" || ev.kind === "rocket") {
          this.fx.push({ kind: "glow", x, y, vx: 0, vy: 0, age: 0, life: 0.35, size: r * 1.6, color: "255,170,60" });
          this.burst(x, y, 10, ["#5a4a3a", "#3a2a1a"], 1.6, "debris", 3);
          this.burst(x, y, 26, ["#fff6d8", "#ffe28a", "#ffffff"], 1.1, "pop", 4.5);
          this.burst(x, y, 14, ["#ff9a2a", "#ffcf4a"], 1.4);
          this.ring(x, y, "#ffcf4a", r); this.fx.push({ kind: "smoke", x, y, vx: 0, vy: -10, age: 0, life: 0.8, size: r * 0.7 });
          if (!this.reduced) this.shake = Math.max(this.shake, 0.08);
        } else { this.ring(x, y, "#7ad8ff", r, 0.5); this.burst(x, y, 12, ["#bff1ff", "#ffffff"], 0.7, "flake", 3); }
        break;
      }
      case "zap": this.bolts.push({ points: ev.points.map((p) => ({ x: px(p.x), y: px(p.y) })), age: 0, life: 0.18, magic: ev.magic, emp: ev.emp }); ev.points.slice(1).forEach((p) => this.burst(px(p.x), px(p.y), 5, ev.magic ? ["#d08aff", "#ffffff"] : ["#9ad8ff", "#ffffff"], 0.6)); if (ev.emp) ev.points.slice(1).forEach((p) => this.ring(px(p.x), px(p.y), "#5ab8ff", 26, 0.35)); break;
      case "snipe": {
        const t = ev.tower, sx = px(t.x) + Math.cos(t.angle) * 28, sy = px(t.y) - 6 + Math.sin(t.angle) * 28;
        this.bolts.push({ tracer: true, points: [{ x: sx, y: sy }, { x: px(ev.x), y: px(ev.y) }], age: 0, life: 0.12 });
        this.burst(sx, sy, 6, ["#ffe066", "#ffffff"], 0.5);
        this.burst(px(ev.x), px(ev.y), ev.crit ? 18 : 8, ev.crit ? ["#ff3b3b", "#ffe066"] : ["#ffffff", "#ffd0a0"], ev.crit ? 1.2 : 0.7);
        if (ev.crit) this.text(px(ev.x), px(ev.y) - 18, "KRIT!", "#ff4a5a", 20);
        break;
      }
      case "pulse": {
        const x = px(ev.tower.x), y = px(ev.tower.y), r = ev.radius * T;
        const PULSE = { bees: ["#ffd34a", "#1a1a1a"], sand: ["#e8c070", "#c8902a"], disco: ["#ff7ad9", "#7ad8ff", "#ffe066", "#7aff7a"], log: ["#8a5a2a", "#c8a070"], lava: ["#ff6a1a", "#ffcf4a"], ghost: ["#9af0ff", "#ffffff"], curse: ["#7aff5a", "#5a2a8a"], magnet: ["#ff4a5a", "#5a7aff"] }[ev.fx];
        if (PULSE) {
          this.ring(x, y, PULSE[0], r, 0.5);
          this.burst(x, y, ev.fx === "disco" ? 18 : 10, PULSE, 0.9, ev.fx === "sand" || ev.fx === "log" ? "fluff" : ev.fx === "disco" ? "star" : "spark", 3);
          if (ev.fx === "ghost") this.ring(x, y, "#ffffff", r * 0.6, 0.4);
          break;
        }
        if (ev.fx === "snow") { this.burst(x, y, 10, ["#ffffff", "#bff1ff"], 0.9, "flake", 2.5); this.ring(x, y, "rgba(200,240,255,0.7)", r, 0.4); }
        else if (ev.fx === "hole") { this.ring(x, y, "#a04aff", r, 0.6); this.fx.push({ kind: "vortex", x, y, vx: 0, vy: 0, age: 0, life: 0.6, size: r }); }
        else { this.ring(x, y, "#c48bff", r, 0.5); this.ring(x, y, "#ffffff", r * 0.6, 0.35); if (!this.reduced) this.shake = Math.max(this.shake, 0.05); }
        break;
      }
      case "freeze": this.burst(px(ev.x), px(ev.y), 12, ["#ffffff", "#bff1ff"], 0.7, "flake", 3); break;
      case "slash": {
        for (const p of ev.points) { this.fx.push({ kind: "slash", x: px(p.x), y: px(p.y), vx: 0, vy: 0, age: 0, life: 0.22, size: 18 + ev.radius * T * 0.6, angle: Math.random() * TAU, color: ev.tower.kind === "samurai" ? "#ff8ac8" : "#fff3c4" }); this.burst(px(p.x), px(p.y), 5, ["#ffffff", "#ffd0e0"], 0.6); }
        break;
      }
      case "warp": {
        const a = { x: px(ev.from.x), y: px(ev.from.y) }, b = { x: px(ev.to.x), y: px(ev.to.y) };
        this.fx.push({ kind: "vortex", x: a.x, y: a.y, vx: 0, vy: 0, age: 0, life: 0.6, size: 26 }); this.fx.push({ kind: "vortex", x: b.x, y: b.y, vx: 0, vy: 0, age: 0, life: 0.6, size: 26 });
        this.bolts.push({ points: [a, b], age: 0, life: 0.2, magic: true }); this.burst(b.x, b.y, 14, ["#b08aff", "#ffffff"], 0.8, "star", 3);
        break;
      }
      case "starHit": { const x = px(ev.x), y = px(ev.y); this.fx.push({ kind: "glow", x, y, vx: 0, vy: 0, age: 0, life: 0.4, size: 70, color: "255,240,160" }); this.burst(x, y, 24, ["#fff8c0", "#ffe066", "#c48bff"], 1.3, "star", 4); this.ring(x, y, "#fff3a0", 50, 0.45); if (!this.reduced) this.shake = Math.max(this.shake, 0.08); break; }
      case "crit": this.text(px(ev.x), px(ev.y) - 20, "KRIT!", "#ff4a5a", 18); break;
      case "eggSaved": this.text(px(ev.x), px(ev.y) - 22, "+1 Ei", "#fff1d0", 18); this.burst(px(ev.x), px(ev.y), 10, ["#fff1d0", "#ffffff"], 0.7, "star", 3); break;
      case "shielded": this.ring(px(NEST.x) + 16, px(NEST.y), "#5dff8c", 70, 0.6); this.text(px(NEST.x), px(NEST.y) - 30, "GEBLOCKT!", "#5dff8c", 18); break;
      case "revive": this.flash = 1; this.flashColor = "93,255,140"; this.banner("WIEDERBELEBT!", "Das Nest bekommt 10 Eier zurück", "#5dff8c", 2.4, 1.2); this.burst(px(NEST.x), px(NEST.y), 50, ["#5dff8c", "#ffffff", "#fff1dc"], 1.4, "feather", 4); break;
      case "kill": {
        const en = ev.enemy, x = px(en.x), y = px(en.y);
        const colors = enemyColors(en.kind);
        this.burst(x, y, ENEMIES[en.kind].boss ? 80 : 14, colors, ENEMIES[en.kind].boss ? 2 : 0.9, "fluff", 3.5);
        this.text(x, y - 10, `+${ev.bounty}`, "#ffe066", ENEMIES[en.kind].boss ? 30 : 15);
        this.fx.push({ kind: "poof", x, y: y - 8, vx: 0, vy: -10, age: 0, life: 0.45, size: ENEMIES[en.kind].size * T * 0.7 });
        // coins fly up to the Korn counter
        const coins = Math.min(8, 1 + Math.floor(ev.bounty / 6));
        for (let i = 0; i < coins; i++) this.fx.push({ kind: "coinfly", x, y, sx: x, sy: y, vx: 0, vy: 0, age: -i * 0.05, life: 0.75, size: 5, ox: (Math.random() - 0.5) * 80, oy: -40 - Math.random() * 60 });
        if (ENEMIES[en.kind].boss) { this.shake = this.reduced ? 0 : 0.6; this.flash = 0.9; this.flashColor = "255,220,120"; this.banner("BOSS BESIEGT!", `+${ev.bounty} Korn`, "#ffe066", 2.2, 1.3); }
        break;
      }
      case "leak": {
        this.nestShake = 0.5; this.flash = Math.max(this.flash, 0.35); this.flashColor = "255,60,80";
        this.burst(px(NEST.x), px(NEST.y), 12, ["#ffffff", "#fff1dc"], 0.8, "feather", 4);
        this.text(px(NEST.x), px(NEST.y) - 20, `-${ev.steal} Ei`, "#ff5a7a", 18);
        if (ev.korn) this.text(px(NEST.x), px(NEST.y) + 6, `-${ev.korn} Korn`, "#ffcf4a", 16);
        if (!this.reduced) this.shake = Math.max(this.shake, 0.12);
        break;
      }
      case "build": {
        const x = px(ev.tower.x), y = px(ev.tower.y);
        this.towerBorn.set(ev.tower.id, performance.now());
        setTimeout(() => { this.burst(x, y + 10, 18, ["#c8a070", "#e8d0a0", "#8a6a40"], 0.7, "fluff", 3.5); this.ring(x, y + 8, "#fff1dc", 40, 0.4); this.burst(x, y, 8, ["#ffffff", "#fff1dc"], 0.5, "feather", 3); if (!this.reduced) this.shake = Math.max(this.shake, 0.05); }, 260);
        break;
      }
      case "upgrade": {
        const x = px(ev.tower.x), y = px(ev.tower.y);
        this.levelUp.set(ev.tower.id, performance.now());
        this.fx.push({ kind: "pillar", x, y, vx: 0, vy: 0, age: 0, life: 0.9, size: 30, color: ev.branch ? "#ff7ad9" : "#ffe066" });
        this.burst(x, y, 30, ["#ffe066", "#ffffff", ev.branch ? "#ff7ad9" : "#ffcf4a"], 1, "star", 4.5);
        this.ring(x, y, "#ffe066", 60, 0.6); this.ring(x, y, "#ffffff", 36, 0.4);
        this.text(x, y - 34, ev.branch ? "SPEZIALISIERT!" : `LEVEL ${ev.tower.level}!`, ev.branch ? "#ff7ad9" : "#ffe066", 18);
        break;
      }
      case "sell": this.burst(px(ev.tower.x), px(ev.tower.y), 16, ["#ffd34a", "#ffe066"], 0.8, "coin", 3.5); this.text(px(ev.tower.x), px(ev.tower.y) - 16, `+${ev.refund}`, "#ffe066"); break;
      case "waveStart": {
        const boss = ev.boss;
        this.banner(boss ? `BOSS-WELLE ${ev.wave}` : `WELLE ${ev.wave}`, ev.mods.length ? ev.mods.map((m) => m.toUpperCase()).join(" + ") : ev.early ? `Früh gerufen: +${ev.bonus} Korn` : "Sie kommen!", boss ? "#ff4a5a" : ev.mods.length ? "#ff7ad9" : "#ffe066", 2, boss ? 1.3 : 1);
        if (boss || ev.mods.length) { this.flash = 0.6; this.flashColor = boss ? "255,40,60" : "255,122,217"; }
        break;
      }
      case "pathOpen":
        this.groundOpen = this.paintGround(true); this.ground = this.groundOpen;
        this.shake = this.reduced ? 0 : 0.5;
        setTimeout(() => this.banner("ZWEITER EINGANG!", "Sie graben sich von unten durch!", "#ff9a2a", 2.4, 1.2), 2100);
        this.burst(px(6), px(12), 60, ["#5a3f22", "#a87a48", "#2a1a10"], 1.6, "fluff", 4);
        break;
      case "waveClear": {
        this.banner("WELLE GESCHAFFT!", `+${ev.bonus + ev.income} Korn${ev.income ? ` (davon ${ev.income} vom Goldhuhn)` : ""}${ev.healed ? ` · +${ev.healed} Ei` : ""}`, "#5dff8c", 1.8, 0.9);
        for (const t of this.engine.towers) if (t.kind === "golden") { this.burst(px(t.x), px(t.y), 14, ["#ffd34a", "#ffe066"], 0.9, "coin", 3.5); }
        break;
      }
      case "boss": this.banner(`${ENEMIES[ev.enemy.kind].name.toUpperCase()}!`, ENEMIES[ev.enemy.kind].desc, "#ff4a5a", 2.2, 1.2); this.shake = this.reduced ? 0 : 0.3; break;
      case "newEnemy": this.cards.push({ kind: ev.kind, age: 0, life: 4.2 }); break;
      case "bossSpawn": this.burst(px(ev.enemy.x), px(ev.enemy.y), 30, ["#7aff3a", "#ff6a1a"], 1.2, "fluff", 4); this.shake = this.reduced ? 0 : 0.2; break;
      case "bomb": {
        const x = px(ev.x), y = px(ev.y);
        this.burst(x, y, 40, ["#ff6a2a", "#ffe066", "#3a2a2a"], 1.5, "fluff", 5); this.ring(x, y, "#ff6a2a", ev.radius * T, 0.5);
        this.fx.push({ kind: "smoke", x, y, vx: 0, vy: -12, age: 0, life: 1, size: ev.radius * T * 0.6 });
        if (ev.towers) this.text(x, y - 24, "TÜRME GELÄHMT!", "#ff6a2a", 16);
        if (!this.reduced) this.shake = Math.max(this.shake, 0.2);
        break;
      }
      case "gameOver": this.flash = 1; this.flashColor = "255,40,60"; this.shake = this.reduced ? 0 : 0.6; break;
      default: break;
    }
    void e;
  }

  // ----------------------------------------------------------------- frame
  draw(time, dt) {
    const ctx = this.ctx, e = this.engine;
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);
    ctx.save();
    if (this.shake > 0) { ctx.translate(Math.sin(time * 97) * this.shake * 18, Math.cos(time * 83) * this.shake * 12); this.shake = Math.max(0, this.shake - dt * 1.5); }
    ctx.drawImage(this.ground, 0, 0, W, H);
    this.drawAmbientBack = true;
    // closed second entrance: a wooden barricade until it bursts open
    if (e.wave < SECOND_PATH_WAVE) {
      ctx.save(); ctx.translate(px(6), px(12.1));
      ctx.fillStyle = "#7a5230"; ctx.strokeStyle = "#3a2410"; ctx.lineWidth = 2;
      for (let i = -1; i <= 1; i++) { ctx.fillRect(i * 12 - 4, -16, 8, 26); ctx.strokeRect(i * 12 - 4, -16, 8, 26); }
      ctx.rotate(-0.15); ctx.fillRect(-20, -6, 40, 7); ctx.strokeRect(-20, -6, 40, 7);
      ctx.restore();
    }
    this.drawNest(time, dt);
    // range + placement ghost
    const ui = this.ui;
    const selected = ui.selected ? e.towers.find((t) => t.id === ui.selected) : null;
    if (selected) this.rangeCircle(selected.x, selected.y, towerStats(selected.kind, selected.level, selected.branch).range, "rgba(255,230,120,0.9)");
    if (ui.placing && ui.hover) {
      const ok = e.canBuild(ui.placing, ui.hover.c, ui.hover.r);
      ctx.fillStyle = ok ? "rgba(93,255,140,0.25)" : "rgba(255,74,90,0.3)";
      ctx.fillRect(ui.hover.c * T, ui.hover.r * T, T, T);
      this.rangeCircle(ui.hover.c, ui.hover.r, towerStats(ui.placing, 1).range, ok ? "rgba(93,255,140,0.9)" : "rgba(255,74,90,0.9)");
      ctx.save(); ctx.globalAlpha = 0.6; ctx.translate(px(ui.hover.c), px(ui.hover.r)); drawTower(ctx, ui.placing, 1, -Math.PI / 4, time); ctx.restore();
    }
    // enemies (ground first, flyers on top), towers, projectiles
    const ground = e.enemies.filter((en) => !en.flying), air = e.enemies.filter((en) => en.flying);
    this.drawZones(time);
    for (const en of ground) { en.engineTime = e.time; drawEnemy(ctx, en, time, this.atlas, e.visible(en)); }
    const towers = [...e.towers].sort((a, b) => a.y - b.y);
    for (const t of towers) {
      let r = this.recoil.get(t.id) || 0;
      if (r > 0) this.recoil.set(t.id, Math.max(0, r - dt * 8));
      const born = this.towerBorn.get(t.id);
      const drop = born ? Math.min(1, (performance.now() - born) / 300) : 1;
      const lvl = this.levelUp.get(t.id);
      const lp = lvl ? Math.min(1, (performance.now() - lvl) / 500) : 1;
      ctx.save(); ctx.translate(px(t.x), px(t.y) - 4 - (this.reduced ? 0 : (1 - drop * drop) * 240));
      const squash = drop >= 1 && born && performance.now() - born < 450 ? 1 + Math.sin(((performance.now() - born - 300) / 150) * Math.PI) * 0.12 : 1;
      const sc = 1.15 * (this.reduced ? 1 : 1 + (1 - lp) * Math.sin(lp * Math.PI) * 0.35);
      ctx.scale(sc * (2 - squash), sc * squash);
      if (t.id === ui.selected) { ctx.shadowColor = "#ffe066"; ctx.shadowBlur = 18; }
      drawTower(ctx, t.kind, t.level, t.angle, time, t.firing, r, t.branch);
      ctx.restore();
      if (t.disabled) {
        ctx.save(); ctx.translate(px(t.x), px(t.y) - 30); ctx.fillStyle = "#ffe066";
        for (let i = 0; i < 3; i++) { const a = time * 7 + (i * TAU) / 3; ctx.beginPath(); ctx.arc(Math.cos(a) * 10, Math.sin(a) * 3, 2.4, 0, TAU); ctx.fill(); }
        ctx.fillStyle = "rgba(60,60,60,0.5)"; ctx.beginPath(); ctx.arc(4, 8, 7 + Math.sin(time * 5) * 2, 0, TAU); ctx.fill();
        ctx.restore();
      } else if (t.jammed < 1) {
        ctx.save(); ctx.fillStyle = "rgba(122,255,58,0.7)"; ctx.font = "900 12px Inter, sans-serif"; ctx.textAlign = "center"; ctx.fillText("~gestört~", px(t.x), px(t.y) - 26); ctx.restore();
      }
      if (t.firing) {
        const target = e.enemies.find((en) => en.id === t.target);
        if (target) this.laser(t, target, time);
      }
    }
    for (const en of air) { en.engineTime = e.time; drawEnemy(ctx, en, time, this.atlas, e.visible(en)); }
    for (const p of e.projectiles) this.projectile(p, time);
    this.drawBolts(dt);
    this.drawAmbient(time, dt);
    this.drawFx(dt);
    ctx.restore();
    this.drawSky(time);
    if (this.flash > 0) { ctx.fillStyle = `rgba(${this.flashColor},${this.flash * 0.22})`; ctx.fillRect(0, 0, W, H); this.flash = Math.max(0, this.flash - dt * 1.8); }
    this.drawHud(time, dt);
    this.drawBanners(dt);
    this.drawCards(dt);
  }

  // "NEU!" cards introduce each enemy type the first time it shows up.
  drawCards(dt) {
    const ctx = this.ctx;
    this.cards = this.cards.filter((c) => c.age < c.life);
    this.cards.slice(0, 3).forEach((c, i) => {
      c.age += dt;
      const spec = ENEMIES[c.kind], box = ATLAS[spec.sprite || c.kind];
      const slide = Math.min(1, c.age / 0.35), out = c.age > c.life - 0.4 ? (c.age - (c.life - 0.4)) / 0.4 : 0;
      const x = 12 - (1 - easeOutBack(slide)) * 260 - out * 260, y = 60 + i * 74;
      ctx.save();
      ctx.fillStyle = "rgba(255,244,220,0.95)"; ctx.strokeStyle = "#7a4a24"; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.roundRect(x, y, 250, 66, 12); ctx.fill(); ctx.stroke();
      if (this.atlas.complete && box) { const h = 56, w = h * (box[2] / box[3]); ctx.drawImage(this.atlas, box[0], box[1], box[2], box[3], x + 34 - w / 2, y + 5, w, h); }
      ctx.fillStyle = "#d8402a"; ctx.font = "italic 900 11px Inter, sans-serif"; ctx.fillText("NEU!", x + 72, y + 18);
      ctx.fillStyle = "#4a2a12"; ctx.font = "900 15px Inter, sans-serif"; ctx.fillText(spec.name, x + 72, y + 35);
      ctx.fillStyle = "#7a5a3a"; ctx.font = "600 11.5px Inter, sans-serif"; ctx.fillText(spec.desc.length > 34 ? spec.desc.slice(0, 33) + "…" : spec.desc, x + 72, y + 53);
      ctx.restore();
    });
  }

  rangeCircle(c, r, range, color) {
    const ctx = this.ctx;
    ctx.save();
    ctx.fillStyle = color.replace("0.9", "0.08"); ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.setLineDash([8, 6]);
    ctx.beginPath(); ctx.arc(px(c), px(r), range * T, 0, TAU); ctx.fill(); ctx.stroke();
    ctx.restore();
  }

  drawNest(time, dt) {
    const ctx = this.ctx, e = this.engine;
    this.nestShake = Math.max(0, this.nestShake - dt);
    const x = px(NEST.x) + 16 + Math.sin(time * 60) * this.nestShake * 6, y = px(NEST.y);
    ctx.save(); ctx.translate(x, y);
    ctx.fillStyle = "rgba(0,0,0,0.35)"; ctx.beginPath(); ctx.ellipse(0, 18, 46, 14, 0, 0, TAU); ctx.fill();
    ctx.fillStyle = "#8a5a2a"; ctx.beginPath(); ctx.ellipse(0, 8, 44, 22, 0, 0, TAU); ctx.fill();
    ctx.strokeStyle = "#c89050"; ctx.lineWidth = 2;
    for (let i = 0; i < 26; i++) { const a = (i / 26) * TAU; ctx.beginPath(); ctx.moveTo(Math.cos(a) * 30, 8 + Math.sin(a) * 14); ctx.lineTo(Math.cos(a + 0.4) * 46, 8 + Math.sin(a + 0.4) * 22); ctx.stroke(); }
    ctx.fillStyle = "#5a3a18"; ctx.beginPath(); ctx.ellipse(0, 4, 32, 14, 0, 0, TAU); ctx.fill();
    const eggs = Math.max(0, e.eggs);
    for (let i = 0; i < Math.min(eggs, 20); i++) {
      const row = Math.floor(i / 7), col = i % 7;
      const ex = -24 + col * 8 + (row % 2) * 4, ey = 2 - row * 6;
      const gl = ctx.createRadialGradient(ex - 1.5, ey - 2, 0.5, ex, ey, 6);
      gl.addColorStop(0, "#ffffff"); gl.addColorStop(0.5, eggs <= 5 ? "#ffd0d0" : "#fff1d0"); gl.addColorStop(1, "#c8a070");
      ctx.fillStyle = gl; ctx.beginPath(); ctx.ellipse(ex, ey, 4, 5.2, 0, 0, TAU); ctx.fill();
    }
    ctx.restore();
    if (eggs <= 5 && e.status === "playing") {
      ctx.save(); ctx.strokeStyle = `rgba(255,60,80,${0.5 + Math.sin(time * 8) * 0.4})`; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.ellipse(x, y + 6, 54, 30, 0, 0, TAU); ctx.stroke(); ctx.restore();
    }
  }

  laser(t, target, time) {
    const ctx = this.ctx;
    const heat = Math.min(1, t.heat / 4);
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    const sx = px(t.x) + Math.cos(t.angle) * 24, sy = px(t.y) - 6 + Math.sin(t.angle) * 24, tx = px(target.x), ty = px(target.y);
    for (const [w, a] of [[10 + heat * 10, 0.25], [4 + heat * 4, 0.6], [1.6, 1]]) {
      ctx.strokeStyle = `rgba(${Math.round(160 + 95 * heat)},${Math.round(80 * (1 - heat))},255,${a})`; ctx.lineWidth = w + Math.sin(time * 50) * 1.2;
      ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(tx, ty); ctx.stroke();
    }
    ctx.restore();
    if (Math.random() < 0.5) this.burst(tx, ty, 1, ["#c48bff", "#ffffff"], 0.4);
  }

  projectile(p, time) {
    const ctx = this.ctx, x = px(p.x), y = px(p.y);
    ctx.save();
    if (p.kind === "shell") {
      if (p.t < 0) { ctx.restore(); return; }
      const h = (p.h || 0) * T * (p.mini ? 0.4 : 1);
      ctx.fillStyle = "rgba(0,0,0,0.3)"; ctx.beginPath(); ctx.ellipse(x, y + 6, 6, 3, 0, 0, TAU); ctx.fill();
      ctx.translate(x, y - h); ctx.rotate(time * 10);
      const g = ctx.createRadialGradient(-2, -2, 0.5, 0, 0, 6); g.addColorStop(0, "#fff"); g.addColorStop(1, p.mini ? "#ff9a2a" : "#e85a5a");
      ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(0, 0, p.mini ? 3.5 : 6, p.mini ? 4.5 : 7.5, 0, 0, TAU); ctx.fill();
      ctx.strokeStyle = "#7a2a1a"; ctx.lineWidth = 1; ctx.stroke();
    } else if (p.kind === "gatling") {
      ctx.fillStyle = p.branch === "mutation" ? "#7aff5a" : p.branch === "explosive" ? "#ff9a2a" : "#ffe066";
      ctx.beginPath(); ctx.arc(x, y, 2.6, 0, TAU); ctx.fill();
    } else if (p.kind === "frost") {
      ctx.fillStyle = "#e8fbff"; ctx.shadowColor = "#7ad8ff"; ctx.shadowBlur = 10; ctx.beginPath(); ctx.arc(x, y, p.branch === "shards" ? 3.5 : 5, 0, TAU); ctx.fill();
    } else if (p.kind === "wizard") {
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createRadialGradient(x, y, 0.5, x, y, 10); g.addColorStop(0, "#ffffff"); g.addColorStop(0.35, p.branch === "freezeEggs" ? "#7ad8ff" : "#d08aff"); g.addColorStop(1, "rgba(160,74,255,0)");
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, 10, 0, TAU); ctx.fill();
      if (Math.random() < 0.4) this.burst(x, y, 1, ["#d08aff"], 0.2);
    } else if (p.kind === "star") {
      if (p.t < 0) { ctx.restore(); return; }
      const k = Math.min(1, p.t / p.dur);
      const sx = px(p.sx + (p.tx - p.sx) * k), sy = px(p.sy + (p.ty - p.sy) * k);
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createLinearGradient(sx - 60, sy - 160, sx, sy); g.addColorStop(0, "rgba(255,240,160,0)"); g.addColorStop(1, "rgba(255,240,160,0.9)");
      ctx.strokeStyle = g; ctx.lineWidth = 6; ctx.beginPath(); ctx.moveTo(sx - 60, sy - 160); ctx.lineTo(sx, sy); ctx.stroke();
      ctx.fillStyle = "#fff8c0"; ctx.translate(sx, sy); ctx.rotate(time * 8);
      ctx.beginPath(); for (let i = 0; i < 10; i++) { const r = i % 2 ? 4 : 10; ctx.lineTo(Math.cos((i / 10) * TAU) * r, Math.sin((i / 10) * TAU) * r); } ctx.fill();
    } else if (p.kind === "archer") {
      ctx.translate(x, y); ctx.rotate(p.angle || 0); ctx.strokeStyle = "#6a4420"; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(-10, 0); ctx.lineTo(6, 0); ctx.stroke();
      ctx.fillStyle = "#c0c8d0"; ctx.beginPath(); ctx.moveTo(9, 0); ctx.lineTo(4, -3); ctx.lineTo(4, 3); ctx.fill(); ctx.fillStyle = "#3a8a2a"; ctx.fillRect(-11, -2.5, 4, 5);
    } else if (p.kind === "beekeeper") {
      ctx.translate(x, y); const f = Math.sin(time * 60) * 2;
      ctx.fillStyle = "rgba(255,255,255,0.7)"; ctx.beginPath(); ctx.ellipse(-1, -3, 3, 2 + f * 0.3, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = "#ffcf2a"; ctx.beginPath(); ctx.ellipse(0, 0, 4, 3, 0, 0, TAU); ctx.fill(); ctx.fillStyle = "#1a1a1a"; ctx.fillRect(-1, -3, 1.5, 6);
    } else if (p.kind === "chef") {
      ctx.translate(x, y); ctx.rotate(time * 10); ctx.fillStyle = "#c86a2a"; ctx.beginPath(); ctx.ellipse(0, 0, 6, 4, 0, 0, TAU); ctx.fill(); ctx.fillStyle = "#fff"; ctx.fillRect(4, -1, 5, 2);
    } else if (p.kind === "bakery") {
      ctx.translate(x, y); ctx.rotate(time * 8); ctx.strokeStyle = "#ff7ab8"; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(0, 0, 5, 0, TAU); ctx.stroke(); ctx.strokeStyle = "#e8a060"; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(0, 0, 7, 0, TAU); ctx.stroke();
    } else if (p.kind === "paintball") {
      const col = ["#ff3ab8", "#3ae8ff", "#ffe03a", "#7aff3a"][p.id % 4];
      ctx.fillStyle = col; ctx.beginPath(); ctx.arc(x, y, 4, 0, TAU); ctx.fill(); ctx.fillStyle = "rgba(255,255,255,0.7)"; ctx.beginPath(); ctx.arc(x - 1.5, y - 1.5, 1.4, 0, TAU); ctx.fill();
    } else if (p.kind === "bubble") {
      ctx.strokeStyle = "rgba(200,240,255,0.9)"; ctx.lineWidth = 1.5; ctx.fillStyle = "rgba(160,220,255,0.25)";
      ctx.beginPath(); ctx.arc(x, y, 7, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(x - 2.5, y - 2.5, 1.6, 0, TAU); ctx.fill();
    } else if (p.kind === "vampire") {
      ctx.translate(x, y); const f = Math.sin(time * 40) * 0.6; ctx.fillStyle = "#2a0a1a";
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(-6, -6 * f - 2, -10, 0); ctx.quadraticCurveTo(-5, 1, 0, 2); ctx.quadraticCurveTo(5, 1, 10, 0); ctx.quadraticCurveTo(6, -6 * f - 2, 0, 0); ctx.fill();
      ctx.fillStyle = "#ff2a4a"; ctx.fillRect(-1.5, -1, 1, 1); ctx.fillRect(0.5, -1, 1, 1);
    } else if (p.kind === "ghost") {
      ctx.globalCompositeOperation = "lighter"; const g = ctx.createRadialGradient(x, y, 0, x, y, 10); g.addColorStop(0, "#ffffff"); g.addColorStop(0.4, "#9af0ff"); g.addColorStop(1, "rgba(120,220,255,0)");
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, 10, 0, TAU); ctx.fill();
    } else if (p.kind === "necro") {
      ctx.translate(x, y); ctx.rotate(time * 12); ctx.fillStyle = "#f0e8d8"; ctx.fillRect(-6, -1.5, 12, 3); ctx.beginPath(); ctx.arc(-6, -2, 2, 0, TAU); ctx.arc(-6, 2, 2, 0, TAU); ctx.arc(6, -2, 2, 0, TAU); ctx.arc(6, 2, 2, 0, TAU); ctx.fill();
    } else if (p.kind === "viking") {
      ctx.translate(x, y); ctx.rotate(time * 16); ctx.strokeStyle = "#6a4420"; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.moveTo(-6, 0); ctx.lineTo(6, 0); ctx.stroke();
      ctx.fillStyle = "#c0c8d0"; ctx.beginPath(); ctx.moveTo(4, -6); ctx.quadraticCurveTo(10, 0, 4, 6); ctx.lineTo(3, 0); ctx.closePath(); ctx.fill();
    } else if (p.kind === "portal") {
      ctx.translate(x, y); ctx.rotate(time * 10); ctx.strokeStyle = "#b08aff"; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.arc(0, 0, 6, 0, 4.5); ctx.stroke(); ctx.fillStyle = "#2a0a4a"; ctx.beginPath(); ctx.arc(0, 0, 3.5, 0, TAU); ctx.fill();
    } else if (p.kind === "rocket") {
      ctx.translate(x, y); ctx.rotate(p.angle || 0);
      ctx.fillStyle = "#e8e0d0"; ctx.fillRect(-7, -2.5, 12, 5); ctx.fillStyle = "#d82a2a"; ctx.beginPath(); ctx.moveTo(5, -2.5); ctx.lineTo(9, 0); ctx.lineTo(5, 2.5); ctx.fill();
      ctx.fillStyle = "#ffcf4a"; ctx.beginPath(); ctx.moveTo(-7, -2); ctx.lineTo(-13 - Math.random() * 4, 0); ctx.lineTo(-7, 2); ctx.fill();
      if (Math.random() < 0.6) this.fx.push({ kind: "smoke", x: x - Math.cos(p.angle || 0) * 10, y: y - Math.sin(p.angle || 0) * 10, vx: 0, vy: -6, age: 0, life: 0.5, size: 4 });
    }
    ctx.restore();
  }

  drawZones(time) {
    const ctx = this.ctx;
    for (const z of this.engine.zones) {
      const left = Math.max(0, (z.until - this.engine.time) / z.time);
      const x = px(z.x), y = px(z.y), r = z.r * T;
      ctx.save(); ctx.globalAlpha = Math.min(1, left * 2) * 0.75;
      const g = ctx.createRadialGradient(x, y, 2, x, y, r);
      if (z.kind === "toxic") { g.addColorStop(0, "rgba(140,255,80,0.55)"); g.addColorStop(1, "rgba(60,160,30,0)"); }
      else if (z.kind === "ash") { g.addColorStop(0, "rgba(120,110,110,0.6)"); g.addColorStop(1, "rgba(60,50,50,0)"); }
      else { g.addColorStop(0, "rgba(255,200,60,0.6)"); g.addColorStop(0.5, "rgba(255,90,20,0.45)"); g.addColorStop(1, "rgba(160,20,0,0)"); }
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
      for (let i = 0; i < 6; i++) {
        const a = i * 1.7 + z.x, d = ((time * 0.6 + i * 0.37) % 1);
        const bx = x + Math.cos(a) * r * 0.55, by = y + Math.sin(a) * r * 0.4 - d * 14;
        ctx.fillStyle = z.kind === "toxic" ? `rgba(180,255,120,${1 - d})` : `rgba(255,${160 + Math.round(80 * d)},40,${1 - d})`;
        ctx.beginPath(); ctx.arc(bx, by, z.kind === "toxic" ? 3 : 4 * (1 - d) + 1, 0, TAU); ctx.fill();
      }
      ctx.restore();
    }
  }

  drawBolts(dt) {
    const ctx = this.ctx;
    this.bolts = this.bolts.filter((b) => b.age < b.life);
    for (const b of this.bolts) {
      b.age += dt;
      ctx.save(); ctx.globalCompositeOperation = "lighter"; ctx.globalAlpha = 1 - b.age / b.life;
      if (b.tracer) {
        ctx.strokeStyle = "rgba(255,230,140,0.9)"; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.moveTo(b.points[0].x, b.points[0].y); ctx.lineTo(b.points[1].x, b.points[1].y); ctx.stroke();
        ctx.restore(); continue;
      }
      const palette = b.magic ? [[8, "rgba(200,120,255,0.5)"], [3, "#e0b0ff"], [1.2, "#ffffff"]] : [[8, "rgba(90,184,255,0.5)"], [3, "#9ad8ff"], [1.2, "#ffffff"]];
      for (const [w, color] of palette) {
        ctx.strokeStyle = color; ctx.lineWidth = w; ctx.beginPath();
        b.points.forEach((p, i) => {
          if (!i) { ctx.moveTo(p.x, p.y - 8); return; }
          const prev = b.points[i - 1];
          for (let k = 1; k <= 4; k++) { const t = k / 4; ctx.lineTo(prev.x + (p.x - prev.x) * t + (k < 4 ? (Math.random() - 0.5) * 16 : 0), prev.y + (p.y - prev.y) * t + (k < 4 ? (Math.random() - 0.5) * 16 : 0)); }
        });
        ctx.stroke();
      }
      ctx.restore();
    }
  }

  drawFx(dt) {
    const ctx = this.ctx;
    this.fx = this.fx.filter((f) => f.age < f.life);
    for (const f of this.fx) {
      f.age += dt; f.x += f.vx * dt; f.y += f.vy * dt;
      if (f.kind === "casing" || f.kind === "debris") { f.vy += 420 * dt; f.vx *= 0.97; }
      if (f.kind !== "text" && f.kind !== "ring" && f.kind !== "smoke") { f.vx *= 0.95; f.vy = f.vy * 0.95 + (f.kind === "feather" || f.kind === "flake" ? 40 : 260) * dt; }
      const k = Math.max(0, Math.min(1, f.age / f.life));
      ctx.save(); ctx.globalAlpha = Math.max(0, 1 - k);
      if (f.kind === "text") {
        const pop = Math.min(1, f.age / 0.15);
        ctx.translate(f.x, f.y); ctx.scale(0.6 + 0.5 * easeOutBack(pop), 0.6 + 0.5 * easeOutBack(pop));
        ctx.font = `italic 900 ${f.size}px Inter, Segoe UI, sans-serif`; ctx.textAlign = "center";
        ctx.lineWidth = 4; ctx.strokeStyle = "#1a1008"; ctx.strokeText(f.text, 0, 0); ctx.fillStyle = f.color; ctx.fillText(f.text, 0, 0);
      } else if (f.kind === "ring") {
        ctx.strokeStyle = f.color; ctx.lineWidth = 4 * (1 - k) + 1; ctx.beginPath(); ctx.arc(f.x, f.y, 4 + f.size * k, 0, TAU); ctx.stroke();
      } else if (f.kind === "flash") {
        ctx.globalCompositeOperation = "lighter"; ctx.translate(f.x, f.y); ctx.rotate(f.angle || 0);
        const g = ctx.createRadialGradient(0, 0, 0, 0, 0, f.size);
        g.addColorStop(0, "#ffffff"); g.addColorStop(0.4, f.color); g.addColorStop(1, "rgba(255,200,80,0)");
        ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(f.size * 1.6, 0); ctx.lineTo(0, -f.size * 0.6); ctx.lineTo(-f.size * 0.4, 0); ctx.lineTo(0, f.size * 0.6); ctx.closePath(); ctx.fill();
        ctx.beginPath(); ctx.arc(0, 0, f.size * 0.7, 0, TAU); ctx.fill();
      } else if (f.kind === "slash") {
        ctx.globalCompositeOperation = "lighter"; ctx.translate(f.x, f.y); ctx.rotate(f.angle);
        ctx.strokeStyle = f.color; ctx.lineWidth = 5 * (1 - k) + 1; ctx.shadowColor = f.color; ctx.shadowBlur = 12;
        ctx.beginPath(); ctx.arc(0, 0, f.size, -0.9 + k * 1.6, 0.6 + k * 1.6); ctx.stroke();
      } else if (f.kind === "casing") {
        ctx.translate(f.x, f.y); ctx.rotate(f.age * f.spin); ctx.fillStyle = "#e8b020"; ctx.fillRect(-1, -2.5, 2, 5);
      } else if (f.kind === "debris") {
        ctx.translate(f.x, f.y); ctx.rotate(f.age * 12); ctx.fillStyle = f.color; ctx.fillRect(-f.size / 2, -f.size / 2, f.size, f.size * 0.7);
      } else if (f.kind === "glow") {
        ctx.globalCompositeOperation = "lighter";
        const g = ctx.createRadialGradient(f.x, f.y, 0, f.x, f.y, f.size);
        g.addColorStop(0, `rgba(${f.color},0.75)`); g.addColorStop(1, `rgba(${f.color},0)`);
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(f.x, f.y, f.size, 0, TAU); ctx.fill();
      } else if (f.kind === "poof") {
        ctx.fillStyle = "rgba(255,255,255,0.75)";
        for (let i = 0; i < 6; i++) { const a = (i / 6) * TAU; ctx.beginPath(); ctx.arc(f.x + Math.cos(a) * f.size * k, f.y + Math.sin(a) * f.size * 0.6 * k, f.size * 0.35 * (1 - k * 0.5), 0, TAU); ctx.fill(); }
      } else if (f.kind === "pillar") {
        ctx.globalCompositeOperation = "lighter";
        const g = ctx.createLinearGradient(f.x, f.y - 260, f.x, f.y);
        g.addColorStop(0, "rgba(255,240,160,0)"); g.addColorStop(1, f.color);
        ctx.fillStyle = g; const w = f.size * (1 - k);
        ctx.fillRect(f.x - w / 2, f.y - 260, w, 270);
      } else if (f.kind === "coinfly") {
        if (f.age < 0) { ctx.restore(); continue; }
        const a = this.hudAnchor(), t = Math.min(1, f.age / f.life);
        const e2 = t * t;
        const cx = f.sx + f.ox * Math.sin(t * Math.PI) + (a.x - f.sx) * e2, cy = f.sy + f.oy * Math.sin(t * Math.PI) + (a.y - f.sy) * e2;
        ctx.globalAlpha = 1;
        ctx.translate(cx, cy); ctx.scale(Math.abs(Math.cos(f.age * 14)) + 0.15, 1);
        ctx.fillStyle = "#ffd34a"; ctx.beginPath(); ctx.arc(0, 0, f.size, 0, TAU); ctx.fill(); ctx.strokeStyle = "#8a5200"; ctx.lineWidth = 1; ctx.stroke();
        if (t >= 0.98 && !f.counted) { f.counted = true; this.hudPulse = 1; }
      } else if (f.kind === "vortex") {
        ctx.translate(f.x, f.y); ctx.rotate(f.age * 12);
        ctx.strokeStyle = "rgba(160,74,255,0.8)"; ctx.lineWidth = 3;
        for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(0, 0, Math.max(0.1, f.size * (1 - k) * (0.4 + i * 0.25)), i * 2, i * 2 + 2.4); ctx.stroke(); }
      } else if (f.kind === "smoke") {
        ctx.fillStyle = "rgba(80,70,60,0.5)"; ctx.beginPath(); ctx.arc(f.x, f.y, f.size * (0.6 + k), 0, TAU); ctx.fill();
      } else if (f.kind === "pop") { // popcorn
        ctx.translate(f.x, f.y); ctx.rotate(f.age * f.spin); ctx.fillStyle = f.color;
        for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.arc(Math.cos(i * 1.6) * f.size * 0.6, Math.sin(i * 1.6) * f.size * 0.6, f.size * 0.7, 0, TAU); ctx.fill(); }
      } else if (f.kind === "feather") {
        ctx.translate(f.x, f.y); ctx.rotate(Math.sin(f.age * 6) * 0.8); ctx.fillStyle = f.color;
        ctx.beginPath(); ctx.ellipse(0, 0, f.size * 1.6, f.size * 0.6, 0, 0, TAU); ctx.fill();
      } else if (f.kind === "coin") {
        ctx.translate(f.x, f.y); ctx.scale(Math.abs(Math.cos(f.age * 12)) + 0.1, 1); ctx.fillStyle = f.color; ctx.beginPath(); ctx.arc(0, 0, f.size, 0, TAU); ctx.fill();
      } else if (f.kind === "star") {
        ctx.translate(f.x, f.y); ctx.rotate(f.age * f.spin); ctx.fillStyle = f.color; ctx.globalCompositeOperation = "lighter";
        ctx.beginPath(); for (let i = 0; i < 8; i++) { const r = i % 2 ? f.size * 0.35 : f.size; ctx.lineTo(Math.cos((i / 8) * TAU) * r, Math.sin((i / 8) * TAU) * r); } ctx.fill();
      } else {
        ctx.translate(f.x, f.y); ctx.rotate(f.age * f.spin); ctx.fillStyle = f.color;
        if (f.kind === "fluff" || f.kind === "flake") { ctx.beginPath(); ctx.arc(0, 0, f.size, 0, TAU); ctx.fill(); }
        else { ctx.globalCompositeOperation = "lighter"; ctx.fillRect(-f.size / 2, -f.size / 2, f.size, f.size); }
      }
      ctx.restore();
    }
  }

  // The sky darkens with the waves: day, dusk, night, blood moon.
  drawSky(time) {
    const ctx = this.ctx, w = this.engine.wave;
    if (w < 4) return;
    let color, a;
    if (w < 9) { color = "255,140,60"; a = 0.05 + (w - 4) * 0.015; }
    else if (w < 16) { color = "30,40,120"; a = 0.12 + (w - 9) * 0.015; }
    else { color = "160,10,30"; a = Math.min(0.32, 0.16 + (w - 16) * 0.01) + Math.sin(time * 2.4) * 0.03; }
    const g = ctx.createRadialGradient(W / 2, H / 2, H * 0.2, W / 2, H / 2, W * 0.7);
    g.addColorStop(0, `rgba(${color},${a * 0.4})`); g.addColorStop(1, `rgba(${color},${a * 1.6})`);
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
  }

  drawBanners(dt) {
    const ctx = this.ctx;
    this.banners = this.banners.filter((b) => b.age < b.life);
    for (const b of this.banners) b.age += dt;
    const b = this.banners.at(-1);
    if (!b) return;
    const t = b.age / b.life, appear = Math.min(1, b.age / 0.3);
    const scale = (this.reduced ? 1 : 2.3 - 1.3 * easeOutBack(appear)) * b.big;
    ctx.save();
    ctx.globalAlpha = t > 0.78 ? Math.max(0, 1 - (t - 0.78) / 0.22) : 1;
    ctx.translate(W / 2, H * 0.4); ctx.scale(scale, scale); ctx.rotate(-0.04);
    ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.font = "italic 900 58px Inter, Segoe UI, sans-serif";
    ctx.lineWidth = 10; ctx.strokeStyle = "rgba(20,10,4,0.9)"; ctx.strokeText(b.text, 0, 0);
    ctx.shadowColor = b.color; ctx.shadowBlur = 24; ctx.fillStyle = b.color; ctx.fillText(b.text, 0, 0); ctx.shadowBlur = 0;
    if (b.sub) { ctx.font = "800 18px Inter, Segoe UI, sans-serif"; ctx.lineWidth = 5; ctx.strokeText(b.sub, 0, 44); ctx.fillStyle = "#fff"; ctx.fillText(b.sub, 0, 44); }
    ctx.restore();
  }
}
