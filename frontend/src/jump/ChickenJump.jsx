import React, { useEffect, useRef, useState } from "react";
import { ArrowDown, ArrowUp, Diamond, Flame, Music, Pause, Play, RefreshCw, Save, SlidersHorizontal, Sparkles, Trophy, Volume2, VolumeX, Zap } from "lucide-react";
import { useGameRewards } from "../economy/useGameRewards";
import "./jump.css";

const initial = { status: "loading", score: 0, distance: 0, pepples: 0, combo: 1, best: 0, maxCombo: 1, nearMisses: 0, record: false };
const ATLAS = { w: 1400, h: 674 };
const FRAME = { run: [0, 0, 275, 309], flap: [279, 0, 242, 273], duck: [525, 0, 282, 204] };

function ChickenArt({ frame = "run", height = 120, className = "" }) {
  const [x, y, w, h] = FRAME[frame];
  const k = height / h;
  return <span className={`jumpChickenArt ${className}`} aria-hidden="true" style={{ width: w * k, height, backgroundSize: `${ATLAS.w * k}px ${ATLAS.h * k}px`, backgroundPosition: `-${x * k}px -${y * k}px` }} />;
}

function VolumePanel({ scene, muted, onMute }) {
  const audio = scene?.audio;
  const [sfx, setSfx] = useState(audio?.sfxVolume ?? 0.8);
  const [music, setMusic] = useState(audio?.musicVolume ?? 0.6);
  return (
    <div className="jumpVolume" role="group" aria-label="Lautstärke">
      <label><Volume2 size={15} /> Effekte <input type="range" min="0" max="1" step="0.05" value={sfx} onChange={(e) => { const v = Number(e.target.value); setSfx(v); audio?.setSfxVolume(v); }} /><b>{Math.round(sfx * 100)}</b></label>
      <label><Music size={15} /> Musik <input type="range" min="0" max="1" step="0.05" value={music} onChange={(e) => { const v = Number(e.target.value); setMusic(v); audio?.setMusicVolume(v); }} /><b>{Math.round(music * 100)}</b></label>
      <button type="button" onClick={onMute}>{muted ? <><Volume2 size={15} /> Ton an</> : <><VolumeX size={15} /> Alles stumm</>}</button>
    </div>
  );
}

export function ChickenJump({ user, renderScoreboard }) {
  const rewards = useGameRewards("chicken-jump", user);
  const host = useRef(null);
  const scene = useRef(null);
  const [run, setRun] = useState(initial);
  const [muted, setMuted] = useState(false);
  const [volumeOpen, setVolumeOpen] = useState(false);
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  const [loadProgress, setLoadProgress] = useState(5);
  const [loadError, setLoadError] = useState("");
  const [loadAttempt, setLoadAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    let game;
    setRun(initial); setLoadError(""); setLoadProgress(5);
    const deadline = setTimeout(() => {
      if (cancelled || scene.current) return;
      setLoadError("Das Laden dauert zu lange. Bitte prüfe deine Verbindung und versuche es erneut.");
      setRun((current) => ({ ...current, status: "error" }));
    }, 20000);
    import("./JumpScene").then(({ mountJumpGame }) => {
      if (cancelled) return;
      setLoadProgress(30);
      game = mountJumpGame(host.current, (next) => { if (!cancelled) setRun(next); }, (nextScene) => {
        clearTimeout(deadline);
        if (cancelled) return;
        if (!nextScene.textures.exists("jump-sprites")) {
          setLoadError("Die Spielgrafik konnte nicht geladen werden. Bitte erneut versuchen.");
          setRun((current) => ({ ...current, status: "error" })); return;
        }
        scene.current = nextScene; nextScene.onRewardRunStart = rewards.beginRound; setLoadError(""); setLoadProgress(100);
      }, (value) => { if (!cancelled) setLoadProgress(value); });
    }).catch(() => {
      clearTimeout(deadline);
      if (!cancelled) { setLoadError("Das Spiel konnte nicht geladen werden. Bitte erneut versuchen."); setRun((current) => ({ ...current, status: "error" })); }
    });
    return () => {
      cancelled = true;
      clearTimeout(deadline);
      scene.current = null;
      game?.destroy(true);
    };
  }, [loadAttempt]);

  function restart() {
    setMessage("");
    setVolumeOpen(false);
    scene.current?.startRun();
    host.current?.closest(".jumpRunner")?.scrollIntoView({ block: "start" });
  }

  function toggleMute() {
    const next = !muted;
    setMuted(next);
    if (scene.current) scene.current.muted = next;
  }

  async function saveScore() {
    if (saving) return;
    setSaving(true);
    try {
      const result = await rewards.submitRound({ score: run.score, level: 1 + Math.floor(run.distance / 100) });
      setMessage(result.message);
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    } finally {
      setSaving(false);
    }
  }

  const active = run.status === "play";
  const ended = run.status === "gameover";
  const paused = run.status === "paused";
  const fmt = (n) => Math.floor(n).toLocaleString("de-DE");
  return (
    <section className="jumpRunner" data-status={run.status} aria-label="Chicken Jump">
      <header className="jumpRunnerHeader">
        <div><span className="jumpEdition">MEADOW RUN</span><h2>Chicken Jump</h2></div>
        <div className="jumpRunnerTools">
          <span className="jumpBest"><Trophy size={15} /> {fmt(run.best)}</span>
          <button type="button" title={muted ? "Sound einschalten" : "Sound ausschalten"} aria-label={muted ? "Sound einschalten" : "Sound ausschalten"} aria-pressed={muted} onClick={toggleMute}>{muted ? <VolumeX size={18} /> : <Volume2 size={18} />}</button>
          <button type="button" title="Lautstärke" aria-label="Lautstärke" aria-expanded={volumeOpen} className={volumeOpen ? "on" : ""} onClick={() => setVolumeOpen((v) => !v)}><SlidersHorizontal size={18} /></button>
          <button type="button" disabled={!active && !paused} title={active ? "Pause" : "Fortsetzen"} aria-label={active ? "Pause" : "Fortsetzen"} onClick={() => scene.current?.togglePause()}>{active ? <Pause size={18} /> : <Play size={18} />}</button>
          <button type="button" disabled={run.status === "loading"} title="Neu starten" aria-label="Neu starten" onClick={restart}><RefreshCw size={18} /></button>
          {volumeOpen && <VolumePanel scene={scene.current} muted={muted} onMute={toggleMute} />}
        </div>
      </header>
      <div className="jumpRunnerStats" aria-live="off">
        <div><span>PUNKTE</span><strong>{fmt(run.score)}</strong></div>
        <div><span>STRECKE</span><strong>{fmt(run.distance)}<small> m</small></strong></div>
        <div><span><Diamond size={12} /> FEDERN</span><strong>{run.pepples}</strong></div>
        <div><span>SAMMELKETTE</span><strong className={run.combo > 1 ? "jumpComboActive" : ""} data-combo={run.combo}>x{run.combo}</strong></div>
      </div>
      <div className="jumpRunnerStage">
        <div ref={host} className="jumpRunnerCanvas" role="application" aria-label="Chicken Jump Spielfeld" />
        {!active && <div className={`jumpRunnerOverlay ${ended ? "ended" : paused ? "paused" : "start"}`}>
          <div className="jumpCard">
            {ended && run.record && <span className="jumpRecord"><Sparkles size={14} /> NEUER REKORD <Sparkles size={14} /></span>}
            <span className="jumpOverlayTag">{ended ? "RUN BEENDET" : paused ? "KURZE VERSCHNAUFPAUSE" : "MEADOW RUN"}</span>
            {!ended && !loadError && <ChickenArt frame={paused ? "duck" : "run"} height={paused ? 74 : 104} className={paused ? "" : "bounce"} />}
            {ended && <ChickenArt frame="flap" height={84} className="tumble" />}
            <h3>{loadError ? "Ein kurzer Boxenstopp." : ended ? fmt(run.score) : paused ? "Pause" : "Chicken Jump"}</h3>
            {run.status === "loading" && <div className="jumpLoading"><progress max="100" value={loadProgress} aria-label="Spiel wird geladen" /><span>{loadProgress < 35 ? "Spiel-Engine wird geladen …" : "Grafik wird geladen …"} {loadProgress}%</span></div>}
            {loadError && <p role="status">{loadError}</p>}
            {ended && <div className="jumpEndStats">
              <div><span>Strecke</span><b>{fmt(run.distance)} m</b></div>
              <div><span>Federn</span><b>{run.pepples}</b></div>
              <div><span>Beste Kette</span><b>x{run.maxCombo}</b></div>
              <div><span>Knapp vorbei</span><b>{run.nearMisses}</b></div>
            </div>}
            {ended && <p className="jumpBestLine"><Trophy size={14} /> Bestwert {fmt(run.best)}</p>}
            {!ended && !paused && !loadError && run.status !== "loading" && <ul className="jumpHowTo">
              <li><kbd>Leertaste</kbd> springen · in der Luft nochmal = <b>Doppelsprung</b></li>
              <li><kbd>↓</kbd> ducken · in der Luft = Sturzflug</li>
              <li className="jumpPowers"><span className="pu shield"><Zap size={13} /> Schild</span><span className="pu magnet"><Diamond size={13} /> Magnet</span><span className="pu star"><Flame size={13} /> Doppelpunkte</span></li>
            </ul>}
            <button type="button" className="jumpPrimary" disabled={run.status === "loading"} onClick={() => loadError ? setLoadAttempt((value) => value + 1) : paused ? scene.current?.togglePause() : restart()}><Play size={20} fill="currentColor" /> {loadError ? "Erneut laden" : run.status === "loading" ? "Lade ..." : ended ? "Nochmal laufen" : paused ? "Weiterlaufen" : "Loslaufen"}</button>
            {ended && user && <button type="button" className="jumpSave" disabled={saving || rewards.submitted} onClick={saveScore}><Save size={16} /> {saving ? "Speichert ..." : rewards.submitted ? "Runde gewertet" : "Score & Chickens einreichen"}</button>}
          </div>
        </div>}
      </div>
      <div className="jumpRunnerFooter">
        <span className="jumpRunState">{active ? "RUNNING" : ended ? "FINISH" : paused ? "PAUSED" : "READY"}</span>
        <div className="jumpTouchControls">
          <button type="button" title="Ducken: S / Pfeil runter" aria-label="Ducken" disabled={!active} onPointerDown={(e) => { e.preventDefault(); e.currentTarget.setPointerCapture(e.pointerId); scene.current?.setDuck(true); }} onPointerUp={() => scene.current?.setDuck(false)} onPointerCancel={() => scene.current?.setDuck(false)} onLostPointerCapture={() => scene.current?.setDuck(false)}><ArrowDown size={24} /></button>
          <button type="button" title="Springen: Leertaste / W / Pfeil hoch" aria-label="Springen" disabled={!active} onPointerDown={(e) => { e.preventDefault(); e.currentTarget.setPointerCapture(e.pointerId); scene.current?.pressJump(); }} onPointerUp={() => scene.current?.releaseJump()} onPointerCancel={() => scene.current?.releaseJump()}><ArrowUp size={24} /></button>
        </div>
      </div>
      {message && <p className="jumpRunnerMessage" role="status">{message}</p>}
      <div className="jumpRunnerScores"><h3>Top Scores</h3>{renderScoreboard?.(refreshKey)}</div>
    </section>
  );
}
