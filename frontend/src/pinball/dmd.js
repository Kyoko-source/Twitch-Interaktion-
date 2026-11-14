// 128x32 dot-matrix display, rendered like an orange plasma DMD.
const W = 128, H = 32;
const FONT = {
  A: [14, 17, 17, 31, 17, 17, 17], B: [30, 17, 17, 30, 17, 17, 30], C: [14, 17, 16, 16, 16, 17, 14], D: [28, 18, 17, 17, 17, 18, 28],
  E: [31, 16, 16, 30, 16, 16, 31], F: [31, 16, 16, 30, 16, 16, 16], G: [14, 17, 16, 23, 17, 17, 15], H: [17, 17, 17, 31, 17, 17, 17],
  I: [14, 4, 4, 4, 4, 4, 14], J: [7, 2, 2, 2, 2, 18, 12], K: [17, 18, 20, 24, 20, 18, 17], L: [16, 16, 16, 16, 16, 16, 31],
  M: [17, 27, 21, 21, 17, 17, 17], N: [17, 17, 25, 21, 19, 17, 17], O: [14, 17, 17, 17, 17, 17, 14], P: [30, 17, 17, 30, 16, 16, 16],
  Q: [14, 17, 17, 17, 21, 18, 13], R: [30, 17, 17, 30, 20, 18, 17], S: [15, 16, 16, 14, 1, 1, 30], T: [31, 4, 4, 4, 4, 4, 4],
  U: [17, 17, 17, 17, 17, 17, 14], V: [17, 17, 17, 17, 17, 10, 4], W: [17, 17, 17, 21, 21, 21, 10], X: [17, 17, 10, 4, 10, 17, 17],
  Y: [17, 17, 10, 4, 4, 4, 4], Z: [31, 1, 2, 4, 8, 16, 31],
  0: [14, 17, 19, 21, 25, 17, 14], 1: [4, 12, 4, 4, 4, 4, 14], 2: [14, 17, 1, 2, 4, 8, 31], 3: [31, 2, 4, 2, 1, 17, 14],
  4: [2, 6, 10, 18, 31, 2, 2], 5: [31, 16, 30, 1, 1, 17, 14], 6: [6, 8, 16, 30, 17, 17, 14], 7: [31, 1, 2, 4, 8, 8, 8],
  8: [14, 17, 17, 14, 17, 17, 14], 9: [14, 17, 17, 15, 1, 2, 12],
  " ": [0, 0, 0, 0, 0, 0, 0], "!": [4, 4, 4, 4, 4, 0, 4], "-": [0, 0, 0, 31, 0, 0, 0], ".": [0, 0, 0, 0, 0, 12, 12],
  ",": [0, 0, 0, 0, 12, 4, 8], ":": [0, 12, 12, 0, 12, 12, 0], "/": [1, 1, 2, 4, 8, 16, 16], "?": [14, 17, 1, 2, 4, 0, 4],
  "+": [0, 4, 4, 31, 4, 4, 0], "%": [24, 25, 2, 4, 8, 19, 3], "'": [4, 4, 8, 0, 0, 0, 0], "(": [2, 4, 8, 8, 8, 4, 2], ")": [8, 4, 2, 2, 2, 4, 8],
};
const norm = (s) => String(s).toUpperCase().replace(/Ä/g, "AE").replace(/Ö/g, "OE").replace(/Ü/g, "UE").replace(/ß/g, "SS");
const fmt = (n) => Math.round(n).toLocaleString("de-DE");

export class DMD {
  constructor(canvas) {
    this.canvas = canvas;
    this.buf = new Float32Array(W * H);
    this.img = document.createElement("canvas");
    this.img.width = W; this.img.height = H;
    this.ictx = this.img.getContext("2d");
    this.data = this.ictx.createImageData(W, H);
    this.sparks = [];
  }

  clear() { this.buf.fill(0); }
  px(x, y, v = 1) { x |= 0; y |= 0; if (x >= 0 && x < W && y >= 0 && y < H) this.buf[y * W + x] = Math.max(this.buf[y * W + x], v); }
  textWidth(s, sx = 1) { return norm(s).length * 6 * sx - sx; }
  text(s, x, y, { sx = 1, sy = 1, v = 1, center = false, right = false } = {}) {
    s = norm(s);
    if (center) x = Math.round((W - this.textWidth(s, sx)) / 2 + x);
    if (right) x = Math.round(W - this.textWidth(s, sx) - x);
    for (const ch of s) {
      const g = FONT[ch] || FONT[" "];
      for (let r = 0; r < 7; r++) for (let c = 0; c < 5; c++) if (g[r] & (16 >> c))
        for (let a = 0; a < sx; a++) for (let b = 0; b < sy; b++) this.px(x + c * sx + a, y + r * sy + b, v);
      x += 6 * sx;
    }
  }
  // Largest scale that fits the width.
  bigText(s, y, maxSy = 3, v = 1, offsetX = 0) {
    let sx = 2;
    if (this.textWidth(s, 2) > W - 2) sx = 1;
    const sy = sx === 2 ? Math.min(maxSy, 3) : 2;
    this.text(s, offsetX, y, { sx, sy, v, center: true });
    return 7 * sy;
  }
  frame(x0, y0, x1, y1, v = 0.5) { for (let x = x0; x <= x1; x++) { this.px(x, y0, v); this.px(x, y1, v); } for (let y = y0; y <= y1; y++) { this.px(x0, y, v); this.px(x1, y, v); } }

  render(state, msg, time) {
    this.clear();
    const t = time;
    if (msg) this.drawMessage(msg, t, state);
    else if (state.status === "attract" || state.status === "loading") this.drawAttract(t, state);
    else if (state.status === "gameover") this.drawGameOver(t, state);
    else this.drawScore(t, state);
    this.drawSparks();
    this.blit();
  }

  drawScore(t, s) {
    const score = fmt(s.score);
    const mission = s.mission;
    if (mission) {
      this.text(`${mission.name}`, 1, 0, { v: 0.75 });
      this.text(`${mission.progress}/${mission.goal} ${Math.ceil(mission.left)}S`, 1, 0, { v: 1, right: true });
      this.bigText(score, 9, 2, 1);
    } else if (s.multiball || s.wizard) {
      const flash = Math.floor(t * 4) % 2 ? 1 : 0.55;
      this.text(s.wizard ? "LAST CALL" : "MULTIBALL", 0, 0, { center: true, v: flash });
      this.bigText(score, 9, 2, 1);
    } else this.bigText(score, 3, 3, 1);
    const bottomY = 25;
    this.text(`BALL ${s.ball}`, 1, bottomY, { v: 0.7 });
    let right = s.bonusX > 1 ? `BONUS ${s.bonusX}X` : "";
    if (s.combo >= 2) right = `COMBO ${s.combo}X`;
    if (s.ballSave) right = Math.floor(t * 3) % 2 ? "BALL SAVE" : "";
    if (s.status === "ready") right = Math.floor(t * 2) % 2 ? "PLUNGER!" : "SKILL SHOT";
    if (right) this.text(right, 1, bottomY, { v: 0.7, right: true });
    if (s.tiltMeter > 1.6 && !s.tilt) this.frame(0, 0, W - 1, H - 1, Math.floor(t * 8) % 2 ? 1 : 0);
  }

  drawMessage(m, t, s) {
    const age = t - m.born, dur = m.ms / 1000, k = Math.min(1, age / 0.18);
    const hasSub = !!m.sub;
    let off = 0;
    if (m.style === "slide") off = Math.round((1 - k) * 128);
    if (m.style === "flash" && age < 0.5 && Math.floor(age * 16) % 2) { for (let i = 0; i < W * H; i++) this.buf[i] = 0.35; }
    if (m.style === "count") {
      this.text(m.title, 2, 4, { v: 0.9 });
      this.bigText(m.sub, 14, 2, 1);
      return;
    }
    if (m.style === "zoom" && k < 1) {
      // Expanding frame while the text pops in.
      const pad = Math.round((1 - k) * 14);
      this.frame(pad * 4, pad, W - 1 - pad * 4, H - 1 - pad, 0.8);
      return;
    }
    const titleY = hasSub ? 1 : 8;
    const hgt = this.bigText(m.title, titleY, hasSub ? 2 : 3, 1, off);
    if (hasSub) {
      const y = Math.min(25, titleY + hgt + 3), w = this.textWidth(m.sub);
      // Too long for the panel: scroll it through once per message.
      if (w > W - 2) this.text(m.sub, Math.round(W - ((age * 70) % (w + W))), y, { v: 0.8 });
      else this.text(m.sub, off, y, { center: true, v: 0.8 });
    }
    if (m.style === "flash" && age > 0.2 && Math.random() < 0.35) this.spawnSpark();
    if (age > dur - 0.12) for (let i = 0; i < W * H; i++) this.buf[i] *= 0.5;
  }

  drawAttract(t, s) {
    const scenes = [
      () => { this.text("PEPPLE", 0, 2, { sx: 3, sy: 2, center: true }); this.text("AFTER HOURS PINBALL", 0, 21, { center: true, v: 0.8 }); },
      () => { this.text("DRUECK", 0, 3, { sx: 2, sy: 1, center: true, v: 0.9 }); this.text("SPIEL STARTEN", 0, 14, { sx: 1, sy: 2, center: true }); },
      () => { this.text("MULTIBALL", 0, 2, { sx: 2, sy: 1, center: true }); this.text("3X VIP-SCOOP", 0, 13, { center: true, v: 0.8 }); this.text("= 3 KUGELN", 0, 22, { center: true, v: 0.8 }); },
      () => { this.text("5 MISSIONEN", 0, 2, { sx: 1, sy: 2, center: true }); this.text("= LAST CALL", 0, 20, { center: true, v: 0.9 }); },
      () => { if (s.best) { this.text("DEIN REKORD", 0, 2, { center: true, v: 0.8 }); this.bigText(fmt(s.best), 12, 2, 1); } else { this.text("ZIELE TREFFEN", 0, 4, { center: true }); this.text("COMBOS BAUEN", 0, 14, { center: true }); this.text("NICHT TILTEN!", 0, 24, { center: true, v: 0.7 }); } },
    ];
    const i = Math.floor(t / 3.2) % scenes.length;
    const local = (t % 3.2) / 3.2;
    scenes[i]();
    // Scanning light bar across the attract screens.
    const bar = Math.floor(local * (W + 40)) - 20;
    for (let x = bar; x < bar + 6; x++) for (let y = 0; y < H; y++) if (this.buf[y * W + x] > 0) this.buf[y * W + x] = 1;
    for (let i2 = 0; i2 < W * H; i2++) if (this.buf[i2] > 0 && this.buf[i2] < 1) this.buf[i2] *= 0.85;
  }

  drawGameOver(t, s) {
    if (Math.floor(t / 2.5) % 2 === 0) { this.text("GAME OVER", 0, 3, { sx: 2, sy: 2, center: true }); this.text(fmt(s.score), 0, 23, { center: true, v: 0.8 }); }
    else { this.text("DEIN SCORE", 0, 1, { center: true, v: 0.75 }); this.bigText(fmt(s.score), 11, 2, 1); }
  }

  spawnSpark() { this.sparks.push({ x: Math.random() * W, y: Math.random() * H, vx: (Math.random() - 0.5) * 3, vy: (Math.random() - 0.5) * 2, life: 12 }); }
  drawSparks() {
    this.sparks = this.sparks.filter((p) => p.life-- > 0);
    for (const p of this.sparks) { p.x += p.vx; p.y += p.vy; this.px(p.x, p.y, p.life / 12); }
  }

  blit() {
    const d = this.data.data;
    for (let i = 0; i < W * H; i++) {
      const v = this.buf[i];
      // Off dots stay faintly visible like real plasma.
      d[i * 4] = 40 + v * 215; d[i * 4 + 1] = 14 + v * 120; d[i * 4 + 2] = 4 + v * 20; d[i * 4 + 3] = 255;
    }
    this.ictx.putImageData(this.data, 0, 0);
    const c = this.canvas, ctx = c.getContext("2d");
    const cw = c.clientWidth || 512, ch = c.clientHeight || 128, dpr = Math.min(2, window.devicePixelRatio || 1);
    if (c.width !== Math.round(cw * dpr) || c.height !== Math.round(ch * dpr)) { c.width = Math.round(cw * dpr); c.height = Math.round(ch * dpr); this.mask = null; }
    const w = c.width, h = c.height;
    ctx.imageSmoothingEnabled = false;
    ctx.globalCompositeOperation = "source-over";
    ctx.fillStyle = "#0b0503";
    ctx.fillRect(0, 0, w, h);
    ctx.drawImage(this.img, 0, 0, w, h);
    if (!this.mask) this.mask = this.makeMask(w, h);
    ctx.drawImage(this.mask, 0, 0);
    // Soft plasma glow.
    ctx.globalCompositeOperation = "lighter";
    ctx.filter = `blur(${Math.max(2, w / 160)}px)`;
    ctx.globalAlpha = 0.55;
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(this.img, 0, 0, w, h);
    ctx.filter = "none";
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
  }

  makeMask(w, h) {
    const m = document.createElement("canvas");
    m.width = w; m.height = h;
    const ctx = m.getContext("2d");
    ctx.fillStyle = "#0b0503";
    ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = "destination-out";
    const cw = w / W, chh = h / H, r = Math.min(cw, chh) * 0.42;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { ctx.beginPath(); ctx.arc((x + 0.5) * cw, (y + 0.5) * chh, r, 0, Math.PI * 2); ctx.fill(); }
    return m;
  }
}
