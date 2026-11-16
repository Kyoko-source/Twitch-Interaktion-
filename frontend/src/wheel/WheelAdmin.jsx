import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Check, Copy, Maximize, Minimize, RotateCcw, Trash2, Volume2, VolumeX, X } from "lucide-react";
import { api } from "../api";
import { WheelAudio } from "./audio.js";
import { WheelStage, buyersText } from "./WheelStage.jsx";
import { colorFor } from "./engine.js";

const SOUND_KEY = "aviary-wheel-admin-sound";
const readSound = () => { try { return localStorage.getItem(SOUND_KEY) === "on"; } catch { return false; } };
const pct = (x) => `${x >= 0.1 ? Math.round(x * 100) : (x * 100).toFixed(1).replace(".", ",")} %`;
const when = (s) => new Date(s * 1000).toLocaleString("de-DE", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });

export function WheelAdmin({ password }) {
  const url = `${window.location.origin}/stream/wheel`;
  const urlInput = useRef(null);
  const stage = useRef(null);
  const audio = useMemo(() => new WheelAudio(), []);
  const [data, setData] = useState(null);
  const [spin, setSpin] = useState(null);
  const [offset, setOffset] = useState(0);
  const [sound, setSound] = useState(readSound);
  const [full, setFull] = useState(false);
  const [busy, setBusy] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState("");
  const [, tick] = useState(0);

  const call = useCallback((path, options = {}) => api(path, { ...options, headers: { "X-Admin-Password": password, ...(options.headers || {}) } }), [password]);

  const load = useCallback(async () => {
    const sent = Date.now() / 1000;
    const result = await call("/api/admin/wheel");
    setOffset(result.server_time - (sent + Date.now() / 1000) / 2);
    setData(result);
    setSpin((current) => {
      const latest = result.history[0] || null;
      if (!latest) return null;
      return current && current.id === latest.id ? { ...current, status: latest.status } : latest;
    });
  }, [call]);

  useEffect(() => { load().catch((e) => setError(e.message)); }, [load]);
  useEffect(() => { const t = setInterval(() => { load().catch(() => {}); }, 6000); return () => clearInterval(t); }, [load]);
  useEffect(() => { const t = setInterval(() => tick((n) => n + 1), 500); return () => clearInterval(t); }, []);
  useEffect(() => { audio.setSfx(sound); audio.setMusic(sound); try { localStorage.setItem(SOUND_KEY, sound ? "on" : "off"); } catch { /* private mode */ } }, [audio, sound]);
  useEffect(() => () => { audio.end(); audio.dispose?.(); }, [audio]);
  useEffect(() => {
    const onFs = () => setFull(Boolean(document.fullscreenElement || document.webkitFullscreenElement));
    document.addEventListener("fullscreenchange", onFs); document.addEventListener("webkitfullscreenchange", onFs);
    return () => { document.removeEventListener("fullscreenchange", onFs); document.removeEventListener("webkitfullscreenchange", onFs); };
  }, []);

  const now = Date.now() / 1000 + offset;
  const spinning = spin && now < spin.created + spin.intro + spin.spin + 1;
  const finished = spin && !spinning;
  const open = finished && spin.status === "open";
  const entries = data?.entries || [];
  const total = data?.total || 0;

  async function doSpin() {
    if (spinning || !entries.length) return;
    setBusy("spin"); setError(""); setNote("");
    audio.ensure();
    try {
      const sent = Date.now() / 1000;
      const result = await call("/api/admin/wheel/spin", { method: "POST", body: "{}" });
      setOffset(result.server_time - (sent + Date.now() / 1000) / 2);
      setSpin(result.spin);
      setNote("Das Rad dreht sich – live im Stream!");
    } catch (e) { setError(e.message); } finally { setBusy(""); }
  }

  async function resolve(action) {
    setBusy(action); setError("");
    try { const result = await call(`/api/admin/wheel/spins/${spin.id}/resolve`, { method: "POST", body: JSON.stringify({ action }) }); setNote(result.message); await load(); }
    catch (e) { setError(e.message); } finally { setBusy(""); }
  }

  async function remove(ids, label) {
    if (!window.confirm(`${label} vom Rad nehmen? Der Kauf selbst bleibt bestehen, Chickens werden nicht erstattet.`)) return;
    setError("");
    try { const result = await call("/api/admin/wheel/remove", { method: "POST", body: JSON.stringify({ purchase_ids: ids }) }); setNote(result.message); await load(); }
    catch (e) { setError(e.message); }
  }

  function toggleFull() {
    const el = stage.current;
    if (document.fullscreenElement || document.webkitFullscreenElement) (document.exitFullscreen || document.webkitExitFullscreen).call(document);
    else (el.requestFullscreen || el.webkitRequestFullscreen)?.call(el);
  }

  useEffect(() => {
    if (!full) return undefined;
    const onKey = (e) => { if (e.code === "Space" || e.code === "Enter") { e.preventDefault(); doSpin(); } };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  const winner = spin && spin.entries.find((e) => e.key === spin.winner);

  return (
    <section className="stack wheelAdmin">
      <div>
        <h2>🎡 Bestrafungsrad</h2>
        <p>Jede im Shop gekaufte Bestrafung landet automatisch auf dem Rad. Kaufen mehrere Leute dieselbe Bestrafung, bekommt sie mehr Lose und wird wahrscheinlicher. Drehen startet das Rad hier und gleichzeitig im Stream.</p>
      </div>

      <div className="panel">
        <div ref={stage} className="wheelStageWrap">
          <WheelStage entries={entries} spin={spin} offset={offset} hold={Boolean(open)} opaque audio={audio}>
            {full && (
              <div className="wsFsControls">
                <button type="button" onClick={doSpin} disabled={Boolean(spinning) || !entries.length}>🎡 Drehen (Leertaste)</button>
                <button type="button" className="ghost" onClick={toggleFull}><Minimize size={16} /> Vollbild beenden</button>
              </div>
            )}
          </WheelStage>
        </div>
        <div className="wheelBar">
          <button type="button" className="wheelSpinBtn" onClick={doSpin} disabled={Boolean(spinning) || busy === "spin" || !entries.length}>{spinning ? "DREHT …" : "🎡 DREHEN!"}</button>
          <button type="button" className="ghost" onClick={toggleFull}>{full ? <><Minimize size={16} /> Vollbild beenden</> : <><Maximize size={16} /> Vollbild</>}</button>
          <button type="button" className="ghost" onClick={() => { audio.ensure(); setSound(!sound); }} aria-pressed={sound}>{sound ? <><Volume2 size={16} /> Ton an</> : <><VolumeX size={16} /> Ton aus</>}</button>
        </div>
        <p>{sound ? "Ton ist hier an. Läuft gleichzeitig die Stream-Quelle, hörst du alles doppelt. Für Vollbild-Aufnahme (Fenster- oder Monitoraufnahme) so lassen." : "Ton ist hier aus, die Stream-Quelle hat ihren eigenen Ton. Willst du dieses Fenster im Vollbild aufnehmen, Ton einschalten."}</p>
        {note && <div className="notice" role="status">{note}</div>}
        {error && <div className="notice error" role="alert">{error}</div>}
      </div>

      {open && winner && (
        <div className="panel wheelResolve">
          <div>
            <h3>😈 {winner.name}</h3>
            <p>gekauft von {buyersText(winner.buyers)}</p>
          </div>
          <div className="row">
            <button type="button" onClick={() => resolve("done")} disabled={Boolean(busy)}><Check size={16} /> Erledigt – vom Rad nehmen</button>
            <button type="button" className="ghost" onClick={() => resolve("keep")} disabled={Boolean(busy)}><RotateCcw size={16} /> Bleibt drauf</button>
          </div>
        </div>
      )}

      <div className="twoCol">
        <div className="panel">
          <h3>Auf dem Rad · {entries.length} {entries.length === 1 ? "Bestrafung" : "Bestrafungen"} · {total} {total === 1 ? "Los" : "Lose"}</h3>
          {!data && <p>Lädt …</p>}
          {data && !entries.length && <p>Noch nichts drauf. Sobald jemand im Shop eine Bestrafung kauft, erscheint sie hier.</p>}
          <div className="list">
            {entries.map((entry, i) => (
              <article className="rowCard wheelEntry" key={entry.key}>
                <i style={{ background: colorFor(i, entries.length).light }} />
                <div>
                  <h4>{entry.name} {entry.weight > 1 && <span className="wheelTag">×{entry.weight}</span>}</h4>
                  <div className="wheelBuyers">
                    {entry.buyers.map((b) => (
                      <span className="wheelBuyer" key={b.purchase_id} title={`gekauft am ${when(b.created)} für ${b.price} Chickens`}>
                        {b.username} <small>{when(b.created)}</small>
                        <button type="button" className="ghost" aria-label={`Kauf von ${b.username} vom Rad nehmen`} onClick={() => remove([b.purchase_id], `Den Kauf von ${b.username}`)}><X size={12} /></button>
                      </span>
                    ))}
                  </div>
                </div>
                <div>
                  <div className="wheelChance">{pct(entry.weight / total)}</div>
                  <button type="button" className="ghost dangerButton" title="Ganz vom Rad nehmen" onClick={() => remove(entry.buyers.map((b) => b.purchase_id), `„${entry.name}“ komplett`)}><Trash2 size={16} /></button>
                </div>
              </article>
            ))}
          </div>
        </div>

        <div className="stack">
          <div className="panel form">
            <h3>Browserquelle für den Stream</h3>
            <label>Glücksrad-URL<input ref={urlInput} value={url} readOnly onFocus={(e) => e.target.select()} /></label>
            <button className="ghost" type="button" onClick={async () => { try { await navigator.clipboard.writeText(url); setNote("URL kopiert."); } catch { urlInput.current?.select(); setNote("URL markiert. Mit Strg + C kopieren."); } }}><Copy size={16} /> URL kopieren</button>
            <p>In Streamlabs oder OBS eine Browserquelle mit 1920 × 1080 ganz oben anlegen und „Audio über OBS steuern“ aktivieren. Sie bleibt unsichtbar, bis du hier drehst, dann übernimmt das Rad mit Ton den Bildschirm. Zum Einrichten zeigt <code>{url}?demo=1</code> endlos Demo-Drehungen.</p>
          </div>
          <div className="panel wheelHistory">
            <h3>Letzte Drehungen</h3>
            {data?.history?.length ? (
              <ol>
                {data.history.map((h) => {
                  const w = h.entries.find((e) => e.key === h.winner);
                  return <li key={h.id}><span><b>{w?.name || h.winner}</b><br /><small>{when(h.created)} · {buyersText(w?.buyers)}</small></span><span className={`wheelTag ${h.status}`}>{h.status === "done" ? "erledigt" : h.status === "open" ? "offen" : "bleibt drauf"}</span></li>;
                })}
              </ol>
            ) : <p>Noch nie gedreht.</p>}
          </div>
        </div>
      </div>
    </section>
  );
}
