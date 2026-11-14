import { LAYOUT, CX } from "./table.js";

// Lamp inserts (table units). `lamp` matches the ids the engine lights.
const C = { pink: "#ff3fb4", cyan: "#3fe7ff", gold: "#ffc94a", purple: "#b06bff", orange: "#ff8a2a", red: "#ff3b4e", green: "#5dff8c", white: "#f4ecff" };
const arcRow = [[3.45, 13.05], [4.05, 12.85], [4.65, 12.78], [5.25, 12.85], [5.85, 13.05]];
export const INSERTS = [
  ...LAYOUT.lanes.map((x, i) => ({ lamp: "lane" + i, shape: "circle", x, y: 2.32, r: 0.19, color: C.cyan, label: "BAR"[i] })),
  ...LAYOUT.lanes.map((x, i) => ({ lamp: "bonus" + (i + 2), shape: "circle", x, y: 3.32, r: 0.13, color: C.gold, label: `${i + 2}X`, small: true })),
  { lamp: "rampL", shape: "arrow", x: 1.8, y: 10.15, r: 0.42, angle: -90, color: C.pink, label: "DJ" },
  { lamp: "rampR", shape: "arrow", x: CX * 2 - 1.8, y: 10.15, r: 0.42, angle: -90, color: C.cyan, label: "NEON" },
  { lamp: "orbitL", shape: "arrow", x: 0.73, y: 10.05, r: 0.3, angle: -90, color: C.gold, label: "" },
  { lamp: "orbitR", shape: "arrow", x: CX * 2 - 0.73, y: 10.05, r: 0.3, angle: -90, color: C.gold, label: "" },
  { lamp: "mission", shape: "triangle", x: 2.3, y: 11.15, r: 0.3, color: C.orange, label: "MISSION" },
  { lamp: "extraBall", shape: "triangle", x: CX * 2 - 2.3, y: 11.15, r: 0.3, color: C.red, label: "EXTRA" },
  { lamp: "vip", shape: "arrow", x: CX, y: 10.55, r: 0.48, angle: -90, color: C.gold, label: "VIP" },
  { lamp: "lock0", shape: "circle", x: 4.2, y: 11.45, r: 0.12, color: C.purple },
  { lamp: "lock1", shape: "circle", x: 4.65, y: 11.6, r: 0.12, color: C.purple },
  { lamp: "lock2", shape: "circle", x: 5.1, y: 11.45, r: 0.12, color: C.purple },
  ...arcRow.map(([x, y], i) => ({ lamp: "m" + i, shape: "circle", x, y, r: 0.17, color: [C.pink, C.green, C.gold, C.purple, C.orange][i], label: "RTSVC"[i] })),
  { lamp: "kickback", shape: "rect", x: 0.67, y: 16.5, r: 0.22, color: C.green, label: "" },
  { lamp: "shootAgain", shape: "circle", x: CX, y: 19.05, r: 0.27, color: C.red, label: "" },
  { lamp: "plunger", shape: "arrow", x: 9.35, y: 17.0, r: 0.3, angle: -90, color: C.white, label: "" },
];

const S = 120; // pixels per table unit
const P = (v) => v * S;

function shapePath(ctx, ins, scale = 1) {
  const r = P(ins.r) * scale, x = P(ins.x), y = P(ins.y);
  ctx.beginPath();
  if (ins.shape === "circle") ctx.arc(x, y, r, 0, Math.PI * 2);
  else if (ins.shape === "rect") ctx.roundRect(x - r * 0.75, y - r * 1.4, r * 1.5, r * 2.8, r * 0.3);
  else if (ins.shape === "triangle") { ctx.moveTo(x, y - r * 1.1); ctx.lineTo(x + r, y + r * 0.7); ctx.lineTo(x - r, y + r * 0.7); ctx.closePath(); }
  else if (ins.shape === "arrow") {
    const a = ((ins.angle ?? -90) * Math.PI) / 180, ca = Math.cos(a), sa = Math.sin(a);
    const pts = [[1.3, 0], [0.1, 0.75], [0.1, 0.32], [-1.1, 0.32], [-1.1, -0.32], [0.1, -0.32], [0.1, -0.75]];
    pts.forEach(([u, v], i) => { const px = x + (u * ca - v * sa) * r, py = y + (u * sa + v * ca) * r; if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py); });
    ctx.closePath();
  }
}

// White shape on transparent for the lit overlay mesh.
export function insertMask(ins) {
  const c = document.createElement("canvas");
  c.width = c.height = 128;
  const ctx = c.getContext("2d");
  const k = 128 / (P(ins.r) * 3.2);
  ctx.translate(64, 64); ctx.scale(k, k); ctx.translate(-P(ins.x), -P(ins.y));
  const g = ctx.createRadialGradient(P(ins.x), P(ins.y), 0, P(ins.x), P(ins.y), P(ins.r) * 1.3);
  g.addColorStop(0, "#ffffff"); g.addColorStop(0.7, "#ffffffee"); g.addColorStop(1, "#ffffff99");
  ctx.fillStyle = g;
  shapePath(ctx, ins); ctx.fill();
  return { canvas: c, size: ins.r * 3.2 };
}

function neonText(ctx, text, x, y, size, color, { glow = 18, weight = 900, align = "center", italic = false, stroke = null } = {}) {
  ctx.save();
  ctx.font = `${italic ? "italic " : ""}${weight} ${size}px Inter, "Segoe UI", Arial, sans-serif`;
  ctx.textAlign = align; ctx.textBaseline = "middle";
  ctx.shadowColor = color; ctx.shadowBlur = glow;
  if (stroke) { ctx.lineWidth = size * 0.12; ctx.strokeStyle = stroke; ctx.strokeText(text, x, y); }
  ctx.fillStyle = color; ctx.fillText(text, x, y);
  ctx.shadowBlur = glow * 0.4; ctx.fillText(text, x, y);
  ctx.restore();
}

export async function paintPlayfield(mascot) {
  try { await document.fonts?.load?.("900 64px Inter"); } catch { /* font is optional */ }
  const c = document.createElement("canvas");
  c.width = P(10); c.height = P(20);
  const ctx = c.getContext("2d");
  const L = LAYOUT;

  // Lacquered night-club base.
  let g = ctx.createLinearGradient(0, 0, 0, c.height);
  g.addColorStop(0, "#10041c"); g.addColorStop(0.35, "#1d0833"); g.addColorStop(0.7, "#160627"); g.addColorStop(1, "#07020d");
  ctx.fillStyle = g; ctx.fillRect(0, 0, c.width, c.height);

  // Sunburst behind the mascot.
  const sx = P(CX), sy = P(12.4);
  ctx.save();
  for (let i = 0; i < 36; i++) {
    const a0 = (i / 36) * Math.PI * 2, a1 = a0 + Math.PI / 36;
    ctx.beginPath(); ctx.moveTo(sx, sy); ctx.arc(sx, sy, P(9), a0, a1); ctx.closePath();
    const rg = ctx.createRadialGradient(sx, sy, P(0.5), sx, sy, P(8));
    rg.addColorStop(0, i % 2 ? "rgba(176,107,255,0.22)" : "rgba(255,63,180,0.16)"); rg.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = rg; ctx.fill();
  }
  ctx.restore();

  // Dance floor under the pop bumpers.
  ctx.save();
  ctx.beginPath(); ctx.arc(P(4.65), P(5.4), P(2.35), 0, Math.PI * 2); ctx.clip();
  const tile = P(0.42);
  for (let ty = P(2.8); ty < P(8.2); ty += tile) for (let tx = P(2.2); tx < P(7.2); tx += tile) {
    const k = (Math.round(tx / tile) + Math.round(ty / tile)) % 2;
    const hue = (tx * 0.07 + ty * 0.05) % 360;
    ctx.fillStyle = k ? `hsla(${290 + (hue % 60)}, 90%, 55%, 0.22)` : "rgba(20,6,34,0.5)";
    ctx.fillRect(tx + 2, ty + 2, tile - 4, tile - 4);
  }
  ctx.restore();
  ctx.save();
  ctx.strokeStyle = "rgba(255,201,74,0.55)"; ctx.lineWidth = 5; ctx.shadowColor = "#ffc94a"; ctx.shadowBlur = 14;
  ctx.beginPath(); ctx.arc(P(4.65), P(5.4), P(2.35), 0, Math.PI * 2); ctx.stroke();
  ctx.restore();

  // Mascot medallion.
  const mx = P(CX), my = P(14.1), mr = P(1.55);
  g = ctx.createRadialGradient(mx, my, mr * 0.2, mx, my, mr * 1.6);
  g.addColorStop(0, "rgba(255,201,74,0.45)"); g.addColorStop(0.55, "rgba(176,107,255,0.25)"); g.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(mx, my, mr * 1.6, 0, Math.PI * 2); ctx.fill();
  ctx.save();
  ctx.beginPath(); ctx.arc(mx, my, mr, 0, Math.PI * 2); ctx.closePath();
  ctx.fillStyle = "#1a0830"; ctx.fill();
  ctx.clip();
  if (mascot) { const s = mr * 2.25; ctx.drawImage(mascot, mx - s / 2, my - s * 0.52, s, s); }
  ctx.restore();
  ctx.save();
  ctx.lineWidth = 10; ctx.strokeStyle = "#ffc94a"; ctx.shadowColor = "#ffc94a"; ctx.shadowBlur = 20;
  ctx.beginPath(); ctx.arc(mx, my, mr, 0, Math.PI * 2); ctx.stroke();
  ctx.lineWidth = 3; ctx.strokeStyle = "#ff3fb4"; ctx.beginPath(); ctx.arc(mx, my, mr + 16, 0, Math.PI * 2); ctx.stroke();
  ctx.restore();

  // Title.
  neonText(ctx, "PEPPLE", P(CX), P(16.15), 128, "#ffd36b", { glow: 26, italic: true, stroke: "#5a1b00" });
  neonText(ctx, "AFTER  HOURS  CLUB", P(CX), P(16.85), 42, "#ff4fc3", { glow: 22, weight: 800 });

  // Art-deco border lines along the cabinet.
  ctx.save();
  ctx.strokeStyle = "rgba(255,201,74,0.6)"; ctx.lineWidth = 4;
  ctx.beginPath(); ctx.arc(P(L.arc.cx), P(L.arc.cy), P(L.arc.r - 0.22), Math.PI, Math.PI * 2); ctx.stroke();
  ctx.strokeStyle = "rgba(255,63,180,0.45)"; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(P(L.arc.cx), P(L.arc.cy), P(L.arc.r - 0.32), Math.PI, Math.PI * 2); ctx.stroke();
  ctx.restore();

  // Chevrons into ramps and orbits.
  const chevrons = (x, y, color, n = 3) => {
    ctx.save(); ctx.strokeStyle = color; ctx.lineWidth = 9; ctx.shadowColor = color; ctx.shadowBlur = 12; ctx.globalAlpha = 0.55;
    for (let i = 0; i < n; i++) { const yy = P(y - i * 0.32); ctx.beginPath(); ctx.moveTo(P(x - 0.32), yy + P(0.16)); ctx.lineTo(P(x), yy); ctx.lineTo(P(x + 0.32), yy + P(0.16)); ctx.stroke(); }
    ctx.restore();
  };
  chevrons(1.8, 9.1, "#ff3fb4"); chevrons(CX * 2 - 1.8, 9.1, "#3fe7ff"); chevrons(CX, 9.45, "#ffc94a", 2);

  // VIP lounge floor in the alcove.
  ctx.save();
  ctx.beginPath(); ctx.rect(P(L.alcove.x0), P(L.alcove.top - 0.3), P(L.alcove.x1 - L.alcove.x0), P(L.alcove.bottom - L.alcove.top + 0.3)); ctx.clip();
  ctx.fillStyle = "#2a1203"; ctx.fill();
  for (let dy = -2; dy < 8; dy++) for (let dx = -2; dx < 8; dx++) {
    const x = P(L.alcove.x0) + dx * 40 + (dy % 2) * 20, y = P(L.alcove.top - 0.3) + dy * 24;
    ctx.beginPath(); ctx.moveTo(x, y - 12); ctx.lineTo(x + 20, y); ctx.lineTo(x, y + 12); ctx.lineTo(x - 20, y); ctx.closePath();
    ctx.fillStyle = (dx + dy) % 2 ? "rgba(255,201,74,0.35)" : "rgba(255,201,74,0.12)"; ctx.fill();
  }
  ctx.restore();

  // Shooter lane and outlanes.
  ctx.fillStyle = "#08030f"; ctx.fillRect(P(L.wallR), P(5.5), P(L.outer - L.wallR), P(15));
  for (let y = 18.6; y > 7; y -= 0.6) { ctx.fillStyle = `rgba(255,255,255,${0.04 + (18.6 - y) * 0.006})`; ctx.fillRect(P(9.1), P(y), P(0.5), 6); }
  ctx.save(); ctx.translate(P(0.67), P(14.4)); ctx.rotate(-Math.PI / 2); neonText(ctx, "KICKBACK", 0, 0, 30, "#5dff8c", { glow: 10, weight: 800 }); ctx.restore();
  ctx.save(); ctx.translate(P(CX * 2 - 0.67), P(16.6)); ctx.rotate(-Math.PI / 2); neonText(ctx, "SPECIAL", 0, 0, 30, "#ff3b4e", { glow: 10, weight: 800 }); ctx.restore();

  // Labels.
  neonText(ctx, "BONUS", P(6.28), P(3.78), 30, "#ffc94a", { glow: 8, weight: 800 });
  neonText(ctx, "DJ-RAMPE", P(1.8), P(10.85), 26, "#ff8fd6", { glow: 8, weight: 800 });
  neonText(ctx, "NEON-RAMPE", P(CX * 2 - 1.8), P(10.85), 26, "#8ff3ff", { glow: 8, weight: 800 });
  neonText(ctx, "VIP LOUNGE", P(CX), P(11.98), 30, "#ffc94a", { glow: 10, weight: 900 });
  neonText(ctx, "NOCHMAL", P(CX), P(19.48), 24, "#ff7a86", { glow: 8, weight: 800 });

  // Stars sprinkled over the dark field.
  let seed = 9;
  const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < 260; i++) {
    const x = rnd() * c.width, y = rnd() * c.height, r = rnd() * 2.2 + 0.4;
    ctx.fillStyle = `rgba(255,255,255,${0.15 + rnd() * 0.35})`; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  }

  // Unlit inserts: dark tinted glass with a bevel.
  for (const ins of INSERTS) {
    ctx.save();
    shapePath(ctx, ins, 1.12); ctx.fillStyle = "rgba(0,0,0,0.6)"; ctx.fill();
    shapePath(ctx, ins);
    const ig = ctx.createRadialGradient(P(ins.x) - P(ins.r) * 0.3, P(ins.y) - P(ins.r) * 0.3, 1, P(ins.x), P(ins.y), P(ins.r) * 1.2);
    ig.addColorStop(0, ins.color + "88"); ig.addColorStop(1, ins.color + "26");
    ctx.fillStyle = ig; ctx.fill();
    ctx.lineWidth = 3; ctx.strokeStyle = ins.color + "aa"; ctx.stroke();
    if (ins.label && ins.shape === "circle") neonText(ctx, ins.label, P(ins.x), P(ins.y) + 1, ins.small ? 20 : 30, "#ffffff", { glow: 0, weight: 900 });
    ctx.restore();
    if (ins.label && ins.shape !== "circle" && ins.lamp !== "rampL" && ins.lamp !== "rampR" && ins.lamp !== "vip") neonText(ctx, ins.label, P(ins.x), P(ins.y + ins.r + 0.28), 22, ins.color, { glow: 6, weight: 800 });
  }

  // Outside the top arc: cabinet black.
  ctx.save();
  ctx.beginPath(); ctx.rect(0, 0, c.width, P(L.arc.cy)); ctx.arc(P(L.arc.cx), P(L.arc.cy), P(L.arc.r), Math.PI * 2, Math.PI, true); ctx.closePath();
  ctx.fillStyle = "#050208"; ctx.fill("evenodd");
  ctx.restore();
  return c;
}

// Apron with rules card, drawn as its own texture.
export function paintApron() {
  const c = document.createElement("canvas");
  c.width = 1392; c.height = 192;
  const ctx = c.getContext("2d");
  const g = ctx.createLinearGradient(0, 0, 0, 192);
  g.addColorStop(0, "#2b0d45"); g.addColorStop(1, "#12051f");
  ctx.fillStyle = g; ctx.fillRect(0, 0, 1392, 192);
  ctx.strokeStyle = "#ffc94a"; ctx.lineWidth = 5; ctx.strokeRect(8, 8, 1376, 176);
  ctx.fillStyle = "#f6eaff"; ctx.font = "800 25px Inter, Arial"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
  const lines = ["VIP-ZIELE ABRAEUMEN + SCOOP = LOCK   ·   3 LOCKS = MULTIBALL", "2 ORBITS = MISSION AN DER DJ-RAMPE   ·   5 MISSIONEN = LAST CALL", "B-A-R = BONUS X + KICKBACK   ·   SCHNELLE RAMPEN & ORBITS = COMBO"];
  lines.forEach((l, i) => ctx.fillText(l, 696, 52 + i * 44));
  return c;
}
