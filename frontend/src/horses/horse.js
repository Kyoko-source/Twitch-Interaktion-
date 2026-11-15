// Procedural race horse with jockey, drawn side-on and facing right in local units
// (nose to tail ~110, ground at y = 0, withers at y ~ -62). One call draws one frame of a
// transverse gallop; `phase` (0..1) walks through the stride.
const TAU = Math.PI * 2;

export const LOOKS = [
  { coat: "#5b3519", dark: "#2b170a", mane: "#140b06", silk: "#e63946", silk2: "#ffffff", cap: "#ffffff", pattern: "hoops", blaze: true, socks: [0, 0, 1, 0] },
  { coat: "#d6a144", dark: "#94631c", mane: "#f6e7c1", silk: "#1d4ed8", silk2: "#facc15", cap: "#facc15", pattern: "diamond", blaze: true, socks: [1, 1, 0, 0] },
  { coat: "#a3aab3", dark: "#5d646d", mane: "#3f4650", silk: "#16a34a", silk2: "#ffffff", cap: "#16a34a", pattern: "sash", blaze: false, socks: [0, 0, 0, 0] },
  { coat: "#24202a", dark: "#0d0b10", mane: "#050407", silk: "#7c3aed", silk2: "#fbbf24", cap: "#fbbf24", pattern: "stars", blaze: false, socks: [0, 0, 0, 1] },
  { coat: "#a5481c", dark: "#5e2409", mane: "#e88a4a", silk: "#f97316", silk2: "#111827", cap: "#111827", pattern: "halves", blaze: true, socks: [1, 0, 0, 1] },
  { coat: "#e6e8ec", dark: "#a7adb7", mane: "#cfd6df", silk: "#06b6d4", silk2: "#0b2a5b", cap: "#0b2a5b", pattern: "hoops", blaze: false, socks: [0, 0, 0, 0] },
  { coat: "#c48b48", dark: "#7b501f", mane: "#1b120a", silk: "#ec4899", silk2: "#ffffff", cap: "#ec4899", pattern: "spots", blaze: true, socks: [0, 1, 1, 0] },
  { coat: "#7d4a22", dark: "#3e220c", mane: "#120a05", silk: "#eab308", silk2: "#6d28d9", cap: "#dc2626", pattern: "diamond", blaze: false, socks: [1, 1, 1, 1], comb: true },
  { coat: "#868e98", dark: "#4b525b", mane: "#eef1f5", silk: "#0f766e", silk2: "#a7f3d0", cap: "#a7f3d0", pattern: "sash", blaze: true, socks: [0, 0, 1, 1], dapple: true },
];

// Level-25 skin "Phönix-Hengst": golden coat, flame mane and tail, wings of fire.
export const PHOENIX = { coat: "#f2b630", dark: "#a8480a", mane: "#ff6a00", silk: "#d61f1f", silk2: "#ffd23f", cap: "#ffd23f", pattern: "stars", blaze: true, socks: [1, 1, 1, 1], phoenix: true };
const FLAME = ["#ff2a00", "#ff6a00", "#ffa200", "#ffd84a", "#fff4b8"];

function flameGradient(c, x0, y0, x1, y1) {
  const g = c.createLinearGradient(x0, y0, x1, y1);
  FLAME.forEach((col, i) => g.addColorStop(i / (FLAME.length - 1), col));
  return g;
}

// Fiery wing behind the jockey: feathers fanning back and up, flapping with the stride.
function phoenixWing(c, phase, gait, time, far) {
  const flap = Math.sin(phase * TAU) * 0.32 * gait + Math.sin(time * 3.2) * 0.12 * (1 - gait);
  c.save();
  c.translate(-2, -66);
  c.rotate(-0.35 + flap + (far ? -0.18 : 0));
  c.globalAlpha = far ? 0.55 : 0.95;
  for (let i = 0; i < 7; i++) {
    const a = -0.15 - i * 0.2, len = 34 + i * 4 - (i > 4 ? (i - 4) * 7 : 0);
    const flick = Math.sin(time * 14 + i * 1.7) * 2.2;
    c.save();
    c.rotate(Math.PI + a);
    c.fillStyle = flameGradient(c, 0, 0, len, 0);
    c.beginPath();
    c.moveTo(0, -3);
    c.quadraticCurveTo(len * 0.55, -9 - flick, len + flick, 0);
    c.quadraticCurveTo(len * 0.55, 5, 0, 3);
    c.closePath(); c.fill();
    c.restore();
  }
  c.restore();
  c.globalAlpha = 1;
}

// Leg pivots and gallop timing: [x, y, phase offset, front?, near side?]
const LEGS = [
  [-26, -43, 0.0, false, false], [26, -41, 0.42, true, false],   // far hind, far fore (behind the body)
  [-22, -43, 0.1, false, true], [30, -41, 0.52, true, true],     // near hind, near fore
];

function shade(hex, k) {
  const n = parseInt(hex.slice(1), 16);
  const ch = (v) => Math.max(0, Math.min(255, Math.round(k > 0 ? v + (255 - v) * k : v * (1 + k))));
  return `rgb(${ch(n >> 16)},${ch((n >> 8) & 255)},${ch(n & 255)})`;
}

function leg(c, look, [hx, hy, off, front, near], phase, gait, sock) {
  const th = (phase + off) * TAU;
  const s = Math.sin(th);
  let upper, lower;
  if (front) {
    upper = (0.12 + 0.62 * s) * gait;
    lower = upper - 1.45 * Math.max(0, Math.sin(th + 0.5)) * gait;
  } else {
    upper = (-0.18 + 0.55 * s) * gait;
    lower = upper + 0.95 * Math.max(0, Math.sin(th - 0.6)) * gait - 0.12 * gait;
  }
  const l1 = front ? 21 : 23, l2 = front ? 22 : 21;
  const kx = hx + Math.sin(upper) * l1, ky = hy + Math.cos(upper) * l1;
  const fx = kx + Math.sin(lower) * l2, fy = ky + Math.cos(lower) * l2;
  const col = near ? look.coat : look.dark;
  c.lineCap = "round";
  c.strokeStyle = col;
  c.lineWidth = front ? 8 : 10;
  c.beginPath(); c.moveTo(hx, hy - 6); c.lineTo(kx, ky); c.stroke();
  c.lineWidth = 5;
  c.beginPath(); c.moveTo(kx, ky); c.lineTo(fx, fy); c.stroke();
  if (sock) {
    c.strokeStyle = near ? "#f4f1ea" : "#c9c4ba";
    c.lineWidth = 5.4;
    const t = 0.55;
    c.beginPath(); c.moveTo(kx + (fx - kx) * t, ky + (fy - ky) * t); c.lineTo(fx, fy); c.stroke();
  }
  // Hoof
  c.fillStyle = near ? "#2a2522" : "#161312";
  c.save(); c.translate(fx, fy); c.rotate(lower);
  c.beginPath(); c.moveTo(-3.4, -2); c.lineTo(3.8, -2); c.lineTo(4.6, 3); c.lineTo(-3.6, 3); c.closePath(); c.fill();
  c.restore();
}

function silkFill(c, look, x, y, w, h) {
  c.fillStyle = look.silk;
  c.fillRect(x, y, w, h);
  c.fillStyle = look.silk2;
  if (look.pattern === "hoops") for (let i = 0; i < 3; i++) c.fillRect(x + (i * w) / 3 + w / 9, y, w / 7, h);
  else if (look.pattern === "halves") c.fillRect(x, y + h / 2, w, h / 2);
  else if (look.pattern === "sash") { c.beginPath(); c.moveTo(x, y); c.lineTo(x + w * 0.35, y); c.lineTo(x + w, y + h); c.lineTo(x + w * 0.65, y + h); c.closePath(); c.fill(); }
  else if (look.pattern === "diamond") { c.beginPath(); c.moveTo(x + w / 2, y); c.lineTo(x + w, y + h / 2); c.lineTo(x + w / 2, y + h); c.lineTo(x, y + h / 2); c.closePath(); c.fill(); }
  else if (look.pattern === "spots") for (let i = 0; i < 4; i++) { c.beginPath(); c.arc(x + w * (0.2 + 0.25 * i), y + h * (i % 2 ? 0.3 : 0.7), Math.min(w, h) * 0.14, 0, TAU); c.fill(); }
  else if (look.pattern === "stars") for (let i = 0; i < 3; i++) star(c, x + w * (0.2 + 0.3 * i), y + h * 0.5, Math.min(w, h) * 0.22);
}

function star(c, x, y, r) {
  c.beginPath();
  for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.45 : r; c.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
  c.closePath(); c.fill();
}

/**
 * Draw one horse. Options:
 *  look      entry of LOOKS
 *  number    saddle cloth number
 *  phase     gallop phase 0..1
 *  gait      0 = standing, 1 = full gallop (blends leg swing, stretch and bob)
 *  time      seconds, for idle motion of tail, mane and head
 *  shadow    draw the ground shadow (default true)
 */
export function drawHorse(c, { look, number, phase = 0, gait = 1, time = 0, shadow = true, glow = null, crown = false, skin = null }) {
  if (skin === "phoenix") look = PHOENIX;
  const th = phase * TAU;
  const bob = -Math.abs(Math.sin(th)) * 3.2 * gait + Math.sin(time * 2.1) * 0.6 * (1 - gait);
  const pitch = Math.sin(th + 0.8) * 0.045 * gait;
  const reach = gait;   // neck stretches out at speed

  if (shadow) {
    c.fillStyle = "rgba(20,12,4,0.32)";
    c.beginPath(); c.ellipse(2, 1, 46 + 6 * gait, 6, 0, 0, TAU); c.fill();
  }
  if (look.phoenix) {   // warm aura around the whole horse
    const pulse = 0.5 + Math.sin(time * 4) * 0.12;
    const a = c.createRadialGradient(0, -55, 6, 0, -55, 80);
    a.addColorStop(0, `rgba(255,180,40,${0.42 * pulse})`); a.addColorStop(1, "rgba(255,80,0,0)");
    c.fillStyle = a; c.beginPath(); c.ellipse(0, -55, 84, 62, 0, 0, TAU); c.fill();
  }
  if (glow) {
    c.save();
    c.strokeStyle = glow; c.lineWidth = 3.5; c.globalAlpha = 0.85 + Math.sin(time * 6) * 0.15;
    c.beginPath(); c.ellipse(2, 1, 54, 10, 0, 0, TAU); c.stroke();
    c.restore();
  }

  c.save();
  c.translate(0, bob);
  c.rotate(pitch);

  if (look.phoenix) phoenixWing(c, phase, gait, time, true);
  // Far legs first (darker, behind the barrel).
  leg(c, look, LEGS[0], phase, gait, look.socks[0]);
  leg(c, look, LEGS[1], phase, gait, look.socks[1]);

  // Tail streams out behind at speed and swishes at rest.
  const tailWave = Math.sin(time * 9 + phase * TAU) * 4 * gait + Math.sin(time * 1.7) * 6 * (1 - gait);
  c.strokeStyle = look.mane; c.lineCap = "round";
  for (let i = 0; i < 4; i++) {
    if (look.phoenix) c.strokeStyle = FLAME[i];
    c.lineWidth = look.phoenix ? 7 - i * 1.4 + Math.sin(time * 18 + i) * 0.8 : 5 - i;
    c.beginPath();
    c.moveTo(-40, -55);
    c.quadraticCurveTo(-58 - 6 * gait, -54 + tailWave * 0.5 + i * 2 - 4 * gait, -66 - 10 * gait + i, -40 + tailWave + i * 3 - 14 * gait + 22 * (1 - gait));
    c.stroke();
  }

  // Barrel, chest and quarters.
  const g = c.createLinearGradient(0, -70, 0, -32);
  g.addColorStop(0, shade(look.coat, 0.22));
  g.addColorStop(0.55, look.coat);
  g.addColorStop(1, look.dark);
  c.fillStyle = g;
  c.beginPath();
  c.moveTo(-42, -52);
  c.bezierCurveTo(-44, -66, -26, -66, -12, -62);   // rump to back
  c.bezierCurveTo(2, -60, 14, -62, 22, -64);       // back to withers
  c.bezierCurveTo(36, -60, 42, -50, 38, -40);      // shoulder and chest
  c.bezierCurveTo(30, -33, 8, -34, -6, -35);       // belly
  c.bezierCurveTo(-24, -34, -36, -36, -42, -52);   // stifle back to rump
  c.closePath(); c.fill();
  if (look.dapple) {
    c.fillStyle = "rgba(255,255,255,0.22)";
    for (let i = 0; i < 9; i++) { c.beginPath(); c.arc(-34 + (i % 5) * 13 + (i > 4 ? 6 : 0), -55 + (i > 4 ? 9 : 0), 3.4, 0, TAU); c.fill(); }
  }
  // Rump highlight
  c.fillStyle = "rgba(255,255,255,0.13)";
  c.beginPath(); c.ellipse(-28, -57, 11, 5, -0.2, 0, TAU); c.fill();

  // Neck and head
  const nx = 4 * reach, ny = 7 * reach;   // stretched forward and lower at speed
  const nod = Math.sin(th - 0.4) * 2.4 * gait + Math.sin(time * 1.3) * 1.2 * (1 - gait);
  // Mane behind the crest, streaming back.
  c.fillStyle = look.phoenix ? flameGradient(c, 46, -95, 6, -60) : look.mane;
  c.beginPath();
  c.moveTo(18, -63);
  for (let i = 0; i <= 6; i++) {
    const t = i / 6, w = Math.sin(time * 12 + i * 1.3) * 1.8 * gait;
    const x = 18 + (44 + nx - 18) * t, y = -63 + (-93 + ny + nod + 63) * t;
    c.lineTo(x - 7 - 5 * gait + w * 0.5, y - 3 + w);
    c.lineTo(x + 2, y - 0.5);
  }
  c.lineTo(46 + nx, -90 + ny + nod);
  c.lineTo(20, -60);
  c.closePath(); c.fill();
  c.fillStyle = g;
  c.beginPath();
  c.moveTo(14, -60);
  c.bezierCurveTo(24, -76, 32 + nx, -90 + ny + nod, 44 + nx, -94 + ny + nod);   // crest
  c.lineTo(57 + nx, -84 + ny + nod);                                             // throat latch
  c.bezierCurveTo(52 + nx, -68 + ny, 46, -54, 39, -42);                          // underside of neck
  c.closePath(); c.fill();
  c.save();
  c.translate(49 + nx, -89 + ny + nod);
  c.rotate(0.62 + 0.18 * reach);
  c.scale(1.18, 1.18);
  c.fillStyle = look.coat;
  c.beginPath();
  c.moveTo(-6, -5); c.bezierCurveTo(4, -8, 20, -6, 25, -2);
  c.bezierCurveTo(28, 1, 27, 6, 22, 7);
  c.bezierCurveTo(14, 8, 2, 9, -6, 6);
  c.closePath(); c.fill();
  c.fillStyle = look.dark;
  c.beginPath(); c.ellipse(23, 3, 4.5, 4, 0, 0, TAU); c.fill();            // muzzle
  if (look.blaze) { c.fillStyle = "#f5f1e8"; c.beginPath(); c.moveTo(0, -6); c.lineTo(20, -3.6); c.lineTo(20, -1.4); c.lineTo(2, -3.4); c.closePath(); c.fill(); }
    // Bridle and blinkers in the silk colour
  c.strokeStyle = look.silk2 === "#ffffff" ? "#2b2b2b" : look.silk2; c.lineWidth = 1.4;
  c.beginPath(); c.moveTo(-3, -5); c.lineTo(-1, 7); c.moveTo(-2, 1); c.lineTo(22, 1); c.stroke();
  c.fillStyle = look.silk; c.beginPath(); c.moveTo(0, -5); c.lineTo(7, -4.5); c.lineTo(7, 0.5); c.lineTo(0, 1); c.closePath(); c.fill();
  c.fillStyle = "#0d0907"; c.beginPath(); c.arc(5.5, -1.8, 1.3, 0, TAU); c.fill();
  // Ears
  c.fillStyle = look.dark;
  c.beginPath(); c.moveTo(-5, -4); c.lineTo(-9, -13); c.lineTo(-1, -6); c.closePath(); c.fill();
  c.restore();

  // Saddle cloth with the number.
  c.fillStyle = "#f8fafc";
  c.beginPath(); c.roundRect?.(-22, -63, 22, 17, 3); if (!c.roundRect) c.rect(-22, -63, 22, 17); c.fill();
  c.strokeStyle = look.silk; c.lineWidth = 2; c.stroke();
  c.fillStyle = "#111";
  c.font = "bold 13px 'Space Grotesk', Inter, sans-serif";
  c.textAlign = "center"; c.textBaseline = "middle";
  c.fillText(String(number), -11, -54);

  if (look.phoenix) phoenixWing(c, phase, gait, time, false);
  // Jockey: crouched low over the withers, hands pumping at speed.
  const pump = Math.sin(th * 1) * 2 * gait;
  const jy = -2 * gait;
  // leg (near side)
  c.strokeStyle = "#f3f0e8"; c.lineWidth = 5; c.lineCap = "round";
  c.beginPath(); c.moveTo(-4, -72 + jy); c.lineTo(8, -66 + jy); c.lineTo(4, -56 + jy); c.stroke();
  c.fillStyle = "#151515"; c.beginPath(); c.ellipse(5, -55 + jy, 4, 2.6, 0.2, 0, TAU); c.fill();   // boot
  // torso in silks
  c.save();
  c.translate(-6, -76 + jy);
  c.rotate(-0.28 - 0.12 * gait);
  c.beginPath(); c.roundRect?.(0, -6, 22, 12, 6); if (!c.roundRect) c.rect(0, -6, 22, 12);
  c.save(); c.clip(); silkFill(c, look, 0, -6, 22, 12); c.restore();
  c.restore();
  // arm to the reins
  c.strokeStyle = look.silk; c.lineWidth = 4.4;
  c.beginPath(); c.moveTo(12, -80 + jy); c.lineTo(26 + pump, -74 + jy); c.lineTo(36 + pump + nx * 0.5, -70 + ny * 0.4 + jy); c.stroke();
  c.strokeStyle = "#3b2a1a"; c.lineWidth = 1.2;
  c.beginPath(); c.moveTo(36 + pump + nx * 0.5, -70 + ny * 0.4 + jy); c.lineTo(66 + nx, -78 + ny + nod); c.stroke();
  // head and cap
  c.fillStyle = "#f1c9a5"; c.beginPath(); c.arc(21, -88 + jy, 5, 0, TAU); c.fill();
  c.fillStyle = look.cap;
  c.beginPath(); c.arc(20, -89.5 + jy, 5.6, Math.PI * 1.02, Math.PI * 2.05); c.closePath(); c.fill();
  c.fillRect(22, -90.5 + jy, 6, 2);
  if (look.comb) { c.fillStyle = "#ef4444"; for (let i = 0; i < 3; i++) { c.beginPath(); c.arc(16 + i * 3.4, -95.5 + jy, 2, 0, TAU); c.fill(); } }
  if (crown) {   // level reward: a golden crown on the jockey
    c.fillStyle = "#ffcf2e"; c.strokeStyle = "#8a5a00"; c.lineWidth = 1;
    c.beginPath(); c.moveTo(13, -95 + jy); c.lineTo(14, -103 + jy); c.lineTo(17.5, -98 + jy); c.lineTo(20.5, -105 + jy); c.lineTo(23.5, -98 + jy); c.lineTo(27, -103 + jy); c.lineTo(28, -95 + jy); c.closePath(); c.fill(); c.stroke();
    c.fillStyle = "#ff3b5c"; c.beginPath(); c.arc(20.5, -98 + jy, 1.3, 0, TAU); c.fill();
  }
  c.fillStyle = "#0e0e0e"; c.fillRect(22, -89 + jy, 4.4, 1.6);   // goggles

  // Near legs in front of the body.
  leg(c, look, LEGS[2], phase, gait, look.socks[2]);
  leg(c, look, LEGS[3], phase, gait, look.socks[3]);
  c.restore();
}
