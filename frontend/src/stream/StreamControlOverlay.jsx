// Admin Stream Control overlay (OBS/Streamlabs browser source, 1920 × 1080, transparent).
//   /stream/control           live: plays every effect an admin fires
//   /stream/control?muted=1   silent copy for the preview in the admin area
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { StreamAudio } from "./audio.js";
import { BY_ID, VIDEOS } from "./effects.js";
import { StreamFx } from "./engine.js";
import "./stream-control.css";

const STALE = 15;   // seconds; older events are not replayed

const TEXT = {
  hype: { big: "HYPE!!!", tone: "fire" },
  gg: { big: "GG", sub: "GUT GESPIELT!", tone: "gold" },
  respect: { big: "F", sub: "RESPEKT GEZOLLT", tone: "key" },
  clutch: { big: "CLUTCH!", tone: "electric" },
  fail: { big: "FAIL!", tone: "stamp" },
  wow: { big: "WOW!", tone: "gold" },
  laugh: { big: "LOL", tone: "fun" },
  rip: { big: "R.I.P.", sub: "🪦", tone: "grave" },
};
const TINT = {
  "noir-rain": "scNoir", thunderstorm: "scStorm", sandstorm: "scSand", underwater: "scWater", fire: "scFireGlow", frost: "scFrost",
  sunset: "scSunset", "night-vision": "scNV", vhs: "scScan", "old-film": "scSepia", horror: "scHorror", rip: "scGray", matrix: "scDim", hype: "scFireGlow",
};

function Layer({ fx }) {
  const text = TEXT[fx.id];
  return (
    <div className={`scEffect${fx.leaving ? " leaving" : ""}`} data-effect={fx.id}>
      {TINT[fx.id] && <div className={`scTint ${TINT[fx.id]}`} />}
      {fx.id === "night-vision" && <div className="scHud nv"><span>NV ◉ 4.0×</span><span>{new Date().toLocaleTimeString("de-DE")}</span></div>}
      {text && <div className={`scText tone-${text.tone}`}><b>{text.big}</b>{text.sub && <small>{text.sub}</small>}</div>}
      {fx.id === "sunglasses" && (
        <div className="scGlasses">
          <svg viewBox="0 0 26 6" shapeRendering="crispEdges" aria-hidden="true">
            <path d="M0 0h26v1H0zM1 1h10v1H1zM15 1h10v1H15zM1 2h9v1H1zM16 2h9v1H16zM2 3h7v1H2zM17 3h7v1H17zM3 4h5v1H3zM18 4h5v1H18zM11 1h4v1h-4z" fill="#000" />
            <path d="M2 1h2v1H2zM3 2h2v1H3zM17 1h2v1h-2zM18 2h2v1h-2z" fill="#fff" />
          </svg>
          <b>DEAL WITH IT</b>
        </div>
      )}
      {fx.id === "countdown" && <div className="scCount">{["3", "2", "1", "LOS!"].map((n, i) => <b key={n} style={{ animationDelay: `${i}s` }}>{n}</b>)}</div>}
    </div>
  );
}

export function StreamControlOverlay() {
  const params = useMemo(() => new URLSearchParams(window.location.search), []);
  const muted = params.get("muted") === "1";
  const [layers, setLayers] = useState([]);
  const [ad, setAd] = useState(null);
  const canvas = useRef(null);
  const engine = useRef(null);
  const stops = useRef(new Map());
  const timers = useRef([]);
  const lastId = useRef(null);
  const audio = useMemo(() => new StreamAudio(), []);

  useEffect(() => {
    document.documentElement.classList.add("streamOverlay");
    if (muted) { audio.setSfx(false); audio.setMusic(false); }
    engine.current = new StreamFx(canvas.current, (name) => audio.fx(name));
    return () => {
      document.documentElement.classList.remove("streamOverlay");
      engine.current?.dispose(); timers.current.forEach(clearTimeout);
      for (const stop of stops.current.values()) stop?.();
      audio.music(null); audio.dispose?.();
    };
  }, [audio, muted]);

  const later = (ms, fn) => { const t = setTimeout(fn, ms); timers.current.push(t); };

  const stopAll = useCallback(() => {
    engine.current?.stop();
    for (const stop of stops.current.values()) stop?.();
    stops.current.clear();
    setLayers((all) => all.map((l) => ({ ...l, leaving: true })));
    later(900, () => setLayers([]));
    setAd((a) => (a ? { ...a, leaving: true } : a));
    later(900, () => setAd(null));
  }, []);

  const play = useCallback((event) => {
    const meta = BY_ID[event.effect];
    if (event.effect === "stop") { stopAll(); return; }
    if (!meta) return;
    audio.ensure();
    if (event.effect === "ad") {
      const video = VIDEOS.find((v) => v.id === event.video);
      if (video) setAd({ key: event.id, src: video.file, label: video.label });
      return;
    }
    const dur = event.duration || meta.dur;
    const key = event.id;
    engine.current?.add(event.effect, dur, key);
    const stop = audio.start(event.effect, dur);
    if (stop) stops.current.set(key, stop);
    setLayers((all) => [...all, { key, id: event.effect, dur }]);
    later(dur * 1000, () => { stops.current.get(key)?.(); stops.current.delete(key); setLayers((all) => all.map((l) => (l.key === key ? { ...l, leaving: true } : l))); });
    later(dur * 1000 + 900, () => setLayers((all) => all.filter((l) => l.key !== key)));
  }, [audio, stopAll]);

  useEffect(() => {
    let timer = 0, alive = true;
    const poll = async () => {
      const ctrl = typeof AbortController === "function" ? new AbortController() : null;
      const abort = setTimeout(() => ctrl?.abort(), 4000);
      try {
        const response = await fetch("/api/stream-control", { cache: "no-store", signal: ctrl?.signal });
        if (response.ok) {
          const data = await response.json();
          if (lastId.current === null) lastId.current = data.last_id;   // nothing old on (re)load
          for (const event of data.events || []) {
            if (event.id <= lastId.current) continue;
            lastId.current = event.id;
            if (data.server_time - event.created < STALE) play(event);
          }
        }
      } catch { /* keep polling */ }
      clearTimeout(abort);
      if (alive) timer = setTimeout(poll, 1000);
    };
    poll();
    return () => { alive = false; clearTimeout(timer); };
  }, [play]);

  return (
    <div className="scRoot">
      {layers.map((fx) => <Layer key={fx.key} fx={fx} />)}
      <canvas ref={canvas} className="scCanvas" aria-hidden="true" />
      {ad && (
        <div className={`scAd${ad.leaving ? " leaving" : ""}`} key={ad.key}>
          <video src={ad.src} autoPlay playsInline muted={muted} onEnded={() => { setAd((a) => (a ? { ...a, leaving: true } : a)); later(900, () => setAd(null)); }} onError={() => setAd(null)} />
          <span className="scAdTag">WERBUNG · {ad.label}</span>
        </div>
      )}
    </div>
  );
}
