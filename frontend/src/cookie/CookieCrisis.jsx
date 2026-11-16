import React, { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { ArrowLeft, Cookie, Gift, Hand, Keyboard, Maximize, MousePointer2, Play, Sparkles, Star } from "lucide-react";
import { api } from "../api";
import "./cookie.css";

const GOAL = 1_000_000;
const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");

// The game itself is a Godot 3D game (games/cookie-crisis), exported for the web and served from
// /standalone/cookie-crisis/. It saves in this browser and – when you are logged in – in your account.
function GameWindow({ onClose }) {
  const root = useRef(null);
  useEffect(() => {
    const app = document.querySelector(".communityApp");
    const wasInert = app?.inert, overflow = document.body.style.overflow;
    if (app) app.inert = true;
    document.body.style.overflow = "hidden";
    return () => { if (app) app.inert = wasInert; document.body.style.overflow = overflow; };
  }, []);
  return createPortal(
    <section className="ccWindow" ref={root} aria-label="Santa's Cookie Crisis spielen">
      <header>
        <button type="button" onClick={onClose}><ArrowLeft size={17} /> Zurück zur Webseite</button>
        <span>Santa's Cookie Crisis</span>
        <button type="button" aria-label="Spiel im Vollbild öffnen" onClick={() => root.current?.requestFullscreen?.().catch(() => {})}><Maximize size={17} /></button>
      </header>
      <div className="ccWindowStage">
        <iframe title="Santa's Cookie Crisis – 3D-Spiel" src="/standalone/cookie-crisis/index.html" allow="autoplay; fullscreen; pointer-lock" data-testid="cookie-frame" />
      </div>
    </section>,
    document.body,
  );
}

export function CookieCrisis({ user, onLogin }) {
  const [playing, setPlaying] = useState(false);
  const [progress, setProgress] = useState(null);

  useEffect(() => {
    if (playing) return undefined;
    let alive = true;
    const local = () => {
      let best = null;
      try {
        for (let i = 0; i < localStorage.length; i++) {
          const k = localStorage.key(i);
          if (!k?.startsWith("aviary_cookie_save_")) continue;
          const st = JSON.parse(localStorage.getItem(k));
          if (st && (!best || st.baked > best.baked)) best = st;
        }
      } catch { /* no local save */ }
      return best;
    };
    (async () => {
      let st = local();
      if (user) {
        try { const r = await api("/api/cookie/save"); if (r?.save) { const remote = JSON.parse(r.save); if (!st || remote.baked > st.baked) st = remote; } } catch { /* offline */ }
      }
      if (alive) setProgress(st ? { baked: st.baked || 0, talers: st.talers || 0, finished: st.finished != null } : null);
    })();
    return () => { alive = false; };
  }, [user?.username, playing]);

  const pct = progress ? Math.min(100, (progress.baked / GOAL) * 100) : 0;
  return (
    <section className="ccLaunch" data-testid="cookie-game" aria-labelledby="cc-title">
      <div className="ccLaunchArt" aria-hidden="true">
        <span className="ccFlake f1">❄</span><span className="ccFlake f2">❄</span><span className="ccFlake f3">❄</span>
        <div className="ccHat" />
        <Cookie size={120} strokeWidth={1.2} />
      </div>
      <div className="ccLaunchCopy">
        <p className="ccKicker">3D-Weihnachtsabenteuer · Ich-Perspektive</p>
        <h2 id="cc-title">Santa's Cookie Crisis</h2>
        <p className="ccLead">Ein Elf. 25 Tonnen Teig. Eine Million Plätzchen.</p>
        <p>Draußen im Schnee liegt ein gewaltiger Teigberg. Greif den Teig mit deinen Händen, trag ihn in die Blockhaus-Backstube, roll ihn aus, stich Sterne aus und schick sie durch den glühenden Förderbandofen. Jeder Keks, der in die Kiste fällt, bringt dir einen Schokotaler. Mit dem Bestellbuch rüstest du auf – vom Holzeimer bis zur magischen Nordpol-Megafabrik.</p>
        {progress && (
          <div className="ccProgress" data-testid="cookie-progress">
            <div><b>{fmt(progress.baked)}</b> / 1.000.000 Kekse · {fmt(progress.talers)} Schokotaler</div>
            <span><i style={{ width: `${pct}%` }} /></span>
            {progress.finished && <em><Star size={14} /> Oberster Keksmeister des Nordpols</em>}
          </div>
        )}
        <button type="button" className="ccPlay" onClick={() => setPlaying(true)} data-testid="cookie-play"><Play size={20} /> {progress?.baked ? "Weiterbacken" : "Jetzt spielen"}</button>
        {!user && <p className="ccNote">Du spielst als Gast – dein Fortschritt bleibt in diesem Browser. <button type="button" className="ghost" onClick={onLogin}>Anmelden</button>, damit er in deinem Konto gespeichert wird und die Auszeichnung ins Profil kommt.</p>}
        <ul className="ccControls">
          <li><Keyboard size={16} /> <b>WASD</b> laufen, <b>Shift</b> rennen</li>
          <li><MousePointer2 size={16} /> Klick ins Spiel fängt die Maus · <b>Esc</b> gibt sie frei</li>
          <li><Hand size={16} /> <b>E</b> oder Klick arbeitet · <b>F</b> lässt fallen · <b>1–4</b> Werkzeuge</li>
          <li><Gift size={16} /> <b>Tab</b> öffnet das Weihnachts-Bestellbuch</li>
          <li><Sparkles size={16} /> <b>Leertaste</b> läuft zum nächsten sinnvollen Schritt</li>
        </ul>
      </div>
      {playing && <GameWindow onClose={() => setPlaying(false)} />}
    </section>
  );
}

export default CookieCrisis;
