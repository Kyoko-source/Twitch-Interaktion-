import React, { useEffect, useRef, useState } from "react";
import { Check, Copy, ExternalLink, Eye, Radio, Send, Video } from "lucide-react";
import { api } from "../api";
import "./live-news.css";

const empty = { message: "", kind: "breaking", speed: 90, enabled: false };
const types = [
  { id: "breaking", label: "Breaking News", color: "#fa5366" },
  { id: "normal", label: "Normale News", color: "#69aaff" },
  { id: "community", label: "Community News", color: "#cf90fb" },
];

export function LiveNewsAdmin({ password }) {
  const [draft, setDraft] = useState(empty);
  const [published, setPublished] = useState(null);
  const [preview, setPreview] = useState(empty);
  const [busy, setBusy] = useState(false);
  const [visibilityPending, setVisibilityPending] = useState(null);
  const [status, setStatus] = useState("");
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);
  const frame = useRef(null);
  const copyTimer = useRef(null);
  const sourceUrl = `${window.location.origin}/overlays/live-news.html`;

  useEffect(() => {
    const controller = new AbortController();
    setPublished(null);
    setError("");
    api("/api/admin/live-news", { headers: { "X-Admin-Password": password }, signal: controller.signal })
      .then((state) => {
        setPublished(state);
        setDraft({ message: state.message, kind: state.kind, speed: state.speed, enabled: state.enabled });
        setPreview(state);
      })
      .catch((err) => { if (!controller.signal.aborted) setError(err.message); });
    return () => { controller.abort(); clearTimeout(copyTimer.current); };
  }, [password]);

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
      if (options.method === "PUT") setPreview(state);
      setStatus(success);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
      setVisibilityPending(null);
    }
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

  const ready = published !== null && !busy;
  const valid = Boolean(draft.message.trim());
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
          if (ready && valid) save({ method: "PUT", body: JSON.stringify({ ...draft, enabled: true }) }, "Nachricht ist live.");
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
          <div className="liveNewsActions">
            <button type="button" className="ghost" disabled={!ready || !valid}
              onClick={() => { setPreview({ ...draft, enabled: true }); setStatus("Vorschau aktualisiert."); }}><Eye size={17} /> Vorschau</button>
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
              <iframe ref={frame} src="/overlays/live-news.html?preview=1" title="Live News Vorschau" onLoad={sendPreview} />
            </div>
          </div>
          <div className="liveNewsPublished">
            <strong>Zuletzt veroeffentlicht</strong>
            <p>{published?.message || "Noch keine Nachricht"}</p>
            {published?.updated_at && <time dateTime={published.updated_at}>{new Date(published.updated_at).toLocaleString("de-DE")}</time>}
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
