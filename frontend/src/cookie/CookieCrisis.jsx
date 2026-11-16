import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Flame, Hand, Lock, Music, RotateCcw, Sparkles, Star, Volume2, VolumeX, Wand2 } from "lucide-react";
import { api } from "../api";
import {
  GOAL, GRAMS_PER_COOKIE, PHASES, UPGRADES, actCut, actLoad, actPortion, actRoll, activeMachines, bottleneck, buy, capacities,
  createState, derive, deserialize, isUnlocked, phaseOf, recommended, serialize, step, throughput, upgradeCost,
} from "./sim.js";
import { createRenderer, fmt } from "./render.js";
import { createSound } from "./sound.js";
import "./cookie.css";

const STAGE_ICON = { portion: "🥣", roll: "🪵", cut: "⭐", load: "🧺", oven: "🔥", chute: "🍪", all: "✨" };
const ACTIONS = [
  { id: "portion", key: "1", label: "Teig nehmen", fn: actPortion },
  { id: "roll", key: "2", label: "Ausrollen", fn: actRoll },
  { id: "cut", key: "3", label: "Ausstechen", fn: actCut },
  { id: "load", key: "4", label: "Aufs Band", fn: actLoad },
];
const num = (n, digits = 0) => Number(n || 0).toLocaleString("de-DE", { maximumFractionDigits: digits, minimumFractionDigits: 0 });
const rateText = (r) => (r >= 100 ? num(r) : num(r, 1));

// What the elf should do next (space bar): the step furthest down the line that can be done.
function nextStep(s, d) {
  if (s.tray > 0 && (s.tray >= d.trayCap || (s.sheet === 0 && s.ball === 0)) && s.queue < d.queueCap) return "load";
  if (s.sheet > 0 && s.tray < d.trayCap) return "cut";
  if (s.ball > 0 && s.sheet < d.sheetCap) return "roll";
  if (s.dough > 0 && s.ball < d.ballCap) return "portion";
  if (s.tray > 0) return "load";
  return null;
}

function storageKey(user) {
  return `aviary_cookie_save_${user?.username || "gast"}`;
}

export function CookieCrisis({ user, onLogin }) {
  const canvasRef = useRef(null);
  const stateRef = useRef(null);
  const renderer = useRef(null);
  const sound = useRef(null);
  const landings = useRef([]);
  const lastServerSave = useRef(0);
  const [ready, setReady] = useState(false);
  const [ui, setUi] = useState(null);
  const [finale, setFinale] = useState(null);
  const [notice, setNotice] = useState("");
  const [soundState, setSoundState] = useState({ muted: false, music: false });
  const [showDone, setShowDone] = useState(false);

  // ------------------------------------------------------------------ load (local + server, newest wins)
  useEffect(() => {
    let alive = true;
    (async () => {
      let local = null, remote = null;
      try { const raw = localStorage.getItem(storageKey(user)); if (raw) local = deserialize(raw); } catch { local = null; }
      if (user) {
        try { const r = await api("/api/cookie/save"); if (r?.save) remote = deserialize(r.save); } catch { remote = null; }
      }
      if (!alive) return;
      const pick = [local, remote].filter(Boolean).sort((a, b) => b.baked - a.baked || (b.savedAt || 0) - (a.savedAt || 0))[0];
      stateRef.current = pick || createState();
      setReady(true);
    })();
    return () => { alive = false; };
  }, [user?.username]);

  const saveLocal = useCallback(() => {
    if (!stateRef.current) return;
    try { localStorage.setItem(storageKey(user), serialize(stateRef.current)); } catch { /* storage full or blocked */ }
  }, [user?.username]);

  const saveServer = useCallback(async ({ keepalive = false, reset = false } = {}) => {
    if (!user || !stateRef.current) return null;
    lastServerSave.current = performance.now();
    try {
      return await api("/api/cookie/save", { method: "PUT", body: JSON.stringify({ data: serialize(stateRef.current), reset }), keepalive });
    } catch (err) {
      if (String(err.message).includes("neuerer")) setNotice("Auf einem anderen Gerät gibt es einen weiteren Spielstand mit mehr Keksen. Lade die Seite neu, um ihn zu übernehmen.");
      return null;
    }
  }, [user?.username]);

  // ------------------------------------------------------------------ game loop
  useEffect(() => {
    if (!ready || !canvasRef.current) return undefined;
    const r = createRenderer(canvasRef.current);
    renderer.current = r;
    const snd = createSound();
    sound.current = snd;
    setSoundState({ muted: snd.muted, music: snd.music });
    const ro = new ResizeObserver(() => r.resize());
    ro.observe(canvasRef.current);
    let raf = 0, last = performance.now(), uiT = 0, localT = 0;
    const loop = (now) => {
      const s = stateRef.current;
      const dt = Math.min(1, (now - last) / 1000); last = now;
      const d = step(s, dt);
      if (s.events.length) {
        r.onEvents(s.events); snd.handle(s.events);
        for (const e of s.events) {
          if (e.type === "land") landings.current.push([now, e.n]);
          if (e.type === "finale") setFinale({ shown: true });
        }
        s.events.length = 0;
      }
      r.frame(s, now);
      snd.update(dt, { belt: s.belt.length ? d.speed : 0, oven: 1, machines: activeMachines(s.levels) });
      uiT += dt; localT += dt;
      if (uiT > 0.12) {
        uiT = 0;
        while (landings.current.length && now - landings.current[0][0] > 4000) landings.current.shift();
        const span = Math.min(4, Math.max(1, s.t));
        const rate = landings.current.reduce((a, b) => a + b[1], 0) / span;
        setUi({ s: { ...s, belt: undefined, falling: undefined }, d, rate });
      }
      if (localT > 5) { localT = 0; saveLocal(); }
      if (user && now - lastServerSave.current > 30000) saveServer();
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    const hide = () => { if (document.visibilityState === "hidden") { saveLocal(); saveServer({ keepalive: true }); } };
    document.addEventListener("visibilitychange", hide);
    window.addEventListener("pagehide", hide);
    return () => {
      cancelAnimationFrame(raf); ro.disconnect(); snd.stop(); r.dispose();
      document.removeEventListener("visibilitychange", hide);
      window.removeEventListener("pagehide", hide);
      saveLocal(); saveServer({ keepalive: true });
    };
  }, [ready, saveLocal, saveServer]);

  // finale: store the save, then ask for the title
  useEffect(() => {
    if (!finale?.shown || finale.title) return;
    renderer.current?.startFinale();
    (async () => {
      saveLocal();
      await saveServer();
      let title = "Oberster Keksmeister des Nordpols", note = "";
      if (user) {
        try { title = (await api("/api/cookie/finale", { method: "POST", body: "{}" })).title; }
        catch (err) { note = err.message; }
      } else note = "Melde dich an, damit die Auszeichnung in deinem Profil erscheint.";
      setFinale({ shown: true, title, note });
    })();
  }, [finale]);

  // ------------------------------------------------------------------ input
  const act = useCallback((id) => {
    const s = stateRef.current;
    if (!s) return;
    sound.current?.unlock();
    const d = derive(s.levels);
    const which = id === "next" ? nextStep(s, d) : id;
    const a = ACTIONS.find((x) => x.id === which);
    if (a) a.fn(s, d);
  }, []);

  useEffect(() => {
    const onKey = (e) => {
      if (e.target.closest?.("input, textarea, select")) return;
      const a = ACTIONS.find((x) => x.key === e.key);
      if (a) { e.preventDefault(); act(a.id); }
      else if (e.code === "Space" && canvasRef.current && document.activeElement?.closest?.(".ccGame")) { e.preventDefault(); act("next"); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [act]);

  function onCanvasClick(e) {
    const rect = e.currentTarget.getBoundingClientRect();
    const h = renderer.current?.hit(e.clientX - rect.left, e.clientY - rect.top);
    if (h && h.id !== "drag") act(h.id);
  }
  function onCanvasMove(e) {
    const rect = e.currentTarget.getBoundingClientRect();
    const h = renderer.current?.hit(e.clientX - rect.left, e.clientY - rect.top);
    renderer.current?.setHover(h);
    e.currentTarget.style.cursor = h && h.id !== "drag" ? "pointer" : e.buttons & 1 ? "grabbing" : "grab";
  }

  function purchase(id) {
    const s = stateRef.current;
    sound.current?.unlock();
    if (buy(s, id)) { saveLocal(); setUi((u) => (u ? { ...u, s: { ...s, belt: undefined, falling: undefined }, d: derive(s.levels) } : u)); }
  }

  async function newGame() {
    if (!window.confirm("Wirklich ganz von vorne anfangen? Dein aktueller Spielstand wird überschrieben.")) return;
    stateRef.current = createState();
    landings.current = [];
    setFinale(null); setShowDone(false);
    saveLocal();
    await saveServer({ reset: true });
  }

  // ------------------------------------------------------------------ view
  const view = useMemo(() => {
    if (!ui) return null;
    const { s, d, rate } = ui;
    const phase = phaseOf(s);
    const caps = capacities(d);
    const neck = bottleneck(d);
    const rec = recommended(s, d);
    const tp = throughput(d);
    const next = PHASES.find((p) => p.n === phase + 1);
    return { s, d, rate, phase, caps, neck, rec, tp, next, machines: activeMachines(s.levels) };
  }, [ui]);

  if (!ready) return <div className="notice">Die Weihnachtsbäckerei wird aufgeschlossen …</div>;

  return (
    <section className="ccGame" data-testid="cookie-game">
      <div className="ccMain">
        <div className="ccStage">
          <canvas ref={canvasRef} className="ccCanvas" onClick={onCanvasClick} onMouseMove={onCanvasMove} onMouseLeave={() => renderer.current?.setHover(null)}
            role="img" aria-label="Ich-Perspektive des Elfen: deine Hände an der Werkbank mit Teigschüssel, Teigplatte und Blech, dahinter Förderbandofen und Sammelschacht" tabIndex={0} />
          {view && (
            <div className="ccHud">
              <div className="ccGoal">
                <div className="ccGoalText"><b data-testid="cookie-baked">{num(view.s.baked)}</b> / 1.000.000 Kekse</div>
                <div className="ccGoalBar"><i style={{ width: `${(view.s.baked / GOAL) * 100}%` }} /></div>
              </div>
              <div className="ccChips">
                <span title="Schokotaler"><b data-testid="cookie-talers">{num(view.s.talers)}</b> 🍫</span>
                <span title="Teig im Vorrat">{num((view.s.dough * GRAMS_PER_COOKIE) / 1000, view.s.dough * GRAMS_PER_COOKIE < 100_000 ? 1 : 0)} kg Teig</span>
                <span title="Kekse pro Sekunde (gemessen)">{rateText(view.rate)} /s</span>
              </div>
            </div>
          )}
          <div className="ccSoundBtns">
            <button type="button" className="ccIcon" onClick={() => setSoundState({ ...soundState, muted: sound.current.toggleMute() })} aria-label={soundState.muted ? "Ton an" : "Ton aus"} title={soundState.muted ? "Ton an" : "Ton aus"}>{soundState.muted ? <VolumeX size={17} /> : <Volume2 size={17} />}</button>
            <button type="button" className={`ccIcon${soundState.music ? " on" : ""}`} onClick={() => setSoundState({ ...soundState, music: sound.current.toggleMusic() })} aria-pressed={soundState.music} aria-label="Hintergrundmusik" title="Hintergrundmusik"><Music size={17} /></button>
          </div>
        </div>

        <div className="ccActions">
          {ACTIONS.map((a) => {
            const auto = view && view.caps.find((c) => c.id === a.id).rate > 0;
            const isNext = view && nextStep(view.s, view.d) === a.id;
            return (
              <button key={a.id} type="button" className={`ccAct${isNext ? " next" : ""}`} onClick={() => act(a.id)} data-testid={`cookie-${a.id}`}>
                <span className="ccActIcon" aria-hidden="true">{STAGE_ICON[a.id]}</span>
                <span><b>{a.label}</b><small>{auto ? "läuft automatisch – hilf mit" : a.id === "portion" ? `${view?.d.sheetSize || 8} Kekse Teig` : a.id === "roll" ? (view?.d.walze ? "Kurbel drehen" : `${view?.d.strokes || 3}× rollen`) : a.id === "cut" ? (view?.d.pressSize ? "Hebel ziehen" : `${view?.d.cutter || 1} pro Stich`) : `Blech: ${view?.s.tray || 0}/${view?.d.trayCap || 6}`}</small></span>
                <kbd>{a.key}</kbd>
              </button>
            );
          })}
          <p className="ccHint"><kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> laufen · Maus ziehen zum Umsehen · Klick auf eine Station arbeitet dort · <kbd>Leertaste</kbd> macht den nächsten sinnvollen Schritt</p>
        </div>

        {view && (
          <div className="ccLine" aria-label="Produktionslinie">
            {view.caps.map((c) => {
              const isNeck = view.neck.id === c.id;
              const pct = Math.min(100, (Math.max(c.rate, 0.01) / Math.max(view.tp, 0.01)) * 100);
              return (
                <div key={c.id} className={`ccStation${isNeck ? " neck" : ""}`}>
                  <span className="ccStationName">{STAGE_ICON[c.id]} {c.name}</span>
                  <span className="ccStationBar"><i style={{ width: `${Math.min(100, pct)}%` }} /></span>
                  <small>{c.rate > 0 ? `${rateText(c.rate)} /s` : "Handarbeit"}{c.hand > 0.05 ? <> · <Hand size={11} /></> : null}</small>
                  {isNeck && <em>Engpass</em>}
                </div>
              );
            })}
            <div className="ccLineInfo">
              <span><Flame size={14} /> Ofen-Auslastung <b>{Math.round(Math.min(1, view.rate / Math.max(view.d.ovenRate, 0.01)) * 100)} %</b></span>
              <span><Wand2 size={14} /> Aktive Maschinen <b>{view.machines}</b></span>
              <span>Rückstau vor dem Ofen <b>{num(view.s.queue)}</b></span>
            </div>
          </div>
        )}
        {notice && <div className="notice">{notice}</div>}
        {!user && <div className="notice">Du spielst als Gast – der Spielstand bleibt nur in diesem Browser. <button type="button" className="ghost" onClick={onLogin}>Anmelden</button></div>}
      </div>

      {view && (
        <aside className="ccShop" aria-label="Werkstatt-Shop">
          <div className="ccShopHead">
            <div><small>Schokotaler</small><strong>{num(view.s.talers)} 🍫</strong></div>
            <div><small>Phase {view.phase}</small><b>{PHASES[view.phase - 1].name}</b></div>
          </div>
          {view.rec && <Upgrade u={view.rec} s={view.s} d={view.d} tp={view.tp} onBuy={purchase} recommended />}
          {view.next && (
            <div className="ccNextPhase">
              <Lock size={14} /> <span>Phase {view.next.n}: <b>{view.next.name}</b> ab {num(view.next.unlock)} Keksen</span>
              <i style={{ width: `${Math.min(100, (view.s.earned / view.next.unlock) * 100)}%` }} />
            </div>
          )}
          {PHASES.filter((p) => p.n <= view.phase).reverse().map((p) => {
            const list = UPGRADES.filter((u) => u.phase === p.n);
            const open = list.filter((u) => (view.s.levels[u.id] || 0) < u.max && u.id !== view.rec?.id);
            const done = list.filter((u) => (view.s.levels[u.id] || 0) >= u.max);
            return (
              <div key={p.n} className="ccPhase">
                <h4>{p.n}. {p.name}</h4>
                {open.sort((a, b) => upgradeCost(a, view.s.levels[a.id] || 0) - upgradeCost(b, view.s.levels[b.id] || 0)).map((u) => <Upgrade key={u.id} u={u} s={view.s} d={view.d} tp={view.tp} onBuy={purchase} />)}
                {done.length > 0 && <div className="ccDone">{done.map((u) => <span key={u.id} title={u.text}>✓ {u.name}</span>)}</div>}
              </div>
            );
          })}
          <button type="button" className="ghost ccReset" onClick={newGame}><RotateCcw size={14} /> Neues Spiel</button>
        </aside>
      )}

      {finale?.shown && !showDone && (
        <div className="ccFinale" role="dialog" aria-modal="true" aria-labelledby="ccFinaleTitle">
          <div className="ccFinaleCard">
            <div className="ccSanta" aria-hidden="true">🎅</div>
            <h2 id="ccFinaleTitle">Ho ho ho – du hast Weihnachten gerettet!</h2>
            <p>„Eine Million Plätzchen, jedes einzelne goldbraun und duftend. Aus einem kleinen Holztisch ist die größte Keksfabrik des Nordpols geworden – und du hast das ganz allein geschafft. Danke, mein lieber Elf!“</p>
            <p className="ccSign">– Der Weihnachtsmann</p>
            <div className="ccAward"><Star size={20} /> {finale.title || "…"} <Star size={20} /></div>
            {finale.note && <small>{finale.note}</small>}
            <button type="button" onClick={() => setShowDone(true)}><Sparkles size={16} /> Weiter feiern</button>
          </div>
        </div>
      )}
    </section>
  );
}

function Upgrade({ u, s, d, tp, onBuy, recommended: rec = false }) {
  const level = s.levels[u.id] || 0;
  const cost = upgradeCost(u, level);
  const can = s.talers >= cost && isUnlocked(s, u);
  const next = derive({ ...s.levels, [u.id]: level + 1 });
  const after = throughput(next);
  let effect = "";
  if (after > tp * 1.0001) effect = `Produktion ${rateText(tp)} → ${rateText(after)} Kekse/s`;
  else if (u.stage !== "all") {
    const before = capacities(d).find((c) => c.id === u.stage), then = capacities(next).find((c) => c.id === u.stage);
    if (then && then.rate > before.rate) effect = `${before.name}: ${rateText(before.rate)} → ${rateText(then.rate)} /s`;
  }
  return (
    <div className={`ccUp${rec ? " rec" : ""}${can ? " can" : ""}`}>
      {rec && <em className="ccRec"><Sparkles size={12} /> Empfohlen</em>}
      <div className="ccUpHead">
        <span className="ccUpIcon" aria-hidden="true">{STAGE_ICON[u.stage]}</span>
        <b>{u.name}</b>
        {u.max > 1 && <span className="ccDots" aria-label={`Stufe ${level} von ${u.max}`}>{Array.from({ length: u.max }, (_, i) => <i key={i} className={i < level ? "on" : ""} />)}</span>}
      </div>
      <small>{u.text}</small>
      {effect && <span className="ccEffect">{effect}</span>}
      <button type="button" disabled={!can} onClick={() => onBuy(u.id)} data-testid={`buy-${u.id}`}>
        {num(cost)} 🍫
        {!can && <i className="ccAfford" style={{ width: `${Math.min(100, (s.talers / cost) * 100)}%` }} />}
      </button>
    </div>
  );
}

export default CookieCrisis;
