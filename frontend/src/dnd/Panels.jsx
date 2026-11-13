import React, { useEffect, useMemo, useRef, useState } from "react";
import { Crown, Eye, EyeOff, Lock, LockOpen, Megaphone, Plus, RotateCcw, Send, SkipForward, Swords, Trash2, UserX } from "lucide-react";
import { DieIcon } from "./DieIcon";
import { ART_CHOICES, CONDITIONS, DICE, MAP_THEMES, MONSTERS, monsterFor, signed } from "./rules";
import { MonsterArt } from "./MonsterArt";
import { CONDITION_INFO } from "./Guide";
import { HpQuick } from "./CharacterSheet";
import { hpPercent, hpTone } from "./BattleMap";

// ---------------------------------------------------------------- dice tray
export function DicePanel({ roll, isDm, mode, setMode }) {
  const [pool, setPool] = useState({});
  const [bonus, setBonus] = useState(0);
  const [label, setLabel] = useState("");
  const [hidden, setHidden] = useState(false);
  const [formula, setFormula] = useState("");
  const built = useMemo(() => {
    const dice = DICE.filter((d) => pool[d]).map((d) => `${pool[d]}d${d}`).join("+");
    return dice ? `${dice}${bonus ? signed(Number(bonus)) : ""}` : "";
  }, [pool, bonus]);
  useEffect(() => setFormula(built), [built]);
  const add = (d) => setPool((p) => ({ ...p, [d]: Math.min(20, (p[d] || 0) + 1) }));
  async function go(expr = formula) {
    if (!expr) return;
    await roll(expr, label, undefined, { secret: hidden && isDm, private: hidden && !isDm });
    setPool({}); setBonus(0); setLabel("");
  }
  return <div className="dicePanel">
    <div className="diceRack" data-tip="dice-rack">{DICE.map((d) => <button type="button" key={d} className="dieButton" onClick={() => add(d)} onDoubleClick={() => go(`1d${d}`)} title={`W${d} hinzufügen (Doppelklick: sofort würfeln)`}>
      <DieIcon sides={d} size={46} />{pool[d] ? <em>{pool[d]}×</em> : null}</button>)}</div>
    <div className="diceBuild">
      <label data-tip="dice-formula">Formel<input value={formula} onChange={(e) => setFormula(e.target.value)} placeholder="z. B. 1d20+5 oder 2d6+3" /></label>
      <label className="diceBonus" data-tip="dice-bonus">Bonus<input type="number" value={bonus} onChange={(e) => setBonus(e.target.value)} /></label>
    </div>
    <label data-tip="dice-label">Wofür?<input value={label} maxLength={60} onChange={(e) => setLabel(e.target.value)} placeholder="Angriff, Schaden, Rettungswurf …" /></label>
    <div className="segmented diceMode" data-tip="dice-mode">
      {[["normal", "Normal"], ["adv", "Vorteil"], ["dis", "Nachteil"]].map(([id, name]) => <button type="button" key={id} className={mode === id ? "active" : ""} onClick={() => setMode(id)}>{name}</button>)}
    </div>
    <label className="checkRow" data-tip="dice-hidden"><input type="checkbox" checked={hidden} onChange={(e) => setHidden(e.target.checked)} />{isDm ? "Verdeckt würfeln (nur du siehst es)" : "Privat (nur du und der DM)"}</label>
    <div className="diceGo">
      <button type="button" className="ghost" data-tip="dice-clear" onClick={() => { setPool({}); setBonus(0); }}><RotateCcw size={16} />Leeren</button>
      <button type="button" className="rollButton" data-tip="dice-roll" disabled={!formula} onClick={() => go()}><DieIcon sides={20} size={22} label={false} />Würfeln</button>
    </div>
    <p className="diceTip">Vorteil und Nachteil gelten für den ersten W20. Klicks auf Werte im Charakterbogen würfeln direkt.</p>
  </div>;
}

// ---------------------------------------------------------------- combat
export function CombatPanel({ view, isDm, act, nameOf, onSelect }) {
  const { order, turn, round } = view.initiative;
  return <div className="combatPanel">
    <header><Swords size={18} /><strong>{round ? `Runde ${round}` : "Kein Kampf"}</strong>
      {isDm && <span className="combatDm">
        <button type="button" data-tip="combat-start" onClick={() => act({ type: "initiative.roll" })}><Swords size={16} />{round ? "Neu würfeln" : "Kampf starten"}</button>
        {round > 0 && <button type="button" className="ghost" data-tip="combat-next" onClick={() => act({ type: "turn.next" })}><SkipForward size={16} />Nächster</button>}
        {round > 0 && <button type="button" className="ghost" data-tip="combat-end" onClick={() => act({ type: "initiative.clear" })}>Beenden</button>}
      </span>}
    </header>
    {!order.length && <p className="dimText">{isDm ? "„Kampf starten“ würfelt Initiative für alle Helden und sichtbaren Kreaturen." : "Der Dungeon Master startet den Kampf."}</p>}
    <ol className="initList" data-tip="combat-list">{order.map((o, i) => {
      const ent = o.ref.startsWith("c:") ? view.characters[o.ref.slice(2)] : view.creatures[o.ref.slice(2)];
      if (!ent) return null;
      const pct = hpPercent(ent);
      return <li key={o.ref} className={`${i === turn && round ? "isTurn" : ""} ${pct <= 0 ? "isDown" : ""}`} style={{ "--tok": ent.color }} onClick={() => onSelect(o.ref)}>
        <span className="initValue">{o.value}</span>
        {o.ref.startsWith("m:") && <MonsterArt className="initArt" art={ent.art} image={ent.image_url} color={ent.color} name={ent.name} />}
        <span className="initName"><strong>{nameOf(o.ref)}</strong><span className={`hpBar ${hpTone(pct)}`}><span style={{ width: `${pct}%` }} /></span></span>
        {isDm && <input type="number" defaultValue={o.value} aria-label="Initiative ändern" onClick={(e) => e.stopPropagation()} onBlur={(e) => Number(e.target.value) !== o.value && act({ type: "initiative.set", ref: o.ref, value: Number(e.target.value) })} />}
      </li>;
    })}</ol>
  </div>;
}

// ---------------------------------------------------------------- selection card
export function SelectedCard({ view, refId, canControl, act, isDm, roll, onClose }) {
  if (!refId) return null;
  const isHero = refId.startsWith("c:");
  const ent = isHero ? view.characters[refId.slice(2)] : view.creatures[refId.slice(2)];
  if (!ent) return null;
  const pct = hpPercent(ent);
  const control = canControl(refId);
  const info = isHero ? null : monsterFor(ent);
  const sub = isHero ? `${ent.char_class} · ${ent.owner}` : [info?.type, info ? `HG ${info.cr}` : "", ent.health || `RK ${ent.ac}`].filter(Boolean).join(" · ");
  return <div className={`selectedCard ${isHero ? "" : "isMonster"}`} style={{ "--tok": ent.color }} data-tip="sel-card" key={refId}>
    {!isHero && <MonsterArt className="selArt" art={ent.art} image={ent.image_url} color={ent.color} name={ent.name} />}
    <div className="selMain">
      <header><span className="selDot" /><strong>{ent.name}</strong><small>{sub}</small><button type="button" className="quietIcon" onClick={onClose} aria-label="Auswahl schließen">×</button></header>
      {info && <p className="selLore">{info.lore}</p>}
      <div className="selHp">
        <span className={`hpBar big ${hpTone(pct)}`}><span style={{ width: `${pct}%` }} /></span>
        <b>{ent.hp != null ? `${ent.hp} / ${ent.max_hp} TP` : ent.health}</b>
      </div>
      {control && <span className="selHpQuick" data-tip="sel-hp"><HpQuick onHp={(delta) => act({ type: "hp.change", ref: refId, delta })} /></span>}
      {isDm && info && <div className="selAttacks" data-tip="sel-attacks">{info.attacks.map((a) => <span key={a.name} className="attackRow">
        {a.save ? <button type="button" className="ghost" onClick={() => roll("1d20", `${a.name} (${a.save})`, ent.name)} title="Würfelt einen W20, z. B. für den Rettungswurf eines Helden">{a.name} · {a.save}</button>
          : <button type="button" className="ghost" onClick={() => roll(`1d20${signed(a.hit)}`, `${a.name}: Angriff`, ent.name)}><Swords size={14} />{a.name} {signed(a.hit)}</button>}
        {a.dmg && <button type="button" className="ghost dmgRoll" onClick={() => roll(a.dmg, `${a.name}: Schaden`, ent.name)}>{a.dmg}</button>}
        {a.note && <small>{a.note}</small>}
      </span>)}</div>}
      <div className="condList" data-tip="sel-conds">{(control ? CONDITIONS : ent.conditions || []).map((c) => <button type="button" key={c} disabled={!control} title={CONDITION_INFO[c]}
        className={ent.conditions?.includes(c) ? "active" : ""} onClick={() => act({ type: "condition.toggle", ref: refId, condition: c })}>{c}</button>)}
        {!control && !ent.conditions?.length && <span className="dimText">Keine Zustände</span>}</div>
      {isDm && !isHero && <div className="selDm" data-tip="sel-dm">
        <button type="button" className="ghost" onClick={() => act({ type: "creature.update", id: ent.id, fields: { visible: !ent.visible } })}>{ent.visible ? <><EyeOff size={15} />Verstecken</> : <><Eye size={15} />Aufdecken</>}</button>
        <button type="button" className="ghost" onClick={() => act({ type: "creature.update", id: ent.id, fields: { hidden_hp: !ent.hidden_hp } })}>{ent.hidden_hp ? "TP zeigen" : "TP verbergen"}</button>
        <select value={ent.art || ""} aria-label="Porträt ändern" onChange={(e) => act({ type: "creature.update", id: ent.id, fields: { art: e.target.value } })}>
          <option value="">Ohne Porträt</option>{ART_CHOICES.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select>
        <button type="button" className="ghost danger" onClick={() => { act({ type: "creature.remove", id: ent.id }); onClose(); }}><Trash2 size={15} />Entfernen</button>
      </div>}
    </div>
  </div>;
}

// ---------------------------------------------------------------- creatures (DM)
export function CreaturePanel({ view, act, onSelect }) {
  const [form, setForm] = useState({ name: "", max_hp: 10, ac: 12, init_bonus: 0, count: 1, color: "#ff4f6d", size: 1, hidden_hp: true, visible: true, art: "shadow", image_url: "" });
  const imageOk = !form.image_url || /^https:\/\//.test(form.image_url);
  const set = (patch) => setForm((f) => ({ ...f, ...patch }));
  const add = (data) => act({ type: "creature.add", ...data });
  const creatures = Object.values(view.creatures);
  return <div className="creaturePanel">
    <h4>Bestiarium <small>{form.count > 1 ? `je ${form.count}× (Anzahl unten)` : "Klick beschwört"}</small></h4>
    <div className="monsterGrid" data-tip="cr-bestiary">{MONSTERS.map((m) => <button type="button" key={m.name} style={{ "--tok": m.color }} title={m.lore} onClick={() => add({ name: m.name, max_hp: m.max_hp, ac: m.ac, init_bonus: m.init_bonus, color: m.color, size: m.size || 1, count: form.count, hidden_hp: form.hidden_hp, visible: form.visible, art: m.art })}>
      <MonsterArt art={m.art} color={m.color} name={m.name} /><strong>{m.name}</strong><small>TP {m.max_hp} · RK {m.ac} · HG {m.cr}</small></button>)}</div>
    <h4>Eigene Kreatur</h4>
    <div className="creatureForm" data-tip="cr-custom">
      <div className="creaturePreview wide"><MonsterArt art={form.art} image={imageOk ? form.image_url : ""} color={form.color} name={form.name || "?"} />
        <label data-tip="cr-art">Porträt<select value={form.art} onChange={(e) => set({ art: e.target.value })}><option value="">Nur Initialen</option>{ART_CHOICES.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></label></div>
      <label className="wide">Name<input value={form.name} maxLength={40} onChange={(e) => set({ name: e.target.value })} placeholder="z. B. Schattenwolf" /></label>
      <label>TP<input type="number" min="1" value={form.max_hp} onChange={(e) => set({ max_hp: Number(e.target.value) })} /></label>
      <label>RK<input type="number" min="1" value={form.ac} onChange={(e) => set({ ac: Number(e.target.value) })} /></label>
      <label>Init<input type="number" value={form.init_bonus} onChange={(e) => set({ init_bonus: Number(e.target.value) })} /></label>
      <label>Anzahl<input type="number" min="1" max="12" value={form.count} onChange={(e) => set({ count: Math.max(1, Math.min(12, Number(e.target.value) || 1)) })} /></label>
      <label>Größe<select value={form.size} onChange={(e) => set({ size: Number(e.target.value) })}><option value={1}>Mittel</option><option value={2}>Groß</option><option value={3}>Riesig</option><option value={4}>Gigantisch</option></select></label>
      <label>Farbe<input type="color" value={form.color} onChange={(e) => set({ color: e.target.value })} /></label>
      <label className="wide" data-tip="cr-image">Eigenes Bild (https-Link, optional)<input value={form.image_url} maxLength={500} onChange={(e) => set({ image_url: e.target.value.trim() })} placeholder="https://…/monster.png" /></label>
      <label className="checkRow wide" data-tip="cr-hidehp"><input type="checkbox" checked={form.hidden_hp} onChange={(e) => set({ hidden_hp: e.target.checked })} />TP vor Spielern verbergen</label>
      <label className="checkRow wide" data-tip="cr-ambush"><input type="checkbox" checked={!form.visible} onChange={(e) => set({ visible: !e.target.checked })} />Versteckt platzieren (Hinterhalt)</label>
      <button type="button" className="wide" data-tip="cr-summon" disabled={!form.name.trim() || !imageOk} onClick={() => add({ ...form, name: form.name.trim() })}><Plus size={16} />Beschwören</button>
    </div>
    <h4>Auf dem Feld ({creatures.length})</h4>
    {!creatures.length && <p className="dimText">Noch keine Kreaturen. Klick oben auf ein Monster.</p>}
    <ul className="creatureList" data-tip="cr-list">{creatures.map((c) => {
      const pct = hpPercent(c);
      return <li key={c.id} style={{ "--tok": c.color }} onClick={() => onSelect(`m:${c.id}`)}>
        <MonsterArt className="listArt" art={c.art} image={c.image_url} color={c.color} name={c.name} /><span className="cName"><strong>{c.name}</strong><small>{c.hp} / {c.max_hp} TP · RK {c.ac}{!c.visible ? " · versteckt" : ""}</small>
          <span className={`hpBar ${hpTone(pct)}`}><span style={{ width: `${pct}%` }} /></span></span>
        <span onClick={(e) => e.stopPropagation()}><HpQuick onHp={(delta) => act({ type: "hp.change", ref: `m:${c.id}`, delta })} /></span>
      </li>;
    })}</ul>
  </div>;
}

// ---------------------------------------------------------------- table settings (DM)
export function TablePanel({ view, act, onLeave }) {
  const [scene, setScene] = useState(view.scene);
  const [map, setMap] = useState(view.map);
  useEffect(() => setMap(view.map), [view.map.cols, view.map.rows, view.map.theme, view.map.image_url]);
  return <div className="tablePanel">
    <div className="tpBlock" data-tip="tp-scene"><h4><Megaphone size={16} />Szene ansagen</h4>
    <label>Titel<input value={scene.title} maxLength={80} onChange={(e) => setScene({ ...scene, title: e.target.value })} /></label>
    <label>Erzähltext<textarea rows={4} value={scene.text} maxLength={2000} onChange={(e) => setScene({ ...scene, text: e.target.value })} placeholder="Ihr betretet eine feuchte Gruft …" /></label>
    <button type="button" onClick={() => act({ type: "scene.set", ...scene })}><Megaphone size={16} />Allen vorlesen</button></div>
    <h4>Karte</h4>
    <div className="mapForm" data-tip="tp-map">
      <label>Spalten<input type="number" min="8" max="40" value={map.cols} onChange={(e) => setMap({ ...map, cols: Number(e.target.value) })} /></label>
      <label>Zeilen<input type="number" min="6" max="30" value={map.rows} onChange={(e) => setMap({ ...map, rows: Number(e.target.value) })} /></label>
      <label>Thema<select value={map.theme} onChange={(e) => setMap({ ...map, theme: e.target.value })}>{MAP_THEMES.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}</select></label>
      <label className="wide">Kartenbild (https-Link, optional)<input value={map.image_url} onChange={(e) => setMap({ ...map, image_url: e.target.value })} placeholder="https://…/karte.jpg" /></label>
      <button type="button" className="wide" onClick={() => act({ type: "map.set", ...map })}>Karte übernehmen</button>
    </div>
    <h4>Tisch</h4>
    <button type="button" className="ghost" data-tip="tp-lock" onClick={() => act({ type: "room.update", locked: !view.locked })}>{view.locked ? <><LockOpen size={16} />Tisch öffnen</> : <><Lock size={16} />Tisch schließen (keine Neuen)</>}</button>
    <ul className="memberList" data-tip="tp-members">{Object.entries(view.members).map(([name, m]) => <li key={name}>
      {m.role === "dm" ? <Crown size={15} /> : null}<strong>{name}</strong><small>{m.role === "dm" ? "Dungeon Master" : m.role === "player" ? "Spieler" : "Zuschauer"}</small>
      {m.role !== "dm" && <button type="button" className="quietIcon" title="Vom Tisch entfernen" onClick={() => act({ type: "member.kick", username: name })}><UserX size={16} /></button>}
    </li>)}</ul>
    <button type="button" className="ghost danger" data-tip="tp-dissolve" onClick={() => { if (window.confirm("Tisch endgültig auflösen? Alle Charaktere und Kreaturen gehen verloren.")) onLeave(); }}><Trash2 size={16} />Tisch auflösen</button>
  </div>;
}

// ---------------------------------------------------------------- log & chat
export function TableLog({ view, say, myName }) {
  const [text, setText] = useState("");
  const [ic, setIc] = useState(false);
  const box = useRef(null);
  const last = view.log[view.log.length - 1]?.id;
  useEffect(() => { box.current?.scrollTo({ top: box.current.scrollHeight, behavior: "smooth" }); }, [last]);
  return <div className="tableLog" data-tip="log">
    <div className="logScroll" ref={box}>{view.log.map((e) => <LogEntry key={e.id} e={e} />)}</div>
    <form className="logInput" onSubmit={(ev) => { ev.preventDefault(); if (text.trim()) { say(text, ic); setText(""); } }}>
      <button type="button" data-tip="log-ic" className={`icToggle ${ic ? "active" : ""}`} onClick={() => setIc(!ic)} title="Im Charakter sprechen">{ic ? (myName || "Charakter") : "Spieler"}</button>
      <input data-tip="log-input" value={text} maxLength={500} onChange={(e) => setText(e.target.value)} placeholder={ic ? "Sag etwas als dein Charakter …" : "Nachricht an den Tisch …"} />
      <button type="submit" aria-label="Senden"><Send size={16} /></button>
    </form>
  </div>;
}

function LogEntry({ e }) {
  if (e.kind === "scene") return <div className="logScene"><strong>{e.text}</strong>{e.body && <p>{e.body}</p>}</div>;
  if (e.kind === "system") return <div className={`logSystem ${e.secret ? "isSecret" : ""}`}>{e.secret && <EyeOff size={12} />}{e.text}</div>;
  if (e.kind === "chat") return <div className={`logChat ${e.ic ? "isIc" : ""}`}><b>{e.ic && e.as_name ? e.as_name : e.user}</b>{e.ic ? <em>„{e.text}“</em> : <span>{e.text}</span>}</div>;
  const r = e.roll;
  return <div className={`logRoll ${r.crit ? "isCrit" : ""} ${r.fumble ? "isFumble" : ""} ${e.secret ? "isSecret" : ""}`}>
    <div className="logRollHead"><b>{e.as_name || e.user}</b><span>{e.label || r.expr}</span>{e.secret && <small>verdeckt</small>}{e.private && <small>privat</small>}{r.mode !== "normal" && <small>{r.mode === "adv" ? "Vorteil" : "Nachteil"}</small>}</div>
    <div className="logRollBody">
      <span className="logDice">{r.parts.map((p, i) => p.type === "mod" ? <span key={i} className="logMod">{signed(p.value)}</span>
        : p.rolls.map((v, j) => <span key={`${i}-${j}`} className={`logDie ${p.kept.includes(j) ? "" : "isDropped"} ${p.sides === 20 && v === 20 ? "nat20" : ""} ${p.sides === 20 && v === 1 ? "nat1" : ""}`}><DieIcon sides={p.sides} size={26} label={false} /><b>{v}</b></span>))}</span>
      <strong className="logTotal">{r.total}</strong>
    </div>
    {r.crit && <div className="critBanner">Natürliche 20!</div>}{r.fumble && <div className="critBanner fumble">Natürliche 1 …</div>}
  </div>;
}
