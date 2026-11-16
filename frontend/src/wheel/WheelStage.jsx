// Shared Bestrafungsrad stage: canvas scene + legend + result card. Used by the admin tab
// (opaque, fullscreen-capable) and by the OBS browser source /stream/wheel (transparent).
import React, { useEffect, useMemo, useRef, useState } from "react";
import { WheelScene, colorFor } from "./engine.js";
import "./wheel.css";

const pct = (x) => `${x >= 0.1 ? Math.round(x * 100) : (x * 100).toFixed(1).replace(".", ",")} %`;

export function buyersText(buyers = []) {
  return buyers.map((b) => (b.count > 1 ? `${b.username} ×${b.count}` : b.username)).join(", ");
}

export function WheelStage({ entries, spin, offset = 0, hold = false, opaque = false, audio = null, className = "", children }) {
  const box = useRef(null);
  const canvas = useRef(null);
  const scene = useRef(null);
  const audioRef = useRef(audio);
  const [u, setU] = useState(10);
  const [view, setView] = useState({ phase: opaque ? "idle" : "hidden", index: -1 });
  audioRef.current = audio;

  useEffect(() => {
    const s = new WheelScene(canvas.current, {
      opaque,
      sound: (name, data) => { const a = audioRef.current; if (a && typeof a[name] === "function") a[name](data); },
      onState: setView,
    });
    scene.current = s;
    const fit = () => { const r = box.current.getBoundingClientRect(); s.resize(r.width, r.height); setU(Math.min(r.width, r.height) / 100); };
    fit();
    const ro = typeof ResizeObserver === "function" ? new ResizeObserver(fit) : null;
    ro?.observe(box.current);
    window.addEventListener("resize", fit);
    return () => { s.dispose(); ro?.disconnect(); window.removeEventListener("resize", fit); };
  }, [opaque]);

  useEffect(() => { scene.current?.setEntries(entries); }, [entries]);
  useEffect(() => { scene.current?.setSpin(spin, offset); }, [spin, offset]);
  useEffect(() => { scene.current?.setHold(hold); }, [hold]);

  const phase = view.phase;
  const showing = phase !== "hidden";
  const result = phase === "result" && spin;
  const shown = (phase === "intro" || phase === "spin" || phase === "result" || phase === "out") && spin ? spin.entries : entries;
  const total = shown.reduce((s, e) => s + e.weight, 0);
  const legend = useMemo(() => shown.map((e, i) => ({ ...e, i, color: colorFor(i, shown.length).light })).sort((a, b) => b.weight - a.weight || a.i - b.i), [shown]);
  const winner = result ? spin.entries.find((e) => e.key === spin.winner) : null;
  const visibleLegend = legend.slice(0, 9);
  const current = phase === "spin" || phase === "intro" ? view.index : -1;
  const currentEntry = current >= 0 ? shown[current] : null;

  return (
    <div className={`wsStage ${opaque ? "wsOpaque" : "wsClear"} ${className}`} ref={box} style={{ "--u": `${u}px` }} data-phase={phase}>
      <canvas ref={canvas} className="wsCanvas" aria-hidden="true" />
      {showing && (
        <aside className={`wsSide${result ? " wsSideResult" : ""}`}>
          <div className="wsTitle"><small>🎡 Das große</small><b>BESTRAFUNGS</b><b className="wsTitleRad">RAD</b></div>
          {!result && (
            <>
              <p className="wsStats">{shown.length ? `${shown.length} ${shown.length === 1 ? "Bestrafung" : "Bestrafungen"} · ${total} ${total === 1 ? "Los" : "Lose"}` : "Noch leer – kauf im Shop eine Bestrafung!"}</p>
              <div className={`wsNow${currentEntry ? " on" : ""}`} key={current}>{currentEntry ? currentEntry.name : phase === "idle" ? "Bereit zum Drehen" : "…"}</div>
              <ol className="wsList">
                {visibleLegend.map((e) => (
                  <li key={e.key} className={e.i === current ? "hot" : ""}>
                    <i style={{ background: e.color }} />
                    <span>{e.name}</span>
                    <b>{pct(e.weight / total)}</b>
                  </li>
                ))}
                {legend.length > visibleLegend.length && <li className="more">+ {legend.length - visibleLegend.length} weitere</li>}
              </ol>
            </>
          )}
          {winner && (
            <div className="wsResult" key={spin.id}>
              <p className="wsKicker">Das Rad hat entschieden</p>
              <h2 className="wsWinner">{winner.name}</h2>
              <p className="wsBuyers">gekauft von <b>{buyersText(winner.buyers)}</b></p>
              <p className="wsChance">Chance war {pct(winner.weight / total)} · {winner.weight} {winner.weight === 1 ? "Los" : "Lose"}</p>
            </div>
          )}
        </aside>
      )}
      {result && phase === "result" && <div className="wsStamp" key={`stamp-${spin.id}`}>😈 BESTRAFUNG! 😈</div>}
      {children}
    </div>
  );
}
