import React, { useCallback, useEffect, useRef, useState } from "react";
import { Copy, Crown, DoorOpen, Eye, LogIn, Map as MapIcon, Plus, ScrollText, Shield, Skull, Swords, Users } from "lucide-react";
import { api } from "../api";
import { BattleMap } from "./BattleMap";
import { CharacterSheet } from "./CharacterSheet";
import { CombatPanel, CreaturePanel, DicePanel, SelectedCard, TableLog, TablePanel } from "./Panels";
import { DieIcon } from "./DieIcon";
import "./dnd.css";

const ROUTE = /^#games\/dnd\/([A-Z2-9]{6})/i;
const routeCode = () => (window.location.hash.match(ROUTE)?.[1] || "").toUpperCase();
const setRoute = (code) => window.history.replaceState(null, "", code ? `/#games/dnd/${code}` : "/#games/dnd");

export function DungeonsAndDragons({ user, onLogin }) {
  const [code, setCode] = useState(routeCode);
  const open = (next) => { setRoute(next); setCode(next); };
  if (!user) return <section className="dndShell"><DndHero /><div className="dndGate"><p>Melde dich an, um einen Tisch zu eröffnen oder einer Runde beizutreten.</p><button type="button" onClick={onLogin}><LogIn size={18} />Zum Login</button></div></section>;
  return <section className="dndShell">{code ? <Table key={code} code={code} user={user} onExit={() => open("")} /> : <><DndHero /><Lobby onOpen={open} /></>}</section>;
}

function DndHero() {
  return <div className="dndHero">
    <div className="dndHeroDice"><DieIcon sides={20} size={92} /><DieIcon sides={12} size={54} /><DieIcon sides={8} size={44} /></div>
    <div>
      <p className="kicker">Pen & Paper · 5. Edition</p>
      <h2>Dungeons and Dragons</h2>
      <p>Euer eigener Spieltisch im Browser: Dungeon Master, bis zu acht Helden, Charakterbögen, Battlemap, Kreaturen mit Lebensbalken und echte Würfel von W4 bis W100. Kostenlos, ohne Download.</p>
    </div>
  </div>;
}

// ---------------------------------------------------------------- lobby
function Lobby({ onOpen }) {
  const [rooms, setRooms] = useState(null);
  const [name, setName] = useState("");
  const [joinCode, setJoinCode] = useState("");
  const [error, setError] = useState("");
  const load = useCallback(() => api("/api/dnd/rooms").then(setRooms).catch((e) => setError(e.message)), []);
  useEffect(() => { load(); const t = setInterval(load, 8000); return () => clearInterval(t); }, [load]);

  async function create(e) {
    e.preventDefault(); setError("");
    try { const r = await api("/api/dnd/rooms", { method: "POST", body: JSON.stringify({ name: name.trim() }) }); onOpen(r.code); }
    catch (err) { setError(err.message); }
  }
  async function join(code, role) {
    setError("");
    try { await api(`/api/dnd/rooms/${code}/join`, { method: "POST", body: JSON.stringify({ role }) }); onOpen(code); }
    catch (err) { setError(err.message); }
  }
  const mine = (rooms || []).filter((r) => r.my_role);
  const open = (rooms || []).filter((r) => !r.my_role);
  return <div className="dndLobby">
    <div className="lobbyActions">
      <form className="lobbyCard createCard" onSubmit={create}>
        <h3><Crown size={20} />Tisch eröffnen</h3>
        <p>Du wirst Dungeon Master: Szenen ansagen, Kreaturen beschwören, verdeckt würfeln.</p>
        <input value={name} maxLength={60} onChange={(e) => setName(e.target.value)} placeholder="Name der Kampagne, z. B. Die Gruft des Lichs" />
        <button type="submit" disabled={name.trim().length < 2}><Plus size={18} />Als DM eröffnen</button>
      </form>
      <form className="lobbyCard" onSubmit={(e) => { e.preventDefault(); if (joinCode.length === 6) join(joinCode, "player"); }}>
        <h3><LogIn size={20} />Mit Code beitreten</h3>
        <p>Dein DM hat dir einen sechsstelligen Code geschickt?</p>
        <input className="codeInput" value={joinCode} maxLength={6} onChange={(e) => setJoinCode(e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, ""))} placeholder="ABC234" />
        <button type="submit" disabled={joinCode.length !== 6}><Swords size={18} />Als Held beitreten</button>
      </form>
    </div>
    {error && <div className="notice error">{error}</div>}
    {mine.length > 0 && <><h3 className="lobbyHeading">Deine Tische</h3><div className="roomGrid">{mine.map((r) => <RoomCard key={r.code} room={r} onOpen={() => onOpen(r.code)} />)}</div></>}
    <h3 className="lobbyHeading">Offene Tische</h3>
    {rooms === null ? <div className="notice">Lade Tische …</div> : open.length ? <div className="roomGrid">{open.map((r) => <RoomCard key={r.code} room={r} onJoin={join} />)}</div>
      : <div className="notice">Gerade ist kein offener Tisch frei. Eröffne doch selbst einen!</div>}
  </div>;
}

function RoomCard({ room, onOpen, onJoin }) {
  const full = room.players >= room.max_players;
  return <article className="roomCard">
    <header><strong>{room.name}</strong><small><Crown size={13} />{room.dm}</small></header>
    <p>{room.scene || "Noch keine Szene"}</p>
    <div className="roomMeta"><span><Users size={14} />{room.players}/{room.max_players} Helden</span><code>{room.code}</code></div>
    {onOpen ? <button type="button" onClick={onOpen}><DoorOpen size={16} />{room.my_role === "dm" ? "Tisch öffnen" : "Weiterspielen"}</button>
      : <div className="roomJoin"><button type="button" disabled={full} onClick={() => onJoin(room.code, "player")}><Swords size={16} />Mitspielen</button><button type="button" className="ghost" onClick={() => onJoin(room.code, "spectator")}><Eye size={16} />Zuschauen</button></div>}
  </article>;
}

// ---------------------------------------------------------------- table
function Table({ code, user, onExit }) {
  const [view, setView] = useState(null);
  const [problem, setProblem] = useState("");
  const [toast, setToast] = useState("");
  const [tab, setTab] = useState("sheet");
  const [selected, setSelected] = useState(null);
  const [mode, setMode] = useState("normal");
  const [overlay, setOverlay] = useState(null);
  const [viewChar, setViewChar] = useState(null);
  const version = useRef(0);
  const seenRoll = useRef(null);

  const accept = useCallback((next) => {
    if (!next || next.unchanged) return;
    version.current = next.version;
    const rolls = next.log.filter((e) => e.kind === "roll");
    const newest = rolls[rolls.length - 1];
    if (seenRoll.current === null) seenRoll.current = newest?.id || 0;
    else if (newest && newest.id > seenRoll.current) { seenRoll.current = newest.id; setOverlay({ ...newest, key: newest.id }); }
    setView(next);
  }, []);

  useEffect(() => {
    let alive = true; let timer;
    const tick = async () => {
      try { accept(await api(`/api/dnd/rooms/${code}?since=${version.current}`)); setProblem(""); }
      catch (e) { if (alive) setProblem(e.status === 403 ? "join" : e.status === 404 ? "gone" : e.message); }
      if (alive) timer = setTimeout(tick, document.hidden ? 5000 : 1100);
    };
    tick();
    return () => { alive = false; clearTimeout(timer); };
  }, [code, accept]);

  useEffect(() => { if (!overlay) return undefined; const t = setTimeout(() => setOverlay(null), 2600); return () => clearTimeout(t); }, [overlay]);
  useEffect(() => { if (!toast) return undefined; const t = setTimeout(() => setToast(""), 3500); return () => clearTimeout(t); }, [toast]);

  const act = useCallback(async (action) => {
    try { const next = await api(`/api/dnd/rooms/${code}/action`, { method: "POST", body: JSON.stringify(action) }); accept(next); return next; }
    catch (e) { setToast(e.message); throw e; }
  }, [code, accept]);

  if (problem === "join") return <JoinPrompt code={code} onJoined={() => setProblem("")} onExit={onExit} />;
  if (problem === "gone") return <div className="dndGate"><p>Diesen Tisch gibt es nicht mehr.</p><button type="button" onClick={onExit}>Zur Lobby</button></div>;
  if (!view) return <div className="notice">Der Tisch wird gedeckt …</div>;

  const isDm = view.role === "dm";
  const mine = Object.values(view.characters).find((c) => c.owner === user.username);
  const canControl = (ref) => isDm || (ref.startsWith("c:") && view.characters[ref.slice(2)]?.owner === user.username);
  const nameOf = (ref) => (ref.startsWith("c:") ? view.characters[ref.slice(2)]?.name : view.creatures[ref.slice(2)]?.name) || "?";
  const roll = (expr, label, as, extra = {}) => act({ type: "roll", expr, label, mode, as: as || mine?.name || "", ...extra }).catch(() => {});
  const leave = async () => {
    try { await api(`/api/dnd/rooms/${code}/leave`, { method: "POST" }); } catch (e) { setToast(e.message); return; }
    onExit();
  };
  const sheetChar = (viewChar && view.characters[viewChar]) || mine || (view.role !== "player" ? Object.values(view.characters)[0] : null);
  const tabs = [["sheet", "Charakter", ScrollText], ["dice", "Würfel", null], ["combat", "Kampf", Swords], ...(isDm ? [["creatures", "Kreaturen", Skull], ["table", "Tisch", MapIcon]] : [])];

  return <div className={`dndTable ${isDm ? "isDm" : ""}`}>
    <header className="tableHead">
      <div>
        <p className="kicker">{isDm ? "Du bist Dungeon Master" : view.role === "player" ? "Du spielst mit" : "Du schaust zu"}</p>
        <h2>{view.name}</h2>
        <p className="tableScene"><b>{view.scene.title}</b>{view.scene.text && ` — ${view.scene.text.slice(0, 140)}${view.scene.text.length > 140 ? " …" : ""}`}</p>
      </div>
      <div className="tableHeadActions">
        <button type="button" className="ghost codeChip" onClick={() => navigator.clipboard?.writeText(view.code).then(() => setToast("Code kopiert – schick ihn deinen Spielern!"))}><Copy size={15} />{view.code}</button>
        <span className="partyChips">{Object.entries(view.members).map(([name, m]) => <span key={name} className={`partyChip role-${m.role}`} title={name}>{m.role === "dm" && <Crown size={12} />}{name}</span>)}</span>
        <button type="button" className="ghost" onClick={onExit}>Lobby</button>
        {!isDm && <button type="button" className="ghost danger" onClick={() => window.confirm("Tisch verlassen? Dein Charakter wird entfernt.") && leave()}><DoorOpen size={16} />Verlassen</button>}
      </div>
    </header>

    <div className="tableBody">
      <div className="tableMapCol">
        <BattleMap view={view} selected={selected} onSelect={setSelected} act={act} canControl={canControl} />
        <SelectedCard view={view} refId={selected} canControl={canControl} act={act} isDm={isDm} onClose={() => setSelected(null)} />
      </div>
      <aside className="tableSide">
        <nav className="tableTabs">{tabs.map(([id, label, Icon]) => <button type="button" key={id} className={tab === id ? "active" : ""} onClick={() => setTab(id)}>
          {Icon ? <Icon size={16} /> : <DieIcon sides={20} size={18} label={false} />}{label}</button>)}</nav>
        <div className="tabBody">
          {tab === "sheet" && <SheetTab view={view} user={user} isDm={isDm} mine={mine} sheetChar={sheetChar} setViewChar={setViewChar} act={act} roll={roll} />}
          {tab === "dice" && <DicePanel roll={roll} isDm={isDm} mode={mode} setMode={setMode} />}
          {tab === "combat" && <CombatPanel view={view} isDm={isDm} act={act} nameOf={nameOf} onSelect={setSelected} />}
          {tab === "creatures" && isDm && <CreaturePanel view={view} act={act} onSelect={setSelected} />}
          {tab === "table" && isDm && <TablePanel view={view} act={act} onLeave={leave} />}
        </div>
      </aside>
      <TableLog view={view} myName={mine?.name} say={(text, ic) => act({ type: "chat.say", text, in_character: ic, as: mine?.name || "" }).catch(() => {})} />
    </div>
    {overlay && <RollOverlay entry={overlay} />}
    {toast && <div className="dndToast" role="status">{toast}</div>}
  </div>;
}

function SheetTab({ view, user, isDm, mine, sheetChar, setViewChar, act, roll }) {
  const others = Object.values(view.characters);
  const save = (character, id) => act({ type: "character.save", character, ...(id ? { id } : {}) });
  return <div className="sheetTab">
    {others.length > 1 || (isDm && others.length) ? <div className="heroSwitch">{others.map((c) => <button type="button" key={c.id} className={sheetChar?.id === c.id ? "active" : ""} style={{ "--tok": c.color }} onClick={() => setViewChar(c.id)}><span className="selDot" />{c.name}</button>)}</div> : null}
    {sheetChar ? <CharacterSheet key={sheetChar.id} character={sheetChar} username={user.username} canEdit={isDm || sheetChar.owner === user.username}
      onSave={(sheet) => save(sheet, sheetChar.id)} onRoll={roll} onHp={isDm || sheetChar.owner === user.username ? (delta) => act({ type: "hp.change", ref: `c:${sheetChar.id}`, delta }) : null} />
      : view.role === "player" ? <><div className="notice">Erschaffe deinen Helden: Klasse wählen, Werte setzen, fertig.</div><CharacterSheet creating username={user.username} canEdit onSave={(sheet) => save(sheet)} onRoll={roll} /></>
        : <div className="notice">{isDm ? "Noch keine Helden am Tisch. Teile den Code oben mit deinen Spielern." : "Noch keine Helden am Tisch."}</div>}
    {!isDm && mine && sheetChar?.id !== mine.id && <button type="button" className="ghost" onClick={() => setViewChar(mine.id)}><Shield size={16} />Zu meinem Bogen</button>}
  </div>;
}

function JoinPrompt({ code, onJoined, onExit }) {
  const [error, setError] = useState("");
  const join = async (role) => {
    try { await api(`/api/dnd/rooms/${code}/join`, { method: "POST", body: JSON.stringify({ role }) }); onJoined(); }
    catch (e) { setError(e.message); }
  };
  return <div className="dndGate">
    <p>Du bist zu Tisch <code>{code}</code> eingeladen.</p>
    <div className="roomJoin"><button type="button" onClick={() => join("player")}><Swords size={16} />Als Held beitreten</button><button type="button" className="ghost" onClick={() => join("spectator")}><Eye size={16} />Zuschauen</button><button type="button" className="ghost" onClick={onExit}>Zur Lobby</button></div>
    {error && <div className="notice error">{error}</div>}
  </div>;
}

function RollOverlay({ entry }) {
  const r = entry.roll;
  const dice = r.parts.filter((p) => p.type === "dice");
  const main = dice[0]?.sides || 20;
  return <div className={`rollOverlay ${r.crit ? "isCrit" : ""} ${r.fumble ? "isFumble" : ""}`} aria-live="polite">
    <div className="rollStage">
      <span className="rollSpin"><DieIcon sides={main} size={120} label={false} /></span>
      <strong className="rollNumber">{r.total}</strong>
    </div>
    <p><b>{entry.as_name || entry.user}</b> · {entry.label || r.expr}{r.mode !== "normal" ? ` · ${r.mode === "adv" ? "Vorteil" : "Nachteil"}` : ""}</p>
    {r.crit && <em>KRITISCHER TREFFER!</em>}{r.fumble && <em>PATZER!</em>}
  </div>;
}
