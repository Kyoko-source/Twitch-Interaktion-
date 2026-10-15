import React, { useEffect, useRef, useState } from "react";
import { ArrowDown, ArrowUp, Diamond, Pause, Play, RefreshCw, Save, Trophy, Volume2, VolumeX } from "lucide-react";
import { useGameRewards } from "../economy/useGameRewards";
import "./jump.css";

const initial = { status: "loading", score: 0, distance: 0, pepples: 0, combo: 1, best: 0 };

export function ChickenJump({ user, renderScoreboard }) {
  const rewards = useGameRewards("chicken-jump", user);
  const host = useRef(null);
  const scene = useRef(null);
  const [run, setRun] = useState(initial);
  const [muted, setMuted] = useState(false);
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    let cancelled = false;
    let game;
    import("./JumpScene").then(({ mountJumpGame }) => {
      if (cancelled) return;
      game = mountJumpGame(host.current, setRun, (nextScene) => { scene.current = nextScene; nextScene.onRewardRunStart = rewards.beginRound; });
    }).catch(() => setMessage("Das Spiel konnte nicht geladen werden. Bitte neu laden."));
    return () => {
      cancelled = true;
      scene.current = null;
      game?.destroy(true);
    };
  }, []);

  function restart() {
    setMessage("");
    scene.current?.startRun();
    host.current?.closest(".jumpRunner")?.scrollIntoView({ block: "start" });
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
  return (
    <section className="jumpRunner" data-status={run.status} aria-label="Chicken Jump">
      <header className="jumpRunnerHeader">
        <div><span className="jumpEdition">MEADOW RUN</span><h2>Chicken Jump</h2></div>
        <div className="jumpRunnerTools">
          <span className="jumpBest"><Trophy size={15} /> {run.best.toLocaleString("de-DE")}</span>
          <button type="button" title={muted ? "Sound einschalten" : "Sound ausschalten"} aria-label={muted ? "Sound einschalten" : "Sound ausschalten"} aria-pressed={muted} onClick={() => {
            const next = !muted;
            setMuted(next);
            if (scene.current) scene.current.muted = next;
          }}>{muted ? <VolumeX size={18} /> : <Volume2 size={18} />}</button>
          <button type="button" disabled={!active && run.status !== "paused"} title={active ? "Pause" : "Fortsetzen"} aria-label={active ? "Pause" : "Fortsetzen"} onClick={() => scene.current?.togglePause()}>{active ? <Pause size={18} /> : <Play size={18} />}</button>
          <button type="button" disabled={run.status === "loading"} title="Neu starten" aria-label="Neu starten" onClick={restart}><RefreshCw size={18} /></button>
        </div>
      </header>
      <div className="jumpRunnerStats" aria-live="off">
        <div><span>PUNKTE</span><strong>{run.score.toLocaleString("de-DE")}</strong></div>
        <div><span>STRECKE</span><strong>{Math.floor(run.distance)}<small> m</small></strong></div>
        <div><span><Diamond size={12} /> FEDERN</span><strong>{run.pepples}</strong></div>
        <div><span>SAMMELKETTE</span><strong className={run.combo > 1 ? "jumpComboActive" : ""}>x{run.combo}</strong></div>
      </div>
      <div className="jumpRunnerStage">
        <div ref={host} className="jumpRunnerCanvas" role="application" aria-label="Chicken Jump Spielfeld" />
        {!active && <div className={`jumpRunnerOverlay ${ended ? "ended" : ""}`}>
          <span className="jumpOverlayTag">{ended ? "RUN BEENDET" : run.status === "paused" ? "KURZE VERSCHNAUFPAUSE" : "MEADOW RUN"}</span>
          <h3>{ended ? run.score.toLocaleString("de-DE") : run.status === "paused" ? "Pause" : "Chicken Jump"}</h3>
          {ended && <p>{Math.floor(run.distance)} m <span>/</span> {run.pepples} Federn <span>/</span> Best {run.best.toLocaleString("de-DE")}</p>}
          <button type="button" className="jumpPrimary" disabled={run.status === "loading"} onClick={() => run.status === "paused" ? scene.current?.togglePause() : restart()}><Play size={20} fill="currentColor" /> {run.status === "loading" ? "Lade ..." : ended ? "Nochmal laufen" : run.status === "paused" ? "Weiterlaufen" : "Loslaufen"}</button>
          {ended && user && <button type="button" className="jumpSave" disabled={saving || rewards.submitted} onClick={saveScore}><Save size={16} /> {saving ? "Speichert ..." : rewards.submitted ? "Runde gewertet" : "Score & Chickens einreichen"}</button>}
        </div>}
      </div>
      <div className="jumpRunnerFooter">
        <span className="jumpRunState">{active ? "RUNNING" : ended ? "FINISH" : run.status === "paused" ? "PAUSED" : "READY"}</span>
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
