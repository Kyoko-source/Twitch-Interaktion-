import React, { useEffect, useRef, useState } from "react";
import {
  ArrowUp,
  ChevronsLeft,
  ChevronsRight,
  Maximize,
  Pause,
  Play,
  RefreshCw,
  Save,
  Volume2,
  VolumeX,
  Zap,
} from "lucide-react";
import { api } from "../api";
import "./pinball.css";

const INITIAL = {
  status: "loading",
  score: 0,
  balls: 3,
  combo: 0,
  mult: 1,
  jackpot: 25000,
  bank: 0,
  plunger: 0,
  comboRemaining: 0,
  notice: "AFTER HOURS",
};

export function PepplePinball({ user, renderScoreboard }) {
  const host = useRef(null),
    gameRef = useRef(null),
    audioRef = useRef(true);
  const [run, setRun] = useState(INITIAL);
  const [audioOn, setAudioOn] = useState(true);
  const [message, setMessage] = useState("");
  const [refresh, setRefresh] = useState(0);
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    let cancelled = false,
      game;
    import("./PinballGame")
      .then(async ({ PinballGame }) => {
        if (cancelled) return;
        game = new PinballGame(host.current, {
          audioEnabledRef: audioRef,
          onSnapshot: setRun,
        });
        gameRef.current = game;
        await game.start();
      })
      .catch((e) => {
        if (!cancelled) {
          setMessage("Flipper konnte nicht laden: " + e.message);
          setRun((r) => ({ ...r, status: "error" }));
        }
      });
    return () => {
      cancelled = true;
      game?.dispose();
      gameRef.current = null;
    };
  }, []);
  function restart() {
    gameRef.current?.reset();
    setMessage("");
    host.current?.closest(".neonPinball")?.scrollIntoView({ block: "start" });
  }
  function toggleAudio() {
    audioRef.current = !audioRef.current;
    setAudioOn(audioRef.current);
    gameRef.current?.audio.setRolling(0);
    if (audioRef.current) gameRef.current?.audio.ensure();
  }
  async function save() {
    if (saving) return;
    setSaving(true);
    try {
      await api("/api/scores", {
        method: "POST",
        body: JSON.stringify({
          game: "chicken-flipper",
          score: run.score,
          level: run.level,
          round: Math.max(1, run.streak || run.combo),
        }),
      });
      setMessage("Score eingereicht.");
      setRefresh((v) => v + 1);
    } catch (e) {
      setMessage(e.message);
    } finally {
      setSaving(false);
    }
  }
  const active = ["ready", "play", "drain"].includes(run.status);
  const gameover = run.status === "gameover";
  const blocked = !active || run.status === "drain";
  const pointerDown = (e, action) => {
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    action();
  };
  return (
    <section
      className="neonPinball"
      data-status={run.status}
      aria-label="PEPPLE Pinball"
    >
      <header className="neonPinballHeader">
        <div>
          <span>AFTER HOURS / PINBALL CLUB</span>
          <h2>PEPPLE Pinball</h2>
        </div>
        <div className="pinballTools">
          <button
            type="button"
            title={audioOn ? "Sound ausschalten" : "Sound einschalten"}
            aria-label={audioOn ? "Sound ausschalten" : "Sound einschalten"}
            aria-pressed={!audioOn}
            onClick={toggleAudio}
          >
            {audioOn ? <Volume2 size={18} /> : <VolumeX size={18} />}
          </button>
          <button
            type="button"
            title={run.status === "paused" ? "Fortsetzen" : "Pause"}
            aria-label={run.status === "paused" ? "Fortsetzen" : "Pause"}
            disabled={!active && run.status !== "paused"}
            onClick={() => gameRef.current?.togglePause()}
          >
            {run.status === "paused" ? <Play size={18} /> : <Pause size={18} />}
          </button>
          <button
            type="button"
            title="Neu starten"
            aria-label="Neu starten"
            disabled={run.status === "loading" || run.status === "error"}
            onClick={restart}
          >
            <RefreshCw size={18} />
          </button>
          <button
            type="button"
            title="Vollbild"
            aria-label="Vollbild"
            onClick={() =>
              host.current
                ?.closest(".pinballMachine")
                ?.requestFullscreen?.()
                .catch(() => {})
            }
          >
            <Maximize size={18} />
          </button>
        </div>
      </header>
      <div className="pinballClubLayout">
        <div className="pinballMachine">
          <div className="pinballScoreStrip">
            <span>SCORE</span>
            <strong>
              {run.score.toLocaleString("de-DE").padStart(9, "0")}
            </strong>
            <b>x{run.mult}</b>
          </div>
          <div className="pinballStage">
            <div ref={host} className="pinballMount" />
            <div className="pinballLiveStatus">
              <span>{run.notice}</span>
              {run.ballSave && <b>BALL SAVE</b>}
            </div>
            <div
              className="pinballChargeTrack"
              aria-label="Plunger-Spannung"
              role="progressbar"
              aria-valuenow={Math.round(run.plunger * 100)}
              aria-valuemin={0}
              aria-valuemax={100}
            >
              <i style={{ height: run.plunger * 100 + "%" }} />
            </div>
            {!active && (
              <div className="pinballMenu">
                <span>
                  {gameover
                    ? "LAST CALL"
                    : run.status === "paused"
                      ? "PAUSED"
                      : "AFTER HOURS"}
                </span>
                <h3>
                  {gameover
                    ? run.score.toLocaleString("de-DE")
                    : run.status === "paused"
                      ? "Pause"
                      : "PEPPLE"}
                </h3>
                <button
                  type="button"
                  disabled={["loading", "error"].includes(run.status)}
                  onClick={() =>
                    run.status === "paused"
                      ? gameRef.current?.togglePause()
                      : restart()
                  }
                >
                  <Play size={19} fill="currentColor" />
                  {run.status === "loading"
                    ? "Lade ..."
                    : run.status === "paused"
                      ? "Weiter"
                      : gameover
                        ? "Neue Runde"
                        : "Spiel starten"}
                </button>
                {gameover && user && (
                  <button
                    type="button"
                    className="pinballSave"
                    disabled={saving}
                    onClick={save}
                  >
                    <Save size={16} />
                    {saving ? "Speichert ..." : "Score einreichen"}
                  </button>
                )}
              </div>
            )}
          </div>
          <div className="pinballTouchBar">
            <button
              type="button"
              title="Linker Flipper: A / Pfeil links"
              aria-label="Linker Flipper"
              disabled={blocked}
              onPointerDown={(e) =>
                pointerDown(e, () => gameRef.current?.setFlipper("left", true))
              }
              onPointerUp={() => gameRef.current?.setFlipper("left", false)}
              onPointerCancel={() => gameRef.current?.setFlipper("left", false)}
              onLostPointerCapture={() =>
                gameRef.current?.setFlipper("left", false)
              }
            >
              <ChevronsLeft size={28} />
            </button>
            <button
              type="button"
              className="pinballLaunch"
              title="Plunger: Leertaste halten und loslassen"
              aria-label="Plunger"
              disabled={run.status !== "ready"}
              onPointerDown={(e) =>
                pointerDown(e, () => gameRef.current?.charge(true))
              }
              onPointerUp={() => gameRef.current?.charge(false)}
              onPointerCancel={() => {
                if (gameRef.current) gameRef.current.keys.launch = false;
              }}
            >
              <ArrowUp size={23} />
              <Zap size={16} />
            </button>
            <button
              type="button"
              title="Rechter Flipper: D / Pfeil rechts"
              aria-label="Rechter Flipper"
              disabled={blocked}
              onPointerDown={(e) =>
                pointerDown(e, () => gameRef.current?.setFlipper("right", true))
              }
              onPointerUp={() => gameRef.current?.setFlipper("right", false)}
              onPointerCancel={() =>
                gameRef.current?.setFlipper("right", false)
              }
              onLostPointerCapture={() =>
                gameRef.current?.setFlipper("right", false)
              }
            >
              <ChevronsRight size={28} />
            </button>
          </div>
        </div>
        <aside className="pinballSession">
          <div className="pinballSessionRow">
            <span>BALLS</span>
            <div className="pinballBalls" aria-label={run.balls + " Kugeln"}>
              {[0, 1, 2].map((i) => (
                <i key={i} className={i < run.balls ? "lit" : ""} />
              ))}
            </div>
          </div>
          <div className="pinballComboPanel">
            <span>HIT COMBO</span>
            <strong>
              {run.combo.toString().padStart(2, "0")}
              <small> HITS</small>
            </strong>
            <div className="pinballComboTrack">
              <i style={{ width: run.comboRemaining * 100 + "%" }} />
            </div>
          </div>
          <div className="pinballJackpot">
            <span>JACKPOT</span>
            <strong>{run.jackpot.toLocaleString("de-DE")}</strong>
            <div className="pinballTargets" aria-label="Jackpot-Ziele">
              {[0, 1, 2, 3, 4].map((i) => (
                <i key={i} className={run.bank & (1 << i) ? "lit" : ""} />
              ))}
            </div>
          </div>
          <div className="pinballSessionRow">
            <span>MULTIPLIER</span>
            <strong>x{run.mult}</strong>
          </div>
          <div className="pinballScoreboard">
            <h3>Top Scores</h3>
            {renderScoreboard?.(refresh)}
          </div>
        </aside>
      </div>
      {message && (
        <p className="pinballMessage" role="status">
          {message}
        </p>
      )}
    </section>
  );
}
