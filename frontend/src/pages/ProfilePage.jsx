import React, { useState } from "react";
import { WalletHistory } from "../economy/WalletHistory";
import { api } from "../api";
import { Avatar, EmptyLogin, RoleBadge, Stat } from "./shared";

export function ProfilePage({ user, setUser, setPage }) {
  const [profile, setProfile] = useState(user || {});
  const [message, setMessage] = useState("");

  if (!user) return <EmptyLogin setPage={setPage} />;

  async function save(event) {
    event.preventDefault();
    try {
      const result = await api("/api/profile", { method: "PATCH", body: JSON.stringify(profile) });
      setUser(result.user);
      setProfile(result.user);
      setMessage("Profil gespeichert.");
    } catch (err) {
      setMessage(err.message);
    }
  }


  return (
    <section className="stack">
      <div className="profileHero">
        <Avatar user={user} className="avatar" />
        <div>
          <p className="kicker">Profilzentrum</p>
          <h1>{user.username}</h1>
          <RoleBadge user={user} />
          <p>{user.bio || "Noch keine Bio eingetragen."}</p>
        </div>
        <div className="heroPanel compact">
          <Stat label="Chickens erspielt" value={user.chickens_earned} />
          <Stat label="Chickens verfügbar" value={user.chickens} />
        </div>
      </div>
      <button onClick={() => setPage("games")} type="button">Chickens in Minispielen verdienen</button>
      <WalletHistory user={user} />
      <form className="panel form" onSubmit={save}>
        <label>Biografie<textarea value={profile.bio || ""} onChange={(event) => setProfile({ ...profile, bio: event.target.value })} /></label>
        <label>Lieblingsspiel<input value={profile.favorite_game || ""} onChange={(event) => setProfile({ ...profile, favorite_game: event.target.value })} /></label>
        <label>Profilbild-URL<input value={profile.avatar_url || ""} onChange={(event) => setProfile({ ...profile, avatar_url: event.target.value })} /></label>
        <button type="submit">Profil speichern</button>
        {message && <div className="notice">{message}</div>}
      </form>
    </section>
  );
}
