import React, { useEffect, useRef, useState } from "react";
import { Check, Copy, ExternalLink, Eye, Radio, Send, Square, Video, Volume2 } from "lucide-react";
import { api } from "../api";
import "./live-news.css";

const empty = {
  message: "", kind: "breaking", speed: 90, enabled: false,
  playback_mode: "loops", repeat_count: 3, duration_seconds: 30, cycle_seconds: 30,
  sound_enabled: true, volume: 70,
};
const types = [
  { id: "breaking", label: "Breaking News", color: "#fa5366" },
  { id: "normal", label: "Normale News", color: "#69aaff" },
  { id: "community", label: "Community News", color: "#cf90fb" },
];

function inRange(value, min, max) {
  return Number.isInteger(value) && value >= min && value <= max;
}

export function LiveNewsAdmin({ password }) {
  const [draft, setDraft] = useState(empty);
  const [published, setPublished] = useState(null);
  const [preview, setPreview] = useState(empty);
  const [busy, setBusy] = useState(false);
  const [visibilityPending, setVisibilityPending] = useState(null);
  const [status, setStatus] = useState("");
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);
  const [frameReady, setFrameReady] = useState(false);
  const [audioPlaying, setAudioPlaying] = useState(false);
  const frame = useRef(null);
  const previewRun = useRef(0);
  const previewAudio = useRef(null);
  const copyTimer = useRef(null);
  const sourceUrl = `${window.location.origin}/overlays/live-news.html`;

  useEffect(() => {
    const controller = new AbortController();
    setPublished(null);
    setError("");
    api("/api/admin/live-news", { headers: { "X-Admin-Password": password }, signal: controller.signal })
      .then((state) => {
        setPublished(state);
        const { revision, updated_at, ends_at, ...settings } = state;
        setDraft({ ...empty, ...settings });
        setPreview(state);
      })
      .catch((err) => { if (!controller.signal.aborted) setError(err.message); });
    return () => { controller.abort(); clearTimeout(copyTimer.current); };
  }, [password]);

  useEffect(() => {
    if (busy) return;
    const controller = new AbortController();
    const timer = setInterval(() => {
      api("/api/admin/live-news", { headers: { "X-Admin-Password": password }, signal: controller.signal })
        .then(setPublished).catch(() => {});
    }, 2000);
    return () => { controller.abort(); clearInterval(timer); };
  }, [password, busy]);

  useEffect(() => {
    previewAudio.current?.pause();
    previewAudio.current = null;
    setAudioPlaying(false);
    return () => {
      const audio = previewAudio.current;
      previewAudio.current = null;
      audio?.pause();
    };
  }, [draft.kind, draft.volume, draft.sound_enabled]);

  function sendPreview() {
    frame.current?.contentWindow?.postMessage({ type: "live-news-preview", state: preview }, window.location.origin);
  }
  useEffect(sendPreview, [preview]);

  async function save(options, success) {
    setBusy(true);
    setError("");
    setStatus("");
    try {
      const state = await api("/api/admin/live-news", {
        ...options, headers: { "X-Admin-Password": password },
      });
      setPublished(state);
      if (options.method === "PUT") setPreview({ ...state, preview_id: ++previewRun.current });
      setStatus(success);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
      setVisibilityPending(null);
    }
  }

  function publish() {
    try {
      const cycle_seconds = frame.current.contentWindow.liveNewsCycleSeconds(draft);
      previewAudio.current?.pause();
      previewAudio.current = null;
      setAudioPlaying(false);
      save({ method: "PUT", body: JSON.stringify({
        ...draft, cycle_seconds, enabled: true,
        repeat_count: inRange(draft.repeat_count, 1, 20) ? draft.repeat_count : empty.repeat_count,
        duration_seconds: inRange(draft.duration_seconds, 5, 3600) ? draft.duration_seconds : empty.duration_seconds,
      }) }, "Nachricht ist live.");
    } catch {
      setError("Vorschau wird noch geladen. Bitte erneut versuchen.");
    }
  }

  function testSound() {
    if (previewAudio.current) {
      previewAudio.current.pause();
      previewAudio.current = null;
      setAudioPlaying(false);
      return;
    }
    const audio = new Audio(`/overlays/sounds/${draft.kind}.wav`);
    previewAudio.current = audio;
    audio.volume = draft.volume / 100;
    audio.onended = () => {
      if (previewAudio.current === audio) { previewAudio.current = null; setAudioPlaying(false); }
    };
    setError("");
    audio.play().then(() => {
      if (previewAudio.current === audio) setAudioPlaying(true);
    }).catch(() => {
      if (previewAudio.current === audio) {
        previewAudio.current = null;
        setAudioPlaying(false);
        setError("Sound konnte nicht abgespielt werden.");
      }
    });
  }

  async function copyUrl() {
    try {
      if (navigator.clipboard && window.isSecureContext) await navigator.clipboard.writeText(sourceUrl);
      else {
        const input = document.getElementById("live-news-url");
        input.focus(); input.select();
        if (!document.execCommand("copy")) throw new Error("Bitte die markierte URL manuell kopieren.");
      }
      setCopied(true);
      clearTimeout(copyTimer.current);
      copyTimer.current = setTimeout(() => setCopied(false), 2500);
    } catch (err) { setError(err.message); }
  }

  const ready = published !== null && frameReady && !busy;
  const limit = draft.playback_mode === "duration" ? draft.duration_seconds : draft.repeat_count;
  const valid = Boolean(draft.message.trim()) && inRange(limit,
    draft.playback_mode === "duration" ? 5 : 1, draft.playback_mode === "duration" ? 3600 : 20);
  return (
    <section className="liveNewsAdmin">
      <header className="liveNewsHeading">
        <h2><Radio size={22} /> Live News</h2>
        <span className={`liveNewsStatus ${published?.enabled ? "on" : ""}`}>
          <i />{published?.enabled ? "Live" : "Ausgeblendet"}
        </span>
      </header>
      <div className="liveNewsWorkspace">
        <form className="liveNewsEditor form" onSubmit={(event) => {
          event.preventDefault();
          if (ready && valid) publish();
        }}>
          <label htmlFor="live-news-message">Nachricht</label>
          <textarea id="live-news-message" maxLength={1000} rows={5} value={draft.message}
            disabled={!published || busy} onChange={(event) => setDraft({ ...draft, message: event.target.value })} />
          <span className="liveNewsCount">{draft.message.length} / 1000</span>
          <fieldset className="liveNewsTypes" disabled={!ready}>
            <legend>Nachrichtentyp</legend>
            {types.map((type) => (
              <label key={type.id} style={{ "--type-color": type.color }}>
                <input type="radio" name="news-kind" value={type.id} checked={draft.kind === type.id}
                  onChange={() => setDraft({ ...draft, kind: type.id })} />
                <span className="liveNewsSwatch" />{type.label}
              </label>
            ))}
          </fieldset>
          <label className="liveNewsSpeed" htmlFor="live-news-speed">
            <span>Geschwindigkeit <output>{draft.speed} px/s</output></span>
            <input id="live-news-speed" type="range" min="40" max="220" step="5" value={draft.speed}
              disabled={!ready} onChange={(event) => setDraft({ ...draft, speed: Number(event.target.value) })} />
          </label>
          <fieldset className="liveNewsPlayback" disabled={!ready}>
            <legend>Automatisch beenden</legend>
            <div className="liveNewsModes" role="group" aria-label="Laufzeitsteuerung">
              <button type="button" aria-pressed={draft.playback_mode === "loops"}
                onClick={() => setDraft({ ...draft, playback_mode: "loops" })}>Durchlaeufe</button>
              <button type="button" aria-pressed={draft.playback_mode === "duration"}
                onClick={() => setDraft({ ...draft, playback_mode: "duration" })}>Zeitdauer</button>
            </div>
            {draft.playback_mode === "loops" ? (
              <label>Anzahl Durchlaeufe<input type="number" min="1" max="20" step="1" required value={draft.repeat_count}
                onChange={(event) => setDraft({ ...draft, repeat_count: event.target.value === "" ? "" : Number(event.target.value) })} /></label>
            ) : (
              <label>Dauer in Sekunden<input type="number" min="5" max="3600" step="1" required value={draft.duration_seconds}
                onChange={(event) => setDraft({ ...draft, duration_seconds: event.target.value === "" ? "" : Number(event.target.value) })} /></label>
            )}
          </fieldset>
          <div className="liveNewsSound">
            <label className="liveNewsVisibility">
              <input type="checkbox" checked={draft.sound_enabled} disabled={!ready}
                onChange={(event) => setDraft({ ...draft, sound_enabled: event.target.checked })} />
              Sound beim Start
            </label>
            <label className="liveNewsSpeed" htmlFor="live-news-volume">
              <span>Lautstaerke <output>{draft.volume} %</output></span>
              <input id="live-news-volume" type="range" min="0" max="100" step="5" value={draft.volume}
                disabled={!ready || !draft.sound_enabled} onChange={(event) => setDraft({ ...draft, volume: Number(event.target.value) })} />
            </label>
            <button type="button" className="ghost" disabled={!ready || !draft.sound_enabled || !draft.volume} onClick={testSound}>
              {audioPlaying ? <Square size={17} /> : <Volume2 size={17} />}{audioPlaying ? "Sound stoppen" : "Sound testen"}
            </button>
          </div>
          <div className="liveNewsActions">
            <button type="button" className="ghost" disabled={!ready || !valid}
              onClick={() => { setPreview({ ...draft, enabled: true, preview_id: ++previewRun.current }); setStatus("Vorschau aktualisiert."); }}><Eye size={17} /> Vorschau</button>
            <button type="submit" disabled={!ready || !valid}><Send size={17} /> Live schalten</button>
          </div>
          <label className="liveNewsVisibility">
            <input type="checkbox" role="switch" checked={visibilityPending ?? Boolean(published?.enabled)} disabled={!ready || !published?.message}
              onChange={(event) => {
                const enabled = event.target.checked;
                setVisibilityPending(enabled);
                save({ method: "PATCH", body: JSON.stringify({ enabled }) }, enabled ? "Ticker eingeblendet." : "Ticker ausgeblendet.");
              }} />
            Im Stream sichtbar
          </label>
          {error && <p className="notice error" role="alert">{error}</p>}
          {status && <p className="notice" role="status">{status}</p>}
        </form>
        <section className="liveNewsPreview">
          <h3>Stream-Vorschau</h3>
          <div className="liveNewsScreen">
            <Video className="liveNewsCamera" size={34} aria-hidden="true" />
            <div className="liveNewsFrameViewport">
              <iframe ref={frame} src="/overlays/live-news.html?preview=1" title="Live News Vorschau" onLoad={() => { setFrameReady(true); sendPreview(); }} />
            </div>
          </div>
          <div className="liveNewsPublished">
            <strong>Zuletzt veroeffentlicht</strong>
            <p>{published?.message || "Noch keine Nachricht"}</p>
            {published?.updated_at && <time dateTime={published.updated_at}>{new Date(published.updated_at).toLocaleString("de-DE")}</time>}
            {published?.enabled && published.ends_at && <p>Endet um {new Date(published.ends_at).toLocaleTimeString("de-DE")}</p>}
          </div>
        </section>
      </div>
      <section className="liveNewsSource">
        <div className="liveNewsSourceHeading"><h3>OBS Browserquelle</h3><span>1920 &times; 1080</span></div>
        <div className="liveNewsUrl">
          <input id="live-news-url" aria-label="Browserquellen-URL" value={sourceUrl} readOnly onFocus={(event) => event.target.select()} />
          <button type="button" className="ghost" title={copied ? "Kopiert" : "URL kopieren"} aria-label={copied ? "Kopiert" : "URL kopieren"} onClick={copyUrl}>{copied ? <Check size={19} /> : <Copy size={19} />}</button>
          <a className="liveNewsOpen" href={sourceUrl} target="_blank" rel="noopener noreferrer" title="Browserquelle oeffnen" aria-label="Browserquelle oeffnen"><ExternalLink size={19} /></a>
        </div>
      </section>
    </section>
  );
}
