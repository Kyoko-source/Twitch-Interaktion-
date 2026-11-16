import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Gift, Music, Snowflake, TreePine, VolumeX } from "lucide-react";
import { musicPrefs, onMusicPrefs, setMusicMuted, setMusicVolume, setMusicWanted } from "./music.js";
import "./christmas.css";
import "./christmas-theme.css";

// Pages with their own sound pause the Christmas song.
const QUIET_PAGES = new Set(["games", "nullsignal"]);
const reducedMotion = () => typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
const NEEDLES = ["#0b2e1b", "#0f3d24", "#155c32", "#1d6b3a", "#2a7d45", "#3a8f52"];
const BULBS = ["#ff4040", "#ffd23f", "#45ff8f", "#45b8ff", "#ff6ad5", "#ff9a3d"];

function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

// Draws a bushy fir branch along a path of points (needles fanning out on both sides).
function drawFir(c, points, rand, thickness = 1) {
  c.lineCap = "round";
  for (let pass = 0; pass < 2; pass++) {
    for (let i = 0; i < points.length; i++) {
      const [x, y, angle] = points[i];
      for (let k = 0; k < 7; k++) {
        const side = k % 2 ? 1 : -1;
        const a = angle + side * (0.6 + rand() * 1.2) + (rand() - 0.5) * 0.5;
        const len = (pass ? 8 : 12 + rand() * 8) * thickness;
        c.strokeStyle = NEEDLES[pass ? 3 + Math.floor(rand() * 3) : Math.floor(rand() * 4)];
        c.lineWidth = pass ? 1.2 : 1.8;
        c.beginPath();
        c.moveTo(x, y);
        c.lineTo(x + Math.cos(a) * len, y + Math.sin(a) * len + (pass ? 0 : 2));
        c.stroke();
      }
    }
  }
}

const sag = (t) => Math.sin(Math.PI * t);

// ----------------------------------------------------------------------------- garland
// Fir garland under the topbar: swags of branches, a light chain woven through and baubles at the joints.
export function Garland({ intro }) {
  const wrap = useRef(null);
  const canvas = useRef(null);
  const [layout, setLayout] = useState({ width: 0, lights: [], baubles: [] });

  useLayoutEffect(() => {
    const el = wrap.current;
    if (!el) return undefined;
    const draw = () => {
      const width = Math.round(el.clientWidth);
      if (!width) return;
      const h = 64, dpr = Math.min(2, window.devicePixelRatio || 1);
      const cv = canvas.current;
      cv.width = width * dpr; cv.height = h * dpr;
      cv.style.width = `${width}px`; cv.style.height = `${h}px`;
      const c = cv.getContext("2d");
      c.setTransform(dpr, 0, 0, dpr, 0, 0);
      c.clearRect(0, 0, width, h);
      const count = Math.max(2, Math.round(width / 210));
      const seg = width / count;
      const rand = rng(7);
      const lights = [], baubles = [];
      for (let s = 0; s < count; s++) {
        const x0 = s * seg, pts = [];
        for (let x = 0; x <= seg; x += 3) {
          const t = x / seg;
          const y = 6 + 22 * sag(t);
          const slope = (22 * Math.PI * Math.cos(Math.PI * t)) / seg;
          pts.push([x0 + x, y, Math.atan2(slope, 1)]);
        }
        drawFir(c, pts, rand);
        // red berries and a pine cone in the middle of each swag
        const mid = x0 + seg / 2, my = 6 + 22;
        c.fillStyle = "#5a3418"; c.beginPath(); c.ellipse(mid + 8, my + 4, 4, 7, 0.3, 0, Math.PI * 2); c.fill();
        for (const [dx, dy] of [[-6, 2], [-2, 6], [-9, 7]]) {
          c.fillStyle = "#d11a2a"; c.beginPath(); c.arc(mid + dx, my + dy, 2.6, 0, Math.PI * 2); c.fill();
          c.fillStyle = "#ff8a8a"; c.beginPath(); c.arc(mid + dx - 0.8, my + dy - 0.8, 0.9, 0, Math.PI * 2); c.fill();
        }
        // the light wire, slightly lower than the branch
        c.strokeStyle = "#1a1a12"; c.lineWidth = 1.2; c.beginPath();
        for (let x = 0; x <= seg; x += 4) {
          const t = x / seg, y = 12 + 24 * sag(t) + Math.sin(t * Math.PI * 6) * 2;
          if (x === 0) c.moveTo(x0 + x, y); else c.lineTo(x0 + x, y);
        }
        c.stroke();
        const n = Math.max(4, Math.round(seg / 34));
        for (let i = 0; i < n; i++) {
          const t = (i + 0.5) / n;
          lights.push({ x: x0 + t * seg, y: 12 + 24 * sag(t) + Math.sin(t * Math.PI * 6) * 2, color: BULBS[lights.length % BULBS.length] });
        }
        if (s > 0) baubles.push({ x: x0, len: 12 + (s % 3) * 8, color: BULBS[(s * 2) % BULBS.length] });
      }
      setLayout({ width, lights, baubles });
    };
    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  return (
    <div className={`xmGarland${intro ? " xmIntro" : ""}`} ref={wrap} aria-hidden="true">
      <div className="xmGarlandFir"><canvas ref={canvas} /></div>
      {layout.baubles.map((b, i) => (
        <span key={`b${i}`} className="xmBauble" style={{ left: b.x, "--len": `${b.len}px`, "--c": b.color, "--d": `${(i % 4) * 0.4}s` }}><i /></span>
      ))}
      {layout.lights.map((l, i) => (
        <span key={i} className="xmBulb" style={{ left: l.x, top: l.y, "--c": l.color, "--i": i, "--tw": `${1.4 + (i % 5) * 0.37}s` }} />
      ))}
    </div>
  );
}

// Small fir sprig with berries in the corner of the menu, behind the logo.
export function RailSprig() {
  const ref = useRef(null);
  useEffect(() => {
    const cv = ref.current;
    const w = 150, h = 80, dpr = Math.min(2, window.devicePixelRatio || 1);
    cv.width = w * dpr; cv.height = h * dpr;
    const c = cv.getContext("2d");
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    const rand = rng(3);
    for (const [x1, y1, x2, y2] of [[150, 4, 40, 30], [150, 18, 70, 66], [150, 2, 96, 6]]) {
      const pts = [];
      for (let t = 0; t <= 1; t += 0.04) pts.push([x1 + (x2 - x1) * t, y1 + (y2 - y1) * t + Math.sin(t * Math.PI) * 6, Math.atan2(y2 - y1, x2 - x1)]);
      drawFir(c, pts, rand, 0.9);
    }
    for (const [x, y] of [[112, 22], [118, 28], [107, 29]]) {
      c.fillStyle = "#d11a2a"; c.beginPath(); c.arc(x, y, 3.2, 0, Math.PI * 2); c.fill();
      c.fillStyle = "#ff9a9a"; c.beginPath(); c.arc(x - 1, y - 1, 1.1, 0, Math.PI * 2); c.fill();
    }
  }, []);
  return <canvas ref={ref} className="xmSprig" style={{ width: 150, height: 80 }} aria-hidden="true" />;
}

export function SantaHat() {
  return (
    <svg className="xmHat" viewBox="0 0 64 52" aria-hidden="true">
      <path d="M6 40 C 14 14, 34 2, 52 10 C 58 13, 60 22, 57 30 L 50 26 C 46 18, 36 16, 30 22 C 24 28, 22 34, 22 40 Z" fill="#d6202f" />
      <path d="M30 22 C 36 16, 46 18, 50 26" fill="none" stroke="#a3111d" strokeWidth="3" opacity=".6" />
      <rect x="2" y="36" width="34" height="12" rx="6" fill="#fbf7f2" />
      <circle cx="56" cy="32" r="7" fill="#fbf7f2" />
    </svg>
  );
}

// ----------------------------------------------------------------------------- fireplace
function Stocking({ color, cuff, x, delay }) {
  return (
    <svg className="xmStocking" viewBox="0 0 30 46" style={{ left: x, animationDelay: delay }} aria-hidden="true">
      <path d="M6 6 H22 V28 C22 34, 20 38, 14 40 L8 42 C3 43, 1 38, 4 35 L8 32 C7 28, 6 26, 6 22 Z" fill={color} />
      <path d="M8 18 H20 M8 24 H20" stroke="#fff" strokeOpacity=".25" strokeWidth="2" />
      <rect x="4" y="2" width="20" height="8" rx="3" fill={cuff} />
    </svg>
  );
}

// A burning fireplace with logs, flames, stockings on the mantel and a flickering glow.
export function Fireplace({ intro }) {
  const ref = useRef(null);
  const introAtStart = useRef(intro);
  useEffect(() => {
    const intro = introAtStart.current;
    const cv = ref.current;
    if (!cv) return undefined;
    const w = 150, h = 70, dpr = Math.min(2, window.devicePixelRatio || 1);
    cv.width = w * dpr; cv.height = h * dpr;
    const c = cv.getContext("2d");
    const calm = reducedMotion();
    const born = performance.now();
    const parts = [];
    let raf = 0, last = born;
    const root = document.documentElement;
    const frame = (now) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      // Fire grows from embers during the intro (starts after ~2.6 s, full after ~5 s).
      const power = intro ? Math.max(0, Math.min(1, (now - born - 2600) / 2400)) : 1;
      c.setTransform(dpr, 0, 0, dpr, 0, 0);
      c.clearRect(0, 0, w, h);
      // embers glow
      const g = c.createRadialGradient(w / 2, h - 8, 4, w / 2, h - 8, 70);
      g.addColorStop(0, `rgba(255,150,40,${0.25 + 0.5 * power})`); g.addColorStop(1, "rgba(255,80,0,0)");
      c.fillStyle = g; c.fillRect(0, 0, w, h);
      // flames
      if (!calm) {
        const spawn = 90 * power * dt * 4;
        for (let i = 0; i < spawn; i++) parts.push({ x: w / 2 + (Math.random() - 0.5) * 70 * (0.5 + power / 2), y: h - 14, vx: (Math.random() - 0.5) * 14, vy: -(28 + Math.random() * 40), r: 7 + Math.random() * 9, life: 0, max: 0.55 + Math.random() * 0.5 });
      }
      c.globalCompositeOperation = "lighter";
      for (let i = parts.length - 1; i >= 0; i--) {
        const p = parts[i];
        p.life += dt;
        if (p.life >= p.max) { parts.splice(i, 1); continue; }
        const k = p.life / p.max;
        p.x += (p.vx + Math.sin((now / 140) + i) * 8) * dt; p.y += p.vy * dt;
        p.vx += (w / 2 - p.x) * dt * 1.4;
        const r = p.r * (1 - k * 0.7);
        const col = k < 0.25 ? [255, 240, 170] : k < 0.55 ? [255, 160, 40] : [230, 60, 20];
        const grad = c.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
        grad.addColorStop(0, `rgba(${col[0]},${col[1]},${col[2]},${0.55 * (1 - k)})`);
        grad.addColorStop(1, `rgba(${col[0]},${col[1]},${col[2]},0)`);
        c.fillStyle = grad; c.beginPath(); c.arc(p.x, p.y, r, 0, Math.PI * 2); c.fill();
      }
      c.globalCompositeOperation = "source-over";
      if (calm && power > 0) { // a still flame for reduced motion
        const grad = c.createRadialGradient(w / 2, h - 30, 2, w / 2, h - 30, 30);
        grad.addColorStop(0, "rgba(255,230,150,.9)"); grad.addColorStop(0.5, "rgba(255,140,30,.6)"); grad.addColorStop(1, "rgba(220,50,10,0)");
        c.fillStyle = grad; c.beginPath(); c.ellipse(w / 2, h - 30, 26, 30, 0, 0, Math.PI * 2); c.fill();
      }
      // logs
      c.fillStyle = "#4a2a14";
      c.save(); c.translate(w / 2, h - 9); c.rotate(-0.12); c.fillRect(-46, -6, 92, 12); c.restore();
      c.save(); c.translate(w / 2, h - 7); c.rotate(0.16); c.fillRect(-42, -5, 84, 10); c.restore();
      c.fillStyle = "#7a4a26"; c.beginPath(); c.ellipse(w / 2 + 45, h - 14, 5, 6, 0, 0, Math.PI * 2); c.fill();
      c.fillStyle = `rgba(255,${120 + Math.random() * 60},40,${0.5 + power * 0.5})`;
      for (let i = 0; i < 6; i++) c.fillRect(w / 2 - 36 + i * 13, h - 6 - Math.random() * 3, 5, 2);
      // the whole page flickers warm with the fire
      const flicker = power * (0.75 + Math.sin(now / 90) * 0.08 + Math.random() * 0.17);
      root.style.setProperty("--xm-fire", flicker.toFixed(3));
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(raf); root.style.removeProperty("--xm-fire"); };
  }, []);

  return (
    <div className={`xmFireplace${intro ? " xmIntro" : ""}`} aria-hidden="true">
      <div className="xmMantel" />
      <Stocking color="#c81d2a" cuff="#fbf7f2" x={24} delay="0s" />
      <Stocking color="#1f7a3e" cuff="#fbf7f2" x={74} delay="-1.2s" />
      <Stocking color="#c81d2a" cuff="#ffd23f" x={124} delay="-2.1s" />
      <div className="xmHearth"><div className="xmFirebox"><canvas ref={ref} style={{ width: 150, height: 70 }} /></div></div>
    </div>
  );
}

// ----------------------------------------------------------------------------- snow
// Snow over the whole page. Flakes that hit the top edge of a tile stay there and pile up.
const SURFACES = ".panel, .card, .dashboardPanel, .pfCard, .pfTile, .pfHero, .memberCard, .memberSpotlight, .leaderRow, .podiumCard, .stat, .cChat, .communityHero, .neonHero, .dailyRewardLink, .xmMantel, .rowCard, .miniCard, .viewerCard, .gameLaunch, .shopCard, .levelPanel";
const BIN = 4;

function Snow({ intro }) {
  const ref = useRef(null);
  const introAtStart = useRef(intro);
  useEffect(() => {
    const intro = introAtStart.current;
    if (reducedMotion()) return undefined;
    const cv = ref.current;
    const c = cv.getContext("2d");
    const dpr = Math.min(1.5, window.devicePixelRatio || 1);
    let w = 0, h = 0;
    const resize = () => { w = window.innerWidth; h = window.innerHeight; cv.width = w * dpr; cv.height = h * dpr; };
    resize();
    window.addEventListener("resize", resize);
    const piles = new WeakMap();
    let surfaces = [];
    const born = performance.now();
    const collect = () => {
      const list = [];
      const menu = document.querySelector(".communityRail.isOpen"); // phone menu open: only its own tiles get snow
      for (const el of document.querySelectorAll(SURFACES)) {
        if (menu && !menu.contains(el)) continue;
        const r = el.getBoundingClientRect();
        if (r.width < 90 || r.height < 26 || r.bottom < 0 || r.top > h) continue;
        if (el.closest(".xmPrompt") || getComputedStyle(el).visibility === "hidden") continue;
        if (!piles.has(el)) {
          const bins = new Float32Array(Math.ceil(r.width / BIN) + 1);
          if (!intro) for (let i = 0; i < bins.length; i++) bins[i] = 2 + Math.random() * 3; // the page already looks snowy
          piles.set(el, { bins, max: 7 + Math.random() * 5 });
        }
        list.push(el);
        if (list.length > 60) break;
      }
      // Only the top-most surfaces get snow (no piles inside other piled tiles' shadows).
      surfaces = list;
    };
    collect();
    const scan = window.setInterval(collect, 700);
    const mobile = w < 760;
    const target = mobile ? 55 : 120;
    const flakes = [];
    const spawn = (anywhere) => flakes.push({ x: Math.random() * w, y: anywhere ? Math.random() * h : -10, r: 0.8 + Math.random() * 2.4, vy: 22 + Math.random() * 38, sway: Math.random() * Math.PI * 2, swaySpeed: 0.6 + Math.random() * 1.2, a: 0.5 + Math.random() * 0.5 });
    if (!intro) for (let i = 0; i < target; i++) spawn(true);
    let raf = 0, last = performance.now();
    const frame = (now) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      if (document.hidden) { raf = requestAnimationFrame(frame); return; }
      const ramp = intro ? Math.max(0, Math.min(1, (now - born - 3800) / 5000)) : 1;
      while (flakes.length < target * ramp) spawn(false);
      c.setTransform(dpr, 0, 0, dpr, 0, 0);
      c.clearRect(0, 0, w, h);
      const rects = surfaces.map((el) => [el, el.getBoundingClientRect()]);
      // piles
      c.fillStyle = "#f4f8ff";
      c.shadowColor = "rgba(150,180,255,.45)"; c.shadowBlur = 4; c.shadowOffsetY = 1;
      for (const [el, r] of rects) {
        if (r.bottom < 0 || r.top > h + 20) continue;
        const pile = piles.get(el);
        if (!pile) continue;
        const { bins } = pile;
        c.beginPath();
        c.moveTo(r.left + 3, r.top + 1);
        let any = false;
        for (let i = 0; i < bins.length; i++) {
          const x = Math.min(r.right - 3, r.left + 3 + i * BIN);
          if (bins[i] > 0.4) any = true;
          c.lineTo(x, r.top + 1 - bins[i]);
        }
        c.lineTo(r.right - 3, r.top + 1);
        c.closePath();
        if (any) c.fill();
      }
      c.shadowBlur = 0; c.shadowOffsetY = 0;
      // flakes
      for (let i = flakes.length - 1; i >= 0; i--) {
        const f = flakes[i];
        const prevY = f.y;
        f.sway += f.swaySpeed * dt;
        f.x += Math.sin(f.sway) * 18 * dt;
        f.y += f.vy * dt;
        let landed = false;
        for (const [el, r] of rects) {
          if (f.x < r.left + 4 || f.x > r.right - 4) continue;
          const pile = piles.get(el);
          const bi = Math.round((f.x - r.left - 3) / BIN);
          const top = r.top + 1 - (pile.bins[bi] || 0);
          if (prevY <= top && f.y >= top) {
            for (let k = -2; k <= 2; k++) {
              const j = bi + k;
              if (j >= 0 && j < pile.bins.length) pile.bins[j] = Math.min(pile.max, pile.bins[j] + f.r * 0.35 * (1 - Math.abs(k) / 3));
            }
            landed = true;
            break;
          }
        }
        if (landed || f.y > h + 10) { flakes.splice(i, 1); continue; }
        c.globalAlpha = f.a;
        c.fillStyle = "#fff";
        c.beginPath(); c.arc(f.x, f.y, f.r, 0, Math.PI * 2); c.fill();
      }
      c.globalAlpha = 1;
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(raf); window.clearInterval(scan); window.removeEventListener("resize", resize); };
  }, []);
  return <canvas ref={ref} className="xmSnow" aria-hidden="true" />;
}

// ----------------------------------------------------------------------------- layer, prompt, settings
// Page-wide pieces: snow, warm fire glow and the song.
export function ChristmasLayer({ intro, page, leaving }) {
  const [prefs, setPrefs] = useState(musicPrefs);
  useEffect(() => onMusicPrefs(setPrefs), []);
  useEffect(() => {
    const quiet = QUIET_PAGES.has(page) || leaving;
    setMusicWanted(!quiet, intro ? 4000 : 2000);
  }, [page, leaving, intro, prefs.muted]);
  useEffect(() => () => setMusicWanted(false), []);
  // Layout effect: the colours switch in the same frame (needed for the circle transition).
  useLayoutEffect(() => {
    document.documentElement.classList.add("xmasOn");
    return () => document.documentElement.classList.remove("xmasOn");
  }, []);
  useEffect(() => {
    document.documentElement.classList.toggle("xmasLeaving", Boolean(leaving));
    return () => document.documentElement.classList.remove("xmasLeaving");
  }, [leaving]);
  return (
    <div className={`xmLayer${intro ? " xmIntro" : ""}${leaving ? " xmLeaving" : ""}`} aria-hidden="true">
      <div className="xmGlow" />
      <div className="xmVignette" />
      {!QUIET_PAGES.has(page) && <Snow intro={intro} />}
    </div>
  );
}

export function MusicButton({ page }) {
  const [prefs, setPrefs] = useState(musicPrefs);
  useEffect(() => onMusicPrefs(setPrefs), []);
  const quiet = QUIET_PAGES.has(page);
  return (
    <button type="button" className={`quietIcon xmMusicBtn${prefs.muted ? " muted" : ""}`} onClick={() => setMusicMuted(!prefs.muted, !quiet)}
      title={prefs.muted ? "Weihnachtsmusik an" : quiet ? "Weihnachtsmusik pausiert hier (Spiel mit eigenem Sound)" : "Weihnachtsmusik aus"} aria-label={prefs.muted ? "Weihnachtsmusik einschalten" : "Weihnachtsmusik ausschalten"} aria-pressed={!prefs.muted}>
      {prefs.muted ? <VolumeX size={17} /> : <Music size={17} />}
    </button>
  );
}

export function ChristmasPrompt({ again, onYes, onNo }) {
  const yes = useRef(null);
  useEffect(() => { yes.current?.focus(); }, []);
  return (
    <div className="xmPrompt" role="dialog" aria-modal="true" aria-labelledby="xmPromptTitle">
      <div className="xmPromptCard">
        <div className="xmPromptSnow" aria-hidden="true">{Array.from({ length: 18 }, (_, i) => <i key={i} style={{ "--x": `${(i * 37) % 100}%`, "--d": `${(i % 6) * 0.7}s`, "--s": `${4 + (i % 4)}s` }} />)}</div>
        <div className="xmPromptIcons" aria-hidden="true"><TreePine size={40} /><Gift size={30} /><Snowflake size={26} /></div>
        <h2 id="xmPromptTitle">{again ? "Wie sieht's aus, jetzt in Weihnachtsstimmung?" : "Naa, schon in Weihnachtsstimmung?"}</h2>
        <p>{again ? "Lichterketten, Kaminfeuer und Schnee warten schon auf dich." : "Dann schmücken wir das Aviary für dich – mit Lichterketten, Kaminfeuer, Schnee und Musik."}</p>
        <div className="xmPromptActions">
          <button ref={yes} type="button" className="xmYes" onClick={(event) => onYes(event)}>Ja, her damit! 🎄</button>
          <button type="button" className="ghost" onClick={onNo}>Nein, noch nicht</button>
        </div>
        <small>Du kannst das jederzeit in deinem Profil umstellen.</small>
      </div>
    </div>
  );
}

export function ChristmasSettings({ mode, setMode }) {
  const [prefs, setPrefs] = useState(musicPrefs);
  useEffect(() => onMusicPrefs(setPrefs), []);
  const on = mode === "on";
  return (
    <section className="panel xmSettings" aria-labelledby="xmSettingsTitle">
      <div>
        <h3 id="xmSettingsTitle"><TreePine size={18} /> Weihnachtsstimmung</h3>
        <p>Lichterketten, Tannenzweige, Kaminfeuer und Schnee auf der ganzen Seite.</p>
      </div>
      <label className="xmSwitch">
        <input type="checkbox" role="switch" checked={on} onChange={() => setMode(on ? "off" : "on")} />
        <span aria-hidden="true" /> Weihnachtsdeko {on ? "an" : "aus"}
      </label>
      {on && (
        <div className="xmMusicRow">
          <label className="xmSwitch">
            <input type="checkbox" role="switch" checked={!prefs.muted} onChange={() => setMusicMuted(!prefs.muted, true)} />
            <span aria-hidden="true" /> Musik
          </label>
          <label className="xmVolume">Lautstärke
            <input type="range" min="0" max="1" step="0.05" value={prefs.volume} disabled={prefs.muted} onChange={(e) => setMusicVolume(e.target.value)} />
            <b>{Math.round(prefs.volume * 100)}</b>
          </label>
        </div>
      )}
    </section>
  );
}
