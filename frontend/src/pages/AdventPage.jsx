import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ExternalLink, FlaskConical, Gift, KeyRound, Lock, RotateCcw, Skull, Sparkles, Star, X } from "lucide-react";
import { api } from "../api";
import "./advent.css";

// Classic scattered door layout: grid slot -> door number.
const LAYOUT = [13, 7, 21, 2, 18, 10, 5, 24, 15, 1, 9, 19, 22, 3, 12, 17, 6, 14, 20, 8, 11, 23, 4, 16];
const WIDE = [1, 6, 11, 17, 21, 24];
const WRAP = ["#ff3fb4", "#3fe7ff", "#ffc94a", "#b06bff", "#5dff8c", "#ff8a2a"];
const KIND = {
  gift: { label: "GESCHENK", icon: Gift, cls: "gift", sound: "/audio/pinball/jackpot.ogg" },
  punishment: { label: "BESTRAFUNG", icon: Skull, cls: "punish", sound: "/audio/pinball/mission-fail.ogg" },
  task: { label: "AUFGABE", icon: Star, cls: "task", sound: "/audio/pinball/mission-complete.ogg" },
};
const two = (n) => String(Math.max(0, Math.floor(n))).padStart(2, "0");
function split(ms) {
  const s = Math.max(0, ms / 1000);
  return { d: Math.floor(s / 86400), h: two((s % 86400) / 3600), m: two((s % 3600) / 60), s: two(s % 60) };
}
const dateLabel = (iso) => new Date(iso).toLocaleString("de-DE", { day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" });

function Snow({ count = 70 }) {
  const flakes = useMemo(() => Array.from({ length: count }, (_, i) => ({
    left: Math.random() * 100, size: 2 + Math.random() * 5, dur: 7 + Math.random() * 12, delay: -Math.random() * 20, drift: (Math.random() - 0.5) * 80, o: 0.35 + Math.random() * 0.6, key: i,
  })), [count]);
  return <div className="advSnow" aria-hidden="true">{flakes.map((f) => <i key={f.key} style={{ left: `${f.left}%`, width: f.size, height: f.size, animationDuration: `${f.dur}s`, animationDelay: `${f.delay}s`, "--drift": `${f.drift}px`, opacity: f.o }} />)}</div>;
}

function Confetti({ burst }) {
  const bits = useMemo(() => Array.from({ length: 110 }, (_, i) => ({
    x: (Math.random() - 0.5) * 900, y: -200 - Math.random() * 500, r: Math.random() * 720, c: WRAP[i % WRAP.length], d: 0.9 + Math.random() * 0.9, w: 6 + Math.random() * 8, key: i,
  })), [burst]);
  if (!burst) return null;
  return <div className="advConfetti" key={burst} aria-hidden="true">{bits.map((b) => <i key={b.key} style={{ "--x": `${b.x}px`, "--y": `${b.y}px`, "--r": `${b.r}deg`, background: b.c, animationDuration: `${b.d}s`, width: b.w, height: b.w * 0.45 }} />)}</div>;
}

function Countdown({ ms, big = false }) {
  const t = split(ms);
  return <div className={`advCount ${big ? "big" : ""}`} role="timer">
    {[["Tage", t.d], ["Std", t.h], ["Min", t.m], ["Sek", t.s]].map(([l, v]) => <div key={l}><b>{v}</b><small>{l}</small></div>)}
  </div>;
}

export function AdventPage({ user }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [now, setNow] = useState(Date.now());
  const [reveal, setReveal] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [busy, setBusy] = useState(false);
  const [burst, setBurst] = useState(0);
  const [opening, setOpening] = useState(null);
  const [pw, setPw] = useState("");
  const [pwMsg, setPwMsg] = useState("");
  const [testMode, setTestMode] = useState(false);
  const base = testMode ? "/api/advent/test" : "/api/advent";
  const offset = useRef(0);
  const known = useRef(null);

  const apply = useCallback((next, { announce = true } = {}) => {
    offset.current = new Date(next.now).getTime() - Date.now();
    const openedNow = next.doors.filter((d) => d.opened).map((d) => d.day);
    if (known.current && announce) {
      const fresh = next.doors.filter((d) => d.opened && !known.current.includes(d.day));
      if (fresh.length) showReveal(fresh[fresh.length - 1]);
    }
    known.current = openedNow;
    setData(next);
  }, []);

  function showReveal(door) {
    setReveal(door);
    setBurst(Date.now());
    try { const a = new Audio(KIND[door.item.kind].sound); a.volume = 0.6; a.play().catch(() => {}); } catch { /* audio optional */ }
  }

  useEffect(() => {
    let alive = true;
    known.current = null;
    const load = () => api(base).then((d) => alive && apply(d)).catch((e) => alive && setError(e.message));
    load();
    const poll = setInterval(load, 20000);
    const tick = setInterval(() => setNow(Date.now()), 1000);
    return () => { alive = false; clearInterval(poll); clearInterval(tick); };
  }, [apply, base, user?.username]);

  async function openDoor(day) {
    setBusy(true); setConfirm(null); setError("");
    setOpening(day);
    try {
      const next = await api(`${base}/${day}/open`, { method: "POST", body: "{}" });
      await new Promise((r) => setTimeout(r, 650));
      apply(next, { announce: false });
      showReveal(next.doors[day - 1]);
    } catch (e) { setError(e.message); }
    setOpening(null); setBusy(false);
  }

  async function virusOff(e) {
    e.preventDefault();
    setPwMsg("");
    try { apply(await api(`${base}/virus/off`, { method: "POST", body: JSON.stringify({ password: pw }) }), { announce: false }); setPw(""); }
    catch (err) { setPwMsg(err.message); }
  }

  async function resetTest() {
    if (!window.confirm("Testmodus zurücksetzen? Alle Test-Türchen werden wieder geschlossen.")) return;
    setError("");
    try { apply(await api("/api/advent/test/reset", { method: "POST", body: "{}" }), { announce: false }); } catch (e) { setError(e.message); }
  }
  function toggleTest() { setReveal(null); setConfirm(null); setPw(""); setPwMsg(""); setData(null); setTestMode(!testMode); }

  const serverNow = now + offset.current;
  if (!data) return <section className="advShell"><Snow count={40} /><div className="advLoading">{error || "Der Kalender wird ausgepackt …"}</div></section>;
  const start = new Date(data.starts_at).getTime();
  const next = data.doors.find((d) => !d.unlocked);
  const ready = data.doors.filter((d) => d.unlocked && !d.opened);
  const virus = data.virus;
  const virusLeft = virus ? new Date(virus.deadline).getTime() - serverNow : 0;

  return (
    <section className={`advShell${testMode ? " isTest" : ""}`}>
      <Snow />
      <div className="advAurora" aria-hidden="true" />
      <header className="advHero">
        <p className="advKicker"><Sparkles size={16} /> {data.year} · 24 Türchen · Geschenke, Aufgaben &amp; Bestrafungen</p>
        <h1><span>Marelles</span> Adventskalender</h1>
        {data.test ? (
          <p className="advLead">Testmodus: Alle 24 Türchen sind sofort offen – nur für Publisher sichtbar.</p>
        ) : serverNow < start ? (
          <><p className="advLead"><b>Türchen 1 kann geöffnet werden in:</b><br />(1. Dezember, 0:00 Uhr)</p><Countdown ms={start - serverNow} big /></>
        ) : next ? (
          <><p className="advLead">{ready.length ? `${ready.length} Türchen ${ready.length === 1 ? "wartet" : "warten"} aufs Öffnen!` : "Alle verfügbaren Türchen sind offen."} Nächstes Türchen ({next.day}) in:</p><Countdown ms={new Date(next.unlocks_at).getTime() - serverNow} /></>
        ) : <p className="advLead">Frohe Weihnachten! Alle 24 Türchen sind da.</p>}
        {(data.can_test || testMode) && (
          <div className="advTestBar">
            <button type="button" className={testMode ? "on" : ""} onClick={toggleTest} aria-pressed={testMode}><FlaskConical size={16} />{testMode ? "Testmodus beenden" : "Testmodus (nur Publisher)"}</button>
            {testMode && <button type="button" onClick={resetTest}><RotateCcw size={16} />Test zurücksetzen</button>}
          </div>
        )}
        {testMode && <p className="advTestNote" role="status">TESTMODUS – nichts hiervon ist echt. Zuschauer sehen davon nichts, der echte Kalender bleibt unberührt.</p>}
        <p className="advRole">{data.can_open ? "Du bist Admin: Klick auf ein leuchtendes Türchen, um es zu öffnen." : "Die Türchen öffnet ein Admin – live im Stream. Geöffnete Türchen kann jeder ansehen."}</p>
      </header>

      {virus && (
        <section className={`advVirus ${virus.off ? "off" : ""}`} aria-label="VIRUS-Countdown">
          <div className="advVirusHead"><Skull size={26} /><div><strong data-text={virus.off ? "VIRUS DEAKTIVIERT" : "VIRUS AKTIV"}>{virus.off ? "VIRUS DEAKTIVIERT" : "VIRUS AKTIV"}</strong><small>24-Stunden-Stream bis {new Date(virus.deadline).toLocaleDateString("de-DE", { day: "numeric", month: "long", year: "numeric" })} · {virus.months} Monate{virus.months < 6 ? " (1 Monat abgezogen!)" : ""}</small></div></div>
          <p className="advVirusText">{virus.off ? "Der 24-Stunden-Stream ist geschafft – der Virus wurde mit dem Passwort deaktiviert." : <>Bestrafung aus Türchen 1: Bis zum Ende dieses Countdowns <b>muss ein 24-Stunden-Stream</b> stattgefunden haben. Erst danach darf der Virus mit dem Passwort abgeschaltet werden. Öffnet sich das Türchen „ZEITMANAGEMENT“, wird 1 Monat abgezogen.</>}</p>
          {virus.off ? <p className="advVirusOff">Abgeschaltet am {dateLabel(virus.off.at)}.</p> : virusLeft > 0 ? <Countdown ms={virusLeft} /> : <p className="advVirusOff">ZEIT ABGELAUFEN!</p>}
          {!virus.off && (
            <form className="advVirusForm" onSubmit={virusOff}>
              <KeyRound size={16} />
              <input type="password" value={pw} onChange={(e) => setPw(e.target.value)} placeholder="Passwort zum Deaktivieren" aria-label="Passwort zum Deaktivieren" autoComplete="off" />
              <button type="submit" disabled={!pw}>Deaktivieren</button>
              {pwMsg && <span role="alert">{pwMsg}</span>}
            </form>
          )}
        </section>
      )}

      {error && <p className="advError" role="alert">{error}</p>}

      <div className="advGrid">
        {LAYOUT.map((day, slot) => {
          const door = data.doors[day - 1];
          const can = data.can_open && door.unlocked && !door.opened;
          const kind = door.item && KIND[door.item.kind];
          const Icon = kind?.icon;
          const state = door.opened ? "open" : door.unlocked ? "ready" : "locked";
          return (
            <div key={day} className={`advDoor ${state} ${WIDE.includes(day) ? "wide" : ""} ${opening === day ? "opening" : ""}`} style={{ "--wrap": WRAP[day % WRAP.length], "--i": slot }}>
              {door.opened && (
                <button type="button" className={`advInside ${kind.cls}`} onClick={() => setReveal(door)} aria-label={`Türchen ${day}: ${kind.label} – ${door.item.title}`}>
                  <Icon size={24} /><b>{kind.label}</b><span>{door.item.title}</span><em>{door.item.text}</em><i className="advMore">Details ansehen</i>
                </button>
              )}
              <button type="button" className="advLid" disabled={!can || busy} onClick={() => setConfirm(day)} aria-label={door.opened ? `Türchen ${day} ist offen` : door.unlocked ? `Türchen ${day} öffnen` : `Türchen ${day} – ab ${day}. Dezember`} tabIndex={door.opened ? -1 : 0}>
                <i className="advRibbonV" /><i className="advRibbonH" /><i className="advBow" />
                <strong>{day}</strong>
                {state === "locked" && <small><Lock size={12} /> {day}.12.</small>}
                {state === "ready" && <small className="advReadyTag">{data.can_open ? "Öffnen!" : "Bereit"}</small>}
              </button>
            </div>
          );
        })}
      </div>

      {confirm && (
        <div className="advModal" role="dialog" aria-modal="true" aria-label={`Türchen ${confirm} öffnen`} onClick={() => setConfirm(null)}>
          <div className="advConfirm" onClick={(e) => e.stopPropagation()}>
            <strong>{confirm}</strong>
            <h2>Türchen {confirm} öffnen?</h2>
            <p>Das lässt sich nicht rückgängig machen. Alle sehen sofort, was drin ist.</p>
            <div><button type="button" className="ghost" onClick={() => setConfirm(null)}>Noch nicht</button><button type="button" onClick={() => openDoor(confirm)}><Gift size={18} />Aufmachen!</button></div>
          </div>
        </div>
      )}

      <Confetti burst={burst} />
      {reveal && (() => {
        const kind = KIND[reveal.item.kind];
        const Icon = kind.icon;
        return (
          <div className="advModal" role="dialog" aria-modal="true" aria-label={`Türchen ${reveal.day}`} onClick={() => setReveal(null)}>
            <article className={`advReveal ${kind.cls}`} onClick={(e) => e.stopPropagation()} key={reveal.day}>
              <button type="button" className="advClose" onClick={() => setReveal(null)} aria-label="Schließen"><X size={20} /></button>
              <span className="advRays" aria-hidden="true" />
              <p className="advDay">Türchen {reveal.day}</p>
              <div className="advKind"><Icon size={42} /><strong data-text={`${kind.label}!`}>{kind.label}!</strong></div>
              <h2>{reveal.item.title}</h2>
              <p className="advText">{reveal.item.text}</p>
              {reveal.item.link && <a className="advLink" href={reveal.item.link} target="_blank" rel="noreferrer"><ExternalLink size={16} />Auf Steam ansehen</a>}
              <small>Geöffnet von {reveal.opened_by} · {dateLabel(reveal.opened_at)}</small>
            </article>
          </div>
        );
      })()}
    </section>
  );
}
