import React, { useCallback, useEffect, useRef, useState } from "react";
import { ChevronsRight, Coins, Crosshair, Egg, Expand, FastForward, Flag, Lock, Music, Pause, Play, RefreshCw, Save, Shrink, SlidersHorizontal, Swords, Trash2, Trophy, Volume2, VolumeX, X, Zap } from "lucide-react";
import { useGameRewards } from "../economy/useGameRewards";
import { CHAOS_MODS, COLS, DefenseEngine, MAX_LEVEL, ROWS, START_EGGS, TOWERS, TOWER_ORDER, branchCost, towerRole, towerStats, upgradeCost } from "./engine.mjs";
import { BRANCH_STYLE, DefenseRenderer, TOWER_COLORS, branchIcon, drawTower, towerArtReady, T } from "./render.js";
import { DefenseAudio } from "./audio.js";
import "./defense.css";

const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const TARGETING = { first: "Vorderster", strong: "Stärkster", last: "Hinterster" };

// ----- replaces TowerIcon: optionally animated portrait
function TowerIcon({ kind, size = 52, level = 1, branch = null, animate = false, angle = 0.12 }) {
  const ref = useRef(null);
  useEffect(() => {
    const c = ref.current, dpr = Math.min(2, window.devicePixelRatio || 1);
    c.width = size * dpr; c.height = size * dpr;
    const ctx = c.getContext("2d");
    let frame = 0;
    const paint = (time) => {
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, c.width, c.height);
      ctx.setTransform(dpr * (size / 64), 0, 0, dpr * (size / 64), 0, 0);
      ctx.translate(32, 40);
      drawTower(ctx, kind, level, angle, time, false, 0, branch);
    };
    let alive = true;
    if (!animate || matchMedia("(prefers-reduced-motion: reduce)").matches) { paint(0); towerArtReady.then(() => alive && paint(0)); return () => { alive = false; }; }
    const loop = (now) => { paint(now / 1000); frame = requestAnimationFrame(loop); };
    frame = requestAnimationFrame(loop);
    return () => { alive = false; cancelAnimationFrame(frame); };
  }, [kind, size, level, branch, animate, angle]);
  return <canvas ref={ref} className="cdTowerIcon" style={{ width: size, height: size }} aria-hidden="true" />;
}

// Rough power numbers for the shop cards (0..1).
function powerBars(kind) {
  const s = towerStats(kind, 1);
  const dps = s.type === "beam" ? s.dps : s.type === "econ" || s.type === "aura" ? 0 : s.damage * s.rate * (s.splash ? 1.6 : 1) * (s.chain ? 2 : 1);
  return [Math.min(1, dps / 80), Math.min(1, s.range / 6), s.type === "econ" || s.type === "aura" ? 0 : Math.min(1, s.rate / 5)];
}
const TYPE_LABEL = { bullet: "Geschütz", shell: "Artillerie", sniper: "Präzision", chain: "Blitz", pulse: "Fläche", beam: "Strahl", econ: "Wirtschaft", aura: "Support", melee: "Nahkampf", warp: "Teleport", starfall: "Kosmisch" };
const ROLE_TABS = [["alle", "Alle"], ["angriff", "Angriff"], ["flaeche", "Fläche"], ["kontrolle", "Kontrolle"], ["support", "Support"]];

function BranchIcon({ kind, branch, size = 84 }) {
  const icon = branchIcon(kind, branch);
  if (!icon) return null;
  const k = size / 72;
  return <span className="cdBranchImg" aria-hidden="true" style={{ width: size, height: size, backgroundImage: `url(${icon.url})`, backgroundSize: `${720 * k}px ${432 * k}px`, backgroundPosition: `-${icon.x * k}px -${icon.y * k}px` }} />;
}
const SHORT = { gatling: "Gatling", frost: "Frost", mortar: "Mörser", sniper: "Sniper", wizard: "Zauber", golden: "Gold", tesla: "Tesla", rocket: "Raketen", medic: "Sani", dark: "Dunkel",
  archer: "Bogen", bubble: "Blasen", samurai: "Samurai", chef: "Koch", bakery: "Bäcker", beekeeper: "Imker", sandstorm: "Sandsturm", paintball: "Paintball", junkyard: "Schrott", viking: "Wikinger",
  gravity: "Schwerkraft", disco: "Disco", lumberjack: "Holzfäller", volcano: "Vulkan", vampire: "Vampir", ghost: "Geist", portal: "Portal", necro: "Nekro", magnet: "Magnet", cosmos: "Kosmos" };

function TowerCard({ kind, index, active, locked, poor, onPick, disabled }) {
  const spec = TOWERS[kind];
  const col = TOWER_COLORS[kind];
  const [hover, setHover] = useState(false);
  const bars = powerBars(kind);
  return (
    <button type="button" className={`cdCard2${active ? " active" : ""}${locked ? " locked" : ""}${poor && !locked ? " poor" : ""}`} style={{ "--tc": col.badge, "--tr": col.ring }}
      onClick={onPick} disabled={disabled} aria-pressed={active} title={spec.desc} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
      <span className="cdCardTitle">{index < 10 && <i>{(index + 1) % 10}</i>}{SHORT[kind]}</span>
      <span className="cdCardArt"><TowerIcon kind={kind} size={78} animate={(hover || active) && !locked} /></span>
      <span className="cdCardType">{TYPE_LABEL[spec.type]}</span>
      {!locked && <span className="cdCardBars" aria-hidden="true">{bars.map((b, i) => <i key={i} style={{ "--v": b }} title={["Schaden", "Reichweite", "Tempo"][i]} />)}</span>}
      <span className="cdCardCost">{locked ? <><Lock size={12} /> Welle {spec.unlock}</> : <><Coins size={13} /> {spec.cost}</>}</span>
      {locked && <span className="cdChains" aria-hidden="true" />}
    </button>
  );
}

function statRows(kind, now, next) {
  const rows = [];
  if (now.type === "econ") {
    rows.push(["Korn pro Welle", `+${fmt(now.income)}`, next && `+${fmt(next.income)}`]);
    if (now.interest || next?.interest) rows.push(["Zinsen", `${Math.round((now.interest || 0) * 100)} %`, next && `${Math.round((next.interest || 0) * 100)} %`]);
    if (now.treasure || next?.treasure) rows.push(["Beute-Bonus", `+${Math.round((now.treasure || 0) * 100)} %`, next && `+${Math.round((next.treasure || 0) * 100)} %`]);
  } else if (now.type === "aura") {
    rows.push(["Buff für Türme", `+${Math.round(now.buff * 100)} %`, next && `+${Math.round(next.buff * 100)} %`]);
  } else {
    const dmg = (s) => (s.type === "beam" ? `${fmt(s.dps)}/s` : fmt(s.damage));
    rows.push(["Schaden", dmg(now), next && dmg(next)]);
    rows.push(["Tempo", now.type === "beam" ? "Dauer" : `${now.rate.toFixed(1)}/s`, next && (next.type === "beam" ? "Dauer" : `${next.rate.toFixed(1)}/s`)]);
  }
  rows.push(["Reichweite", now.range > 20 ? "∞" : now.range.toFixed(1), next && (next.range > 20 ? "∞" : next.range.toFixed(1))]);
  return rows;
}

function UpgradeModal({ tower, korn, onClose, onUpgrade, onSell, onTarget }) {
  const spec = TOWERS[tower.kind];
  const now = towerStats(tower.kind, tower.level, tower.branch);
  const next = !tower.branch && tower.level < MAX_LEVEL ? towerStats(tower.kind, tower.level + 1) : null;
  const col = TOWER_COLORS[tower.kind];
  const canTarget = !["econ", "aura", "pulse"].includes(now.type);
  const choosing = tower.level === MAX_LEVEL && !tower.branch;
  return (
    <div className="cdModalWrap" onClick={onClose}>
      <div className="cdModal" style={{ "--tc": col.badge, "--tr": col.ring }} onClick={(ev) => ev.stopPropagation()} role="dialog" aria-modal="true" aria-label={`${spec.name} aufrüsten`}>
        <button type="button" className="cdModalClose" onClick={onClose} aria-label="Schließen"><X size={20} /></button>
        <div className="cdModalHero">
          <div className="cdModalArt" key={`${tower.level}-${tower.branch}`}><TowerIcon kind={tower.kind} size={170} level={tower.level} branch={tower.branch} animate /></div>
          <div className="cdModalInfo cdPanelHead">
            <span className="cdModalKicker">{TYPE_LABEL[now.type]} · {tower.kills} Abschüsse</span>
            <h3>{spec.name}</h3>
            <b className="cdModalSub">{tower.branch ? spec.branches[tower.branch].name : `Level ${tower.level}`}</b>
            <div className="cdLevelPath" aria-label={`Level ${tower.level} von 4`}>
              {[1, 2, 3].map((l) => <i key={l} className={tower.level >= l ? "on" : ""}>{l}</i>)}
              <i className={`crown${tower.branch ? " on" : ""}`}>♛</i>
            </div>
            <table className="cdStatTable"><tbody>
              {statRows(tower.kind, now, next).map(([label, a, b]) => (
                <tr key={label}><th>{label}</th><td>{a}</td>{next && <td className={b !== a ? "up" : ""}>{b !== a ? `→ ${b}` : ""}</td>}</tr>
              ))}
            </tbody></table>
          </div>
        </div>
        {choosing ? (
          <div className="cdBranches">
            <p>Wähle eine Spezialisierung – nur eine ist möglich:</p>
            <div className="cdBranchGrid">
              {Object.entries(spec.branches).map(([key, b]) => {
                const style = BRANCH_STYLE[tower.kind][key];
                return (
                  <button key={key} type="button" disabled={korn < branchCost(tower.kind)} onClick={() => onUpgrade(key)} style={{ "--bc": style[0] }}>
                    <span className="cdBranchArt">{branchIcon(tower.kind, key) ? <BranchIcon kind={tower.kind} branch={key} size={78} /> : <TowerIcon kind={tower.kind} size={84} level={4} branch={key} animate />}</span>
                    <b><span className="glyph">{style[1]}</span> {b.name}</b>
                    <small>{b.desc}</small>
                    <em><Coins size={12} /> {branchCost(tower.kind)}</em>
                  </button>
                );
              })}
            </div>
          </div>
        ) : null}
        <div className="cdModalActions">
          {canTarget && (
            <div className="cdTargeting" role="group" aria-label="Ziel">
              <Crosshair size={15} />
              {Object.entries(TARGETING).map(([key, label]) => <button key={key} type="button" className={tower.targeting === key ? "on" : ""} onClick={() => onTarget(key)}>{label}</button>)}
            </div>
          )}
          {next && <button type="button" className="cdUp" disabled={korn < upgradeCost(tower.kind, tower.level)} onClick={() => onUpgrade(null)}>⬆ Level {tower.level + 1} <em><Coins size={12} /> {upgradeCost(tower.kind, tower.level)}</em></button>}
          {tower.branch && <span className="cdMaxed">♛ Voll ausgebaut</span>}
          <button type="button" className="cdSell" onClick={onSell}><Trash2 size={15} /> Verkaufen +{Math.floor(tower.spent * 0.7)}</button>
        </div>
      </div>
    </div>
  );
}

function VolumePanel({ audio, onClose }) {
  const [sfx, setSfx] = useState(audio.sfxVolume);
  const [music, setMusic] = useState(audio.musicVolume);
  return (
    <div className="cdVolume" role="dialog" aria-label="Lautstärke">
      <label><Volume2 size={16} /><span>Sound</span><input type="range" min="0" max="100" value={Math.round(sfx * 100)} aria-label="Lautstärke Sound" onChange={(ev) => { const v = Number(ev.target.value) / 100; setSfx(v); audio.setSfxVolume(v); audio.play("build"); }} /><b>{Math.round(sfx * 100)}%</b></label>
      <label><Music size={16} /><span>Musik</span><input type="range" min="0" max="100" value={Math.round(music * 100)} aria-label="Lautstärke Musik" onChange={(ev) => { const v = Number(ev.target.value) / 100; setMusic(v); audio.setMusicVolume(v); }} /><b>{Math.round(music * 100)}%</b></label>
      <button type="button" onClick={onClose}>Fertig</button>
    </div>
  );
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
  const [volumeOpen, setVolumeOpen] = useState(false);
  const [role, setRole] = useState("alle");
  const pausedByModal = useRef(false);
  const shopRef = useRef(TOWER_ORDER);
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
      frame = requestAnimationFrame(loop);
      // A drawing glitch must never freeze the game: reset the effect lists and keep going.
      try { renderer.draw(now / 1000, pausedRef.current ? 0 : dt * Math.min(1.5, speedRef.current)); }
      catch (err) { renderer.fx = []; renderer.bolts = []; if (!renderer.warned) { renderer.warned = true; console.warn("Chicken Defense draw error", err); } }
    };
    frame = requestAnimationFrame(loop);
    sync();
    return () => { cancelAnimationFrame(frame); audio.dispose(); delete canvas.current?.__defense; };
  }, [sync]);

  useEffect(() => { if (sys.current.renderer) sys.current.renderer.ui.placing = placing; }, [placing]);
  useEffect(() => {
    if (sys.current.renderer) sys.current.renderer.ui.selected = selected;
    if (selected && !pausedRef.current) { pausedByModal.current = true; setPaused(true); }
    if (!selected && pausedByModal.current) { pausedByModal.current = false; setPaused(false); }
  }, [selected]);
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
  function setTargeting(mode) { const t = sys.current.engine.towers.find((x) => x.id === selected); if (t) { t.targeting = mode; sync(); } }

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
      if (/^[0-9]$/.test(ev.key)) { const kind = shopRef.current[n === 0 ? 9 : n - 1]; if (kind) k.choose(kind); return; }
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
  const shopList = TOWER_ORDER.filter((kind) => role === "alle" || towerRole(kind) === role);
  shopRef.current = shopList;
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
          <button type="button" onClick={() => setVolumeOpen((v) => !v)} aria-expanded={volumeOpen} aria-label="Lautstärke"><SlidersHorizontal size={18} /></button>
          <button type="button" onClick={() => { const v = !musicOn; setMusicOn(v); sys.current.audio.setMusic(v); }} aria-pressed={musicOn} aria-label={musicOn ? "Musik aus" : "Musik an"} className={musicOn ? "" : "off"}><Music size={18} /></button>
          <button type="button" onClick={() => { const v = !sfxOn; setSfxOn(v); sys.current.audio.setSfx(v); }} aria-pressed={sfxOn} aria-label={sfxOn ? "Sound aus" : "Sound an"}>{sfxOn ? <Volume2 size={18} /> : <VolumeX size={18} />}</button>
          <button type="button" onClick={toggleFull} aria-label={full ? "Vollbild beenden" : "Vollbild"}>{full ? <Shrink size={18} /> : <Expand size={18} />}</button>
        </div>
        {volumeOpen && sys.current.audio && <VolumePanel audio={sys.current.audio} onClose={() => setVolumeOpen(false)} />}
        {tower && playing && <UpgradeModal tower={tower} korn={snap.korn} onClose={() => setSelected(null)} onUpgrade={(branch) => upgrade(branch)} onSell={sell} onTarget={setTargeting} />}
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
        {paused && playing && !tower && <div className="cdOverlay"><div className="cdCard"><h3>Pause</h3><p>Die Räuber warten …</p><button type="button" className="cdPrimary" onClick={() => setPaused(false)}><Play size={18} /> Weiter</button></div></div>}
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

      <div className="cdShopTabs" role="tablist" aria-label="Turm-Kategorien">
        {ROLE_TABS.map(([key, label]) => <button key={key} type="button" role="tab" aria-selected={role === key} className={role === key ? "on" : ""} onClick={() => setRole(key)}>{label} <i>{key === "alle" ? TOWER_ORDER.length : TOWER_ORDER.filter((k) => towerRole(k) === key).length}</i></button>)}
      </div>
      <div className="cdShop" role="group" aria-label="Türme kaufen">
        {shopList.map((kind, i) => {
          const spec = TOWERS[kind];
          const locked = Math.max(1, snap.wave) < spec.unlock;
          return <TowerCard key={kind} kind={kind} index={i} active={placing === kind} locked={locked} poor={snap.korn < spec.cost} disabled={!playing || locked} onPick={() => choose(kind)} />;
        })}
      </div>
      <div className="cdShopHint">
        {placing ? <span><b>{TOWERS[placing].name}</b> platzieren: Klick auf freie Wiese · Rechtsklick/Esc bricht ab</span>
          : <span>Turm wählen (1–9, 0), neben den Weg setzen. Klick auf ein Huhn öffnet das Upgrade-Menü.</span>}
        {playing && <button type="button" className="cdGiveUp" onClick={() => { sys.current.engine.giveUp(); sync(); }}><Flag size={14} /> Aufgeben</button>}
      </div>

      {renderScoreboard && <div className="cdScores"><h3><Trophy size={18} /> Rangliste</h3>{renderScoreboard(refreshKey)}</div>}
    </section>
  );
}

export const CD_TILE = T;
