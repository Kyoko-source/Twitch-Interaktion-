import React, { useState } from "react";
import { Mail } from "lucide-react";
import { Avatar, RoleBadge, Stat, useApi } from "./shared";

export function MembersPage({ user, setPage }) {
  const { data, loading, error } = useApi("/api/users", []);
  const [query, setQuery] = useState("");
  const filtered = data.filter((member) => String(member.username || "").toLowerCase().includes(query.toLowerCase()));
  const top = data[0];
  const totals = data.reduce((acc, member) => ({
    chickens: acc.chickens + Number(member.chickens || 0),
    chickens_earned: acc.chickens_earned + Number(member.chickens_earned || 0),
  }), { chickens: 0, chickens_earned: 0 });

  function openPrivate(member) {
    try {
      localStorage.setItem("aviary_chat_target", member.username);
    } catch {
      // Private mode can still be opened without persisted handoff.
    }
    setPage("chat");
  }

  return (
    <section className="stack">
      <div className="membersHeader">
        <div>
          <p className="kicker">Schwarmregister</p>
          <h1>Mitglieder</h1>
          <p>Profile, Lieblingsspiele und Energielevel auf einen Blick.</p>
        </div>
        <div className="memberStats">
          <Stat label="Mitglieder" value={data.length} />
          <Stat label="Chickens erspielt" value={totals.chickens_earned} />
          <Stat label="Chickens" value={totals.chickens} />
        </div>
      </div>
      {top && (
        <div className="memberSpotlight">
          <Avatar user={top} className="avatar" />
          <div>
            <span className="rank">#1 im Schwarm</span>
            <h2>{top.username}</h2>
            <RoleBadge user={top} />
            <p>{top.favorite_game ? `Lieblingsspiel: ${top.favorite_game}` : "Lieblingsspiel noch geheim."}</p>
          </div>
          <strong>{top.chickens_earned || 0} Chickens</strong>
        </div>
      )}
      <input className="searchInput" placeholder="Mitglied suchen..." value={query} onChange={(event) => setQuery(event.target.value)} />
      {loading && <div className="notice">Lade Mitglieder...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="memberGrid">
        {filtered.map((member, index) => (
          <article className="memberCard" key={member.username}>
            <span className="rank">#{data.findIndex((entry) => entry.username === member.username) + 1 || index + 1}</span>
            <Avatar user={member} />
            <h3>{member.username}</h3>
            <RoleBadge user={member} />
            <p>{member.favorite_game || "Kein Lieblingsspiel gesetzt"}</p>
            <div className="miniStats">
              <span>{member.chickens_earned || 0} erspielt</span>
              <span>{member.chickens || 0} verfügbar</span>
            </div>
            {user && member.username !== user.username && (
              <button className="miniAction" onClick={() => openPrivate(member)} type="button">
                <Mail size={15} /> Privat schreiben
              </button>
            )}
          </article>
        ))}
      </div>
    </section>
  );
}
