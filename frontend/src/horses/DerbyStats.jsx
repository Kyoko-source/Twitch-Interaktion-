import React, { useState } from "react";
import { BarChart3 } from "lucide-react";
import { LOOKS } from "./horse.js";

const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");
const pct = (x) => `${(x * 100).toLocaleString("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %`;

// Win chances of the horses, from every race ever run: one bar per horse (its share of all
// wins), a dashed marker for the fair chance the server draws with (1 in 9), plus totals.
export function DerbyStats({ stats, names }) {
  const [hover, setHover] = useState(-1);
  const [table, setTable] = useState(false);
  if (!stats) return null;
  const { races = 0, won = 0, wins = [], chance = 1 / 9 } = stats;
  const share = wins.map((w) => (races ? w / races : 0));
  // Scale to the leader (at least twice the fair chance) so small differences stay readable.
  const top = Math.max(chance * 2, ...share);
  const leader = races ? share.indexOf(Math.max(...share)) : -1;

  return (
    <section className="hrStats" aria-labelledby="hrStatsTitle">
      <div className="hrStatsHead">
        <h3 id="hrStatsTitle"><BarChart3 size={20} /> Gewinnchancen der Pferde</h3>
        <button type="button" className="hrStatsToggle" onClick={() => setTable(!table)} aria-pressed={table}>{table ? "Als Grafik" : "Als Tabelle"}</button>
      </div>
      <div className="hrStatsTiles">
        <div><small>Rennen insgesamt</small><strong data-testid="derby-races">{fmt(races)}</strong></div>
        <div><small>Gewonnene Wetten</small><strong data-testid="derby-won">{fmt(won)}</strong></div>
        <div><small>Gewinnquote der Spieler</small><strong>{races ? pct(won / races) : "–"}</strong></div>
      </div>

      {table ? (
        <table className="hrStatsTable">
          <thead><tr><th scope="col">Pferd</th><th scope="col">Siege</th><th scope="col">Anteil aller Siege</th></tr></thead>
          <tbody>
            {names.map((name, i) => <tr key={name}><th scope="row">#{i + 1} {name}</th><td>{fmt(wins[i])}</td><td>{races ? pct(share[i]) : "–"}</td></tr>)}
          </tbody>
        </table>
      ) : (
        <div className="hrChart" role="group" aria-label={`Siege pro Pferd aus ${fmt(races)} Rennen`} style={{ "--fair": `${(chance / top) * 100}%` }}>
          <div className="hrChartRow hrChartFair" aria-hidden="true"><span /><span className="hrChartTrack"><em>faire Chance {pct(chance)}</em></span><span /></div>
          {names.map((name, i) => (
            <div key={name} className={`hrChartRow${hover === i ? " hover" : ""}`} onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(-1)} onFocus={() => setHover(i)} onBlur={() => setHover(-1)} tabIndex={0}>
              <span className="hrChartName"><i style={{ "--silk": LOOKS[i].silk, "--silk2": LOOKS[i].silk2 }} /><em>{name}</em></span>
              <span className="hrChartTrack">
                <b style={{ width: `${(share[i] / top) * 100}%` }} className={i === leader ? "lead" : ""} />
                {hover === i && (
                  <span className="hrChartTip" role="tooltip">
                    <strong>#{i + 1} {name}</strong>
                    {fmt(wins[i])} von {fmt(races)} Rennen gewonnen · {races ? pct(share[i]) : "–"}
                  </span>
                )}
              </span>
              <span className="hrChartVal">{fmt(wins[i])} <small>{races ? pct(share[i]) : "–"}</small></span>
            </div>
          ))}
        </div>
      )}
      <p className="hrStatsNote">Balken: Anteil aller bisherigen Siege. Gestrichelt: die echte Chance pro Rennen – der Server lost jedes Mal fair aus, jedes Pferd hat {pct(chance)}. Abweichungen sind Zufall, keine Form.</p>
    </section>
  );
}
