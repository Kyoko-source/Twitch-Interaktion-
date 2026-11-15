import React, { useEffect, useRef, useState } from "react";
import { Copy, Play, Radio, Save, Trophy } from "lucide-react";
import { api } from "../api";
import "./economy.css";

export function ShopAlertsAdmin({ password }) {
  const frame = useRef(null);
  const sourceInput = useRef(null);
  const [duration, setDuration] = useState(10);
  const [purchases, setPurchases] = useState([]);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [ready, setReady] = useState(false);
  const [saving, setSaving] = useState(false);
  const url = `${window.location.origin}/overlays/shop-alert.html`;
  useEffect(() => {
    let alive = true;
    api("/api/admin/purchase-alerts", { headers: { "X-Admin-Password": password } }).then((result) => { if (alive) { setDuration(result.settings.duration_seconds); setPurchases(result.purchases); } }).catch((err) => { if (alive) setError(err.message); });
    return () => { alive = false; };
  }, [password]);
  async function save(event) {
    event.preventDefault(); setSaving(true); setMessage(""); setError("");
    try { const result = await api("/api/admin/purchase-alerts", { method: "PUT", headers: { "X-Admin-Password": password }, body: JSON.stringify({ duration_seconds: duration }) }); setMessage(result.message); }
    catch (err) { setError(err.message); } finally { setSaving(false); }
  }
  function preview(kind) {
    frame.current?.contentWindow?.postMessage({ type: "aviary-shop-preview", duration, kind }, window.location.origin);
  }
  return <section className="stack shopAlertsAdmin"><div><h2><Radio size={21} /> Bestrafungen & Highscores live im Stream</h2><p>Erfolgreiche Bestrafungskäufe und gespeicherte neue Spielrekorde erscheinen automatisch in der Bildschirmmitte. Alle Meldungen werden nacheinander angezeigt.</p></div>
    <div className="twoCol"><form className="panel form" onSubmit={save}><h3>Browser-Quelle für OBS</h3><label>Shop-Alert-URL<input ref={sourceInput} value={url} readOnly onFocus={(event) => event.target.select()} /></label><button className="ghost" type="button" onClick={async () => { try { await navigator.clipboard.writeText(url); setMessage("URL kopiert."); } catch { sourceInput.current?.select(); setMessage("URL markiert. Mit Strg + C kopieren."); } }}><Copy size={16} /> URL kopieren</button><p>Browser-Quelle mit 1920 × 1080 anlegen und über dein Spiel legen. Außerhalb der Box bleibt alles transparent. Die News-Quelle bleibt separat.</p><label>Anzeigedauer in Sekunden<input type="number" min="5" max="20" value={duration} onChange={(event) => setDuration(Number(event.target.value))} /></label><button type="submit" disabled={saving || !Number.isInteger(duration) || duration < 5 || duration > 20}><Save size={16} />{saving ? "Speichert …" : "Anzeigedauer speichern"}</button>{message && <div className="notice" role="status">{message}</div>}{error && <div className="notice error" role="alert">{error}</div>}</form>
      <div className="panel"><div className="communitySectionHeading"><h3>Vorschau</h3><button className="ghost" type="button" disabled={!ready} onClick={() => preview("purchase")}><Play size={15} /> Vorschau abspielen</button></div><button className="ghost" type="button" disabled={!ready} onClick={() => preview("highscore")}><Trophy size={15} /> Highscore-Vorschau</button><div className="shopAlertPreview"><iframe ref={frame} title="Shop-Alert Vorschau" src="/overlays/shop-alert.html?preview=1" onLoad={() => setReady(true)} /></div><p>Die Vorschau ist nur hier sichtbar und veröffentlicht weder einen Kauf noch einen Rekord.</p></div></div>
    <DerbyOverlayPanel />
    <section className="panel"><h3>Letzte Käufe</h3><div className="list">{purchases.length ? purchases.map((purchase) => <article className="miniCard recentShopPurchase" key={purchase.id}><span><strong>{purchase.username}</strong><small>{purchase.item_name}</small></span><b>{purchase.price} Chickens</b></article>) : <p>Noch keine Käufe seit der Chicken-Umstellung.</p>}</div></section>
  </section>;
}

function DerbyOverlayPanel() {
  const url = `${window.location.origin}/stream/derby`;
  const input = useRef(null);
  const [note, setNote] = useState("");
  const [demo, setDemo] = useState(false);
  return <section className="panel derbyOverlayAdmin"><h3><Trophy size={18} /> Chicken Derby als Vollbild-Szene</h3>
    <p>Sobald jemand auf der Webseite ein Pferderennen startet, übernimmt das Rennen als eigene Vollbild-Szene den Stream: Ansage mit Name und Pferd, Countdown, alle fünf Runden mit Kommentator und das Ergebnis. Danach ist die Quelle wieder komplett transparent. Läuft ein Rennen schon, steigt die Szene synchron ein; mehrere Rennen laufen nacheinander.</p>
    <label>Derby-URL für OBS<input ref={input} value={url} readOnly onFocus={(event) => event.target.select()} /></label>
    <div className="row"><button className="ghost" type="button" onClick={async () => { try { await navigator.clipboard.writeText(url); setNote("URL kopiert."); } catch { input.current?.select(); setNote("URL markiert. Mit Strg + C kopieren."); } }}><Copy size={16} /> URL kopieren</button>
      <button className="ghost" type="button" onClick={() => setDemo(!demo)}><Play size={15} /> {demo ? "Vorschau beenden" : "Demo-Rennen ansehen"}</button></div>
    <p>Browser-Quelle mit 1920 × 1080 als oberste Quelle anlegen und „Audio über OBS steuern“ aktivieren, damit Musik, Publikum und Ansager im Stream zu hören sind. Zum Einrichten zeigt <code>{url}?demo=1</code> endlos Demo-Rennen.</p>
    {note && <div className="notice" role="status">{note}</div>}
    {demo && <div className="derbyOverlayPreview"><iframe title="Chicken Derby Overlay Vorschau" src="/stream/derby?demo=1" /></div>}
  </section>;
}
