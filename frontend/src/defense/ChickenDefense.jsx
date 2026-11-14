import React, { useCallback, useEffect, useRef, useState } from "react";
import { ChevronsRight, Coins, Crosshair, Egg, Expand, FastForward, Flag, Lock, Music, Pause, Play, RefreshCw, Save, Shrink, Swords, Trash2, Trophy, Volume2, VolumeX, Zap } from "lucide-react";
import { useGameRewards } from "../economy/useGameRewards";
import { CHAOS_MODS, COLS, DefenseEngine, MAX_LEVEL, ROWS, START_EGGS, TOWERS, TOWER_ORDER, branchCost, towerStats, upgradeCost } from "./engine.mjs";
import { DefenseRenderer, drawTower, T } from "./render.js";
import { DefenseAudio } from "./audio.js";
import "./defense.css";

const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const TARGETING = { first: "Vorderster", strong: "Stärkster", last: "Hinterster" };

function TowerIcon({ kind, size = 52, level = 1, branch = null }) {
  const ref = useRef(null);
  useEffect(() => {
    const c = ref.current, dpr = Math.min(2, window.devicePixelRatio || 1);
    c.width = size * dpr; c.height = size * dpr;
    const ctx = c.getContext("2d");
    ctx.scale(dpr * (size / 52), dpr * (size / 52));
    ctx.translate(26, 30);
    drawTower(ctx, kind, level, -0.6, 0, false, 0, branch);
  }, [kind, size, level, branch]);
  return <canvas ref={ref} className="cdTowerIcon" style={{ width: size, height: size }} aria-hidden="true" />;
}

function useCountUp(value, ms = 1400) {
  const [v, setV] = useState(0);
  useEffect(() => {
    const start = performance.now();
    let f = 0;
    const step = (now) => { const t = Math.min(1, (now - start) / ms); setV(value * (1 - Math.pow(1 - t, 3))); if (t < 1) f = requestAnimationFrame(step); };
    f = requestAnimationFrame(step);
    return () => cancelAnimationFrame(f);
  }, [value, ms]);
  return v;
}

function FinalScore({ value }) { return <strong className="cdFinal">{fmt(useCountUp(value))}<span>Punkte</span></strong>; }

export function ChickenDefense({ user, renderScoreboard }) {
  const rewards = useGameRewards("chicken-defense", user);
  const root = useRef(null), canvas = useRef(null);
  const sys = useRef({});
  const [snap, setSnap] = useState({ status: "ready", wave: 0, korn: 0, eggs: START_EGGS, score: 0, kills: 0, waveActive: false, queued: 0, mods: [] });
  const [placing, setPlacing] = useState(null);
  const [selected, setSelected] = useState(null);
  const [speed, setSpeed] = useState(1);
  const [paused, setPaused] = useState(false);
  const [sfxOn, setSfxOn] = useState(true);
  const [musicOn, setMusicOn] = useState(true);
  const [full, setFull] = useState(false);
  const [message, setMessage] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);
  const speedRef = useRef(1), pausedRef = useRef(false);
  speedRef.current = speed; pausedRef.current = paused;

  const sync = useCallback(() => {
    const e = sys.current.engine;
    if (!e) return;
    setSnap({ status: e.status, wave: e.wave, korn: e.korn, eggs: e.eggs, score: e.score, kills: e.kills, waveActive: e.waveActive, queued: e.queue.length, mods: e.mods, enemies: e.enemies.length });
  }, []);

  // ---------------------------------------------------------------- setup + loop
  useEffect(() => {
    const audio = new DefenseAudio();
    const engine = new DefenseEngine({ onEvent: (ev) => onEvent(ev) });
    const renderer = new DefenseRenderer(canvas.current, engine);
    sys.current = { engine, renderer, audio, startedAt: 0 };
    canvas.current.__defense = sys.current;
    function onEvent(ev) {
      renderer.event(ev);
      const a = audio;
      switch (ev.type) {
        case "shoot": a.play(ev.tower.kind); break;
        case "explode": a.play(ev.kind === "shell" || ev.kind === "rocket" ? "boom" : "frost"); break;
        case "zap": a.play(ev.magic ? "wizard" : "tesla"); break;
        case "snipe": a.play("sniper"); if (ev.crit) a.play("crit"); break;
        case "pulse": a.play("pulse"); break;
        case "freeze": a.play("freeze"); break;
        case "shielded": a.play("shield"); break;
        case "revive": a.play("revive"); a.voice("vo-flawless"); break;
        case "kill": a.play("kill", { rate: 0.9 + Math.random() * 0.4 }); if (ev.bounty >= 100) { a.play("bossDown"); a.voice("vo-flawless"); } break;
        case "leak": a.play("leak"); break;
        case "build": a.play("build"); break;
        case "upgrade": a.play("upgrade"); break;
        case "sell": a.play("sell"); break;
        case "waveStart":
          a.play("wave");
          if (ev.boss) { a.play("boss"); a.voice("vo-sudden-death"); }
          else if (ev.mods.length) { a.play("chaos"); a.voice("vo-hurry"); }
          else if (ev.wave === 1) a.voice("vo-fight");
          a.music(ev.boss || ev.wave >= 15 ? "chaos" : ev.wave >= 6 ? "battle" : "calm");
          break;
        case "pathOpen": a.play("rumble"); a.play("chaos"); break;
        case "waveClear": a.play("clear"); if (engine.wave < 15) a.music(engine.wave >= 5 ? "battle" : "calm"); break;
        case "gameOver": a.play("over"); a.voice("vo-over"); a.music(null); break;
        default: break;
      }
      if (["kill", "leak", "build", "upgrade", "sell", "waveStart", "waveClear", "gameOver", "revive", "shielded"].includes(ev.type)) sync();
    }
    let frame = 0, last = performance.now(), acc = 0, lastSync = 0;
    const loop = (now) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      if (!pausedRef.current && engine.status === "playing" && !document.hidden) {
        acc += dt * speedRef.current;
        const step = 1 / 60;
        let n = 0;
        while (acc >= step && n < 12) { engine.update(step); acc -= step; n++; }
        if (now - lastSync > 150) { lastSync = now; sync(); }
      }
      if (engine.towers.some((t) => t.firing) && !pausedRef.current) audio.play("beam");
      renderer.draw(now / 1000, pausedRef.current ? 0 : dt * Math.min(1.5, speedRef.current));
      frame = requestAnimationFrame(loop);
    };
    frame = requestAnimationFrame(loop);
    sync();
    return () => { cancelAnimationFrame(frame); audio.dispose(); delete canvas.current?.__defense; };
  }, [sync]);

  useEffect(() => { if (sys.current.renderer) sys.current.renderer.ui.placing = placing; }, [placing]);
  useEffect(() => { if (sys.current.renderer) sys.current.renderer.ui.selected = selected; }, [selected]);
  useEffect(() => { sys.current.audio?.pause(paused); }, [paused]);

  // ---------------------------------------------------------------- actions
  function start() {
    const { engine, audio } = sys.current;
    audio.unlock(); audio.play("start"); audio.voice("vo-ready");
    engine.start();
    sys.current.startedAt = performance.now();
    rewards.beginRound();
    setPlacing(null); setSelected(null); setPaused(false); setMessage("");
    audio.music("calm");
    sync();
  }
  function nextWave() {
    const { engine, audio } = sys.current;
    audio.unlock();
    if (engine.startWave()) sync();
  }
  function choose(kind) {
    const e = sys.current.engine;
    if (e.status !== "playing") return;
    if (Math.max(1, e.wave) < TOWERS[kind].unlock) return;
    setSelected(null);
    setPlacing((p) => (p === kind ? null : kind));
  }
  function tileFromEvent(ev) {
    const r = canvas.current.getBoundingClientRect();
    const c = Math.floor(((ev.clientX - r.left) / r.width) * COLS), row = Math.floor(((ev.clientY - r.top) / r.height) * ROWS);
    return { c: Math.max(0, Math.min(COLS - 1, c)), r: Math.max(0, Math.min(ROWS - 1, row)) };
  }
  function onMove(ev) { if (sys.current.renderer) sys.current.renderer.ui.hover = tileFromEvent(ev); }
  function onLeave() { if (sys.current.renderer) sys.current.renderer.ui.hover = null; }
  function onClick(ev) {
    const { engine, audio } = sys.current;
    if (engine.status !== "playing") return;
    audio.unlock();
    const { c, r } = tileFromEvent(ev);
    sys.current.renderer.ui.hover = { c, r };
    if (placing) {
      const t = engine.build(placing, c, r);
      if (t && engine.korn < TOWERS[placing].cost) setPlacing(null);
      if (!t) audio.play("leak", { gain: 0.3, rate: 1.6 });
      return;
    }
    const tower = engine.towerAt(c, r);
    setSelected(tower ? tower.id : null);
  }
  function upgrade(branch = null) { const { engine } = sys.current; if (selected && engine.upgrade(selected, branch)) sync(); }
  function sell() { const { engine } = sys.current; if (selected && engine.sell(selected)) { setSelected(null); sync(); } }
  function cycleTargeting() { if (selected) { sys.current.engine.cycleTargeting(selected); sync(); } }

  async function save() {
    try {
      const seconds = Math.round((performance.now() - (sys.current.startedAt || performance.now())) / 1000);
      const result = await rewards.submitRound({ score: snap.score, level: Math.max(1, snap.wave), kills: snap.kills, seconds_survived: Math.min(7200, seconds) });
      setMessage(result.message); setRefreshKey((k) => k + 1);
    } catch (e) { setMessage(e.message); }
  }

  function toggleFull() {
    if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {});
    else root.current?.requestFullscreen?.().catch(() => {});
  }
  useEffect(() => {
    const onFs = () => setFull(document.fullscreenElement === root.current);
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  // keyboard
  const keys = useRef({});
  keys.current = { choose, nextWave, upgrade, sell, setPaused, setPlacing, setSelected, speed, setSpeed };
  useEffect(() => {
    const onKey = (ev) => {
      if (/^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || "")) return;
      if (!root.current?.isConnected || sys.current.engine?.status !== "playing") return;
      const k = keys.current;
      const n = Number(ev.key);
      if (/^[0-9]$/.test(ev.key)) { k.choose(TOWER_ORDER[n === 0 ? 9 : n - 1]); return; }
      if (ev.key === "Escape") { k.setPlacing(null); k.setSelected(null); }
      else if (ev.code === "Space") { ev.preventDefault(); k.nextWave(); }
      else if (ev.key === "u" || ev.key === "U") k.upgrade();
      else if (ev.key === "Delete" || ev.key === "Backspace") k.sell();
      else if (ev.key === "p" || ev.key === "P") k.setPaused((p) => !p);
      else if (ev.key === "+" || ev.key === "f" || ev.key === "F") k.setSpeed((s) => (s >= 3 ? 1 : s + 1));
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
  useEffect(() => {
    const blur = () => { if (sys.current.engine?.status === "playing") setPaused(true); };
    window.addEventListener("blur", blur);
    return () => window.removeEventListener("blur", blur);
  }, []);

  const e = sys.current.engine;
  const tower = selected && e ? e.towers.find((t) => t.id === selected) : null;
  const stats = tower ? towerStats(tower.kind, tower.level, tower.branch) : null;
  const playing = snap.status === "playing", ended = snap.status === "ended";
  const canCall = playing && snap.queued === 0;
  const early = playing && snap.waveActive && snap.enemies > 0;
  const danger = snap.eggs <= 5 && playing;

  return (
    <section ref={root} className={`cdShell${full ? " isFull" : ""}${danger ? " isDanger" : ""}${snap.wave >= 15 ? " isChaos" : ""}`} aria-label="Chicken Defense">
      <header className="cdHeader">
        <div><span>TOWER DEFENSE</span><h2>Chicken Defense</h2></div>
        <dl className="cdHud">
          <div><dt>Welle</dt><dd data-testid="cd-wave">{snap.wave}</dd></div>
          <div className={danger ? "hot" : ""}><dt><Egg size={13} /> Eier</dt><dd data-testid="cd-eggs">{snap.eggs}</dd></div>
          <div><dt><Coins size={13} /> Korn</dt><dd data-testid="cd-korn">{fmt(snap.korn)}</dd></div>
          <div><dt>Punkte</dt><dd data-testid="cd-score">{fmt(snap.score)}</dd></div>
        </dl>
      </header>

      <div className="cdStage">
        <canvas ref={canvas} className={`cdCanvas${placing ? " isPlacing" : ""}`} onPointerMove={onMove} onPointerLeave={onLeave} onClick={onClick}
          onContextMenu={(ev) => { ev.preventDefault(); setPlacing(null); setSelected(null); }} aria-label="Spielfeld: Klicke auf eine freie Wiese, um den gewählten Turm zu bauen." />
        <div className="cdStageTools">
          <button type="button" onClick={() => { const v = !musicOn; setMusicOn(v); sys.current.audio.setMusic(v); }} aria-pressed={musicOn} aria-label={musicOn ? "Musik aus" : "Musik an"} className={musicOn ? "" : "off"}><Music size={18} /></button>
          <button type="button" onClick={() => { const v = !sfxOn; setSfxOn(v); sys.current.audio.setSfx(v); }} aria-pressed={sfxOn} aria-label={sfxOn ? "Sound aus" : "Sound an"}>{sfxOn ? <Volume2 size={18} /> : <VolumeX size={18} />}</button>
          <button type="button" onClick={toggleFull} aria-label={full ? "Vollbild beenden" : "Vollbild"}>{full ? <Shrink size={18} /> : <Expand size={18} />}</button>
        </div>
        {playing && snap.mods.length > 0 && <div className="cdMods">{snap.mods.map((m) => <span key={m} title={CHAOS_MODS[m].desc}>{CHAOS_MODS[m].name}</span>)}</div>}
        {playing && (
          <div className="cdWaveBar">
            <button type="button" className={`cdWaveBtn${canCall ? " ready" : ""}`} onClick={nextWave} disabled={!canCall}>
              {snap.wave === 0 ? <><Swords size={18} /> Erste Welle starten</> : early ? <><ChevronsRight size={18} /> Nächste Welle früh <em>+{12 + (snap.wave + 1) * 2} Korn</em></> : canCall ? <><Swords size={18} /> Welle {snap.wave + 1} starten</> : <><Zap size={18} /> Welle läuft …</>}
            </button>
            <div className="cdSpeed" role="group" aria-label="Spieltempo">
              <button type="button" onClick={() => setPaused((p) => !p)} aria-pressed={paused} aria-label={paused ? "Weiter" : "Pause"}>{paused ? <Play size={16} /> : <Pause size={16} />}</button>
              {[1, 2, 3].map((s) => <button key={s} type="button" className={speed === s ? "active" : ""} onClick={() => setSpeed(s)} aria-pressed={speed === s}>{s === 1 ? "1×" : s === 2 ? <><FastForward size={14} />2×</> : <><FastForward size={14} />3×</>}</button>)}
            </div>
          </div>
        )}
        {paused && playing && <div className="cdOverlay"><div className="cdCard"><h3>Pause</h3><p>Die Räuber warten …</p><button type="button" className="cdPrimary" onClick={() => setPaused(false)}><Play size={18} /> Weiter</button></div></div>}
        {snap.status === "ready" && (
          <div className="cdOverlay">
            <div className="cdCard intro">
              <h3>Verteidige das Nest!</h3>
              <p>Füchse, Ratten, Krähen und Schlimmeres wollen an deine Eier. Baue Hühner-Türme neben den Weg. Am Anfang ist es gemütlich – ab Welle 10 wird es wild, ab Welle 15 herrscht Chaos.</p>
              <ul className="cdHow">
                <li><b>1–9, 0</b> Turm wählen, auf die Wiese klicken</li>
                <li><b>Leertaste</b> nächste Welle (früh = Bonus-Korn)</li>
                <li><b>U</b> aufrüsten <b>Entf</b> verkaufen <b>P</b> Pause <b>F</b> Tempo</li>
              </ul>
              <button type="button" className="cdPrimary" onClick={start}><Play size={18} fill="currentColor" /> Spiel starten</button>
            </div>
          </div>
        )}
        {ended && (
          <div className="cdOverlay over">
            <div className="cdCard">
              <span className="cdOverIcon"><Trophy size={26} /></span>
              <h3>{snap.eggs <= 0 ? "Das Nest ist leer!" : "Rückzug!"}</h3>
              <p>Welle {snap.wave} · {fmt(snap.kills)} Räuber verjagt</p>
              <FinalScore value={snap.score} />
              {user && snap.score > 0 && <button type="button" className="cdPrimary" disabled={rewards.saving || rewards.submitted} onClick={save}><Save size={18} /> {rewards.saving ? "Speichert …" : rewards.submitted ? "Runde gewertet" : "Score speichern"}</button>}
              {!user && <p className="cdHint"><a href="/#login">Melde dich an</a>, um Scores zu speichern und Chickens zu verdienen.</p>}
              <button type="button" className="cdSecondary" onClick={start}><RefreshCw size={16} /> Nochmal</button>
              {message && <p className="cdMsg" role="status">{message}</p>}
            </div>
          </div>
        )}
      </div>

      <div className="cdDock">
        <div className="cdTowers" role="group" aria-label="Türme">
          {TOWER_ORDER.map((kind, i) => {
            const spec = TOWERS[kind];
            const locked = Math.max(1, snap.wave) < spec.unlock;
            const poor = snap.korn < spec.cost;
            return (
              <button key={kind} type="button" className={`cdTower${placing === kind ? " active" : ""}${locked ? " locked" : ""}${poor && !locked ? " poor" : ""}`} onClick={() => choose(kind)} disabled={!playing || locked} title={spec.desc} aria-pressed={placing === kind}>
                <i className="cdKey">{(i + 1) % 10}</i>
                <TowerIcon kind={kind} />
                <b>{spec.name}</b>
                <span>{locked ? <><Lock size={12} /> ab Welle {spec.unlock}</> : <><Coins size={12} /> {spec.cost}</>}</span>
              </button>
            );
          })}
        </div>
        <div className="cdPanel" aria-live="polite">
          {tower && stats ? (
            <>
              <div className="cdPanelHead"><TowerIcon kind={tower.kind} size={44} level={tower.level} branch={tower.branch} /><div><b>{TOWERS[tower.kind].name}</b><small>{tower.branch ? TOWERS[tower.kind].branches[tower.branch].name : `Level ${tower.level}`} · {tower.kills} Abschüsse</small></div></div>
              <dl className="cdStats">
                {stats.type === "econ" ? <>
                  <div><dt>Korn/Welle</dt><dd>+{fmt(stats.income)}</dd></div>
                  <div><dt>Bonus</dt><dd>{stats.interest ? `${Math.round(stats.interest * 100)} % Zins` : stats.treasure ? `+${Math.round(stats.treasure * 100)} % Beute` : "–"}</dd></div>
                </> : stats.type === "aura" ? <>
                  <div><dt>Buff</dt><dd>+{Math.round(stats.buff * 100)} %</dd></div>
                  <div><dt>Reichweite</dt><dd>{stats.range.toFixed(1)}</dd></div>
                </> : <>
                  <div><dt>Schaden</dt><dd>{stats.type === "beam" ? `${fmt(stats.dps)}/s` : fmt(stats.damage)}</dd></div>
                  <div><dt>Reichweite</dt><dd>{stats.range > 20 ? "∞" : stats.range.toFixed(1)}</dd></div>
                  <div><dt>Tempo</dt><dd>{stats.type === "beam" ? "Dauer" : `${stats.rate.toFixed(1)}/s`}</dd></div>
                </>}
              </dl>
              {tower.level === MAX_LEVEL && !tower.branch && (
                <div className="cdBranches" role="group" aria-label="Spezialisierung wählen">
                  {Object.entries(TOWERS[tower.kind].branches).map(([key, b]) => (
                    <button key={key} type="button" disabled={snap.korn < branchCost(tower.kind)} onClick={() => upgrade(key)} title={b.desc}>
                      <TowerIcon kind={tower.kind} size={34} level={4} branch={key} />
                      <b>{b.name}</b><small>{b.desc}</small><em><Coins size={11} /> {branchCost(tower.kind)}</em>
                    </button>
                  ))}
                </div>
              )}
              <div className="cdPanelActions">
                {["first", "strong", "last"].includes(tower.targeting) && stats.type !== "econ" && stats.type !== "aura" && stats.type !== "pulse" && <button type="button" onClick={cycleTargeting}><Crosshair size={15} /> {TARGETING[tower.targeting]}</button>}
                {tower.level < MAX_LEVEL
                  ? <button type="button" className="up" disabled={snap.korn < upgradeCost(tower.kind, tower.level)} onClick={() => upgrade()}>⬆ Level {tower.level + 1} <em>{upgradeCost(tower.kind, tower.level)}</em></button>
                  : tower.branch ? <button type="button" className="up" disabled>MAX</button> : null}
                <button type="button" className="sell" onClick={sell}><Trash2 size={15} /> +{Math.floor(tower.spent * 0.7)}</button>
              </div>
            </>
          ) : placing ? (
            <p className="cdPanelHint"><b>{TOWERS[placing].name}</b> – {TOWERS[placing].desc}<br /><small>Klicke auf eine freie Wiese. Rechtsklick oder Esc bricht ab.</small></p>
          ) : (
            <p className="cdPanelHint">Wähle einen Turm (1–9, 0) und klicke neben den Weg. Klicke einen Turm an, um ihn aufzurüsten. Auf Level 3 wählst du eine von drei Spezialisierungen.</p>
          )}
          {playing && <button type="button" className="cdGiveUp" onClick={() => { sys.current.engine.giveUp(); sync(); }}><Flag size={14} /> Aufgeben</button>}
        </div>
      </div>

      {renderScoreboard && <div className="cdScores"><h3><Trophy size={18} /> Rangliste</h3>{renderScoreboard(refreshKey)}</div>}
    </section>
  );
}

export const CD_TILE = T;
