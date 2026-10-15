import React, { useEffect, useState } from "react";
import { api } from "../api";

export function GameScoreboard({ game, refreshKey = 0 }) {
  const [rows, setRows] = useState([]), [error, setError] = useState(""), [loading, setLoading] = useState(true);
  const [recent, setRecent] = useState(null), [retry, setRetry] = useState(0);
  useEffect(() => {
    let alive = true;
    setLoading(true); setError("");
    api(`/api/scores/${game}`).then((next) => { if (alive) setRows(next); })
      .catch((err) => { if (alive) setError(err.message); })
      .finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [game, refreshKey, retry]);
  useEffect(() => {
    setRecent(null); setRows([]);
    function saved(event) {
      if (event.detail.game !== game) return;
      const entry = event.detail;
      setRecent(entry); setRows((current) => [...current, entry]);
    }
    window.addEventListener("aviary-score-saved", saved);
    return () => window.removeEventListener("aviary-score-saved", saved);
  }, [game]);
  const best = new Map();
  rows.forEach((entry) => {
    const key = String(entry.username || "").trim().toLowerCase();
    if (key && (!best.has(key) || Number(entry.score) > Number(best.get(key).score))) best.set(key, entry);
  });
  const leaders = [...best.values()].sort((a, b) => Number(b.score) - Number(a.score)).slice(0, 8);
  return <div className="gameScoreboard">
    {recent && <p className="gameRecentScore" role="status">Zuletzt gespeichert: {recent.username} · {Number(recent.score).toLocaleString("de-DE")} Punkte. Die Tabelle zeigt die persönliche Bestleistung.</p>}
    {loading && !leaders.length && <p>Lade Highscores …</p>}
    {error && <p className="gameScoresError" role="status">Die Highscores konnten nicht vollständig geladen werden. <button type="button" className="ghost" onClick={() => setRetry((value) => value + 1)}>Erneut laden</button></p>}
    <ol className="gameScores">{leaders.map((entry, index) => <li key={entry.username.toLowerCase()}><span>#{index + 1} {entry.username}</span><b>{Number(entry.score).toLocaleString("de-DE")}</b></li>)}</ol>
    {!loading && !error && !leaders.length && <p>Noch keine Scores. Der erste Platz wartet auf dich.</p>}
  </div>;
}
