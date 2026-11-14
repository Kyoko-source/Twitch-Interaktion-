import React, { useEffect, useMemo, useRef, useState } from "react";
import "./casino.css";

// End-of-ball bonus as a casino payout: marquee bulbs, every line rolls up, the multiplier
// slams in, then the grand total rolls up while it keeps getting bigger, shakier and golder.
const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const easeOut = (t) => 1 - Math.pow(1 - t, 3);

function useRoll(from, to, ms, active, onTick) {
  const [value, setValue] = useState(from);
  const [progress, setProgress] = useState(0);
  const tickRef = useRef(onTick);
  tickRef.current = onTick;
  useEffect(() => {
    if (!active) return undefined;
    let frame = 0, last = 0;
    const start = performance.now();
    const step = (now) => {
      const t = Math.min(1, (now - start) / ms);
      setValue(from + (to - from) * easeOut(t));
      setProgress(t);
      if (now - last > 55 && t < 1) { last = now; tickRef.current?.(t); }
      if (t < 1) frame = requestAnimationFrame(step);
    };
    frame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frame);
  }, [from, to, ms, active]);
  return [value, progress];
}

function Row({ label, value, audio }) {
  const [v, t] = useRoll(0, value, 750, true, (p) => audio?.play("spinner", { gain: 0.16, rate: 1 + p * 0.8, gap: 0.045 }));
  return (
    <li className={t >= 1 ? "done" : ""}>
      <span>{label}</span>
      <b>{fmt(v)}</b>
    </li>
  );
}

function Coins({ count = 46 }) {
  const coins = useMemo(() => Array.from({ length: count }, (_, i) => ({ key: i, x: Math.random() * 100, d: 0.9 + Math.random() * 1.3, delay: Math.random() * 1.6, s: 16 + Math.random() * 22, r: Math.random() * 720 })), [count]);
  return <div className="pbCoins" aria-hidden="true">{coins.map((c) => <i key={c.key} style={{ left: `${c.x}%`, width: c.s, height: c.s, animationDuration: `${c.d}s`, animationDelay: `${c.delay}s`, "--r": `${c.r}deg` }} />)}</div>;
}

function Total({ base, total, audio }) {
  const [v, t] = useRoll(base, total, 2300, true, (p) => audio?.play("spinner", { gain: 0.2, rate: 1.1 + p * 1.4, gap: 0.04 }));
  const done = t >= 1;
  useEffect(() => { if (done) { audio?.play("super-jackpot", { gain: 0.7 }); audio?.play("kickback", { gain: 0.6 }); } }, [done, audio]);
  return (
    <div className={`pbCasinoTotal${done ? " done" : ""}`} style={{ "--grow": 0.7 + easeOut(t) * 0.75, "--shake": `${1 + t * 7}px` }}>
      <small>GESAMT-BONUS</small>
      <strong>{fmt(v)}</strong>
      {done && <Coins />}
    </div>
  );
}

export function BonusCasino({ sysRef }) {
  const [state, setState] = useState(null);
  useEffect(() => {
    const s = sysRef.current;
    const handler = (type, d = {}) => {
      if (type === "bonusStart") setState({ rows: [], bonusX: d.bonusX, phase: "rows", base: 0, total: 0, key: Date.now() });
      else if (type === "bonusStep") setState((st) => st && { ...st, rows: [...st.rows, { label: d.label, value: d.value, key: st.rows.length }], base: st.base + d.value });
      else if (type === "bonusMult") { setState((st) => st && { ...st, phase: "mult", base: d.base, bonusX: d.bonusX }); s.audio?.play("vip-lit", { gain: 0.8 }); s.audio?.play("kickback", { gain: 0.5 }); }
      else if (type === "bonusTotal") setState((st) => st && { ...st, phase: "total", total: d.total, base: d.base });
      else if (["newBall", "shootAgain", "gameOver", "gameStart"].includes(type)) setState(null);
    };
    s.casino = handler;
    return () => { if (s.casino === handler) s.casino = null; };
  }, [sysRef]);

  if (!state) return null;
  const audio = sysRef.current.audio;
  return (
    <div className={`pbCasino phase-${state.phase}`} key={state.key} role="status" aria-label="Ball-Bonus">
      <div className="pbCasinoPanel">
        <span className="pbBulbs" aria-hidden="true" />
        <header><b>★</b> BALL-BONUS <b>★</b></header>
        <ul>{state.rows.map((r) => <Row key={r.key} label={r.label} value={r.value} audio={audio} />)}</ul>
        {state.phase !== "rows" && (
          <div className="pbCasinoMult">
            <span>{fmt(state.base)}</span>
            <strong>× {state.bonusX}</strong>
          </div>
        )}
        {state.phase === "total" && <Total base={state.base} total={state.total} audio={audio} />}
      </div>
    </div>
  );
}
