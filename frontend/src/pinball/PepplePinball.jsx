import React, { useEffect, useRef, useState } from "react";
import { ArrowDown, ChevronsLeft, ChevronsRight, HelpCircle, Maximize, Minimize, Music, Pause, Play, RefreshCw, SlidersHorizontal, Volume2, VolumeX } from "lucide-react";
import { useGameRewards } from "../economy/useGameRewards";
import { MISSIONS } from "./engine.js";
import { HypeLayer } from "./hype.jsx";
import "./pinball.css";

const BEST_KEY = "pepple-pinball-best-v2";
const readBest = () => { try { return Number(localStorage.getItem(BEST_KEY)) || 0; } catch { return 0; } };
const writeBest = (v) => { try { localStorage.setItem(BEST_KEY, String(v)); } catch { /* storage blocked */ } };
const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const AUDIO_KEY = "pepple-pinball-audio-v1";
const readAudio = () => {
  const base = { sfx: 0.8, music: 0.7, sfxOn: true, musicOn: true };
  try { return { ...base, ...JSON.parse(localStorage.getItem(AUDIO_KEY) || "{}") }; } catch { return base; }
};
const INITIAL = { status: "loading", score: 0, ball: 1, ballsTotal: 3, bonusX: 1, locks: 0, missionsDone: [false, false, false, false, false], combo: 0, plunger: 0, stats: {} };

export function PepplePinball({ user, renderScoreboard }) {
  const rewards = useGameRewards("chicken-flipper", user);
  const stageRef = useRef(null), dmdRef = useRef(null), shellRef = useRef(null);
  const sys = useRef({});
  const [snap, setSnap] = useState(INITIAL);
  const [paused, setPaused] = useState(false);
  const [vol, setVol] = useState(readAudio);
  const [volOpen, setVolOpen] = useState(false);
  const [full, setFull] = useState(false);
  const [help, setHelp] = useState(false);
  const [message, setMessage] = useState("");
  const [best, setBest] = useState(readBest);
  const [refresh, setRefresh] = useState(0);
  const [error, setError] = useState("");
  const pausedRef = useRef(false);
  const [reducedMotion] = useState(() => { try { return matchMedia("(prefers-reduced-motion: reduce)").matches; } catch { return false; } });

  useEffect(() => {
    let cancelled = false, frame = 0;
    const s = sys.current;
    (async () => {
      try {
        const [{ PinballEngine }, { PinballRenderer }, { DMD }, { PinballAudio }] = await Promise.all([import("./engine.js"), import("./render.js"), import("./dmd.js"), import("./audio.js")]);
        if (cancelled) return;
        const engine = new PinballEngine();
        const audio = new PinballAudio();
        const saved = readAudio();
        audio.best = readBest();
        audio.sfxVolume = saved.sfx; audio.musicVolume = saved.music; audio.sfxOn = saved.sfxOn; audio.musicOn = saved.musicOn;
        const renderer = new PinballRenderer(stageRef.current, engine, { quality: matchMedia("(max-width: 720px)").matches ? "low" : "high" });
        const dmd = new DMD(dmdRef.current);
        Object.assign(s, { engine, audio, renderer, dmd });
        engine.on((type, d) => audio.handle(type, d));
        engine.on((type, d) => s.hype?.(type, d));
        engine.on((type, d) => { if (type === "gameOver") s.onGameOver?.(d); });
        stageRef.current.__pinball = s;
        await renderer.init();
        if (cancelled) return;
        let last = performance.now(), lastSnap = 0;
        const loop = (now) => {
          frame = requestAnimationFrame(loop);
          const dt = Math.min(0.05, (now - last) / 1000);
          last = now;
          if (!pausedRef.current) {
            engine.update(dt);
            renderer.render(dt);
            if (renderer.rolling) audio.setRolling(renderer.rolling.speed, renderer.rolling.height);
          }
          const view = engine.snapshot();
          dmd.render({ ...view, best: s.best }, engine.messages[0], engine.time);
          if (now - lastSnap > 100) { lastSnap = now; setSnap(view); }
        };
        frame = requestAnimationFrame(loop);
        setSnap(engine.snapshot());
      } catch (e) {
        if (!cancelled) { setError("Flipper konnte nicht laden: " + e.message); setSnap((v) => ({ ...v, status: "error" })); }
      }
    })();
    return () => {
      cancelled = true;
      cancelAnimationFrame(frame);
      s.renderer?.dispose();
      s.audio?.dispose();
      if (stageRef.current) delete stageRef.current.__pinball;
    };
  }, []);

  // Keep the latest callbacks reachable from the game loop.
  useEffect(() => {
    sys.current.best = best;
    if (sys.current.audio) sys.current.audio.best = best;
    sys.current.onGameOver = async ({ score }) => {
      if (score > best) { setBest(score); writeBest(score); }
      if (!user) { setMessage("Melde dich an, damit dein Score in die Rangliste kommt."); return; }
      try {
        const st = sys.current.engine.stats;
        const result = await rewards.submitRound({ score, level: Math.max(1, Math.min(10000, st.missions + 1)), round: Math.max(1, Math.min(1000, st.bestCombo || 1)) });
        setMessage(result.message);
        setRefresh((v) => v + 1);
      } catch (e) { setMessage(e.message); }
    };
  }, [best, user, rewards]);

  function start() {
    const s = sys.current;
    if (!s.engine) return;
    s.audio.ensure();
    rewards.beginRound();
    setMessage("");
    s.engine.start();
    setPausedState(false);
    shellRef.current?.scrollIntoView({ block: "start", behavior: "smooth" });
  }
  function setPausedState(v) {
    pausedRef.current = v; setPaused(v);
    const s = sys.current;
    s.audio?.pauseAll(v);
    if (v) { s.engine?.setFlipper("left", false); s.engine?.setFlipper("right", false); }
  }
  const togglePause = () => { const st = sys.current.engine?.status; if (st === "ready" || st === "play" || st === "bonus") setPausedState(!pausedRef.current); };

  // Fullscreen: native where the browser allows it, otherwise (iPhone) a fixed full-window cabinet.
  const fullRef = useRef(false);
  function setFullscreen(on) {
    const machine = shellRef.current?.querySelector(".pbMachine");
    fullRef.current = on; setFull(on);
    if (on) {
      const req = machine?.requestFullscreen || machine?.webkitRequestFullscreen;
      if (req) Promise.resolve(req.call(machine, { navigationUI: "hide" })).catch(() => {});
    } else if (document.fullscreenElement || document.webkitFullscreenElement) {
      Promise.resolve((document.exitFullscreen || document.webkitExitFullscreen)?.call(document)).catch(() => {});
    }
  }
  const toggleFull = () => setFullscreen(!fullRef.current);
  useEffect(() => {
    const sync = () => { if (!(document.fullscreenElement || document.webkitFullscreenElement) && fullRef.current) { fullRef.current = false; setFull(false); } };
    document.addEventListener("fullscreenchange", sync);
    document.addEventListener("webkitfullscreenchange", sync);
    return () => { document.removeEventListener("fullscreenchange", sync); document.removeEventListener("webkitfullscreenchange", sync); };
  }, []);

  // Keyboard.
  useEffect(() => {
    const typing = () => /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || "") || document.activeElement?.isContentEditable;
    const down = (e) => {
      const s = sys.current; if (!s.engine || typing()) return;
      const k = e.code;
      if (["Space", "ArrowLeft", "ArrowRight", "ArrowDown", "ArrowUp", "ShiftLeft", "ShiftRight"].includes(k) && stageRef.current?.isConnected) e.preventDefault();
      s.audio.ensure();
      const st = s.engine.status;
      if ((st === "attract" || st === "gameover") && (k === "Enter" || (k === "Space" && !e.repeat))) { start(); return; }
      if (k === "KeyF" && !e.repeat) { toggleFull(); return; }
      if (k === "Escape" && fullRef.current) { setFullscreen(false); return; }
      if (k === "KeyP" || k === "Escape") { if (!e.repeat) togglePause(); return; }
      if (pausedRef.current || e.repeat) return;
      if (k === "KeyA" || k === "ArrowLeft" || k === "ShiftLeft") s.engine.setFlipper("left", true);
      if (k === "KeyD" || k === "ArrowRight" || k === "ShiftRight") s.engine.setFlipper("right", true);
      if (k === "Space" || k === "ArrowDown" || k === "Enter" || k === "KeyS") s.engine.setPlunger(true);
      if (k === "KeyQ") s.engine.nudge(-1);
      if (k === "KeyE") s.engine.nudge(1);
      if (k === "KeyW" || k === "ArrowUp") s.engine.nudge(0);
    };
    const up = (e) => {
      const s = sys.current; if (!s.engine) return;
      const k = e.code;
      if (k === "KeyA" || k === "ArrowLeft" || k === "ShiftLeft") s.engine.setFlipper("left", false);
      if (k === "KeyD" || k === "ArrowRight" || k === "ShiftRight") s.engine.setFlipper("right", false);
      if (k === "Space" || k === "ArrowDown" || k === "Enter" || k === "KeyS") s.engine.setPlunger(false);
    };
    const blur = () => { const st = sys.current.engine?.status; if (st === "play" || st === "ready") setPausedState(true); };
    const vis = () => { if (document.hidden) blur(); };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    window.addEventListener("blur", blur);
    document.addEventListener("visibilitychange", vis);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); window.removeEventListener("blur", blur); document.removeEventListener("visibilitychange", vis); };
  });

  // Touch: left half / right half of the table are the flipper buttons.
  const touchSide = (e) => { const r = e.currentTarget.getBoundingClientRect(); return e.clientX - r.left < r.width / 2 ? "left" : "right"; };
  const onStageDown = (e) => {
    if (e.pointerType === "mouse") return;
    const s = sys.current; if (!s.engine || pausedRef.current) return;
    s.audio.ensure();
    const st = s.engine.status;
    if (st === "attract" || st === "gameover") return;
    const side = touchSide(e);
    try { e.currentTarget.setPointerCapture?.(e.pointerId); } catch { /* synthetic or already released pointer */ }
    (s.touches ||= new Map()).set(e.pointerId, side);
    s.engine.setFlipper(side, true);
  };
  const onStageUp = (e) => {
    const s = sys.current; const side = s.touches?.get(e.pointerId);
    if (!side) return;
    s.touches.delete(e.pointerId);
    if (![...s.touches.values()].includes(side)) s.engine.setFlipper(side, false);
  };
  const hold = (fnDown, fnUp) => ({
    onPointerDown: (e) => { e.preventDefault(); try { e.currentTarget.setPointerCapture?.(e.pointerId); } catch { /* ignore */ } sys.current.audio?.ensure(); fnDown(); },
    onPointerUp: fnUp, onPointerCancel: fnUp, onLostPointerCapture: fnUp,
  });

  const st = snap.status;
  const active = st === "ready" || st === "play" || st === "bonus";
  const updateVol = (patch) => {
    const next = { ...vol, ...patch };
    setVol(next);
    try { localStorage.setItem(AUDIO_KEY, JSON.stringify(next)); } catch { /* storage blocked */ }
    const a = sys.current.audio;
    if (!a) return;
    a.ensure();
    if ("sfx" in patch) a.setSfxVolume(next.sfx);
    if ("music" in patch) a.setMusicVolume(next.music);
    if ("sfxOn" in patch) a.setSfx(next.sfxOn);
    if ("musicOn" in patch) a.setMusic(next.musicOn);
    if ("sfx" in patch && next.sfxOn) a.play("bumper-ping", { gain: 0.5, gap: 0.12 });
  };

  return (
    <section className={`pbShell${full ? " pbFull" : ""}`} ref={shellRef} data-status={paused ? "paused" : st} aria-label="PEPPLE Pinball">
      <header className="pbHeader">
        <div><span>AFTER HOURS CLUB · FLIPPER</span><h2>PEPPLE Pinball</h2></div>
        <div className="pbTools">
          <button type="button" onClick={() => setHelp(!help)} aria-pressed={help} title="Regeln & Steuerung"><HelpCircle size={18} /></button>
          <button type="button" onClick={() => setVolOpen(!volOpen)} aria-expanded={volOpen} title="Lautstärke" aria-label="Lautstärke">{vol.sfxOn || vol.musicOn ? <Volume2 size={18} /> : <VolumeX size={18} />}</button>
          <button type="button" onClick={togglePause} disabled={!active} title={paused ? "Weiter" : "Pause"} aria-label={paused ? "Weiter" : "Pause"}>{paused ? <Play size={18} /> : <Pause size={18} />}</button>
          <button type="button" onClick={start} disabled={st === "loading" || st === "error"} title="Neues Spiel" aria-label="Neues Spiel"><RefreshCw size={18} /></button>
          <button type="button" onClick={toggleFull} title="Vollbild (F)" aria-label="Vollbild"><Maximize size={18} /></button>
        </div>
      </header>
      <div className="pbLayout">
        <div className="pbMachine">
          {full && (
            <div className="pbFsBar">
              <button type="button" onClick={() => setVolOpen(!volOpen)} aria-label="Lautstärke" title="Lautstärke"><SlidersHorizontal size={18} /></button>
              <button type="button" onClick={togglePause} disabled={!active} aria-label={paused ? "Weiter" : "Pause"} title={paused ? "Weiter" : "Pause"}>{paused ? <Play size={18} /> : <Pause size={18} />}</button>
              <button type="button" onClick={start} disabled={st === "loading" || st === "error"} aria-label="Neues Spiel" title="Neues Spiel"><RefreshCw size={18} /></button>
              <button type="button" onClick={() => setFullscreen(false)} aria-label="Vollbild beenden" title="Vollbild beenden (Esc)"><Minimize size={18} /></button>
            </div>
          )}
          {volOpen && (
            <div className="pbVolume" role="group" aria-label="Lautstärke">
              <div className="pbVolRow">
                <button type="button" onClick={() => updateVol({ sfxOn: !vol.sfxOn })} aria-pressed={!vol.sfxOn} aria-label={vol.sfxOn ? "Effekte stumm" : "Effekte an"}>{vol.sfxOn ? <Volume2 size={18} /> : <VolumeX size={18} />}</button>
                <label><span>Effekte</span><input type="range" min="0" max="100" value={Math.round(vol.sfx * 100)} aria-label="Lautstärke Effekte" onChange={(e) => updateVol({ sfx: Number(e.target.value) / 100, sfxOn: true })} /></label>
                <b>{vol.sfxOn ? Math.round(vol.sfx * 100) : 0}%</b>
              </div>
              <div className="pbVolRow">
                <button type="button" onClick={() => updateVol({ musicOn: !vol.musicOn })} aria-pressed={!vol.musicOn} aria-label={vol.musicOn ? "Musik stumm" : "Musik an"} className={vol.musicOn ? "" : "muted"}><Music size={18} /></button>
                <label><span>Musik</span><input type="range" min="0" max="100" value={Math.round(vol.music * 100)} aria-label="Lautstärke Musik" onChange={(e) => updateVol({ music: Number(e.target.value) / 100, musicOn: true })} /></label>
                <b>{vol.musicOn ? Math.round(vol.music * 100) : 0}%</b>
              </div>
              <button type="button" className="pbVolClose" onClick={() => setVolOpen(false)}>Fertig</button>
            </div>
          )}
          <canvas ref={dmdRef} className="pbDmd" aria-label={`Anzeige: ${fmt(snap.score)} Punkte`} role="img" />
          <div className="pbStage" ref={stageRef} onPointerDown={onStageDown} onPointerUp={onStageUp} onPointerCancel={onStageUp}>
            {st === "loading" && <div className="pbOverlay"><div className="pbSpinner" /><p>Tisch wird aufgebaut …</p></div>}
            {error && <div className="pbOverlay"><p>{error}</p></div>}
            {(st === "attract" || st === "gameover") && !error && (
              <div className="pbOverlay pbStart">
                {st === "gameover" ? <><span>LAST CALL</span><strong>{fmt(snap.score)}</strong>{snap.score >= best && snap.score > 0 && <em>Neuer Rekord!</em>}</> : <><span>AFTER HOURS CLUB</span><strong>PEPPLE</strong></>}
                <button type="button" onClick={start}><Play size={20} fill="currentColor" />{st === "gameover" ? "Nochmal spielen" : "Spiel starten"}</button>
                <small>Enter oder Leertaste</small>
                {st === "gameover" && <dl className="pbStats"><div><dt>Rampen</dt><dd>{snap.stats.ramps || 0}</dd></div><div><dt>Orbits</dt><dd>{snap.stats.orbits || 0}</dd></div><div><dt>Jackpots</dt><dd>{snap.stats.jackpots || 0}</dd></div><div><dt>Missionen</dt><dd>{snap.stats.missions || 0}</dd></div><div><dt>Beste Combo</dt><dd>{snap.stats.bestCombo || 0}x</dd></div></dl>}
              </div>
            )}
            {paused && <div className="pbOverlay pbStart"><span>PAUSE</span><strong>{fmt(snap.score)}</strong><button type="button" onClick={() => setPausedState(false)}><Play size={20} fill="currentColor" />Weiter</button></div>}
            {st === "ready" && !paused && <div className="pbPlungeHint">Leertaste halten & loslassen<br /><small>Flipper-Tasten verschieben die Skill-Shot-Bahn</small></div>}
            <HypeLayer sysRef={sys} snap={snap} best={best} reduced={reducedMotion} />
            <div className="pbPlungeMeter" aria-hidden="true"><i style={{ height: `${snap.plunger * 100}%` }} /><b /></div>
          </div>
          <div className="pbTouch">
            <button type="button" aria-label="Linker Flipper" {...hold(() => sys.current.engine?.setFlipper("left", true), () => sys.current.engine?.setFlipper("left", false))}><ChevronsLeft size={30} /></button>
            <button type="button" className="pbLaunch" aria-label="Plunger" {...hold(() => sys.current.engine?.setPlunger(true), () => sys.current.engine?.setPlunger(false))}><ArrowDown size={24} /></button>
            <button type="button" aria-label="Rechter Flipper" {...hold(() => sys.current.engine?.setFlipper("right", true), () => sys.current.engine?.setFlipper("right", false))}><ChevronsRight size={30} /></button>
          </div>
        </div>
        <aside className="pbSide">
          <div className="pbCard pbScore">
            <span>SCORE</span><strong>{fmt(snap.score)}</strong>
            <div className="pbRow"><em>Ball {Math.min(snap.ball, 3)}{snap.extraBalls ? ` +${snap.extraBalls}` : ""}</em><em>Bonus {snap.bonusX}x</em><em>Rekord {fmt(Math.max(best, snap.score))}</em></div>
          </div>
          <div className="pbCard">
            <h3>Missionen</h3>
            <ol className="pbMissions">
              {MISSIONS.map((m, i) => {
                const running = snap.mission?.name === m.name;
                return <li key={m.id} className={snap.missionsDone[i] ? "done" : running ? "running" : ""}><b>{"RTSVC"[i]}</b><span>{m.name}<small>{running ? `${snap.mission.progress}/${snap.mission.goal} · ${Math.ceil(snap.mission.left)} s` : m.hint}</small></span></li>;
              })}
            </ol>
            <p className="pbHint">{snap.wizard ? "LAST CALL läuft – jeder Schuss 1 Mio!" : snap.mission ? "Mission läuft!" : snap.missionLit ? "Mission bereit: DJ-Rampe (links) treffen!" : "2 Orbits schalten die nächste Mission frei."}</p>
          </div>
          <div className="pbCard pbLocks">
            <h3>VIP Lounge</h3>
            <div className="pbLockRow">{[0, 1, 2].map((i) => <i key={i} className={snap.locks > i ? "lit" : ""} />)}<span>{snap.multiball ? "MULTIBALL!" : snap.vipLit ? "Scoop offen – Lock holen!" : `${snap.locks}/3 Locks`}</span></div>
            {snap.extraBallLit && <p className="pbHint hot">Extra Ball an der Neon-Rampe (rechts)!</p>}
            {snap.combo >= 2 && <p className="pbHint hot">{snap.combo}-fach Combo läuft</p>}
          </div>
          {help && (
            <div className="pbCard pbHelp">
              <h3>Steuerung</h3>
              <ul>
                <li><kbd>A</kbd>/<kbd>←</kbd>/<kbd>Shift</kbd> linker · <kbd>D</kbd>/<kbd>→</kbd> rechter Flipper</li>
                <li><kbd>Leertaste</kbd> halten = Plunger spannen</li>
                <li><kbd>Q</kbd>/<kbd>E</kbd>/<kbd>W</kbd> Tisch anstoßen – zu oft = TILT</li>
                <li><kbd>P</kbd> Pause · <kbd>F</kbd> Vollbild · am Handy: linke/rechte Tischhälfte tippen</li>
              </ul>
              <h3>So holst du Punkte</h3>
              <ul>
                <li>Skill Shot: Plunger so dosieren, dass die Kugel in die blinkende B-A-R-Bahn fällt.</li>
                <li>B-A-R komplett: Bonus-Multiplikator +1 und Kickback.</li>
                <li>V-I-P-Ziele abräumen, dann den Scoop treffen: 3 Locks starten den Multiball. Danach alle 4 Jackpot-Pfeile und der Super Jackpot im Scoop.</li>
                <li>2 Orbits schalten eine Mission frei, gestartet wird sie an der DJ-Rampe. Alle 5 Missionen starten LAST CALL.</li>
                <li>Rampen und Orbits schnell hintereinander geben Combos.</li>
              </ul>
            </div>
          )}
          <div className="pbCard pbBoard">
            <h3>Top Scores</h3>
            {renderScoreboard?.(refresh)}
          </div>
        </aside>
      </div>
      {message && <p className="pbMessage" role="status">{message}</p>}
    </section>
  );
}
