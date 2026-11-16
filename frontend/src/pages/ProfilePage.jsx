import React from "react";
import { WalletHistory } from "../economy/WalletHistory";
import { LevelPanel } from "../economy/LevelUp";
import { ProfileView } from "../profile/ProfileView";
import { EmptyLogin } from "./shared";

// Your own profile: the public profile (with edit button) plus level tree and wallet, which only you see.
export function ProfilePage({ user, setUser, setPage }) {
  if (!user) return <EmptyLogin setPage={setPage} />;
  return (
    <section className="stack">
      <ProfileView username={user.username} me={user} setUser={setUser} setPage={setPage} />
      <div className="pfOwnExtras">
        <h2>Nur für dich sichtbar</h2>
        <LevelPanel user={user} />
        <WalletHistory user={user} />
      </div>
    </section>
  );
}
