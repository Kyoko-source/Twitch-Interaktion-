import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { HelpCircle, LogIn, Minus, Plus, Repeat, Volume2, VolumeX } from "lucide-react";
import { api } from "../api";
import { publishWallet, requestId } from "../economy/useGameRewards";
import { PinballAudio } from "../pinball/audio.js";
import { ALL_SYMBOLS, SYMBOL_NAMES, SlotSymbol } from "./symbols.jsx";
import "../pinball/casino.css";
import "./slots.css";

const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const easeOut = (t) => 1 - Math.pow(1 - t, 3);
const randomSym = () => ALL_SYMBOLS[Math.floor(Math.random() * ALL_SYMBOLS.length)];
const STRIP = 22; // symbols that fly past before the final three
const TIERS = [
  { at: 10, label: "BIG WIN", tone: "gold", sound: "jackpot", voice: "vo-winner" },
  { at: 25, label: "MEGA WIN", tone: "pink", sound: "super-jackpot", voice: "vo-f-congratulations" },
  { at: 50, label: "EPIC WIN", tone: "cyan", sound: "wizard", voice: "vo-flawless" },
  { at: 100, label: "LEGENDARY WIN", tone: "rainbow", sound: "super-jackpot", voice: "vo-multi" },
];
const CREW_V = 2;

function idleGrid() { return Array.from({ length: 5 }, () => Array.from({ length: 3 }, randomSym)); }

function WinCounter({ win, bet, audio, onTier }) {
  const [value, setValue] = useState(0);
  const [done, setDone] = useState(false);
  const tierRef = useRef(-1);
  useEffect(() => {
    const ratio = win / bet;
    const ms = ratio >= 10 ? 4200 : ratio >= 3 ? 1800 : 900;
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
      const tier = TIERS.reduce((n, tr, i) => (v / bet >= tr.at ? i : n), -1);
      if (tier > tierRef.current) { tierRef.current = tier; onTier(tier); }
      if (t < 1) frame = requestAnimationFrame(step); else setDone(true);
    };
    frame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frame);
  }, [win, bet, audio, onTier]);
  useEffect(() => { if (done && win / bet >= 10) { audio?.play("super-jackpot", { gain: 0.8 }); audio?.play("kickback", { gain: 0.7 }); } }, [done, win, bet, audio]);
  return <strong className={`slWinValue${done ? " done" : ""}`} style={{ "--grow": 0.8 + Math.min(1, value / Math.max(1, bet * 50)) * 0.7 }}>+{fmt(value)}</strong>;
}

function Coins({ count, mode }) {
  const coins = useMemo(() => Array.from({ length: count }, (_, i) => ({
    key: i, x: Math.random() * 100, dx: (Math.random() - 0.5) * 1000, peak: 280 + Math.random() * 440, d: 1 + Math.random() * 1.2,
    delay: Math.random() * (mode === "boom" ? 0.3 : 3), s: 16 + Math.random() * 26, r: Math.random() * 1080,
  })), [count, mode]);
  return <div className={`pbCoins mode-${mode}`} aria-hidden="true">{coins.map((c) => <i key={c.key} style={{ left: `${c.x}%`, width: c.s, height: c.s, animationDuration: `${c.d}s`, animationDelay: `${c.delay}s`, "--r": `${c.r}deg`, "--dx": `${c.dx}px`, "--peak": `${-c.peak}px` }} />)}</div>;
}

export function ChickenJackpot({ user, onLogin }) {
  const [info, setInfo] = useState(null);
  const [grid, setGrid] = useState(idleGrid);
  const [strips, setStrips] = useState(null);
  const [stopped, setStopped] = useState([true, true, true, true, true]);
  const [tense, setTense] = useState(false);
  const [result, setResult] = useState(null);
  const [showWin, setShowWin] = useState(false);
  const [tier, setTier] = useState(-1);
  const [lineIdx, setLineIdx] = useState(0);
  const [betIdx, setBetIdx] = useState(1);
  const [spinning, setSpinning] = useState(false);
  const [auto, setAuto] = useState(0);
  const [msg, setMsg] = useState("");
  const [lever, setLever] = useState(false);
  const [soundOn, setSoundOn] = useState(true);
  const [help, setHelp] = useState(false);
  const audioRef = useRef(null);
  const cabRef = useRef(null);
  const tickTimer = useRef(0);
  const autoRef = useRef(0);
  autoRef.current = auto;

  const audio = useMemo(() => { const a = new PinballAudio(); audioRef.current = a; return a; }, []);
  useEffect(() => () => { audio.dispose(); clearInterval(tickTimer.current); }, [audio]);

  const load = useCallback(() => {
    if (!user) return;
    api("/api/slots").then((d) => setInfo(d)).catch((e) => setMsg(e.message));
  }, [user]);
  useEffect(load, [load]);

  const bets = info?.bets || [2, 5, 10, 20, 50];
  const bet = bets[Math.min(betIdx, bets.length - 1)];
  const balance = info?.wallet?.chickens ?? 0;

  const quake = useCallback((strength = 1) => {
    const el = cabRef.current;
    if (!el || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    el.style.setProperty("--quake", String(strength));
    el.classList.remove("pbQuake"); void el.offsetWidth; el.classList.add("pbQuake");
    setTimeout(() => el.classList.remove("pbQuake"), 520);
  }, []);

  const onTier = useCallback((t) => {
    if (t < 0) return;
    setTier(t);
    audio.play(TIERS[t].sound, { gain: 0.85 });
    audio.voice(TIERS[t].voice);
    quake(1.4 + t * 0.5);
  }, [audio, quake]);

  async function spin() {
    if (!user || spinning) return;
    if (balance < bet) { setMsg("Nicht genug Chickens für diesen Einsatz."); setAuto(0); return; }
    audio.ensure();
    setMsg(""); setResult(null); setShowWin(false); setTier(-1); setLineIdx(0);
    setSpinning(true); setLever(true); setTimeout(() => setLever(false), 380);
    audio.play("plunger", { gain: 0.7 }); audio.play("launch", { gain: 0.6 });
    // Start every reel spinning immediately; the server answer decides where they land.
    setStopped([false, false, false, false, false]);
    const filler = Array.from({ length: 5 }, () => Array.from({ length: STRIP }, randomSym));
    setStrips({ filler, final: null, key: Date.now() });
    clearInterval(tickTimer.current);
    tickTimer.current = setInterval(() => audio.play("spinner", { gain: 0.12, rate: 0.9 + Math.random() * 0.2, gap: 0 }), 85);
    let data;
    try {
      data = await api("/api/slots/spin", { method: "POST", body: JSON.stringify({ bet, request_id: requestId() }) });
    } catch (e) {
      clearInterval(tickTimer.current);
      setStopped([true, true, true, true, true]); setStrips(null); setSpinning(false); setAuto(0);
      setMsg(e.message); load(); return;
    }
    setStrips((s) => ({ ...s, final: data.grid }));
    // Staggered stops; two golden eggs already showing make the rest crawl in.
    let at = 650;
    const eggsAfter = (reel) => data.grid.slice(0, reel + 1).flat().filter((x) => x === "egg").length;
    for (let r = 0; r < 5; r++) {
      const tension = r >= 2 && eggsAfter(r - 1) >= 2;
      at += tension ? 1100 : 260;
      const reel = r;
      setTimeout(() => {
        if (tension) setTense(false);
        setStopped((st) => st.map((v, i) => (i === reel ? true : v)));
        audio.play("drop", { gain: 0.7, rate: 0.9 + reel * 0.06 });
        if (data.grid[reel].includes("egg")) audio.play("vip-lit", { gain: 0.5 });
        if (reel === 4) finish(data);
        else if (reel >= 1 && eggsAfter(reel) >= 2) { setTense(true); audio.play("mission-lit", { gain: 0.6 }); }
      }, at);
    }
  }

  function finish(data) {
    clearInterval(tickTimer.current);
    setGrid(data.grid);
    setStrips(null);
    setTense(false);
    setInfo((i) => (i ? { ...i, wallet: data.wallet, today: data.today } : i));
    publishWallet(user.username, data.wallet);
    setResult(data);
    setSpinning(false);
    if (data.win > 0) {
      setShowWin(true);
      const ratio = data.win / data.bet;
      audio.play(ratio >= 3 ? "lanes-complete" : "lane", { gain: 0.7 });
      if (ratio >= 3) quake(1);
      const hold = ratio >= 10 ? 7000 : ratio >= 3 ? 3200 : 1600;
      setTimeout(() => { setShowWin(false); if (autoRef.current > 0) nextAuto(ratio); }, hold);
    } else if (autoRef.current > 0) setTimeout(() => nextAuto(0), 650);
  }

  function nextAuto(ratio) {
    if (ratio >= 10) { setAuto(0); return; }
    setAuto((n) => { const left = n - 1; if (left > 0) setTimeout(() => document.querySelector(".slSpin")?.click(), 50); return Math.max(0, left); });
  }

  // Cycle through the winning lines.
  useEffect(() => {
    if (!result?.wins?.length) return undefined;
    const t = setInterval(() => setLineIdx((i) => (i + 1) % result.wins.length), 900);
    return () => clearInterval(t);
  }, [result]);

  useEffect(() => {
    const key = (e) => {
      if (/^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || "")) return;
      if (e.code === "Space" && cabRef.current?.isConnected) { e.preventDefault(); if (!e.repeat) document.querySelector(".slSpin")?.click(); }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  });

  const winCells = new Set();
  const activeLine = result?.wins?.[lineIdx];
  if (result) {
    for (const w of result.wins) for (const [r, row] of w.cells) winCells.add(`${r}-${row}`);
    for (const [r, row] of result.scatter?.cells || []) winCells.add(`${r}-${row}`);
  }
  const ratio = result ? result.win / result.bet : 0;
  const big = showWin && ratio >= 10;
  const T = tier >= 0 ? TIERS[tier] : null;
  const lines = info?.lines;

  return (
    <section className={`slShell${big ? " isBig" : ""}${spinning ? " isSpinning" : ""}`} aria-label="Chicken Jackpot">
      <header className="slHeader">
        <div><span>AVIARY CASINO · NUR VIRTUELLE CHICKENS</span><h2>Chicken Jackpot</h2></div>
        <div className="pbTools">
          <button type="button" onClick={() => setHelp(!help)} aria-pressed={help} title="Gewinntabelle" aria-label="Gewinntabelle"><HelpCircle size={18} /></button>
          <button type="button" onClick={() => { const v = !soundOn; setSoundOn(v); audio.setSfx(v); }} aria-pressed={!soundOn} title={soundOn ? "Sound aus" : "Sound an"} aria-label={soundOn ? "Sound aus" : "Sound an"}>{soundOn ? <Volume2 size={18} /> : <VolumeX size={18} />}</button>
        </div>
      </header>

      <div className="slCabinet" ref={cabRef}>
        <span className="pbBeams slBeams" aria-hidden="true" />
        <div className="slMarquee">
          <span className="pbBulbs" aria-hidden="true" />
          <b>★</b> CHICKEN JACKPOT <b>★</b>
        </div>
        <div className="slLeds">
          <div><small>GUTHABEN</small><strong data-testid="slot-balance">{user ? fmt(balance) : "–"}</strong></div>
          <div><small>EINSATZ</small><strong>{bet}</strong></div>
          <div className={result?.win ? "hot" : ""}><small>GEWINN</small><strong>{result ? fmt(result.win) : 0}</strong></div>
        </div>

        <div className={`slWindow${tense ? " tense" : ""}`}>
          <div className="slReels">
            {Array.from({ length: 5 }, (_, r) => {
              const moving = strips && !stopped[r];
              const column = moving ? [...strips.filler[r], ...(strips.final ? strips.final[r] : strips.filler[r].slice(0, 3))] : strips?.final ? strips.final[r] : grid[r];
              return (
                <div key={r} className={`slReel${moving ? " moving" : ""}${tense && !stopped[r] ? " tenseReel" : ""}`}>
                  <div className="slStrip" key={moving ? `${strips.key}-${r}` : `still-${r}`} style={moving ? { "--n": column.length - 3 } : undefined}>
                    {column.map((s, i) => {
                      const row = moving ? -1 : i;
                      const hit = !moving && winCells.has(`${r}-${row}`);
                      const inLine = !moving && activeLine?.cells.some(([cr, crow]) => cr === r && crow === row);
                      return <div key={i} className={`slCell${hit ? " hit" : ""}${inLine ? " inLine" : ""}`}><SlotSymbol name={s} /></div>;
                    })}
                  </div>
                </div>
              );
            })}
          </div>
          {activeLine && lines && (
            <svg className="slLine" viewBox="0 0 500 300" preserveAspectRatio="none" aria-hidden="true">
              <polyline points={lines[activeLine.line].map((row, r) => `${r * 100 + 50},${row * 100 + 50}`).join(" ")} />
            </svg>
          )}
          {showWin && result && (
            <div className={`slWinBox${big ? " big" : ""}`} key={result.grid.flat().join("")}>
              {T && <div key={tier} className={`pbWinTier tone-${T.tone}`}>{T.label}</div>}
              <WinCounter win={result.win} bet={result.bet} audio={audio} onTier={onTier} />
              {activeLine && <small>{activeLine.count}× {SYMBOL_NAMES[activeLine.symbol]} · Linie {activeLine.line + 1}</small>}
              {result.scatter && <small>{result.scatter.count} Goldene Eier! ×{result.scatter.mult}</small>}
            </div>
          )}
        </div>

        <button type="button" className={`slLever${lever ? " pulled" : ""}`} onClick={spin} disabled={!user || spinning} aria-label="Hebel ziehen"><span /><i /></button>

        <div className="slControls">
          {user ? (
            <>
              <div className="slBet">
                <button type="button" onClick={() => setBetIdx(Math.max(0, betIdx - 1))} disabled={spinning || betIdx === 0} aria-label="Einsatz verringern"><Minus size={18} /></button>
                <span><small>EINSATZ</small><b>{bet}</b></span>
                <button type="button" onClick={() => setBetIdx(Math.min(bets.length - 1, betIdx + 1))} disabled={spinning || betIdx >= bets.length - 1} aria-label="Einsatz erhöhen"><Plus size={18} /></button>
              </div>
              <button type="button" className="slSpin" onClick={spin} disabled={spinning || balance < bet}>{spinning ? "…" : "SPIN"}</button>
              <button type="button" className={`slAuto${auto ? " on" : ""}`} onClick={() => { if (auto) setAuto(0); else { setAuto(10); if (!spinning) setTimeout(() => document.querySelector(".slSpin")?.click(), 30); } }} disabled={!auto && (spinning || balance < bet)}><Repeat size={16} />{auto ? `STOP (${auto})` : "AUTO 10"}</button>
            </>
          ) : (
            <button type="button" className="slSpin login" onClick={onLogin}><LogIn size={20} /> Anmelden & spielen</button>
          )}
        </div>
        {msg && <p className="slMsg" role="alert">{msg}</p>}
        {info?.today && <p className="slFine">Nur virtuelle Chickens, kein echtes Geld. Auszahlungsquote ca. {Math.round((info.rtp || 0.93) * 100)} %. Heute am Automaten: {info.today.net >= 0 ? "+" : ""}{fmt(info.today.net)} / max. +{info.today.cap} Gewinn pro Tag.</p>}

        {big && (
          <div className="slParty" aria-hidden="true">
            <span className="pbSpot left" /><span className="pbSpot right" /><span className="pbStrobe slStrobe" />
            <Coins count={70} mode="fountain" />
            <img className="slCut left" src={`/assets/pinball/crew/mimi-hype.webp?v=${CREW_V}`} alt="" />
            <img className="slCut right" src={`/assets/pinball/crew/luna-cheer.webp?v=${CREW_V}`} alt="" />
          </div>
        )}
      </div>

      {help && info && (
        <div className="slPaytable">
          <h3>Gewinntabelle <small>(× Einsatz, von links auf einer der 10 Linien)</small></h3>
          <div className="slPayGrid">
            {Object.entries(info.pay).reverse().map(([sym, pays]) => (
              <div key={sym}><SlotSymbol name={sym} /><span>{pays.map((p, i) => <b key={i}>{i + 3}× = {p}</b>)}</span></div>
            ))}
            <div><SlotSymbol name="egg" /><span>{Object.entries(info.scatter).map(([n, p]) => <b key={n}>{n}× = {p}</b>)}<em>überall</em></span></div>
          </div>
          <p>Die Krone ist Wild und ersetzt alle Symbole außer dem Goldenen Ei.</p>
        </div>
      )}
    </section>
  );
}
