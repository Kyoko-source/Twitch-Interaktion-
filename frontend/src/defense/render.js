import { BLOCKED, COLS, ENEMIES, NEST, PATHS, ROWS, SECOND_PATH_WAVE, towerStats } from "./engine.mjs";

export const T = 48;
export const W = COLS * T, H = ROWS * T;
const TAU = Math.PI * 2;
const px = (v) => (v + 0.5) * T;
const easeOutBack = (t) => { const c = 1.9; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); };

function seeded(seed) { return () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }; }

export const TOWER_COLORS = {
  gatling: { body: "#fffaf0", ring: "#ffb000", accent: "#e8b020", badge: "#ff4a3a" },
  frost: { body: "#eef9ff", ring: "#7ad8ff", accent: "#2a6ad0", badge: "#3a8aff" },
  mortar: { body: "#fff1dc", ring: "#c8902a", accent: "#4a4a52", badge: "#a8402a" },
  sniper: { body: "#fffaf0", ring: "#6aa83a", accent: "#2f5a20", badge: "#e85a20" },
  wizard: { body: "#fffaf0", ring: "#b56cff", accent: "#5a2aa8", badge: "#8a3aff" },
  golden: { body: "#ffd34a", ring: "#ffe066", accent: "#ffcf4a", badge: "#ff9a00" },
  tesla: { body: "#fffaf0", ring: "#5ab8ff", accent: "#ffe066", badge: "#2a7aff" },
  rocket: { body: "#fff1dc", ring: "#ff5a3a", accent: "#d82a2a", badge: "#c8202a" },
  medic: { body: "#fffaf0", ring: "#5dff8c", accent: "#ff3b3b", badge: "#2ab84a" },
  dark: { body: "#3a2a4a", ring: "#a04aff", accent: "#7a2aff", badge: "#5a1aa8" },
};

function shade(hex, f = 0.7) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.round(((n >> 16) & 255) * f), g = Math.round(((n >> 8) & 255) * f), b = Math.round((n & 255) * f);
  return `rgb(${r},${g},${b})`;
}

function goggles(ctx, hx, hy, face, color = "#1a1a22") {
  ctx.fillStyle = color; ctx.strokeStyle = "#5a3a20"; ctx.lineWidth = 1.2;
  ctx.beginPath(); ctx.arc(hx + face * 1.5, hy - 2, 3.2, 0, TAU); ctx.arc(hx + face * 6, hy - 2, 3, 0, TAU); ctx.fill(); ctx.stroke();
  ctx.fillStyle = "rgba(140,220,255,0.8)"; ctx.beginPath(); ctx.arc(hx + face * 1, hy - 3, 1.2, 0, TAU); ctx.arc(hx + face * 5.5, hy - 3, 1.1, 0, TAU); ctx.fill();
}

// Chicken towers drawn procedurally. (0,0) is the tile centre; ~ 44 px wide.
export function drawTower(ctx, kind, level = 1, angle = -Math.PI / 2, time = 0, firing = false, recoil = 0, branch = null) {
  const col = TOWER_COLORS[kind];
  ctx.save();
  // pedestal: stone ring, gold for the golden chicken, purple for dark matter, sandbags for mortar
  ctx.fillStyle = "rgba(0,0,0,0.3)"; ctx.beginPath(); ctx.ellipse(0, 14, 21, 7, 0, 0, TAU); ctx.fill();
  const stone = ctx.createLinearGradient(0, -4, 0, 16);
  if (kind === "golden") { stone.addColorStop(0, "#ffe680"); stone.addColorStop(1, "#b07800"); }
  else if (kind === "dark") { stone.addColorStop(0, "#7a5a9a"); stone.addColorStop(1, "#2a1a3a"); }
  else if (kind === "frost") { stone.addColorStop(0, "#e0f4ff"); stone.addColorStop(1, "#6a8aa8"); }
  else if (kind === "sniper") { stone.addColorStop(0, "#8a6a40"); stone.addColorStop(1, "#4a3420"); }
  else { stone.addColorStop(0, "#a8acb8"); stone.addColorStop(1, "#4a4e5c"); }
  ctx.fillStyle = stone; ctx.beginPath(); ctx.ellipse(0, 8, 20, 9, 0, 0, TAU); ctx.fill();
  ctx.strokeStyle = "rgba(0,0,0,0.25)"; ctx.lineWidth = 1;
  for (let i = -2; i <= 2; i++) { ctx.beginPath(); ctx.moveTo(i * 8, 2); ctx.lineTo(i * 8.5, 15); ctx.stroke(); }
  ctx.strokeStyle = col.ring; ctx.lineWidth = branch ? 3.5 : 2.5;
  if (branch) { ctx.shadowColor = col.ring; ctx.shadowBlur = 10 + Math.sin(time * 4) * 4; }
  ctx.beginPath(); ctx.ellipse(0, 7, 18, 8, 0, 0, TAU); ctx.stroke(); ctx.shadowBlur = 0;
  // banner with level pips (branch = crown pip)
  ctx.fillStyle = col.badge; ctx.beginPath(); ctx.moveTo(-7, 9); ctx.lineTo(7, 9); ctx.lineTo(7, 19); ctx.lineTo(0, 16); ctx.lineTo(-7, 19); ctx.closePath(); ctx.fill();
  ctx.strokeStyle = "#ffe8a0"; ctx.lineWidth = 1; ctx.stroke();
  const pips = Math.min(level, 3);
  for (let i = 0; i < pips; i++) { ctx.fillStyle = "#ffe066"; ctx.beginPath(); ctx.arc(-4 + i * 4, 12.5, 1.5, 0, TAU); ctx.fill(); }
  if (branch) { ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.moveTo(-4, 15); ctx.lineTo(-3, 13); ctx.lineTo(0, 14.5); ctx.lineTo(3, 13); ctx.lineTo(4, 15); ctx.fill(); }
  if (kind === "golden") { // golden eggs heap
    for (let i = 0; i < 6; i++) { const ex = -14 + i * 5.6, ey = 4 + (i % 2) * 2; const g = ctx.createRadialGradient(ex - 1, ey - 2, 0.5, ex, ey, 4); g.addColorStop(0, "#fff8d0"); g.addColorStop(1, "#d89a00"); ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(ex, ey, 3.2, 4, 0, 0, TAU); ctx.fill(); }
  }
  const bob = Math.sin(time * 4 + kind.length) * 1.2;
  ctx.translate(0, bob - recoil * 2);
  const face = Math.cos(angle) >= 0 ? 1 : -1;
  // aura effects behind the body
  if (kind === "dark") {
    ctx.save(); ctx.rotate(time * 2);
    const g = ctx.createRadialGradient(0, -4, 2, 0, -4, 24); g.addColorStop(0, "rgba(160,74,255,0.5)"); g.addColorStop(1, "rgba(60,0,120,0)");
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, -4, 24, 0, TAU); ctx.fill(); ctx.restore();
  }
  if (kind === "golden") {
    ctx.save(); ctx.globalAlpha = 0.5 + Math.sin(time * 3) * 0.2; ctx.strokeStyle = "#fff3a0"; ctx.lineWidth = 2;
    for (let i = 0; i < 8; i++) { const a = (i / 8) * TAU + time * 0.6; ctx.beginPath(); ctx.moveTo(Math.cos(a) * 16, -6 + Math.sin(a) * 16); ctx.lineTo(Math.cos(a) * 22, -6 + Math.sin(a) * 22); ctx.stroke(); }
    ctx.restore();
  }
  if (kind === "medic") {
    ctx.save(); ctx.globalAlpha = 0.35 + Math.sin(time * 3) * 0.15; ctx.strokeStyle = "#5dff8c"; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(0, -2, 18 + Math.sin(time * 3) * 2, 0, TAU); ctx.stroke(); ctx.restore();
  }
  if (kind === "sniper") { // leafy camouflage
    ctx.fillStyle = "#3a7a2a";
    for (let i = 0; i < 9; i++) { const a = (i / 9) * TAU; ctx.beginPath(); ctx.ellipse(Math.cos(a) * 12, -4 + Math.sin(a) * 9, 5, 3, a, 0, TAU); ctx.fill(); }
  }
  // body
  const bodyCol = kind === "rocket" || kind === "mortar" ? "#fff1dc" : col.body;
  const g = ctx.createRadialGradient(-4, -8, 2, 0, -2, 16);
  g.addColorStop(0, kind === "dark" ? "#8a6aa8" : "#ffffff"); g.addColorStop(0.35, bodyCol); g.addColorStop(1, shade(bodyCol));
  ctx.fillStyle = g; ctx.strokeStyle = "#2a1a10"; ctx.lineWidth = 1.6;
  const size = Math.min(level, 4);
  ctx.beginPath(); ctx.ellipse(0, -2, 12 + size, 10.5 + size * 0.6, 0, 0, TAU); ctx.fill(); ctx.stroke();
  // outfits
  if (kind === "dark") { ctx.fillStyle = "#4a1a7a"; ctx.beginPath(); ctx.moveTo(-15, -8); ctx.quadraticCurveTo(-face * 24, 6, -12, 9); ctx.lineTo(12, 9); ctx.quadraticCurveTo(face * 22, 2, 15, -8); ctx.quadraticCurveTo(0, -2, -15, -8); ctx.fill(); }
  if (kind === "frost") { ctx.fillStyle = "#2a5ab0"; ctx.beginPath(); ctx.ellipse(0, 2, 13, 7, 0, 0, TAU); ctx.fill(); ctx.fillStyle = "#ffffff"; ctx.beginPath(); ctx.ellipse(0, -4, 13, 3, 0, 0, TAU); ctx.fill(); }
  if (kind === "wizard") { ctx.fillStyle = "#5a2aa8"; ctx.beginPath(); ctx.ellipse(0, 3, 14, 7, 0, 0, TAU); ctx.fill(); ctx.fillStyle = "#ffe066"; for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.arc(-8 + i * 5, 3 + (i % 2) * 2, 1.2, 0, TAU); ctx.fill(); } }
  if (kind === "rocket" || kind === "mortar") { ctx.fillStyle = "#7a5030"; ctx.fillRect(-12, -6, 24, 8); ctx.fillStyle = "#c8902a"; ctx.fillRect(-12, -4, 24, 2); }
  if (kind === "medic") { ctx.fillStyle = "#4a8a5a"; ctx.fillRect(-face * 18, -14, 9, 14); ctx.fillStyle = "#fff"; ctx.fillRect(-face * 15.5 - 1, -10, 3, 7); ctx.fillRect(-face * 15.5 - 3, -8, 7, 3); }
  if (kind === "tesla") { ctx.fillStyle = "#6a5040"; ctx.fillRect(-12, -2, 24, 6); }
  // tail feathers
  ctx.fillStyle = kind === "dark" ? "#2a1a3a" : shade(bodyCol);
  ctx.strokeStyle = "#2a1a10"; ctx.lineWidth = 1.4;
  ctx.beginPath(); ctx.moveTo(-face * 11, -6); ctx.lineTo(-face * 20, -14); ctx.lineTo(-face * 17, -2); ctx.lineTo(-face * 21, -6); ctx.lineTo(-face * 12, 2); ctx.closePath(); ctx.fill(); ctx.stroke();
  // wing
  ctx.fillStyle = kind === "dark" ? "#5a3a7a" : shade(bodyCol, 0.88);
  ctx.beginPath(); ctx.ellipse(-face * 2, 0, 7, 5, face * 0.3 + (firing ? Math.sin(time * 40) * 0.3 : kind === "golden" ? Math.sin(time * 6) * 0.4 : 0), 0, TAU); ctx.fill(); ctx.stroke();
  // head
  const hx = face * 9, hy = -13;
  ctx.fillStyle = kind === "dark" ? "#4a3a5a" : col.body; ctx.beginPath(); ctx.arc(hx, hy, 7, 0, TAU); ctx.fill(); ctx.stroke();
  // comb
  ctx.fillStyle = "#ff3b3b";
  if (!["wizard", "frost", "medic", "golden"].includes(kind)) {
    const comb = kind === "tesla" || kind === "dark" ? 1.3 : 1;
    ctx.beginPath(); ctx.arc(hx - 3, hy - 7 * comb + 2, 3 * comb, 0, TAU); ctx.arc(hx + 1, hy - 8 * comb + 2, 3.2 * comb, 0, TAU); ctx.arc(hx + 4, hy - 6 * comb + 2, 2.6 * comb, 0, TAU); ctx.fill();
  }
  // eye + beak
  ctx.fillStyle = "#1a0a10"; ctx.beginPath(); ctx.arc(hx + face * 2.5, hy - 1, 1.8, 0, TAU); ctx.fill();
  ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(hx + face * 3, hy - 1.6, 0.7, 0, TAU); ctx.fill();
  ctx.fillStyle = "#ffad1f"; ctx.beginPath(); ctx.moveTo(hx + face * 6, hy - 1); ctx.lineTo(hx + face * 12, hy + 1); ctx.lineTo(hx + face * 6, hy + 3); ctx.closePath(); ctx.fill();
  // hats and headgear
  if (["gatling", "rocket", "mortar", "tesla", "sniper"].includes(kind)) goggles(ctx, hx, hy, face);
  if (kind === "dark") goggles(ctx, hx, hy, face, "#7a2aff");
  if (kind === "rocket" || kind === "mortar") { ctx.fillStyle = "#7a4a20"; ctx.beginPath(); ctx.arc(hx, hy - 3, 7.2, Math.PI, TAU); ctx.fill(); }
  if (kind === "gatling") { ctx.fillStyle = "#d82a2a"; ctx.beginPath(); ctx.moveTo(hx - face * 4, hy + 5); ctx.lineTo(-face * 16, hy + 2 + Math.sin(time * 10) * 2); ctx.lineTo(hx - face * 4, hy + 8); ctx.fill(); }
  if (kind === "wizard") {
    ctx.fillStyle = "#5a2aa8"; ctx.strokeStyle = "#2a0a5a"; ctx.lineWidth = 1.2;
    ctx.beginPath(); ctx.moveTo(hx - 10, hy - 4); ctx.lineTo(hx + 10, hy - 4); ctx.lineTo(hx - face * 2, hy - 26); ctx.lineTo(hx - face * 8, hy - 20); ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#ffe066"; ctx.beginPath(); ctx.arc(hx, hy - 12, 1.8, 0, TAU); ctx.arc(hx - face * 3, hy - 17, 1.3, 0, TAU); ctx.fill();
  }
  if (kind === "frost") { ctx.fillStyle = "#2a5ab0"; ctx.beginPath(); ctx.arc(hx, hy - 2, 8, Math.PI, TAU); ctx.fill(); ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.ellipse(hx, hy - 2, 9, 2.6, 0, 0, TAU); ctx.fill(); ctx.beginPath(); ctx.arc(hx, hy - 10, 3, 0, TAU); ctx.fill(); goggles(ctx, hx, hy, face, "#1a2a5a"); }
  if (kind === "medic") { ctx.fillStyle = "#fff"; ctx.strokeStyle = "#c8c8c8"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(hx - 7, hy - 5); ctx.lineTo(hx + 7, hy - 5); ctx.lineTo(hx + 5, hy - 12); ctx.lineTo(hx - 5, hy - 12); ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.fillStyle = "#ff3b3b"; ctx.fillRect(hx - 1, hy - 11, 2, 5); ctx.fillRect(hx - 2.5, hy - 9.5, 5, 2); }
  if (kind === "golden") { ctx.fillStyle = "#ffcf4a"; ctx.strokeStyle = "#8a5200"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(hx - 6, hy - 5); ctx.lineTo(hx - 7, hy - 13); ctx.lineTo(hx - 3, hy - 9); ctx.lineTo(hx, hy - 15); ctx.lineTo(hx + 3, hy - 9); ctx.lineTo(hx + 7, hy - 13); ctx.lineTo(hx + 6, hy - 5); ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.fillStyle = "#ff3b8a"; ctx.beginPath(); ctx.arc(hx, hy - 14, 1.6, 0, TAU); ctx.fill(); }
  if (kind === "tesla") { // shoulder coils
    for (const sx of [-14, 14]) { ctx.fillStyle = "#5a6a80"; ctx.fillRect(sx - 2.5, -14, 5, 12); ctx.fillStyle = "#c8a040"; for (let k = 0; k < 3; k++) ctx.fillRect(sx - 3.5, -12 + k * 3.5, 7, 1.6); ctx.fillStyle = "#9ad8ff"; ctx.beginPath(); ctx.arc(sx, -16, 3 + Math.sin(time * 18 + sx) * 0.8, 0, TAU); ctx.fill(); ctx.shadowColor = "#5ab8ff"; ctx.shadowBlur = 10; ctx.fill(); ctx.shadowBlur = 0; }
  }
  // weapon toward the target
  ctx.save();
  ctx.translate(0, -2); ctx.rotate(angle); ctx.translate(-recoil * 4, 0);
  ctx.strokeStyle = "#1a1008"; ctx.lineWidth = 1.4;
  if (kind === "gatling") {
    ctx.fillStyle = "#e8b020"; ctx.beginPath(); ctx.roundRect(0, -6, 12, 12, 3); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#3a3a44";
    const spin = firing || recoil > 0 ? time * 40 : 0;
    for (let i = 0; i < 3; i++) { const o = Math.sin(spin + (i * TAU) / 3) * 3; ctx.fillRect(11, -1.5 + o, 13, 3); }
    if (recoil > 0.5) { ctx.fillStyle = "#ffe066"; ctx.beginPath(); ctx.moveTo(25, 0); ctx.lineTo(32, -4); ctx.lineTo(30, 0); ctx.lineTo(32, 4); ctx.fill(); }
  } else if (kind === "frost") {
    ctx.fillStyle = "#5a6a80"; ctx.fillRect(4, -4, 14, 8); ctx.strokeRect(4, -4, 14, 8);
    ctx.fillStyle = "#bff1ff"; ctx.beginPath(); ctx.moveTo(18, -6); ctx.lineTo(26, 0); ctx.lineTo(18, 6); ctx.closePath(); ctx.fill();
  } else if (kind === "mortar") {
    ctx.fillStyle = "#3a3a42"; ctx.beginPath(); ctx.roundRect(2, -7, 22, 14, 5); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#1a1a1e"; ctx.beginPath(); ctx.ellipse(23, 0, 3, 6, 0, 0, TAU); ctx.fill();
  } else if (kind === "sniper") {
    ctx.fillStyle = "#3a2a1a"; ctx.fillRect(2, -2.5, 30, 5); ctx.strokeRect(2, -2.5, 30, 5);
    ctx.fillStyle = "#1a1a22"; ctx.fillRect(10, -7, 12, 4); ctx.fillStyle = "#7ad8ff"; ctx.fillRect(21, -6.5, 2, 3);
  } else if (kind === "wizard") {
    ctx.strokeStyle = "#7a4a20"; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(4, 4); ctx.lineTo(20, -2); ctx.stroke();
    const glow = ctx.createRadialGradient(22, -3, 0.5, 22, -3, 7); glow.addColorStop(0, "#ffffff"); glow.addColorStop(0.4, "#d08aff"); glow.addColorStop(1, "rgba(160,74,255,0)");
    ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(22, -3, 7 + Math.sin(time * 8) * 1.5, 0, TAU); ctx.fill();
  } else if (kind === "rocket") {
    ctx.fillStyle = "#e8e0d0"; ctx.beginPath(); ctx.roundRect(-2, -7, 26, 14, 6); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#d82a2a"; ctx.fillRect(4, -7, 4, 14); ctx.fillRect(14, -7, 4, 14);
    if (recoil < 0.3) { ctx.fillStyle = "#d82a2a"; ctx.beginPath(); ctx.moveTo(24, -5); ctx.lineTo(31, 0); ctx.lineTo(24, 5); ctx.fill(); }
  } else if (kind === "medic") {
    ctx.fillStyle = "#f0f0f0"; ctx.beginPath(); ctx.moveTo(6, -2); ctx.lineTo(18, -7); ctx.lineTo(18, 7); ctx.lineTo(6, 2); ctx.closePath(); ctx.fill(); ctx.stroke();
  } else if (kind === "dark") {
    const v = ctx.createRadialGradient(20, 0, 1, 20, 0, 9); v.addColorStop(0, "#000"); v.addColorStop(0.5, "#2a0a4a"); v.addColorStop(1, "rgba(160,74,255,0)");
    ctx.fillStyle = v; ctx.beginPath(); ctx.arc(20, 0, 9, 0, TAU); ctx.fill();
    ctx.strokeStyle = "rgba(200,140,255,0.8)"; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(20, 0, 7, time * 6, time * 6 + 4); ctx.stroke();
  }
  ctx.restore();
  ctx.restore();
}

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
  const frozen = e.frozenUntil > now, stunned = e.stunUntil > now;
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
    this.recoil = new Map(); this.nestShake = 0; this.towerBorn = new Map();
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
    base.addColorStop(0, "#3f8a3a"); base.addColorStop(0.5, "#4f9a44"); base.addColorStop(1, "#3a7a36");
    g.fillStyle = base; g.fillRect(0, 0, W, H);
    // checker tint so tiles read
    for (let x = 0; x < COLS; x++) for (let y = 0; y < ROWS; y++) { if ((x + y) % 2) { g.fillStyle = "rgba(255,255,255,0.025)"; g.fillRect(x * T, y * T, T, T); } }
    // grass blades
    for (let i = 0; i < 2600; i++) {
      const x = rnd() * W, y = rnd() * H, h = 3 + rnd() * 6;
      g.strokeStyle = rnd() < 0.5 ? "rgba(120,200,90,0.5)" : "rgba(30,80,30,0.45)"; g.lineWidth = 1;
      g.beginPath(); g.moveTo(x, y); g.lineTo(x + (rnd() - 0.5) * 3, y - h); g.stroke();
    }
    const drawPath = (pts, open) => {
      const line = (w, color) => {
        g.strokeStyle = color; g.lineWidth = w; g.lineCap = "round"; g.lineJoin = "round";
        g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(px(x), px(y)) : g.moveTo(px(x), px(y)))); g.stroke();
      };
      line(T * 0.98, open ? "#5a3f22" : "rgba(60,90,40,0.6)");
      line(T * 0.86, open ? "#a87a48" : "rgba(80,110,50,0.7)");
      line(T * 0.6, open ? "#c39462" : "rgba(90,120,55,0.6)");
    };
    drawPath(PATHS.a, true);
    if (withB) drawPath(PATHS.b, true); else drawPath(PATHS.b, false);
    // pebbles on the paths
    for (let i = 0; i < 420; i++) {
      const x = Math.floor(rnd() * COLS), y = Math.floor(rnd() * ROWS);
      if (!BLOCKED.has(`${x},${y}`)) continue;
      g.fillStyle = rnd() < 0.5 ? "rgba(90,60,30,0.5)" : "rgba(230,200,160,0.4)";
      g.beginPath(); g.arc(x * T + rnd() * T, y * T + rnd() * T, 1 + rnd() * 2.2, 0, TAU); g.fill();
    }
    // flowers and rocks on free tiles
    for (let i = 0; i < 140; i++) {
      const x = rnd() * W, y = rnd() * H;
      if (BLOCKED.has(`${Math.floor(x / T)},${Math.floor(y / T)}`)) continue;
      if (rnd() < 0.75) {
        const colr = ["#ffe066", "#ff8ac8", "#ffffff", "#b48cff"][Math.floor(rnd() * 4)];
        g.fillStyle = colr; for (let k = 0; k < 5; k++) { const a = (k / 5) * TAU; g.beginPath(); g.arc(x + Math.cos(a) * 2.6, y + Math.sin(a) * 2.6, 2, 0, TAU); g.fill(); }
        g.fillStyle = "#ffb000"; g.beginPath(); g.arc(x, y, 1.6, 0, TAU); g.fill();
      } else {
        g.fillStyle = "#7a7e88"; g.beginPath(); g.ellipse(x, y, 5 + rnd() * 5, 3 + rnd() * 3, rnd(), 0, TAU); g.fill();
        g.fillStyle = "rgba(255,255,255,0.25)"; g.beginPath(); g.ellipse(x - 1.5, y - 1.5, 2.5, 1.4, 0, 0, TAU); g.fill();
      }
    }
    // fox den at entrance A
    const den = (x, y) => { g.fillStyle = "#2a1a10"; g.beginPath(); g.ellipse(x, y, 26, 20, 0, 0, TAU); g.fill(); g.fillStyle = "#0a0604"; g.beginPath(); g.ellipse(x + 4, y + 2, 17, 13, 0, 0, TAU); g.fill(); };
    den(px(-0.25), px(2));
    if (withB) den(px(6), px(12.3));
    // soft vignette
    const v = g.createRadialGradient(W / 2, H / 2, H * 0.3, W / 2, H / 2, W * 0.65);
    v.addColorStop(0, "rgba(0,0,0,0)"); v.addColorStop(1, "rgba(0,0,0,0.35)");
    g.fillStyle = v; g.fillRect(0, 0, W, H);
    return c;
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
      case "shoot": this.recoil.set(ev.tower.id, 1); break;
      case "hit": {
        const color = ev.kind === "frost" ? "#bff1ff" : ev.kind === "wizard" ? "#d08aff" : ev.branch === "mutation" ? "#7aff5a" : "#ffe066";
        this.burst(px(ev.x), px(ev.y), ev.kind === "gatling" ? 2 : 6, [color, "#ffffff"], 0.5);
        break;
      }
      case "explode": {
        const x = px(ev.x), y = px(ev.y), r = ev.radius * T;
        if (ev.kind === "shell" || ev.kind === "rocket") {
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
        if (ev.fx === "snow") { this.burst(x, y, 10, ["#ffffff", "#bff1ff"], 0.9, "flake", 2.5); this.ring(x, y, "rgba(200,240,255,0.7)", r, 0.4); }
        else if (ev.fx === "hole") { this.ring(x, y, "#a04aff", r, 0.6); this.fx.push({ kind: "vortex", x, y, vx: 0, vy: 0, age: 0, life: 0.6, size: r }); }
        else { this.ring(x, y, "#c48bff", r, 0.5); this.ring(x, y, "#ffffff", r * 0.6, 0.35); if (!this.reduced) this.shake = Math.max(this.shake, 0.05); }
        break;
      }
      case "freeze": this.burst(px(ev.x), px(ev.y), 12, ["#ffffff", "#bff1ff"], 0.7, "flake", 3); break;
      case "shielded": this.ring(px(NEST.x) + 16, px(NEST.y), "#5dff8c", 70, 0.6); this.text(px(NEST.x), px(NEST.y) - 30, "GEBLOCKT!", "#5dff8c", 18); break;
      case "revive": this.flash = 1; this.flashColor = "93,255,140"; this.banner("WIEDERBELEBT!", "Das Nest bekommt 10 Eier zurück", "#5dff8c", 2.4, 1.2); this.burst(px(NEST.x), px(NEST.y), 50, ["#5dff8c", "#ffffff", "#fff1dc"], 1.4, "feather", 4); break;
      case "kill": {
        const en = ev.enemy, x = px(en.x), y = px(en.y);
        const colors = enemyColors(en.kind);
        this.burst(x, y, ENEMIES[en.kind].boss ? 80 : 14, colors, ENEMIES[en.kind].boss ? 2 : 0.9, "fluff", 3.5);
        this.text(x, y - 10, `+${ev.bounty}`, "#ffe066", ENEMIES[en.kind].boss ? 30 : 15);
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
      case "build": this.towerBorn.set(ev.tower.id, performance.now()); this.burst(px(ev.tower.x), px(ev.tower.y), 14, ["#ffffff", "#fff1dc", "#c8a070"], 0.6, "feather", 3); this.ring(px(ev.tower.x), px(ev.tower.y), "#ffe066", 34); break;
      case "upgrade": this.towerBorn.set(ev.tower.id, performance.now()); this.burst(px(ev.tower.x), px(ev.tower.y), 22, ["#ffe066", "#ffffff"], 0.9, "star", 4); this.ring(px(ev.tower.x), px(ev.tower.y), "#ffe066", 50); this.text(px(ev.tower.x), px(ev.tower.y) - 24, `LEVEL ${ev.tower.level}`, "#ffe066", 16); break;
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
      const pop = born ? Math.min(1, (performance.now() - born) / 450) : 1;
      ctx.save(); ctx.translate(px(t.x), px(t.y) - 4);
      const sc = (this.reduced ? 1 : easeOutBack(pop)) * 1.15;
      ctx.scale(sc, sc);
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
    this.drawFx(dt);
    ctx.restore();
    this.drawSky(time);
    if (this.flash > 0) { ctx.fillStyle = `rgba(${this.flashColor},${this.flash * 0.22})`; ctx.fillRect(0, 0, W, H); this.flash = Math.max(0, this.flash - dt * 1.8); }
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
      const x = 12 - (1 - easeOutBack(slide)) * 260 - out * 260, y = 56 + i * 74;
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
      if (f.kind !== "text" && f.kind !== "ring" && f.kind !== "smoke") { f.vx *= 0.95; f.vy = f.vy * 0.95 + (f.kind === "feather" || f.kind === "flake" ? 40 : 260) * dt; }
      const k = f.age / f.life;
      ctx.save(); ctx.globalAlpha = Math.max(0, 1 - k);
      if (f.kind === "text") {
        const pop = Math.min(1, f.age / 0.15);
        ctx.translate(f.x, f.y); ctx.scale(0.6 + 0.5 * easeOutBack(pop), 0.6 + 0.5 * easeOutBack(pop));
        ctx.font = `italic 900 ${f.size}px Inter, Segoe UI, sans-serif`; ctx.textAlign = "center";
        ctx.lineWidth = 4; ctx.strokeStyle = "#1a1008"; ctx.strokeText(f.text, 0, 0); ctx.fillStyle = f.color; ctx.fillText(f.text, 0, 0);
      } else if (f.kind === "ring") {
        ctx.strokeStyle = f.color; ctx.lineWidth = 4 * (1 - k) + 1; ctx.beginPath(); ctx.arc(f.x, f.y, 4 + f.size * k, 0, TAU); ctx.stroke();
      } else if (f.kind === "vortex") {
        ctx.translate(f.x, f.y); ctx.rotate(f.age * 12);
        ctx.strokeStyle = "rgba(160,74,255,0.8)"; ctx.lineWidth = 3;
        for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(0, 0, f.size * (1 - k) * (0.4 + i * 0.25), i * 2, i * 2 + 2.4); ctx.stroke(); }
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
