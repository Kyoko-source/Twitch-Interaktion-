import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Expand, HelpCircle, LogIn, Music, Shrink, SlidersHorizontal, Trophy, Volume2, VolumeX } from "lucide-react";
import { api } from "../api";
import { publishWallet, requestId } from "../economy/useGameRewards";
import { SlotFx } from "../slots/fx.js";
import { DerbyAudio } from "./audio.js";
import { LOOKS, drawHorse } from "./horse.js";
import { DerbyScene } from "./scene.js";
import { DerbyStats } from "./DerbyStats.jsx";
import "../pinball/casino.css";
import "./horses.css";

const NAMES = ["Donnerhuf", "Goldmähne", "Sturmwind", "Mitternacht", "Feuerfunke", "Silberpfeil", "Kleiner Keks", "Royal Gacker", "Nebelläufer"];
const TAGLINES = ["Startet wie ein Gewitter.", "Glänzt bei Flutlicht.", "Liebt Gegenwind.", "Läuft am liebsten nachts.", "Heißblütig bis zum Ziel.", "Pfeilschnell auf der Geraden.", "Klein, aber gemein.", "Trägt die Krone des Hühnerhofs.", "Taucht aus dem Nichts auf."];
const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
// The finished race joins the all-time stats right away (the server counted it at booking).
const addRace = (stats, r) => (stats && !r.duplicate ? { ...stats, races: stats.races + 1, won: stats.won + (r.won ? 1 : 0), wins: stats.wins.map((w, i) => w + (i === r.winner ? 1 : 0)) } : stats);

function Portrait({ index, active, size = 150, skin = null }) {
  const ref = useRef(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return undefined;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = size, h = Math.round(size * 0.72);
    canvas.width = w * dpr; canvas.height = h * dpr;
    const c = canvas.getContext("2d");
    let raf = 0, phase = 0, last = performance.now();
    const draw = (now) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      phase = (phase + dt * 2.3) % 1;
      c.setTransform(dpr, 0, 0, dpr, 0, 0);
      c.clearRect(0, 0, w, h);
      const k = size / 150;
      c.translate(w * 0.47, h * 0.93); c.scale(k, k);
      drawHorse(c, { look: LOOKS[index], number: index + 1, phase, gait: active ? 1 : 0, time: now / 1000 + index, skin });
      if (active) raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [index, active, size, skin]);
  return <canvas ref={ref} className="hrPortrait" style={{ width: size, height: Math.round(size * 0.72) }} aria-hidden="true" />;
}

function VolumePanel({ audio }) {
  const [sfx, setSfx] = useState(audio.sfxVolume);
  const [music, setMusic] = useState(audio.musicVolume);
  return (
    <div className="hrVolume" role="group" aria-label="Lautstärke">
      <label><Volume2 size={15} aria-hidden="true" /><span>Effekte</span><input type="range" min="0" max="1" step="0.05" value={sfx} style={{ "--fill": `${sfx * 100}%` }} onChange={(e) => { const v = Number(e.target.value); setSfx(v); audio.setSfxVolume(v); }} /><b>{Math.round(sfx * 100)}</b></label>
      <label><Music size={15} aria-hidden="true" /><span>Musik</span><input type="range" min="0" max="1" step="0.05" value={music} style={{ "--fill": `${music * 100}%` }} onChange={(e) => { const v = Number(e.target.value); setMusic(v); audio.setMusicVolume(v); }} /><b>{Math.round(music * 100)}</b></label>
    </div>
  );
}

function CreditCounter({ from, to, ms, audio, onDone }) {
  const [value, setValue] = useState(from);
  const done = useRef(onDone);
  done.current = onDone;
  useEffect(() => {
    const start = performance.now();
    let raf = 0, last = 0;
    const step = (now) => {
      const t = Math.min(1, (now - start) / ms);
      const e = 1 - Math.pow(1 - t, 3);
      setValue(from + (to - from) * e);
      if (now - last > 60 && t < 1) { last = now; audio.play(`coin-${1 + Math.floor(Math.random() * 5)}`, { gain: 0.35 + t * 0.3, rate: 0.9 + t * 0.6, gap: 0.03 }); }
      if (t < 1) raf = requestAnimationFrame(step); else done.current?.();
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [from, to, ms, audio]);
  return <strong className="hrCount">{fmt(value)}</strong>;
}

export { NAMES, Portrait, CreditCounter };

export function HorseRace({ user, onLogin }) {
  const [info, setInfo] = useState(null);
  const [chosen, setChosen] = useState(-1);
  const [phase, setPhase] = useState("lobby");          // lobby | starting | countdown | race | result
  const [race, setRace] = useState(null);
  const [count, setCount] = useState(null);
  const [call, setCall] = useState(null);
  const [hud, setHud] = useState(null);
  const [result, setResult] = useState(null);           // { stage, ... }
  const [msg, setMsg] = useState("");
  const [help, setHelp] = useState(false);
  const [volume, setVolume] = useState(false);
  const [muted, setMuted] = useState(false);
  const [full, setFull] = useState(false);
  const shell = useRef(null);
  const stage = useRef(null);
  const canvas = useRef(null);
  const fxCanvas = useRef(null);
  const scene = useRef(null);
  const fx = useRef(null);
  const raceRef = useRef(null);
  const alive = useRef(true);
  const callTimer = useRef(0);
  const audio = useMemo(() => new DerbyAudio(), []);

  const quake = useCallback((strength = 1) => {
    const el = stage.current;
    if (!el || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    el.style.setProperty("--quake", String(strength));
    el.classList.remove("pbQuake"); void el.offsetWidth; el.classList.add("pbQuake");
    setTimeout(() => el.classList.remove("pbQuake"), 520);
  }, []);

  const showWin = useCallback(async (data) => {
    setResult({ stage: "flash", data });
    audio.music("multiball");
    audio.play("super-jackpot", { gain: 0.9 });
    audio.voiceFree = 0; audio.voice("vo-winner", 0.4);
    audio.roar(6);
    quake(2.4);
    fx.current?.burst("star", 0.5, 0.4, 60, 1.6);
    fx.current?.rain("feather", 8, 6);
    await sleep(1700);
    if (!alive.current) return;
    setResult({ stage: "double", data });
    audio.play("kickback", { gain: 0.9 });
    quake(2);
    await sleep(900);
    if (!alive.current) return;
    setResult({ stage: "count", data });
    fx.current?.rain("coin", 45, 3.5);
  }, [audio, quake]);

  const onEvent = useCallback((e) => {
    if (!alive.current) return;
    if (e.type === "count") setCount({ n: e.n, key: Math.random() });
    else if (e.type === "go") { setCount({ n: "LOS!", key: Math.random() }); setPhase("race"); audio.music("play"); quake(1.4); setTimeout(() => alive.current && setCount(null), 900); }
    else if (e.type === "call") {
      clearTimeout(callTimer.current);
      setCall({ ...e, key: Math.random() });
      callTimer.current = setTimeout(() => alive.current && setCall(null), e.big ? 2400 : 1900);
      if (e.big) quake(e.tone === "win" ? 2 : 0.9);
    } else if (e.type === "cross") {
      const r = raceRef.current;
      if (r?.won) { fx.current?.burst("star", 0.5, 0.5, 40, 1.4); fx.current?.fountain(40, 1.1); }
    } else if (e.type === "done") {
      const r = raceRef.current;
      if (!r) return;
      setPhase("result");
      if (r.won) showWin(r);
      else {
        setResult({ stage: "lose", data: r });
        audio.music("lobby");
        audio.play(r.place === 2 ? "mission-fail" : "game-over", { gain: 0.6 });
      }
      setInfo((i) => (i ? { ...i, wallet: r.wallet, recent: [r.winner, ...(i.recent || [])].slice(0, 10), stats: addRace(i.stats, r) } : i));
      publishWallet(user?.username, r.wallet);
    }
  }, [audio, quake, showWin, user?.username]);

  useEffect(() => {
    alive.current = true;
    scene.current = new DerbyScene(canvas.current, { audio, names: NAMES, onEvent: (e) => onEventRef.current(e), onHud: (h) => alive.current && setHud(h) });
    fx.current = fxCanvas.current ? new SlotFx(fxCanvas.current) : null;
    return () => { alive.current = false; scene.current?.dispose(); fx.current?.dispose(); audio.music(null); audio.dispose?.(); clearTimeout(callTimer.current); };
  }, [audio]);
  const onEventRef = useRef(onEvent);
  onEventRef.current = onEvent;

  useEffect(() => { scene.current?.setChosen(chosen); }, [chosen]);
  const unlockList = user?.unlocks || [];
  // The worn skin comes from the server (bought skins + level-25 Phönix); without it the level unlock decides.
  const skin = info?.skins ? info.skins.active : unlockList.includes("derby-phoenix") ? "phoenix" : null;
  useEffect(() => {
    scene.current?.setFlair({ crown: unlockList.includes("derby-crown"), champion: unlockList.includes("derby-champion"), phoenix: skin === "phoenix", skin });
  }, [unlockList.join(","), skin]);

  async function wearSkin(id) {
    try {
      const out = await api("/api/horses/skin", { method: "PUT", body: JSON.stringify({ skin: id }) });
      setInfo((i) => (i ? { ...i, skins: out.skins } : i));
      audio.ensure(); audio.play(id === "none" ? "drain" : "vip-lit", { gain: 0.6 });
    } catch (e) { setMsg(e.message); }
  }

  const load = useCallback(() => {
    if (!user) return;
    api("/api/horses").then(setInfo).catch((e) => setMsg(e.message));
  }, [user?.username]);
  useEffect(load, [load]);

  const stake = info?.stake ?? 50;
  const payout = info?.payout ?? 100;
  const credits = info?.wallet?.credits ?? 0;
  const shownCredits = race && phase !== "result" ? credits - (race.payout || 0) : credits;
  const busy = phase !== "lobby" && phase !== "result";

  async function startRace() {
    if (!user || busy) return;
    if (chosen < 0) { setMsg("Such dir zuerst ein Pferd aus!"); return; }
    if (credits < stake) { setMsg(`Ein Rennen kostet ${stake} Credits. Credits gibt es im Shop.`); return; }
    audio.ensure();
    setMsg(""); setResult(null); setCall(null); setHud(null);
    setPhase("starting");
    let data;
    try {
      data = await api("/api/horses/race", { method: "POST", body: JSON.stringify({ horse: chosen, request_id: requestId() }) });
    } catch (e) {
      setPhase("lobby"); setMsg(e.message); load(); return;
    }
    if (!alive.current) return;
    raceRef.current = data;
    setRace(data);
    setInfo((i) => (i ? { ...i, wallet: data.wallet } : i));
    publishWallet(user.username, { ...data.wallet, credits: data.wallet.credits - data.payout });
    setPhase("countdown");
    audio.music("play");
    scene.current?.start(data, chosen);
    shell.current?.scrollIntoView?.({ behavior: "smooth", block: "start" });
  }

  function again() {
    fx.current?.stopRain();
    setResult(null); setRace(null); raceRef.current = null; setCall(null); setHud(null); setCount(null);
    setPhase("lobby");
    scene.current?.reset();
    audio.music("lobby");
  }

  function toggleMute() {
    const next = !muted;
    setMuted(next);
    audio.setSfx(!next); audio.setMusic(!next);
  }

  useEffect(() => {
    const sync = () => setFull(document.fullscreenElement === shell.current);
    document.addEventListener("fullscreenchange", sync);
    return () => document.removeEventListener("fullscreenchange", sync);
  }, []);
  function toggleFull() {
    if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {});
    else shell.current?.requestFullscreen?.().catch(() => {});
  }

  const recentWins = useMemo(() => {
    const counts = Array(9).fill(0);
    for (const w of info?.recent || []) counts[w] += 1;
    return counts;
  }, [info?.recent]);
  const myLook = chosen >= 0 ? LOOKS[chosen] : null;
  const res = result?.data;

  return (
    <section ref={shell} className={`hrShell${full ? " isFull" : ""}`} aria-label="Chicken Derby">
      <header className="hrHeader">
        <div><span>AVIARY DOWNS · 9 PFERDE · 5 RUNDEN · SIEG = EINSATZ ×2</span><h2>Chicken Derby</h2></div>
        <div className="pbTools hrTools">
          <button type="button" onClick={() => setHelp(!help)} aria-pressed={help} title="Regeln" aria-label="Regeln"><HelpCircle size={18} /></button>
          <button type="button" onClick={() => setVolume(!volume)} aria-expanded={volume} title="Lautstärke" aria-label="Lautstärke"><SlidersHorizontal size={18} /></button>
          <button type="button" onClick={toggleMute} aria-pressed={muted} title={muted ? "Ton an" : "Ton aus"} aria-label={muted ? "Ton an" : "Ton aus"}>{muted ? <VolumeX size={18} /> : <Volume2 size={18} />}</button>
          <button type="button" onClick={toggleFull} title={full ? "Vollbild beenden" : "Vollbild"} aria-label={full ? "Vollbild beenden" : "Vollbild"}>{full ? <Shrink size={18} /> : <Expand size={18} />}</button>
          {volume && <VolumePanel audio={audio} />}
        </div>
      </header>

      <div className="hrLeds">
        <div><small>CREDITS</small><strong data-testid="derby-credits">{user ? fmt(shownCredits) : "–"}</strong></div>
        <div><small>EINSATZ</small><strong>{stake} CR</strong></div>
        <div className="hot"><small>BEI SIEG</small><strong>{payout} CR</strong></div>
        <div style={myLook ? { "--silk": myLook.silk } : undefined} className={myLook ? "mine" : ""}><small>DEIN PFERD</small><strong>{chosen >= 0 ? `#${chosen + 1} ${NAMES[chosen]}` : "–"}</strong></div>
      </div>

      <div className="hrStage" ref={stage}>
        <canvas ref={canvas} className="hrCanvas" aria-label="Rennbahn" role="img" />

        {call && (
          <div className={`hrCall tone-${call.tone}${call.big ? " big" : ""}`} key={call.key} aria-live="assertive">
            <span>{call.text}</span>
          </div>
        )}

        {hud && (phase === "race" || phase === "result") && race && (
          <>
            <div className="hrLap"><b>RUNDE {hud.lap}/{race.laps}</b><i style={{ "--p": hud.progress }} /></div>
            <ol className="hrBoard" aria-label="Live-Platzierung">
              {hud.order.map((id, i) => (
                <li key={id} className={id === chosen ? "me" : ""} style={{ "--silk": LOOKS[id].silk, "--silk2": LOOKS[id].silk2 }}>
                  <em>{i + 1}</em><span className="hrSilk" /><b>{NAMES[id]}</b>
                </li>
              ))}
            </ol>
            {chosen >= 0 && phase === "race" && <div className={`hrMine${hud.myRank === 1 ? " first" : ""}`} style={{ "--silk": LOOKS[chosen].silk }}><small>DEIN PFERD</small><b>PLATZ {hud.myRank}</b></div>}
          </>
        )}

        {count && <div className="hrCountdown" key={count.key}><b>{count.n}</b>{typeof count.n === "number" && <small>{NAMES[chosen]} wartet in Box {chosen + 1}</small>}</div>}

        {phase === "lobby" && !result && (
          <div className="hrLobbyBadge"><Trophy size={18} /> Wähle unten dein Pferd und starte das Rennen</div>
        )}

        {result?.stage && result.stage !== "lose" && res && (
          <div className={`pbCasino hrWin phase-${result.stage === "count" ? "total" : "mult"}`}>
            <span className="pbBeams" aria-hidden="true" />
            <span className="pbSpot left" aria-hidden="true" /><span className="pbSpot right" aria-hidden="true" />
            <span className="pbStrobe" aria-hidden="true" />
            <div className="hrWinPanel">
              <div className="hrWinTitle">SIEG!!!</div>
              <div className="hrWinHorse"><Portrait index={res.horse} active size={220} skin={skin} /><span className="hrLaurel" aria-hidden="true" /></div>
              <div className="hrWinName">#{res.horse + 1} {NAMES[res.horse]}</div>
              {result.stage === "flash" && <div className="hrWinSub">DEIN PFERD HAT GEWONNEN!</div>}
              {result.stage === "double" && <div className="hrDouble"><span>{res.stake}</span><b>×2</b></div>}
              {(result.stage === "count" || result.stage === "final") && (
                <div className="hrPayout">
                  <CreditCounter from={res.stake} to={res.payout} ms={2600} audio={audio} onDone={() => { if (!alive.current) return; audio.play("bonus-total", { gain: 0.9 }); quake(2.6); fx.current?.fountain(90, 1.4); setResult((r) => (r ? { ...r, stage: "final" } : r)); }} />
                  <small>CREDITS</small>
                </div>
              )}
              {result.stage === "final" && <button type="button" className="hrAgain" onClick={again}>Nächstes Rennen</button>}
            </div>
          </div>
        )}

        {result?.stage === "lose" && res && (
          <div className="hrLose">
            <div className="hrLosePanel">
              <small>{res.place === 2 ? "SO KNAPP!!!" : "DIESMAL NICHT"}</small>
              <div className="hrPlace">PLATZ {res.place}</div>
              <p><b>{NAMES[res.horse]}</b> wird {res.place}. – gewonnen hat <b>#{res.winner + 1} {NAMES[res.winner]}</b>.</p>
              <div className="hrLoseWinner"><Portrait index={res.winner} active size={150} /></div>
              <p className="hrLoseStake">−{res.stake} Credits</p>
              <button type="button" className="hrAgain" onClick={again}>Revanche!</button>
            </div>
          </div>
        )}

        <canvas ref={fxCanvas} className="hrFx" aria-hidden="true" />
      </div>

      {msg && <p className="hrMsg" role="alert">{msg}</p>}

      {(phase === "lobby" || phase === "starting") && (
        <div className="hrPicker">
          <div className="hrPickHead">
            <h3>Auf welches Pferd setzt du?</h3>
            <span>Jedes Pferd hat die gleiche Chance: 1 zu 9</span>
          </div>
          {info?.skins && (
            <div className="hrSkins" role="group" aria-label="Skin für dein Pferd">
              <small>DEIN SKIN</small>
              <button type="button" className={!skin ? "on" : ""} aria-pressed={!skin} onClick={() => wearSkin("none")}>Ohne</button>
              {info.skins.catalog.map((s) => s.owned ? (
                <button type="button" key={s.id} className={`skin-${s.id}${skin === s.id ? " on" : ""}`} aria-pressed={skin === s.id} onClick={() => wearSkin(s.id)}>{s.name}</button>
              ) : (
                <a key={s.id} className={`locked skin-${s.id}`} href="#shop" title={s.text}>🔒 {s.name}<em>{s.price ? `${fmt(s.price)} Chickens` : `Level ${s.level}`}</em></a>
              ))}
            </div>
          )}
          <div className="hrCards">
            {NAMES.map((name, i) => (
              <button type="button" key={name} className={`hrCard${chosen === i ? " on" : ""}`} onClick={() => { setChosen(i); audio.ensure(); if (!audio.track) audio.music("lobby"); audio.play("lane", { gain: 0.5, rate: 0.9 + i * 0.05 }); }} aria-pressed={chosen === i} style={{ "--silk": LOOKS[i].silk, "--silk2": LOOKS[i].silk2 }}>
                <span className="hrNum">{i + 1}</span>
                <Portrait index={i} active={chosen === i} size={132} skin={chosen === i ? skin : null} />
                <b>{name}</b>
                <small>{TAGLINES[i]}</small>
                <em>{recentWins[i] ? `${recentWins[i]}× gewonnen (letzte 10)` : "Noch kein Sieg zuletzt"}</em>
              </button>
            ))}
          </div>
          <div className="hrStartRow">
            {!user ? (
              <button type="button" className="hrStart" onClick={onLogin}><LogIn size={20} /> Anmelden & wetten</button>
            ) : credits < stake ? (
              <a className="hrStart buy" href="#shop">Credits kaufen ({stake} nötig)</a>
            ) : (
              <button type="button" className="hrStart" onClick={startRace} disabled={chosen < 0 || phase === "starting"}>
                {phase === "starting" ? "Pferde gehen in die Boxen …" : chosen < 0 ? "Erst ein Pferd wählen" : `RENNEN STARTEN · ${stake} CREDITS AUF ${NAMES[chosen].toUpperCase()}`}
              </button>
            )}
          </div>
          <p className="hrFine">Ein Rennen kostet {stake} Credits, die du auf dein Pferd setzt. Gewinnt es, bekommst du {payout} Credits zurück. Den Sieger lost der Server vor dem Start aus, jedes Pferd mit derselben Chance. Alles virtuell, kein echtes Geld.</p>
        </div>
      )}

      {help && (
        <div className="hrHelp">
          <h3>So läuft das Derby</h3>
          <ol>
            <li>Pferd auswählen und das Rennen für {stake} Credits starten. Dein Einsatz liegt auf diesem Pferd.</li>
            <li>10 Sekunden Countdown: Die Pferde stehen in den Startboxen.</li>
            <li>Fünf Runden über die Ovalbahn. Das Tempo wechselt ständig, die Führung auch.</li>
            <li>Gewinnt dein Pferd, verdoppelt sich dein Einsatz: {payout} Credits zurück. Sonst ist der Einsatz weg.</li>
          </ol>
        </div>
      )}

      {user && <DerbyStats stats={info?.stats} names={NAMES} />}
    </section>
  );
}
