import React, { useEffect, useRef, useState } from "react";
import { EyeOff, Skull } from "lucide-react";

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

  return <div className="battleWrap" ref={wrap}>
    <div className={`battleGrid mapTheme-${theme}`} style={{ width: cols * cell, height: rows * cell, "--cell": `${cell}px`, backgroundImage: image ? `url("${image}")` : undefined }}
      onPointerMove={move} onPointerUp={up} onPointerCancel={() => setDrag(null)} onClick={(e) => { if (e.target === e.currentTarget) onSelect(null); }}>
      <div className="battleGridLines" />
      {tokens.map((t) => {
        const pos = drag?.ref === t.ref ? drag : t;
        const size = t.size || 1;
        const pct = hpPercent(t);
        const isDown = pct <= 0;
        return <button key={t.ref} type="button"
          className={`token token-${t.kind} ${selected === t.ref ? "isSelected" : ""} ${current === t.ref ? "isTurn" : ""} ${isDown ? "isDown" : ""} ${drag?.ref === t.ref ? "isDragging" : ""} ${t.visible === false ? "isHidden" : ""}`}
          style={{ left: pos.x * cell, top: pos.y * cell, width: size * cell, height: size * cell, "--tok": t.color }}
          onPointerDown={(e) => startDrag(e, t)} title={t.name} aria-label={`${t.name}${t.health ? `, ${t.health}` : t.hp != null ? `, ${t.hp} von ${t.max_hp} TP` : ""}`}>
          <span className="tokenFace">{t.avatar_url ? <img src={t.avatar_url} alt="" draggable="false" /> : isDown && t.kind === "monster" ? <Skull size={size * cell * .42} /> : initials(t.name)}</span>
          <span className={`tokenHp ${hpTone(pct)}`}><span style={{ width: `${pct}%` }} /></span>
          {t.conditions?.length > 0 && <span className="tokenConds">{t.conditions.length}</span>}
          {t.visible === false && <EyeOff className="tokenHiddenIcon" size={14} />}
          {size * cell >= 36 && <span className="tokenName">{t.name}</span>}
        </button>;
      })}
    </div>
  </div>;
}
