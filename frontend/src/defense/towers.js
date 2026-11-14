import { TOWERS } from "./engine.mjs";
// Chicken tower art. Every level changes the look: L1 wooden crate, L2 stone ring,
// L3 fortress with gold trim and flag, L4 (branch) adds a rune circle, a coloured aura
// and branch gear. (0,0) is the tile centre, art is ~48 px wide at scale 1.
const TAU = Math.PI * 2;

export const TOWER_COLORS = {
  gatling: { body: "#fffaf0", ring: "#ffb000", badge: "#ff4a3a" },
  frost: { body: "#eef9ff", ring: "#7ad8ff", badge: "#3a8aff" },
  mortar: { body: "#fff1dc", ring: "#c8902a", badge: "#a8402a" },
  sniper: { body: "#fffaf0", ring: "#6aa83a", badge: "#e85a20" },
  wizard: { body: "#fffaf0", ring: "#b56cff", badge: "#8a3aff" },
  golden: { body: "#ffd34a", ring: "#ffe066", badge: "#ff9a00" },
  tesla: { body: "#fffaf0", ring: "#5ab8ff", badge: "#2a7aff" },
  rocket: { body: "#fff1dc", ring: "#ff5a3a", badge: "#c8202a" },
  medic: { body: "#fffaf0", ring: "#5dff8c", badge: "#2ab84a" },
  dark: { body: "#3a2a4a", ring: "#a04aff", badge: "#5a1aa8" },
};

export const BRANCH_STYLE = {
  gatling: { rapid: ["#ff4a3a", "»"], mutation: ["#7aff3a", "☣"], explosive: ["#ff9a2a", "✸"] },
  frost: { shards: ["#9ad8ff", "✦"], blizzard: ["#e8fbff", "❄"], deep: ["#5ab8ff", "◆"] },
  mortar: { big: ["#ff6a2a", "✹"], toxic: ["#7aff3a", "☣"], barrage: ["#ffcf4a", "⁂"] },
  sniper: { longshot: ["#ffe066", "◎"], pierce: ["#c0c8d8", "➤"], crit: ["#ff3b3b", "✚"] },
  wizard: { storm: ["#c48bff", "✺"], freezeEggs: ["#7ad8ff", "❄"], chainMagic: ["#ff7ad9", "∞"] },
  golden: { rich: ["#ffd34a", "♛"], interest: ["#5dff8c", "%"], treasure: ["#ffb000", "✧"] },
  tesla: { lightning: ["#9ad8ff", "ϟ"], overcharge: ["#ffe066", "⚡"], emp: ["#5ab8ff", "◉"] },
  rocket: { cluster: ["#ff9a2a", "⁂"], napalm: ["#ff4a1a", "♨"], homing: ["#ff3b3b", "➹"] },
  medic: { heal: ["#5dff8c", "✚"], shield: ["#7ad8ff", "◈"], revive: ["#ffe066", "☥"] },
  dark: { hole: ["#a04aff", "●"], gravity: ["#c48bff", "◍"], void: ["#ff4fd8", "✦"] },
};

function shade(hex, f = 0.7) {
  const n = parseInt(hex.slice(1), 16);
  return `rgb(${Math.round(((n >> 16) & 255) * f)},${Math.round(((n >> 8) & 255) * f)},${Math.round((n & 255) * f)})`;
}

function goggles(ctx, hx, hy, face, color = "#1a1a22") {
  ctx.fillStyle = color; ctx.strokeStyle = "#5a3a20"; ctx.lineWidth = 1.2;
  ctx.beginPath(); ctx.arc(hx + face * 1.5, hy - 2, 3.2, 0, TAU); ctx.arc(hx + face * 6, hy - 2, 3, 0, TAU); ctx.fill(); ctx.stroke();
  ctx.fillStyle = "rgba(140,220,255,0.85)"; ctx.beginPath(); ctx.arc(hx + face * 1, hy - 3, 1.2, 0, TAU); ctx.arc(hx + face * 5.5, hy - 3, 1.1, 0, TAU); ctx.fill();
}

// ------------------------------------------------------------------ pedestal per level
function pedestal(ctx, kind, level, branch, time) {
  const col = TOWER_COLORS[kind];
  const bcol = branch ? BRANCH_STYLE[kind][branch][0] : col.ring;
  ctx.fillStyle = "rgba(0,0,0,0.32)"; ctx.beginPath(); ctx.ellipse(0, 15, 22 + level * 1.5, 7.5, 0, 0, TAU); ctx.fill();
  if (branch) { // rotating rune circle on the ground
    ctx.save(); ctx.translate(0, 10); ctx.scale(1, 0.42); ctx.rotate(time * 0.8);
    ctx.strokeStyle = bcol; ctx.lineWidth = 2.5; ctx.globalAlpha = 0.85; ctx.shadowColor = bcol; ctx.shadowBlur = 12;
    ctx.beginPath(); ctx.arc(0, 0, 30, 0, TAU); ctx.stroke();
    ctx.setLineDash([6, 5]); ctx.beginPath(); ctx.arc(0, 0, 25, 0, TAU); ctx.stroke(); ctx.setLineDash([]);
    for (let i = 0; i < 6; i++) { const a = (i / 6) * TAU; ctx.beginPath(); ctx.arc(Math.cos(a) * 30, Math.sin(a) * 30, 2.6, 0, TAU); ctx.fillStyle = bcol; ctx.fill(); }
    ctx.restore();
  }
  if (level <= 1) {
    // wooden crate with hay
    ctx.fillStyle = "#8a5a2a"; ctx.strokeStyle = "#4a2a10"; ctx.lineWidth = 1.4;
    ctx.beginPath(); ctx.roundRect(-17, 2, 34, 13, 3); ctx.fill(); ctx.stroke();
    ctx.strokeStyle = "#5a3a18"; for (const y of [6.5, 10.5]) { ctx.beginPath(); ctx.moveTo(-16, y); ctx.lineTo(16, y); ctx.stroke(); }
    ctx.fillStyle = "#e8c860"; for (let i = 0; i < 7; i++) { ctx.beginPath(); ctx.ellipse(-14 + i * 4.6, 2, 3, 2, (i % 2 ? 0.4 : -0.4), 0, TAU); ctx.fill(); }
    return;
  }
  // stone ring (L2+), bigger fortress at L3+
  const big = level >= 3;
  const rx = big ? 22 : 20, ry = big ? 10 : 9;
  const stone = ctx.createLinearGradient(0, -4, 0, 18);
  if (kind === "golden") { stone.addColorStop(0, "#ffe680"); stone.addColorStop(1, "#b07800"); }
  else if (kind === "dark") { stone.addColorStop(0, "#7a5a9a"); stone.addColorStop(1, "#2a1a3a"); }
  else if (kind === "frost") { stone.addColorStop(0, "#e0f4ff"); stone.addColorStop(1, "#6a8aa8"); }
  else { stone.addColorStop(0, "#b4b8c4"); stone.addColorStop(1, "#4a4e5c"); }
  if (big) { ctx.fillStyle = shade("#6a6e7a", 0.8); ctx.beginPath(); ctx.ellipse(0, 12, rx + 2, ry, 0, 0, TAU); ctx.fill(); }
  ctx.fillStyle = stone; ctx.beginPath(); ctx.ellipse(0, 8, rx, ry, 0, 0, TAU); ctx.fill();
  ctx.strokeStyle = "rgba(0,0,0,0.25)"; ctx.lineWidth = 1;
  for (let i = -2; i <= 2; i++) { ctx.beginPath(); ctx.moveTo(i * 8, 1); ctx.lineTo(i * 8.6, 16); ctx.stroke(); }
  if (big) { // crenellations + gold trim
    ctx.fillStyle = "#9aa0ae";
    for (let i = 0; i < 8; i++) { const a = Math.PI + (i / 7) * Math.PI; ctx.fillRect(Math.cos(a) * (rx - 2) - 3, 8 + Math.sin(a) * (ry - 2) - 6, 6, 6); }
    ctx.strokeStyle = "#ffcf4a"; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(0, 9, rx - 1, ry - 1, 0, 0, Math.PI); ctx.stroke();
  }
  ctx.strokeStyle = bcol; ctx.lineWidth = branch ? 3.5 : 2.5;
  if (branch) { ctx.shadowColor = bcol; ctx.shadowBlur = 10 + Math.sin(time * 4) * 4; }
  ctx.beginPath(); ctx.ellipse(0, 7, rx - 2, ry - 1.5, 0, 0, TAU); ctx.stroke(); ctx.shadowBlur = 0;
  // banner with level pips
  ctx.fillStyle = col.badge; ctx.beginPath(); ctx.moveTo(-7, 10); ctx.lineTo(7, 10); ctx.lineTo(7, 21); ctx.lineTo(0, 18); ctx.lineTo(-7, 21); ctx.closePath(); ctx.fill();
  ctx.strokeStyle = "#ffe8a0"; ctx.lineWidth = 1; ctx.stroke();
  for (let i = 0; i < Math.min(level, 3); i++) { ctx.fillStyle = "#ffe066"; ctx.beginPath(); ctx.arc(-4 + i * 4, 13.5, 1.5, 0, TAU); ctx.fill(); }
  if (big) { // flag
    const wave = Math.sin(time * 6) * 2;
    ctx.strokeStyle = "#5a3a18"; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(-rx + 3, 6); ctx.lineTo(-rx + 3, -24); ctx.stroke();
    ctx.fillStyle = branch ? bcol : col.badge; ctx.beginPath(); ctx.moveTo(-rx + 4, -24); ctx.quadraticCurveTo(-rx + 12, -22 + wave, -rx + 18, -20); ctx.lineTo(-rx + 4, -15); ctx.closePath(); ctx.fill();
  }
}

// ------------------------------------------------------------------ the tower
export function drawTower(ctx, kind, level = 1, angle = -Math.PI / 2, time = 0, firing = false, recoil = 0, branch = null) {
  if (SPRITE_TOWERS[kind]) { drawSpriteTower(ctx, kind, level, angle, time, firing, recoil, branch); return; }
  const col = TOWER_COLORS[kind];
  const lv = Math.min(level, 3);
  const bstyle = branch ? BRANCH_STYLE[kind][branch] : null;
  ctx.save();
  pedestal(ctx, kind, level, branch, time);
  const bob = Math.sin(time * 4 + kind.length) * 1.2;
  ctx.translate(0, bob - recoil * 2 - (lv - 1) * 1.5);
  const sc = 0.9 + lv * 0.07 + (branch ? 0.06 : 0);
  ctx.scale(sc, sc);
  const face = Math.cos(angle) >= 0 ? 1 : -1;

  // auras behind the body
  if (bstyle) {
    const g = ctx.createRadialGradient(0, -6, 2, 0, -6, 30);
    g.addColorStop(0, `${bstyle[0]}55`); g.addColorStop(1, `${bstyle[0]}00`);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, -6, 30, 0, TAU); ctx.fill();
  }
  if (kind === "dark") {
    for (let r = 0; r < lv; r++) {
      ctx.save(); ctx.rotate(time * (1.5 + r) * (r % 2 ? -1 : 1));
      ctx.strokeStyle = `rgba(170,90,255,${0.55 - r * 0.12})`; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(0, -4, 18 + r * 5, 0, 4); ctx.stroke(); ctx.restore();
    }
    if (lv >= 3) for (let i = 0; i < 3; i++) { const a = time * 1.2 + (i * TAU) / 3; ctx.fillStyle = "#5a4a6a"; ctx.beginPath(); ctx.arc(Math.cos(a) * 24, -8 + Math.sin(a) * 8, 3.5, 0, TAU); ctx.fill(); }
  }
  if (kind === "golden") {
    ctx.save(); ctx.globalAlpha = 0.45 + Math.sin(time * 3) * 0.2; ctx.strokeStyle = "#fff3a0"; ctx.lineWidth = 2;
    for (let i = 0; i < 6 + lv * 2; i++) { const a = (i / (6 + lv * 2)) * TAU + time * 0.6; ctx.beginPath(); ctx.moveTo(Math.cos(a) * 16, -6 + Math.sin(a) * 16); ctx.lineTo(Math.cos(a) * (21 + lv * 2), -6 + Math.sin(a) * (21 + lv * 2)); ctx.stroke(); }
    ctx.restore();
    for (let i = 0; i < 2 + lv * 2; i++) { const ex = -15 + (i % 5) * 7.5, ey = 6 - Math.floor(i / 5) * 5; const g = ctx.createRadialGradient(ex - 1, ey - 2, 0.5, ex, ey, 4); g.addColorStop(0, "#fff8d0"); g.addColorStop(1, "#d89a00"); ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(ex, ey, 3.2, 4, 0, 0, TAU); ctx.fill(); }
  }
  if (kind === "medic") {
    ctx.save(); ctx.globalAlpha = 0.35 + Math.sin(time * 3) * 0.15; ctx.strokeStyle = "#5dff8c"; ctx.lineWidth = 2;
    for (let r = 0; r < lv; r++) { ctx.beginPath(); ctx.arc(0, -2, 16 + r * 5 + Math.sin(time * 3 + r) * 2, 0, TAU); ctx.stroke(); }
    ctx.restore();
  }
  if (kind === "frost") {
    for (let i = 0; i < lv * 2; i++) {
      const a = Math.PI * 0.15 + (i / (lv * 2)) * Math.PI * 0.7;
      ctx.save(); ctx.translate(Math.cos(a) * 18 * (i % 2 ? 1 : -1), 6); ctx.rotate((i % 2 ? 0.3 : -0.3));
      ctx.fillStyle = "rgba(200,240,255,0.9)"; ctx.strokeStyle = "#5ab8ff"; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(0, -9 - lv); ctx.lineTo(3, 0); ctx.lineTo(-3, 0); ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.restore();
    }
  }
  if (kind === "sniper") { ctx.fillStyle = "#3a7a2a"; for (let i = 0; i < 9 + lv * 2; i++) { const a = (i / (9 + lv * 2)) * TAU; ctx.beginPath(); ctx.ellipse(Math.cos(a) * 12, -4 + Math.sin(a) * 9, 5, 3, a, 0, TAU); ctx.fill(); } }

  // body
  const bodyCol = col.body;
  const g = ctx.createRadialGradient(-4, -8, 2, 0, -2, 16);
  g.addColorStop(0, kind === "dark" ? "#8a6aa8" : "#ffffff"); g.addColorStop(0.35, bodyCol); g.addColorStop(1, shade(bodyCol));
  ctx.fillStyle = g; ctx.strokeStyle = "#2a1a10"; ctx.lineWidth = 1.6;
  ctx.beginPath(); ctx.ellipse(0, -2, 13 + lv, 11 + lv * 0.6, 0, 0, TAU); ctx.fill(); ctx.stroke();
  // outfits that grow with level
  if (kind === "dark") { ctx.fillStyle = "#4a1a7a"; ctx.beginPath(); ctx.moveTo(-15, -8); ctx.quadraticCurveTo(-face * (22 + lv * 2), 6, -12, 9); ctx.lineTo(12, 9); ctx.quadraticCurveTo(face * (20 + lv * 2), 2, 15, -8); ctx.quadraticCurveTo(0, -2, -15, -8); ctx.fill(); }
  if (kind === "frost") { ctx.fillStyle = "#2a5ab0"; ctx.beginPath(); ctx.ellipse(0, 2, 13 + lv, 7, 0, 0, TAU); ctx.fill(); ctx.fillStyle = "#ffffff"; ctx.beginPath(); ctx.ellipse(0, -4, 13 + lv, 3, 0, 0, TAU); ctx.fill(); }
  if (kind === "wizard") { ctx.fillStyle = "#5a2aa8"; ctx.beginPath(); ctx.ellipse(0, 3, 14 + lv, 7, 0, 0, TAU); ctx.fill(); ctx.fillStyle = "#ffe066"; for (let i = 0; i < 2 + lv * 2; i++) { ctx.beginPath(); ctx.arc(-10 + i * 3.5, 3 + (i % 2) * 2, 1.1, 0, TAU); ctx.fill(); } }
  if (kind === "rocket" || kind === "mortar" || kind === "gatling") { ctx.fillStyle = "#7a5030"; ctx.fillRect(-12, -6, 24, 7); if (lv >= 2) { ctx.fillStyle = "#c8902a"; for (let i = 0; i < 6; i++) ctx.fillRect(-11 + i * 4, -5, 2, 5); } }
  if (kind === "medic") { ctx.fillStyle = "#4a8a5a"; ctx.fillRect(-face * 18, -14, 9, 14); ctx.fillStyle = "#fff"; ctx.fillRect(-face * 15.5 - 1, -10, 3, 7); ctx.fillRect(-face * 15.5 - 3, -8, 7, 3); if (lv >= 3) { ctx.strokeStyle = "#ffe066"; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(face * 9, -25, 7, 2.5, 0, 0, TAU); ctx.stroke(); } }
  if (kind === "tesla") { ctx.fillStyle = "#6a5040"; ctx.fillRect(-12, -2, 24, 6); }
  if (branch === "mutation") { ctx.fillStyle = "#3a8a2a"; ctx.fillRect(-face * 19, -16, 7, 13); ctx.fillStyle = "#7aff3a"; ctx.fillRect(-face * 18, -14, 5, 8 + Math.sin(time * 6)); }
  if (branch === "revive") { ctx.fillStyle = "rgba(255,255,255,0.9)"; for (const s of [-1, 1]) { ctx.beginPath(); ctx.ellipse(s * 16, -8, 10, 5, s * -0.6 + Math.sin(time * 5) * 0.2 * s, 0, TAU); ctx.fill(); } }
  // tail + wing
  ctx.fillStyle = kind === "dark" ? "#2a1a3a" : shade(bodyCol);
  ctx.strokeStyle = "#2a1a10"; ctx.lineWidth = 1.4;
  ctx.beginPath(); ctx.moveTo(-face * 11, -6); ctx.lineTo(-face * (20 + lv), -14 - lv); ctx.lineTo(-face * 17, -2); ctx.lineTo(-face * (21 + lv), -6); ctx.lineTo(-face * 12, 2); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.fillStyle = kind === "dark" ? "#5a3a7a" : shade(bodyCol, 0.88);
  ctx.beginPath(); ctx.ellipse(-face * 2, 0, 7, 5, face * 0.3 + (firing ? Math.sin(time * 40) * 0.3 : kind === "golden" ? Math.sin(time * 6) * 0.4 : 0), 0, TAU); ctx.fill(); ctx.stroke();
  // head
  const hx = face * 9, hy = -13;
  ctx.fillStyle = kind === "dark" ? "#4a3a5a" : col.body; ctx.beginPath(); ctx.arc(hx, hy, 7, 0, TAU); ctx.fill(); ctx.stroke();
  if (!["wizard", "frost", "medic", "golden"].includes(kind)) {
    const comb = (kind === "tesla" || kind === "dark" ? 1.25 : 1) * (0.9 + lv * 0.1);
    ctx.fillStyle = "#ff3b3b";
    ctx.beginPath(); ctx.arc(hx - 3, hy - 7 * comb + 2, 3 * comb, 0, TAU); ctx.arc(hx + 1, hy - 8 * comb + 2, 3.2 * comb, 0, TAU); ctx.arc(hx + 4, hy - 6 * comb + 2, 2.6 * comb, 0, TAU); ctx.fill();
  }
  ctx.fillStyle = "#1a0a10"; ctx.beginPath(); ctx.arc(hx + face * 2.5, hy - 1, 1.8, 0, TAU); ctx.fill();
  ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(hx + face * 3, hy - 1.6, 0.7, 0, TAU); ctx.fill();
  ctx.fillStyle = "#ffad1f"; ctx.beginPath(); ctx.moveTo(hx + face * 6, hy - 1); ctx.lineTo(hx + face * 12, hy + 1); ctx.lineTo(hx + face * 6, hy + 3); ctx.closePath(); ctx.fill();
  // headgear
  if (["gatling", "rocket", "mortar", "tesla", "sniper"].includes(kind)) goggles(ctx, hx, hy, face);
  if (kind === "dark") goggles(ctx, hx, hy, face, "#7a2aff");
  if (kind === "rocket" || kind === "mortar") { ctx.fillStyle = "#7a4a20"; ctx.beginPath(); ctx.arc(hx, hy - 3, 7.2, Math.PI, TAU); ctx.fill(); }
  if (kind === "gatling") { ctx.fillStyle = "#d82a2a"; ctx.beginPath(); ctx.moveTo(hx - face * 4, hy + 5); ctx.lineTo(-face * (16 + lv * 2), hy + 2 + Math.sin(time * 10) * 2); ctx.lineTo(hx - face * 4, hy + 8); ctx.fill(); }
  if (kind === "wizard") {
    const tall = 22 + lv * 4;
    ctx.fillStyle = branch === "freezeEggs" ? "#2a6ab0" : branch === "chainMagic" ? "#a82a7a" : "#5a2aa8"; ctx.strokeStyle = "#2a0a5a"; ctx.lineWidth = 1.2;
    ctx.beginPath(); ctx.moveTo(hx - 10, hy - 4); ctx.lineTo(hx + 10, hy - 4); ctx.lineTo(hx - face * 2, hy - tall); ctx.lineTo(hx - face * 8, hy - tall + 6); ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#ffe066"; for (let i = 0; i < lv + 1; i++) { ctx.beginPath(); ctx.arc(hx - face * i * 1.5, hy - 9 - i * 4, 1.4, 0, TAU); ctx.fill(); }
  }
  if (kind === "frost") { ctx.fillStyle = "#2a5ab0"; ctx.beginPath(); ctx.arc(hx, hy - 2, 8, Math.PI, TAU); ctx.fill(); ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.ellipse(hx, hy - 2, 9, 2.6, 0, 0, TAU); ctx.fill(); ctx.beginPath(); ctx.arc(hx, hy - 10, 2 + lv, 0, TAU); ctx.fill(); goggles(ctx, hx, hy, face, "#1a2a5a"); }
  if (kind === "medic") { ctx.fillStyle = "#fff"; ctx.strokeStyle = "#c8c8c8"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(hx - 7, hy - 5); ctx.lineTo(hx + 7, hy - 5); ctx.lineTo(hx + 5, hy - 12); ctx.lineTo(hx - 5, hy - 12); ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.fillStyle = "#ff3b3b"; ctx.fillRect(hx - 1, hy - 11, 2, 5); ctx.fillRect(hx - 2.5, hy - 9.5, 5, 2); }
  if (kind === "golden") {
    const cs = 1 + lv * 0.18;
    ctx.save(); ctx.translate(hx, hy - 5); ctx.scale(cs, cs);
    ctx.fillStyle = "#ffcf4a"; ctx.strokeStyle = "#8a5200"; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(-6, 0); ctx.lineTo(-7, -8); ctx.lineTo(-3, -4); ctx.lineTo(0, -10); ctx.lineTo(3, -4); ctx.lineTo(7, -8); ctx.lineTo(6, 0); ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#ff3b8a"; ctx.beginPath(); ctx.arc(0, -9, 1.6, 0, TAU); ctx.fill(); ctx.restore();
  }
  if (kind === "tesla") {
    const hgt = 10 + lv * 3;
    for (const sx of [-14, 14]) {
      ctx.fillStyle = "#5a6a80"; ctx.fillRect(sx - 2.5, -4 - hgt, 5, hgt);
      ctx.fillStyle = "#c8a040"; for (let k = 0; k < lv + 1; k++) ctx.fillRect(sx - 3.5, -2 - hgt + k * 3.5, 7, 1.6);
      ctx.fillStyle = branch === "overcharge" ? "#ffe066" : "#9ad8ff"; ctx.beginPath(); ctx.arc(sx, -6 - hgt, 2.5 + lv * 0.6 + Math.sin(time * 18 + sx) * 0.8, 0, TAU); ctx.fill();
    }
    if (lv >= 2) { // arcs between the coils
      ctx.strokeStyle = "rgba(160,220,255,0.8)"; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(-14, -6 - hgt);
      for (let k = 1; k < 6; k++) ctx.lineTo(-14 + k * 5.6, -6 - hgt + Math.sin(time * 40 + k * 2) * 3); ctx.stroke();
    }
  }
  // weapon toward the target
  ctx.save();
  ctx.translate(0, -2); ctx.rotate(angle); ctx.translate(-recoil * 4, 0);
  ctx.strokeStyle = "#1a1008"; ctx.lineWidth = 1.4;
  const hot = branch === "rapid";
  if (kind === "gatling") {
    const guns = lv >= 3 ? [-5, 5] : [0];
    for (const off of guns) {
      ctx.save(); ctx.translate(0, off);
      ctx.fillStyle = branch === "explosive" ? "#ff9a2a" : "#e8b020"; ctx.beginPath(); ctx.roundRect(0, -6, 12, 12, 3); ctx.fill(); ctx.stroke();
      const n = 2 + lv, spin = firing || recoil > 0 ? time * 40 : 0;
      for (let i = 0; i < n; i++) { const o = Math.sin(spin + (i * TAU) / n) * 3.2; ctx.fillStyle = hot ? `rgb(${200 + Math.round(55 * Math.random())},60,30)` : "#3a3a44"; ctx.fillRect(11, -1.4 + o, 12 + lv * 2, 2.8); }
      ctx.restore();
    }
    if (lv >= 2) { ctx.fillStyle = "#c8902a"; for (let i = 0; i < 5; i++) ctx.fillRect(2 + i * 2.2, 6, 1.6, 3); }
  } else if (kind === "frost") {
    ctx.fillStyle = "#5a6a80"; ctx.fillRect(4, -4 - lv * 0.5, 12 + lv * 2, 8 + lv); ctx.strokeRect(4, -4 - lv * 0.5, 12 + lv * 2, 8 + lv);
    ctx.fillStyle = branch === "deep" ? "#1a4a8a" : "#bff1ff";
    const tip = 16 + lv * 2;
    ctx.beginPath(); ctx.moveTo(tip, -6 - lv); ctx.lineTo(tip + 8 + lv * 2, 0); ctx.lineTo(tip, 6 + lv); ctx.closePath(); ctx.fill();
  } else if (kind === "mortar") {
    const barrels = branch === "barrage" ? 3 : lv >= 3 ? 2 : 1;
    const len = 18 + lv * 3 + (branch === "big" ? 6 : 0), thick = 12 + lv * 1.5 + (branch === "big" ? 4 : 0);
    for (let b = 0; b < barrels; b++) {
      const off = (b - (barrels - 1) / 2) * (thick * 0.8);
      ctx.fillStyle = branch === "toxic" ? "#2a5a2a" : "#3a3a42"; ctx.beginPath(); ctx.roundRect(2, off - thick / 2, len, thick, 5); ctx.fill(); ctx.stroke();
      ctx.fillStyle = "#1a1a1e"; ctx.beginPath(); ctx.ellipse(len + 1, off, 3, thick / 2 - 1, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = branch === "toxic" ? "#7aff3a" : "#c8902a"; ctx.fillRect(8, off - thick / 2, 3, thick);
    }
  } else if (kind === "sniper") {
    const len = 28 + lv * 4 + (branch === "longshot" ? 10 : 0);
    ctx.fillStyle = "#3a2a1a"; ctx.fillRect(2, -2.5, len, 5); ctx.strokeRect(2, -2.5, len, 5);
    if (branch === "pierce") { ctx.fillStyle = "#e0e8f0"; ctx.fillRect(len - 2, -3, 6, 6); }
    if (lv >= 2) { ctx.fillStyle = "#1a1a22"; ctx.fillRect(10, -8, 14, 4.5); ctx.fillStyle = "#7ad8ff"; ctx.fillRect(23, -7.5, 2, 3.5); }
    if (lv >= 3) { ctx.strokeStyle = "#3a2a1a"; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(len - 6, 2); ctx.lineTo(len - 2, 9); ctx.moveTo(len - 6, 2); ctx.lineTo(len - 10, 9); ctx.stroke(); }
    if (branch === "crit") { ctx.strokeStyle = "rgba(255,40,40,0.6)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(len, 0); ctx.lineTo(len + 60, 0); ctx.stroke(); }
  } else if (kind === "wizard") {
    ctx.strokeStyle = "#7a4a20"; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(4, 4); ctx.lineTo(20 + lv * 2, -2); ctx.stroke();
    const oc = branch === "freezeEggs" ? "#7ad8ff" : branch === "chainMagic" ? "#ff7ad9" : "#d08aff";
    const gl = ctx.createRadialGradient(22 + lv * 2, -3, 0.5, 22 + lv * 2, -3, 7 + lv);
    gl.addColorStop(0, "#ffffff"); gl.addColorStop(0.4, oc); gl.addColorStop(1, "rgba(160,74,255,0)");
    ctx.fillStyle = gl; ctx.beginPath(); ctx.arc(22 + lv * 2, -3, 7 + lv + Math.sin(time * 8) * 1.5, 0, TAU); ctx.fill();
  } else if (kind === "rocket") {
    const pods = branch === "homing" || branch === "cluster" ? 3 : lv;
    for (let i = 0; i < pods; i++) {
      const off = (i - (pods - 1) / 2) * 9;
      ctx.fillStyle = "#e8e0d0"; ctx.beginPath(); ctx.roundRect(-2, off - 5, 24 + lv * 2, 10, 5); ctx.fill(); ctx.stroke();
      ctx.fillStyle = branch === "napalm" ? "#ff6a1a" : "#d82a2a"; ctx.fillRect(4, off - 5, 3, 10); ctx.fillRect(13, off - 5, 3, 10);
      if (recoil < 0.3) { ctx.beginPath(); ctx.moveTo(22 + lv * 2, off - 4); ctx.lineTo(28 + lv * 2, off); ctx.lineTo(22 + lv * 2, off + 4); ctx.fill(); }
    }
    if (branch === "homing") { ctx.strokeStyle = "#c0c8d8"; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(-4, -14, 5, Math.PI, TAU); ctx.stroke(); }
  } else if (kind === "medic") {
    ctx.fillStyle = "#f0f0f0"; ctx.beginPath(); ctx.moveTo(6, -2); ctx.lineTo(16 + lv * 2, -6 - lv); ctx.lineTo(16 + lv * 2, 6 + lv); ctx.lineTo(6, 2); ctx.closePath(); ctx.fill(); ctx.stroke();
  } else if (kind === "dark") {
    const r = 8 + lv * 1.5;
    const v = ctx.createRadialGradient(20, 0, 1, 20, 0, r);
    v.addColorStop(0, "#000"); v.addColorStop(0.5, branch === "void" ? "#5a0a3a" : "#2a0a4a"); v.addColorStop(1, "rgba(160,74,255,0)");
    ctx.fillStyle = v; ctx.beginPath(); ctx.arc(20, 0, r, 0, TAU); ctx.fill();
    ctx.strokeStyle = "rgba(200,140,255,0.85)"; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(20, 0, r - 2, time * 6, time * 6 + 4); ctx.stroke();
  }
  ctx.restore();
  // wizard orbiting orbs, one per level
  if (kind === "wizard") for (let i = 0; i < lv; i++) { const a = time * 2 + (i * TAU) / lv; ctx.fillStyle = branch === "freezeEggs" ? "#bff1ff" : "#e0b0ff"; ctx.beginPath(); ctx.arc(Math.cos(a) * 20, -8 + Math.sin(a) * 7, 2.6, 0, TAU); ctx.fill(); }
  ctx.restore();
  // branch badge floating above the tower
  if (bstyle) {
    const by = -44 - (lv - 1) * 1.5 + Math.sin(time * 3) * 2;
    ctx.save();
    ctx.fillStyle = bstyle[0]; ctx.shadowColor = bstyle[0]; ctx.shadowBlur = 12;
    ctx.beginPath(); ctx.arc(0, by, 8, 0, TAU); ctx.fill(); ctx.shadowBlur = 0;
    ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.fillStyle = "#1a1008"; ctx.font = "900 10px 'Segoe UI Symbol', Inter, sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText(bstyle[1], 0, by + 0.5);
    ctx.restore();
  }
}

/** Where the muzzle is, relative to the tower centre (for flashes). */
export function muzzle(kind, level, angle) {
  const reach = ({ gatling: 26, frost: 26, mortar: 26, sniper: 36, wizard: 26, rocket: 30, tesla: 0, dark: 22, golden: 0, medic: 20 }[kind] ?? 24) + level * 2;
  return { x: Math.cos(angle) * reach, y: -4 - (level - 1) * 1.5 + Math.sin(angle) * reach };
}

// ------------------------------------------------------------------ sprite towers (concept sheets)
export const SPRITE_TOWERS = { beekeeper: [0, 45, 200, 155], gravity: [200, 47, 200, 153], samurai: [400, 45, 200, 155], volcano: [600, 44, 200, 156], portal: [800, 47, 200, 153], chef: [0, 233, 200, 167], paintball: [200, 228, 200, 172], necro: [400, 227, 200, 173], disco: [600, 232, 200, 168], bubble: [800, 233, 200, 167], viking: [0, 447, 200, 153], magnet: [200, 445, 200, 155], sandstorm: [400, 445, 200, 155], vampire: [600, 445, 200, 155], archer: [800, 444, 200, 156], junkyard: [0, 638, 200, 162], ghost: [200, 640, 200, 160], bakery: [400, 636, 200, 164], cosmos: [600, 639, 200, 161], lumberjack: [800, 640, 200, 160] };
const SPRITE_ORDER = Object.keys(SPRITE_TOWERS);
export const TOWER_ATLAS_URL = "/assets/defense/towers.webp";
export const BRANCH_ICON_URL = "/assets/defense/branch-icons.webp";
const SPRITE_COLORS = {
  beekeeper: ["#e8a800", "#ffd34a"], gravity: ["#8a3aff", "#c48bff"], samurai: ["#c8202a", "#ff7a8a"], volcano: ["#e8501a", "#ffb04a"], portal: ["#6a3ad8", "#b08aff"],
  chef: ["#c8402a", "#ffcf4a"], paintball: ["#d82aa8", "#ff7ad9"], necro: ["#5a2a8a", "#7aff5a"], disco: ["#b02ad8", "#ff7ad9"], bubble: ["#2a8ad8", "#9ad8ff"],
  viking: ["#a8402a", "#ffcf4a"], magnet: ["#5a3ad8", "#ff4a5a"], sandstorm: ["#c88a2a", "#ffd88a"], vampire: ["#8a1a3a", "#ff4a6a"], archer: ["#3a8a2a", "#9adf5a"],
  junkyard: ["#a8402a", "#c8a070"], ghost: ["#3a6ab8", "#9af0ff"], bakery: ["#c82a7a", "#ffb0d8"], cosmos: ["#5a2ab8", "#ffe066"], lumberjack: ["#a82a2a", "#5aa83a"],
};
for (const [kind, [badge, ring]] of Object.entries(SPRITE_COLORS)) {
  TOWER_COLORS[kind] = { body: "#fffaf0", ring, badge };
  BRANCH_STYLE[kind] = Object.fromEntries(Object.keys(TOWERS[kind].branches).map((key, i) => [key, [[ring, badge, "#ffe066"][i], "✦"]]));
}

let towerAtlas = null, iconAtlas = null;
export const towerArtReady = typeof Image === "undefined" ? Promise.resolve() : Promise.all([
  new Promise((resolve) => { towerAtlas = new Image(); towerAtlas.onload = resolve; towerAtlas.onerror = resolve; towerAtlas.src = TOWER_ATLAS_URL; }),
  new Promise((resolve) => { iconAtlas = new Image(); iconAtlas.onload = resolve; iconAtlas.onerror = resolve; iconAtlas.src = BRANCH_ICON_URL; }),
]);

/** Position of a branch icon (72 px cells, 10 per row) in the icon atlas. */
export function branchIcon(kind, branch) {
  const i = SPRITE_ORDER.indexOf(kind);
  if (i < 0) return null;
  const k = Object.keys(TOWERS[kind].branches).indexOf(branch);
  const idx = i * 3 + k;
  return { x: (idx % 10) * 72, y: Math.floor(idx / 10) * 72, size: 72, url: BRANCH_ICON_URL };
}

export function drawSpriteTower(ctx, kind, level = 1, angle = 0, time = 0, firing = false, recoil = 0, branch = null) {
  const box = SPRITE_TOWERS[kind];
  const lv = Math.min(level, 3);
  const [badge, ring] = SPRITE_COLORS[kind];
  const bcol = branch ? BRANCH_STYLE[kind][branch][0] : ring;
  const scale = [0.8, 0.9, 1.0][lv - 1] + (branch ? 0.08 : 0);
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.32)"; ctx.beginPath(); ctx.ellipse(0, 14, 24 * scale, 8, 0, 0, TAU); ctx.fill();
  if (branch) {
    ctx.save(); ctx.translate(0, 12); ctx.scale(1, 0.42); ctx.rotate(time * 0.8);
    ctx.strokeStyle = bcol; ctx.lineWidth = 2.5; ctx.shadowColor = bcol; ctx.shadowBlur = 12;
    ctx.beginPath(); ctx.arc(0, 0, 34, 0, TAU); ctx.stroke();
    ctx.setLineDash([6, 5]); ctx.beginPath(); ctx.arc(0, 0, 28, 0, TAU); ctx.stroke(); ctx.setLineDash([]);
    for (let i = 0; i < 6; i++) { const a = (i / 6) * TAU; ctx.fillStyle = bcol; ctx.beginPath(); ctx.arc(Math.cos(a) * 34, Math.sin(a) * 34, 2.8, 0, TAU); ctx.fill(); }
    ctx.restore();
  } else if (lv >= 2) {
    ctx.save(); ctx.translate(0, 12); ctx.scale(1, 0.4);
    ctx.strokeStyle = "#ffcf4a"; ctx.lineWidth = 3; ctx.shadowColor = "#ffcf4a"; ctx.shadowBlur = lv >= 3 ? 14 : 6;
    ctx.beginPath(); ctx.arc(0, 0, 30, 0, TAU); ctx.stroke(); ctx.restore();
  }
  if (lv >= 3 || branch) {
    const g = ctx.createRadialGradient(0, -14, 2, 0, -14, 40);
    g.addColorStop(0, `${branch ? bcol : "#ffe066"}55`); g.addColorStop(1, `${branch ? bcol : "#ffe066"}00`);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, -14, 40, 0, TAU); ctx.fill();
  }
  const h = 58 * scale, w = h * (box[2] / box[3]);
  const face = Math.cos(angle) >= 0 ? 1 : -1;
  const bob = Math.sin(time * 3 + kind.length) * 1;
  const ready = towerAtlas?.complete && towerAtlas.naturalWidth;
  ctx.save();
  ctx.translate(0, bob);
  ctx.scale(face * (1 + recoil * 0.06), 1 - recoil * 0.06);
  if (ready) ctx.drawImage(towerAtlas, box[0], box[1], box[2], box[3], -w / 2, 18 - h, w, h);
  else { ctx.fillStyle = badge; ctx.beginPath(); ctx.ellipse(0, -10, 16, 18, 0, 0, TAU); ctx.fill(); }
  if (firing && ready) { ctx.globalCompositeOperation = "lighter"; ctx.globalAlpha = 0.25; ctx.drawImage(towerAtlas, box[0], box[1], box[2], box[3], -w / 2, 18 - h, w, h); }
  ctx.restore();
  if (lv >= 3) for (let i = 0; i < 4; i++) {
    const a = time * 1.6 + (i * TAU) / 4;
    ctx.fillStyle = branch ? bcol : "#fff3a0";
    ctx.beginPath(); ctx.arc(Math.cos(a) * 26, -16 + Math.sin(a) * 9, 1.8 + Math.sin(time * 6 + i), 0, TAU); ctx.fill();
  }
  for (let i = 0; i < lv; i++) {
    const sx = (i - (lv - 1) / 2) * 9;
    ctx.save(); ctx.translate(sx, 22); ctx.fillStyle = "#ffe066"; ctx.strokeStyle = "#8a5200"; ctx.lineWidth = 1;
    ctx.beginPath();
    for (let k = 0; k < 10; k++) { const r = k % 2 ? 1.8 : 4.2; ctx.lineTo(Math.cos((k / 10) * TAU - Math.PI / 2) * r, Math.sin((k / 10) * TAU - Math.PI / 2) * r); }
    ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.restore();
  }
  if (branch) {
    const icon = branchIcon(kind, branch);
    const by = 18 - h - 10 + Math.sin(time * 3) * 2;
    ctx.save();
    ctx.fillStyle = "#fff8e8"; ctx.strokeStyle = bcol; ctx.lineWidth = 2.5; ctx.shadowColor = bcol; ctx.shadowBlur = 12;
    ctx.beginPath(); ctx.arc(0, by, 12, 0, TAU); ctx.fill(); ctx.stroke(); ctx.shadowBlur = 0;
    if (icon && iconAtlas?.complete && iconAtlas.naturalWidth) ctx.drawImage(iconAtlas, icon.x, icon.y, 72, 72, -11, by - 11, 22, 22);
    ctx.restore();
  }
  ctx.restore();
}
