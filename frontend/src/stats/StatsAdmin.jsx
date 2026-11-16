import React, { useCallback, useEffect, useState } from "react";
import { Activity, MonitorSmartphone, RefreshCw, TrendingDown, TrendingUp } from "lucide-react";
import { api } from "../api";
import { gameMeta, nav } from "../pages/shared";
import { BarList, Heatmap, Share, TimeChart, fmt } from "./charts.jsx";
import "./stats.css";

const RANGES = [[1, "Heute"], [7, "7 Tage"], [30, "30 Tage"], [90, "90 Tage"]];
const S = ["var(--st-1)", "var(--st-2)", "var(--st-3)", "var(--st-4)", "var(--st-5)", "var(--st-6)", "var(--st-7)", "var(--st-8)"];
const PAGE_NAMES = { ...Object.fromEntries(nav.map((n) => [n.id, n.label])), u: "Profilseiten", login: "Login", support: "Support", nullsignal: "NULLSIGNAL" };

export function pageName(path) {
  const [first, second] = path.split("/");
  const base = PAGE_NAMES[first] || first;
  if (!second) return base;
  return `${base} · ${gameMeta[second]?.title || second}`;
}

function Kpi({ label, pair, digits = 0, suffix = "", hint }) {
  const [now, before] = pair;
  let delta = null;
  if (before > 0) delta = Math.round(((now - before) / before) * 100);
  const up = delta !== null && delta > 0, down = delta !== null && delta < 0;
  return (
    <article className="stKpi">
      <span className="stKpiLabel">{label}</span>
      <b className="stKpiValue">{fmt(now, digits)}{suffix}</b>
      <span className={`stDelta${up ? " up" : down ? " down" : ""}`}>
        {up && <TrendingUp size={14} aria-hidden="true" />}{down && <TrendingDown size={14} aria-hidden="true" />}
        {delta === null ? (now > 0 ? "neu im Zeitraum" : "–") : `${delta > 0 ? "+" : ""}${delta} % ${hint}`}
      </span>
    </article>
  );
}

export function StatsAdmin({ password }) {
  const [days, setDays] = useState(30);
  const [data, setData] = useState(null);
  const [metric, setMetric] = useState("visitors");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try { setData(await api(`/api/admin/stats?days=${days}`, { headers: { "X-Admin-Password": password } })); setError(""); }
    catch (e) { setError(e.message); } finally { setLoading(false); }
  }, [days, password]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { const t = setInterval(load, 60000); return () => clearInterval(t); }, [load]);

  if (!data?.kpis) return <section className="stack stats"><p>{error || "Statistik lädt …"}</p></section>;
  const { kpis, traffic, activity: act, keys, hourly } = data;
  const hint = days === 1 ? "vs. gestern" : "vs. Vorzeitraum";
  const daily = traffic.daily;
  const trafficSeries = {
    visitors: { kind: "bars", series: [{ id: "m", label: "Mitglieder", color: S[0], values: daily.map((d) => d.members) }, { id: "g", label: "Gäste", color: S[1], values: daily.map((d) => d.guests) }] },
    views: { kind: "area", series: [{ id: "v", label: "Seitenaufrufe", color: S[0], values: daily.map((d) => d.views) }] },
    minutes: { kind: "area", series: [{ id: "t", label: "Aktive Minuten", color: S[0], values: daily.map((d) => d.minutes) }], unit: " min" },
  }[metric];
  const since = data.tracking_since ? new Date(data.tracking_since * 1000).toLocaleString("de-DE", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }) : null;
  const deviceColors = { Desktop: S[0], Smartphone: S[1], Tablet: S[2] };

  return (
    <section className="stack stats">
      <header className="stHead">
        <div>
          <h2>Statistik</h2>
          <p>Traffic, Aktivität und Wirtschaft der Community. {since ? `Seitenaufrufe werden seit ${since} erfasst.` : "Seitenaufrufe werden ab jetzt erfasst."} Ohne Cookies und ohne IP-Adressen.</p>
        </div>
        <div className="stControls">
          <div className="stRange" role="group" aria-label="Zeitraum">
            {RANGES.map(([d, label]) => <button key={d} type="button" className={days === d ? "on" : ""} aria-pressed={days === d} onClick={() => setDays(d)}>{label}</button>)}
          </div>
          <button type="button" className="ghost stRefresh" onClick={load} aria-label="Aktualisieren"><RefreshCw size={16} className={loading ? "spin" : ""} /></button>
        </div>
      </header>
      {error && <div className="notice error" role="alert">{error}</div>}

      <div className="stLive panel">
        <span className="stPulse" aria-hidden="true" />
        <b>{data.online.length}</b> gerade online
        <div className="stOnline">
          {data.online.slice(0, 18).map((o, i) => <span key={i} className={o.user === "Gast" ? "guest" : ""}>{o.user} · {pageName(o.path)}</span>)}
          {data.online.length > 18 && <span>+{data.online.length - 18}</span>}
        </div>
      </div>

      <div className="stKpis">
        <Kpi label="Besucher" pair={kpis.visitors} hint={hint} />
        <Kpi label="Seitenaufrufe" pair={kpis.views} hint={hint} />
        <Kpi label="Ø Minuten pro Besucher" pair={kpis.minutes_per_visitor} digits={1} hint={hint} />
        <Kpi label="Eingeloggte Besucher" pair={kpis.members} hint={hint} />
        <Kpi label="Aktive Mitglieder" pair={kpis.active_members} hint={hint} />
        <Kpi label="Spielrunden" pair={kpis.rounds} hint={hint} />
        <Kpi label="Shop-Käufe" pair={kpis.purchases} hint={hint} />
        <Kpi label="Chickens ausgegeben" pair={kpis.spent} hint={hint} />
      </div>

      <div className="panel stCard">
        <div className="stCardHead">
          <h3>Traffic {hourly ? "nach Stunde" : "pro Tag"}</h3>
          <div className="stRange small" role="group" aria-label="Kennzahl">
            {[["visitors", "Besucher"], ["views", "Seitenaufrufe"], ["minutes", "Aktive Minuten"]].map(([id, label]) => <button key={id} type="button" className={metric === id ? "on" : ""} aria-pressed={metric === id} onClick={() => setMetric(id)}>{label}</button>)}
          </div>
        </div>
        <TimeChart keys={keys} hourly={hourly} kind={trafficSeries.kind} series={trafficSeries.series} unit={trafficSeries.unit || ""} height={280} />
      </div>

      <div className="stGrid2">
        <div className="panel stCard">
          <h3>Wann ist am meisten los?</h3>
          <Heatmap heat={traffic.heat} />
        </div>
        <div className="panel stCard">
          <h3>Beliebteste Seiten</h3>
          <BarList rows={traffic.pages.slice(0, 8).map((p) => ({ label: pageName(p.path), value: p.views, sub: `${fmt(p.visitors)} Besucher · ${fmt(p.minutes)} aktive Minuten` }))} empty="Noch keine Seitenaufrufe erfasst." />
        </div>
      </div>

      <div className="stGrid3">
        <div className="panel stCard">
          <h3><MonitorSmartphone size={17} /> Geräte</h3>
          <Share rows={traffic.devices.map(([label, value]) => ({ label, value, color: deviceColors[label] || S[3] }))} />
        </div>
        <div className="panel stCard">
          <h3>Browser</h3>
          <BarList rows={traffic.browsers.map(([label, value]) => ({ label, value }))} />
        </div>
        <div className="panel stCard">
          <h3>Woher kommen Besucher?</h3>
          <BarList rows={traffic.referrers.map(([label, value]) => ({ label, value }))} empty="Noch keine externen Verweise (z. B. von Twitch oder Discord)." />
        </div>
      </div>

      <h3 className="stSection"><Activity size={18} /> Aktivität & Wirtschaft</h3>
      <div className="stGrid2">
        <div className="panel stCard">
          <h3>Aktive Mitglieder {hourly ? "pro Stunde" : "pro Tag"}</h3>
          <TimeChart keys={keys} hourly={hourly} series={[{ id: "a", label: "Aktive Mitglieder", color: S[0], values: act.active_daily }]} />
        </div>
        <div className="panel stCard">
          <h3>Spielrunden {hourly ? "pro Stunde" : "pro Tag"}</h3>
          <TimeChart keys={keys} hourly={hourly} kind="bars" series={[{ id: "r", label: "Minispiele", color: S[0], values: act.rounds_daily }, { id: "c", label: "Casino & Derby", color: S[1], values: act.casino_daily }]} />
        </div>
        <div className="panel stCard">
          <h3>Chickens verdient & ausgegeben</h3>
          <TimeChart keys={keys} hourly={hourly} kind="line" series={[{ id: "e", label: "Verdient (Spiele)", color: S[0], values: act.earned_daily }, { id: "s", label: "Ausgegeben (Shop)", color: S[1], values: act.spent_daily }]} />
        </div>
        <div className="panel stCard">
          <h3>Beliebteste Spiele</h3>
          <BarList rows={act.games.slice(0, 8).map(([label, value]) => ({ label, value }))} format={(v) => `${fmt(v)} Runden`} />
        </div>
        <div className="panel stCard">
          <h3>Fleißigste Spieler</h3>
          <BarList rows={act.players.map(([label, value]) => ({ label, value }))} format={(v) => `${fmt(v)} Runden`} />
        </div>
        <div className="panel stCard">
          <h3>Meistgekaufte Items</h3>
          <BarList rows={act.items.map(([label, value]) => ({ label, value }))} format={(v) => `${fmt(v)}×`} />
        </div>
      </div>
    </section>
  );
}
