// Stand-in art for the new Chicken Jump obstacles and scenery, drawn once into canvas textures.
// Painted art with the same texture key (listed in /assets/jump/art.json) replaces each of these.
const OUTLINE = "#3a2412";

function canvas(scene, key, w, h, draw) {
  if (scene.textures.exists(key)) return;
  const tex = scene.textures.createCanvas(key, w, h);
  const c = tex.getContext();
  c.lineJoin = "round"; c.lineCap = "round";
  draw(c, w, h);
  tex.refresh();
}

function gradient(c, x0, y0, x1, y1, stops) {
  const g = c.createLinearGradient(x0, y0, x1, y1);
  stops.forEach(([at, col]) => g.addColorStop(at, col));
  return g;
}

export function makePlaceholders(scene) {
  // Round hay bale, side view
  canvas(scene, "hay", 170, 150, (c) => {
    c.fillStyle = "rgba(30,18,6,0.35)"; c.beginPath(); c.ellipse(85, 140, 76, 9, 0, 0, Math.PI * 2); c.fill();
    c.fillStyle = gradient(c, 0, 10, 0, 140, [[0, "#f3d27a"], [0.55, "#d9a53e"], [1, "#9a6a1e"]]);
    c.strokeStyle = OUTLINE; c.lineWidth = 5;
    c.beginPath(); c.roundRect ? c.roundRect(12, 14, 146, 124, 50) : c.rect(12, 14, 146, 124); c.fill(); c.stroke();
    c.strokeStyle = "rgba(120,80,20,0.55)"; c.lineWidth = 2.5;
    for (let r = 12; r < 60; r += 9) { c.beginPath(); c.ellipse(85, 76, r * 1.15, r, 0, 0.3, Math.PI * 2 - 0.4); c.stroke(); }
    c.strokeStyle = "rgba(255,240,180,0.7)"; c.lineWidth = 2;
    for (let i = 0; i < 26; i++) { const x = 20 + Math.random() * 130, y = 18 + Math.random() * 110; c.beginPath(); c.moveTo(x, y); c.lineTo(x + 8 + Math.random() * 8, y - 3 + Math.random() * 6); c.stroke(); }
    c.strokeStyle = "#b8312a"; c.lineWidth = 6; c.beginPath(); c.moveTo(48, 16); c.lineTo(48, 136); c.moveTo(122, 16); c.lineTo(122, 136); c.stroke();
  });

  // Red tractor
  canvas(scene, "tractor", 380, 230, (c) => {
    c.fillStyle = "rgba(30,18,6,0.35)"; c.beginPath(); c.ellipse(190, 222, 170, 10, 0, 0, Math.PI * 2); c.fill();
    c.strokeStyle = OUTLINE; c.lineWidth = 5;
    // exhaust
    c.fillStyle = "#3a3a40"; c.fillRect(110, 18, 14, 70); c.strokeRect(110, 18, 14, 70);
    // body and hood
    c.fillStyle = gradient(c, 0, 80, 0, 180, [[0, "#ff5a48"], [1, "#b51e18"]]);
    c.beginPath(); c.moveTo(30, 170); c.lineTo(30, 110); c.lineTo(180, 100); c.lineTo(190, 160); c.lineTo(250, 160); c.lineTo(250, 70); c.lineTo(340, 70); c.lineTo(350, 170); c.closePath(); c.fill(); c.stroke();
    // cab window
    c.fillStyle = gradient(c, 0, 80, 0, 150, [[0, "#cfefff"], [1, "#7fb8d8"]]);
    c.beginPath(); c.moveTo(262, 82); c.lineTo(330, 82); c.lineTo(334, 140); c.lineTo(262, 140); c.closePath(); c.fill(); c.stroke();
    c.fillStyle = "rgba(255,255,255,0.6)"; c.fillRect(270, 88, 10, 40);
    // grill
    c.fillStyle = "#3a2a20"; for (let i = 0; i < 4; i++) c.fillRect(36, 118 + i * 11, 26, 6);
    // headlight
    c.fillStyle = "#fff3a0"; c.beginPath(); c.arc(70, 106, 9, 0, Math.PI * 2); c.fill(); c.stroke();
    const wheel = (x, y, r) => {
      c.fillStyle = "#1e1c1e"; c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill(); c.stroke();
      c.strokeStyle = "#3e3a3e"; c.lineWidth = 5;
      for (let a = 0; a < Math.PI * 2; a += Math.PI / 7) { c.beginPath(); c.moveTo(x + Math.cos(a) * r * 0.82, y + Math.sin(a) * r * 0.82); c.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r); c.stroke(); }
      c.strokeStyle = OUTLINE; c.lineWidth = 5;
      c.fillStyle = "#f2c230"; c.beginPath(); c.arc(x, y, r * 0.5, 0, Math.PI * 2); c.fill(); c.stroke();
      c.fillStyle = "#8a6a10"; c.beginPath(); c.arc(x, y, r * 0.16, 0, Math.PI * 2); c.fill();
    };
    wheel(290, 160, 62);
    wheel(80, 180, 38);
  });

  // Running fox, two frames side by side (legs apart / together)
  canvas(scene, "fox", 400, 130, (c) => {
    for (let f = 0; f < 2; f++) {
      const ox = f * 200;
      c.save(); c.translate(ox, 0);
      c.fillStyle = "rgba(30,18,6,0.3)"; c.beginPath(); c.ellipse(100, 122, 70, 7, 0, 0, Math.PI * 2); c.fill();
      c.strokeStyle = OUTLINE; c.lineWidth = 4;
      // tail (fox runs left, tail to the right)
      c.fillStyle = gradient(c, 120, 0, 195, 0, [[0, "#e8721e"], [0.75, "#f0904a"], [0.76, "#fff6ea"], [1, "#fff6ea"]]);
      c.beginPath(); c.moveTo(130, 66); c.quadraticCurveTo(170, f ? 40 : 52, 196, f ? 46 : 60); c.quadraticCurveTo(178, 86, 132, 82); c.closePath(); c.fill(); c.stroke();
      // legs
      c.strokeStyle = "#5a2a10"; c.lineWidth = 8;
      const legs = f ? [[60, 40], [80, 96], [120, 108], [140, 150]] : [[66, 80], [82, 72], [118, 128], [132, 122]];
      legs.forEach(([x, tx]) => { c.beginPath(); c.moveTo(x, 84); c.lineTo(tx * 0.5 + x * 0.5 - 6, 112); c.stroke(); });
      c.strokeStyle = OUTLINE; c.lineWidth = 4;
      // body
      c.fillStyle = gradient(c, 0, 50, 0, 100, [[0, "#f08a34"], [1, "#c95412"]]);
      c.beginPath(); c.ellipse(98, 72, 48, 22, -0.05, 0, Math.PI * 2); c.fill(); c.stroke();
      c.fillStyle = "#fff6ea"; c.beginPath(); c.ellipse(80, 84, 22, 9, 0, 0, Math.PI * 2); c.fill();
      // head
      c.fillStyle = "#ef8030";
      c.beginPath(); c.moveTo(60, 52); c.lineTo(18, 70); c.lineTo(58, 82); c.closePath(); c.fill(); c.stroke();
      c.beginPath(); c.arc(60, 64, 18, 0, Math.PI * 2); c.fill(); c.stroke();
      c.beginPath(); c.moveTo(56, 48); c.lineTo(60, 28); c.lineTo(70, 48); c.closePath(); c.fill(); c.stroke();
      c.beginPath(); c.moveTo(68, 50); c.lineTo(78, 32); c.lineTo(80, 52); c.closePath(); c.fill(); c.stroke();
      c.fillStyle = "#fff6ea"; c.beginPath(); c.moveTo(44, 70); c.lineTo(20, 70); c.lineTo(52, 80); c.closePath(); c.fill();
      c.fillStyle = "#1a1210"; c.beginPath(); c.arc(19, 70, 4, 0, Math.PI * 2); c.fill();
      c.beginPath(); c.ellipse(52, 60, 3.5, 4.5, 0, 0, Math.PI * 2); c.fill();
      c.fillStyle = "#fff"; c.beginPath(); c.arc(51, 58.5, 1.4, 0, Math.PI * 2); c.fill();
      c.restore();
    }
  });

  // Low branch reaching down from the top of the screen
  canvas(scene, "branch", 300, 820, (c) => {
    c.strokeStyle = OUTLINE; c.lineWidth = 6;
    c.fillStyle = gradient(c, 0, 0, 300, 0, [[0, "#5a3a1e"], [1, "#7a5230"]]);
    c.beginPath(); c.moveTo(250, 0); c.quadraticCurveTo(170, 300, 150, 640); c.lineTo(178, 640); c.quadraticCurveTo(210, 320, 300, 0); c.closePath(); c.fill(); c.stroke();
    c.lineWidth = 4;
    c.beginPath(); c.moveTo(170, 420); c.quadraticCurveTo(110, 470, 80, 560); c.stroke();
    c.beginPath(); c.moveTo(165, 520); c.quadraticCurveTo(230, 580, 240, 650); c.stroke();
    const leaf = (x, y, r, col) => { c.fillStyle = col; c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill(); };
    const cluster = (cx, cy, s) => {
      for (let i = 0; i < 16; i++) { const a = Math.random() * Math.PI * 2, d = Math.random() * s; leaf(cx + Math.cos(a) * d, cy + Math.sin(a) * d * 0.7, s * (0.32 + Math.random() * 0.2), i % 3 ? "#2f7a2e" : "#3f9a3a"); }
      for (let i = 0; i < 8; i++) { const a = Math.random() * Math.PI * 2, d = Math.random() * s * 0.7; leaf(cx + Math.cos(a) * d, cy + Math.sin(a) * d * 0.6 - s * 0.2, s * 0.22, "#6cc24a"); }
    };
    c.strokeStyle = OUTLINE; c.lineWidth = 4;
    cluster(80, 600, 70); cluster(160, 700, 90); cluster(240, 680, 70); cluster(150, 470, 60);
    c.fillStyle = "#c0202a"; for (let i = 0; i < 5; i++) leaf(110 + Math.random() * 110, 680 + Math.random() * 60, 8, "#d8323a");
  });

  // Mud puddle on the path
  canvas(scene, "mud", 300, 70, (c) => {
    c.fillStyle = gradient(c, 0, 10, 0, 64, [[0, "#6a4424"], [1, "#3e2410"]]);
    c.beginPath(); c.ellipse(150, 38, 144, 26, 0, 0, Math.PI * 2); c.fill();
    c.fillStyle = "rgba(255,230,190,0.35)"; c.beginPath(); c.ellipse(120, 30, 70, 7, -0.05, 0, Math.PI * 2); c.fill();
    c.fillStyle = "#4a2c14"; for (let i = 0; i < 6; i++) { c.beginPath(); c.arc(20 + i * 52, 18 + (i % 2) * 40, 8, 0, Math.PI * 2); c.fill(); }
    c.strokeStyle = "rgba(255,240,210,0.5)"; c.lineWidth = 2; c.beginPath(); c.ellipse(200, 40, 18, 5, 0, 0, Math.PI * 2); c.stroke();
  });

  // Soft cloud (replaces the flat grey blobs)
  canvas(scene, "cloud-soft", 320, 140, (c) => {
    const puff = (x, y, r, a) => { const g = c.createRadialGradient(x, y - r * 0.3, r * 0.1, x, y, r); g.addColorStop(0, `rgba(255,236,236,${a})`); g.addColorStop(0.7, `rgba(255,214,222,${a * 0.6})`); g.addColorStop(1, "rgba(255,210,220,0)"); c.fillStyle = g; c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill(); };
    puff(90, 86, 60, 0.75); puff(160, 70, 70, 0.8); puff(230, 88, 58, 0.7); puff(160, 100, 80, 0.45);
  });

  // Foreground grass clump with flowers
  canvas(scene, "grass-tuft", 120, 70, (c) => {
    for (let i = 0; i < 22; i++) {
      const x = 10 + Math.random() * 100, h = 26 + Math.random() * 40, lean = (Math.random() - 0.5) * 22;
      c.strokeStyle = i % 3 ? "#2f6e2a" : "#4f9a3a"; c.lineWidth = 3 + Math.random() * 2;
      c.beginPath(); c.moveTo(x, 70); c.quadraticCurveTo(x + lean * 0.3, 70 - h * 0.6, x + lean, 70 - h); c.stroke();
    }
    [["#ffe066", 34, 26], ["#ffffff", 74, 20], ["#ff8ab0", 92, 30]].forEach(([col, x, y]) => { c.fillStyle = col; c.beginPath(); c.arc(x, y, 4.5, 0, Math.PI * 2); c.fill(); c.fillStyle = "#c98a00"; c.beginPath(); c.arc(x, y, 1.6, 0, Math.PI * 2); c.fill(); });
  });

  // Rain drop and warning sign
  canvas(scene, "raindrop", 4, 26, (c) => { c.fillStyle = gradient(c, 0, 0, 0, 26, [[0, "rgba(200,220,255,0)"], [1, "rgba(220,235,255,0.85)"]]); c.fillRect(0, 0, 3, 26); });
  canvas(scene, "warn", 120, 108, (c) => {
    c.fillStyle = "#ffcf2e"; c.strokeStyle = "#2a1a08"; c.lineWidth = 7;
    c.beginPath(); c.moveTo(60, 8); c.lineTo(114, 100); c.lineTo(6, 100); c.closePath(); c.fill(); c.stroke();
    c.fillStyle = "#2a1a08"; c.fillRect(54, 36, 12, 36); c.beginPath(); c.arc(60, 86, 7, 0, Math.PI * 2); c.fill();
  });
}
