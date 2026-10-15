import React, { useEffect, useRef, useState } from "react";
import { Clock, Flag, Gamepad2, Heart, Maximize, Minimize, Pause, Play, RefreshCw, Shield, Skull, Sparkles, Target, Volume2, VolumeX, Zap } from "lucide-react";
import { useGameRewards } from "../economy/useGameRewards";
import { SPECIAL_WEAPONS, WEAPON_ART, evolutionTier, evolutionMultiplier, updateSpecialWeapons, steerComet, explodeComet } from "./SurvivorWeapons.mjs";
import { survivorSound, survivorStop, survivorVolume } from "./SurvivorAudio";
import { ArcadeButton } from "../ui/ArcadeButton";
import "./survivor.css";
import { drawBeamVfx, drawProjectileTrail } from "./SurvivorVfx";

function Stat({label,value}) { return <div className="stat"><strong>{value ?? 0}</strong><span>{label}</span></div>; }
function useCanvasGame(draw, deps, onError) {
  const canvasRef = useRef(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return undefined;
    const ctx = canvas.getContext("2d");
    let frame = 0;
    let last = performance.now();
    let alive = true;
    function loop(now) {
      if (!alive) return;
      const dt = Math.min(40, now - last);
      last = now;
      try {
        draw(ctx, canvas, dt, frame++);
      } catch (err) {
        alive = false;
        if (onError) onError(err);
        else console.error(err);
        return;
      }
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
    return () => {
      alive = false;
    };
  }, deps);
  return canvasRef;
}

const survivorSettingsKey = "pepple-survivor-settings-v1";
const defaultSurvivorSettings = { audioOn: true, volume: 0.75, controlMode: "wasd" };

function readSurvivorSettings() {
  if (typeof window === "undefined") return defaultSurvivorSettings;
  try {
    const saved = JSON.parse(window.localStorage.getItem(survivorSettingsKey) || "{}");
    const volume = Number.isFinite(Number(saved.volume)) ? Math.min(1, Math.max(0, Number(saved.volume))) : defaultSurvivorSettings.volume;
    return {
      audioOn: typeof saved.audioOn === "boolean" ? saved.audioOn : defaultSurvivorSettings.audioOn,
      volume,
      controlMode: saved.controlMode === "arrows" ? "arrows" : "wasd",
    };
  } catch {
    return defaultSurvivorSettings;
  }
}

function writeSurvivorSettings(settings) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(survivorSettingsKey, JSON.stringify(settings));
  } catch {
    // Local storage can be blocked in private or hardened browsers.
  }
}


function roundRect(ctx, x, y, w, h, r = 8, strokeOnly = false) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  if (strokeOnly) ctx.stroke();
  else ctx.fill();
}

export function PeppleSurvivor({ user, renderScoreboard }) {
  const rewards = useGameRewards("braincell-survivor", user);
  const upgradePool = [...SPECIAL_WEAPONS,
    { id: "bolt", name: "Federblitz", kind: "weapon", icon: "feather", desc: "Feuert zielsuchende Federbolzen auf nahe Gegner.", color: "#c88cff" },
    { id: "orbit", name: "Orbit-Kaefig", kind: "weapon", icon: "orbit", desc: "Beschwoert kreisende Kaefig-Ringe um dich.", color: "#ffcf8a" },
    { id: "nova", name: "Nova-Puls", kind: "weapon", icon: "nova", desc: "Stoesst in Intervallen alle Gegner zurueck.", color: "#ff6fb7" },
    { id: "laser", name: "Sternenlaser", kind: "weapon", icon: "laser", desc: "Schneidet den staerksten Gegner mit Licht.", color: "#7af4dc" },
    { id: "egg", name: "Kosmo-Ei", kind: "weapon", icon: "egg", desc: "Laesst explosive Eier in die Schwarmbahn fallen.", color: "#fff4e9" },
    { id: "aura", name: "Nest-Aura", kind: "weapon", icon: "aura", desc: "Verbrennt nahe Drohnen mit warmer Kaefigenergie.", color: "#c88956" },
    { id: "drone", name: "Mini-Satelliten", kind: "weapon", icon: "drone", desc: "Kleine Begleiter feuern Plasma aus dem Orbit.", color: "#8f7bff" },
    { id: "thunder", name: "Kettenblitz", kind: "weapon", icon: "thunder", desc: "Springt von Alien zu Alien und knistert brutal.", color: "#ffe66d" },
    { id: "frost", name: "Kryo-Federn", kind: "weapon", icon: "frost", desc: "Verlangsamt getroffene Aliens mit Eisnebel.", color: "#9bf6ff" },
    { id: "gravity", name: "Schwarzes Pepple", kind: "weapon", icon: "gravity", desc: "Zieht Aliens in eine dunkle Singularitaet.", color: "#6d4cff" },
    { id: "speed", name: "Kometenboots", kind: "passive", icon: "boots", desc: "Mehr Tempo und bessere Ausweichfenster.", color: "#7af4dc" },
    { id: "magnet", name: "Pepple-Magnet", kind: "passive", icon: "magnet", desc: "Zieht XP-Kristalle aus groesserer Distanz an.", color: "#b46cff" },
    { id: "shield", name: "Schildfedern", kind: "passive", icon: "shield", desc: "Mehr maximale HP und weniger Kontaktschaden.", color: "#ffcf8a" },
    { id: "regen", name: "Warmnest", kind: "passive", icon: "regen", desc: "Regeneriert im Lauf langsam HP.", color: "#ff9f6e" },
    { id: "might", name: "Pepple-Fokus", kind: "passive", icon: "might", desc: "Alle Waffen verursachen mehr Schaden.", color: "#ff6fb7" },
    { id: "cooldown", name: "Taktgeber", kind: "passive", icon: "cooldown", desc: "Waffen laden schneller wieder auf.", color: "#dfb8ff" },
  ];
  const worldConfig = { width: 6200, height: 4200, spawnX: 3100, spawnY: 2100 };
  const initialSettingsRef = useRef(readSurvivorSettings());
  const [status, setStatus] = useState("menu");
  const [audioOn, setAudioOn] = useState(() => initialSettingsRef.current.audioOn);
  const [volume, setVolume] = useState(() => initialSettingsRef.current.volume);
  const [controlMode, setControlMode] = useState(() => initialSettingsRef.current.controlMode);
  const [fullscreen, setFullscreen] = useState(false);
  const [choices, setChoices] = useState([]);
  const [message, setMessage] = useState("WASD bewegen, XP sammeln, beim Level-Up Waffen waehlen.");
  const [lastRun, setLastRun] = useState(null);
  const [assetsReady, setAssetsReady] = useState(false);
  const [assetError, setAssetError] = useState("");
  const [assetAttempt, setAssetAttempt] = useState(0);
  const [snapshot, setSnapshot] = useState({
    score: 0,
    level: 1,
    seconds: 0,
    kills: 0,
    hp: 150,
    maxHp: 150,
    energy: 100,
    bleeding: false,
    playerX: worldConfig.spawnX,
    playerY: worldConfig.spawnY,
    xp: 0,
    nextXp: 45,
    wave: 1,
    weapons: [{ id: "bolt", name: "Federblitz", level: 1, color: "#c88cff", icon: "feather" }],
  });
  const [refreshKey, setRefreshKey] = useState(0);
  const keysRef = useRef({});

  const stageRef = useRef(null);
  const bgRef = useRef(null);
  const weaponArtRef = useRef(null);
  const touchRef = useRef({ x: 0, y: 0, active: false });
  const reducedMotion = useRef(window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  const spriteRef = useRef(null);
  const obstacleArtRef = useRef(null);
  const titleRef = useRef(null);
  const playerArtRef = useRef(null);
  const playerFaceRef = useRef(null);
  const criticalAlarmRef = useRef(0);
  const audioRef = useRef({ ctx: null });
  const statusRef = useRef("menu");

  const perfCaps = { enemies: 92, bossEnemies: 64, shots: 88, hazards: 72, particles: 230, gems: 120, potions: 8, beams: 48, bombs: 22, wells: 8 };
  const bossCooldownSeconds = 180;

  function makeObstacles() {
    const specs = [
      [940, 760, 122, 55, "starAmber", -0.35, 1.04, "#ffcf8a"],
      [1510, 1220, 92, 42, "mine", 0.14, 0.84, "#ff6fb7"],
      [2190, 880, 132, 62, "shipScout", -0.2, 1.05, "#7af4dc"],
      [2850, 1320, 108, 48, "starBlue", 0.82, 0.9, "#7af4dc"],
      [3790, 920, 142, 65, "satellite", -0.5, 1.02, "#9bf6ff"],
      [4940, 760, 128, 58, "mine", 0.52, 1.03, "#ff6fb7"],
      [5450, 1310, 174, 76, "shipWreck", -0.38, 1.12, "#ff9f6e"],
      [1220, 1940, 146, 66, "starAmber", 0.74, 1.18, "#ffe66d"],
      [1980, 2520, 188, 82, "shipWreck", -0.18, 1.3, "#826b62"],
      [2470, 1810, 108, 50, "starAmber", -0.4, 1.0, "#ffcf8a"],
      [3650, 1610, 132, 58, "shipScout", 0.32, 1.03, "#7af4dc"],
      [4150, 2160, 112, 51, "starBlue", 0.2, 0.96, "#b46cff"],
      [4760, 2600, 100, 45, "mine", 1.2, 0.92, "#dfb8ff"],
      [5360, 2190, 136, 62, "satellite", -0.86, 0.98, "#9bf6ff"],
      [780, 3100, 154, 70, "shipScout", 0.16, 1.05, "#66798b"],
      [1400, 3440, 104, 47, "starBlue", 0.62, 0.9, "#9bf6ff"],
      [2120, 3320, 126, 57, "mine", -0.78, 0.96, "#ff6fb7"],
      [2920, 3480, 162, 72, "satellite", 0.6, 1.1, "#7af4dc"],
      [3640, 3220, 174, 78, "shipWreck", -0.72, 1.12, "#6b7486"],
      [4380, 3440, 112, 50, "starAmber", 1.35, 0.94, "#dfb8ff"],
      [5120, 3300, 150, 68, "starBlue", -0.9, 1.08, "#9bf6ff"],
      [5700, 2860, 164, 72, "shipScout", 0.4, 1.05, "#7af4dc"],
      [900, 2520, 112, 50, "mine", -0.2, 0.88, "#ff6fb7"],
      [1700, 1680, 92, 42, "starAmber", 0.55, 0.78, "#ff9f6e"],
      [3350, 2620, 126, 56, "starBlue", 1.1, 1.0, "#7af4dc"],
      [4520, 1540, 186, 82, "shipWreck", 0.42, 1.22, "#617387"],
      [5700, 1840, 110, 50, "starAmber", -0.65, 0.9, "#ffcf8a"],
      [760, 1420, 146, 66, "satellite", 0.38, 1.0, "#9bf6ff"],
    ];
    return specs.map(([x, y, visualRadius, collisionRadius, type, rotation, scale, color], index) => ({
      id: `obstacle-${index}`,
      x,
      y,
      visualRadius,
      collisionRadius,
      radius: collisionRadius,
      type,
      rotation,
      scale,
      color,
    }));
  }

  function makeSurvivorState() {
    return {
      world: worldConfig,
      player: { x: worldConfig.spawnX, y: worldConfig.spawnY, hp: 150, maxHp: 150, invuln: 0 },
      energy: 100,
      bleeding: false,
      bleedStartedAt: 0,
      bleedHpStart: 150,
      camera: { x: worldConfig.spawnX - 640, y: worldConfig.spawnY - 360 },
      obstacles: makeObstacles(),
      gems: [],
      potions: [],
      enemies: [],
      shots: [],
      bombs: [],
      beams: [],
      wells: [],
      hazards: [],
      particles: [],
      score: 0,
      xp: 0,
      nextXp: 45,
      seconds: 0,
      kills: 0,
      level: 1,
      wave: 1,
      spawn: 0,
      nextBossAt: bossCooldownSeconds,
      bossActive: false,
      timers: { rail: 500, comet: 700, bolt: 0, nova: 2600, laser: 1600, egg: 900, drone: 640, thunder: 2100, gravity: 3200, regen: 1000, comfortRegen: 1000, potion: 4200 },
      weapons: { rail: 0, comet: 0, bolt: 1, orbit: 0, nova: 0, laser: 0, egg: 0, aura: 0, drone: 0, thunder: 0, frost: 0, gravity: 0, speed: 0, magnet: 0, shield: 0, regen: 0, might: 0, cooldown: 0 },
      over: false,
    };
  }

  const stateRef = useRef(makeSurvivorState());

  function setGameStatus(next) {
    statusRef.current = next;
    if (next !== "play") { keysRef.current = {}; touchRef.current = { x: 0, y: 0, active: false }; }
    if (next === "gameover") syncSnapshot(stateRef.current);
    setStatus(next);

    if (next === "gameover" || next === "menu" || next === "options" || next === "paused" || next === "crashed") survivorStop(audioRef.current.ctx);
  }

  useEffect(() => {
    function down(event) {
      if (event.target.closest?.("input,textarea,select,[contenteditable='true']")) return;
      if (statusRef.current === "play" && [" ", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(event.key.toLowerCase())) event.preventDefault();
      if (["p", "escape"].includes(event.key.toLowerCase())) {
        if (event.repeat) return;
        event.preventDefault();
        if (statusRef.current === "options") {
          setMessage("WASD bewegen, XP sammeln, beim Level-Up Waffen waehlen.");
          setGameStatus("menu");
          return;
        }
        if (statusRef.current === "play") {
          setMessage("Run pausiert. Fortsetzen bringt dich direkt zurueck ins Chaos.");
          setGameStatus("paused");
        } else if (statusRef.current === "paused") {
          setMessage("Weiter geht's. Die Aliens haben kurz gewartet.");
          setGameStatus("play");
        }
        return;
      }
      keysRef.current[event.key.toLowerCase()] = true;
    }
    function up(event) { keysRef.current[event.key.toLowerCase()] = false; }
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };
  }, []);

  useEffect(() => {
    const pause = () => { keysRef.current = {}; touchRef.current = { x: 0, y: 0, active: false }; if (statusRef.current === "play") setGameStatus("paused"); };
    const visibility = () => { if (document.hidden) pause(); };
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const motion = (event) => { reducedMotion.current = event.matches; };
    window.addEventListener("blur", pause); document.addEventListener("visibilitychange", visibility); media.addEventListener("change", motion);
    return () => { window.removeEventListener("blur", pause); document.removeEventListener("visibilitychange", visibility); media.removeEventListener("change", motion); };
  }, []);

  useEffect(() => {
    function fullscreenChange() {
      setFullscreen(document.fullscreenElement === stageRef.current);
    }
    document.addEventListener("fullscreenchange", fullscreenChange);
    return () => document.removeEventListener("fullscreenchange", fullscreenChange);
  }, []);

  useEffect(() => () => {

    audioRef.current.ctx?.close?.();
    audioRef.current.ctx = null;
  }, []);

  useEffect(() => {
    let alive = true;
    setAssetsReady(false); setAssetError("");
    const deadline = setTimeout(() => { if (alive) setAssetError("Die Spielgrafik lädt zu lange. Bitte erneut versuchen."); }, 20000);
    const assets = [[bgRef, "/assets/survivor/nebula.png"], [weaponArtRef, "/assets/survivor/weapons.png"], [spriteRef, "/assets/pepple-survivor-sprites.png"], [obstacleArtRef, "/assets/survivor-obstacles-ai-v1.png?v=1"], [titleRef, "/assets/pepple-survivor-title-flori-v2.png?v=2"], [playerArtRef, "/assets/player-chicken-ai-v1.png?v=1"], [playerFaceRef, "/assets/player-face.jpeg?v=2"]];
    Promise.all(assets.map(([ref, src]) => new Promise((resolve, reject) => {
      const image = new Image(); ref.current = image; image.decoding = "async";
      image.onload = resolve; image.onerror = () => reject(new Error("Eine Spielgrafik konnte nicht geladen werden. Bitte erneut versuchen.")); image.src = src;
    }))).then(() => { if (alive) { setAssetsReady(true); setAssetError(""); } }).catch((error) => { if (alive) setAssetError(error.message); }).finally(() => clearTimeout(deadline));
    return () => { alive = false; clearTimeout(deadline); };
  }, [assetAttempt]);

  useEffect(() => {
    writeSurvivorSettings({ audioOn, volume, controlMode });

  }, [audioOn, volume, controlMode]);

  useEffect(() => { survivorVolume(audioRef.current.ctx, audioOn ? volume : 0); if (!audioOn) survivorStop(audioRef.current.ctx); }, [audioOn, volume]);

  function audio() {
    if (!audioOn) return null;
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return null;
    try {
      if (!audioRef.current.ctx) audioRef.current.ctx = new AudioCtx();
      if (audioRef.current.ctx.state === "suspended") audioRef.current.ctx.resume().catch(() => {});
      return audioRef.current.ctx;
    } catch { return null; }
  }

  function sfx(type) { survivorSound(audio(), type, volume); }

  function levelUpFanfare() { sfx('level'); }
  function criticalAlarm() { sfx('hit'); }
  function bleedingAlarm() { sfx('nova'); }

  function burst(x, y, color, amount = 10) {
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;
    const state = stateRef.current;
    const pressure = state.particles.length > 180 ? 0.45 : state.particles.length > 120 ? 0.7 : 1;
    const count = reducedMotion.current ? 0 : clamp(Math.floor((Number(amount) || 0) * pressure), 0, 38);
    for (let i = 0; i < count; i += 1) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 0.8 + Math.random() * 3.2;
      state.particles.push({ x, y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: 420 + Math.random() * 360, ttl: 800, color });
    }
  }

  function pushRing(state, x, y, radius, life, color) {
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(radius) || !Number.isFinite(life)) return;
    const safeRadius = clamp(radius, 1, 760);
    const safeLife = clamp(life, 60, 2200);
    state.particles.push({ ring: true, x, y, vx: 0, vy: 0, max: safeRadius, life: safeLife, ttl: safeLife, color });
  }

  function alienBloodBurst(x, y, color = "#9cff4a", amount = 12, force = 1) {
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;
    const state = stateRef.current;
    const pressure = state.particles.length > 180 ? 0.38 : state.particles.length > 120 ? 0.65 : 1;
    const count = reducedMotion.current ? 0 : clamp(Math.floor((Number(amount) || 0) * pressure), 0, 42);
    const safeForce = Number.isFinite(force) ? clamp(force, 0.1, 2.4) : 1;
    for (let i = 0; i < count; i += 1) {
      const angle = Math.random() * Math.PI * 2;
      const speed = (1.4 + Math.random() * 5.8) * safeForce;
      state.particles.push({
        type: "slime",
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        size: 2.5 + Math.random() * 7,
        life: 620 + Math.random() * 760,
        ttl: 1380,
        color,
      });
    }
  }

  function scorePopup(state, x, y, points, color = "#ffcf8a") {
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(points)) return;
    state.particles.push({
      type: "score",
      text: `+${points}`,
      x,
      y: y - 18,
      vx: (Math.random() - 0.5) * 0.9,
      vy: -1.45 - Math.random() * 0.65,
      life: 940,
      ttl: 940,
      size: points >= 100 ? 28 : points >= 30 ? 22 : 18,
      color,
    });
  }

  function bossAttack(state, canvas, boss) {
    const pattern = Math.floor(state.seconds * 1.35 + state.wave) % 5;
    if (pattern === 0) {
      state.hazards.push({ type: "ring", x: boss.x, y: boss.y, radius: 28, max: 340, life: 1280, ttl: 1280, damage: 22, hit: false, color: "#ff6fb7" });
      state.hazards.push({ type: "ring", x: state.player.x, y: state.player.y, radius: 18, max: 190, life: 920, ttl: 920, damage: 16, hit: false, color: "#ffcf8a" });
      boss.phase = 1.4;
      pushRing(state, boss.x, boss.y, 260, 520, "#ff6fb7");
    } else if (pattern === 1) {
      for (let i = 0; i < 12; i += 1) {
        const angle = i / 12 * Math.PI * 2 + state.seconds;
        state.hazards.push({ type: "orb", x: boss.x, y: boss.y, vx: Math.cos(angle) * 3.5, vy: Math.sin(angle) * 3.5, radius: 15, life: 2300, ttl: 2300, damage: 13, color: i % 2 ? "#ffcf8a" : "#b46cff" });
      }
      burst(boss.x, boss.y, "#ffcf8a", 28);
    } else if (pattern === 2) {
      const base = Math.atan2(state.player.y - boss.y, state.player.x - boss.x);
      for (let i = -1; i <= 1; i += 1) {
        const angle = base + i * 0.34;
        const length = Math.max(canvas.width, canvas.height) * 1.08;
        state.hazards.push({ type: "beam", x1: boss.x, y1: boss.y, x2: boss.x + Math.cos(angle) * length, y2: boss.y + Math.sin(angle) * length, life: 980, ttl: 980, warmup: 430, damage: 16, width: 18, hitWidth: 10, color: i === 0 ? "#ffcf8a" : "#7af4dc", hit: false });
      }
      pushRing(state, boss.x, boss.y, 150, 360, "#7af4dc");
    } else if (pattern === 3) {
      for (let i = 0; i < 7; i += 1) {
        const ox = (Math.random() - 0.5) * canvas.width * 0.85;
        const oy = (Math.random() - 0.5) * canvas.height * 0.65;
        state.hazards.push({ type: "meteor", x: state.player.x + ox, y: state.player.y + oy, radius: 34 + Math.random() * 18, life: 1150 + i * 70, ttl: 1150 + i * 70, damage: 15, color: i % 2 ? "#ff6fb7" : "#ffcf8a", hit: false, exploded: false });
      }
      sfx("bomb");
    } else {
      for (let i = 0; i < 6; i += 1) {
        const angle = i / 6 * Math.PI * 2 + state.seconds * 0.8;
        const length = Math.max(canvas.width, canvas.height) * 0.86;
        state.hazards.push({ type: "beam", x1: boss.x, y1: boss.y, x2: boss.x + Math.cos(angle) * length, y2: boss.y + Math.sin(angle) * length, life: 820, ttl: 820, warmup: 360, damage: 12, width: 14, hitWidth: 8, color: i % 2 ? "#b46cff" : "#ff6fb7", hit: false });
      }
      pushRing(state, boss.x, boss.y, 420, 720, "#b46cff");
      burst(boss.x, boss.y, "#b46cff", 30);
    }
    boss.rage = 520;
    boss.ability = Math.max(860, 1700 - Math.min(620, state.wave * 34));
    sfx(pattern === 3 ? "bomb" : "thunder");
  }

  function damageMult(state) {
    return 1 + state.weapons.might * 0.18;
  }

  function cooldownMult(state) {
    return Math.max(0.5, 1 - state.weapons.cooldown * 0.08);
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function finitePoint(entity) {
    return entity && Number.isFinite(entity.x) && Number.isFinite(entity.y);
  }

  function distanceSq(ax, ay, bx, by) {
    const dx = ax - bx;
    const dy = ay - by;
    return dx * dx + dy * dy;
  }

  function compactSurvivorCollections(state, canvas) {
    const viewLimit = Math.max(canvas.width, canvas.height);
    const keepSq = viewLimit * viewLimit * (state.bossActive ? 1.35 : 1.18);
    const player = state.player;
    const keepBoss = (enemy) => enemy.boss || distanceSq(enemy.x, enemy.y, player.x, player.y) < keepSq;
    const maxEnemies = state.bossActive ? perfCaps.bossEnemies : perfCaps.enemies;
    state.enemies = state.enemies.filter((enemy) => finitePoint(enemy) && keepBoss(enemy)).slice(-maxEnemies);
    state.shots = state.shots.filter((shot) => Number.isFinite(shot.x) && Number.isFinite(shot.y) && shot.life > 0).slice(-perfCaps.shots);
    state.hazards = state.hazards.filter((hazard) => hazard.life > 0).slice(-perfCaps.hazards);
    state.gems = state.gems.filter((gem) => finitePoint(gem) && distanceSq(gem.x, gem.y, player.x, player.y) < keepSq * 1.25).slice(-perfCaps.gems);
    state.potions = state.potions.filter((potion) => finitePoint(potion) && potion.life > 0 && distanceSq(potion.x, potion.y, player.x, player.y) < keepSq * 1.45).slice(-perfCaps.potions);
    state.beams = state.beams.filter((beam) => beam.life > 0).slice(-perfCaps.beams);
    state.bombs = state.bombs.filter((bomb) => bomb.life > 0).slice(-perfCaps.bombs);
    state.wells = state.wells.filter((well) => well.life > 0).slice(-perfCaps.wells);
  }

  function obstacleHitRadius(obstacle) {
    return (obstacle.collisionRadius || obstacle.radius) * (obstacle.scale || 1);
  }

  function collidesObstacle(state, x, y, radius = 16) {
    return (state.obstacles || []).some((obstacle) => {
      const hitRadius = obstacleHitRadius(obstacle) + radius;
      return distanceSq(x, y, obstacle.x, obstacle.y) < hitRadius * hitRadius;
    });
  }

  function segmentHitsObstacle(state, x1, y1, x2, y2, padding = 0) {
    if (![x1, y1, x2, y2].every(Number.isFinite)) return true;
    return (state.obstacles || []).some((obstacle) => {
      const vx = x2 - x1;
      const vy = y2 - y1;
      const lenSq = Math.max(1, vx * vx + vy * vy);
      const t = clamp(((obstacle.x - x1) * vx + (obstacle.y - y1) * vy) / lenSq, 0, 1);
      const px = x1 + vx * t;
      const py = y1 + vy * t;
      return Math.hypot(obstacle.x - px, obstacle.y - py) < obstacleHitRadius(obstacle) + padding;
    });
  }

  function visibleTargets(state, targets, x, y, padding = 8) {
    return targets.filter((target) => finitePoint(target) && !segmentHitsObstacle(state, x, y, target.x, target.y, padding));
  }

  function pushOutOfObstacles(state, entity, radius = 18) {
    (state.obstacles || []).forEach((obstacle) => {
      const dx = entity.x - obstacle.x;
      const dy = entity.y - obstacle.y;
      const dist = Math.max(0.001, Math.hypot(dx, dy));
      const minDist = obstacleHitRadius(obstacle) + radius;
      if (dist < minDist) {
        entity.x = obstacle.x + (dx / dist) * minDist;
        entity.y = obstacle.y + (dy / dist) * minDist;
      }
    });
    const world = state.world || worldConfig;
    entity.x = clamp(entity.x, radius, world.width - radius);
    entity.y = clamp(entity.y, radius, world.height - radius);
  }

  function roundedCanvasRect(ctx, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + r);
    ctx.lineTo(x + width, y + height - r);
    ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    ctx.lineTo(x + r, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
  }

  function movePlayer(state, dx, dy) {
    const player = state.player;
    const radius = 24;
    if (dx) {
      player.x += dx;
      pushOutOfObstacles(state, player, radius);
    }
    if (dy) {
      player.y += dy;
      pushOutOfObstacles(state, player, radius);
    }
  }

  function spawnPotion(state, canvas) {
    if (!state || state.potions.length >= perfCaps.potions) return;
    const world = state.world || worldConfig;
    const viewLeft = state.camera?.x ?? state.player.x - canvas.width / 2;
    const viewTop = state.camera?.y ?? state.player.y - canvas.height / 2;
    const margin = 90;
    for (let attempt = 0; attempt < 22; attempt += 1) {
      const nearView = attempt < 14;
      const x = nearView
        ? clamp(viewLeft + margin + Math.random() * Math.max(1, canvas.width - margin * 2), 42, world.width - 42)
        : 42 + Math.random() * Math.max(1, world.width - 84);
      const y = nearView
        ? clamp(viewTop + margin + Math.random() * Math.max(1, canvas.height - margin * 2), 42, world.height - 42)
        : 42 + Math.random() * Math.max(1, world.height - 84);
      const tooClose = distanceSq(x, y, state.player.x, state.player.y) < 150 * 150;
      const overlapsPotion = state.potions.some((potion) => distanceSq(x, y, potion.x, potion.y) < 95 * 95);
      if (!tooClose && !overlapsPotion && !collidesObstacle(state, x, y, 26)) {
        state.potions.push({ x, y, heal: 36, radius: 19, life: 36000, ttl: 36000, spin: Math.random() * Math.PI * 2 });
        return;
      }
    }
  }

  function makeChoices(state) {
    const pool = upgradePool
      .filter((upgrade) => Number(state.weapons[upgrade.id] || 0) < 8)
      .map((upgrade) => ({ ...upgrade, level: Number(state.weapons[upgrade.id] || 0) + 1 }))
      .sort(() => Math.random() - 0.5);
    return pool.slice(0, 3);
  }

  function syncSnapshot(state) {
    const weapons = upgradePool
      .filter((upgrade) => Number(state.weapons[upgrade.id] || 0) > 0)
      .map((upgrade) => ({ id: upgrade.id, name: upgrade.name, level: state.weapons[upgrade.id], color: upgrade.color, icon: upgrade.icon }));
    setSnapshot({
      score: state.score,
      level: state.level,
      seconds: Math.floor(state.seconds),
      kills: state.kills,
      hp: Math.max(0, Math.ceil(state.player.hp)),
      maxHp: state.player.maxHp,
      energy: Math.max(0, Math.min(100, Math.ceil(state.energy))),
      bleeding: Boolean(state.bleeding),
      playerX: state.player.x,
      playerY: state.player.y,
      xp: Math.floor(state.xp),
      nextXp: state.nextXp,
      wave: state.wave,
      bossActive: state.bossActive, nextBossAt: state.nextBossAt, bossHp: state.enemies.find((enemy) => enemy.boss)?.hp || 0, bossMaxHp: state.enemies.find((enemy) => enemy.boss)?.maxHp || 1,
      weapons,
    });
  }

  function enforceBleeding(state) {
    if (!state.bleeding) return;
    const elapsed = Math.max(0, state.seconds - state.bleedStartedAt);
    const startHp = Math.max(1, state.bleedHpStart || state.player.maxHp);
    const bleedCap = Math.max(0, startHp * (1 - elapsed / 20));
    state.player.hp = Math.min(state.player.hp, bleedCap);
  }

  function enterLevelUp(state) {
    const nextChoices = makeChoices(state);
    if (!nextChoices.length) {
      setMessage("Alle Upgrades sind voll. Bonuspunkte aktiviert, Run laeuft weiter.");
      state.score += state.level * 75;
      syncSnapshot(state);
      return;
    }
    setChoices(nextChoices);
    setMessage("Level Up. Waehle dein naechstes Upgrade.");
    setGameStatus("levelup");
    levelUpFanfare();
    syncSnapshot(state);
  }

  function gainXp(state, amount) {
    if (statusRef.current !== "play" || state.over) return;
    state.xp += amount;
    while (state.xp >= state.nextXp) {
      state.xp -= state.nextXp;
      state.level += 1;
      state.nextXp = Math.floor(state.nextXp * 1.16 + 24);
      enterLevelUp(state);
      break;
    }
  }

  function recoverRun(err) {
    console.error(err);
    const state = stateRef.current;
    setLastRun({
      score: state.score || snapshot.score,
      level: state.level || snapshot.level,
      seconds: Math.floor(state.seconds || snapshot.seconds || 0),
      kills: state.kills || snapshot.kills,
    });
    keysRef.current = {};
    setChoices([]);
    setMessage("Ein Item-Effekt wurde abgefangen. Du kannst direkt neu starten, ohne die Webseite neu zu laden.");
    syncSnapshot(state);
    setGameStatus("crashed");
  }

  function updateCamera(state, canvas) {
    const camera = state.camera || { x: 0, y: 0 };
    const world = state.world || worldConfig;
    const screenX = state.player.x - camera.x;
    const screenY = state.player.y - camera.y;
    const leftEdge = canvas.width * 0.34;
    const rightEdge = canvas.width * 0.66;
    const topEdge = canvas.height * 0.32;
    const bottomEdge = canvas.height * 0.68;
    if (screenX > rightEdge) camera.x = state.player.x - rightEdge;
    if (screenX < leftEdge) camera.x = state.player.x - leftEdge;
    if (screenY > bottomEdge) camera.y = state.player.y - bottomEdge;
    if (screenY < topEdge) camera.y = state.player.y - topEdge;
    camera.x = clamp(camera.x, 0, Math.max(0, world.width - canvas.width));
    camera.y = clamp(camera.y, 0, Math.max(0, world.height - canvas.height));
    state.camera = camera;
  }

  function spawnBoss(state, canvas) {
    state.enemies = [];
    state.shots = [];
    state.bombs = [];
    state.wells = [];
    state.hazards = [];
    const angle = Math.random() * Math.PI * 2;
    const distance = Math.min(canvas.width, canvas.height) * 0.58;
    const waveScale = 1 + state.wave * 0.34;
    const world = state.world || worldConfig;
    const bossX = clamp(state.player.x + Math.cos(angle) * distance, 70, world.width - 70);
    const bossY = clamp(state.player.y + Math.sin(angle) * distance, 70, world.height - 70);
    state.enemies.push({
      x: bossX,
      y: bossY,
      hp: 780 * waveScale,
      maxHp: 780 * waveScale,
      speed: 0.76 + state.wave * 0.045,
      radius: 68,
      elite: true,
      boss: true,
      variant: "boss",
      wobble: Math.random() * 8,
      tint: "#ffcf8a",
      ability: 900,
      phase: 0,
      rage: 0,
    });
    state.bossActive = true;
    setMessage("BOSSALARM. Das Vieh geht jetzt komplett steil.");
    pushRing(state, state.player.x, state.player.y, 560, 980, "#ffcf8a");
    pushRing(state, bossX, bossY, 340, 820, "#ff6fb7");
    sfx("nova");
  }

  function spawnEnemy(state, canvas) {
    const world = state.world || worldConfig;
    const viewLeft = state.camera?.x ?? state.player.x - canvas.width / 2;
    const viewTop = state.camera?.y ?? state.player.y - canvas.height / 2;
    let edge = null;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const side = Math.floor(Math.random() * 4);
      const candidate = [
        { x: viewLeft - 80, y: viewTop + Math.random() * canvas.height },
        { x: viewLeft + canvas.width + 80, y: viewTop + Math.random() * canvas.height },
        { x: viewLeft + Math.random() * canvas.width, y: viewTop - 80 },
        { x: viewLeft + Math.random() * canvas.width, y: viewTop + canvas.height + 80 },
      ][side];
      candidate.x = clamp(candidate.x, 24, world.width - 24);
      candidate.y = clamp(candidate.y, 24, world.height - 24);
      if (!collidesObstacle(state, candidate.x, candidate.y, 22)) {
        edge = candidate;
        break;
      }
    }
    if (!edge) edge = { x: clamp(state.player.x + 420, 24, world.width - 24), y: clamp(state.player.y, 24, world.height - 24) };
    const elite = Math.random() < Math.min(0.24, state.seconds / 210);
    const waveScale = 1 + state.wave * 0.17;
    const variants = ["green", "pink", "blue", "gold"];
    state.enemies.push({
      ...edge,
      hp: elite ? 48 * waveScale : 20 * waveScale,
      maxHp: elite ? 48 * waveScale : 20 * waveScale,
      speed: (elite ? 0.96 : 1.42) + state.wave * 0.055,
      radius: elite ? 19 : 12,
      elite,
      boss: false,
      variant: elite ? "elite" : variants[Math.floor(Math.random() * variants.length)],
      wobble: Math.random() * 8,
      tint: elite ? "#b46cff" : "#ff6fb7",
      ability: 0,
    });
  }

  const spriteMap = {
    chicken: { x: 38, y: 24, w: 286, h: 354 },
    alienGreen: { x: 396, y: 125, w: 224, h: 236 },
    alienPink: { x: 678, y: 86, w: 226, h: 278 },
    alienBlue: { x: 957, y: 98, w: 230, h: 270 },
    alienGold: { x: 1194, y: 108, w: 248, h: 258 },
    alienElite: { x: 228, y: 410, w: 392, h: 318 },
    alienBoss: { x: 668, y: 383, w: 548, h: 326 },
    laser: { x: 24, y: 774, w: 184, h: 134 },
    feather: { x: 238, y: 734, w: 184, h: 244 },
    egg: { x: 430, y: 743, w: 178, h: 184 },
    thunder: { x: 622, y: 756, w: 174, h: 188 },
    gravity: { x: 805, y: 760, w: 178, h: 156 },
    frost: { x: 1010, y: 732, w: 170, h: 236 },
    orbit: { x: 1192, y: 760, w: 178, h: 166 },
    nova: { x: 1378, y: 760, w: 144, h: 160 },
  };

  const obstacleSpriteMap = {
    starAmber: { x: 0, y: 110, w: 418, h: 470, aspect: 1.0, glow: "#ffcf8a" },
    starBlue: { x: 418, y: 122, w: 418, h: 452, aspect: 1.0, glow: "#7af4dc" },
    shipScout: { x: 836, y: 158, w: 418, h: 326, aspect: 1.48, glow: "#7af4dc" },
    shipWreck: { x: 0, y: 660, w: 418, h: 404, aspect: 1.42, glow: "#ff6fb7" },
    satellite: { x: 418, y: 642, w: 418, h: 438, aspect: 1.1, glow: "#9bf6ff" },
    mine: { x: 836, y: 650, w: 418, h: 438, aspect: 1.0, glow: "#ff6fb7" },
  };

  function getSprite(name) {
    const art = weaponArtRef.current, index = WEAPON_ART[name];
    if (index !== undefined && art?.complete && art.naturalWidth) {
      const w = art.naturalWidth / 4, h = art.naturalHeight / 3;
      return { sheet: art, rect: { x: (index % 4) * w, y: Math.floor(index / 4) * h, w, h } };
    }
    const sheet = spriteRef.current;
    if (!sheet?.complete || !sheet.naturalWidth) return null;
    const rect = spriteMap[name];
    if (!rect) return null;
    return { sheet, rect };
  }

  function drawSprite(ctx, name, x, y, width, height, options = {}) {
    const asset = getSprite(name);
    if (!asset) return false;
    if (![x, y, width, height].every(Number.isFinite) || width <= 0 || height <= 0) return false;
    const { sheet, rect } = asset;
    ctx.save();
    ctx.translate(x, y);
    if (options.rotate) ctx.rotate(options.rotate);
    if (options.flip) ctx.scale(-1, 1);
    if (options.alpha != null) ctx.globalAlpha = options.alpha;
    ctx.shadowBlur = options.shadowBlur ?? 0;
    ctx.shadowColor = options.shadowColor || "transparent";
    ctx.drawImage(sheet, rect.x, rect.y, rect.w, rect.h, -width / 2, -height / 2, width, height);
    ctx.restore();
    return true;
  }

  function drawObstacleSprite(ctx, obstacle, visualRadius, frame) {
    const sheet = obstacleArtRef.current;
    const rect = obstacleSpriteMap[obstacle.type];
    if (!sheet?.complete || !sheet.naturalWidth || !rect) return false;
    const pulse = 1 + Math.sin(frame / 45 + obstacle.x * 0.01) * 0.025;
    const width = visualRadius * 2 * (rect.aspect || 1) * pulse;
    const height = visualRadius * 2 * pulse;
    if (![width, height].every(Number.isFinite) || width <= 0 || height <= 0) return false;
    ctx.save();
    ctx.shadowBlur = obstacle.type.includes("star") ? 42 : 30;
    ctx.shadowColor = rect.glow || obstacle.color;
    ctx.drawImage(sheet, rect.x, rect.y, rect.w, rect.h, -width / 2, -height / 2, width, height);
    ctx.globalAlpha = 0.2;
    ctx.strokeStyle = rect.glow || obstacle.color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, 0, obstacle.collisionRadius || obstacle.radius || 40, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    return true;
  }

  function roundedRect(ctx, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + r);
    ctx.lineTo(x + width, y + height - r);
    ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    ctx.lineTo(x + r, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
  }

  function drawCanvasMeter(ctx, x, y, width, height, pct, label, value, colors, frame, danger = false) {
    const safePct = clamp(Number.isFinite(pct) ? pct : 0, 0, 1);
    const fillWidth = Math.max(0, (width - 8) * safePct);
    ctx.save();
    ctx.shadowBlur = danger ? 24 + Math.sin(frame / 5) * 8 : 18;
    ctx.shadowColor = danger ? "rgba(255, 44, 73, 0.75)" : colors.glow;
    roundedRect(ctx, x, y, width, height, 8);
    const back = ctx.createLinearGradient(x, y, x, y + height);
    back.addColorStop(0, "rgba(255,255,255,0.13)");
    back.addColorStop(0.48, "rgba(12,12,22,0.82)");
    back.addColorStop(1, "rgba(0,0,0,0.74)");
    ctx.fillStyle = back;
    ctx.fill();
    ctx.shadowBlur = 0;

    roundedRect(ctx, x + 4, y + 4, width - 8, height - 8, 6);
    ctx.fillStyle = "rgba(0,0,0,0.48)";
    ctx.fill();

    if (fillWidth > 0) {
      ctx.save();
      roundedRect(ctx, x + 4, y + 4, width - 8, height - 8, 6);
      ctx.clip();
      const fill = ctx.createLinearGradient(x + 4, y, x + width - 4, y);
      fill.addColorStop(0, colors.start);
      fill.addColorStop(0.56, colors.mid);
      fill.addColorStop(1, colors.end);
      ctx.fillStyle = fill;
      ctx.fillRect(x + 4, y + 4, fillWidth, height - 8);
      ctx.globalAlpha = 0.22;
      for (let sx = x + 4 - ((frame * 1.4) % 32); sx < x + 4 + fillWidth + 32; sx += 32) {
        ctx.fillStyle = "#fff4e9";
        ctx.beginPath();
        ctx.moveTo(sx, y + 4);
        ctx.lineTo(sx + 12, y + 4);
        ctx.lineTo(sx - 2, y + height - 4);
        ctx.lineTo(sx - 14, y + height - 4);
        ctx.closePath();
        ctx.fill();
      }
      ctx.restore();
    }

    ctx.strokeStyle = danger ? "rgba(255,255,255,0.58)" : "rgba(255,218,184,0.34)";
    ctx.lineWidth = 1.4;
    roundedRect(ctx, x, y, width, height, 8);
    ctx.stroke();
    ctx.fillStyle = "#fff4e9";
    ctx.font = "900 11px Inter, system-ui, sans-serif";
    ctx.textBaseline = "middle";
    ctx.shadowBlur = 12;
    ctx.shadowColor = colors.glow;
    ctx.fillText(label, x + 12, y + height / 2);
    ctx.textAlign = "right";
    ctx.fillText(value, x + width - 12, y + height / 2);
    ctx.restore();
  }

  function drawSurvivorHudBars(ctx, canvas, state, frame) {
    const player = state.player;
    const x = 22;
    const y = canvas.height - 128;
    const width = Math.min(330, canvas.width - 44);
    const energyPct = clamp((state.energy ?? 100) / 100, 0, 1);
    const hpPct = clamp(player.hp / Math.max(1, player.maxHp), 0, 1);
    const xpPct = clamp(state.xp / Math.max(1, state.nextXp), 0, 1);
    ctx.save();
    ctx.fillStyle = "rgba(4, 4, 12, 0.48)";
    roundedRect(ctx, x - 8, y - 10, width + 16, 116, 8);
    ctx.fill();
    ctx.strokeStyle = "rgba(255, 218, 184, 0.16)";
    ctx.stroke();
    drawCanvasMeter(ctx, x, y, width, 22, energyPct, state.bleeding ? "BLEED" : "MOVE", state.bleeding ? "ALARM" : `${Math.round(energyPct * 100)}%`, {
      start: state.bleeding ? "#ff163f" : "#ffcf33",
      mid: state.bleeding ? "#fff4e9" : "#ffe66d",
      end: state.bleeding ? "#ff5f7c" : "#5dff9a",
      glow: state.bleeding ? "rgba(255, 22, 63, 0.82)" : "rgba(255, 230, 109, 0.62)",
    }, frame, state.bleeding);
    drawCanvasMeter(ctx, x, y + 34, width, 28, hpPct, "HP", `${Math.ceil(Math.max(0, player.hp))}/${player.maxHp}`, {
      start: hpPct <= 0.22 ? "#ff163f" : "#ff3d71",
      mid: hpPct <= 0.22 ? "#fff4e9" : "#ff7f7f",
      end: hpPct <= 0.22 ? "#ffb000" : "#ffcf8a",
      glow: hpPct <= 0.22 ? "rgba(255, 30, 68, 0.82)" : "rgba(255, 95, 124, 0.56)",
    }, frame, hpPct <= 0.22);
    drawCanvasMeter(ctx, x, y + 74, width, 22, xpPct, `LVL ${state.level}`, `${state.xp}/${state.nextXp} XP`, {
      start: "#7af4dc",
      mid: "#b46cff",
      end: "#ffcf8a",
      glow: "rgba(122, 244, 220, 0.58)",
    }, frame);
    ctx.restore();
  }

  function drawUpgradeIcon(ctx, icon, x, y, size, color, frame = 0) {
    const spriteName = icon === "drone" ? "laser" : icon === "boots" ? "feather" : icon === "magnet" ? "gravity" : icon === "shield" ? "orbit" : icon === "regen" ? "egg" : icon === "might" ? "nova" : icon === "cooldown" ? "thunder" : icon;
    if (drawSprite(ctx, spriteName, x, y, size * 1.55, size * 1.55, { rotate: Math.sin(frame / 35) * 0.08, shadowBlur: 18, shadowColor: color })) return;
    ctx.save();
    ctx.translate(x, y);
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = Math.max(2, size / 16);
    ctx.shadowBlur = 16;
    ctx.shadowColor = color;
    if (icon === "feather") {
      ctx.beginPath();
      ctx.ellipse(0, 0, size * 0.18, size * 0.48, -0.75, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#fff4e9";
      ctx.beginPath();
      ctx.moveTo(-size * 0.28, size * 0.3);
      ctx.lineTo(size * 0.28, -size * 0.36);
      ctx.stroke();
    } else if (icon === "orbit") {
      for (let i = 0; i < 3; i += 1) {
        ctx.rotate(Math.PI / 3);
        ctx.beginPath();
        ctx.ellipse(0, 0, size * 0.42, size * 0.17, frame / 40 + i, 0, Math.PI * 2);
        ctx.stroke();
      }
    } else if (icon === "nova") {
      ctx.beginPath();
      ctx.arc(0, 0, size * 0.22, 0, Math.PI * 2);
      ctx.fill();
      for (let i = 0; i < 12; i += 1) {
        const a = i / 12 * Math.PI * 2;
        ctx.beginPath();
        ctx.moveTo(Math.cos(a) * size * 0.32, Math.sin(a) * size * 0.32);
        ctx.lineTo(Math.cos(a) * size * 0.52, Math.sin(a) * size * 0.52);
        ctx.stroke();
      }
    } else if (icon === "laser") {
      ctx.beginPath();
      ctx.moveTo(-size * 0.42, size * 0.22);
      ctx.lineTo(size * 0.42, -size * 0.22);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(size * 0.42, -size * 0.22, size * 0.12, 0, Math.PI * 2);
      ctx.fill();
    } else if (icon === "egg") {
      ctx.beginPath();
      ctx.ellipse(0, 0, size * 0.25, size * 0.35, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#ffcf8a";
      ctx.stroke();
    } else {
      ctx.beginPath();
      ctx.arc(0, 0, size * 0.32, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawAlien(ctx, enemy, frame) {
    const glow = enemy.slow > 0 ? "#9bf6ff" : enemy.tint || (enemy.elite ? "#b46cff" : "#ff6fb7");
    const spriteName = enemy.variant === "boss" ? "alienBoss" : enemy.variant === "elite" ? "alienElite" : `alien${(enemy.variant || "pink").replace(/^./, (char) => char.toUpperCase())}`;
    const bob = Math.sin(frame / 14 + enemy.wobble) * (enemy.boss ? 3 : 2);
    const spriteW = enemy.boss ? enemy.radius * 5.4 : enemy.elite ? enemy.radius * 4.1 : enemy.radius * 3.6;
    const spriteH = enemy.boss ? enemy.radius * 3.45 : enemy.elite ? enemy.radius * 3.25 : enemy.radius * 3.35;
    ctx.save();
    ctx.translate(enemy.x, enemy.y + bob);
    ctx.rotate(Math.sin(frame / 22 + enemy.wobble) * 0.08);
    if (enemy.boss) {
      const rageAlpha = enemy.rage > 0 ? 0.6 : 0.34;
      ctx.save();
      ctx.globalAlpha = rageAlpha;
      ctx.strokeStyle = enemy.rage > 0 ? "#ffcf8a" : "#ff6fb7";
      ctx.lineWidth = enemy.rage > 0 ? 5 : 3;
      ctx.shadowBlur = 38;
      ctx.shadowColor = enemy.rage > 0 ? "#ffcf8a" : "#ff6fb7";
      for (let i = 0; i < 3; i += 1) {
        ctx.rotate(frame / (140 + i * 45));
        ctx.beginPath();
        ctx.ellipse(0, 0, enemy.radius * (1.25 + i * 0.22), enemy.radius * (0.58 + i * 0.1), 0, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.restore();
    }
    if (enemy.slow > 0) {
      ctx.globalAlpha = 0.34;
      ctx.fillStyle = "#9bf6ff";
      ctx.shadowBlur = 26;
      ctx.shadowColor = "#9bf6ff";
      ctx.beginPath();
      ctx.arc(0, 0, Math.max(spriteW, spriteH) * 0.36, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
    }
    const usedSprite = drawSprite(ctx, spriteName, 0, 0, spriteW, spriteH, { shadowBlur: enemy.boss ? 38 : enemy.elite ? 28 : 20, shadowColor: glow });
    ctx.restore();
    if (usedSprite) {
      if (enemy.hp < enemy.maxHp) {
        const pct = Math.max(0, enemy.hp / enemy.maxHp);
        ctx.save();
        ctx.shadowBlur = 0;
        ctx.fillStyle = "rgba(2,4,11,.78)";
        ctx.fillRect(enemy.x - enemy.radius * 1.35, enemy.y - spriteH * 0.58, enemy.radius * 2.7, 4);
        ctx.fillStyle = glow;
        ctx.fillRect(enemy.x - enemy.radius * 1.35, enemy.y - spriteH * 0.58, enemy.radius * 2.7 * pct, 4);
        ctx.restore();
      }
      if (enemy.boss) {
        ctx.save();
        ctx.globalAlpha = 0.74;
        ctx.fillStyle = "#ffcf8a";
        ctx.font = "950 12px Inter, Arial";
        ctx.textAlign = "center";
        ctx.shadowBlur = 14;
        ctx.shadowColor = "#ff6fb7";
        ctx.fillText("BOSS", enemy.x, enemy.y - spriteH * 0.66);
        ctx.restore();
      }
      return;
    }
    const scale = enemy.boss ? 1.35 : enemy.elite ? 1.08 : 1;
    ctx.save();
    ctx.translate(enemy.x, enemy.y);
    ctx.rotate(Math.sin(frame / 22 + enemy.wobble) * 0.18);
    ctx.scale(scale, scale);
    ctx.shadowBlur = enemy.boss ? 34 : enemy.elite ? 24 : 17;
    ctx.shadowColor = glow;

    const body = ctx.createRadialGradient(-5, -6, 4, 0, 0, enemy.radius * 1.45);
    body.addColorStop(0, enemy.slow > 0 ? "#dcfbff" : "#f7d5ff");
    body.addColorStop(0.34, enemy.slow > 0 ? "#7af4dc" : enemy.elite ? "#9f63ff" : "#ff6fb7");
    body.addColorStop(1, enemy.boss ? "#5a2418" : "#2b1232");
    ctx.fillStyle = body;
    ctx.beginPath();
    ctx.ellipse(0, 0, enemy.radius * 1.18, enemy.radius * 0.92, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,244,233,.72)";
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.fillStyle = "#0b0610";
    ctx.beginPath();
    ctx.ellipse(-enemy.radius * 0.34, -enemy.radius * 0.12, enemy.radius * 0.22, enemy.radius * 0.34, -0.18, 0, Math.PI * 2);
    ctx.ellipse(enemy.radius * 0.34, -enemy.radius * 0.12, enemy.radius * 0.22, enemy.radius * 0.34, 0.18, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#fff4e9";
    ctx.beginPath();
    ctx.arc(-enemy.radius * 0.4, -enemy.radius * 0.22, 2.2, 0, Math.PI * 2);
    ctx.arc(enemy.radius * 0.28, -enemy.radius * 0.22, 2.2, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = glow;
    ctx.lineWidth = 2.2;
    for (let i = 0; i < 4; i += 1) {
      const side = i < 2 ? -1 : 1;
      const y = -enemy.radius * 0.2 + (i % 2) * enemy.radius * 0.52;
      ctx.beginPath();
      ctx.moveTo(side * enemy.radius * 0.8, y);
      ctx.quadraticCurveTo(side * enemy.radius * 1.35, y + Math.sin(frame / 15 + i) * 8, side * enemy.radius * 1.55, y + enemy.radius * 0.55);
      ctx.stroke();
    }

    if (enemy.hp < enemy.maxHp) {
      const pct = Math.max(0, enemy.hp / enemy.maxHp);
      ctx.shadowBlur = 0;
      ctx.fillStyle = "rgba(2,4,11,.78)";
      ctx.fillRect(-enemy.radius * 1.25, -enemy.radius * 1.65, enemy.radius * 2.5, 4);
      ctx.fillStyle = glow;
      ctx.fillRect(-enemy.radius * 1.25, -enemy.radius * 1.65, enemy.radius * 2.5 * pct, 4);
    }
    ctx.restore();
  }

  function drawPlayerFace(ctx, x, y, scale = 1) {
    const face = playerFaceRef.current;
    if (!face?.complete || !face.naturalWidth) return false;

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);

    ctx.shadowBlur = 18;
    ctx.shadowColor = "rgba(255,207,138,.48)";
    const featherBase = ctx.createRadialGradient(0, 18, 6, 0, 13, 36);
    featherBase.addColorStop(0, "#fff7dc");
    featherBase.addColorStop(0.48, "#ffcf8a");
    featherBase.addColorStop(1, "#8f573f");
    ctx.fillStyle = featherBase;
    ctx.beginPath();
    ctx.ellipse(0, 17, 30, 19, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#fff4e9";
    for (let i = -2; i <= 2; i += 1) {
      ctx.beginPath();
      ctx.ellipse(i * 10, 18 + Math.abs(i) * 2, 8, 18, i * 0.18, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);
    ctx.shadowBlur = 18;
    ctx.shadowColor = "rgba(255,207,138,.62)";
    ctx.beginPath();
    ctx.ellipse(0, -2, 26, 30, 0, 0, Math.PI * 2);
    ctx.clip();
    const size = Math.min(face.naturalWidth, face.naturalHeight);
    const sx = (face.naturalWidth - size) / 2;
    const sy = Math.max(0, (face.naturalHeight - size) * 0.16);
    ctx.drawImage(face, sx, sy, size, size, -30, -36, 60, 66);
    ctx.globalCompositeOperation = "source-atop";
    const shade = ctx.createLinearGradient(-24, -34, 24, 30);
    shade.addColorStop(0, "rgba(255,244,233,.16)");
    shade.addColorStop(0.45, "rgba(255,207,138,.04)");
    shade.addColorStop(1, "rgba(40,8,18,.24)");
    ctx.fillStyle = shade;
    ctx.fillRect(-31, -37, 62, 68);
    ctx.restore();

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);
    ctx.shadowBlur = 14;
    ctx.shadowColor = "#7af4dc";
    const glass = ctx.createRadialGradient(-11, -18, 3, 0, -3, 35);
    glass.addColorStop(0, "rgba(255,255,255,.5)");
    glass.addColorStop(0.28, "rgba(122,244,220,.16)");
    glass.addColorStop(1, "rgba(122,244,220,.02)");
    ctx.fillStyle = glass;
    ctx.beginPath();
    ctx.ellipse(0, -2, 31, 34, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(222,248,255,.88)";
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.ellipse(0, -2, 31, 34, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeStyle = "rgba(255,255,255,.56)";
    ctx.lineWidth = 3.2;
    ctx.beginPath();
    ctx.arc(-9, -16, 13, Math.PI * 1.05, Math.PI * 1.55);
    ctx.stroke();
    ctx.restore();
    return true;
  }

  function drawAstronautChicken(ctx, player, frame) {
    const bob = Math.sin(frame / 18) * 2;
    const playerArt = playerArtRef.current;
    if (playerArt?.complete && playerArt.naturalWidth) {
      const pulse = player.invuln > 0 ? 1 + Math.sin(frame / 4) * 0.04 : 1;
      const width = 94 * pulse;
      const height = 112 * pulse;
      ctx.save();
      ctx.translate(player.x, player.y + bob);
      ctx.shadowBlur = player.invuln > 0 ? 42 : 28;
      ctx.shadowColor = player.invuln > 0 ? "#fff4e9" : "#ffcf8a";
      ctx.drawImage(playerArt, -width / 2, -height * 0.68, width, height);
      ctx.strokeStyle = player.invuln > 0 ? "rgba(255,244,233,.9)" : "rgba(122,244,220,.32)";
      ctx.lineWidth = player.invuln > 0 ? 3 : 1.6;
      ctx.beginPath();
      ctx.ellipse(2, -37, 28 * pulse, 32 * pulse, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
      return;
    }
    if (drawSprite(ctx, "chicken", player.x, player.y + bob, 72, 90, { shadowBlur: 34, shadowColor: player.invuln > 0 ? "#fff4e9" : "#ffcf8a" })) {
      drawPlayerFace(ctx, player.x + 4, player.y + bob - 22, 0.84, frame);
      ctx.save();
      ctx.strokeStyle = player.invuln > 0 ? "rgba(255,244,233,.9)" : "rgba(122,244,220,.48)";
      ctx.lineWidth = player.invuln > 0 ? 3.2 : 1.8;
      ctx.shadowBlur = 22;
      ctx.shadowColor = player.invuln > 0 ? "#fff4e9" : "#7af4dc";
      ctx.beginPath();
      ctx.ellipse(player.x + 3, player.y + bob - 18, 31 + Math.sin(frame / 11) * 1.6, 36, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
      return;
    }
    ctx.save();
    ctx.translate(player.x, player.y);
    ctx.shadowBlur = 34;
    ctx.shadowColor = player.invuln > 0 ? "#fff4e9" : "#ffcf8a";

    const suit = ctx.createLinearGradient(-26, -20, 26, 24);
    suit.addColorStop(0, "#fff7dc");
    suit.addColorStop(0.48, "#ffcf8a");
    suit.addColorStop(1, "#c88956");
    ctx.fillStyle = suit;
    ctx.beginPath();
    ctx.ellipse(0, 10, 22, 18, Math.sin(frame / 14) * 0.06, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#fff4e9";
    ctx.beginPath();
    ctx.arc(7, -8, 13, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ff9f6e";
    ctx.beginPath();
    ctx.moveTo(19, -9);
    ctx.lineTo(33, -4);
    ctx.lineTo(19, 2);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#140912";
    ctx.beginPath();
    ctx.arc(10, -12, 2.5, 0, Math.PI * 2);
    ctx.fill();
    drawPlayerFace(ctx, 6, -10, 0.74, frame);

    const helmet = ctx.createRadialGradient(-10, -18, 3, 3, -9, 30);
    helmet.addColorStop(0, "rgba(255,255,255,.62)");
    helmet.addColorStop(0.35, "rgba(122,244,220,.18)");
    helmet.addColorStop(1, "rgba(122,244,220,.04)");
    ctx.fillStyle = helmet;
    ctx.beginPath();
    ctx.arc(3, -5, 29, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(222,248,255,.86)";
    ctx.lineWidth = 2.4;
    ctx.stroke();
    ctx.strokeStyle = "rgba(255,255,255,.55)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(-5, -14, 12, Math.PI * 1.05, Math.PI * 1.55);
    ctx.stroke();

    ctx.strokeStyle = "rgba(255,207,138,.38)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(0, 1, 36 + Math.sin(frame / 10) * 3, 28, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function drawWeaponProjectile(ctx, shot, frame) {
    const angle = Math.atan2(shot.vy, shot.vx) + Math.PI / 2;
    const spriteName = shot.type === "comet" ? "comet" : shot.type === "drone" ? "laser" : stateRef.current.weapons.frost ? "frost" : "feather";
    const color = shot.type === "comet" ? "#ffad74" : shot.type === "drone" ? "#8f7bff" : stateRef.current.weapons.frost ? "#9bf6ff" : "#c88cff";
    drawProjectileTrail(ctx, shot, frame, reducedMotion.current);
    if (drawSprite(ctx, spriteName, shot.x, shot.y, shot.type === "drone" ? 42 : 34, shot.type === "drone" ? 28 : 48, { rotate: angle, shadowBlur: 18, shadowColor: color })) return;
    ctx.strokeStyle = color;
    ctx.lineWidth = shot.type === "drone" ? 3 : 4;
    ctx.beginPath();
    ctx.moveTo(shot.x - shot.vx * 1.5, shot.y - shot.vy * 1.5);
    ctx.lineTo(shot.x, shot.y);
    ctx.stroke();
  }

  function drawWorldBackdrop(ctx, canvas, state, frame) {
    const camera = state.camera || { x: 0, y: 0 };
    const world = state.world || worldConfig;
    const bgImage = bgRef.current;
    if (bgImage?.complete && bgImage.naturalWidth) {
      const scale = Math.max(canvas.width / bgImage.naturalWidth, canvas.height / bgImage.naturalHeight) * 1.35;
      const width = bgImage.naturalWidth * scale, height = bgImage.naturalHeight * scale;
      const x = clamp((canvas.width - width) / 2 - (camera.x - world.width / 2) * 0.025, canvas.width - width, 0);
      const y = clamp((canvas.height - height) / 2 - (camera.y - world.height / 2) * 0.025, canvas.height - height, 0);
      ctx.drawImage(bgImage, x, y, width, height);
    } else {
      const bg = ctx.createRadialGradient(canvas.width * 0.55, canvas.height * 0.42, 30, canvas.width * 0.5, canvas.height * 0.5, canvas.width);
      bg.addColorStop(0, "#311745");
      bg.addColorStop(0.24, "#17091f");
      bg.addColorStop(0.58, "#070913");
      bg.addColorStop(1, "#02040b");
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    ctx.save();
    for (let i = 0; i < 240; i += 1) {
      const x = (i * 379) % world.width - camera.x;
      const y = (i * 223 + Math.sin(frame / 70 + i) * 5) % world.height - camera.y;
      if (x < -4 || y < -4 || x > canvas.width + 4 || y > canvas.height + 4) continue;
      const size = i % 13 === 0 ? 2.4 : i % 7 === 0 ? 1.6 : 0.9;
      ctx.fillStyle = i % 9 ? "rgba(255,244,233,.58)" : "rgba(122,244,220,.7)";
      ctx.globalAlpha = 0.26 + (i % 6) * 0.08;
      ctx.fillRect(x, y, size, size);
    }
    ctx.restore();

    ctx.save();
    const left = -camera.x;
    const top = -camera.y;
    ctx.strokeStyle = "rgba(255,207,138,.18)";
    ctx.lineWidth = 8;
    ctx.strokeRect(left, top, world.width, world.height);
    ctx.restore();
  }

  function drawObstacle(ctx, obstacle, frame) {
    const visualRadius = obstacle.visualRadius || obstacle.radius;
    const collisionRadius = obstacle.collisionRadius || obstacle.radius;
    ctx.save();
    ctx.translate(obstacle.x, obstacle.y);
    ctx.rotate(obstacle.rotation + Math.sin(frame / 160 + obstacle.x) * 0.015);
    ctx.scale(obstacle.scale || 1, obstacle.scale || 1);
    if (drawObstacleSprite(ctx, obstacle, visualRadius, frame)) {
      ctx.restore();
      return;
    }
    ctx.shadowBlur = obstacle.type === "star" ? 46 : 32;
    ctx.shadowColor = obstacle.type === "ship" ? "#7af4dc" : obstacle.type === "wreck" ? "#ff6fb7" : obstacle.color;
    if (obstacle.type.includes("ship") || obstacle.type.includes("Wreck") || obstacle.type === "satellite") {
      const length = visualRadius * 1.6;
      const height = visualRadius * 0.7;
      const hull = ctx.createLinearGradient(-length * 0.75, -height * 0.45, length * 0.7, height * 0.38);
      hull.addColorStop(0, "#d7e8ff");
      hull.addColorStop(0.18, obstacle.color);
      hull.addColorStop(0.6, "#243141");
      hull.addColorStop(1, obstacle.type === "wreck" ? "#3d1825" : "#132b35");
      ctx.fillStyle = hull;
      ctx.beginPath();
      ctx.moveTo(length * 0.7, 0);
      ctx.lineTo(length * 0.18, -height * 0.48);
      ctx.lineTo(-length * 0.58, -height * 0.32);
      ctx.lineTo(-length * 0.82, height * 0.08);
      ctx.lineTo(-length * 0.34, height * 0.46);
      ctx.lineTo(length * 0.46, height * 0.32);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = "rgba(255,244,233,.58)";
      ctx.lineWidth = 3.2;
      ctx.stroke();

      const cockpit = ctx.createRadialGradient(length * 0.16, -height * 0.06, 2, length * 0.16, -height * 0.06, height * 0.34);
      cockpit.addColorStop(0, "#effff8");
      cockpit.addColorStop(0.4, "#7af4dc");
      cockpit.addColorStop(1, "rgba(122,244,220,.08)");
      ctx.fillStyle = cockpit;
      ctx.beginPath();
      ctx.ellipse(length * 0.1, -height * 0.08, length * 0.18, height * 0.18, 0.12, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = obstacle.type === "wreck" ? "rgba(255,111,183,.55)" : "rgba(122,244,220,.52)";
      ctx.lineWidth = 4;
      for (let i = 0; i < 3; i += 1) {
        ctx.beginPath();
        ctx.moveTo(-length * 0.5 + i * length * 0.22, -height * 0.22);
        ctx.lineTo(-length * 0.36 + i * length * 0.2, height * 0.28);
        ctx.stroke();
      }

      ctx.fillStyle = obstacle.type === "wreck" ? "rgba(255,111,183,.48)" : "rgba(255,207,138,.72)";
      ctx.beginPath();
      ctx.moveTo(-length * 0.78, -height * 0.14);
      ctx.lineTo(-length * 1.02, 0);
      ctx.lineTo(-length * 0.78, height * 0.14);
      ctx.closePath();
      ctx.fill();

      ctx.strokeStyle = obstacle.type === "wreck" ? "rgba(255,111,183,.28)" : "rgba(122,244,220,.26)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.ellipse(0, 0, collisionRadius, collisionRadius * 0.52, 0, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      const points = 10;
      const pulse = 1 + Math.sin(frame / 36 + obstacle.x) * 0.04;
      const glow = ctx.createRadialGradient(0, 0, 8, 0, 0, visualRadius * 1.35);
      glow.addColorStop(0, "rgba(255,244,233,.92)");
      glow.addColorStop(0.24, obstacle.color);
      glow.addColorStop(0.58, "rgba(180,108,255,.3)");
      glow.addColorStop(1, "rgba(122,244,220,0)");
      ctx.globalAlpha = 0.92;
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(0, 0, visualRadius * 1.12 * pulse, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;

      const crystal = ctx.createLinearGradient(-visualRadius, -visualRadius, visualRadius, visualRadius);
      crystal.addColorStop(0, "#fff4e9");
      crystal.addColorStop(0.32, obstacle.color);
      crystal.addColorStop(0.72, "#7af4dc");
      crystal.addColorStop(1, "#2a102d");
      ctx.fillStyle = crystal;
      ctx.beginPath();
      for (let i = 0; i < points * 2; i += 1) {
        const a = i / (points * 2) * Math.PI * 2;
        const r = i % 2 === 0 ? visualRadius * 0.82 : visualRadius * 0.34;
        const x = Math.cos(a) * r;
        const y = Math.sin(a) * r;
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = "rgba(255,244,233,.78)";
      ctx.lineWidth = 2.8;
      ctx.stroke();

      ctx.strokeStyle = "rgba(255,244,233,.32)";
      ctx.lineWidth = 1.4;
      for (let i = 0; i < 4; i += 1) {
        ctx.rotate(Math.PI / 4);
        ctx.beginPath();
        ctx.ellipse(0, 0, visualRadius * 0.96, visualRadius * 0.18, frame / 180, 0, Math.PI * 2);
        ctx.stroke();
      }

      ctx.fillStyle = "#fff4e9";
      ctx.beginPath();
      ctx.arc(-visualRadius * 0.16, -visualRadius * 0.18, visualRadius * 0.08, 0, Math.PI * 2);
      ctx.arc(visualRadius * 0.18, visualRadius * 0.1, visualRadius * 0.06, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = "rgba(255,244,233,.28)";
      ctx.lineWidth = 2;
      ctx.shadowBlur = 16;
      ctx.shadowColor = obstacle.color;
      ctx.beginPath();
      ctx.arc(0, 0, collisionRadius, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  const canvasRef = useCanvasGame((ctx, canvas, dt, frame) => {
    const state = stateRef.current;
    const isPlaying = statusRef.current === "play";

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    drawWorldBackdrop(ctx, canvas, state, frame);

    if (isPlaying && !state.over) {
      state.seconds += dt / 1000;
      state.wave = 1 + Math.floor(state.seconds / 24);
      const speed = 3.15 + state.weapons.speed * 0.34;
      const useWasd = controlMode === "wasd";
      const mx = touchRef.current.active ? touchRef.current.x : Number(Boolean(useWasd ? keysRef.current.d : keysRef.current.arrowright)) - Number(Boolean(useWasd ? keysRef.current.a : keysRef.current.arrowleft));
      const my = touchRef.current.active ? touchRef.current.y : Number(Boolean(useWasd ? keysRef.current.s : keysRef.current.arrowdown)) - Number(Boolean(useWasd ? keysRef.current.w : keysRef.current.arrowup));
      const len = Math.max(1, Math.hypot(mx, my));
      const moving = Math.hypot(mx, my) > 0.05;
      movePlayer(state, (mx / len) * speed * (dt / 16), (my / len) * speed * (dt / 16));
      updateCamera(state, canvas);
      state.player.invuln = Math.max(0, state.player.invuln - dt);
      if ((mx || my) && frame % (state.particles.length > 170 ? 4 : 2) === 0) state.particles.push({ x: state.player.x - mx * 13, y: state.player.y - my * 13, vx: -mx * 0.5 + (Math.random() - 0.5), vy: -my * 0.5 + (Math.random() - 0.5), life: 220, ttl: 220, color: "#ffcf8a" });
      if (!state.bleeding) {
        state.energy = moving ? Math.min(100, state.energy + dt * 0.065) : Math.max(0, state.energy - dt * 0.026);
        if (state.energy <= 0) {
          state.energy = 0;
          state.bleeding = true;
          state.bleedStartedAt = state.seconds;
          state.bleedHpStart = Math.max(1, state.player.hp);
          setMessage("Unstillbare Blutung entdeckt. Bewegung kam zu spaet.");
          pushRing(state, state.player.x, state.player.y, 150, 760, "#ff163f");
          burst(state.player.x, state.player.y, "#ff163f", 32);
          bleedingAlarm();
        }
      }

      if (!state.bossActive && state.seconds >= state.nextBossAt) spawnBoss(state, canvas);

      state.spawn -= dt;
      if (!state.bossActive && state.spawn <= 0) {
        const crowdPressure = Math.max(0, state.enemies.length - 58);
        const count = crowdPressure > 18 ? 1 : 1 + Math.floor(Math.min(4, Math.max(0, state.wave - 1) / 3));
        for (let i = 0; i < count; i += 1) spawnEnemy(state, canvas);
        state.spawn = Math.max(135, 780 - state.seconds * 5.4 + crowdPressure * 8);
      }

      state.timers.potion -= dt;
      if (state.timers.potion <= 0) {
        spawnPotion(state, canvas);
        const lowHealthBoost = state.player.hp < state.player.maxHp * 0.42 ? 0.52 : 1;
        state.timers.potion = (12500 + Math.random() * 6500) * lowHealthBoost;
      }
      compactSurvivorCollections(state, canvas);

      updateSpecialWeapons(state, dt, { visible: (targets, x, y) => visibleTargets(state, targets, x, y, 12), damageMult: damageMult(state), cooldownMult: cooldownMult(state), burst, ring: (x, y, radius, life, color) => pushRing(state, x, y, radius, life, color), sound: sfx });
      state.timers.bolt -= dt;
      if (state.weapons.bolt && state.timers.bolt <= 0 && state.enemies.length) {
        const targetPool = state.enemies.filter((enemy) => distanceSq(enemy.x, enemy.y, state.player.x, state.player.y) < 900 * 900).slice(0, 56);
        const targets = visibleTargets(state, targetPool, state.player.x, state.player.y, 12)
          .sort((a, b) => distanceSq(a.x, a.y, state.player.x, state.player.y) - distanceSq(b.x, b.y, state.player.x, state.player.y));
        const bolts = Math.min(targets.length, 1 + Math.floor((state.weapons.bolt - 1) / 2));
        for (let i = 0; i < bolts; i += 1) {
          const target = targets[i];
          const dx = target.x - state.player.x;
          const dy = target.y - state.player.y;
          const dist = Math.max(1, Math.hypot(dx, dy));
          state.shots.push({ type: "bolt", x: state.player.x, y: state.player.y, vx: dx / dist * 10.2, vy: dy / dist * 10.2, life: 820, damage: (14 + state.weapons.bolt * 4) * damageMult(state) * evolutionMultiplier(state.weapons.bolt), pierce: Math.floor(state.weapons.bolt / 3) });
        }
        state.timers.bolt = Math.max(130, (520 - state.weapons.bolt * 28) * cooldownMult(state));
        if (bolts > 0 && frame % 3 === 0) sfx("shot");
      }

      state.timers.egg -= dt;
      if (state.weapons.egg && state.timers.egg <= 0 && state.enemies.length) {
        const targets = visibleTargets(state, state.enemies.slice(0, 54), state.player.x, state.player.y, 16);
        const pool = targets.length ? targets : state.enemies.filter(finitePoint);
        const target = pool[Math.floor(Math.random() * pool.length)];
        const radius = 54 + state.weapons.egg * 8;
        const damage = (28 + state.weapons.egg * 8) * damageMult(state) * evolutionMultiplier(state.weapons.egg);
        if (finitePoint(target) && finitePoint(state.player) && Number.isFinite(radius) && Number.isFinite(damage)) {
          state.bombs.push({
            x: state.player.x,
            y: state.player.y,
            tx: target.x,
            ty: target.y,
            life: 650,
            ttl: 650,
            radius,
            damage,
            exploded: false,
          });
          sfx("bomb");
        }
        state.timers.egg = Math.max(650, (2100 - state.weapons.egg * 110) * cooldownMult(state));
      }

      state.timers.drone -= dt;
      if (state.weapons.drone && state.timers.drone <= 0 && state.enemies.length) {
        const count = Math.min(6, state.weapons.drone);
        const targets = visibleTargets(state, state.enemies.slice(0, 56), state.player.x, state.player.y, 12)
          .sort((a, b) => distanceSq(a.x, a.y, state.player.x, state.player.y) - distanceSq(b.x, b.y, state.player.x, state.player.y));
        const shots = targets.length ? count : 0;
        for (let i = 0; i < shots; i += 1) {
          const target = targets[i % targets.length];
          const angle = frame / 32 + i / count * Math.PI * 2;
          const x = state.player.x + Math.cos(angle) * 58;
          const y = state.player.y + Math.sin(angle) * 58;
          const dx = target.x - x;
          const dy = target.y - y;
          const dist = Math.max(1, Math.hypot(dx, dy));
          state.shots.push({ type: "drone", x, y, vx: dx / dist * 11.4, vy: dy / dist * 11.4, life: 720, damage: (11 + state.weapons.drone * 3.8) * damageMult(state) * evolutionMultiplier(state.weapons.drone), pierce: 0 });
        }
        state.timers.drone = Math.max(120, (660 - state.weapons.drone * 54) * cooldownMult(state));
        if (shots > 0) sfx("drone");
      }

      state.timers.thunder -= dt;
      if (state.weapons.thunder && state.timers.thunder <= 0 && state.enemies.length) {
        let ox = state.player.x;
        let oy = state.player.y;
        const chain = [];
        const pool = [...state.enemies];
        for (let step = 0; step < 2 + state.weapons.thunder + evolutionTier(state.weapons.thunder) * 2 && pool.length; step += 1) {
          const visible = visibleTargets(state, pool.slice(0, 58), ox, oy, 16).sort((a, b) => distanceSq(a.x, a.y, ox, oy) - distanceSq(b.x, b.y, ox, oy));
          const next = visible[0];
          if (!next) break;
          chain.push(next);
          pool.splice(pool.indexOf(next), 1);
          ox = next.x;
          oy = next.y;
        }
        ox = state.player.x;
        oy = state.player.y;
        chain.forEach((enemy, index) => {
          state.beams.push({ x1: ox, y1: oy, x2: enemy.x, y2: enemy.y, life: 190, ttl: 190, color: "#ffe66d", width: 5 - Math.min(2, index * 0.4) });
          enemy.hp -= (18 + state.weapons.thunder * 7) * damageMult(state) * evolutionMultiplier(state.weapons.thunder);
          ox = enemy.x;
          oy = enemy.y;
        });
        state.timers.thunder = Math.max(720, (2700 - state.weapons.thunder * 160) * cooldownMult(state));
        sfx("thunder");
      }

      state.timers.gravity -= dt;
      if (state.weapons.gravity && state.timers.gravity <= 0 && state.enemies.length) {
        const target = [...state.enemies].sort((a, b) => b.hp - a.hp)[0];
        state.wells.push({ x: target.x, y: target.y, radius: 92 + state.weapons.gravity * 16, life: 2400, ttl: 2400, damage: (0.045 + state.weapons.gravity * 0.025) * damageMult(state) * evolutionMultiplier(state.weapons.gravity) });
        state.timers.gravity = Math.max(1600, (5400 - state.weapons.gravity * 260) * cooldownMult(state));
        sfx("nova");
      }

      state.timers.nova -= dt;
      if (state.weapons.nova && state.timers.nova <= 0) {
        const radius = clamp(150 + state.weapons.nova * 26, 80, 420);
        const damage = (22 + state.weapons.nova * 8) * damageMult(state) * evolutionMultiplier(state.weapons.nova);
        state.enemies.forEach((enemy) => {
          if (!finitePoint(enemy) || !Number.isFinite(enemy.hp)) return;
          const dist = Math.hypot(enemy.x - state.player.x, enemy.y - state.player.y);
          if (dist < radius) {
            enemy.hp -= damage;
            const dx = (enemy.x - state.player.x) / Math.max(1, dist);
            const dy = (enemy.y - state.player.y) / Math.max(1, dist);
            enemy.x += dx * 22;
            enemy.y += dy * 22;
            pushOutOfObstacles(state, enemy, enemy.radius || 14);
          }
        });
        pushRing(state, state.player.x, state.player.y, radius, 420, "#ff6fb7");
        state.timers.nova = Math.max(1800, (6200 - state.weapons.nova * 390) * cooldownMult(state));
        sfx("level");
      }

      state.timers.laser -= dt;
      if (state.weapons.laser && state.timers.laser <= 0 && state.enemies.length) {
        const target = visibleTargets(state, state.enemies.slice(0, 64), state.player.x, state.player.y, 18).sort((a, b) => b.hp - a.hp)[0];
        if (target) {
          state.beams.push({ x1: state.player.x, y1: state.player.y, x2: target.x, y2: target.y, life: 220, ttl: 220, color: "#7af4dc", width: 7 });
          target.hp -= (40 + state.weapons.laser * 18) * damageMult(state) * evolutionMultiplier(state.weapons.laser);
          sfx("laser");
        }
        state.timers.laser = Math.max(950, (3600 - state.weapons.laser * 220) * cooldownMult(state));
      }

      state.timers.regen -= dt;
      if (state.weapons.regen && state.timers.regen <= 0) {
        state.player.hp = Math.min(state.player.maxHp, state.player.hp + 1.6 + state.weapons.regen * 0.8);
        state.timers.regen = 1000;
      }
      state.timers.comfortRegen -= dt;
      if (state.timers.comfortRegen <= 0) {
        state.player.hp = Math.min(state.player.maxHp, state.player.hp + 1.2);
        state.timers.comfortRegen = 1000;
      }

      state.enemies.forEach((enemy) => {
        const dx = state.player.x - enemy.x;
        const dy = state.player.y - enemy.y;
        const dist = Math.max(1, Math.hypot(dx, dy));
        enemy.slow = Math.max(0, (enemy.slow || 0) - dt);
        enemy.ability = Math.max(0, (enemy.ability || 0) - dt);
        enemy.rage = Math.max(0, (enemy.rage || 0) - dt);
        const enemySpeed = enemy.speed * (enemy.slow > 0 ? 0.48 : 1);
        const bossRush = enemy.boss && enemy.phase > 0 ? 2.35 : 1;
        let moveX = dx / dist * enemySpeed * bossRush;
        let moveY = dy / dist * enemySpeed * bossRush;
        enemy.x += (moveX + Math.sin(state.seconds * 3 + enemy.wobble) * (enemy.boss ? 0.72 : 0.24)) * (dt / 16);
        enemy.y += (moveY + Math.cos(state.seconds * 2 + enemy.wobble) * (enemy.boss ? 0.58 : 0.18)) * (dt / 16);
        pushOutOfObstacles(state, enemy, enemy.radius);
        if (enemy.boss) {
          enemy.phase = Math.max(0, enemy.phase - dt / 620);
          if (frame % 8 === 0) {
            burst(enemy.x + Math.sin(frame / 9) * 54, enemy.y + Math.cos(frame / 11) * 38, enemy.rage > 0 ? "#ffcf8a" : "#ff6fb7", 3);
          }
          if (enemy.ability <= 0) {
            bossAttack(state, canvas, enemy);
          }
        }
        if (dist < enemy.radius + 18 && state.player.invuln <= 0) {
          const contactDamage = enemy.boss ? 24 : enemy.elite ? 12 : 8;
          state.player.hp -= Math.max(3, contactDamage - state.weapons.shield * 2.2);
          state.player.invuln = enemy.boss ? 980 : 820;
          burst(state.player.x, state.player.y, "#ff6fb7", 14);
          sfx("hit");
          if (state.player.hp <= 0 && !state.over) {
            state.over = true;
            setLastRun({ score: state.score, level: state.level, seconds: Math.floor(state.seconds), kills: state.kills });
            setGameStatus("gameover");
            setMessage(`Run beendet: ${state.score} Punkte, ${state.kills} Drohnen zerlegt.`);
          }
        }
        if (state.weapons.aura && dist < 76 + state.weapons.aura * 18) {
          enemy.hp -= (0.12 + state.weapons.aura * 0.055) * dt * damageMult(state) * evolutionMultiplier(state.weapons.aura);
        }
      });

      state.shots.forEach((shot) => {
        if (shot.type === "comet") steerComet(shot, state.enemies, dt);
        shot.x += shot.vx * (dt / 16);
        shot.y += shot.vy * (dt / 16);
        if (collidesObstacle(state, shot.x, shot.y, shot.type === "drone" ? 12 : 8)) {
          shot.life = 0;
          burst(shot.x, shot.y, "#ffcf8a", 5);
        }
        shot.life -= dt;
      });
      const shotKeep = Math.max(canvas.width, canvas.height) * 0.95;
      state.shots = state.shots.filter((shot) => shot.life > 0 && distanceSq(shot.x, shot.y, state.player.x, state.player.y) < shotKeep * shotKeep);
      state.shots.forEach((shot) => {
        const possibleTargets = state.enemies.filter((enemy) => distanceSq(shot.x, shot.y, enemy.x, enemy.y) < 96 * 96);
        possibleTargets.forEach((enemy) => {
          const hitRadius = enemy.radius + 7;
          if (distanceSq(shot.x, shot.y, enemy.x, enemy.y) < hitRadius * hitRadius && shot.life > 0) {
            if (shot.type === "comet") { explodeComet(shot, state, { burst, ring: (x, y, radius, life, color) => pushRing(state, x, y, radius, life, color), sound: sfx }); return; }
            enemy.hp -= shot.damage;
            if (enemy.boss) alienBloodBurst(shot.x, shot.y, "#ff5f7c", 8, 0.75);
            if (state.weapons.frost) {
              enemy.slow = Math.max(enemy.slow || 0, (650 + state.weapons.frost * 180) * evolutionMultiplier(state.weapons.frost));
              enemy.tint = "#9bf6ff";
              if (Math.random() < 0.12) sfx("freeze");
            }
            shot.pierce -= 1;
            if (shot.pierce < 0) shot.life = 0;
            burst(shot.x, shot.y, enemy.elite ? "#b46cff" : "#ff6fb7", 5);
          }
        });
      });

      state.bombs.forEach((bomb) => {
        if (![bomb.x, bomb.y, bomb.tx, bomb.ty, bomb.life, bomb.ttl, bomb.radius, bomb.damage].every(Number.isFinite) || bomb.ttl <= 0 || bomb.radius <= 0) {
          bomb.life = 0;
          return;
        }
        const t = clamp(1 - bomb.life / Math.max(1, bomb.ttl), 0, 1);
        bomb.x += (bomb.tx - bomb.x) * 0.08;
        bomb.y += (bomb.ty - bomb.y) * 0.08;
        const world = state.world || worldConfig;
        bomb.x = clamp(bomb.x, 0, world.width);
        bomb.y = clamp(bomb.y, 0, world.height);
        bomb.life -= dt;
        if (!bomb.exploded && (t >= 0.95 || bomb.life <= 0)) {
          bomb.exploded = true;
          state.enemies.forEach((enemy) => {
            if (finitePoint(enemy) && Math.hypot(enemy.x - bomb.x, enemy.y - bomb.y) < bomb.radius) {
              enemy.hp -= bomb.damage;
              if (enemy.boss) alienBloodBurst(enemy.x, enemy.y, "#ff5f7c", 18, 1);
            }
          });
          burst(bomb.x, bomb.y, "#ffcf8a", 24);
          bomb.life = 0;
        }
      });
      state.bombs = state.bombs.filter((bomb) => bomb.life > 0);
      state.beams.forEach((beam) => { beam.life -= dt; });
      state.beams = state.beams.filter((beam) => beam.life > 0);
      state.wells.forEach((well) => {
        well.life -= dt;
        state.enemies.forEach((enemy) => {
          const dist = Math.max(1, Math.hypot(well.x - enemy.x, well.y - enemy.y));
          if (dist < well.radius) {
            enemy.hp -= well.damage * dt;
            enemy.x += (well.x - enemy.x) / dist * (2.2 + state.weapons.gravity * 0.35) * (dt / 16);
            enemy.y += (well.y - enemy.y) / dist * (2.2 + state.weapons.gravity * 0.35) * (dt / 16);
          }
        });
      });
      state.wells = state.wells.filter((well) => well.life > 0);

      state.hazards.forEach((hazard) => {
        hazard.life -= dt;
        if (hazard.type === "ring") {
          hazard.radius = hazard.max * (1 - hazard.life / hazard.ttl);
          const dist = Math.hypot(state.player.x - hazard.x, state.player.y - hazard.y);
          if (!hazard.hit && Math.abs(dist - hazard.radius) < 24 && state.player.invuln <= 0) {
            state.player.hp -= Math.max(4, hazard.damage - state.weapons.shield * 2);
            state.player.invuln = 760;
            hazard.hit = true;
            burst(state.player.x, state.player.y, "#ff6fb7", 12);
          }
        } else if (hazard.type === "orb") {
          hazard.x += hazard.vx * (dt / 16);
          hazard.y += hazard.vy * (dt / 16);
          if (Math.hypot(state.player.x - hazard.x, state.player.y - hazard.y) < hazard.radius + 19 && state.player.invuln <= 0) {
            state.player.hp -= Math.max(4, hazard.damage - state.weapons.shield * 2);
            state.player.invuln = 760;
            hazard.life = 0;
            burst(state.player.x, state.player.y, hazard.color, 12);
          }
        } else if (hazard.type === "beam") {
          const elapsed = hazard.ttl - hazard.life;
          const beamArmed = elapsed >= (hazard.warmup || 0);
          const vx = hazard.x2 - hazard.x1;
          const vy = hazard.y2 - hazard.y1;
          const lenBeam = Math.max(1, Math.hypot(vx, vy));
          const t = Math.max(0, Math.min(1, ((state.player.x - hazard.x1) * vx + (state.player.y - hazard.y1) * vy) / (lenBeam * lenBeam)));
          const px = hazard.x1 + vx * t;
          const py = hazard.y1 + vy * t;
          const hitWidth = hazard.hitWidth || Math.max(7, (hazard.width || 12) * 0.55);
          if (beamArmed && !hazard.hit && Math.hypot(state.player.x - px, state.player.y - py) < hitWidth && state.player.invuln <= 0) {
            state.player.hp -= Math.max(4, hazard.damage - state.weapons.shield * 2);
            state.player.invuln = 820;
            hazard.hit = true;
            burst(state.player.x, state.player.y, "#ffcf8a", 16);
          }
        } else if (hazard.type === "meteor") {
          const progress = 1 - hazard.life / hazard.ttl;
          if (!hazard.exploded && progress > 0.64) {
            hazard.exploded = true;
            pushRing(state, hazard.x, hazard.y, hazard.radius * 2.8, 520, hazard.color);
            burst(hazard.x, hazard.y, hazard.color, 24);
            if (Math.hypot(state.player.x - hazard.x, state.player.y - hazard.y) < hazard.radius * 1.55 && state.player.invuln <= 0) {
              state.player.hp -= Math.max(5, hazard.damage - state.weapons.shield * 2);
              state.player.invuln = 820;
              burst(state.player.x, state.player.y, "#ffcf8a", 18);
            }
          }
        }
      });
      state.hazards = state.hazards.filter((hazard) => hazard.life > 0);
      enforceBleeding(state);
      if (state.player.hp <= 0 && !state.over) {
        state.over = true;
        setLastRun({ score: state.score, level: state.level, seconds: Math.floor(state.seconds), kills: state.kills });
        setGameStatus("gameover");
        setMessage(`Run beendet: ${state.score} Punkte, ${state.kills} Aliens zerlegt.`);
      }

      if (state.weapons.orbit) {
        const count = 2 + Math.floor(state.weapons.orbit / 2);
        const radius = 58 + state.weapons.orbit * 6;
        for (let i = 0; i < count; i += 1) {
          const angle = frame / 24 + i / count * Math.PI * 2;
          const ox = state.player.x + Math.cos(angle) * radius;
          const oy = state.player.y + Math.sin(angle) * radius;
          state.enemies.slice(0, 72).forEach((enemy) => {
            const hitRadius = enemy.radius + 12;
            if (distanceSq(enemy.x, enemy.y, ox, oy) < hitRadius * hitRadius) enemy.hp -= (0.2 + state.weapons.orbit * 0.09) * dt * damageMult(state) * evolutionMultiplier(state.weapons.orbit);
          });
        }
      }

      state.enemies = state.enemies.filter((enemy) => {
        if (enemy.hp > 0) return true;
        const points = enemy.boss ? 900 : enemy.elite ? 32 : 12;
        state.kills += 1;
        state.score += points;
        if (enemy.boss) {
          state.bossActive = false;
          state.nextBossAt = state.seconds + bossCooldownSeconds;
          state.hazards = [];
          setMessage("Boss zerlegt. Naechster Boss in 3 Minuten.");
          scorePopup(state, enemy.x, enemy.y, points, "#ffcf8a");
          alienBloodBurst(enemy.x, enemy.y, "#ff5f7c", 70, 1.25);
          burst(enemy.x, enemy.y, "#ff6fb7", 34);
        }
        state.gems.push({ x: enemy.x, y: enemy.y, value: enemy.boss ? 150 : enemy.elite ? 18 : 8, spin: Math.random() * 7 });
        return false;
      });

      const enemyKeep = Math.max(canvas.width, canvas.height) * 1.15;
      state.enemies = state.enemies.filter((enemy) => enemy.boss || distanceSq(enemy.x, enemy.y, state.player.x, state.player.y) < enemyKeep * enemyKeep);

      const magnetRadius = 58 + state.weapons.magnet * 44;
      state.gems = state.gems.filter((gem) => {
        const dist = Math.hypot(gem.x - state.player.x, gem.y - state.player.y);
        if (dist < magnetRadius) {
          gem.x += (state.player.x - gem.x) * Math.min(0.18, 5 / Math.max(1, dist));
          gem.y += (state.player.y - gem.y) * Math.min(0.18, 5 / Math.max(1, dist));
        }
        if (Math.hypot(gem.x - state.player.x, gem.y - state.player.y) < 24) {
          state.score += Math.floor(gem.value * 1.5);
          gainXp(state, gem.value);
          burst(gem.x, gem.y, "#7af4dc", 12);
          sfx("pepple");
          return false;
        }
        return true;
      });

      state.potions = state.potions.filter((potion) => {
        potion.life -= dt;
        if (potion.life <= 0) return false;
        const pickupRadius = (potion.radius || 19) + 23;
        if (distanceSq(potion.x, potion.y, state.player.x, state.player.y) < pickupRadius * pickupRadius && state.player.hp < state.player.maxHp) {
          const healed = Math.min(potion.heal || 36, state.player.maxHp - state.player.hp);
          state.player.hp += healed;
          scorePopup(state, potion.x, potion.y, Math.ceil(healed), "#5dff9a");
          burst(potion.x, potion.y, "#5dff9a", 16);
          pushRing(state, potion.x, potion.y, 76, 460, "#5dff9a");
          sfx("heal");
          return false;
        }
        return true;
      });
      enforceBleeding(state);
      if (state.player.hp <= 0 && !state.over) {
        state.over = true;
        setLastRun({ score: state.score, level: state.level, seconds: Math.floor(state.seconds), kills: state.kills });
        setGameStatus("gameover");
        setMessage(`Run beendet: ${state.score} Punkte, ${state.kills} Aliens zerlegt.`);
      }

      if (frame % 10 === 0 || state.over) syncSnapshot(state);
    }

    state.particles.forEach((particle) => {
      particle.vx = Number.isFinite(particle.vx) ? particle.vx : 0;
      particle.vy = Number.isFinite(particle.vy) ? particle.vy : 0;
      particle.ttl = Number.isFinite(particle.ttl) && particle.ttl > 0 ? particle.ttl : 1;
      if (particle.ring) particle.max = Number.isFinite(particle.max) && particle.max > 0 ? clamp(particle.max, 1, 760) : 1;
      particle.x += particle.vx * (dt / 16);
      particle.y += particle.vy * (dt / 16);
      particle.life -= dt;
    });
    state.particles = state.particles
      .filter((particle) => {
        if (!Number.isFinite(particle.x) || !Number.isFinite(particle.y) || !Number.isFinite(particle.life) || !Number.isFinite(particle.ttl) || particle.ttl <= 0 || particle.life <= 0 || (particle.ring && !Number.isFinite(particle.max))) return false;
        const keep = Math.max(canvas.width, canvas.height) * 1.25;
        return distanceSq(particle.x, particle.y, state.player.x, state.player.y) < keep * keep;
      })
      .slice(-perfCaps.particles);

    const cameraX = statusRef.current === "menu" ? 0 : (state.camera?.x || 0);
    const cameraY = statusRef.current === "menu" ? 0 : (state.camera?.y || 0);
    ctx.save();
    ctx.translate(-cameraX, -cameraY);

    if (statusRef.current !== "menu") {
      (state.obstacles || []).forEach((obstacle) => drawObstacle(ctx, obstacle, frame));
    }

    state.potions.forEach((potion) => {
      const age = clamp(potion.life / Math.max(1, potion.ttl), 0, 1);
      const pulse = Math.sin(frame / 10 + potion.spin) * 0.08 + 1;
      ctx.save();
      ctx.translate(potion.x, potion.y);
      ctx.scale(pulse, pulse);
      ctx.shadowBlur = 26;
      ctx.shadowColor = "#5dff9a";
      ctx.fillStyle = `rgba(93,255,154,${0.12 + age * 0.12})`;
      ctx.beginPath();
      ctx.arc(0, 4, 34, 0, Math.PI * 2);
      ctx.fill();

      const glass = ctx.createLinearGradient(-15, -24, 15, 24);
      glass.addColorStop(0, "rgba(255,255,255,.95)");
      glass.addColorStop(0.36, "rgba(172,255,216,.82)");
      glass.addColorStop(1, "rgba(35,82,73,.78)");
      ctx.fillStyle = glass;
      ctx.strokeStyle = "rgba(239,255,248,.82)";
      ctx.lineWidth = 2.4;
      ctx.beginPath();
      roundedCanvasRect(ctx, -13, -17, 26, 34, 8);
      ctx.fill();
      ctx.stroke();

      const liquid = ctx.createLinearGradient(0, 1, 0, 17);
      liquid.addColorStop(0, "#ff547d");
      liquid.addColorStop(0.55, "#ff1f55");
      liquid.addColorStop(1, "#771640");
      ctx.fillStyle = liquid;
      ctx.beginPath();
      roundedCanvasRect(ctx, -9, -2, 18, 17, 6);
      ctx.fill();

      ctx.fillStyle = "#fff7df";
      ctx.fillRect(-7, -25, 14, 8);
      ctx.fillStyle = "#ffcf8a";
      ctx.fillRect(-9, -29, 18, 5);
      ctx.strokeStyle = "rgba(255,255,255,.92)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(-5, -11);
      ctx.lineTo(3, -17);
      ctx.stroke();
      ctx.restore();
    });

    state.gems.forEach((gem) => {
      const spin = frame / 18 + gem.spin;
      ctx.save();
      ctx.translate(gem.x, gem.y);
      ctx.rotate(spin);
      ctx.shadowBlur = 18;
      ctx.shadowColor = "#7af4dc";
      const grd = ctx.createLinearGradient(-10, -10, 10, 10);
      grd.addColorStop(0, "#effff8");
      grd.addColorStop(0.45, "#7af4dc");
      grd.addColorStop(1, "#b46cff");
      ctx.fillStyle = grd;
      ctx.beginPath();
      ctx.moveTo(0, -10);
      ctx.lineTo(9, 0);
      ctx.lineTo(0, 10);
      ctx.lineTo(-9, 0);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    });

    state.shots.forEach((shot) => drawWeaponProjectile(ctx, shot, frame));

    state.enemies.forEach((enemy) => drawAlien(ctx, enemy, frame));

    state.beams.forEach(beam => drawBeamVfx(ctx, beam, frame, reducedMotion.current));

    state.bombs.forEach((bomb) => {
      if (![bomb.x, bomb.y, bomb.life, bomb.ttl, bomb.radius].every(Number.isFinite) || bomb.ttl <= 0 || bomb.radius <= 0) return;
      const blastProgress = clamp(1 - bomb.life / Math.max(1, bomb.ttl), 0, 1);
      const blastRadius = Math.max(1, bomb.radius * blastProgress);
      ctx.save();
      ctx.translate(bomb.x, bomb.y);
      ctx.rotate(frame / 24);
      ctx.shadowBlur = 26;
      ctx.shadowColor = "#ffcf8a";
      if (!drawSprite(ctx, "egg", 0, 0, 44, 44, { shadowBlur: 24, shadowColor: "#ffcf8a" })) {
        ctx.fillStyle = "#fff4e9";
        ctx.beginPath();
        ctx.ellipse(0, 0, 10, 14, 0.2, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.strokeStyle = "rgba(255,207,138,.5)";
      ctx.lineWidth = 2.2;
      ctx.beginPath();
      ctx.arc(0, 0, blastRadius, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    });

    state.wells.forEach((well) => {
      const alpha = Math.max(0, well.life / well.ttl);
      ctx.save();
      ctx.translate(well.x, well.y);
      ctx.rotate(frame / 38);
      ctx.globalAlpha = 0.25 + alpha * 0.38;
      ctx.shadowBlur = 42;
      ctx.shadowColor = "#6d4cff";
      drawSprite(ctx, "gravity", 0, 0, well.radius * 1.05, well.radius * 0.92, { rotate: -frame / 26, shadowBlur: 38, shadowColor: "#6d4cff" });
      ctx.strokeStyle = "#6d4cff";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.ellipse(0, 0, well.radius, well.radius * 0.36, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    });

    state.hazards.forEach((hazard) => {
      const alpha = Math.max(0, hazard.life / hazard.ttl);
      ctx.save();
      ctx.globalAlpha = Math.min(1, 0.25 + alpha);
      ctx.shadowBlur = 30;
      ctx.shadowColor = hazard.color;
      if (hazard.type === "ring") {
        ctx.strokeStyle = hazard.color;
        ctx.lineWidth = 7;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, hazard.radius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = "rgba(255,244,233,.65)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, hazard.radius + 10, 0, Math.PI * 2);
        ctx.stroke();
      } else if (hazard.type === "orb") {
        const grd = ctx.createRadialGradient(hazard.x - 6, hazard.y - 8, 2, hazard.x, hazard.y, hazard.radius * 1.6);
        grd.addColorStop(0, "#fff4e9");
        grd.addColorStop(0.4, hazard.color);
        grd.addColorStop(1, "rgba(40,7,35,.12)");
        ctx.fillStyle = grd;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, hazard.radius, 0, Math.PI * 2);
        ctx.fill();
      } else if (hazard.type === "beam") {
        const elapsed = hazard.ttl - hazard.life;
        const warmup = hazard.warmup || 0;
        const armed = elapsed >= warmup;
        const charge = warmup ? clamp(elapsed / warmup, 0, 1) : 1;
        ctx.lineCap = "round";
        ctx.strokeStyle = armed ? `rgba(255,207,138,${alpha * 0.26})` : `rgba(244,220,255,${0.12 + charge * 0.32})`;
        ctx.lineWidth = armed ? hazard.width * 1.55 : Math.max(3, hazard.width * 0.62 + charge * 5);
        ctx.beginPath();
        ctx.moveTo(hazard.x1, hazard.y1);
        ctx.lineTo(hazard.x2, hazard.y2);
        ctx.stroke();
        ctx.strokeStyle = armed ? `rgba(255,244,233,${alpha * 0.86})` : `rgba(180,108,255,${0.42 + charge * 0.34})`;
        ctx.lineWidth = armed ? Math.max(3, hazard.hitWidth || 5) : 2.4;
        ctx.beginPath();
        ctx.moveTo(hazard.x1, hazard.y1);
        ctx.lineTo(hazard.x2, hazard.y2);
        ctx.stroke();
        if (!armed) {
          const cueGap = 34;
          const dx = hazard.x2 - hazard.x1;
          const dy = hazard.y2 - hazard.y1;
          const len = Math.max(1, Math.hypot(dx, dy));
          const nx = dx / len;
          const ny = dy / len;
          ctx.strokeStyle = `rgba(255,255,255,${0.24 + charge * 0.36})`;
          ctx.lineWidth = 1.6;
          ctx.setLineDash([12, 18]);
          ctx.beginPath();
          ctx.moveTo(hazard.x1 + nx * cueGap, hazard.y1 + ny * cueGap);
          ctx.lineTo(hazard.x2 - nx * cueGap, hazard.y2 - ny * cueGap);
          ctx.stroke();
          ctx.setLineDash([]);
        }
      } else if (hazard.type === "meteor") {
        const progress = 1 - alpha;
        const warnRadius = hazard.radius * (1.8 - progress * 0.5);
        ctx.strokeStyle = `rgba(255,244,233,${0.22 + progress * 0.45})`;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, warnRadius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = hazard.color;
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, hazard.radius * (0.7 + progress * 0.5), 0, Math.PI * 2);
        ctx.stroke();
        if (!hazard.exploded) {
          ctx.fillStyle = hazard.color;
          ctx.globalAlpha = Math.min(1, 0.22 + progress * 0.55);
          ctx.beginPath();
          ctx.moveTo(hazard.x - 10, hazard.y - 90 + progress * 62);
          ctx.lineTo(hazard.x + 10, hazard.y - 90 + progress * 62);
          ctx.lineTo(hazard.x + 4, hazard.y - 8);
          ctx.lineTo(hazard.x - 4, hazard.y - 8);
          ctx.closePath();
          ctx.fill();
        }
      }
      ctx.restore();
    });

    const player = state.player;
    if (state.weapons.aura) {
      const radius = 76 + state.weapons.aura * 18;
      ctx.save();
      ctx.globalAlpha = 0.18;
      ctx.fillStyle = "#c88956";
      ctx.shadowBlur = 28;
      ctx.shadowColor = "#c88956";
      ctx.beginPath();
      ctx.arc(player.x, player.y, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    if (state.weapons.orbit) {
      const count = 2 + Math.floor(state.weapons.orbit / 2);
      const radius = 58 + state.weapons.orbit * 6;
      for (let i = 0; i < count; i += 1) {
        const angle = frame / 24 + i / count * Math.PI * 2;
        const ox = player.x + Math.cos(angle) * radius;
        const oy = player.y + Math.sin(angle) * radius;
        drawUpgradeIcon(ctx, "orbit", ox, oy, 28, "#ffcf8a", frame);
      }
    }

    state.particles.forEach((particle) => {
      if (!Number.isFinite(particle.x) || !Number.isFinite(particle.y) || !Number.isFinite(particle.life) || !Number.isFinite(particle.ttl) || particle.ttl <= 0) return;
      ctx.globalAlpha = clamp(particle.life / particle.ttl, 0, 1);
      if (particle.ring) {
        if (!Number.isFinite(particle.max) || particle.max <= 0) return;
        const ringRadius = clamp(particle.max * (1 - particle.life / particle.ttl), 1, 780);
        ctx.strokeStyle = particle.color;
        ctx.lineWidth = 3;
        ctx.shadowBlur = 22;
        ctx.shadowColor = particle.color;
        ctx.beginPath();
        ctx.arc(particle.x, particle.y, ringRadius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.shadowBlur = 0;
      } else if (particle.type === "score") {
        const alpha = clamp(particle.life / particle.ttl, 0, 1);
        const lift = 1 - alpha;
        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.font = `950 ${particle.size || 18}px Inter, Arial, sans-serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.lineWidth = 5;
        ctx.strokeStyle = "rgba(6, 4, 16, 0.78)";
        ctx.shadowBlur = 24;
        ctx.shadowColor = particle.color;
        ctx.strokeText(particle.text || "+0", particle.x, particle.y - lift * 16);
        ctx.fillStyle = particle.color;
        ctx.fillText(particle.text || "+0", particle.x, particle.y - lift * 16);
        ctx.fillStyle = "rgba(255,244,233,0.88)";
        ctx.font = `850 ${Math.max(10, (particle.size || 18) * 0.48)}px Inter, Arial, sans-serif`;
        ctx.fillText("PTS", particle.x, particle.y + (particle.size || 18) * 0.68 - lift * 16);
        ctx.restore();
      } else {
        ctx.fillStyle = particle.color;
        ctx.shadowBlur = particle.type === "slime" ? 12 : 0;
        ctx.shadowColor = particle.color;
        ctx.beginPath();
        if (particle.type === "slime") {
          ctx.ellipse(particle.x, particle.y, particle.size || 5, Math.max(2, (particle.size || 5) * 0.54), Math.atan2(particle.vy, particle.vx), 0, Math.PI * 2);
        } else {
          ctx.arc(particle.x, particle.y, 2.4, 0, Math.PI * 2);
        }
        ctx.fill();
        ctx.shadowBlur = 0;
      }
      ctx.globalAlpha = 1;
    });

    if (!["menu", "options"].includes(statusRef.current)) drawAstronautChicken(ctx, player, frame);

    ctx.restore();



    if (["menu", "options"].includes(statusRef.current)) {
      const titleImage = titleRef.current;
      if (titleImage?.complete && titleImage.naturalWidth) {
        const scale = Math.max(canvas.width / titleImage.naturalWidth, canvas.height / titleImage.naturalHeight);
        ctx.drawImage(titleImage, (canvas.width - titleImage.naturalWidth * scale) / 2, (canvas.height - titleImage.naturalHeight * scale) / 2, titleImage.naturalWidth * scale, titleImage.naturalHeight * scale);
      }
    }
    if (statusRef.current === "levelup") {
      ctx.fillStyle = "rgba(3,5,12,.44)";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
  }, [status, audioOn, volume, controlMode], recoverRun);

  function start() {
    if (!assetsReady || rewards.saving) return;
    rewards.beginRound();
    stateRef.current = makeSurvivorState();
    setChoices([]);
    setLastRun(null);
    if ("speechSynthesis" in window) window.speechSynthesis.cancel();
    setSnapshot({ score: 0, level: 1, seconds: 0, kills: 0, hp: 150, maxHp: 150, energy: 100, bleeding: false, playerX: worldConfig.spawnX, playerY: worldConfig.spawnY, xp: 0, nextXp: 45, wave: 1, weapons: [{ id: "bolt", name: "Federblitz", level: 1, color: "#c88cff", icon: "feather" }] });
    setMessage("Sammle XP-Kristalle. Beim Level-Up waehlt ihr den Build.");
    setGameStatus("play");
    requestAnimationFrame(() => stageRef.current?.focus?.());
    audio();
    sfx("start");
  }

  function chooseUpgrade(upgrade) {
    const state = stateRef.current;
    if (statusRef.current !== "levelup") return;
    state.weapons[upgrade.id] = Number(state.weapons[upgrade.id] || 0) + 1;
    if (upgrade.id === "shield") {
      state.player.maxHp += 24;
      state.player.hp = Math.min(state.player.maxHp, state.player.hp + 34);
    }
    if (upgrade.id === "speed") state.player.invuln = Math.max(state.player.invuln, 620);
    setChoices([]);
    setMessage(`${upgrade.name} Level ${state.weapons[upgrade.id]} aktiviert.`);
    syncSnapshot(state);
    sfx("start");
    setGameStatus("play");
  }

  function togglePause() {
    if (statusRef.current === "play") {
      keysRef.current = {};
      setMessage("Run pausiert. Fortsetzen bringt dich direkt zurueck ins Chaos.");
      setGameStatus("paused");
      return;
    }
    if (statusRef.current === "paused") {
      setMessage("Weiter geht's. Die Aliens haben kurz gewartet.");
      setGameStatus("play");
    }
  }

  async function toggleFullscreen() {
    const node = stageRef.current;
    if (!node || !document.fullscreenEnabled) return;
    try {
      if (document.fullscreenElement === node) await document.exitFullscreen();
      else await node.requestFullscreen();
    } catch (err) {
      console.error(err);
      setMessage("Vollbild konnte vom Browser nicht gestartet werden.");
    }
  }

  async function save() {
    if (statusRef.current !== "gameover" || rewards.submitted || rewards.saving) return;
    try {
      const state = stateRef.current;
      const build = Object.entries(state.weapons).filter(([, level]) => level > 0).map(([id, level]) => `${id}:${level}`).join(",");
      const result = await rewards.submitRound({ score: state.score, level: state.level, seconds_survived: Math.floor(state.seconds), kills: state.kills, build });
      setMessage(result.message);
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  function finishRun() {
    if (!["play", "paused", "levelup"].includes(statusRef.current)) return;
    stateRef.current.over = true;
    setChoices([]); setGameStatus("gameover");
    setMessage("Run beendet. Speichere deinen Score und sichere dir deine Chickens.");
  }

  function moveStick(event) {
    if (statusRef.current !== "play" || !touchRef.current.active) return;
    const bounds = event.currentTarget.getBoundingClientRect();
    const dx = (event.clientX - bounds.left - bounds.width / 2) / (bounds.width * 0.34), dy = (event.clientY - bounds.top - bounds.height / 2) / (bounds.height * 0.34);
    const length = Math.max(1, Math.hypot(dx, dy));
    touchRef.current = { x: dx / length, y: dy / length, active: true };
    event.currentTarget.style.setProperty("--stick-x", `${dx / length * 26}px`); event.currentTarget.style.setProperty("--stick-y", `${dy / length * 26}px`);
  }
  function releaseStick(event) {
    touchRef.current = { x: 0, y: 0, active: false };
    event.currentTarget.style.setProperty("--stick-x", "0px"); event.currentTarget.style.setProperty("--stick-y", "0px");
  }

  useEffect(() => {
    const canvas = canvasRef.current;
    canvas.__survivorGame = { get state() { return stateRef.current; }, get status() { return statusRef.current; },
      start, chooseUpgrade, gainXp: (amount) => gainXp(stateRef.current, amount), spawnBoss: () => spawnBoss(stateRef.current, canvas), upgradePool };
    return () => { delete canvas.__survivorGame; };
  }, [assetsReady, audioOn, volume]);

  useEffect(() => {
    if (!["play", "paused", "gameover", "levelup"].includes(status)) return;
    const frame = requestAnimationFrame(() => {
      if (document.hidden) return;
      const next = status === "play" ? canvasRef.current : stageRef.current?.querySelector(".survivorScreenPanel button:not(:disabled)");
      next?.focus({ preventScroll: true });
    });
    return () => cancelAnimationFrame(frame);
  }, [status, rewards.saving, rewards.submitted]);

  const healthPct = Math.max(0, Math.min(100, snapshot.hp / Math.max(1, snapshot.maxHp || 150) * 100));
  const bleeding = Boolean(snapshot.bleeding);
  const xpPct = Math.max(0, Math.min(100, snapshot.xp / Math.max(1, snapshot.nextXp) * 100));
  const bloodIntensity = status === "play" || status === "paused" || status === "levelup" ? Math.max(0, Math.min(1, (55 - healthPct) / 55)) : 0;
  const criticalHealth = status === "play" && healthPct > 0 && healthPct <= 20;
  const playerX = Number.isFinite(snapshot.playerX) ? snapshot.playerX : worldConfig.spawnX;
  const playerY = Number.isFinite(snapshot.playerY) ? snapshot.playerY : worldConfig.spawnY;
  const edgeDistance = Math.min(playerX, playerY, worldConfig.width - playerX, worldConfig.height - playerY);
  const simulationEdge = status === "play" && !criticalHealth && edgeDistance <= 260;

  useEffect(() => {
    if (!criticalHealth) {
      if (status !== "play" || healthPct > 28) criticalAlarmRef.current = 0;
      return;
    }
    const now = performance.now();
    if (now - criticalAlarmRef.current < 4200) return;
    criticalAlarmRef.current = now;
    criticalAlarm();
  }, [criticalHealth, healthPct, status, audioOn, volume]);

  const active = status === "play";
  const canFinish = ["play", "paused", "levelup"].includes(status);
  const clock = (seconds) => `${Math.floor(seconds / 60).toString().padStart(2, "0")}:${Math.floor(seconds % 60).toString().padStart(2, "0")}`;
  const bossRemaining = Math.max(0, (snapshot.nextBossAt || 180) - snapshot.seconds);
  const artStyle = (icon) => { const index = WEAPON_ART[icon] ?? 0; return { backgroundPosition: `${(index % 4) * 100 / 3}% ${Math.floor(index / 4) * 50}%` }; };
  const overlay = ["menu", "options", "paused", "gameover", "crashed", "levelup"].includes(status);

  return (
    <section className="survivorFrame survivorComplete survivorV2" data-status={status} aria-label="Pepple Survivor">
      <header className="survivorCommandHeader">
        <div className="survivorBrand"><img src="/assets/player-face.jpeg?v=2" alt="" /><div><h2>Pepple <span>Survivor</span></h2><p>Ein Build. Ein Schwarm. Dein letzter Widerstand.</p></div></div>
        <dl className="survivorCommandStats">{[["Score", snapshot.score.toLocaleString("de-DE"), Target], ["Level", snapshot.level, Sparkles], ["Welle", snapshot.wave, Zap], ["Kills", snapshot.kills, Skull], ["Zeit", clock(snapshot.seconds), Clock]].map(([label, value, Icon]) => <div key={label}><dt>{label}</dt><dd><Icon size={15} />{value}</dd></div>)}</dl>
        <div className="survivorTools">
          <ArcadeButton type="button" aria-label={audioOn ? "Sound ausschalten" : "Sound einschalten"} aria-pressed={audioOn} onClick={() => setAudioOn((value) => !value)}>{audioOn ? <Volume2 size={20} /> : <VolumeX size={20} />}</ArcadeButton>
          <ArcadeButton type="button" aria-label={status === "paused" ? "Fortsetzen" : "Pause"} disabled={!active && status !== "paused"} onClick={togglePause}>{status === "paused" ? <Play size={20} /> : <Pause size={20} />}</ArcadeButton>
          <ArcadeButton type="button" aria-label={fullscreen ? "Vollbild schließen" : "Vollbild öffnen"} onClick={toggleFullscreen}><Maximize size={19} /></ArcadeButton>
        </div>
      </header>
      <div className="survivorBattleGrid" ref={stageRef} tabIndex={-1}>
        <div className="survivorBattleMain">
          <div className="survivorStage" style={{ "--blood": bloodIntensity }}>

            <canvas className="gameCanvas survivorCanvas" ref={canvasRef} tabIndex={0} width="1280" height="720" aria-label="Pepple Survivor Spielfeld. WASD oder Pfeiltasten bewegen, Waffen feuern automatisch." />
            <div className="survivorCombatHud" aria-live="off">
              <div className="survivorCombatMeter survivorHealth"><Heart size={18} fill="currentColor" /><span><i style={{ width: `${healthPct}%` }} /><b>{snapshot.hp} / {snapshot.maxHp}</b></span></div>
              <div className="survivorCombatMeter survivorXp"><Sparkles size={17} /><span><i style={{ width: `${xpPct}%` }} /><b>Level {snapshot.level} · {snapshot.xp} / {snapshot.nextXp} XP</b></span></div>
            </div>
            {fullscreen && <ArcadeButton type="button" className="survivorFullExit" aria-label="Vollbild schließen" onClick={toggleFullscreen}><Minimize size={20} /></ArcadeButton>}
            <div className="bloodEdge" aria-hidden="true" />
            {bleeding && active && <div className="survivorCombatWarning" role="alert">Unstillbare Blutung! Bewegung kam zu spät.</div>}
            {!bleeding && criticalHealth && <div className="survivorCombatWarning" role="alert">Leben kritisch! Such dir einen Heiltrank.</div>}
            {simulationEdge && <div className="survivorEdgeHint">Rand der Simulation</div>}
            {overlay && <div className={`survivorScreenOverlay ${status === "menu" ? "isMenu" : ""} ${status === "levelup" ? "isUpgrade" : ""}`}>
              {status === "levelup" ? <div className="survivorScreenPanel survivorUpgradePanel">
                <h3>Level {snapshot.level} <span>erreicht</span></h3><p>Wähle dein nächstes Upgrade.</p>
                <div className="survivorUpgradeGrid">{choices.map((choice) => <ArcadeButton type="button" key={choice.id} className="survivorUpgradeCard" style={{ "--weapon": choice.color }} onClick={() => chooseUpgrade(choice)}>
                  <span className="survivorUpgradeArt" style={artStyle(choice.icon)} />
                  <strong>{choice.name}</strong><small>{choice.level === 1 ? choice.kind === "weapon" ? "Neue Waffe" : "Neuer Effekt" : `Level ${choice.level}${choice.kind === "weapon" && [4, 8].includes(choice.level) ? " · Evolution" : ""}`}</small>
                  <em>{choice.desc}</em><b>Wählen</b>
                </ArcadeButton>)}</div><small>Das Spiel ist pausiert, bis du gewählt hast.</small>
              </div> : status === "options" ? <div className="survivorScreenPanel survivorOptions">
                <h3>Dein Spielgefühl</h3><label>Bewegung<select value={controlMode} onChange={(event) => setControlMode(event.target.value)}><option value="wasd">WASD</option><option value="arrows">Pfeiltasten</option></select></label>
                <label>Sound<input type="checkbox" checked={audioOn} onChange={(event) => setAudioOn(event.target.checked)} /></label>
                <label>Lautstärke<input type="range" min="0" max="1" step="0.05" value={volume} onChange={(event) => setVolume(Number(event.target.value))} /></label>
                <ArcadeButton type="button" className="survivorPrimary" onClick={() => setGameStatus("menu")}>Zurück zum Spiel</ArcadeButton>
              </div> : <div className="survivorScreenPanel">
                <h3>{assetError ? "Kurzer Systemcheck." : !assetsReady ? "Dein Arsenal lädt …" : status === "menu" ? "Bereit für den Schwarm?" : status === "paused" ? "Einmal Luft holen." : status === "crashed" ? "Run unterbrochen." : "Run beendet"}</h3>
                <p>{assetError || (status === "menu" ? "Sammle XP. Entwickle deine Waffen. Überlebe das Chaos." : status === "paused" ? "Dein Build wartet. Der Schwarm auch." : status === "crashed" ? "Dein Ergebnis bleibt erhalten. Starte direkt einen neuen Run." : `${snapshot.kills} Kills · Level ${snapshot.level} · ${clock(snapshot.seconds)}`)}</p>
                {status === "gameover" && <strong className="survivorFinalScore">{snapshot.score.toLocaleString("de-DE")}<small>Punkte</small></strong>}
                {status === "gameover" && user && snapshot.score > 0 && <ArcadeButton type="button" className="survivorPrimary" onClick={save} disabled={rewards.saving || rewards.submitted}>{rewards.saving ? "Speichert …" : rewards.submitted ? "Runde gewertet" : "Score & Chickens einreichen"}</ArcadeButton>}
                {status === "gameover" && !user && <p className="survivorGuestNote">Melde dich an, um deinen Score zu speichern und Chickens zu verdienen.</p>}
                <ArcadeButton type="button" className={status === "gameover" ? "survivorSecondary" : "survivorPrimary"} disabled={(!assetsReady && !assetError) || rewards.saving} onClick={() => assetError ? setAssetAttempt((value) => value + 1) : status === "paused" ? togglePause() : start()}>
                  {status === "gameover" || assetError ? <RefreshCw size={18} /> : <Play size={18} fill="currentColor" />}{assetError ? "Erneut laden" : !assetsReady ? "Lade Spielwelt …" : status === "paused" ? "Fortsetzen" : status === "gameover" || status === "crashed" ? "Nochmal spielen" : "Spiel starten"}
                </ArcadeButton>
                {status === "menu" && <ArcadeButton type="button" className="survivorSecondary" onClick={() => setGameStatus("options")}>Optionen</ArcadeButton>}
                {status === "gameover" && <p className="survivorSaveFeedback" role="status">{message}</p>}
              </div>}
            </div>}
          </div>
          <div className="survivorControlBar"><span className="survivorKeycaps"><kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd><i>/ Pfeiltasten</i></span><span>Bewegen · Waffen feuern automatisch</span><span className="survivorPauseHint"><kbd>P</kbd> Pause</span>
            <ArcadeButton type="button" className="survivorFinish" onClick={finishRun} disabled={!canFinish || rewards.saving}><Flag size={16} /> Run beenden</ArcadeButton>
          </div>
          <div className="survivorMobileInput"><div><strong>In Bewegung bleiben.</strong><p>Halte den Stick in deine Richtung.<br />Deine Waffen übernehmen den Rest.</p></div>
            <div className="survivorJoystick" role="group" aria-label="Bewegungsstick" onPointerDown={(event) => { if (!active) return; event.preventDefault(); event.currentTarget.setPointerCapture(event.pointerId); touchRef.current.active = true; moveStick(event); }} onPointerMove={moveStick} onPointerUp={releaseStick} onPointerCancel={releaseStick} onLostPointerCapture={releaseStick}><span /></div>
          </div>
        </div>
        <div className="survivorSidebarHost"><aside className="survivorSide">
          <h3>Dein <span>Arsenal</span></h3>
          <div className="survivorArsenal">{snapshot.weapons.map((weapon) => <div className="survivorWeaponSlot" key={weapon.id} style={{ "--weapon": weapon.color }}><span className="survivorWeaponArt" style={artStyle(weapon.icon)} /><div><strong>{weapon.name}</strong><small>Lv. {weapon.level}{weapon.level >= 4 && upgradePool.find((entry) => entry.id === weapon.id)?.kind === "weapon" ? " · Evolution" : ""}</small><span className="survivorWeaponPips">{Array.from({ length: 8 }, (_, index) => <i key={index} className={index < weapon.level ? "isFilled" : ""} />)}</span></div></div>)}</div>
          <div className="survivorBossPanel"><div><strong>{snapshot.bossActive ? "Boss aktiv" : "Nächster Boss"}</strong><b>{snapshot.bossActive ? `${Math.ceil(snapshot.bossHp)} HP` : clock(bossRemaining)}</b></div><span><i style={{ width: `${snapshot.bossActive ? snapshot.bossHp / snapshot.bossMaxHp * 100 : (1 - bossRemaining / 180) * 100}%` }} /></span></div>
          <div className="survivorEnergyPanel" data-low={snapshot.energy < 25}><div><strong>Bewegungsenergie</strong><b>{snapshot.energy}%</b></div><span><i style={{ width: `${snapshot.energy}%` }} /></span><small>Bewegung schützt vor Blutung.</small></div>
          <div className="survivorScorePanel"><h3>Highscores</h3>{renderScoreboard?.(refreshKey)}</div>
        </aside></div>
      </div>
      {message && status !== "gameover" && <p className="survivorRunMessage" role="status">{message}</p>}
    </section>
  );
}
