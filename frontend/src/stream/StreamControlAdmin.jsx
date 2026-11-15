import React, { useEffect, useRef, useState } from "react";
import { Copy, Eye, EyeOff, Megaphone, OctagonX, Play, Radio, Timer, Volume2, VolumeX } from "lucide-react";
import { api } from "../api";
import { CATEGORIES, EFFECTS, VIDEOS } from "./effects.js";
import "./stream-admin.css";

export function StreamControlAdmin({ password }) {
  const url = `${window.location.origin}/stream/control`;
  const input = useRef(null);
  const [custom, setCustom] = useState(false);
  const [duration, setDuration] = useState(10);
  const [video, setVideo] = useState(VIDEOS[0].id);
  const [running, setRunning] = useState({});        // effect id -> until (ms)
  const [note, setNote] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState("");
  const [preview, setPreview] = useState(true);
  const [previewSound, setPreviewSound] = useState(false);
  const [, tick] = useState(0);

  useEffect(() => { const t = setInterval(() => tick((n) => n + 1), 500); return () => clearInterval(t); }, []);

  async function fire(effect, extra = {}) {
    setBusy(effect); setError("");
    const meta = EFFECTS.find((e) => e.id === effect);
    const seconds = custom ? duration : meta?.dur || 10;
    try {
      const result = await api("/api/admin/stream-control", { method: "POST", headers: { "X-Admin-Password": password }, body: JSON.stringify({ effect, duration: Math.max(3, Math.min(60, seconds || 10)), ...extra }) });
      setNote(`${meta ? `${meta.emoji} ${meta.label}` : "Stopp"}: ${result.message}`);
      if (effect === "stop") setRunning({});
      else if (effect !== "ad") setRunning((r) => ({ ...r, [effect]: Date.now() + seconds * 1000 }));
    } catch (e) { setError(e.message); } finally { setBusy(""); }
  }

  const now = Date.now();
  return (
    <section className="stack streamControl">
      <div>
        <h2><Radio size={21} /> Admin Stream Control</h2>
        <p>Effekte per Klick live im Stream einblenden. Die Browserquelle ist unsichtbar, bis du hier etwas auslöst. Mehrere Effekte lassen sich kombinieren.</p>
      </div>

      <div className="twoCol">
        <div className="panel form">
          <h3>Browserquelle für Twitch</h3>
          <label>Stream-Control-URL<input ref={input} value={url} readOnly onFocus={(e) => e.target.select()} /></label>
          <button className="ghost" type="button" onClick={async () => { try { await navigator.clipboard.writeText(url); setNote("URL kopiert."); } catch { input.current?.select(); setNote("URL markiert. Mit Strg + C kopieren."); } }}><Copy size={16} /> URL kopieren</button>
          <p>In Streamlabs oder OBS eine Browserquelle mit 1920 × 1080 anlegen, ganz oben in jede Szene legen, in der Effekte erscheinen sollen, und „Audio über OBS steuern“ aktivieren.</p>
          <div className="scDuration">
            <label className="scSwitch"><input type="checkbox" checked={custom} onChange={(e) => setCustom(e.target.checked)} /> Eigene Dauer statt Standard</label>
            {custom && <label><Timer size={15} /> {duration} Sekunden<input type="range" min="3" max="60" value={duration} onChange={(e) => setDuration(Number(e.target.value))} /></label>}
          </div>
          <button className="scStop" type="button" onClick={() => fire("stop")} disabled={busy === "stop"}><OctagonX size={20} /> ALLES STOPPEN</button>
          {note && <div className="notice" role="status">{note}</div>}
          {error && <div className="notice error" role="alert">{error}</div>}
        </div>

        <div className="panel">
          <div className="communitySectionHeading"><h3>Live-Vorschau</h3>
            <div className="row">
              <button className="ghost" type="button" onClick={() => setPreviewSound(!previewSound)} aria-pressed={previewSound}>{previewSound ? <><Volume2 size={15} /> Ton an</> : <><VolumeX size={15} /> Ton aus</>}</button>
              <button className="ghost" type="button" onClick={() => setPreview(!preview)}>{preview ? <><EyeOff size={15} /> Ausblenden</> : <><Eye size={15} /> Einblenden</>}</button>
            </div>
          </div>
          {preview && <div className="scPreview"><iframe key={previewSound ? "sound" : "muted"} title="Stream Control Vorschau" src={previewSound ? "/stream/control" : "/stream/control?muted=1"} allow="autoplay" /></div>}
          <p>{previewSound ? "Vorschau mit Ton: zum Testen. Während des Streams wieder ausschalten, sonst hörst du alles doppelt." : "Zeigt stumm genau das, was im Stream erscheint. Im Stream selbst haben Effekte und Werbung Ton."}</p>
        </div>
      </div>

      <div className="panel scAdPanel">
        <h3><Megaphone size={18} /> Werbung</h3>
        <p>Spielt das gewählte Video einmal im Vollbild mit Ton und blendet danach wieder aus.</p>
        <div className="scVideos">
          {VIDEOS.map((v) => (
            <button type="button" key={v.id} className={`scVideo${video === v.id ? " on" : ""}`} onClick={() => setVideo(v.id)} aria-pressed={video === v.id}>
              <video src={`${v.file}#t=${v.thumb || 4}`} preload="metadata" muted playsInline />
              <b>{v.label}</b>
            </button>
          ))}
        </div>
        <button type="button" onClick={() => fire("ad", { video })} disabled={busy === "ad"}><Play size={16} /> Werbung abspielen</button>
      </div>

      {CATEGORIES.map((cat) => (
        <div className="panel" key={cat.id}>
          <h3>{cat.label}</h3>
          <div className="scGrid">
            {EFFECTS.filter((e) => e.cat === cat.id && e.id !== "ad").map((e) => {
              const left = running[e.id] ? Math.ceil((running[e.id] - now) / 1000) : 0;
              return (
                <button type="button" key={e.id} className={`scBtn${left > 0 ? " live" : ""}`} onClick={() => fire(e.id)} disabled={busy === e.id} title={e.text}>
                  <span className="scEmoji">{e.emoji}</span>
                  <b>{e.label}</b>
                  <small>{left > 0 ? `läuft · ${left}s` : e.text}</small>
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </section>
  );
}
