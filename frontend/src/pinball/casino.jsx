import React, { useEffect, useMemo, useRef, useState } from "react";
import "./casino.css";

// End-of-ball bonus as an over-the-top slot machine payout: spinning light beams, sweeping
// spotlights, a colour strobe (kept at <= 3 flashes/s), chasing marquee bulbs, rows that roll
// up and stamp in, a slamming multiplier, then a grand total that rolls up through BIG / MEGA /
// EPIC / LEGENDARY win tiers with a coin fountain, ending in a coin explosion.
const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const easeOut = (t) => 1 - Math.pow(1 - t, 3);
const TIERS = [
  { at: 50_000, label: "BIG WIN", tone: "gold", sound: "jackpot", voice: "vo-winner" },
  { at: 250_000, label: "MEGA WIN", tone: "pink", sound: "super-jackpot", voice: "vo-f-congratulations" },
  { at: 750_000, label: "EPIC WIN", tone: "cyan", sound: "wizard", voice: "vo-flawless" },
  { at: 2_000_000, label: "LEGENDARY WIN", tone: "rainbow", sound: "super-jackpot", voice: "vo-multi" },
];

function useRoll(from, to, ms, onTick) {
  const [value, setValue] = useState(from);
  const [progress, setProgress] = useState(0);
  const tickRef = useRef(onTick);
  tickRef.current = onTick;
  useEffect(() => {
    let frame = 0, last = 0;
    const start = performance.now();
    const step = (now) => {
      const t = Math.min(1, (now - start) / ms);
      const v = from + (to - from) * easeOut(t);
      setValue(v);
      setProgress(t);
      if (now - last > 50 && t < 1) { last = now; tickRef.current?.(t, v); }
      if (t < 1) frame = requestAnimationFrame(step);
    };
    frame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frame);
  }, [from, to, ms]);
  return [value, progress];
}

function Row({ label, value, audio }) {
  const [v, t] = useRoll(0, value, 750, (p) => audio?.play("spinner", { gain: 0.16, rate: 1 + p * 0.8, gap: 0.045 }));
  const done = t >= 1;
  useEffect(() => { if (done) { audio?.play("bonus-step", { gain: 0.6 }); audio?.play(`coin-${1 + Math.floor(Math.random() * 5)}`, { gain: 0.6 }); } }, [done, audio]);
  return (
    <li className={done ? "done" : ""}>
      <span>{label}</span>
      <b>{fmt(v)}</b>
      {done && <i className="pbRowStamp">+</i>}
    </li>
  );
}

// Coins either rain from above or shoot up out of a fountain at the bottom.
function Coins({ count, mode = "rain", seed }) {
  const coins = useMemo(() => Array.from({ length: count }, (_, i) => ({
    key: i, x: Math.random() * 100, dx: (Math.random() - 0.5) * 900, peak: 260 + Math.random() * 420,
    d: 1 + Math.random() * 1.2, delay: Math.random() * (mode === "boom" ? 0.25 : 3), s: 14 + Math.random() * 26, r: Math.random() * 1080,
  })), [count, mode, seed]);
  return <div className={`pbCoins mode-${mode}`} aria-hidden="true">{coins.map((c) => <i key={c.key} style={{ left: `${c.x}%`, width: c.s, height: c.s, animationDuration: `${c.d}s`, animationDelay: `${c.delay}s`, "--r": `${c.r}deg`, "--dx": `${c.dx}px`, "--peak": `${-c.peak}px` }} />)}</div>;
}

function Total({ base, total, audio, quake }) {
  const [tier, setTier] = useState(-1);
  const tierRef = useRef(-1);
  const [v, t] = useRoll(base, total, 3800, (p, value) => {
    audio?.play("spinner", { gain: 0.22, rate: 1.1 + p * 1.6, gap: 0.035 });
    if (Math.random() < 0.55) audio?.play(`coin-${1 + Math.floor(Math.random() * 5)}`, { gain: 0.25 + p * 0.3, rate: 0.9 + Math.random() * 0.5, gap: 0.03 });
    const next = TIERS.reduce((n, tr, i) => (value >= tr.at ? i : n), -1);
    if (next > tierRef.current) {
      tierRef.current = next;
      setTier(next);
      audio?.play(TIERS[next].sound, { gain: 0.8 });
      audio?.voice?.(TIERS[next].voice);
      quake(1.2 + next * 0.5);
    }
  });
  const done = t >= 1;
  useEffect(() => {
    if (!done) return;
    audio?.play("super-jackpot", { gain: 0.8 });
    audio?.play("kickback", { gain: 0.7 });
    for (let i = 0; i < 12; i++) audio?.play(`coin-${1 + (i % 5)}`, { gain: 0.5, rate: 0.8 + Math.random() * 0.6, gap: 0, delay: i * 0.06 });
    quake(3);
  }, [done, audio, quake]);
  const T = tier >= 0 ? TIERS[tier] : null;
  return (
    <div className={`pbCasinoTotal${done ? " done" : ""}`} style={{ "--grow": 0.7 + easeOut(t) * 0.8, "--shake": `${1 + t * 9}px` }}>
      {T && <div key={tier} className={`pbWinTier tone-${T.tone}`} data-text={T.label}>{T.label}</div>}
      <small>{done ? "AUSZAHLUNG!" : "GESAMT-BONUS"}</small>
      <strong key={done ? "done" : "roll"}>{fmt(v)}</strong>
      {!done && <Coins count={30 + Math.max(0, tier + 1) * 14} mode="fountain" seed={tier} />}
      {done && <><Coins count={90} mode="boom" seed="boom" /><span className="pbShock" /><span className="pbShock s2" /></>}
    </div>
  );
}

export function BonusCasino({ sysRef }) {
  const [state, setState] = useState(null);
  const rootRef = useRef(null);
  const quake = useRef((strength = 1) => {
    const m = rootRef.current?.closest(".pbMachine");
    if (!m || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    m.style.setProperty("--quake", String(strength));
    m.classList.remove("pbQuake"); void m.offsetWidth; m.classList.add("pbQuake");
    setTimeout(() => m.classList.remove("pbQuake"), 520);
  }).current;
  useEffect(() => {
    const s = sysRef.current;
    const handler = (type, d = {}) => {
      if (type === "bonusStart") setState({ rows: [], bonusX: d.bonusX, phase: "rows", base: 0, total: 0, key: Date.now() });
      else if (type === "bonusStep") setState((st) => st && { ...st, rows: [...st.rows, { label: d.label, value: d.value, key: st.rows.length }], base: st.base + d.value });
      else if (type === "bonusMult") { setState((st) => st && { ...st, phase: "mult", base: d.base, bonusX: d.bonusX }); s.audio?.play("vip-lit", { gain: 0.8 }); s.audio?.play("kickback", { gain: 0.6 }); quake(1.6); }
      else if (type === "bonusTotal") setState((st) => st && { ...st, phase: "total", total: d.total, base: d.base });
      else if (["newBall", "shootAgain", "gameOver", "gameStart"].includes(type)) setState(null);
    };
    s.casino = handler;
    return () => { if (s.casino === handler) s.casino = null; };
  }, [sysRef, quake]);

  if (!state) return <span ref={rootRef} hidden />;
  const audio = sysRef.current.audio;
  return (
    <div className={`pbCasino phase-${state.phase}`} key={state.key} ref={rootRef} role="status" aria-label="Ball-Bonus">
      <span className="pbBeams" aria-hidden="true" />
      <span className="pbSpot left" aria-hidden="true" />
      <span className="pbSpot right" aria-hidden="true" />
      <span className="pbStrobe" aria-hidden="true" />
      <div className="pbCasinoPanel">
        <span className="pbBulbs" aria-hidden="true" />
        <span className="pbBulbs outer" aria-hidden="true" />
        <header><b>★</b> BALL-BONUS <b>★</b></header>
        <ul>{state.rows.map((r) => <Row key={r.key} label={r.label} value={r.value} audio={audio} />)}</ul>
        {state.phase !== "rows" && (
          <div className="pbCasinoMult">
            <span>{fmt(state.base)}</span>
            <strong>× {state.bonusX}</strong>
            <span className="pbShock small" aria-hidden="true" />
          </div>
        )}
        {state.phase === "total" && <Total base={state.base} total={state.total} audio={audio} quake={quake} />}
      </div>
    </div>
  );
}
