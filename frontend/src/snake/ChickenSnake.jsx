import React, { useEffect, useRef, useState } from "react";
import { ArrowDown, ArrowLeft, ArrowRight, ArrowUp, Crown, Flag, Maximize, Minimize, Moon, Pause, Play, RefreshCw, Save, Trophy, Volume2, VolumeX } from "lucide-react";
import { api } from "../api";
import { useGameRewards } from "../economy/useGameRewards";
import { mountSnakeGame } from "./SnakeScene";
import "./snake.css";

const INITIAL = { status: "loading", score: 0, eggs: 0, level: 1, length: 5, combo: 0, reason: "" };
const KEYS = { arrowup: "up", w: "up", arrowdown: "down", s: "down", arrowleft: "left", a: "left", arrowright: "right", d: "right" };
const number = (value) => Number(value).toLocaleString("de-DE");

function readMuted() {
  try { return localStorage.getItem("aviary-snake-muted") === "true"; } catch { return false; }
}

function KeyHint() {
  return <span className="snakeKeyHint"><span><kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd></span><span>/ Pfeiltasten</span><i>·</i><span><kbd>P</kbd> Pause</span></span>;
}

// Mobile browsers can suppress the next synthesized click after a canvas swipe.
// Handle a completed touch directly, while preserving normal mouse/keyboard clicks.
function SnakeButton({ onClick, disabled, ...props }) {
  const touchHandled = useRef(false);
  return <button {...props} disabled={disabled}
    onPointerDown={() => { touchHandled.current = false; }}
    onPointerUp={(event) => {
      if (disabled || event.pointerType !== "touch") return;
      const bounds = event.currentTarget.getBoundingClientRect();
      if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) return;
      event.preventDefault(); touchHandled.current = true; onClick?.(event);
    }}
    onClick={(event) => {
      if (touchHandled.current && event.detail !== 0) { touchHandled.current = false; return; }
      touchHandled.current = false; onClick?.(event);
    }} />;
}

export function ChickenSnake({ user, renderScoreboard }) {
  const rewards = useGameRewards("chicken-snake", user);
  const root = useRef(null), canvas = useRef(null), scene = useRef(null);
  const actions = useRef({}), gesture = useRef(null), feedbackTimer = useRef(null);
  const mounted = useRef(false), submitLock = useRef(false);
  const [run, setRun] = useState(INITIAL);
  const [muted, setMuted] = useState(readMuted);
  const [expanded, setExpanded] = useState(false);
  const [fallbackFullscreen, setFallbackFullscreen] = useState(false);
  const [message, setMessage] = useState("");
  const [assetError, setAssetError] = useState("");
  const [assetAttempt, setAssetAttempt] = useState(0);
  const [feedback, setFeedback] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);
  const [record, setRecord] = useState(null);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; clearTimeout(feedbackTimer.current); };
  }, []);

  useEffect(() => {
    let disposed = false, game;
    setRun(INITIAL); setAssetError("");
    mountSnakeGame(canvas.current, (next) => { if (!disposed) setRun(next); }, (event) => {
      if (disposed) return;
      let text = "";
      if (event.type === "level") text = `Level ${event.level} · Das Tempo steigt!`;
      if (event.type === "eat" && event.combo > 1) text = `Sammelserie ×${event.combo}`;
      if (text) {
        clearTimeout(feedbackTimer.current); setFeedback(text);
        feedbackTimer.current = setTimeout(() => setFeedback(""), 1800);
      }
    }).then((instance) => {
      game = instance;
      if (disposed) { game.destroy(); return; }
      scene.current = game;
      game.setMuted(readMuted());
    }).catch((error) => { if (!disposed) setAssetError(error.message); });
    return () => { disposed = true; game?.destroy(); scene.current = null; };
  }, [assetAttempt]);

  useEffect(() => {
    let disposed = false;
    api("/api/scores/chicken-snake").then((rows) => {
      if (!disposed) setRecord(Math.max(0, ...rows.map((row) => Number(row.score) || 0)));
    }).catch(() => { /* An unavailable record must not prevent playing. */ });
    return () => { disposed = true; };
  }, [refreshKey]);

  useEffect(() => {
    function keydown(event) {
      if (event.target.closest?.("input,textarea,select,[contenteditable='true']")) return;
      const key = event.key.toLowerCase(), game = scene.current;
      if (!game) return;
      if (KEYS[key] && game.engine.status === "playing") {
        event.preventDefault(); game.turn(KEYS[key]);
      } else if (!event.repeat && (key === "p" || key === "escape")) {
        if (key === "escape" && actions.current.fallbackFullscreen) { actions.current.closeFullscreen(); return; }
        if (game.engine.status === "playing" || game.engine.status === "paused") {
          event.preventDefault(); game.togglePause();
        }
      } else if (!event.repeat && (key === " " || key === "enter") && !event.target.closest?.("button,a")) {
        if (game.engine.status === "ready") { event.preventDefault(); actions.current.start(); }
        else if (game.engine.status === "paused") { event.preventDefault(); game.togglePause(); }
      }
    }
    const pause = () => scene.current?.engine.pause();
    const visibility = () => { if (document.hidden) pause(); };
    window.addEventListener("keydown", keydown);
    window.addEventListener("blur", pause);
    document.addEventListener("visibilitychange", visibility);
    return () => {
      window.removeEventListener("keydown", keydown); window.removeEventListener("blur", pause);
      document.removeEventListener("visibilitychange", visibility);
    };
  }, []);

  useEffect(() => {
    const change = () => setExpanded(document.fullscreenElement === root.current);
    document.addEventListener("fullscreenchange", change);
    return () => document.removeEventListener("fullscreenchange", change);
  }, []);

  useEffect(() => {
    if (!fallbackFullscreen) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = previous; };
  }, [fallbackFullscreen]);

  function start() {
    if (!scene.current || submitLock.current) return;
    setMessage(""); setFeedback(""); clearTimeout(feedbackTimer.current);
    rewards.beginRound(); scene.current.start();
    canvas.current.focus({ preventScroll: true });
    root.current.querySelector(".snakeStage")?.scrollIntoView({ block: "nearest", behavior: "instant" });
  }

  async function save() {
    if (submitLock.current || rewards.submitted || scene.current?.engine.status !== "ended" || run.score <= 0) return;
    submitLock.current = true;
    try {
      const result = await rewards.submitRound({ score: run.score, level: run.level });
      if (!mounted.current) return;
      setMessage(result.message);
      setRecord((value) => Math.max(value || 0, run.score));
      setRefreshKey((value) => value + 1);
    } catch (error) { if (mounted.current) setMessage(error.message); }
    finally { submitLock.current = false; }
  }

  function toggleSound() {
    const next = !muted;
    setMuted(next); scene.current?.setMuted(next);
    try { localStorage.setItem("aviary-snake-muted", String(next)); } catch { /* Optional preference. */ }
  }

  async function fullscreen() {
    if (fallbackFullscreen) { setFallbackFullscreen(false); return; }
    try {
      if (document.fullscreenElement === root.current) await document.exitFullscreen();
      else if (root.current.requestFullscreen) await root.current.requestFullscreen();
      else setFallbackFullscreen(true);
    } catch { setFallbackFullscreen(true); }
  }

  actions.current = { start, fallbackFullscreen, closeFullscreen: () => setFallbackFullscreen(false) };

  function swipeStart(event) {
    if (scene.current?.engine.status !== "playing") return;
    event.preventDefault(); event.currentTarget.setPointerCapture(event.pointerId);
    gesture.current = { x: event.clientX, y: event.clientY, id: event.pointerId };
    event.currentTarget.focus({ preventScroll: true });
  }
  function swipeMove(event) {
    const from = gesture.current;
    if (!from || from.id !== event.pointerId) return;
    const dx = event.clientX - from.x, dy = event.clientY - from.y;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 18) return;
    scene.current?.turn(Math.abs(dx) > Math.abs(dy) ? dx > 0 ? "right" : "left" : dy > 0 ? "down" : "up");
    gesture.current = { x: event.clientX, y: event.clientY, id: event.pointerId };
  }

  const active = run.status === "playing", paused = run.status === "paused", ended = run.status === "ended";
  const fullscreenActive = expanded || fallbackFullscreen;
  const newRecord = ended && record !== null && run.score > record;
  const endTitle = run.reason === "won" ? "Der Garten gehört dir!" : run.reason === "collision" ? "Deine Spur war schneller." : "Gut geschlängelt!";

  return (
    <section ref={root} className={`snakeGame ${fallbackFullscreen ? "isExpanded" : ""}`} data-status={run.status} aria-label="Chicken Snake">
      <header className="snakeHeader">
        <div><h2>Chicken Snake</h2><p>Kleine Schlange. Große Ambitionen.</p></div>
        <dl className="snakeHud" aria-live="off">
          <div><dt>Score</dt><dd data-testid="snake-score">{number(run.score)}</dd></div>
          <div><dt>Level</dt><dd>{run.level}</dd></div>
          <div><dt>Rekord</dt><dd>{record === null ? "–" : number(record)}</dd></div>
        </dl>
      </header>

      <div className="snakeStage">
        <canvas ref={canvas} className="snakeCanvas" tabIndex={0} role="img" aria-label={`Chicken Snake Spielfeld. ${run.score} Punkte. Steuerung mit WASD oder Pfeiltasten, P für Pause.`}
          onPointerDown={swipeStart} onPointerMove={swipeMove} onPointerUp={() => { gesture.current = null; }}
          onPointerCancel={() => { gesture.current = null; }} onLostPointerCapture={() => { gesture.current = null; }} />
        <span className="snakeWorld"><Moon size={15} fill="currentColor" /> Nachtgarten</span>
        <div className="snakeStageTools">
          <SnakeButton type="button" aria-label={muted ? "Sound einschalten" : "Sound ausschalten"} title={muted ? "Sound einschalten" : "Sound ausschalten"} aria-pressed={!muted} onClick={toggleSound}>{muted ? <VolumeX size={20} /> : <Volume2 size={20} />}</SnakeButton>
          <SnakeButton type="button" aria-label={fullscreenActive ? "Vollbild schließen" : "Vollbild öffnen"} title={fullscreenActive ? "Vollbild schließen" : "Vollbild öffnen"} onClick={fullscreen}>{fullscreenActive ? <Minimize size={19} /> : <Maximize size={19} />}</SnakeButton>
        </div>
        {active && feedback && <div className="snakeFeedback" key={feedback}>{feedback}</div>}
        {!active && <div className={`snakeOverlay ${ended ? "isEnded" : ""} ${assetError ? "isError" : ""}`}>
          <div className="snakeOverlayContent">
            {ended && <span className="snakeEndIcon">{newRecord || run.reason === "won" ? <Crown size={26} /> : <Trophy size={24} />}</span>}
            <h3>{assetError ? "Ein Blatt hängt fest." : run.status === "loading" ? "Der Garten erwacht …" : paused ? "Einmal durchatmen." : ended ? endTitle : "Hungrig auf den Highscore?"}</h3>
            <p>{assetError || (paused ? "Dein Spiel wartet auf dich." : ended ? `${run.eggs} ${run.eggs === 1 ? "goldenes Ei" : "goldene Eier"} · Level ${run.level} · Länge ${run.length}` : "Sammle goldene Eier. Wachse über dich hinaus.")}</p>
            {ended && <strong className="snakeFinalScore">{number(run.score)}<span>Punkte</span></strong>}
            {newRecord && <p className="snakeRecordNotice">Neuer Rekord? Speichern und im Stream feiern!</p>}
            {ended && user && run.score > 0 && <SnakeButton type="button" className="snakePrimary" disabled={rewards.saving || rewards.submitted} onClick={save}>
              <Save size={18} /> {rewards.saving ? "Speichert …" : rewards.submitted ? "Runde gewertet" : "Score speichern"}
            </SnakeButton>}
            {ended && !user && <p className="snakeGuestHint"><a href="/#login">Melde dich an</a>, um Scores zu speichern und Chickens zu verdienen.</p>}
            <SnakeButton type="button" className={ended && user && run.score > 0 ? "snakeSecondary" : "snakePrimary"}
              disabled={(run.status === "loading" && !assetError) || rewards.saving}
              onClick={() => assetError ? setAssetAttempt((value) => value + 1) : paused ? scene.current?.togglePause() : start()}>
              {ended || assetError ? <RefreshCw size={18} /> : <Play size={19} fill="currentColor" />}
              {assetError ? "Erneut laden" : run.status === "loading" ? "Lade Spielwelt …" : paused ? "Weiterspielen" : ended ? "Nochmal spielen" : "Spiel starten"}
            </SnakeButton>
            {message && <p className="snakeSaveMessage" role="status">{message}</p>}
            {!ended && !assetError && <div className="snakeOverlayKeys"><KeyHint /></div>}
          </div>
        </div>}
      </div>

      <div className="snakeToolbar">
        <KeyHint />
        <span className="snakeLiveInfo">{run.eggs} {run.eggs === 1 ? "Ei" : "Eier"} <i>·</i> Länge {run.length}</span>
        <div className="snakeActions">
          <SnakeButton type="button" disabled={!active && !paused} onClick={() => scene.current?.togglePause()}>{paused ? <Play size={17} /> : <Pause size={17} />}{paused ? "Fortsetzen" : "Pause"}</SnakeButton>
          <SnakeButton type="button" disabled={!active && !paused} onClick={() => scene.current?.engine.finish()}><Flag size={16} /> Runde abschließen</SnakeButton>
        </div>
      </div>

      <div className="snakeMobileControls">
        <p>Wische im Spielfeld<br /><span>oder nutze die Pfeile.</span></p>
        <div className="snakeDpad" role="group" aria-label="Schlange steuern">
          {[["up", "Nach oben", ArrowUp], ["left", "Nach links", ArrowLeft], ["down", "Nach unten", ArrowDown], ["right", "Nach rechts", ArrowRight]].map(([direction, label, Icon]) =>
            <button type="button" className={`snakeDirection-${direction}`} key={direction} aria-label={label} disabled={!active}
              onPointerDown={(event) => { event.preventDefault(); scene.current?.turn(direction); }}
              onClick={() => scene.current?.turn(direction)}><Icon size={23} /></button>)}
        </div>
      </div>

      <div className="snakeBelow">
        <div className="snakeRecordGuide"><div className="snakeEggArt" aria-hidden="true" /><div><h3>Dein nächster Rekord</h3><p>Score speichern und Chickens sichern.</p><small>Ränder sind Portale. Deine eigene Spur ist die Gefahr.<br />10 Punkte pro Ei. Alle 5 Eier steigt das Tempo.</small></div></div>
        <div className="snakeScores"><h3><Trophy size={18} /> Rangliste</h3>{renderScoreboard?.(refreshKey)}</div>
      </div>
    </section>
  );
}
