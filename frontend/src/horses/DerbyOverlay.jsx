// Chicken Derby stream overlay (OBS browser source, 1920 × 1080): whenever someone on the site
// starts a race, the whole race takes over the stream as its own full-screen scene, in sync with
// the player's screen. Between races the page is fully transparent.
//   /stream/derby          live feed
//   /stream/derby?demo=1   endless demo races for setting up OBS
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { SlotFx } from "../slots/fx.js";
import { DerbyAudio } from "./audio.js";
import { CreditCounter, NAMES, Portrait } from "./HorseRace.jsx";
import { LOOKS } from "./horse.js";
import { demoRace, raceEnd } from "./race.mjs";
import { DerbyScene } from "./scene.js";
import "../pinball/casino.css";
import "./horses.css";
import "./overlay.css";

const COUNTDOWN = 10;
const RESULT_HOLD = 9000;
const MAX_AGE = 6 * 60;          // seconds; older queued races are dropped
let demoCount = 0;
// Demo bets win every other race so both endings can be checked while setting up OBS.
function makeDemo() {
  const race = demoRace();
  const won = demoCount++ % 2 === 0;
  const horse = won ? race.winner : race.order[1 + Math.floor(Math.random() * 8)];
  return { ...race, horse, won, place: race.order.indexOf(horse) + 1, username: "Vorschau", stake: 50, payout: won ? 100 : 0, id: `demo-${demoCount}` };
}
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");

export function DerbyOverlay() {
  const params = useMemo(() => new URLSearchParams(window.location.search), []);
  const demo = params.get("demo") === "1";
  const [show, setShow] = useState(null);          // the race on screen (with username)
  const [leaving, setLeaving] = useState(false);
  const [count, setCount] = useState(null);
  const [call, setCall] = useState(null);
  const [hud, setHud] = useState(null);
  const [result, setResult] = useState(null);
  const [racing, setRacing] = useState(false);
  const canvas = useRef(null);
  const fxCanvas = useRef(null);
  const stage = useRef(null);
  const scene = useRef(null);
  const fx = useRef(null);
  const current = useRef(null);
  const queue = useRef([]);
  const seen = useRef(new Set());
  const clock = useRef({ server: Date.now() / 1000, perf: performance.now() });
  const firstPoll = useRef(true);
  const alive = useRef(true);
  const callTimer = useRef(0);
  const audio = useMemo(() => new DerbyAudio(), []);
  const now = () => clock.current.server + (performance.now() - clock.current.perf) / 1000;

  useEffect(() => {
    document.documentElement.classList.add("derbyOverlay");
    try { JSON.parse(sessionStorage.getItem("aviary-derby-seen") || "[]").forEach((id) => seen.current.add(id)); } catch { /* optional in OBS */ }
    return () => document.documentElement.classList.remove("derbyOverlay");
  }, []);

  const remember = (id) => {
    seen.current.add(id);
    try { sessionStorage.setItem("aviary-derby-seen", JSON.stringify([...seen.current].slice(-100))); } catch { /* optional */ }
  };

  const quake = useCallback((strength = 1) => {
    const el = stage.current;
    if (!el) return;
    el.style.setProperty("--quake", String(strength));
    el.classList.remove("pbQuake"); void el.offsetWidth; el.classList.add("pbQuake");
    setTimeout(() => el.classList.remove("pbQuake"), 520);
  }, []);

  const next = useCallback(() => {
    if (current.current || !alive.current) return;
    let race;
    while ((race = queue.current.shift())) {
      if (demo || now() - race.created < MAX_AGE) break;
    }
    if (!race) return;
    current.current = race;
    // Live: join the player's timeline. Too late for that (it waited in the queue): from the top.
    let at = demo ? -COUNTDOWN : now() - race.created - COUNTDOWN;
    if (at > raceEnd(race) - 8) at = -COUNTDOWN;
    if (!demo) remember(race.id);
    audio.ensure();
    setResult(null); setCall(null); setHud(null); setCount(null); setLeaving(false);
    setRacing(at >= 0);
    setShow(race);
    scene.current.paused = false;
    scene.current.markLabel = String(race.username || "").slice(0, 16).toUpperCase() || null;
    scene.current.start(race, race.horse, at);
    audio.music("play");
  }, [audio, demo]);

  const finish = useCallback(async (race) => {
    if (race.won) {
      setResult({ stage: "flash" });
      audio.music("multiball"); audio.play("super-jackpot", { gain: 0.9 }); audio.voiceFree = 0; audio.voice("vo-winner", 0.4); audio.roar(6);
      quake(2.4); fx.current?.burst("star", 0.5, 0.4, 70, 1.6); fx.current?.rain("feather", 8, 6);
      await sleep(1700); if (!alive.current) return;
      setResult({ stage: "double" }); audio.play("kickback", { gain: 0.9 }); quake(2);
      await sleep(900); if (!alive.current) return;
      setResult({ stage: "count" }); fx.current?.rain("coin", 45, 3.5);
      await sleep(3200); if (!alive.current) return;
      audio.play("bonus-total", { gain: 0.9 }); quake(2.6); fx.current?.fountain(90, 1.4);
      setResult({ stage: "final" });
      await sleep(RESULT_HOLD - 5800);
    } else {
      setResult({ stage: "lose" });
      audio.play(race.place === 2 ? "mission-fail" : "game-over", { gain: 0.6 });
      await sleep(RESULT_HOLD);
    }
    if (!alive.current) return;
    setLeaving(true);
    audio.music(null);
    await sleep(900);
    if (!alive.current) return;
    fx.current?.stopRain();
    scene.current.paused = true;
    scene.current.reset();
    audio.silence();
    setShow(null); setResult(null); setHud(null); setCall(null); setLeaving(false);
    current.current = null;
    if (demo) { await sleep(4000); queue.current.push(makeDemo()); }
    next();
  }, [audio, demo, next, quake]);

  const onEvent = useCallback((e) => {
    if (!alive.current) return;
    const race = current.current;
    if (e.type === "count") setCount({ n: e.n, key: Math.random() });
    else if (e.type === "go") { setCount({ n: "LOS!", key: Math.random() }); setRacing(true); quake(1.4); setTimeout(() => alive.current && setCount(null), 900); }
    else if (e.type === "call") {
      clearTimeout(callTimer.current);
      setCall({ ...e, key: Math.random() });
      callTimer.current = setTimeout(() => alive.current && setCall(null), e.big ? 2400 : 1900);
      if (e.big) quake(e.tone === "win" ? 2 : 0.9);
    } else if (e.type === "cross") {
      if (race?.won) { fx.current?.burst("star", 0.5, 0.5, 50, 1.4); fx.current?.fountain(50, 1.1); }
    } else if (e.type === "done" && race) finish(race);
  }, [finish, quake]);
  const onEventRef = useRef(onEvent);
  onEventRef.current = onEvent;

  useEffect(() => {
    alive.current = true;
    scene.current = new DerbyScene(canvas.current, { audio, names: NAMES, onEvent: (e) => onEventRef.current(e), onHud: (h) => alive.current && setHud(h) });
    scene.current.paused = true;
    fx.current = new SlotFx(fxCanvas.current);
    return () => { alive.current = false; scene.current?.dispose(); fx.current?.dispose(); audio.music(null); audio.dispose?.(); clearTimeout(callTimer.current); };
  }, [audio]);

  // Live feed
  useEffect(() => {
    if (demo) {
      queue.current.push(makeDemo());
      const t = setTimeout(next, 600);
      return () => clearTimeout(t);
    }
    let timer = 0;
    const poll = async () => {
      try {
        const response = await fetch("/api/horses/live", { cache: "no-store", signal: AbortSignal.timeout(5000) });
        if (response.ok) {
          const data = await response.json();
          clock.current = { server: data.server_time, perf: performance.now() };
          for (const race of data.races || []) {
            if (seen.current.has(race.id) || queue.current.some((r) => r.id === race.id) || current.current?.id === race.id) continue;
            // On (re)load only races that are still running are shown; finished ones are history.
            if (firstPoll.current && now() - race.created - COUNTDOWN > raceEnd(race) + 1) { seen.current.add(race.id); continue; }
            queue.current.push(race);
          }
          firstPoll.current = false;
          next();
        }
      } catch { /* keep polling */ }
      if (alive.current) timer = setTimeout(poll, 1500);
    };
    poll();
    return () => clearTimeout(timer);
  }, [demo, next]);

  const race = show;
  const look = race ? LOOKS[race.horse] : null;
  const user = race ? String(race.username || "Jemand").slice(0, 32) : "";

  return (
    <div className={`hrShell doShell${race ? " on" : ""}${leaving ? " leaving" : ""}`}>
      <div className="doStage hrStage" ref={stage}>
        <canvas ref={canvas} className="hrCanvas" aria-hidden="true" />
        {race && (
          <>
            <div className="doLive"><i /> LIVE · CHICKEN DERBY</div>

            {!racing && !result && (
              <div className="doIntro" style={{ "--silk": look.silk }}>
                <div className="doIntroHorse"><Portrait index={race.horse} active size={260} /></div>
                <div className="doIntroText">
                  <b>{user}</b>
                  <span>setzt <em>{fmt(race.stake)} Credits</em> auf</span>
                  <strong>#{race.horse + 1} {NAMES[race.horse]}</strong>
                  <small>Sieg = {fmt(race.stake * 2)} Credits</small>
                </div>
              </div>
            )}

            {call && <div className={`hrCall tone-${call.tone}${call.big ? " big" : ""}`} key={call.key}><span>{call.text}</span></div>}

            {hud && racing && (
              <>
                <div className="hrLap"><b>RUNDE {hud.lap}/{race.laps}</b><i style={{ "--p": hud.progress }} /></div>
                <ol className="hrBoard">
                  {hud.order.map((id, i) => (
                    <li key={id} className={id === race.horse ? "me" : ""} style={{ "--silk": LOOKS[id].silk, "--silk2": LOOKS[id].silk2 }}>
                      <em>{i + 1}</em><span className="hrSilk" /><b>{NAMES[id]}</b>
                    </li>
                  ))}
                </ol>
                {!result && <div className={`hrMine doMine${hud.myRank === 1 ? " first" : ""}`} style={{ "--silk": look.silk }}><small>{user} · {NAMES[race.horse]}</small><b>PLATZ {hud.myRank}</b></div>}
              </>
            )}

            {count && <div className="hrCountdown" key={count.key}><b>{count.n}</b></div>}

            {result && result.stage !== "lose" && (
              <div className={`pbCasino hrWin phase-${result.stage === "count" || result.stage === "final" ? "total" : "mult"}`}>
                <span className="pbBeams" /><span className="pbSpot left" /><span className="pbSpot right" /><span className="pbStrobe" />
                <div className="hrWinPanel">
                  <div className="hrWinTitle">SIEG!!!</div>
                  <div className="hrWinHorse"><Portrait index={race.horse} active size={220} /><span className="hrLaurel" /></div>
                  <div className="hrWinName">{user} gewinnt mit #{race.horse + 1} {NAMES[race.horse]}!</div>
                  {result.stage === "flash" && <div className="hrWinSub">DER EINSATZ VERDOPPELT SICH!</div>}
                  {result.stage === "double" && <div className="hrDouble"><span>{race.stake}</span><b>×2</b></div>}
                  {(result.stage === "count" || result.stage === "final") && (
                    <div className="hrPayout"><CreditCounter from={race.stake} to={race.payout} ms={2600} audio={audio} /><small>CREDITS FÜR {user.toUpperCase()}</small></div>
                  )}
                </div>
              </div>
            )}

            {result?.stage === "lose" && (
              <div className="hrLose">
                <div className="hrLosePanel">
                  <small>{race.place === 2 ? "SO KNAPP!!!" : "DIESMAL NICHT"}</small>
                  <div className="hrPlace">PLATZ {race.place}</div>
                  <p><b>{user}</b> setzte auf <b>{NAMES[race.horse]}</b> – gewonnen hat <b>#{race.winner + 1} {NAMES[race.winner]}</b>.</p>
                  <div className="hrLoseWinner"><Portrait index={race.winner} active size={150} /></div>
                  <p className="hrLoseStake">−{fmt(race.stake)} Credits</p>
                </div>
              </div>
            )}
          </>
        )}
        <canvas ref={fxCanvas} className="hrFx" aria-hidden="true" />
      </div>
    </div>
  );
}
