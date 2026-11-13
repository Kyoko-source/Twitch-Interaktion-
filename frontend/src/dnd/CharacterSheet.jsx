import React, { useEffect, useState } from "react";
import { Dices, Heart, Pencil, Save, Shield, Sparkles, Swords, Wind, X } from "lucide-react";
import { ABILITIES, CLASSES, SKILLS, SPECIES, STANDARD_ARRAY, blankCharacter, classInfo, mod, profBonus, signed, suggestedAc, suggestedHp } from "./rules";
import { hpPercent, hpTone } from "./BattleMap";

const SHEET_KEYS = ["name", "species", "char_class", "subclass", "level", "background", "alignment", "abilities", "max_hp", "hp", "temp_hp", "ac", "speed",
  "skills", "saves", "inventory", "features", "spells", "notes", "color", "avatar_url", "gold", "death_saves"];
const pickSheet = (c) => Object.fromEntries(SHEET_KEYS.map((k) => [k, c[k]]));

export function CharacterSheet({ character, canEdit, onSave, onRoll, onHp, username, creating }) {
  const [editing, setEditing] = useState(Boolean(creating));
  const [draft, setDraft] = useState(() => (character ? pickSheet(character) : blankCharacter(username)));
  const [busy, setBusy] = useState(false);
  useEffect(() => { if (!editing && character) setDraft(pickSheet(character)); }, [character, editing]);

  const sheet = editing ? draft : character;
  const info = classInfo(sheet.char_class);
  const prof = profBonus(sheet.level);
  const skillBonus = (s) => mod(sheet.abilities[s.ability]) + (sheet.skills.includes(s.key) ? prof : 0);
  const saveBonus = (a) => mod(sheet.abilities[a]) + (sheet.saves.includes(a) ? prof : 0);
  const passive = 10 + skillBonus(SKILLS.find((s) => s.key === "perception"));
  const set = (patch) => setDraft((d) => ({ ...d, ...patch }));
  const setAbility = (key, value) => setDraft((d) => ({ ...d, abilities: { ...d.abilities, [key]: Math.max(1, Math.min(30, Number(value) || 1)) } }));
  const roll = (label, bonus) => !editing && onRoll(`1d20${signed(bonus)}`, label, sheet.name);

  function chooseClass(name) {
    const next = classInfo(name);
    setDraft((d) => {
      const keepKit = d.inventory && d.inventory !== classInfo(d.char_class).kit;
      const updated = { ...d, char_class: name, saves: next.saves, skills: d.skills.filter((k) => next.skills.includes(k)).slice(0, next.pick), color: next.color, inventory: keepKit ? d.inventory : next.kit };
      const hp = suggestedHp(updated);
      return { ...updated, max_hp: hp, hp, ac: suggestedAc(updated) };
    });
  }
  function standardArray() {
    const order = [...info.primary, ...ABILITIES.map((a) => a.key).filter((k) => !info.primary.includes(k))];
    const abilities = Object.fromEntries(order.map((k, i) => [k, STANDARD_ARRAY[i]]));
    setDraft((d) => { const u = { ...d, abilities }; const hp = suggestedHp(u); return { ...u, max_hp: hp, hp, ac: suggestedAc(u) }; });
  }
  function toggleSkill(key) {
    setDraft((d) => ({ ...d, skills: d.skills.includes(key) ? d.skills.filter((k) => k !== key) : [...d.skills, key] }));
  }
  async function save() {
    setBusy(true);
    try { await onSave({ ...draft, level: Number(draft.level), max_hp: Number(draft.max_hp), hp: Math.min(Number(draft.hp), Number(draft.max_hp)), ac: Number(draft.ac), speed: Number(draft.speed), temp_hp: Number(draft.temp_hp), gold: Number(draft.gold) }); setEditing(false); }
    catch { /* toast shown by caller */ }
    setBusy(false);
  }

  const pct = hpPercent(sheet);
  return <div className="sheet" style={{ "--cls": info.color }}>
    <header className="sheetHead">
      <div className="sheetCrest">{sheet.avatar_url ? <img src={sheet.avatar_url} alt="" /> : <Swords size={30} />}</div>
      <div className="sheetTitle">
        {editing ? <input className="sheetName" value={draft.name} maxLength={40} onChange={(e) => set({ name: e.target.value })} aria-label="Name" />
          : <h3>{sheet.name}</h3>}
        <p>{sheet.species} · {sheet.char_class}{sheet.subclass ? ` (${sheet.subclass})` : ""} · Stufe {sheet.level}{character?.owner ? ` · ${character.owner}` : ""}</p>
      </div>
      {canEdit && !creating && (editing
        ? <div className="sheetActions"><button type="button" className="ghost" onClick={() => setEditing(false)}><X size={16} />Abbrechen</button><button type="button" disabled={busy} onClick={save}><Save size={16} />Speichern</button></div>
        : <button type="button" className="ghost" data-tip="sheet-edit" onClick={() => setEditing(true)}><Pencil size={16} />Bearbeiten</button>)}
    </header>

    {editing && <section className="sheetBuild">
      <div className="classPicker" data-tip="sheet-class">{CLASSES.map((c) => <button type="button" key={c.name} className={draft.char_class === c.name ? "active" : ""} style={{ "--cls": c.color }} onClick={() => chooseClass(c.name)}>
        <strong>{c.name}</strong><small>W{c.die} · {c.blurb}</small></button>)}</div>
      <div className="sheetRow">
        <label>Volk<select value={draft.species} onChange={(e) => { const s = SPECIES.find((x) => x.name === e.target.value); set({ species: e.target.value, speed: s?.speed || 30 }); }}>{SPECIES.map((s) => <option key={s.name}>{s.name}</option>)}</select></label>
        <label>Stufe<input type="number" min="1" max="20" value={draft.level} onChange={(e) => { const u = { ...draft, level: Math.max(1, Math.min(20, Number(e.target.value) || 1)) }; const hp = suggestedHp(u); setDraft({ ...u, max_hp: hp, hp: Math.min(u.hp, hp) || hp }); }} /></label>
        <label>Unterklasse<input value={draft.subclass} maxLength={60} onChange={(e) => set({ subclass: e.target.value })} placeholder="ab Stufe 3" /></label>
        <label>Hintergrund<input value={draft.background} maxLength={60} onChange={(e) => set({ background: e.target.value })} placeholder="z. B. Soldat, Gelehrter" /></label>
        <label>Gesinnung<input value={draft.alignment} maxLength={40} onChange={(e) => set({ alignment: e.target.value })} placeholder="z. B. chaotisch gut" /></label>
        <label>Farbe<input type="color" value={draft.color} onChange={(e) => set({ color: e.target.value })} /></label>
      </div>
      <p className="sheetHint">{SPECIES.find((s) => s.name === draft.species)?.trait} Rüstung: {info.armor}. Wähle {info.pick} Fertigkeiten deiner Klasse (unten anklicken) – {draft.skills.filter((k) => info.skills.includes(k)).length}/{info.pick} gewählt.</p>
    </section>}

    <section className="vitals">
      <div className="vital hpVital" data-tip="sheet-hp">
        <Heart size={18} />
        <div className="vitalHp">
          {editing ? <span className="vitalInputs"><input type="number" value={draft.hp} onChange={(e) => set({ hp: e.target.value })} aria-label="Aktuelle TP" /> / <input type="number" value={draft.max_hp} onChange={(e) => set({ max_hp: e.target.value })} aria-label="Maximale TP" /></span>
            : <strong>{sheet.hp}<small> / {sheet.max_hp}</small>{sheet.temp_hp > 0 && <em> +{sheet.temp_hp}</em>}</strong>}
          <span className={`hpBar ${hpTone(pct)}`}><span style={{ width: `${pct}%` }} /></span>
        </div>
        {!editing && onHp && <HpQuick onHp={onHp} />}
      </div>
      <div className="vital" data-tip="sheet-ac"><Shield size={18} /><span>RK</span>{editing ? <input type="number" value={draft.ac} onChange={(e) => set({ ac: e.target.value })} /> : <strong>{sheet.ac}</strong>}</div>
      <button type="button" className="vital rollable" data-tip="sheet-init" onClick={() => roll("Initiative", mod(sheet.abilities.dex))}><Sparkles size={18} /><span>Init</span><strong>{signed(mod(sheet.abilities.dex))}</strong></button>
      <div className="vital" data-tip="sheet-speed"><Wind size={18} /><span>Tempo</span>{editing ? <input type="number" value={draft.speed} onChange={(e) => set({ speed: e.target.value })} /> : <strong>{sheet.speed}</strong>}</div>
      <div className="vital" data-tip="sheet-prof"><span>Übung</span><strong>{signed(prof)}</strong></div>
      <div className="vital" data-tip="sheet-passive"><span>Passive Wahrn.</span><strong>{passive}</strong></div>
    </section>

    <section className="abilityGrid" data-tip="sheet-abilities">
      {ABILITIES.map((a) => <div key={a.key} className="abilityBox">
        <button type="button" className="rollable" disabled={editing} onClick={() => roll(`${a.name}-Probe`, mod(sheet.abilities[a.key]))}>
          <span>{a.short}</span><strong>{signed(mod(sheet.abilities[a.key]))}</strong>
        </button>
        {editing ? <input type="number" min="1" max="30" value={draft.abilities[a.key]} onChange={(e) => setAbility(a.key, e.target.value)} aria-label={a.name} /> : <small>{sheet.abilities[a.key]}</small>}
        <button type="button" className={`saveChip ${sheet.saves.includes(a.key) ? "isProf" : ""}`} disabled={editing} onClick={() => roll(`Rettungswurf ${a.name}`, saveBonus(a.key))}>RW {signed(saveBonus(a.key))}</button>
      </div>)}
      {editing && <button type="button" className="ghost arrayButton" data-tip="sheet-array" onClick={standardArray}><Dices size={16} />Standardwerte für {draft.char_class}</button>}
    </section>

    <section className="skillList" data-tip="sheet-skills">
      {SKILLS.map((s) => {
        const proficient = sheet.skills.includes(s.key);
        const allowed = !editing || info.skills.includes(s.key) || proficient;
        return <button type="button" key={s.key} className={`skill ${proficient ? "isProf" : ""} ${editing && info.skills.includes(s.key) ? "isClassSkill" : ""}`} disabled={!allowed}
          onClick={() => (editing ? toggleSkill(s.key) : roll(s.name, skillBonus(s)))}>
          <i /> <span>{s.name}</span><small>{ABILITIES.find((a) => a.key === s.ability).short}</small><strong>{signed(skillBonus(s))}</strong>
        </button>;
      })}
    </section>

    <section className="sheetNotes" data-tip="sheet-notes">
      {[["inventory", "Ausrüstung"], ["features", "Merkmale & Talente"], ["spells", "Zauber"], ["notes", "Notizen"]].map(([key, label]) => <label key={key}>{label}
        {editing ? <textarea rows={key === "notes" ? 3 : 4} value={draft[key]} onChange={(e) => set({ [key]: e.target.value })} /> : <p>{sheet[key] || "—"}</p>}
      </label>)}
      {editing && <label>Profilbild (https-Link)<input value={draft.avatar_url} onChange={(e) => set({ avatar_url: e.target.value })} placeholder="optional" /></label>}
      <label>Gold{editing ? <input type="number" min="0" value={draft.gold} onChange={(e) => set({ gold: e.target.value })} /> : <p>{sheet.gold} GM</p>}</label>
    </section>
    {creating && <button type="button" className="sheetCreate" data-tip="sheet-create" disabled={busy || !draft.name.trim()} onClick={save}><Swords size={18} />Charakter an den Tisch bringen</button>}
  </div>;
}

function HpQuick({ onHp }) {
  const [amount, setAmount] = useState("");
  const send = (sign) => { const n = Math.abs(parseInt(amount, 10)); if (n) { onHp(sign * n); setAmount(""); } };
  return <span className="hpQuick">
    <input inputMode="numeric" value={amount} onChange={(e) => setAmount(e.target.value.replace(/\D/g, ""))} placeholder="0" aria-label="TP-Menge" />
    <button type="button" className="dmg" onClick={() => send(-1)}>Schaden</button>
    <button type="button" className="heal" onClick={() => send(1)}>Heilen</button>
  </span>;
}

export { HpQuick };
