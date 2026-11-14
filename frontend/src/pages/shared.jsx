import React, { useEffect, useState } from "react";
import { CalendarDays, Gamepad2, Gift, GitBranch, Home, MessageCircle, Newspaper, Palette, Shield, ShoppingBasket, Trophy, User, Users } from "lucide-react";
import { api } from "../api";

export const nav = [
  { id: "home", label: "Home", icon: Home },
  { id: "advent", label: "Marelles Adventskalender", icon: Gift },
  { id: "news", label: "News", icon: Newspaper },
  { id: "members", label: "Mitglieder", icon: Users },
  { id: "chat", label: "Chat", icon: MessageCircle },
  { id: "profile", label: "Profil", icon: User },
  { id: "shop", label: "Shop", icon: ShoppingBasket },
  { id: "leaderboard", label: "Rangliste", icon: Trophy },
  { id: "events", label: "Events", icon: CalendarDays },
  { id: "games", label: "Minispiele", icon: Gamepad2 },
  { id: "systematics", label: "Systematik", icon: GitBranch },
  { id: "gallery", label: "Hall of Fame", icon: Palette },
  { id: "admin", label: "Admin", icon: Shield },
];

export const gameMeta = {
  "chicken-jump": { title: "Chicken Jump", accent: "#ffcf8a", text: "Spring über Zäune, sammle Federn und erspiele dir Chickens." },
  "chicken-snake": { title: "Chicken Snake", accent: "#7af4dc", text: "Sammle goldene Eier und jage mit deiner Jade-Schlange den nächsten Rekord." },
  "chicken-flipper": { title: "PEPPLE Pinball", accent: "#7affd3", text: "After Hours / PEPPLE Pinball." },
  "braincell-survivor": { title: "Pepple Survivor", accent: "#ff6fb7", text: "Weiche Schwarmdrohnen aus und sammle so lange wie möglich Chickens." },
  dnd: { title: "Dungeons and Dragons", accent: "#ff4f6d", text: "Euer eigener Pen-&-Paper-Tisch mit DM, Helden, Battlemap und echten Würfeln." },
  "nullsignal": { title: "NULLSIGNAL", accent: "#ff9c52", text: "Zwei Stimmen. Eine Chance. Entschärft gemeinsam eine echte 3D-Bombe." },
  "after-play": { title: "After Play", accent: "#b5b995", text: "Kinderparadies. Dreizehn Rundgänge. Erkenne, was sich verändert hat." },
};

export const roleMeta = {
  publisher: { label: "Publisher", color: "#ffc94a" },
  admin: { label: "Admin", color: "#ff3048" },
  moderator: { label: "Moderator", color: "#ff4fc3" },
  vip: { label: "VIP", color: "#a855ff" },
  member: { label: "Mitglied", color: "#4ade80" },
};

export function userRole(user) {
  const role = String(user?.role || "member").toLowerCase();
  return roleMeta[role] ? role : "member";
}

// Publisher is the top role and has every admin right.
export function isAdmin(user) {
  const role = userRole(user);
  return role === "admin" || role === "publisher";
}

export function RoleBadge({ user, role }) {
  const key = roleMeta[role] ? role : userRole(user);
  const meta = roleMeta[key];
  return <span className="roleBadge" style={{ "--role": meta.color }}>{meta.label}</span>;
}

export function routeParts() {
  if (typeof window === "undefined") return [];
  const hashParts = window.location.hash.replace(/^#\/?/, "").split("/").filter(Boolean);
  if (hashParts.length) return hashParts;
  const pathParts = window.location.pathname.replace(/^\/+|\/+$/g, "").split("/").filter(Boolean);
  if (pathParts.length) window.history.replaceState(null, "", `/#${pathParts.join("/")}`);
  return pathParts;
}

export function useApi(path, fallback, reloadKey = 0) {
  const [data, setData] = useState(fallback);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError("");
    api(path)
      .then((next) => alive && setData(next))
      .catch((err) => alive && setError(err.message))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [path, reloadKey]);

  return { data, error, loading, setData };
}

export function Stat({ label, value }) {
  return (
    <div className="stat">
      <strong>{value ?? 0}</strong>
      <span>{label}</span>
    </div>
  );
}

export function Avatar({ user, className = "viewerAvatar" }) {
  const initials = String(user?.username || "?").slice(0, 2);
  return <div className={className}>{user?.avatar_url ? <img src={user.avatar_url} alt="" /> : initials}</div>;
}

export function PanelTitle({ title, action, onClick }) {
  return <div className="communitySectionHeading"><h2>{title}</h2>{action && (onClick ? <button className="inlineLink" onClick={onClick} type="button">{action}</button> : <span className="inlineLink">{action}</span>)}</div>;
}

export function ListPage({ title, path, render }) {
  const { data, loading, error } = useApi(path, []);
  return (
    <section className="stack">
      <h1>{title}</h1>
      {loading && <div className="notice">Lade Daten...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="grid">{data.map(render)}</div>
    </section>
  );
}

export function CardGrid({ title, items, render }) {
  return (
    <section className="stack">
      <h2>{title}</h2>
      <div className="grid">{items.length ? items.map(render) : <div className="notice">Noch keine Einträge.</div>}</div>
    </section>
  );
}

export function EmptyLogin({ setPage }) {
  return (
    <section className="narrow">
      <div className="panel">
        <h1>Bitte anmelden</h1>
        <p>Dieser Bereich gehört zu deinem Aviary-Profil.</p>
        <button onClick={() => setPage("login")} type="button">Zum Login</button>
      </div>
    </section>
  );
}
