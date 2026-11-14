import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Expand, HelpCircle, LogIn, Minus, Music, Plus, Repeat, Shrink, Volume2, VolumeX, Zap } from "lucide-react";
import { api } from "../api";
import { publishWallet, requestId } from "../economy/useGameRewards";
import { PinballAudio } from "../pinball/audio.js";
import { ALL_SYMBOLS, SYMBOL_NAMES, SlotSymbol } from "./symbols.jsx";
import { Reel } from "./Reel.jsx";
import { RoyalBird } from "./RoyalBird.jsx";
import { SlotFx } from "./fx.js";
import "../pinball/casino.css";
import "./slots.css";

const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const easeOut = (t) => 1 - Math.pow(1 - t, 3);
const randomSym = () => ALL_SYMBOLS[Math.floor(Math.random() * ALL_SYMBOLS.length)];
const pick = (list) => list[Math.floor(Math.random() * list.length)];
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const CREW_V = 2;
const BULBS = 44;
const TIERS = [
  { at: 10, label: "BIG WIN", tone: "gold", sound: "jackpot", voice: "vo-winner" },
  { at: 25, label: "MEGA WIN", tone: "pink", sound: "super-jackpot", voice: "vo-f-congratulations" },
  { at: 50, label: "EPIC WIN", tone: "cyan", sound: "wizard", voice: "vo-flawless" },
  { at: 100, label: "LEGENDARY WIN", tone: "rainbow", sound: "super-jackpot", voice: "vo-multi" },
];
const SAY = {
  spin: ["Komm schon!", "Eier, Eier, Eier!", "Ich hab ein gutes Gefühl!", "Gack gack!", "Dreh das Ding!", "Heute ist unser Tag!"],
  tense: ["Nur noch ein Ei…", "Bitte bitte bitte…", "Ich kann nicht hinsehen!"],
  win: ["Nice!", "Gewinner-Huhn!", "Mehr davon!", "Gack-tastisch!", "Läuft bei dir!"],
  big: ["WAAAS?!", "KÖNIGLICH!!", "Ich flipp aus!", "REGEN AUS GOLD!"],
  loss: ["Nächstes Mal!", "Hmpf.", "Noch einer!", "Knapp daneben…"],
  near: ["Sooo knapp!", "Zwei Eier… ARGH!"],
  bonus: ["EIER-ALARM!!!", "FREISPIELE!!!", "Jetzt wird's königlich!"],
};

function idleGrid() { return Array.from({ length: 5 }, () => Array.from({ length: 3 }, randomSym)); }

// Bulbs around the reel window, evenly spaced along the rectangle's outline.
const bulbPositions = Array.from({ length: BULBS }, (_, i) => {
  const t = i / BULBS, w = 1.6, h = 1, per = 2 * (w + h);
  let d = t * per, x, y;
  if (d < w) { x = d / w; y = 0; } else if ((d -= w) < h) { x = 1; y = d / h; } else if ((d -= h) < w) { x = 1 - d / w; y = 1; } else { d -= w; x = 0; y = 1 - d / h; }
  return { left: `${x * 100}%`, top: `${y * 100}%`, "--i": i };
});

function WinCounter({ win, unit, audio, onTier, onDone, ms }) {
  const [value, setValue] = useState(0);
  const [done, setDone] = useState(false);
  const tierRef = useRef(-1);
  const cb = useRef({ onTier, onDone });
  cb.current = { onTier, onDone };
  useEffect(() => {
    const start = performance.now();
    let frame = 0, last = 0;
    const step = (now) => {
      const t = Math.min(1, (now - start) / ms);
      const v = win * easeOut(t);
      setValue(v);
      if (now - last > 55 && t < 1) {
        last = now;
        audio?.play("spinner", { gain: 0.2, rate: 1 + t * 1.6, gap: 0.035 });
        if (Math.random() < 0.6) audio?.play(`coin-${1 + Math.floor(Math.random() * 5)}`, { gain: 0.3 + t * 0.3, rate: 0.9 + Math.random() * 0.5, gap: 0.03 });
      }
      const tier = TIERS.reduce((n, tr, i) => (v / unit >= tr.at ? i : n), -1);
      if (tier > tierRef.current) { tierRef.current = tier; cb.current.onTier?.(tier); }
      if (t < 1) frame = requestAnimationFrame(step); else { setDone(true); cb.current.onDone?.(); }
    };
    frame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frame);
  }, [win, unit, audio, ms]);
  // --chars lets the CSS shrink the digits so even millions fit the reel window.
  return <strong className={`slWinValue${done ? " done" : ""}`} style={{ "--grow": 0.8 + Math.min(1, value / Math.max(1, unit * 50)) * 0.7, "--chars": fmt(win).length + 1 }}>+{fmt(value)}</strong>;
}

export function ChickenJackpot({ user, onLogin }) {
  const [info, setInfo] = useState(null);
  const [grid, setGrid] = useState(idleGrid);
  const [result, setResult] = useState(null);       // the spin whose wins are on screen
  const [winBox, setWinBox] = useState(null);       // { win, ratio, key }
  const [tier, setTier] = useState(-1);
  const [lineIdx, setLineIdx] = useState(0);
  const [tense, setTense] = useState(-1);           // reel index that crawls in
  const [phase, setPhase] = useState("idle");       // idle | spin | result | bonusIntro | bonus | bonusEnd
  const [bonus, setBonus] = useState(null);         // { played, awarded, total, mult }
  const [splash, setSplash] = useState(null);       // { title, sub, key }
  const [mood, setMood] = useState("idle");
  const [say, setSay] = useState("");
  const [lights, setLights] = useState("idle");
  const [popups, setPopups] = useState([]);
  const [lever, setLever] = useState(false);
  const [betIdx, setBetIdx] = useState(0);
  const [auto, setAuto] = useState(0);
  const [msg, setMsg] = useState("");
  const [soundOn, setSoundOn] = useState(true);
  const [musicOn, setMusicOn] = useState(true);
  const [help, setHelp] = useState(false);
  const [full, setFull] = useState(false);
  const [shownGsc, setShownGsc] = useState(null);
  const [lastWin, setLastWin] = useState(0);
  const shell = useRef(null);
  const cab = useRef(null);
  const win = useRef(null);
  const canvas = useRef(null);
  const fx = useRef(null);
  const reels = useRef([]);
  const alive = useRef(true);
  const slam = useRef(false);
  const busy = useRef(false);
  const autoRef = useRef(0);
  const sayTimer = useRef(0);
  const counterDone = useRef(null);
  autoRef.current = auto;

  const audio = useMemo(() => new PinballAudio(), []);
  useEffect(() => {
    alive.current = true;
    fx.current = canvas.current ? new SlotFx(canvas.current) : null;
    return () => { alive.current = false; audio.dispose(); fx.current?.dispose(); clearTimeout(sayTimer.current); };
  }, [audio]);

  const load = useCallback(() => {
    if (!user) return;
    api("/api/slots").then((d) => { setInfo(d); setShownGsc(null); }).catch((e) => setMsg(e.message));
  }, [user?.username]);
  useEffect(load, [load]);

  const bets = info?.bets || [1, 2, 5, 10];
  const bet = bets[Math.min(betIdx, bets.length - 1)];
  const gscPerCredit = info?.gsc_per_credit || 10000;
  const balance = info?.wallet?.credits ?? 0;
  const gsc = shownGsc ?? info?.wallet?.gsc ?? 0;
  const spinning = phase !== "idle";

  const speak = useCallback((list, ms = 2300) => {
    clearTimeout(sayTimer.current);
    setSay(Array.isArray(list) ? pick(list) : list);
    sayTimer.current = setTimeout(() => setSay(""), ms);
  }, []);

  const quake = useCallback((strength = 1) => {
    const el = cab.current;
    if (!el || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    el.style.setProperty("--quake", String(strength));
    el.classList.remove("pbQuake"); void el.offsetWidth; el.classList.add("pbQuake");
    setTimeout(() => el.classList.remove("pbQuake"), 520);
  }, []);

  // Canvas coordinates (0..1) of a reel cell.
  const cellPoint = useCallback((r, row) => {
    const c = canvas.current?.getBoundingClientRect(), w = win.current?.getBoundingClientRect();
    if (!c || !w || !c.width) return [0.5, 0.5];
    return [(w.left - c.left + w.width * ((r + 0.5) / 5)) / c.width, (w.top - c.top + w.height * ((row + 0.5) / 3)) / c.height];
  }, []);

  const popup = useCallback((text, x, y, tone = "") => {
    const id = Math.random().toString(36).slice(2);
    setPopups((p) => [...p, { id, text, x, y, tone }]);
    setTimeout(() => alive.current && setPopups((p) => p.filter((q) => q.id !== id)), 1500);
  }, []);

  const onTier = useCallback((t) => {
    if (t < 0) return;
    setTier(t);
    audio.play(TIERS[t].sound, { gain: 0.85 });
    audio.voice(TIERS[t].voice);
    quake(1.4 + t * 0.5);
    fx.current?.burst("star", 0.5, 0.45, 26 + t * 10, 1.2);
    fx.current?.fountain(30 + t * 20, 1 + t * 0.15);
    setMood("big");
  }, [audio, quake]);

  // ------------------------------------------------------------------ reels
  async function landReels(final, fast) {
    const eggsUpTo = (reel) => final.slice(0, reel + 1).flat().filter((x) => x === "egg").length;
    for (let r = 0; r < 5; r++) {
      if (!alive.current) return;
      const tension = r >= 2 && eggsUpTo(r - 1) >= 2 && !slam.current;
      if (tension) {
        setTense(r); setLights("tense"); setMood("tense"); speak(SAY.tense);
        audio.play("mission-lit", { gain: 0.6 });
        const beats = fast ? 3 : 5;
        for (let b = 0; b < beats && !slam.current; b++) { await sleep(260); audio.play("ball-click", { gain: 0.5, rate: 0.7 + b * 0.08 }); }
      } else await sleep(slam.current ? 40 : r === 0 ? (fast ? 420 : 620) : fast ? 170 : 240);
      await reels.current[r]?.stop(final[r], slam.current ? 260 : tension ? 760 : 470);
      if (!alive.current) return;
      if (tension) { setTense(-1); setLights("spin"); setMood("spin"); }
      audio.play("drop", { gain: 0.7, rate: 0.9 + r * 0.06 });
      const [x] = cellPoint(r, 1);
      fx.current?.burst("spark", x, 0.92, 8, 0.4);
      if (final[r].includes("egg")) {
        audio.play("vip-lit", { gain: 0.55 });
        final[r].forEach((s, row) => { if (s === "egg") { const [ex, ey] = cellPoint(r, row); fx.current?.burst("star", ex, ey, 10, 0.5); } });
      }
    }
  }

  // ------------------------------------------------------------- wins
  async function present(res, stake, { quick = false } = {}) {
    setResult(res);
    setLineIdx(0);
    const unit = stake * gscPerCredit;
    const ratio = res.win / unit;
    if (!res.win) {
      const eggs = res.grid.flat().filter((s) => s === "egg").length;
      if (!quick) { setMood(eggs === 2 ? "tense" : "sad"); speak(eggs === 2 ? SAY.near : SAY.loss, 1600); }
      await sleep(quick ? 350 : 500);
      return;
    }
    setLights(ratio >= 10 ? "big" : "win");
    setMood(ratio >= 10 ? "big" : "win");
    speak(ratio >= 10 ? SAY.big : SAY.win);
    audio.play(ratio >= 3 ? "lanes-complete" : "lane", { gain: 0.7 });
    for (const w of res.wins) {
      for (const [r, row] of w.cells) { const [x, y] = cellPoint(r, row); fx.current?.burst(ratio >= 3 ? "coin" : "spark", x, y, ratio >= 3 ? 5 : 8, 0.6); }
      const [lx, ly] = cellPoint(w.count - 1, w.cells[w.count - 1][1]);
      popup(`+${fmt(w.win ?? w.mult * unit)}`, lx, ly);
    }
    for (const [r, row] of res.scatter?.cells || []) { const [x, y] = cellPoint(r, row); fx.current?.burst("star", x, y, 14, 0.8); }
    if (ratio >= 3) quake(1);
    setTier(-1);
    const ms = ratio >= 10 ? 4600 : ratio >= 3 ? 2000 : 900;
    const done = new Promise((resolve) => { counterDone.current = resolve; });
    setWinBox({ win: res.win, unit, ratio, key: Math.random(), ms });
    if (ratio >= 10) { fx.current?.rain("coin", 40, 4.5); fx.current?.rain("feather", 6, 4.5); audio.duck(5); }
    else if (ratio >= 3) fx.current?.fountain(26, 0.9);
    await done;
    if (ratio >= 10) { audio.play("super-jackpot", { gain: 0.8 }); audio.play("kickback", { gain: 0.7 }); fx.current?.fountain(70, 1.3); quake(2.2); }
    await sleep(ratio >= 10 ? 2200 : ratio >= 3 ? 1300 : quick ? 700 : 1000);
    // Small base-game wins stay on the glass until the next spin; big ones clear the view.
    if (ratio >= 3 || quick) setWinBox(null);
  }

  // --------------------------------------------------------- egg bonus
  async function runBonus(b, stake) {
    const initial = b.awarded - b.spins.reduce((n, s) => n + (s.extra_spins || 0), 0);
    setPhase("bonusIntro"); setLights("bonus"); setMood("bonus"); speak(SAY.bonus, 3000);
    audio.play("multiball", { gain: 0.9 }); audio.play("multiball-fx", { gain: 0.6 }); audio.voice("vo-fight", 0.7);
    audio.music("multiball");
    quake(2.4);
    fx.current?.burst("star", 0.5, 0.5, 60, 1.6); fx.current?.rain("feather", 10, 3);
    setSplash({ title: "EIER-BONUS!", sub: `${initial} FREISPIELE · ALLE GEWINNE ×${b.mult}`, key: Math.random() });
    await sleep(3000);
    setSplash(null);
    setPhase("bonus");
    let awarded = initial, total = 0;
    setBonus({ played: 0, awarded, total, mult: b.mult });
    for (let i = 0; i < b.spins.length; i++) {
      if (!alive.current) return 0;
      const fs = b.spins[i];
      setResult(null); setTense(-1); setLights("spin"); setMood("spin");
      setBonus({ played: i + 1, awarded, total, mult: b.mult });
      audio.play("launch", { gain: 0.5 });
      reels.current.forEach((r) => r?.spin());
      await sleep(slam.current ? 120 : 380);
      setGrid(fs.grid);
      await landReels(fs.grid, true);
      setLights("bonus");
      await present(fs, stake, { quick: true });
      total += fs.win;
      if (fs.extra_spins) {
        awarded += fs.extra_spins;
        audio.play("extra-ball", { gain: 0.9 }); audio.voice("vo-f-power-up");
        setSplash({ title: `+${fs.extra_spins} FREISPIELE!`, sub: "Mehr Eier, mehr Gold!", key: Math.random() });
        fx.current?.burst("star", 0.5, 0.5, 40, 1.3);
        await sleep(1800);
        setSplash(null);
      }
      setBonus({ played: i + 1, awarded, total, mult: b.mult });
      setMood("bonus");
    }
    // Grand finale of the bonus.
    setPhase("bonusEnd"); setLights("big"); setMood(total > 0 ? "big" : "sad");
    audio.play("bonus-total", { gain: 0.9 });
    const unit = stake * gscPerCredit;
    const done = new Promise((resolve) => { counterDone.current = resolve; });
    setResult(null);
    setWinBox({ win: total, unit, ratio: total / unit, key: Math.random(), ms: total > 0 ? 5200 : 400, bonusTotal: true });
    if (total > 0) { fx.current?.rain("coin", 50, 5); fx.current?.rain("feather", 8, 5); }
    await done;
    if (total > 0) { fx.current?.fountain(90, 1.4); quake(2.6); audio.play("super-jackpot", { gain: 0.9 }); }
    await sleep(2600);
    setWinBox(null);
    setBonus(null);
    audio.music("play");
    return total;
  }

  // -------------------------------------------------------------- spin
  async function spin() {
    if (!user) return;
    if (busy.current) { slam.current = true; return; } // second press = stop the reels now
    if (balance < bet) { setMsg("Nicht genug Credits. Credits gibt es im Shop (10 Chickens pro Credit)."); setAuto(0); return; }
    busy.current = true; slam.current = false;
    audio.ensure();
    if (musicOn && !audio.track) audio.music("play");
    setMsg(""); setResult(null); setWinBox(null); setTier(-1); setTense(-1);
    setPhase("spin"); setLights("spin"); setMood("spin"); speak(SAY.spin, 1500);
    setLever(true); setTimeout(() => setLever(false), 380);
    audio.play("plunger", { gain: 0.7 }); audio.play("launch", { gain: 0.6 });
    reels.current.forEach((r) => r?.spin());
    const tick = setInterval(() => audio.play("spinner", { gain: 0.1, rate: 0.9 + Math.random() * 0.2, gap: 0 }), 95);
    let data;
    try {
      data = await api("/api/slots/spin", { method: "POST", body: JSON.stringify({ bet, request_id: requestId() }) });
    } catch (e) {
      clearInterval(tick);
      await Promise.all(reels.current.map((r, i) => r?.stop(grid[i], 300)));
      busy.current = false; setPhase("idle"); setLights("idle"); setMood("sad"); setAuto(0);
      setMsg(e.message); load(); return;
    }
    if (!alive.current) { clearInterval(tick); return; }
    const before = info?.wallet?.gsc ?? 0;
    setShownGsc(before);
    setInfo((i) => (i ? { ...i, wallet: { ...data.wallet } } : i)); // "today" follows after the show, no spoilers
    setGrid(data.grid);
    await landReels(data.grid, false);
    clearInterval(tick);
    setPhase("result");
    await present({ ...data, win: data.base_win ?? data.win }, data.bet);
    let gained = data.base_win ?? data.win;
    setShownGsc(before + gained);
    if (data.bonus) { gained += await runBonus(data.bonus, data.bet); }
    if (!alive.current) return;
    setShownGsc(null);
    setInfo((i) => (i ? { ...i, today: data.today } : i));
    setLastWin(data.win);
    publishWallet(user.username, data.wallet);
    busy.current = false; slam.current = false;
    setPhase("idle"); setLights(data.win ? "win" : "idle"); setTense(-1);
    if (!data.win) setMood("idle");
    setTimeout(() => alive.current && !busy.current && (setLights("idle"), setMood("idle")), 2500);
    const ratio = data.win / (data.bet * gscPerCredit);
    if (autoRef.current > 0) {
      if (ratio >= 10 || data.bonus) setAuto(0);
      else setAuto((n) => { const left = n - 1; if (left > 0) setTimeout(() => alive.current && document.querySelector(".slSpin")?.click(), 450); return Math.max(0, left); });
    }
  }

  // Cycle through the winning lines.
  useEffect(() => {
    if (!result?.wins?.length) return undefined;
    const t = setInterval(() => setLineIdx((i) => (i + 1) % result.wins.length), 850);
    return () => clearInterval(t);
  }, [result]);

  useEffect(() => {
    const key = (e) => {
      if (/^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || "")) return;
      if (e.code === "Space" && shell.current?.isConnected) { e.preventDefault(); if (!e.repeat) document.querySelector(".slSpin")?.click(); }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, []);

  useEffect(() => {
    const sync = () => setFull(document.fullscreenElement === shell.current);
    document.addEventListener("fullscreenchange", sync);
    return () => document.removeEventListener("fullscreenchange", sync);
  }, []);
  function toggleFull() {
    if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {});
    else shell.current?.requestFullscreen?.().catch(() => {});
  }

  const hits = useMemo(() => {
    const set = new Set();
    if (!result) return set;
    for (const w of result.wins || []) for (const [r, row] of w.cells) set.add(`${r}-${row}`);
    for (const [r, row] of result.scatter?.cells || []) set.add(`${r}-${row}`);
    return set;
  }, [result]);
  const activeLine = result?.wins?.[lineIdx];
  const lines = info?.lines;
  const T = tier >= 0 ? TIERS[tier] : null;
  const big = winBox && winBox.ratio >= 10;
  const inBonus = phase === "bonusIntro" || phase === "bonus" || phase === "bonusEnd";

  return (
    <section ref={shell} className={`slShell${full ? " isFull" : ""}${inBonus ? " inBonus" : ""}${big ? " isBig" : ""}`} aria-label="Chicken Jackpot">
      <header className="slHeader">
        <div><span>AVIARY CASINO · CREDITS REIN, GSC RAUS</span><h2>Chicken Jackpot</h2></div>
        <div className="pbTools">
          <button type="button" onClick={() => setHelp(!help)} aria-pressed={help} title="Gewinntabelle" aria-label="Gewinntabelle"><HelpCircle size={18} /></button>
          <button type="button" onClick={() => { const v = !musicOn; setMusicOn(v); audio.setMusic(v); }} aria-pressed={!musicOn} title={musicOn ? "Musik aus" : "Musik an"} aria-label={musicOn ? "Musik aus" : "Musik an"}><Music size={18} className={musicOn ? "" : "slOff"} /></button>
          <button type="button" onClick={() => { const v = !soundOn; setSoundOn(v); audio.setSfx(v); }} aria-pressed={!soundOn} title={soundOn ? "Sound aus" : "Sound an"} aria-label={soundOn ? "Sound aus" : "Sound an"}>{soundOn ? <Volume2 size={18} /> : <VolumeX size={18} />}</button>
          <button type="button" onClick={toggleFull} title={full ? "Vollbild beenden" : "Vollbild"} aria-label={full ? "Vollbild beenden" : "Vollbild"}>{full ? <Shrink size={18} /> : <Expand size={18} />}</button>
        </div>
      </header>

      <div className="slStage">
        <RoyalBird mood={mood} say={say} />
        <div className={`slCabinet lights-${lights}`} ref={cab}>
          <span className="pbBeams slBeams" aria-hidden="true" />
          <div className="slTop">
            <svg className="slTopCrown" viewBox="0 0 120 60" aria-hidden="true"><path d="M10 52 L18 14 L40 34 L60 4 L80 34 L102 14 L110 52 Z" fill="url(#slCrownG)" stroke="#7a4300" strokeWidth="3" strokeLinejoin="round" /><defs><linearGradient id="slCrownG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#fff6c4" /><stop offset="0.5" stopColor="#ffcf4a" /><stop offset="1" stopColor="#b8740a" /></linearGradient></defs><circle cx="60" cy="6" r="5" fill="#ff5ad6" stroke="#fff" strokeWidth="1.5" /></svg>
            <div className="slMarquee"><span className="pbBulbs" aria-hidden="true" /><b>★</b> CHICKEN JACKPOT <b>★</b></div>
          </div>

          <div className="slLeds">
            <div><small>CREDITS</small><strong data-testid="slot-balance">{user ? fmt(balance) : "–"}</strong></div>
            <div><small>EINSATZ</small><strong>{bet} CR</strong></div>
            <div className={winBox ? "hot" : ""}><small>{inBonus ? "BONUS GSC" : "LETZTER GEWINN"}</small><strong>{inBonus ? fmt(bonus?.total || 0) : fmt(lastWin)}</strong></div>
            <div><small>DEINE GSC</small><strong data-testid="slot-gsc">{user ? fmt(gsc) : "–"}</strong></div>
          </div>

          {inBonus && bonus && (
            <div className="slBonusBar" aria-live="polite">
              <span className="slBonusEgg"><SlotSymbol name="egg" /></span>
              <b>FREISPIEL {Math.min(bonus.played, bonus.awarded)} / {bonus.awarded}</b>
              <em>ALLE GEWINNE ×{bonus.mult}</em>
              <i style={{ "--p": bonus.awarded ? bonus.played / bonus.awarded : 0 }} />
            </div>
          )}

          <div className={`slWindowWrap${tense >= 0 ? " tense" : ""}`}>
            <div className="slBulbRing" aria-hidden="true">{bulbPositions.map((style, i) => <span key={i} style={style} />)}</div>
            <div className="slWindow" ref={win}>
              <div className="slReels">
                {grid.map((column, r) => (
                  <Reel key={r} ref={(el) => { reels.current[r] = el; }} index={r} symbols={column} hits={hits} line={activeLine?.cells} tense={tense === r} />
                ))}
              </div>
              <div className="slGlass" aria-hidden="true" />
              {activeLine && lines && (
                <svg className="slLine" viewBox="0 0 500 300" preserveAspectRatio="none" aria-hidden="true" key={`${lineIdx}-${activeLine.line}`}>
                  <polyline points={lines[activeLine.line].map((row, r) => `${r * 100 + 50},${row * 100 + 50}`).join(" ")} />
                </svg>
              )}
              {winBox && (
                <div className={`slWinBox${winBox.ratio >= 3 ? " mid" : ""}${big ? " big" : ""}${winBox.bonusTotal ? " bonusTotal" : ""}`} key={winBox.key}>
                  {winBox.bonusTotal && <div className="slWinHead">EIER-BONUS GESAMT</div>}
                  {T && <div key={tier} className={`pbWinTier tone-${T.tone}`}>{T.label}</div>}
                  <WinCounter win={winBox.win} unit={winBox.unit} audio={audio} onTier={onTier} onDone={() => counterDone.current?.()} ms={winBox.ms} />
                  {activeLine && !winBox.bonusTotal && <small>{activeLine.count}× {SYMBOL_NAMES[activeLine.symbol]} · Linie {activeLine.line + 1}</small>}
                  {result?.scatter && !winBox.bonusTotal && <small>{result.scatter.count} Goldene Eier!</small>}
                </div>
              )}
              {splash && (
                <div className="slSplash" key={splash.key}>
                  <div className="slSplashEggs"><SlotSymbol name="egg" /><SlotSymbol name="egg" /><SlotSymbol name="egg" /></div>
                  <strong>{splash.title}</strong>
                  <span>{splash.sub}</span>
                </div>
              )}
            </div>
          </div>

          <button type="button" className={`slLever${lever ? " pulled" : ""}`} onClick={spin} disabled={!user || (spinning && phase !== "spin")} aria-label="Hebel ziehen"><span /><i /></button>

          <div className="slControls">
            {user ? (
              <>
                <div className="slBet">
                  <button type="button" onClick={() => setBetIdx(Math.max(0, betIdx - 1))} disabled={spinning || betIdx === 0} aria-label="Einsatz verringern"><Minus size={18} /></button>
                  <span><small>EINSATZ</small><b>{bet}</b></span>
                  <button type="button" onClick={() => setBetIdx(Math.min(bets.length - 1, betIdx + 1))} disabled={spinning || betIdx >= bets.length - 1} aria-label="Einsatz erhöhen"><Plus size={18} /></button>
                </div>
                {balance < bet && !spinning ? (
                  <a className="slSpin buy" href="#shop">Credits kaufen</a>
                ) : (
                  <button type="button" className={`slSpin${spinning ? " isStop" : ""}`} onClick={spin} disabled={spinning && phase !== "spin" && phase !== "bonus"}>
                    {spinning ? <><Zap size={22} /> STOP</> : "SPIN"}
                  </button>
                )}
                <button type="button" className={`slAuto${auto ? " on" : ""}`} onClick={() => { if (auto) setAuto(0); else { setAuto(10); if (!spinning) setTimeout(() => document.querySelector(".slSpin")?.click(), 30); } }} disabled={!auto && (spinning || balance < bet)}><Repeat size={16} />{auto ? `STOP (${auto})` : "AUTO 10"}</button>
              </>
            ) : (
              <button type="button" className="slSpin login" onClick={onLogin}><LogIn size={20} /> Anmelden & spielen</button>
            )}
          </div>
          {msg && <p className="slMsg" role="alert">{msg}</p>}
          {info && <p className="slFine">1 Credit = 1 Spin pro Einsatzstufe ({fmt(gscPerCredit)} GSC Einsatzwert). 3+ Goldene Eier starten den Eier-Bonus mit Freispielen. Gewinne kommen als Glücksspiel-Coins (GSC) – im Shop tauschst du GSC gegen Chickens. Alles virtuell, kein echtes Geld. Heute gewonnen: {fmt(info.today?.won || 0)} GSC.</p>}

          <canvas ref={canvas} className="slFx" aria-hidden="true" />
          <div className="slPopups" aria-hidden="true">{popups.map((p) => <b key={p.id} style={{ left: `${p.x * 100}%`, top: `${p.y * 100}%` }}>{p.text}</b>)}</div>
          {big && (
            <div className="slParty" aria-hidden="true">
              <span className="pbSpot left" /><span className="pbSpot right" /><span className="pbStrobe slStrobe" />
              <img className="slCut left" src={`/assets/pinball/crew/mimi-hype.webp?v=${CREW_V}`} alt="" />
              <img className="slCut right" src={`/assets/pinball/crew/luna-cheer.webp?v=${CREW_V}`} alt="" />
            </div>
          )}
        </div>
      </div>

      {help && info && (
        <div className="slPaytable">
          <h3>Gewinntabelle <small>(× Einsatzwert in GSC, von links auf einer der 10 Linien · 1 Credit = {fmt(gscPerCredit)} GSC)</small></h3>
          <div className="slPayGrid">
            {Object.entries(info.pay).reverse().map(([sym, pays]) => (
              <div key={sym}><SlotSymbol name={sym} /><span><strong>{SYMBOL_NAMES[sym]}</strong>{pays.map((p, i) => <b key={i}>{i + 3}× = {p}</b>)}</span></div>
            ))}
            <div><SlotSymbol name="egg" /><span><strong>Goldenes Ei</strong>{Object.entries(info.scatter).map(([n, p]) => <b key={n}>{n}× = {p}{info.free_spins?.[n] ? ` + ${info.free_spins[n]} Freispiele` : ""}</b>)}<em>überall auf den Walzen</em></span></div>
          </div>
          <p>Der Königsvogel ist Wild und ersetzt alle Symbole außer dem Goldenen Ei. Im Eier-Bonus zählen alle Gewinne ×{info.free_mult || 3}, und neue Eier bringen weitere Freispiele.</p>
        </div>
      )}
    </section>
  );
}
