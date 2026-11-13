import React from "react";
import { Trophy } from "lucide-react";
import { Avatar, RoleBadge, useApi } from "./shared";

export function LeaderboardPage() {
  const { data, loading, error } = useApi("/api/leaderboard", []);
  const top = data.slice(0, 3);
  const maxScore = Math.max(1, ...data.map((item) => Number(item.chickens_earned || 0)));

  return (
    <section className="stack">
      <div className="leaderHero">
        <div>
          <p className="kicker">Rangliste</p>
          <h1>Chicken-Rangliste</h1>
          <p>Die besten Spieler unseres Schwarms, sortiert nach insgesamt erspielten Chickens. Einkäufe kosten dich keinen Rang.</p>
        </div>
        <Trophy size={72} />
      </div>
      {loading && <div className="notice">Lade Rangliste...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="podium stagePodium">
        {[top[1], top[0], top[2]].filter(Boolean).map((item) => {
          const rank = data.findIndex((entry) => entry.username === item.username) + 1;
          return (
            <article className={`podiumCard place${rank}`} key={item.username}>
              <span>#{rank}</span>
              <Avatar user={item} />
              <strong>{item.username}</strong>
              <RoleBadge user={item} />
              <small>{item.rank_name} · {item.chickens_earned || 0} Chickens erspielt</small>
            </article>
          );
        })}
      </div>
      <div className="leaderTable">
        {data.map((item, index) => (
          <article className="leaderRow" key={item.username}>
            <span className="rank">#{index + 1}</span>
            <Avatar user={item} />
            <div className="leaderName">
              <strong>{item.username}</strong>
              <small><RoleBadge user={item} /> {item.rank_name}</small>
            </div>
            <div className="progressTrack"><span style={{ width: `${Math.max(0, (Number(item.chickens_earned || 0) / maxScore) * 100)}%` }} /></div>
            <b>{item.chickens_earned || 0}</b>
            <small>{item.chickens || 0} verfügbar</small>
          </article>
        ))}
      </div>
    </section>
  );
}
