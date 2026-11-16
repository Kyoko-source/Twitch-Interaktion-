// Background song for the Christmas look: one shared <audio>, soft fades, and a small store so
// the topbar button and the profile settings stay in sync. Browsers block sound until the visitor
// interacts with the page, so a blocked start waits for the first click or key press.
const SRC = "/music/christmas/cozy-christmas-village.mp3";
const KEY = "aviary_xmas_music";

let audio = null;
let fadeTimer = 0;
let wanted = false;
let retryArmed = false;
const listeners = new Set();

function readPrefs() {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) || "{}");
    return { muted: Boolean(raw.muted), volume: typeof raw.volume === "number" ? Math.min(1, Math.max(0, raw.volume)) : 0.35 };
  } catch {
    return { muted: false, volume: 0.35 };
  }
}

let prefs = readPrefs();

function savePrefs() {
  try { localStorage.setItem(KEY, JSON.stringify(prefs)); } catch { /* per-browser convenience only */ }
  listeners.forEach((fn) => fn({ ...prefs }));
}

function element() {
  if (!audio) {
    audio = new Audio(SRC);
    audio.loop = true;
    audio.preload = "auto";
    audio.volume = 0;
  }
  return audio;
}

function fadeTo(target, ms, done) {
  const a = element();
  window.clearInterval(fadeTimer);
  const start = a.volume, t0 = performance.now();
  fadeTimer = window.setInterval(() => {
    const t = Math.min(1, (performance.now() - t0) / ms);
    a.volume = Math.max(0, Math.min(1, start + (target - start) * t));
    if (t >= 1) { window.clearInterval(fadeTimer); done?.(); }
  }, 40);
}

function armRetry() {
  if (retryArmed) return;
  retryArmed = true;
  const go = () => {
    retryArmed = false;
    window.removeEventListener("pointerdown", go, true);
    window.removeEventListener("keydown", go, true);
    if (wanted) start(2500);
  };
  window.addEventListener("pointerdown", go, true);
  window.addEventListener("keydown", go, true);
}

function start(fadeMs) {
  const a = element();
  const playing = a.play();
  if (playing?.catch) playing.then(() => fadeTo(prefs.volume, fadeMs)).catch(() => armRetry());
  else fadeTo(prefs.volume, fadeMs);
}

// Should the song play right now? (Christmas on, not muted, not on a page with its own sound.)
export function setMusicWanted(next, fadeMs = 2500) {
  next = Boolean(next) && !prefs.muted;
  if (next === wanted) return;
  wanted = next;
  if (wanted) start(fadeMs);
  else if (audio) fadeTo(0, 900, () => { if (!wanted) audio.pause(); });
}

export function musicPrefs() {
  return { ...prefs };
}

export function setMusicMuted(muted, active) {
  prefs = { ...prefs, muted: Boolean(muted) };
  savePrefs();
  if (prefs.muted) setMusicWanted(false);
  else if (active) { wanted = false; setMusicWanted(true, 1200); }
}

export function setMusicVolume(volume) {
  prefs = { ...prefs, volume: Math.min(1, Math.max(0, Number(volume) || 0)) };
  savePrefs();
  if (audio && wanted) { window.clearInterval(fadeTimer); audio.volume = prefs.volume; }
}

export function onMusicPrefs(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
