import React, { useEffect, useRef, useState } from "react";
import { EyeOff, Skull } from "lucide-react";
import { MonsterArt, hasArt } from "./MonsterArt";

const initials = (name) => String(name || "?").split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();

export function hpPercent(e) {
  if (typeof e.hp_pct === "number") return e.hp_pct;
  return Math.round((Math.max(0, e.hp) / Math.max(1, e.max_hp)) * 100);
}

export function hpTone(pct) {
  return pct > 60 ? "good" : pct > 30 ? "warn" : pct > 0 ? "bad" : "down";
}

// Grid battle map with draggable tokens. Players drag their own hero, the
// DM drags everything; moves snap to cells and are sent as one action.
export function BattleMap({ view, selected, onSelect, act, canControl }) {
  const wrap = useRef(null);
  const [cell, setCell] = useState(40);
  const [drag, setDrag] = useState(null);
  const [fx, setFx] = useState([]);
  const lastHp = useRef(null);
  const { cols, rows, theme, image_url: image } = view.map;
  const current = view.initiative.order[view.initiative.turn]?.ref;

  useEffect(() => {
    const el = wrap.current;
    if (!el) return undefined;
    const measure = () => setCell(Math.max(26, Math.min(64, Math.floor(el.clientWidth / cols))));
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(el);
    return () => observer.disconnect();
  }, [cols]);

  const tokens = [
    ...Object.values(view.characters).map((c) => ({ ...c, ref: `c:${c.id}`, kind: "hero", size: 1 })),
    ...Object.values(view.creatures).map((c) => ({ ...c, ref: `m:${c.id}`, kind: "monster" })),
  ];

  // Compare HP with the previous poll and spawn floating numbers.
  const hpKey = tokens.map((t) => `${t.ref}:${t.hp ?? ""}:${hpPercent(t)}`).join("|");
  useEffect(() => {
    const now = Object.fromEntries(tokens.map((t) => [t.ref, { hp: t.hp, pct: hpPercent(t) }]));
    const before = lastHp.current;
    lastHp.current = now;
    if (!before) return;
    const fresh = [];
    for (const [ref, cur] of Object.entries(now)) {
      const old = before[ref];
      if (!old) continue;
      const delta = cur.hp != null && old.hp != null ? cur.hp - old.hp : null;
      const dir = delta != null ? Math.sign(delta) : Math.sign(cur.pct - old.pct);
      if (!dir) continue;
      fresh.push({ id: `${ref}-${Date.now()}-${Math.random()}`, ref, kind: dir < 0 ? "dmg" : "heal", text: delta != null ? `${delta > 0 ? "+" : ""}${delta}` : dir < 0 ? "Treffer!" : "Heilung", ko: cur.pct <= 0 && old.pct > 0 });
    }
    if (!fresh.length) return;
    setFx((list) => [...list, ...fresh]);
    setTimeout(() => setFx((list) => list.filter((f) => !fresh.includes(f))), 1500);
  }, [hpKey]);

  function cellFromEvent(event) {
    const box = wrap.current.querySelector(".battleGrid").getBoundingClientRect();
    return { x: Math.floor((event.clientX - box.left) / cell), y: Math.floor((event.clientY - box.top) / cell) };
  }

  function startDrag(event, token) {
    onSelect(token.ref);
    if (!canControl(token.ref)) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    setDrag({ ref: token.ref, x: token.x, y: token.y, moved: false });
  }
  function move(event) {
    if (!drag) return;
    const pos = cellFromEvent(event);
    const size = tokens.find((t) => t.ref === drag.ref)?.size || 1;
    const x = Math.max(0, Math.min(cols - size, pos.x));
    const y = Math.max(0, Math.min(rows - size, pos.y));
    if (x !== drag.x || y !== drag.y) setDrag({ ...drag, x, y, moved: true });
  }
  function up() {
    if (drag?.moved) act({ type: "token.move", ref: drag.ref, x: drag.x, y: drag.y }).catch(() => {});
    setDrag(null);
  }

  return <div className="battleWrap" ref={wrap} data-tip="map">
    <div className={`battleGrid mapTheme-${theme}`} style={{ width: cols * cell, height: rows * cell, "--cell": `${cell}px`, backgroundImage: image ? `url("${image}")` : undefined }}
      onPointerMove={move} onPointerUp={up} onPointerCancel={() => setDrag(null)} onClick={(e) => { if (e.target === e.currentTarget) onSelect(null); }}>
      <div className="battleGridLines" />
      {tokens.map((t) => {
        const pos = drag?.ref === t.ref ? drag : t;
        const size = t.size || 1;
        const pct = hpPercent(t);
        const isDown = pct <= 0;
        const hits = fx.filter((f) => f.ref === t.ref);
        const art = t.kind === "monster" && (t.image_url || hasArt(t.art));
        return <button key={t.ref} type="button" data-tip="token"
          className={`token token-${t.kind} ${selected === t.ref ? "isSelected" : ""} ${current === t.ref ? "isTurn" : ""} ${isDown ? "isDown" : ""} ${drag?.ref === t.ref ? "isDragging" : ""} ${t.visible === false ? "isHidden" : ""} ${hits.some((f) => f.kind === "dmg") ? "isHit" : ""} ${hits.some((f) => f.kind === "heal") ? "isHealed" : ""} ${hits.some((f) => f.ko) ? "isKo" : ""}`}
          style={{ left: pos.x * cell, top: pos.y * cell, width: size * cell, height: size * cell, "--tok": t.color }}
          onPointerDown={(e) => startDrag(e, t)} title={t.name} aria-label={`${t.name}${t.health ? `, ${t.health}` : t.hp != null ? `, ${t.hp} von ${t.max_hp} TP` : ""}`}>
          <span className="tokenSummon" aria-hidden="true" />
          <span className="tokenFace">{t.avatar_url ? <img src={t.avatar_url} alt="" draggable="false" /> : art ? <MonsterArt art={t.art} image={t.image_url} color={t.color} name={t.name} /> : isDown && t.kind === "monster" ? <Skull size={size * cell * .42} /> : initials(t.name)}</span>
          {isDown && art && <Skull className="tokenSkull" size={Math.max(14, size * cell * .34)} />}
          {hits.map((f) => <span key={f.id} className={`hpFloat ${f.kind}`} aria-hidden="true">{f.ko ? "K.O.!" : f.text}</span>)}
          <span className={`tokenHp ${hpTone(pct)}`}><span style={{ width: `${pct}%` }} /></span>
          {t.conditions?.length > 0 && <span className="tokenConds">{t.conditions.length}</span>}
          {t.visible === false && <EyeOff className="tokenHiddenIcon" size={14} />}
          {size * cell >= 36 && <span className="tokenName">{t.name}</span>}
        </button>;
      })}
    </div>
  </div>;
}
