import React, { useEffect, useMemo, useRef, useState } from "react";
import { Award, Check, Coins, Flame, Gift, Lock, MapPin, Star, Ticket } from "lucide-react";
import { LOOKS, drawHorse } from "../horses/horse.js";

const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");

// Animated preview of the level-25 Derby skin (galloping Phönix-Hengst).
export function PhoenixPreview({ size = 220, still = false }) {
  const ref = useRef(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return undefined;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = size, h = Math.round(size * 0.8);
    canvas.width = w * dpr; canvas.height = h * dpr;
    const c = canvas.getContext("2d");
    const calm = still || matchMedia("(prefers-reduced-motion: reduce)").matches;
    let raf = 0, phase = 0, last = performance.now();
    const draw = (now) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      phase = (phase + dt * 2.3) % 1;
      c.setTransform(dpr, 0, 0, dpr, 0, 0);
      c.clearRect(0, 0, w, h);
      const k = size / 165;
      c.translate(w * 0.52, h * 0.9); c.scale(k, k);
      drawHorse(c, { look: LOOKS[1], number: 25, phase, gait: calm ? 0.3 : 1, time: now / 1000, skin: "phoenix" });
      if (!calm) raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [size, still]);
  return <canvas ref={ref} className="phoenixPreview" style={{ width: size, height: Math.round(size * 0.8) }} role="img" aria-label="Vorschau: Phönix-Hengst mit Feuermähne und Flammenflügeln" />;
}

function nodeKind(node, unlocks) {
  if (node.unlocks.some((id) => unlocks[id]?.skin)) return "skin";
  if (node.unlocks.length) return "unlock";
  if (node.title) return "title";
  if (node.level % 5 === 0) return "milestone";
  return "plain";
}

// Level tree from 1 to 100: every level as a node; titles, unlocks and milestones stand out.
// Pick a node to see what it brings and how much XP is still missing.
export function LevelTree({ info }) {
  const unlocks = useMemo(() => Object.fromEntries((info.unlock_list || []).map((u) => [u.id, u])), [info.unlock_list]);
  const tree = info.tree || [];
  const firstSpecial = tree.find((n) => n.level > info.level && n.unlocks.length)?.level;
  const [selected, setSelected] = useState(() => Math.min(100, info.level + 1));
  const [onlyHighlights, setOnlyHighlights] = useState(false);
  if (!tree.length) return null;
  const node = tree[selected - 1] || tree[0];
  const missing = Math.max(0, node.xp - info.xp);
  const phoenix = tree.find((n) => n.unlocks.includes("derby-phoenix"));
  const shown = onlyHighlights ? tree.filter((n) => nodeKind(n, unlocks) !== "plain") : tree;

  return (
    <div className="levelTree">
      <div className="levelTreeHead">
        <h4><MapPin size={16} /> Level-Baum 1–100</h4>
        <div className="levelTreeTools">
          <span className="ltLegend"><i className="done" /> erreicht <i className="now" /> du <i className="locked" /> offen</span>
          <button type="button" className="ltFilter" aria-pressed={onlyHighlights} onClick={() => setOnlyHighlights(!onlyHighlights)}>{onlyHighlights ? "Alle Level" : "Nur Highlights"}</button>
        </div>
      </div>

      {phoenix && (
        <button type="button" className={`ltShowcase${info.level >= phoenix.level ? " owned" : ""}`} onClick={() => setSelected(phoenix.level)}>
          <PhoenixPreview size={170} />
          <span>
            <small><Flame size={14} /> LEVEL {phoenix.level} · DERBY-SKIN</small>
            <b>{unlocks["derby-phoenix"]?.name || "Phönix-Hengst"}</b>
            <em>{info.level >= phoenix.level ? "Freigeschaltet! Dein Pferd im Chicken Derby brennt." : `Noch ${fmt(phoenix.xp - info.xp)} XP – dann trägt dein Derby-Pferd Feuermähne und Flammenflügel.`}</em>
          </span>
        </button>
      )}

      <ol className="ltGrid" aria-label="Level 1 bis 100">
        {shown.map((n) => {
          const kind = nodeKind(n, unlocks);
          const state = n.level < info.level ? "done" : n.level === info.level ? "now" : "locked";
          return (
            <li key={n.level}>
              <button type="button" className={`ltNode ${kind} ${state}${selected === n.level ? " sel" : ""}`} onClick={() => setSelected(n.level)} aria-pressed={selected === n.level}
                aria-label={`Level ${n.level}${n.title ? `, Titel ${n.title}` : ""}${n.unlocks.length ? `, ${n.unlocks.map((id) => unlocks[id]?.name).join(", ")}` : ""}${state === "done" ? ", erreicht" : state === "now" ? ", dein Level" : ""}`}>
                {kind === "skin" ? <Flame size={15} /> : kind === "unlock" ? <Gift size={13} /> : kind === "title" ? <Star size={12} /> : null}
                <b>{n.level}</b>
              </button>
            </li>
          );
        })}
      </ol>

      <div className={`ltDetail ${nodeKind(node, unlocks)}`} aria-live="polite">
        <div className="ltDetailHead">
          <span className="ltDetailLv">LV {node.level}</span>
          <div>
            <b>{node.title ? `Titel: ${node.title}` : node.level === 1 ? "Start" : node.level % 5 === 0 ? "Meilenstein" : `Level ${node.level}`}</b>
            <small>
              {node.level <= info.level ? <><Check size={13} /> Erreicht</> : <><Lock size={13} /> ab {fmt(node.xp)} XP gesamt · noch {fmt(missing)} XP</>}
            </small>
          </div>
        </div>
        <div className="ltRewards">
          {node.rewards ? <>
            <span><Coins size={15} /> +{fmt(node.rewards.chickens)} Chickens</span>
            <span><Ticket size={15} /> +{fmt(node.rewards.credits)} Credits</span>
          </> : <span>Hier fängt alles an.</span>}
          {node.title && <span className="title"><Award size={15} /> Titel „{node.title}“</span>}
          {node.level % 5 === 0 && <span className="alert">Stream-Alert</span>}
        </div>
        {node.unlocks.map((id) => {
          const u = unlocks[id];
          if (!u) return null;
          return (
            <div key={id} className={`ltUnlock${u.skin ? " skin" : ""}`}>
              {u.skin && <PhoenixPreview size={190} />}
              <span><b>{u.skin ? <Flame size={15} /> : <Gift size={15} />} {u.name}</b><small>{u.text}</small></span>
            </div>
          );
        })}
        {!node.unlocks.length && firstSpecial && node.level < firstSpecial && (
          <p className="ltHint">Nächste Freischaltung: Level {firstSpecial} – {tree[firstSpecial - 1].unlocks.map((id) => unlocks[id]?.name).join(" & ")}</p>
        )}
      </div>
    </div>
  );
}
