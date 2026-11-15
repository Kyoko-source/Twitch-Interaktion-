// Canvas side of Admin Stream Control: particles, weather, light and screen effects drawn over
// the stream. Every effect is a handler with optional init/update/draw; several can run at once.
// Written for the older Chromium inside Streamlabs/OBS (no newer canvas or CSS APIs).
const TAU = Math.PI * 2;
const rand = (a, b) => a + Math.random() * (b - a);
const pick = (list) => list[Math.floor(Math.random() * list.length)];
const CONF = ["#ff3b5c", "#ffcf4a", "#3fd6ff", "#7dff6b", "#b46bff", "#ff8a3d", "#ffffff", "#ff5ad6"];
const EMOJI_FONT = '"Segoe UI Emoji","Apple Color Emoji","Noto Color Emoji",sans-serif';
const emojiCache = new Map();

function emojiImg(e, size) {
  const s = Math.max(8, Math.round(size / 4) * 4);
  const key = `${e}|${s}`;
  let img = emojiCache.get(key);
  if (!img) {
    img = document.createElement("canvas");
    img.width = img.height = Math.ceil(s * 1.35);
    const c = img.getContext("2d");
    c.font = `${s}px ${EMOJI_FONT}`; c.textAlign = "center"; c.textBaseline = "middle";
    c.fillText(e, img.width / 2, img.height / 2 + s * 0.06);
    emojiCache.set(key, img);
  }
  return img;
}

// ------------------------------------------------------------------ particles
function part(o) { return { vx: 0, vy: 0, g: 0, drag: 0, life: 0, max: 12, size: 10, rot: 0, vr: 0, sway: 0, swayF: 2, ph: Math.random() * TAU, a: 1, ...o }; }

function stepParts(e, fx, dt) {
  const { W, H } = e;
  fx.parts = fx.parts.filter((p) => {
    p.life += dt;
    if (p.drag) { const k = Math.max(0, 1 - p.drag * dt); p.vx *= k; p.vy *= k; }
    p.vy += p.g * dt;
    p.x += p.vx * dt + (p.sway ? Math.sin(p.life * p.swayF + p.ph) * p.sway * dt : 0);
    p.y += p.vy * dt;
    p.rot += p.vr * dt;
    if (p.onStep && p.onStep(e, fx, p) === false) return false;
    if (p.life > p.max) return false;
    if (p.vy >= 0 && p.y > H + 160) return false;
    if (p.vy < 0 && p.y < -200 && !p.g) return false;
    if (p.x < -400 || p.x > W + 400) return false;
    return true;
  });
}

function drawPart(c, p) {
  const fade = p.fade ? Math.min(1, (p.max - p.life) / p.fade, p.life / 0.15) : 1;
  c.globalAlpha = p.a * fade * c.__fxAlpha;
  switch (p.kind) {
    case "conf": {
      c.save(); c.translate(p.x, p.y); c.rotate(p.rot); c.scale(1, Math.cos(p.life * p.flip));
      c.fillStyle = p.color; c.fillRect(-p.size / 2, -p.size * 0.3, p.size, p.size * 0.6); c.restore(); break;
    }
    case "emoji": {
      const img = emojiImg(p.emoji, p.size);
      const sc = p.pop ? Math.min(1, p.life / 0.18) * (1 + 0.15 * Math.sin(p.life * 10)) : 1;
      c.save(); c.translate(p.x, p.y + (p.bob ? -Math.abs(Math.sin(p.life * p.bob)) * p.size * 0.18 : 0)); c.rotate(p.rot); c.scale(sc * (p.flipX || 1), sc);
      c.drawImage(img, -img.width / 2, -img.height / 2); c.restore(); break;
    }
    case "coin": {
      c.save(); c.translate(p.x, p.y); c.rotate(p.rot * 0.2); c.scale(Math.abs(Math.cos(p.life * 7 + p.ph)) * 0.9 + 0.1, 1);
      c.fillStyle = "#c98a00"; c.beginPath(); c.arc(0, 0, p.size, 0, TAU); c.fill();
      c.fillStyle = "#ffd84a"; c.beginPath(); c.arc(0, 0, p.size * 0.8, 0, TAU); c.fill();
      c.fillStyle = "#fff6c4"; c.beginPath(); c.arc(-p.size * 0.25, -p.size * 0.25, p.size * 0.25, 0, TAU); c.fill(); c.restore(); break;
    }
    case "dot": c.fillStyle = p.color; c.beginPath(); c.arc(p.x, p.y, p.size, 0, TAU); c.fill(); break;
    case "spark": {
      c.fillStyle = p.color; c.globalAlpha *= Math.max(0, 1 - p.life / p.max);
      c.beginPath(); c.arc(p.x, p.y, p.size, 0, TAU); c.fill(); break;
    }
    case "streak": {
      c.strokeStyle = p.color; c.lineWidth = p.size; c.beginPath(); c.moveTo(p.x, p.y); c.lineTo(p.x - p.vx * p.len, p.y - p.vy * p.len); c.stroke(); break;
    }
    case "petal": {
      c.save(); c.translate(p.x, p.y); c.rotate(p.rot); c.scale(1, Math.cos(p.life * 3 + p.ph) * 0.5 + 0.6);
      c.fillStyle = p.color; c.beginPath(); c.ellipse(0, 0, p.size, p.size * 0.55, 0, 0, TAU); c.fill(); c.restore(); break;
    }
    case "feather": {
      c.save(); c.translate(p.x, p.y); c.rotate(p.rot);
      c.fillStyle = p.color; c.beginPath(); c.ellipse(0, 0, p.size * 0.32, p.size, 0, 0, TAU); c.fill();
      c.strokeStyle = "rgba(120,90,60,0.6)"; c.lineWidth = 1.2; c.beginPath(); c.moveTo(0, -p.size); c.lineTo(0, p.size * 1.25); c.stroke(); c.restore(); break;
    }
    case "bubble": {
      c.strokeStyle = "rgba(220,245,255,0.8)"; c.lineWidth = 1.6; c.beginPath(); c.arc(p.x, p.y, p.size, 0, TAU); c.stroke();
      c.fillStyle = "rgba(255,255,255,0.18)"; c.fill();
      c.fillStyle = "rgba(255,255,255,0.8)"; c.beginPath(); c.arc(p.x - p.size * 0.35, p.y - p.size * 0.35, p.size * 0.22, 0, TAU); c.fill(); break;
    }
    case "flame": {
      const k = p.life / p.max, r = p.size * (1 - k * 0.7);
      const g = c.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
      g.addColorStop(0, k < 0.3 ? "rgba(255,250,200,0.9)" : "rgba(255,200,80,0.8)");
      g.addColorStop(0.4, k < 0.5 ? "rgba(255,140,30,0.6)" : "rgba(230,60,20,0.5)");
      g.addColorStop(1, "rgba(200,30,10,0)");
      c.fillStyle = g; c.beginPath(); c.arc(p.x, p.y, r, 0, TAU); c.fill(); break;
    }
    case "balloon": {
      c.save(); c.translate(p.x, p.y); c.rotate(Math.sin(p.life * 1.4 + p.ph) * 0.12);
      c.strokeStyle = "rgba(255,255,255,0.7)"; c.lineWidth = 1.5; c.beginPath(); c.moveTo(0, p.size * 1.15); c.quadraticCurveTo(10, p.size * 1.8, 0, p.size * 2.6); c.stroke();
      c.fillStyle = p.color; c.beginPath(); c.ellipse(0, 0, p.size * 0.82, p.size, 0, 0, TAU); c.fill();
      c.beginPath(); c.moveTo(-6, p.size * 1.12); c.lineTo(6, p.size * 1.12); c.lineTo(0, p.size * 0.95); c.fill();
      c.fillStyle = "rgba(255,255,255,0.45)"; c.beginPath(); c.ellipse(-p.size * 0.3, -p.size * 0.4, p.size * 0.18, p.size * 0.3, -0.4, 0, TAU); c.fill(); c.restore(); break;
    }
    case "star": {
      const tw = Math.sin((p.life / p.max) * Math.PI);
      c.globalAlpha *= tw; c.fillStyle = p.color; c.save(); c.translate(p.x, p.y); c.rotate(p.rot);
      c.beginPath();
      for (let i = 0; i < 8; i++) { const r = i % 2 ? p.size * 0.22 : p.size; const a = (i * Math.PI) / 4; c.lineTo(Math.cos(a) * r, Math.sin(a) * r); }
      c.closePath(); c.fill(); c.restore(); break;
    }
    case "rocket": c.fillStyle = "#fff6d0"; c.beginPath(); c.arc(p.x, p.y, 3.5, 0, TAU); c.fill(); break;
    default: break;
  }
}

// Emit `rate` particles per second while the effect is running.
function emit(fx, key, rate, dt, make) {
  if (fx.t > fx.dur) return;
  fx.acc[key] = (fx.acc[key] || 0) + rate * dt;
  while (fx.acc[key] >= 1) { fx.acc[key] -= 1; fx.parts.push(make()); }
}

function lightning(e, fromX) {
  const pts = [[fromX, -10]];
  let x = fromX, y = -10;
  while (y < e.H * rand(0.55, 0.85)) { x += rand(-60, 60); y += rand(30, 70); pts.push([x, y]); }
  const branches = [];
  for (let i = 2; i < pts.length - 2; i += 3) {
    const b = [pts[i]]; let bx = pts[i][0], by = pts[i][1];
    for (let k = 0; k < 4; k++) { bx += rand(-70, 70); by += rand(25, 55); b.push([bx, by]); }
    branches.push(b);
  }
  return { pts, branches, life: 0 };
}

function drawBolt(c, bolt, alpha) {
  for (const [w, col] of [[14, "rgba(150,170,255,0.25)"], [5, "rgba(210,220,255,0.7)"], [2, "#ffffff"]]) {
    c.globalAlpha = alpha; c.strokeStyle = col; c.lineWidth = w; c.lineJoin = "round";
    for (const line of [bolt.pts, ...bolt.branches]) { c.beginPath(); line.forEach(([x, y], i) => (i ? c.lineTo(x, y) : c.moveTo(x, y))); c.stroke(); }
  }
}

function rain(e, fx, dt, rate, color, slant = 220) {
  emit(fx, "rain", rate, dt, () => part({ kind: "streak", x: rand(-0.2 * e.W, 1.1 * e.W), y: rand(-80, -10), vx: slant, vy: rand(1500, 1900), size: rand(1, 2.2), len: 0.022, color, max: 2,
    onStep: (en, f, p) => { if (p.y > en.H - rand(0, 40)) { if (Math.random() < 0.3) f.parts.push(part({ kind: "dot", x: p.x, y: en.H - 4, size: rand(1.5, 3), color, vy: -rand(60, 160), vx: rand(-60, 60), g: 900, max: 0.4 })); return false; } return true; } }));
}

function noise(c, e, n, color) {
  c.fillStyle = color;
  for (let i = 0; i < n; i++) c.fillRect(Math.random() * e.W, Math.random() * e.H, 2, 2);
}

function textBurst(e, fx, emojis, n, power = 1) {
  for (let i = 0; i < n; i++) {
    const a = rand(0, TAU), v = rand(300, 900) * power;
    fx.parts.push(part({ kind: "emoji", emoji: pick(emojis), x: e.W / 2, y: e.H * 0.45, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 300, g: 900, drag: 0.6, size: rand(40, 80), vr: rand(-4, 4), max: 4 }));
  }
}

// ------------------------------------------------------------------ effects
export const HANDLERS = {
  "confetti-cannon": {
    init: (e, fx) => { fx.s.shots = [0, 0.45, 1, 1.7, 2.5, 3.4]; fx.s.i = 0; },
    update: (e, fx) => {
      while (fx.s.i < fx.s.shots.length && fx.t >= fx.s.shots[fx.s.i] && fx.t < fx.dur) {
        fx.s.i++; e.sound("cannon");
        for (const side of [-1, 1]) {
          const x0 = side < 0 ? 0 : e.W;
          for (let i = 0; i < 170; i++) fx.parts.push(part({ kind: "conf", x: x0, y: e.H, vx: -side * rand(250, 1500) * e.sx, vy: -rand(1000, 2150) * e.sy, g: 1250 * e.sy, drag: 0.85, size: rand(10, 22), color: pick(CONF), vr: rand(-14, 14), flip: rand(5, 14), max: 7 }));
          for (let i = 0; i < 26; i++) fx.parts.push(part({ kind: "spark", x: x0, y: e.H - 10, vx: -side * rand(100, 700), vy: -rand(200, 900), g: 600, size: rand(2, 5), color: "#fff6c4", max: 0.7 }));
        }
      }
    },
  },
  "confetti-rain": { update: (e, fx, dt) => emit(fx, "c", 110, dt, () => part({ kind: "conf", x: rand(0, e.W), y: -20, vx: rand(-60, 60), vy: rand(160, 320), size: rand(10, 18), color: pick(CONF), vr: rand(-6, 6), flip: rand(4, 10), sway: 80, swayF: rand(1, 3), max: 14 })) },
  fireworks: {
    update: (e, fx, dt) => {
      fx.s.next = (fx.s.next ?? 0) - dt;
      if (fx.s.next <= 0 && fx.t < fx.dur) {
        fx.s.next = rand(0.3, 0.75);
        const hue = Math.floor(rand(0, 360));
        fx.parts.push(part({ kind: "rocket", x: rand(0.12, 0.88) * e.W, y: e.H, vx: rand(-60, 60), vy: -rand(950, 1300) * e.sy, g: 520 * e.sy, max: rand(0.9, 1.3),
          onStep: (en, f, p) => {
            if (Math.random() < 0.7) f.parts.push(part({ kind: "spark", x: p.x, y: p.y, vx: rand(-20, 20), vy: rand(20, 80), size: 2, color: "#ffd9a0", max: 0.4 }));
            if (p.life >= p.max - 0.02) {
              en.sound("firework");
              const n = 110, ring = Math.random() < 0.4;
              for (let i = 0; i < n; i++) {
                const a = (i / n) * TAU, v = ring ? 380 : rand(80, 440);
                f.parts.push(part({ kind: "spark", x: p.x, y: p.y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, g: 170, drag: 1.1, size: rand(2, 4), color: `hsl(${hue + rand(-25, 25)},100%,${rand(55, 75)}%)`, max: rand(1.3, 2.2) }));
              }
              return false;
            }
            return true;
          } }));
      }
    },
    composite: "lighter",
  },
  balloons: { update: (e, fx, dt) => emit(fx, "b", 5, dt, () => part({ kind: "balloon", x: rand(0, e.W), y: e.H + 80, vy: -rand(120, 230), sway: 40, swayF: rand(0.8, 1.6), size: rand(36, 62), color: pick(CONF.slice(0, 6)), max: 16 })) },
  "gold-rain": {
    update: (e, fx, dt) => {
      emit(fx, "g", 45, dt, () => part({ kind: "coin", x: rand(0, e.W), y: -30, vx: rand(-40, 40), vy: rand(250, 520), g: 380, size: rand(12, 24), vr: rand(-6, 6), max: 6 }));
      fx.s.c = (fx.s.c || 0) + dt; if (fx.s.c > 0.12 && fx.t < fx.dur) { fx.s.c = 0; e.sound("coin"); }
    },
  },
  "money-rain": { update: (e, fx, dt) => emit(fx, "m", 14, dt, () => part({ kind: "emoji", emoji: pick(["💸", "💵", "💶", "💰"]), x: rand(0, e.W), y: -50, vy: rand(110, 220), sway: 90, swayF: rand(1, 2.5), vr: rand(-2, 2), size: rand(44, 72), max: 14 })) },
  stars: { update: (e, fx, dt) => emit(fx, "s", 34, dt, () => part({ kind: Math.random() < 0.3 ? "emoji" : "star", emoji: "✨", x: rand(0, e.W), y: rand(0, e.H), size: rand(10, 34), color: pick(["#fff6c4", "#ffffff", "#ffe27a", "#bfefff"]), vr: rand(-1, 1), max: rand(0.8, 1.6), fade: 0.4 })), composite: "lighter" },
  hearts: { update: (e, fx, dt) => emit(fx, "h", 16, dt, () => part({ kind: "emoji", emoji: pick(["💖", "❤️", "💕", "💗", "💘"]), x: rand(0, e.W), y: e.H + 40, vy: -rand(160, 320), sway: 70, swayF: rand(1, 3), size: rand(36, 84), max: 9 })) },
  applause: { update: (e, fx, dt) => emit(fx, "a", 12, dt, () => part({ kind: "emoji", emoji: pick(["👏", "👏", "🙌", "👏🏻", "👏🏽"]), x: rand(0.05, 0.95) * e.W, y: rand(0.15, 0.9) * e.H, size: rand(50, 110), pop: true, vr: rand(-0.5, 0.5), max: 0.9, fade: 0.3 })) },
  disco: {
    draw: (e, c, fx) => {
      const cx = e.W / 2, cy = 70, cols = ["255,60,160", "60,200,255", "255,220,60", "120,255,120", "180,90,255", "255,120,40"];
      c.globalCompositeOperation = "lighter";
      cols.forEach((col, i) => {
        const a = Math.PI / 2 + Math.sin(e.time * (0.7 + i * 0.13) + i * 1.7) * 0.9, len = e.H * 1.3, w = 0.16;
        const g = c.createLinearGradient(cx, cy, cx + Math.cos(a) * len, cy + Math.sin(a) * len);
        g.addColorStop(0, `rgba(${col},0.55)`); g.addColorStop(1, `rgba(${col},0)`);
        c.globalAlpha = c.__fxAlpha * 0.8; c.fillStyle = g;
        c.beginPath(); c.moveTo(cx, cy); c.lineTo(cx + Math.cos(a - w) * len, cy + Math.sin(a - w) * len); c.lineTo(cx + Math.cos(a + w) * len, cy + Math.sin(a + w) * len); c.closePath(); c.fill();
      });
      for (let i = 0; i < 70; i++) {
        const x = (Math.sin(i * 12.9898 + e.time * 0.6) * 0.5 + 0.5) * e.W, y = (Math.cos(i * 78.233 + e.time * 0.4) * 0.5 + 0.5) * e.H;
        c.globalAlpha = c.__fxAlpha * (0.4 + 0.4 * Math.sin(e.time * 6 + i)); c.fillStyle = "#fff"; c.fillRect(x, y, 4, 4);
      }
      c.globalCompositeOperation = "source-over";
      // mirror ball
      c.globalAlpha = c.__fxAlpha;
      const g = c.createRadialGradient(cx - 20, cy - 20, 5, cx, cy, 60);
      g.addColorStop(0, "#ffffff"); g.addColorStop(0.5, "#b8c0d0"); g.addColorStop(1, "#4a5060");
      c.fillStyle = g; c.beginPath(); c.arc(cx, cy, 58, 0, TAU); c.fill();
      for (let i = 0; i < 40; i++) { const a = (i / 40) * TAU + e.time, r = (i % 4) * 12 + 10; c.fillStyle = Math.sin(e.time * 8 + i) > 0.5 ? "#ffffff" : "rgba(255,255,255,0.25)"; c.fillRect(cx + Math.cos(a) * r - 3, cy + Math.sin(a) * r * 0.9 - 3, 6, 6); }
      c.strokeStyle = "#888"; c.lineWidth = 3; c.beginPath(); c.moveTo(cx, 0); c.lineTo(cx, cy - 58); c.stroke();
    },
  },
  rainbow: {
    draw: (e, c, fx) => {
      const cols = ["#ff3b3b", "#ff9a2e", "#ffe14a", "#4ce06b", "#3fb6ff", "#5a6bff", "#b46bff"];
      const reveal = Math.min(1, fx.t / 1.6), cx = e.W / 2, cy = e.H * 1.08, r0 = e.H * 0.95, bw = e.H * 0.035;
      cols.forEach((col, i) => { c.globalAlpha = c.__fxAlpha * 0.62; c.strokeStyle = col; c.lineWidth = bw; c.beginPath(); c.arc(cx, cy, r0 - i * bw, Math.PI, Math.PI + Math.PI * reveal); c.stroke(); });
    },
    update: (e, fx, dt) => emit(fx, "s", 20, dt, () => { const a = Math.PI + Math.random() * Math.PI * Math.min(1, fx.t / 1.6); const r = e.H * 0.95 - rand(0, 7) * e.H * 0.035; return part({ kind: "star", x: e.W / 2 + Math.cos(a) * r, y: e.H * 1.08 + Math.sin(a) * r, size: rand(8, 18), color: "#fff", max: 1 }); }),
  },
  hype: {
    update: (e, fx, dt) => {
      emit(fx, "f", 160, dt, () => part({ kind: "flame", x: rand(0, e.W), y: e.H + 20, vx: rand(-30, 30), vy: -rand(200, 520), size: rand(40, 90), max: rand(0.7, 1.3) }));
      emit(fx, "e", 6, dt, () => part({ kind: "emoji", emoji: "🔥", x: rand(0, e.W), y: e.H + 40, vy: -rand(300, 500), size: rand(50, 90), max: 4 }));
    },
    composite: "lighter",
  },

  "noir-rain": {
    update: (e, fx, dt) => {
      rain(e, fx, dt, 520, "rgba(225,228,235,0.55)", 180);
      fx.s.next = (fx.s.next ?? rand(2, 4)) - dt;
      if (fx.s.next <= 0 && fx.t < fx.dur) { fx.s.next = rand(5, 9); fx.s.flash = 1; e.sound("thunder-far"); }
      fx.s.flash = Math.max(0, (fx.s.flash || 0) - dt * 2.5);
    },
    draw: (e, c, fx) => {
      c.globalAlpha = c.__fxAlpha * 0.5; noise(c, e, 900, "rgba(255,255,255,0.35)"); noise(c, e, 900, "rgba(0,0,0,0.45)");
      if (fx.s.flash > 0) { c.globalAlpha = c.__fxAlpha * Math.min(0.75, fx.s.flash * (Math.random() < 0.3 ? 0.4 : 1)); c.fillStyle = "#fff"; c.fillRect(0, 0, e.W, e.H); }
    },
  },
  thunderstorm: {
    update: (e, fx, dt) => {
      rain(e, fx, dt, 900, "rgba(190,205,235,0.55)", 340);
      fx.s.next = (fx.s.next ?? 0.8) - dt;
      if (fx.s.next <= 0 && fx.t < fx.dur) { fx.s.next = rand(2.2, 4.5); fx.s.bolt = lightning(e, rand(0.15, 0.85) * e.W); fx.s.flash = 1; e.sound("thunder"); }
      fx.s.flash = Math.max(0, (fx.s.flash || 0) - dt * 3);
      if (fx.s.bolt) { fx.s.bolt.life += dt; if (fx.s.bolt.life > 0.35) fx.s.bolt = null; }
    },
    draw: (e, c, fx) => {
      if (fx.s.flash > 0) { c.globalAlpha = c.__fxAlpha * Math.min(0.6, fx.s.flash); c.fillStyle = "#dfe6ff"; c.fillRect(0, 0, e.W, e.H); }
      if (fx.s.bolt) drawBolt(c, fx.s.bolt, c.__fxAlpha * (Math.random() < 0.25 ? 0.3 : 1));
    },
  },
  snow: { update: (e, fx, dt) => emit(fx, "s", 70, dt, () => part({ kind: "dot", color: "rgba(255,255,255,0.9)", x: rand(-50, e.W + 50), y: -10, vx: rand(-20, 20), vy: rand(40, 120), sway: 30, swayF: rand(0.5, 1.5), size: rand(1.5, 5.5), max: 30 })) },
  fog: {
    init: (e, fx) => { fx.s.blobs = Array.from({ length: 16 }, () => ({ x: rand(-0.2, 1.2) * e.W, y: rand(0, 1) * e.H, r: rand(260, 560), vx: rand(15, 55) })); },
    draw: (e, c, fx) => {
      for (const b of fx.s.blobs) {
        b.x += b.vx * e.dt; if (b.x - b.r > e.W) b.x = -b.r;
        const g = c.createRadialGradient(b.x, b.y, 0, b.x, b.y, b.r);
        g.addColorStop(0, "rgba(225,230,238,0.42)"); g.addColorStop(1, "rgba(225,230,238,0)");
        c.globalAlpha = c.__fxAlpha; c.fillStyle = g; c.fillRect(b.x - b.r, b.y - b.r, b.r * 2, b.r * 2);
      }
    },
  },
  sandstorm: {
    init: (e, fx) => { fx.s.blobs = Array.from({ length: 12 }, () => ({ x: rand(0, e.W), y: rand(0, e.H), r: rand(200, 480), vx: rand(200, 420) })); },
    update: (e, fx, dt) => emit(fx, "s", 700, dt, () => part({ kind: "streak", x: -40, y: rand(0, e.H), vx: rand(900, 1600), vy: rand(-60, 60), size: rand(1, 2.4), len: 0.012, color: "rgba(226,186,120,0.55)", max: 3 })),
    draw: (e, c, fx) => {
      for (const b of fx.s.blobs) {
        b.x += b.vx * e.dt; if (b.x - b.r > e.W) { b.x = -b.r; b.y = rand(0, e.H); }
        const g = c.createRadialGradient(b.x, b.y, 0, b.x, b.y, b.r);
        g.addColorStop(0, "rgba(200,150,80,0.4)"); g.addColorStop(1, "rgba(200,150,80,0)");
        c.globalAlpha = c.__fxAlpha; c.fillStyle = g; c.fillRect(b.x - b.r, b.y - b.r, b.r * 2, b.r * 2);
      }
    },
  },
  autumn: { update: (e, fx, dt) => emit(fx, "l", 11, dt, () => part({ kind: "emoji", emoji: pick(["🍂", "🍁", "🍂"]), x: rand(-50, e.W), y: -40, vx: rand(20, 90), vy: rand(70, 150), sway: 110, swayF: rand(1, 2.2), vr: rand(-3, 3), size: rand(30, 58), max: 20 })) },
  sakura: { update: (e, fx, dt) => emit(fx, "p", 45, dt, () => part({ kind: "petal", color: pick(["#ffc4dc", "#ffb0cf", "#ffe0ec", "#ff9cc2"]), x: rand(-0.3 * e.W, e.W), y: -20, vx: rand(80, 170), vy: rand(50, 120), sway: 50, swayF: rand(1, 2.5), vr: rand(-3, 3), size: rand(7, 13), max: 20 })) },
  underwater: {
    update: (e, fx, dt) => emit(fx, "b", 28, dt, () => part({ kind: "bubble", x: rand(0, e.W), y: e.H + 20, vy: -rand(80, 220), sway: 40, swayF: rand(2, 4), size: rand(4, 18), max: 14 })),
    draw: (e, c, fx) => {
      c.globalCompositeOperation = "lighter";
      for (let i = 0; i < 7; i++) {
        const x = (i / 6) * e.W + Math.sin(e.time * 0.5 + i) * 120;
        const g = c.createLinearGradient(x, 0, x + 200, e.H);
        g.addColorStop(0, "rgba(150,230,255,0.22)"); g.addColorStop(1, "rgba(150,230,255,0)");
        c.globalAlpha = c.__fxAlpha; c.fillStyle = g;
        c.beginPath(); c.moveTo(x - 40, 0); c.lineTo(x + 40, 0); c.lineTo(x + 260, e.H); c.lineTo(x + 120, e.H); c.closePath(); c.fill();
      }
      c.globalCompositeOperation = "source-over";
    },
  },
  fire: {
    update: (e, fx, dt) => {
      emit(fx, "f", 260, dt, () => part({ kind: "flame", x: rand(-40, e.W + 40), y: e.H + 30, vx: rand(-30, 30), vy: -rand(150, 430), size: rand(40, 95), max: rand(0.8, 1.6) }));
      emit(fx, "s", 30, dt, () => part({ kind: "spark", x: rand(0, e.W), y: e.H, vx: rand(-60, 60), vy: -rand(300, 700), g: 150, size: rand(1.5, 3), color: "#ffcf6b", max: rand(1, 2.2) }));
    },
    composite: "lighter",
  },
  frost: {
    init: (e, fx) => {
      const segs = [];
      const branch = (x, y, a, len, depth, t0) => {
        const x2 = x + Math.cos(a) * len, y2 = y + Math.sin(a) * len;
        segs.push({ x, y, x2, y2, t: t0, w: Math.max(0.6, 3 - depth * 0.6) });
        if (depth < 4) for (const d of [-0.55, 0.55]) branch(x2, y2, a + d + rand(-0.2, 0.2), len * rand(0.55, 0.75), depth + 1, t0 + rand(0.15, 0.35));
        if (depth < 3) branch(x2, y2, a + rand(-0.15, 0.15), len * 0.8, depth + 1, t0 + 0.2);
      };
      for (let i = 0; i < 46; i++) {
        const side = i % 4, k = Math.random();
        const [x, y, a] = side === 0 ? [k * e.W, 0, Math.PI / 2] : side === 1 ? [k * e.W, e.H, -Math.PI / 2] : side === 2 ? [0, k * e.H, 0] : [e.W, k * e.H, Math.PI];
        branch(x, y, a + rand(-0.6, 0.6), rand(40, 110), 0, rand(0, 1.6));
      }
      fx.s.segs = segs;
    },
    draw: (e, c, fx) => {
      c.globalAlpha = c.__fxAlpha * 0.85; c.strokeStyle = "rgba(235,248,255,0.85)"; c.lineCap = "round";
      for (const s of fx.s.segs) {
        const k = Math.min(1, (fx.t - s.t) / 0.3);
        if (k <= 0) continue;
        c.lineWidth = s.w; c.beginPath(); c.moveTo(s.x, s.y); c.lineTo(s.x + (s.x2 - s.x) * k, s.y + (s.y2 - s.y) * k); c.stroke();
      }
    },
  },
  sunset: {
    draw: (e, c, fx) => {
      const sx = e.W * 0.82, sy = e.H * 0.16, cx = e.W / 2, cy = e.H / 2;
      c.globalCompositeOperation = "lighter";
      const sun = c.createRadialGradient(sx, sy, 0, sx, sy, 260);
      sun.addColorStop(0, "rgba(255,240,200,0.9)"); sun.addColorStop(0.2, "rgba(255,190,90,0.45)"); sun.addColorStop(1, "rgba(255,120,40,0)");
      c.globalAlpha = c.__fxAlpha; c.fillStyle = sun; c.fillRect(sx - 260, sy - 260, 520, 520);
      [[0.35, 50, "255,160,80"], [0.6, 30, "255,120,200"], [0.9, 80, "120,200,255"], [1.25, 40, "255,220,120"], [1.5, 110, "255,140,80"]].forEach(([k, r, col]) => {
        const x = sx + (cx - sx) * k * 2, y = sy + (cy - sy) * k * 2;
        const g = c.createRadialGradient(x, y, 0, x, y, r);
        g.addColorStop(0, `rgba(${col},0.22)`); g.addColorStop(0.7, `rgba(${col},0.12)`); g.addColorStop(1, `rgba(${col},0)`);
        c.fillStyle = g; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill();
      });
      c.globalCompositeOperation = "source-over";
    },
  },
  "night-vision": { draw: (e, c) => { c.globalAlpha = c.__fxAlpha * 0.5; noise(c, e, 1400, "rgba(170,255,170,0.5)"); } },

  vhs: {
    draw: (e, c, fx) => {
      c.globalAlpha = c.__fxAlpha;
      const band = ((e.time * 0.18) % 1.3) * e.H - 0.15 * e.H;
      for (let i = 0; i < 60; i++) { c.fillStyle = `rgba(255,255,255,${Math.random() * 0.25})`; c.fillRect(Math.random() * e.W * 0.3, band + Math.random() * 60, rand(40, e.W), 1.5); }
      if (Math.random() < 0.06) { const y = rand(0, e.H); c.fillStyle = "rgba(255,255,255,0.15)"; c.fillRect(0, y, e.W, rand(2, 10)); }
      c.fillStyle = "rgba(255,0,80,0.07)"; c.fillRect(Math.sin(e.time * 3) * 6, 0, e.W, e.H);
      c.font = `${Math.round(e.H * 0.045)}px "Courier New", monospace`; c.fillStyle = "#ffffff"; c.textBaseline = "top";
      c.shadowColor = "rgba(0,0,0,0.8)"; c.shadowBlur = 6;
      c.fillText("▶ PLAY", e.W * 0.05, e.H * 0.06);
      if (Math.floor(e.time * 2) % 2) c.fillText("● REC", e.W * 0.83, e.H * 0.06);
      const s = Math.floor(fx.t), clock = `0:${String(12 + Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
      c.fillText(`SP  ${clock}`, e.W * 0.05, e.H * 0.88);
      c.fillText("NOV. 15 1996", e.W * 0.74, e.H * 0.88);
      c.shadowBlur = 0;
    },
  },
  glitch: {
    draw: (e, c) => {
      c.globalAlpha = c.__fxAlpha;
      const n = Math.floor(rand(4, 14));
      for (let i = 0; i < n; i++) {
        c.fillStyle = pick(["rgba(0,255,255,0.35)", "rgba(255,0,200,0.35)", "rgba(255,255,255,0.5)", "rgba(0,0,0,0.7)", "rgba(80,255,80,0.3)"]);
        const full = Math.random() < 0.35;
        c.fillRect(full ? 0 : rand(0, e.W), rand(0, e.H), full ? e.W : rand(60, 600), rand(4, full ? 30 : 90));
      }
      if (Math.random() < 0.08) { c.fillStyle = "rgba(0,0,0,0.85)"; c.fillRect(0, 0, e.W, e.H); }
      if (Math.random() < 0.5) {
        c.font = `900 ${Math.round(e.H * 0.08)}px Inter, sans-serif`; c.textAlign = "center"; c.textBaseline = "middle";
        const dx = rand(-14, 14);
        c.fillStyle = "rgba(255,0,200,0.8)"; c.fillText("SIGNAL GESTÖRT", e.W / 2 + dx, e.H / 2);
        c.fillStyle = "rgba(0,255,255,0.8)"; c.fillText("SIGNAL GESTÖRT", e.W / 2 - dx, e.H / 2 + 3);
        c.fillStyle = "#fff"; c.fillText("SIGNAL GESTÖRT", e.W / 2, e.H / 2);
      }
    },
  },
  matrix: {
    init: (e, fx) => {
      const size = Math.round(e.H / 40);
      fx.s.size = size;
      fx.s.cols = Array.from({ length: Math.ceil(e.W / size) }, () => ({ y: rand(-40, 0), v: rand(8, 22), chars: [] }));
    },
    draw: (e, c, fx) => {
      const { size, cols } = fx.s, G = "アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ハヒフヘホ";
      c.globalAlpha = c.__fxAlpha * 0.6; c.fillStyle = "#000"; c.fillRect(0, 0, e.W, e.H);
      c.font = `${size}px "MS Gothic", monospace`; c.textAlign = "center"; c.textBaseline = "top";
      cols.forEach((col, i) => {
        col.y += col.v * e.dt;
        if ((col.y - 30) * size > e.H) { col.y = rand(-20, 0); col.v = rand(8, 22); }
        const head = Math.floor(col.y);
        for (let k = 0; k < 26; k++) {
          const row = head - k;
          if (row < 0 || row * size > e.H) continue;
          if (!col.chars[row] || Math.random() < 0.02) col.chars[row] = G[Math.floor(Math.random() * G.length)];
          c.globalAlpha = c.__fxAlpha * (k === 0 ? 1 : Math.max(0, 1 - k / 26));
          c.fillStyle = k === 0 ? "#e8ffe8" : "#2bff6a";
          c.fillText(col.chars[row], i * size + size / 2, row * size);
        }
      });
    },
  },
  "old-film": {
    draw: (e, c) => {
      c.globalAlpha = c.__fxAlpha;
      if (Math.random() < 0.5) { c.fillStyle = `rgba(${Math.random() < 0.5 ? "255,240,210" : "0,0,0"},${rand(0, 0.08)})`; c.fillRect(0, 0, e.W, e.H); }
      c.strokeStyle = "rgba(30,20,10,0.55)";
      for (let i = 0; i < 3; i++) if (Math.random() < 0.5) { const x = rand(0, e.W); c.lineWidth = rand(0.6, 2); c.beginPath(); c.moveTo(x, 0); c.lineTo(x + rand(-10, 10), e.H); c.stroke(); }
      c.fillStyle = "rgba(20,10,0,0.6)";
      for (let i = 0; i < 12; i++) { c.beginPath(); c.arc(rand(0, e.W), rand(0, e.H), rand(1, 4), 0, TAU); c.fill(); }
      if (Math.random() < 0.05) { c.lineWidth = 1.5; c.beginPath(); const x = rand(0, e.W), y = rand(0, e.H); c.moveTo(x, y); c.bezierCurveTo(x + 40, y + 20, x - 30, y + 60, x + 20, y + 100); c.stroke(); }
    },
  },
  "crt-off": {
    draw: (e, c, fx) => {
      const t = fx.t, end = fx.dur, H = e.H, W = e.W;
      let k;
      if (t < 0.45) k = t / 0.45; else if (t > end - 0.6) k = Math.max(0, (end - t) / 0.6); else k = 1;
      c.globalAlpha = 1;
      c.fillStyle = "#000";
      const half = (H / 2) * Math.min(1, k * 1.15);
      c.fillRect(0, 0, W, half); c.fillRect(0, H - half, W, half);
      if (k >= 1) c.fillRect(0, 0, W, H);
      const lineW = k < 0.8 ? W : W * Math.max(0, 1 - (k - 0.8) / 0.2);
      if (k > 0 && k < 1 || (t > 0.45 && t < 0.75)) {
        const g = c.createLinearGradient(0, H / 2 - 20, 0, H / 2 + 20);
        g.addColorStop(0, "rgba(255,255,255,0)"); g.addColorStop(0.5, "rgba(255,255,255,1)"); g.addColorStop(1, "rgba(255,255,255,0)");
        c.fillStyle = g; c.fillRect(W / 2 - lineW / 2, H / 2 - 20, lineW, 40);
      }
      if (t > 0.45 && t < 0.8) { const r = 18 * (1 - (t - 0.45) / 0.35); c.fillStyle = "#fff"; c.beginPath(); c.arc(W / 2, H / 2, Math.max(0, r), 0, TAU); c.fill(); }
    },
    noFade: true,
  },
  shockwave: {
    update: (e, fx, dt) => {
      fx.s.next = (fx.s.next ?? 0) - dt;
      fx.s.rings = (fx.s.rings || []).filter((r) => (r.t += dt) < 1);
      if (fx.s.next <= 0 && fx.t < fx.dur) {
        fx.s.next = 0.85; fx.s.rings.push({ t: 0 }); fx.s.flash = 0.5; e.sound("boom");
        for (let i = 0; i < 40; i++) { const a = rand(0, TAU), v = rand(400, 1100); fx.parts.push(part({ kind: "spark", x: e.W / 2, y: e.H / 2, vx: Math.cos(a) * v, vy: Math.sin(a) * v, drag: 1.5, size: rand(2, 5), color: "#ffffff", max: 0.8 })); }
      }
      fx.s.flash = Math.max(0, (fx.s.flash || 0) - dt * 2.5);
    },
    draw: (e, c, fx) => {
      const diag = Math.hypot(e.W, e.H) / 2;
      for (const r of fx.s.rings || []) {
        const k = 1 - Math.pow(1 - r.t, 2), rad = k * diag, w = 70 * (1 - r.t);
        [["rgba(255,0,200,0.5)", -6], ["rgba(0,255,255,0.5)", 6], ["rgba(255,255,255,0.85)", 0]].forEach(([col, off]) => {
          c.globalAlpha = c.__fxAlpha * (1 - r.t); c.strokeStyle = col; c.lineWidth = Math.max(1, w * (off ? 0.5 : 0.35));
          c.beginPath(); c.arc(e.W / 2 + off, e.H / 2, rad, 0, TAU); c.stroke();
        });
      }
      if (fx.s.flash > 0) { c.globalAlpha = c.__fxAlpha * fx.s.flash * 0.6; c.fillStyle = "#fff"; c.fillRect(0, 0, e.W, e.H); }
    },
  },
  "glass-crack": {
    init: (e, fx) => {
      const make = (x, y) => {
        const lines = [];
        const rays = Math.floor(rand(12, 18));
        for (let i = 0; i < rays; i++) {
          let a = (i / rays) * TAU + rand(-0.15, 0.15), px = x, py = y; const pts = [[px, py]];
          const len = rand(0.35, 0.9) * Math.hypot(e.W, e.H) * 0.5;
          for (let d = 0; d < len; d += 90) { a += rand(-0.09, 0.09); const step = rand(60, 120); px += Math.cos(a) * step; py += Math.sin(a) * step; pts.push([px, py]); if (Math.random() < 0.25) { const b = a + rand(0.4, 0.8) * (Math.random() < 0.5 ? -1 : 1); lines.push([[px, py], [px + Math.cos(b) * rand(40, 110), py + Math.sin(b) * rand(40, 110)]]); } }
          lines.push(pts);
        }
        for (let ring = 1; ring <= 3; ring++) {
          const r = ring * rand(40, 70);
          for (let i = 0; i < rays; i++) if (Math.random() < 0.7) { const a1 = (i / rays) * TAU, a2 = ((i + 1) / rays) * TAU; lines.push([[x + Math.cos(a1) * r, y + Math.sin(a1) * r], [x + Math.cos((a1 + a2) / 2) * r * rand(0.85, 1.15), y + Math.sin((a1 + a2) / 2) * r * rand(0.85, 1.15)], [x + Math.cos(a2) * r, y + Math.sin(a2) * r]]); }
        }
        return { x, y, lines };
      };
      fx.s.cracks = [make(rand(0.35, 0.65) * e.W, rand(0.35, 0.6) * e.H)];
      fx.s.flash = 0.8; e.sound("glass");
    },
    update: (e, fx, dt) => {
      fx.s.flash = Math.max(0, fx.s.flash - dt * 3);
      if (!fx.s.second && fx.t > 1.3 && fx.dur > 2.5) {
        fx.s.second = true; e.sound("glass"); fx.s.flash = 0.5;
        const c0 = fx.s.cracks[0];
        fx.s.cracks.push({ ...HANDLERS["glass-crack"].mk(e, c0) });
      }
    },
    mk: (e) => { const tmp = { s: {} }; HANDLERS["glass-crack"].init({ ...e, sound: () => {} }, tmp); return tmp.s.cracks[0]; },
    draw: (e, c, fx) => {
      for (const crack of fx.s.cracks) {
        for (const [w, col] of [[4, "rgba(0,0,0,0.35)"], [1.6, "rgba(255,255,255,0.95)"]]) {
          c.globalAlpha = c.__fxAlpha; c.strokeStyle = col; c.lineWidth = w; c.lineJoin = "round";
          for (const line of crack.lines) { c.beginPath(); line.forEach(([x, y], i) => (i ? c.lineTo(x, y) : c.moveTo(x, y))); c.stroke(); }
        }
        const g = c.createRadialGradient(crack.x, crack.y, 0, crack.x, crack.y, 70);
        g.addColorStop(0, "rgba(255,255,255,0.8)"); g.addColorStop(1, "rgba(255,255,255,0)");
        c.fillStyle = g; c.beginPath(); c.arc(crack.x, crack.y, 70, 0, TAU); c.fill();
      }
      if (fx.s.flash > 0) { c.globalAlpha = c.__fxAlpha * fx.s.flash * 0.5; c.fillStyle = "#fff"; c.fillRect(0, 0, e.W, e.H); }
    },
  },
  spotlight: {
    init: (e, fx) => { fx.s.layer = document.createElement("canvas"); },
    draw: (e, c, fx) => {
      const L = fx.s.layer;
      if (L.width !== e.cw || L.height !== e.ch) { L.width = e.cw; L.height = e.ch; }
      const l = L.getContext("2d");
      l.setTransform(e.cw / e.W, 0, 0, e.ch / e.H, 0, 0);
      l.globalCompositeOperation = "source-over"; l.clearRect(0, 0, e.W, e.H);
      l.fillStyle = "rgba(0,0,0,0.88)"; l.fillRect(0, 0, e.W, e.H);
      const x = e.W / 2 + Math.sin(e.time * 0.7) * e.W * 0.32, y = e.H / 2 + Math.sin(e.time * 1.1 + 1) * e.H * 0.25, r = e.H * 0.24;
      l.globalCompositeOperation = "destination-out";
      const g = l.createRadialGradient(x, y, r * 0.6, x, y, r);
      g.addColorStop(0, "rgba(0,0,0,1)"); g.addColorStop(1, "rgba(0,0,0,0)");
      l.fillStyle = g; l.beginPath(); l.arc(x, y, r, 0, TAU); l.fill();
      c.save(); c.setTransform(1, 0, 0, 1, 0, 0); c.globalAlpha = c.__fxAlpha; c.drawImage(L, 0, 0); c.restore();
    },
  },
  dizzy: {
    draw: (e, c, fx) => {
      const cx = e.W / 2, cy = e.H * 0.28;
      const items = ["⭐", "🐤", "⭐", "💫", "🐤", "⭐"];
      items.forEach((em, i) => {
        const a = e.time * 3 + (i / items.length) * TAU, x = cx + Math.cos(a) * e.W * 0.16, y = cy + Math.sin(a) * e.H * 0.06;
        const img = emojiImg(em, 64 + Math.sin(a) * 16);
        c.globalAlpha = c.__fxAlpha; c.drawImage(img, x - img.width / 2, y - img.height / 2);
      });
      c.globalAlpha = c.__fxAlpha * 0.35; c.strokeStyle = "#fff"; c.lineWidth = 4;
      for (let i = 0; i < 3; i++) { c.beginPath(); c.ellipse(e.W / 2, e.H / 2, e.W * (0.2 + i * 0.12), e.H * (0.15 + i * 0.1), e.time * (i % 2 ? 1 : -1), 0.3, 2.4); c.stroke(); }
    },
  },
  hypno: {
    draw: (e, c) => {
      const cx = e.W / 2, cy = e.H / 2, max = Math.hypot(e.W, e.H) / 2;
      c.save(); c.translate(cx, cy); c.rotate(-e.time * 2.4);
      c.globalAlpha = c.__fxAlpha * 0.42; c.strokeStyle = "#000"; c.lineWidth = 34;
      for (const off of [0, Math.PI]) { c.beginPath(); for (let a = 0; a < 26; a += 0.08) { const r = (a / 26) * max * 1.1; c.lineTo(Math.cos(a + off) * r, Math.sin(a + off) * r); } c.stroke(); }
      c.strokeStyle = "#b46bff"; c.lineWidth = 8; c.globalAlpha = c.__fxAlpha * 0.5;
      c.beginPath(); for (let a = 0; a < 26; a += 0.08) { const r = (a / 26) * max * 1.1; c.lineTo(Math.cos(a + 1.57) * r, Math.sin(a + 1.57) * r); } c.stroke();
      c.restore();
    },
  },

  "chicken-run": {
    update: (e, fx, dt) => {
      emit(fx, "c", 5, dt, () => part({ kind: "emoji", emoji: pick(["🐓", "🐔", "🐥", "🐓", "🐤"]), x: e.W + 80, y: rand(0.62, 0.95) * e.H, vx: -rand(380, 760), size: rand(60, 120), bob: rand(14, 20), max: 8,
        onStep: (en, f, p) => { if (Math.random() < 0.15) f.parts.push(part({ kind: "dot", color: "rgba(220,200,170,0.5)", x: p.x + p.size * 0.3, y: p.y + p.size * 0.4, vx: rand(40, 120), vy: -rand(10, 40), size: rand(3, 8), max: 0.5, fade: 0.4 })); return true; } }));
      fx.s.cl = (fx.s.cl || 0) + dt; if (fx.s.cl > 0.35 && fx.t < fx.dur) { fx.s.cl = 0; e.sound("cluck"); }
    },
  },
  "egg-rain": {
    update: (e, fx, dt) => emit(fx, "e", 9, dt, () => part({ kind: "emoji", emoji: "🥚", x: rand(30, e.W - 30), y: -40, vy: rand(80, 200), g: 900, vr: rand(-3, 3), size: rand(42, 66), max: 8,
      onStep: (en, f, p) => { if (p.y > en.H - p.size * 0.4) { en.sound("splat"); f.parts.push(part({ kind: "emoji", emoji: "🍳", x: p.x, y: en.H - p.size * 0.35, size: p.size * 1.15, max: 1.8, fade: 0.5, pop: true })); return false; } return true; } })),
  },
  feathers: { update: (e, fx, dt) => emit(fx, "f", 26, dt, () => part({ kind: "feather", color: pick(["#fffaf0", "#f4e7d0", "#ffffff", "#e8d4b0"]), x: rand(-100, e.W), y: -30, vx: rand(30, 160), vy: rand(60, 140), sway: 140, swayF: rand(1, 2.5), vr: rand(-2.5, 2.5), size: rand(14, 26), max: 18 })) },
  popcorn: {
    update: (e, fx, dt) => {
      emit(fx, "p", 22, dt, () => part({ kind: "emoji", emoji: "🍿", x: rand(0, e.W), y: e.H + 30, vx: rand(-200, 200), vy: -rand(750, 1250) * e.sy, g: 1500 * e.sy, vr: rand(-6, 6), size: rand(40, 70), max: 4 }));
      fx.s.p = (fx.s.p || 0) + dt; if (fx.s.p > 0.09 && fx.t < fx.dur) { fx.s.p = 0; e.sound("pop"); }
    },
  },
  pizza: { update: (e, fx, dt) => emit(fx, "p", 11, dt, () => part({ kind: "emoji", emoji: "🍕", x: rand(0, e.W), y: -50, vy: rand(200, 420), vr: rand(-5, 5), size: rand(54, 92), max: 8 })) },
  laugh: { update: (e, fx, dt) => emit(fx, "l", 14, dt, () => part({ kind: "emoji", emoji: pick(["😂", "🤣", "😹", "😆"]), x: rand(0.05, 0.95) * e.W, y: rand(0.1, 0.95) * e.H, vy: -rand(20, 80), size: rand(60, 130), pop: true, vr: rand(-0.6, 0.6), max: 1.2, fade: 0.4 })) },
  horror: {
    init: (e, fx) => { fx.s.drips = Array.from({ length: 34 }, () => ({ x: rand(0, e.W), w: rand(6, 22), v: rand(25, 110), len: 0, delay: rand(0, 3) })); },
    draw: (e, c, fx) => {
      c.globalAlpha = c.__fxAlpha;
      for (const d of fx.s.drips) {
        if (fx.t < d.delay) continue;
        d.len = Math.min(e.H * 0.7, d.len + d.v * e.dt);
        c.fillStyle = "#6e000c";
        c.fillRect(d.x - d.w / 2, 0, d.w, d.len);
        c.beginPath(); c.arc(d.x, d.len, d.w * 0.75, 0, TAU); c.fill();
        c.fillStyle = "rgba(255,80,80,0.25)"; c.fillRect(d.x - d.w / 4, 0, d.w / 5, d.len);
      }
    },
  },
  sunglasses: {},

  gg: { init: (e, fx) => { textBurst(e, fx, ["🏆", "⭐", "🥇", "✨"], 50); } },
  rip: { update: (e, fx, dt) => emit(fx, "r", 6, dt, () => part({ kind: "emoji", emoji: pick(["🥀", "🕯️"]), x: rand(0, e.W), y: -40, vy: rand(60, 120), sway: 40, vr: rand(-1, 1), size: rand(40, 64), max: 10 })) },
  respect: { update: (e, fx, dt) => emit(fx, "r", 12, dt, () => part({ kind: "emoji", emoji: "🫡", x: rand(0, e.W), y: e.H + 40, vy: -rand(160, 300), size: rand(36, 60), max: 8 })) },
  clutch: {
    update: (e, fx, dt) => {
      fx.s.next = (fx.s.next ?? 0) - dt;
      if (fx.s.next <= 0 && fx.t < fx.dur - 0.5) { fx.s.next = rand(0.35, 0.8); fx.s.bolt = lightning(e, rand(0.1, 0.9) * e.W); fx.s.flash = 0.6; }
      fx.s.flash = Math.max(0, (fx.s.flash || 0) - dt * 3);
      if (fx.s.bolt) { fx.s.bolt.life += dt; if (fx.s.bolt.life > 0.25) fx.s.bolt = null; }
    },
    draw: (e, c, fx) => {
      if (fx.s.flash > 0) { c.globalAlpha = c.__fxAlpha * fx.s.flash * 0.4; c.fillStyle = "#9fd8ff"; c.fillRect(0, 0, e.W, e.H); }
      if (fx.s.bolt) drawBolt(c, fx.s.bolt, c.__fxAlpha);
    },
  },
  fail: { update: (e, fx, dt) => emit(fx, "f", 7, dt, () => part({ kind: "emoji", emoji: pick(["💀", "🤡", "🙈"]), x: rand(0, e.W), y: -50, vy: rand(150, 300), g: 300, vr: rand(-3, 3), size: rand(50, 80), max: 6 })) },
  wow: { init: (e, fx) => { for (let i = 0; i < 90; i++) { const a = rand(0, TAU), v = rand(200, 1000); fx.parts.push(part({ kind: "star", x: e.W / 2, y: e.H / 2, vx: Math.cos(a) * v, vy: Math.sin(a) * v, drag: 1.2, size: rand(10, 30), color: pick(["#fff6c4", "#ffffff", "#ffe27a", "#bfefff"]), max: rand(1.2, 2.4) })); } }, composite: "lighter" },
  countdown: {},
  ad: {},
};

export class StreamFx {
  constructor(canvas, sound = () => {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.active = [];
    this.sound = sound;
    this.time = 0;
    this.dt = 0;
    this.frame = this.frame.bind(this);
    this.resize = this.resize.bind(this);
    this.resize();
    window.addEventListener("resize", this.resize);
  }

  resize() {
    this.W = window.innerWidth || 1920; this.H = window.innerHeight || 1080;
    const dpr = Math.min(1.5, window.devicePixelRatio || 1);
    this.cw = Math.round(this.W * dpr); this.ch = Math.round(this.H * dpr);
    this.canvas.width = this.cw; this.canvas.height = this.ch;
    this.sx = this.W / 1920; this.sy = this.H / 1080;
  }

  add(id, dur, key = Math.random()) {
    const h = HANDLERS[id];
    if (!h) return;
    const fx = { id, key, t: 0, dur, parts: [], acc: {}, s: {} };
    h.init?.(this, fx);
    this.active.push(fx);
    if (!this.raf) { this.last = performance.now(); this.raf = requestAnimationFrame(this.frame); }
  }

  stop() { for (const fx of this.active) fx.dur = Math.min(fx.dur, fx.t); }

  frame(now) {
    const dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now; this.time += dt; this.dt = dt;
    const c = this.ctx;
    c.setTransform(this.cw / this.W, 0, 0, this.ch / this.H, 0, 0);
    c.clearRect(0, 0, this.W, this.H);
    this.active = this.active.filter((fx) => {
      fx.t += dt;
      const h = HANDLERS[fx.id];
      h.update?.(this, fx, dt);
      stepParts(this, fx, dt);
      const fadeOut = h.noFade ? 1 : fx.t > fx.dur ? Math.max(0, 1 - (fx.t - fx.dur) / 0.8) : 1;
      const fadeIn = h.noFade ? 1 : Math.min(1, fx.t / 0.35);
      c.__fxAlpha = fadeIn * fadeOut;
      c.save();
      if (h.composite) c.globalCompositeOperation = h.composite;
      h.draw?.(this, c, fx);
      // Particles already in the air keep flying after the effect ends.
      c.__fxAlpha = fadeIn * (fx.t > fx.dur + 0.8 ? Math.max(0, 1 - (fx.t - fx.dur - 0.8) / 2) : 1);
      for (const p of fx.parts) drawPart(c, p);
      c.restore();
      const drained = !fx.parts.length || fx.t > fx.dur + 3;
      return !(fx.t > fx.dur + 0.8 && drained);
    });
    c.globalAlpha = 1;
    this.raf = this.active.length ? requestAnimationFrame(this.frame) : 0;
    if (!this.raf) c.clearRect(0, 0, this.W, this.H);
  }

  dispose() { cancelAnimationFrame(this.raf); window.removeEventListener("resize", this.resize); }
}
