// Small SVG chart kit for the admin Statistik: thin marks, recessive grid, one y-axis,
// crosshair/hover tooltips, legend for 2+ series. Colours come from CSS custom properties
// (stats.css) so the series follow their entity, never their rank.
import React, { useEffect, useRef, useState } from "react";

export const fmt = (n, digits = 0) => Number(n || 0).toLocaleString("de-DE", { maximumFractionDigits: digits, minimumFractionDigits: 0 });

export function keyLabel(key, hourly, long = false) {
  if (hourly) return `${key.slice(11, 13)} Uhr`;
  const d = new Date(`${key}T12:00:00`);
  return long ? d.toLocaleDateString("de-DE", { weekday: "short", day: "2-digit", month: "2-digit" }) : d.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" });
}

function niceScale(max, ticks = 4) {
  if (max <= 0) return { top: ticks, step: 1 };
  const raw = max / ticks;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((s) => s >= raw) || 10 * mag;
  return { top: Math.ceil(max / step) * step, step };
}

function useWidth() {
  const ref = useRef(null);
  const [width, setWidth] = useState(640);
  useEffect(() => {
    const el = ref.current;
    if (!el) return undefined;
    const fit = () => setWidth(Math.max(240, el.getBoundingClientRect().width));
    fit();
    const ro = typeof ResizeObserver === "function" ? new ResizeObserver(fit) : null;
    ro?.observe(el);
    return () => ro?.disconnect();
  }, []);
  return [ref, width];
}

export function Legend({ series }) {
  if (series.length < 2) return null;
  return (
    <ul className="stLegend">
      {series.map((s) => <li key={s.id}><i style={{ background: s.color }} />{s.label}</li>)}
    </ul>
  );
}

// Line / area over time. `stacked` draws stacked bars instead (for parts of a whole).
export function TimeChart({ keys, series, hourly = false, kind = "area", height = 240, unit = "", digits = 0 }) {
  const [ref, width] = useWidth();
  const [hover, setHover] = useState(null);
  const pad = { l: 44, r: 12, t: 12, b: 26 };
  const w = width - pad.l - pad.r, h = height - pad.t - pad.b;
  const n = keys.length;
  const totals = keys.map((_, i) => (kind === "bars" ? series.reduce((s, x) => s + (x.values[i] || 0), 0) : Math.max(0, ...series.map((x) => x.values[i] || 0))));
  const { top, step } = niceScale(Math.max(0, ...totals));
  const y = (v) => pad.t + h - (v / top) * h;
  const slot = w / Math.max(1, n);
  const x = (i) => (kind === "bars" ? pad.l + slot * i + slot / 2 : pad.l + (n === 1 ? w / 2 : (w * i) / (n - 1)));
  const ticks = [];
  for (let v = 0; v <= top + 1e-9; v += step) ticks.push(v);
  const every = Math.max(1, Math.ceil(n / Math.max(2, Math.floor(w / 70))));

  function move(event) {
    const box = event.currentTarget.getBoundingClientRect();
    const px = event.clientX - box.left;
    const i = kind === "bars" ? Math.floor((px - pad.l) / slot) : Math.round(((px - pad.l) / Math.max(1, w)) * (n - 1));
    setHover(i >= 0 && i < n ? i : null);
  }

  const barW = Math.max(2, Math.min(28, slot - 4));
  return (
    <div className="stChart" ref={ref}>
      <Legend series={series} />
      <svg width={width} height={height} role="img" aria-label={series.map((s) => s.label).join(", ")} onPointerMove={move} onPointerLeave={() => setHover(null)}>
        {ticks.map((v) => (
          <g key={v}>
            <line className="stGrid" x1={pad.l} x2={width - pad.r} y1={y(v)} y2={y(v)} />
            <text className="stTick" x={pad.l - 8} y={y(v) + 4} textAnchor="end">{fmt(v, 1)}</text>
          </g>
        ))}
        <line className="stAxis" x1={pad.l} x2={width - pad.r} y1={y(0)} y2={y(0)} />
        {keys.map((k, i) => (i % every === 0 ? <text key={k} className="stTick" x={x(i)} y={height - 6} textAnchor="middle">{keyLabel(k, hourly)}</text> : null))}

        {kind === "bars" && keys.map((k, i) => {
          let base = 0;
          const parts = series.map((s) => ({ s, v: s.values[i] || 0 })).filter((p) => p.v > 0);
          return (
            <g key={k} opacity={hover === null || hover === i ? 1 : 0.55}>
              {parts.map((p, j) => {
                const y0 = y(base), y1 = y(base + p.v);
                base += p.v;
                const topSeg = j === parts.length - 1;
                const hgt = Math.max(0, y0 - y1 - (j > 0 ? 2 : 0));
                const r = topSeg ? Math.min(4, barW / 2, hgt) : 0;
                const bx = x(i) - barW / 2, by = y1;
                const d = `M${bx},${by + hgt} V${by + r} Q${bx},${by} ${bx + r},${by} H${bx + barW - r} Q${bx + barW},${by} ${bx + barW},${by + r} V${by + hgt} Z`;
                return <path key={p.s.id} d={d} fill={p.s.color} />;
              })}
            </g>
          );
        })}

        {kind !== "bars" && series.map((s) => {
          const pts = s.values.map((v, i) => `${x(i)},${y(v || 0)}`);
          return (
            <g key={s.id}>
              {kind === "area" && series.length === 1 && <path d={`M${x(0)},${y(0)} L${pts.join(" L")} L${x(n - 1)},${y(0)} Z`} fill={s.color} opacity="0.16" />}
              <polyline points={pts.join(" ")} fill="none" stroke={s.color} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
              {n <= 31 && s.values.map((v, i) => (hover === i ? <circle key={i} cx={x(i)} cy={y(v || 0)} r="4.5" fill={s.color} className="stDot" /> : null))}
            </g>
          );
        })}
        {hover !== null && kind !== "bars" && <line className="stCross" x1={x(hover)} x2={x(hover)} y1={pad.t} y2={y(0)} />}
        <rect x={pad.l} y={pad.t} width={w} height={h} fill="transparent" />
      </svg>
      {hover !== null && (
        <div className="stTip" style={{ left: Math.min(width - 170, Math.max(0, x(hover) - 80)) }}>
          <b>{keyLabel(keys[hover], hourly, true)}</b>
          {series.map((s) => <span key={s.id}><i style={{ background: s.color }} />{s.label}<em>{fmt(s.values[hover], digits)}{unit}</em></span>)}
          {kind === "bars" && series.length > 1 && <span className="sum">Gesamt<em>{fmt(totals[hover], digits)}{unit}</em></span>}
        </div>
      )}
    </div>
  );
}

// Weekday × hour heatmap, one sequential hue.
const DAYS = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
const RAMP = ["#104281", "#184f95", "#1c5cab", "#256abf", "#2a78d6", "#3987e5", "#5598e7", "#6da7ec", "#86b6ef", "#9ec5f4", "#b7d3f6", "#cde2fb"];
export function Heatmap({ heat }) {
  const [tip, setTip] = useState(null);
  const max = Math.max(1, ...heat.flat());
  return (
    <div className="stHeat" onPointerLeave={() => setTip(null)}>
      <div className="stHeatGrid">
        <span />
        {Array.from({ length: 24 }, (_, hr) => <span key={hr} className="stHeatHour">{hr % 3 === 0 ? hr : ""}</span>)}
        {heat.map((row, d) => (
          <React.Fragment key={d}>
            <span className="stHeatDay">{DAYS[d]}</span>
            {row.map((v, hr) => (
              <span key={hr} className="stCell" style={{ background: v ? RAMP[Math.min(RAMP.length - 1, Math.floor((v / max) * (RAMP.length - 1)))] : undefined }}
                onPointerEnter={() => setTip({ d, hr, v })} aria-label={`${DAYS[d]} ${hr} Uhr: ${v} Aufrufe`} />
            ))}
          </React.Fragment>
        ))}
      </div>
      <div className="stHeatFoot">
        <span>{tip ? `${DAYS[tip.d]}, ${tip.hr}–${tip.hr + 1} Uhr: ${fmt(tip.v)} Aufrufe` : "Zeiger über ein Feld für Details"}</span>
        <span className="stRamp">wenig <i style={{ background: `linear-gradient(90deg, ${RAMP[0]}, ${RAMP[RAMP.length - 1]})` }} /> viel</span>
      </div>
    </div>
  );
}

// Ranked horizontal bars (HTML, wraps long labels well).
export function BarList({ rows, color = "var(--st-1)", empty = "Noch keine Daten.", format = fmt }) {
  if (!rows.length) return <p className="stEmpty">{empty}</p>;
  const max = Math.max(1, ...rows.map((r) => r.value));
  return (
    <ol className="stBars">
      {rows.map((r) => (
        <li key={r.label} title={`${r.label}: ${format(r.value)}`}>
          <div className="stBarHead"><span>{r.label}</span><b>{format(r.value)}</b></div>
          <div className="stBarTrack"><i style={{ width: `${(r.value / max) * 100}%`, background: color }} /></div>
          {r.sub && <small>{r.sub}</small>}
        </li>
      ))}
    </ol>
  );
}

// Parts of a whole as one segmented bar + legend with shares.
export function Share({ rows }) {
  const total = rows.reduce((s, r) => s + r.value, 0);
  if (!total) return <p className="stEmpty">Noch keine Daten.</p>;
  return (
    <div className="stShare">
      <div className="stShareBar">{rows.map((r) => <i key={r.label} style={{ flexGrow: r.value, background: r.color }} title={`${r.label}: ${Math.round((r.value / total) * 100)} %`} />)}</div>
      <ul className="stLegend stShareLegend">
        {rows.map((r) => <li key={r.label}><i style={{ background: r.color }} />{r.label}<b>{Math.round((r.value / total) * 100)} %</b><small>{fmt(r.value)}</small></li>)}
      </ul>
    </div>
  );
}
