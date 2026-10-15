import React, { Suspense, lazy, useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  CalendarDays,
  Check,
  Gamepad2,
  GitBranch,
  Home,
  Image as ImageIcon,
  Link2,
  Lock,
  Mail,
  MessageCircle,
  MousePointer2,
  Newspaper,
  Palette,
  Plus,
  RefreshCw,
  Save,
  Send,
  Shield,
  Sparkles,
  ShoppingBasket,
  Star,
  Trash2,
  Trophy,
  User,
  Users,
  Zap,
} from "lucide-react";
import { CommunityShop } from "./economy/CommunityShop";
import { ShopAlertsAdmin } from "./economy/ShopAlertsAdmin";
import { GameScoreboard } from "./economy/GameScoreboard";
import { WalletHistory } from "./economy/WalletHistory";
import { AdminMembers, AdminPoints } from "./economy/AdminMembers";
import "./economy/account-tools.css";
import { api, setToken } from "./api";
import { PepplePinball } from "./pinball/PepplePinball";
import { ChickenJump } from "./jump/ChickenJump";
import { ChickenSnake } from "./snake/ChickenSnake";
import { LiveNewsAdmin } from "./live-news/LiveNewsAdmin";
import { AppShell, Dashboard } from "./ui/CommunityLayout";
import "./styles.css";
import "./ui/community-theme.css";

const PeppleSurvivor = lazy(() => import("./survivor/PeppleSurvivor").then((module) => ({ default: module.PeppleSurvivor })));

const nav = [
  { id: "home", label: "Home", icon: Home },
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

const gameMeta = {
  "chicken-jump": { title: "Chicken Jump", accent: "#ffcf8a", text: "Spring über Zäune, sammle Federn und erspiele dir Chickens." },
  "chicken-snake": { title: "Chicken Snake", accent: "#7af4dc", text: "Sammle goldene Eier und jage mit deiner Jade-Schlange den nächsten Rekord." },
  "chicken-flipper": { title: "PEPPLE Pinball", accent: "#7affd3", text: "After Hours / PEPPLE Pinball." },
  "braincell-survivor": { title: "Pepple Survivor", accent: "#ff6fb7", text: "Weiche Schwarmdrohnen aus und sammle so lange wie moeglich Chickens." },
  dnd: { title: "Dungeons and Dragons", accent: "#c88956", text: "Die grosse DnD-Lobby kommt als eigenes Modul zurueck." },
};

const roleMeta = {
  admin: { label: "Admin", color: "#ff3048" },
  moderator: { label: "Moderator", color: "#ff4fc3" },
  vip: { label: "VIP", color: "#a855ff" },
  member: { label: "Mitglied", color: "#4ade80" },
};

function userRole(user) {
  const role = String(user?.role || "member").toLowerCase();
  return roleMeta[role] ? role : "member";
}

function RoleBadge({ user, role }) {
  const key = roleMeta[role] ? role : userRole(user);
  const meta = roleMeta[key];
  return <span className="roleBadge" style={{ "--role": meta.color }}>{meta.label}</span>;
}

function routeParts() {
  if (typeof window === "undefined") return [];
  const hashParts = window.location.hash.replace(/^#\/?/, "").split("/").filter(Boolean);
  if (hashParts.length) return hashParts;
  const pathParts = window.location.pathname.replace(/^\/+|\/+$/g, "").split("/").filter(Boolean);
  if (pathParts.length) window.history.replaceState(null, "", `/#${pathParts.join("/")}`);
  return pathParts;
}

function useApi(path, fallback, reloadKey = 0) {
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

function Stat({ label, value }) {
  return (
    <div className="stat">
      <strong>{value ?? 0}</strong>
      <span>{label}</span>
    </div>
  );
}

function Avatar({ user, className = "viewerAvatar" }) {
  const initials = String(user?.username || "?").slice(0, 2);
  return <div className={className}>{user?.avatar_url ? <img src={user.avatar_url} alt="" /> : initials}</div>;
}

const emptyDashboard = { stats: {}, leaderboard: [], active_members: [], news: [], events: [], gallery: [] };

function HomePage({ user, setPage }) {
  const { data, loading, error } = useApi("/api/dashboard", emptyDashboard);
  return <Dashboard user={user} setPage={setPage} data={data} loading={loading} error={error} games={gameMeta} roleBadge={<RoleBadge user={user} />} />;
}

function PanelTitle({ title, action, onClick }) {
  return <div className="communitySectionHeading"><h2>{title}</h2>{action && (onClick ? <button className="inlineLink" onClick={onClick} type="button">{action}</button> : <span className="inlineLink">{action}</span>)}</div>;
}

function LoginPage({ onLogin }) {
  const [mode, setMode] = useState("login");
  const [form, setForm] = useState({ username: "", password: "", code: "" });
  const [message, setMessage] = useState("");

  async function submit(event) {
    event.preventDefault();
    setMessage("");
    try {
      if (mode === "login") {
        const result = await api("/api/auth/login", { method: "POST", body: JSON.stringify(form) });
        setToken(result.token);
        onLogin(result.user);
      } else if (mode === "complete") {
        const result = await api("/api/auth/complete-registration", { method: "POST", body: JSON.stringify(form) });
        setToken(result.token);
        onLogin(result.user);
      } else {
        const result = await api("/api/auth/registration-requests", { method: "POST", body: JSON.stringify(form) });
        setMessage(result.message);
      }
    } catch (err) {
      setMessage(err.message);
    }
  }

  return (
    <section className="narrow">
      <div className="panel">
        <p className="kicker">Account</p>
        <h1>{mode === "login" ? "Anmelden" : "Registrierung"}</h1>
        <div className="segmented">
          <button className={mode === "login" ? "active" : ""} onClick={() => setMode("login")} type="button">Login</button>
          <button className={mode === "request" ? "active" : ""} onClick={() => setMode("request")} type="button">Anfrage</button>
          <button className={mode === "complete" ? "active" : ""} onClick={() => setMode("complete")} type="button">Code</button>
        </div>
        <form onSubmit={submit} className="form">
          <label>Twitch-Name<input value={form.username} onChange={(event) => setForm({ ...form, username: event.target.value })} /></label>
          <label>Passwort<input type="password" value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} /></label>
          {mode === "complete" && <label>Einmalcode<input value={form.code} onChange={(event) => setForm({ ...form, code: event.target.value })} /></label>}
          <button type="submit">{mode === "login" ? "Anmelden" : mode === "complete" ? "Registrierung abschliessen" : "Anfragen"}</button>
        </form>
        {message && <div className="notice">{message}</div>}
      </div>
    </section>
  );
}

function ProfilePage({ user, setUser, setPage }) {
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

function ListPage({ title, path, render }) {
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

function CardGrid({ title, items, render }) {
  return (
    <section className="stack">
      <h2>{title}</h2>
      <div className="grid">{items.length ? items.map(render) : <div className="notice">Noch keine Eintraege.</div>}</div>
    </section>
  );
}

function MembersPage({ user, setPage }) {
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

function formatChatTime(value) {
  if (!value) return "";
  try {
    return new Intl.DateTimeFormat("de-DE", { hour: "2-digit", minute: "2-digit" }).format(new Date(value));
  } catch {
    return "";
  }
}

function chatStyleClass(style) {
  return `chatStyle-${["sparkle", "cotton", "neon", "royal"].includes(style) ? style : "default"}`;
}

function ChatPage({ user, setPage }) {
  const initialTarget = useMemo(() => {
    try {
      return localStorage.getItem("aviary_chat_target") || "";
    } catch {
      return "";
    }
  }, []);
  const [mode, setMode] = useState(initialTarget ? "private" : "global");
  const [selectedUser, setSelectedUser] = useState(initialTarget);
  const [users, setUsers] = useState([]);
  const [onlineUsers, setOnlineUsers] = useState([]);
  const [messages, setMessages] = useState([]);
  const [body, setBody] = useState("");
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [styleState, setStyleState] = useState({ selected: "default", styles: [] });

  useEffect(() => {
    try {
      localStorage.removeItem("aviary_chat_target");
    } catch {
      // Optional handoff only.
    }
  }, []);

  useEffect(() => {
    if (!user) return undefined;
    let alive = true;
    async function loadPeople() {
      try {
        const [nextUsers, nextOnline, nextStyles] = await Promise.all([
          api("/api/users"),
          api("/api/chat/online"),
          api("/api/chat/styles"),
        ]);
        if (!alive) return;
        setUsers(nextUsers);
        setOnlineUsers(nextOnline);
        setStyleState(nextStyles);
      } catch (err) {
        if (alive) setNotice(err.message);
      }
    }
    loadPeople();
    const interval = window.setInterval(loadPeople, 10000);
    return () => {
      alive = false;
      window.clearInterval(interval);
    };
  }, [user?.username]);

  useEffect(() => {
    if (!user) return undefined;
    let alive = true;
    async function loadMessages() {
      const path = mode === "global" ? "/api/chat/global" : selectedUser ? `/api/chat/private/${encodeURIComponent(selectedUser)}` : "";
      if (!path) {
        setMessages([]);
        setLoading(false);
        return;
      }
      try {
        const next = await api(path);
        if (!alive) return;
        setMessages(next);
        setNotice("");
      } catch (err) {
        if (alive) setNotice(err.message.includes("chat_messages") ? "Chat-Tabelle fehlt noch. Bitte add_chat_tables.sql in Supabase ausfuehren." : err.message);
      } finally {
        if (alive) setLoading(false);
      }
    }
    setLoading(true);
    loadMessages();
    const interval = window.setInterval(loadMessages, 3500);
    return () => {
      alive = false;
      window.clearInterval(interval);
    };
  }, [mode, selectedUser, user?.username]);

  if (!user) return <EmptyLogin setPage={setPage} />;

  const onlineNames = new Set(onlineUsers.map((member) => member.username));
  const selectableUsers = users.filter((member) => member.username && member.username !== user.username);
  const currentTarget = selectableUsers.find((member) => member.username === selectedUser);

  async function chooseStyle(style) {
    const next = styleState.styles.find((entry) => entry.id === style);
    if (!next?.owned) {
      setPage("shop");
      return;
    }
    try {
      const result = await api("/api/chat/styles", { method: "POST", body: JSON.stringify({ style }) });
      setStyleState((current) => ({ ...current, selected: result.style }));
      setNotice(result.message);
    } catch (err) {
      setNotice(err.message);
    }
  }

  async function sendMessage(event) {
    event.preventDefault();
    const text = body.trim();
    if (!text) return;
    if (mode === "private" && !selectedUser) {
      setNotice("Waehle zuerst ein Mitglied fuer den privaten Chat.");
      return;
    }
    const path = mode === "global" ? "/api/chat/global" : `/api/chat/private/${encodeURIComponent(selectedUser)}`;
    try {
      const result = await api(path, { method: "POST", body: JSON.stringify({ body: text }) });
      setMessages((current) => [...current, result.message].filter(Boolean));
      setBody("");
      setNotice("");
    } catch (err) {
      setNotice(err.message.includes("chat_messages") ? "Chat-Tabelle fehlt noch. Bitte add_chat_tables.sql in Supabase ausfuehren." : err.message);
    }
  }

  return (
    <section className="stack chatPage">
      <div className="chatHero">
        <div>
          <p className="kicker">Live Schwarmfunk</p>
          <h1>Chat</h1>
          <p>Global mit allen Online-Mitgliedern schreiben oder direkt private Nachrichten senden.</p>
        </div>
        <div className="chatModeTabs" role="tablist" aria-label="Chatmodus">
          <button className={mode === "global" ? "active" : ""} onClick={() => setMode("global")} type="button"><MessageCircle size={17} /> Global</button>
          <button className={mode === "private" ? "active" : ""} onClick={() => setMode("private")} type="button"><Mail size={17} /> Privat</button>
        </div>
      </div>
      <div className="chatLayout">
        <aside className="chatSidebar panel">
          <PanelTitle icon={Users} title="Online" action={`${onlineUsers.length}`} />
          <div className="chatPeopleList">
            {onlineUsers.length ? onlineUsers.map((member) => (
              <button key={member.username} onClick={() => { setSelectedUser(member.username); setMode("private"); }} type="button">
                <Avatar user={member} />
                <span><b>{member.username}</b><small>Online</small></span>
                <i />
              </button>
            )) : <div className="notice">Gerade niemand online.</div>}
          </div>
          <PanelTitle icon={Mail} title="Privat schreiben" action={`${selectableUsers.length}`} />
          <div className="chatPeopleList compact">
            {selectableUsers.map((member) => (
              <button className={selectedUser === member.username && mode === "private" ? "active" : ""} key={member.username} onClick={() => { setSelectedUser(member.username); setMode("private"); }} type="button">
                <Avatar user={member} />
                <span><b>{member.username}</b><small>{onlineNames.has(member.username) ? "Online" : "Offline"}</small></span>
                {onlineNames.has(member.username) && <i />}
              </button>
            ))}
          </div>
        </aside>
        <div className="chatWindow panel">
          <div className="chatWindowHead">
            <div>
              <span>{mode === "global" ? "Globalchat" : "Privater Chat"}</span>
              <strong>{mode === "global" ? "Alle online im Aviary" : currentTarget?.username || "Mitglied waehlen"}</strong>
            </div>
            {mode === "private" && currentTarget && <RoleBadge user={currentTarget} />}
          </div>
          {notice && <div className="notice error">{notice}</div>}
          <div className="chatStylePicker" aria-label="Chatbalken Animationen">
            {styleState.styles.map((style) => (
              <button
                className={`${styleState.selected === style.id ? "active" : ""} ${chatStyleClass(style.id)}`}
                key={style.id}
                onClick={() => chooseStyle(style.id)}
                type="button"
                title={style.owned ? style.description : "Im Shop kaufen"}
              >
                <span>{style.name}</span>
                {!style.owned && <small>{style.price} Chickens</small>}
              </button>
            ))}
          </div>
          <div className="chatMessages" aria-live="polite">
            {loading && <div className="notice">Lade Chat...</div>}
            {!loading && !messages.length && <div className="notice">Noch keine Nachrichten. Schreib die erste.</div>}
            {messages.map((message) => {
              const mine = message.sender_username === user.username;
              return (
                <article className={`chatBubble ${mine ? "mine" : ""} ${chatStyleClass(message.chat_style)}`} key={message.id || `${message.sender_username}-${message.created_at}`}>
                  {!mine && <Avatar user={message.sender} />}
                  <div>
                    <header>
                      <b>{message.sender?.username || message.sender_username}</b>
                      <RoleBadge user={message.sender} />
                      <time>{formatChatTime(message.created_at)}</time>
                    </header>
                    <p>{message.body}</p>
                  </div>
                </article>
              );
            })}
          </div>
          <form className="chatComposer" onSubmit={sendMessage}>
            <input
              value={body}
              onChange={(event) => setBody(event.target.value)}
              placeholder={mode === "global" ? "Nachricht an alle Online-Mitglieder..." : selectedUser ? `Nachricht an ${selectedUser}...` : "Erst Mitglied links waehlen..."}
              maxLength={1200}
              disabled={mode === "private" && !selectedUser}
            />
            <button type="submit" disabled={!body.trim() || (mode === "private" && !selectedUser)}><Send size={17} /> Senden</button>
          </form>
        </div>
      </div>
    </section>
  );
}

function LeaderboardPage() {
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

function ShopPage({ user, setPage }) {
  const { data, error, loading } = useApi("/api/shop", []);
  return <CommunityShop user={user} setPage={setPage} data={data} error={error} loading={loading} />;
}

function EventsPage({ user, setPage }) {
  const { data, loading, error } = useApi("/api/events", []);
  const [message, setMessage] = useState("");
  if (!user) return <EmptyLogin setPage={setPage} />;
  async function signup(eventId) {
    try {
      const result = await api("/api/events/signup", { method: "POST", body: JSON.stringify({ event_id: eventId }) });
      setMessage(result.message);
    } catch (err) {
      setMessage(err.message);
    }
  }
  return (
    <section className="stack">
      <h1>Events</h1>
      {message && <div className="notice">{message}</div>}
      {loading && <div className="notice">Lade Events...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="list">
        {data.map((event) => (
          <article className="rowCard eventTicket" key={event.id}>
            <div><h3>{event.title}</h3><p>{event.description}</p><span>{event.event_date}</span></div>
            <button onClick={() => signup(event.id)} type="button">Anmelden</button>
          </article>
        ))}
      </div>
    </section>
  );
}

const Scoreboard = GameScoreboard;

function GamesPage({ user }) {
  const gameFromRoute = () => {
    const [, nextGame] = routeParts();
    if (nextGame === "chicken-racer") return "chicken-flipper";
    return gameMeta[nextGame] && nextGame !== "dnd" ? nextGame : "chicken-jump";
  };
  const [game, setGameState] = useState(gameFromRoute);
  function setGame(nextGame) {
    setGameState(nextGame);
    window.history.replaceState(null, "", `/#games/${nextGame}`);
  }
  useEffect(() => {
    function syncGame() { setGameState(gameFromRoute()); }
    window.addEventListener("hashchange", syncGame);
    window.addEventListener("popstate", syncGame);
    return () => {
      window.removeEventListener("hashchange", syncGame);
      window.removeEventListener("popstate", syncGame);
    };
  }, []);
  const current = {
    "chicken-jump": <ChickenJump user={user} renderScoreboard={(refreshKey) => <Scoreboard game="chicken-jump" refreshKey={refreshKey} />} />,
    "chicken-snake": <ChickenSnake user={user} renderScoreboard={(refreshKey) => <Scoreboard game="chicken-snake" refreshKey={refreshKey} />} />,
    "chicken-flipper": <PepplePinball user={user} renderScoreboard={(refreshKey) => <Scoreboard game="chicken-flipper" refreshKey={refreshKey} />} />,
    "braincell-survivor": <Suspense fallback={<div className="notice">Lade Pepple Survivor …</div>}><PeppleSurvivor user={user} renderScoreboard={(refreshKey) => <Scoreboard game="braincell-survivor" refreshKey={refreshKey} />} /></Suspense>,
  }[game];

  return (
    <section className="gamesShell">
      <div className="sectionHero arcadeHero">
        <div>
          <p className="kicker">Minispiele</p>
          <h1>Dein nächster Highscore wartet.</h1>
          <p>Vier Spiele, neue Bestleistungen und jede Menge Chickens. Such dir dein Spiel aus.</p>
        </div>
        <Zap size={64} />
      </div>
      <div className="gameEarningInfo">Chickens verdienen: Runde spielen und danach den Score einreichen. Bis zu 25 pro Runde und 120 pro Tag, ab 15 Sekunden Spielzeit. Punkte und Spielzeit bestimmen deine Belohnung.</div>
      <div className="gameTabs">
        {Object.entries(gameMeta).map(([id, meta]) => (
          <button className={game === id ? "active" : ""} key={id} onClick={() => id !== "dnd" && setGame(id)} disabled={id === "dnd"} type="button">
            <Gamepad2 size={16} /> {meta.title}
          </button>
        ))}
      </div>
      {current}
    </section>
  );
}

function SystematicsPage() {
  const boardRef = useRef(null);
  const [doc, setDoc] = useState({ title: "Systematik", description: "", nodes: [], links: [] });
  const [selectedId, setSelectedId] = useState("");
  const [newBox, setNewBox] = useState({ parentId: "", title: "Neue Box", subtitle: "Beschreibung", color: "#b46cff", template: "custom" });
  const [adminPassword, setAdminPassword] = useState("");
  const [editing, setEditing] = useState(false);
  const [connectFrom, setConnectFrom] = useState("");
  const [message, setMessage] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const selected = doc.nodes.find((node) => node.id === selectedId) || doc.nodes[0];
  const parentId = selected ? parentForNode(doc, selected.id) : "";
  const nodeOptions = buildNodeOptions(doc);
  const selectedPath = selected ? pathForNode(doc, selected.id) : "";

  useEffect(() => {
    api("/api/systematics")
      .then((result) => {
        setDoc(autoLayoutSystematics({ ...result, links: primaryTreeLinks(result) }));
        setSelectedId(result.nodes?.[0]?.id || "");
        setNewBox((current) => ({ ...current, parentId: result.nodes?.[0]?.id || "" }));
      })
      .catch((err) => setMessage(err.message));
  }, [reloadKey]);

  function updateDoc(patch) {
    setDoc((current) => ({ ...current, ...patch }));
  }

  function updateNode(id, patch) {
    setDoc((current) => ({
      ...current,
      nodes: current.nodes.map((node) => (node.id === id ? { ...node, ...patch } : node)),
    }));
  }

  function selectNode(nodeId) {
    setSelectedId(nodeId);
    setNewBox((current) => ({ ...current, parentId: nodeId }));
  }

  function addNode(overrides = {}) {
    const parent = doc.nodes.find((node) => node.id === (overrides.parentId || newBox.parentId || selected?.id)) || doc.nodes[0];
    const id = `node-${Date.now()}`;
    const node = {
      id,
      title: overrides.title || newBox.title || "Neue Box",
      subtitle: overrides.subtitle || newBox.subtitle || "Beschreibung",
      color: overrides.color || newBox.color || "#b46cff",
      image_url: "",
      x: 0,
      y: 0,
    };
    setDoc((current) => autoLayoutSystematics({
      ...current,
      nodes: [...current.nodes, node],
      links: parent ? [...current.links.filter((link) => link.target !== id), { source: parent.id, target: id }] : current.links,
    }));
    setSelectedId(id);
    setNewBox((current) => ({ ...current, title: "Neue Box", subtitle: "Beschreibung", template: "custom", parentId: parent?.id || "" }));
  }

  function deleteNode() {
    if (!selected || doc.nodes.length <= 1) return;
    setDoc((current) => autoLayoutSystematics({
      ...current,
      nodes: current.nodes.filter((node) => node.id !== selected.id),
      links: current.links.filter((link) => link.source !== selected.id && link.target !== selected.id),
    }));
    setSelectedId(doc.nodes.find((node) => node.id !== selected.id)?.id || "");
  }

  function handleConnect(nodeId) {
    if (!editing) return;
    if (!connectFrom) {
      setConnectFrom(nodeId);
      setMessage("Zielbox anklicken, um automatisch zu verbinden.");
      return;
    }
    if (connectFrom !== nodeId) {
      if (descendantsForNode(doc, nodeId).has(connectFrom)) {
        setMessage("Diese Verbindung wuerde eine Schleife bauen. Bitte anders einsortieren.");
        setConnectFrom("");
        return;
      }
      setDoc((current) => {
        const exists = current.links.some((link) => link.source === connectFrom && link.target === nodeId);
        return exists ? current : autoLayoutSystematics({ ...current, links: [...current.links, { source: connectFrom, target: nodeId }] });
      });
    }
    setConnectFrom("");
  }

  function removeLink(source, target) {
    setDoc((current) => autoLayoutSystematics({ ...current, links: current.links.filter((link) => link.source !== source || link.target !== target) }));
  }

  function changeParent(nodeId, nextParentId) {
    if (!nodeId || nodeId === nextParentId) return;
    const descendantIds = descendantsForNode(doc, nodeId);
    if (descendantIds.has(nextParentId)) {
      setMessage("Diese Box kann nicht unter ihr eigenes Kind einsortiert werden.");
      return;
    }
    setDoc((current) => autoLayoutSystematics({
      ...current,
      links: [
        ...current.links.filter((link) => link.target !== nodeId),
        ...(nextParentId ? [{ source: nextParentId, target: nodeId }] : []),
      ],
    }));
  }

  function applyTemplate(templateKey) {
    const template = systematicsTemplates.find((item) => item.id === templateKey);
    if (!template) return;
    setNewBox((current) => ({ ...current, template: templateKey, title: template.title, subtitle: template.subtitle, color: template.color }));
  }

  function pointerDown(event, node) {
    event.preventDefault();
    if (connectFrom) {
      handleConnect(node.id);
      return;
    }
    selectNode(node.id);
  }

  function addSibling() {
    addNode({ parentId, title: "Neue Box daneben" });
  }

  function repairStructure() {
    setDoc((current) => autoLayoutSystematics({ ...current, links: primaryTreeLinks(current) }));
    setMessage("Struktur bereinigt: jede Box hat nur noch eine Haupt-Elternbox.");
  }

  async function unlock() {
    try {
      await api("/api/admin/overview", { headers: { "X-Admin-Password": adminPassword } });
      setEditing(true);
      setMessage("Bearbeitungsmodus aktiv.");
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function save() {
    try {
      const arranged = autoLayoutSystematics({ ...doc, links: primaryTreeLinks(doc) });
      const result = await api("/api/admin/systematics", {
        method: "PUT",
        headers: { "X-Admin-Password": adminPassword },
        body: JSON.stringify(arranged),
      });
      setDoc(arranged);
      setMessage(result.message);
      setReloadKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  function imageUpload(event) {
    const file = event.target.files?.[0];
    if (!file || !selected) return;
    const reader = new FileReader();
    reader.onload = () => updateNode(selected.id, { image_url: String(reader.result || "") });
    reader.readAsDataURL(file);
  }

  const nodeById = new Map(doc.nodes.map((node) => [node.id, node]));

  return (
    <section className="systematicsShell">
      <div className="sectionHero systematicsHero">
        <div>
          <p className="kicker">Baukasten</p>
          <h1>{doc.title}</h1>
          <p>{doc.description}</p>
        </div>
        <GitBranch size={68} />
      </div>
      <div className="systematicsLayout">
        <div className="systematicsBoardWrap">
          <div className="systematicsToolbar">
            <div>
              <span className={editing ? "editBadge active" : "editBadge"}>{editing ? "Admin Bearbeitung aktiv" : "Nur Ansicht"}</span>
              {connectFrom && <span className="editBadge active">Zielbox anklicken: verbindet und sortiert automatisch</span>}
            </div>
            <div>
              <button className="ghost" onClick={() => setConnectFrom(selected?.id || "")} disabled={!editing || !selected} type="button"><Link2 size={16} /> Spezial-Verbindung</button>
              <button onClick={() => addNode({ parentId: selected?.id })} disabled={!editing || !selected} type="button"><Plus size={16} /> Kind zu Auswahl</button>
              <button className="ghost" onClick={addSibling} disabled={!editing || !selected} type="button"><Plus size={16} /> Daneben</button>
              <button className="ghost" onClick={() => setDoc((current) => autoLayoutSystematics(current))} disabled={!editing} type="button"><RefreshCw size={16} /> Auto sortieren</button>
              <button className="ghost" onClick={save} disabled={!editing} type="button"><Save size={16} /> Speichern</button>
            </div>
          </div>
          <div className="systematicsBoard" ref={boardRef}>
            <svg className="systematicsLinks" viewBox="0 0 1080 650" preserveAspectRatio="none">
              {doc.links.map((link) => {
                const source = nodeById.get(link.source);
                const target = nodeById.get(link.target);
                if (!source || !target) return null;
                const x1 = Number(source.x || 0) + 82;
                const y1 = Number(source.y || 0) + 104;
                const x2 = Number(target.x || 0) + 82;
                const y2 = Number(target.y || 0);
                const mid = (y1 + y2) / 2;
                return <path key={`${link.source}-${link.target}`} d={`M ${x1} ${y1} C ${x1} ${mid}, ${x2} ${mid}, ${x2} ${y2}`} />;
              })}
            </svg>
            {doc.nodes.map((node) => (
              <button
                className={`systemNode ${selected?.id === node.id ? "selected" : ""} ${connectFrom === node.id ? "connecting" : ""}`}
                key={node.id}
                onClick={() => selectNode(node.id)}
                onDoubleClick={() => handleConnect(node.id)}
                onPointerDown={(event) => pointerDown(event, node)}
                style={{ left: node.x, top: node.y, "--node-color": node.color }}
                type="button"
              >
                <span className="systemNodeImage">{node.image_url ? <img src={node.image_url} alt="" /> : <GitBranch size={28} />}</span>
                <strong>{node.title}</strong>
                <small>{node.subtitle}</small>
              </button>
            ))}
          </div>
        </div>
        <aside className="systematicsEditor">
          <div className="panel form">
            <h2><Lock size={18} /> Admin</h2>
            <label>Admin Passwort<input type="password" value={adminPassword} onChange={(event) => setAdminPassword(event.target.value)} /></label>
            <button onClick={unlock} type="button"><MousePointer2 size={16} /> Builder freischalten</button>
            {message && <div className="notice">{message}</div>}
          </div>
          <div className="panel form systematicsQuickAdd">
            <h2><Plus size={18} /> Neue Box</h2>
            <div className="builderHint">
              <strong>1. Ziel waehlen</strong>
              <span>Beispiel: fuer Huhn erst `Voegel` oder `Huehnervoegel` auswaehlen, dann einfuegen.</span>
            </div>
            <label>Gehört zu
              <select disabled={!editing} value={newBox.parentId || selected?.id || ""} onChange={(event) => setNewBox({ ...newBox, parentId: event.target.value })}>
                {nodeOptions.map((option) => <option value={option.id} key={option.id}>{option.label}</option>)}
              </select>
            </label>
            <label>Text<input disabled={!editing} value={newBox.title} onChange={(event) => setNewBox({ ...newBox, title: event.target.value, template: "custom" })} /></label>
            <label>Untertext<input disabled={!editing} value={newBox.subtitle} onChange={(event) => setNewBox({ ...newBox, subtitle: event.target.value, template: "custom" })} /></label>
            <label>Farbe<input disabled={!editing} type="color" value={newBox.color} onChange={(event) => setNewBox({ ...newBox, color: event.target.value, template: "custom" })} /></label>
            <div className="newBoxPreview" style={{ "--node-color": newBox.color }}>
              <span>{doc.nodes.find((node) => node.id === newBox.parentId)?.title || "Oberste Ebene"}</span>
              <strong>{newBox.title}</strong>
              <small>{newBox.subtitle}</small>
            </div>
            <button onClick={() => addNode({ parentId: newBox.parentId })} disabled={!editing || !newBox.parentId} type="button"><Plus size={16} /> Unter dieser Box einfuegen</button>
          </div>
          {selected && (
            <div className="panel form selectedBoxEditor">
              <h2><MousePointer2 size={18} /> Box bearbeiten</h2>
              {selectedPath && <div className="builderHint"><strong>Aktueller Pfad</strong><span>{selectedPath}</span></div>}
              <div className="editorActions">
                <button onClick={() => addNode({ parentId: selected.id, title: "Neue Unterbox" })} disabled={!editing} type="button">Kind hinzufuegen</button>
                <button className="ghost dangerButton" onClick={deleteNode} disabled={!editing || doc.nodes.length <= 1} type="button"><Trash2 size={16} /></button>
              </div>
              <label>Diese Box gehört zu
                <select disabled={!editing || doc.nodes.length <= 1} value={parentId} onChange={(event) => changeParent(selected.id, event.target.value)}>
                  <option value="">Oberste Ebene</option>
                  {nodeOptions.filter((option) => option.id !== selected.id && !descendantsForNode(doc, selected.id).has(option.id)).map((option) => <option value={option.id} key={option.id}>{option.label}</option>)}
                </select>
              </label>
              <label>Text<input disabled={!editing} value={selected.title} onChange={(event) => updateNode(selected.id, { title: event.target.value })} /></label>
              <label>Untertext<input disabled={!editing} value={selected.subtitle} onChange={(event) => updateNode(selected.id, { subtitle: event.target.value })} /></label>
              <label>Farbe<input disabled={!editing} type="color" value={selected.color} onChange={(event) => updateNode(selected.id, { color: event.target.value })} /></label>
              <label>Bild-URL<input disabled={!editing} value={selected.image_url?.startsWith("data:") ? "" : selected.image_url} onChange={(event) => updateNode(selected.id, { image_url: event.target.value })} /></label>
              <label className="fileInput"><ImageIcon size={16} /> Bild hochladen<input disabled={!editing} type="file" accept="image/*" onChange={imageUpload} /></label>
            </div>
          )}
          <details className="panel systematicsAdvanced">
            <summary>Erweitert</summary>
            <div className="form">
              <label>Systematik Titel<input disabled={!editing} value={doc.title} onChange={(event) => updateDoc({ title: event.target.value })} /></label>
              <label>Beschreibung<textarea disabled={!editing} value={doc.description} onChange={(event) => updateDoc({ description: event.target.value })} /></label>
              <label>Vorlage
                <select disabled={!editing} value={newBox.template} onChange={(event) => applyTemplate(event.target.value)}>
                  {systematicsTemplates.map((template) => <option value={template.id} key={template.id}>{template.label}</option>)}
                </select>
              </label>
              <div className="templateChips">
                {systematicsTemplates.slice(2).map((template) => (
                  <button disabled={!editing} onClick={() => applyTemplate(template.id)} type="button" key={template.id} style={{ "--node-color": template.color }}>{template.label}</button>
                ))}
              </div>
            </div>
          </details>
          <div className="panel">
            <h2><Link2 size={18} /> Verbindungen</h2>
            <button className="ghost repairButton" disabled={!editing} onClick={repairStructure} type="button"><RefreshCw size={16} /> Hauptstruktur bereinigen</button>
            <div className="linkList">
              {doc.links.map((link) => <button disabled={!editing} onClick={() => removeLink(link.source, link.target)} type="button" key={`${link.source}-${link.target}`}>{nodeById.get(link.source)?.title}{" -> "}{nodeById.get(link.target)?.title}</button>)}
            </div>
          </div>
        </aside>
      </div>
    </section>
  );
}

function TypeIcon() {
  return <span className="typeIcon">T</span>;
}

const systematicsTemplates = [
  { id: "custom", label: "Eigene Box", title: "Neue Box", subtitle: "Beschreibung", color: "#b46cff" },
  { id: "kingdom", label: "Reich", title: "Tierreich", subtitle: "Animalia", color: "#ffcf8a" },
  { id: "class", label: "Klasse", title: "Voegel", subtitle: "Aves", color: "#7af4dc" },
  { id: "order", label: "Ordnung", title: "Huehnervoegel", subtitle: "Galliformes", color: "#ff6fb7" },
  { id: "family", label: "Familie", title: "Fasanenartige", subtitle: "Phasianidae", color: "#c88956" },
  { id: "genus", label: "Gattung", title: "Kammhuehner", subtitle: "Gallus", color: "#b46cff" },
  { id: "species", label: "Art", title: "Haushuhn", subtitle: "Gallus gallus domesticus", color: "#ffcf8a" },
  { id: "mammal", label: "Saeugetier", title: "Saeugetiere", subtitle: "Mammalia", color: "#7af4dc" },
  { id: "reptile", label: "Reptil", title: "Reptilien", subtitle: "Reptilia", color: "#8edb75" },
];

function parentForNode(doc, nodeId) {
  return doc.links.find((link) => link.target === nodeId)?.source || "";
}

function pathForNode(doc, nodeId) {
  const byId = new Map(doc.nodes.map((node) => [node.id, node]));
  const parts = [];
  const seen = new Set();
  let currentId = nodeId;
  while (currentId && byId.has(currentId) && !seen.has(currentId)) {
    seen.add(currentId);
    parts.unshift(byId.get(currentId)?.title || "Box");
    currentId = parentForNode(doc, currentId);
  }
  return parts.join(" > ");
}

function buildNodeOptions(doc) {
  return doc.nodes
    .map((node) => ({ id: node.id, label: pathForNode(doc, node.id) || node.title }))
    .sort((a, b) => a.label.localeCompare(b.label, "de"));
}

function primaryTreeLinks(doc) {
  const ids = new Set(doc.nodes.map((node) => node.id));
  const accepted = [];
  const targetSeen = new Set();
  for (const link of doc.links) {
    if (!ids.has(link.source) || !ids.has(link.target) || link.source === link.target || targetSeen.has(link.target)) continue;
    const draft = { ...doc, links: [...accepted, link] };
    if (descendantsForNode(draft, link.target).has(link.source)) continue;
    accepted.push(link);
    targetSeen.add(link.target);
  }
  return accepted;
}

function descendantsForNode(doc, nodeId) {
  const children = new Map(doc.nodes.map((node) => [node.id, []]));
  doc.links.forEach((link) => children.get(link.source)?.push(link.target));
  const result = new Set();
  const queue = [...(children.get(nodeId) || [])];
  while (queue.length) {
    const current = queue.shift();
    if (!current || result.has(current)) continue;
    result.add(current);
    queue.push(...(children.get(current) || []));
  }
  return result;
}

function autoLayoutSystematics(input) {
  const nodes = Array.isArray(input?.nodes) ? input.nodes : [];
  const rawLinks = Array.isArray(input?.links) ? input.links : [];
  const ids = new Set(nodes.map((node) => node.id));
  const links = rawLinks.filter((link) => ids.has(link.source) && ids.has(link.target) && link.source !== link.target);
  const incoming = new Map(nodes.map((node) => [node.id, 0]));
  const children = new Map(nodes.map((node) => [node.id, []]));
  links.forEach((link) => {
    incoming.set(link.target, (incoming.get(link.target) || 0) + 1);
    children.get(link.source)?.push(link.target);
  });

  const roots = nodes.filter((node) => (incoming.get(node.id) || 0) === 0);
  const levelById = new Map();
  const queue = (roots.length ? roots : nodes.slice(0, 1)).map((node) => ({ id: node.id, level: 0 }));
  while (queue.length) {
    const current = queue.shift();
    if (!current) continue;
    const previous = levelById.get(current.id);
    if (previous !== undefined && previous <= current.level) continue;
    levelById.set(current.id, current.level);
    (children.get(current.id) || []).forEach((childId) => queue.push({ id: childId, level: current.level + 1 }));
  }

  nodes.forEach((node) => {
    if (!levelById.has(node.id)) levelById.set(node.id, Math.max(0, levelById.size ? Math.max(...levelById.values()) + 1 : 0));
  });

  const levels = new Map();
  nodes.forEach((node) => {
    const level = levelById.get(node.id) || 0;
    levels.set(level, [...(levels.get(level) || []), node]);
  });

  const width = 1080;
  const nodeWidth = 164;
  const top = 42;
  const rowGap = 156;
  const arrangedNodes = nodes.map((node) => {
    const level = levelById.get(node.id) || 0;
    const row = levels.get(level) || [];
    const index = row.findIndex((item) => item.id === node.id);
    const gap = Math.max(24, (width - row.length * nodeWidth) / (row.length + 1));
    return {
      ...node,
      x: Math.round(gap + index * (nodeWidth + gap)),
      y: Math.round(top + level * rowGap),
    };
  });

  return {
    title: input?.title || "Systematik",
    description: input?.description || "",
    nodes: arrangedNodes,
    links,
  };
}

function AdminPage() {
  const [password, setPassword] = useState("");
  const [overview, setOverview] = useState(null);
  const [message, setMessage] = useState("");
  const [tab, setTab] = useState("registrations");
  const [reloadKey, setReloadKey] = useState(0);
  const [news, setNews] = useState({ title: "", body: "", image_url: "" });
  const [shop, setShop] = useState({ name: "", description: "", price: 0, category: "Rewards" });
  const [eventForm, setEventForm] = useState({ title: "", description: "", event_date: "" });

  async function adminCall(path, options = {}) {
    return api(path, { ...options, headers: { "X-Admin-Password": password, ...(options.headers || {}) } });
  }

  async function load() {
    try {
      setMessage("");
      const [adminOverview, shopItems, events, newsPosts] = await Promise.all([
        adminCall("/api/admin/overview"),
        api("/api/shop").catch(() => []),
        api("/api/events").catch(() => []),
        api("/api/news").catch(() => []),
      ]);
      setOverview({ ...adminOverview, shop_items: shopItems, events, news_posts: newsPosts });
    } catch (err) {
      setMessage(err.message);
    }
  }

  useEffect(() => {
    if (overview) load();
  }, [reloadKey]);

  async function mutate(path, options, success) {
    try {
      const result = await adminCall(path, options);
      setMessage(success || result.message || "Gespeichert.");
      setReloadKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function approveRegistration(id, username) {
    try {
      const result = await adminCall(`/api/admin/registration/${id}/approve`, { method: "POST", body: "{}" });
      setMessage(`Code fuer ${username}: ${result.code}`);
      setReloadKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  const tabs = [
    ["registrations", "Registrierungen"],
    ["points", "Chickens"],
    ["roles", "Mitglieder & Rollen"],
    ["news", "News"],
    ["live-news", "Live News"],
    ["shop-alerts", "Shop-Alerts"],
    ["shop", "Shop"],
    ["events", "Events"],
    ["support", "Support"],
  ];

  return (
    <section className="stack">
      <div className="adminHero">
        <div>
          <p className="kicker">Admin Center</p>
          <h1>Kontrollraum</h1>
          <p>Registrierungen, Chickens, News, Shop, Events und Meldungen verwalten.</p>
        </div>
        <Shield size={72} />
      </div>
      <div className="panel form">
        <label>Admin Passwort<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} /></label>
        <button onClick={load} type="button">Dashboard laden</button>
        {message && <div className="notice">{message}</div>}
      </div>
      {overview && (
        <>
          <div className="adminStats">
            <Stat label="Viewer" value={overview.users.length} />
            <Stat label="Anfragen" value={overview.registration_requests.length} />
            <Stat label="Meldungen" value={overview.support_messages.length} />
            <Stat label="Shop Items" value={overview.shop_items.length} />
          </div>
          <div className="segmented adminTabs">
            {tabs.map(([id, label]) => <button className={tab === id ? "active" : ""} onClick={() => setTab(id)} type="button" key={id}>{label}</button>)}
          </div>
          {tab === "registrations" && <div className="grid">{overview.registration_requests.map((item) => <article className="card" key={item.id}><h3>{item.username}</h3><p>{item.status}</p><button onClick={() => approveRegistration(item.id, item.username)} type="button"><Check size={16} /> Genehmigen</button></article>)}</div>}
          {tab === "points" && <AdminPoints users={overview.users} adminCall={adminCall} onUpdated={() => setReloadKey((value) => value + 1)} />}
          {tab === "roles" && <AdminMembers users={overview.users} adminCall={adminCall} onUpdated={() => setReloadKey((value) => value + 1)} />}
          {tab === "news" && (
            <AdminListForm title="News erstellen" form={news} setForm={setNews} fields={["title", "body", "image_url"]} onSubmit={() => mutate("/api/admin/news", { method: "POST", body: JSON.stringify(news) })}>
              {overview.news_posts.map((item) => <AdminRow key={item.id} title={item.title} text={item.body} onDelete={() => mutate(`/api/admin/news/${item.id}`, { method: "DELETE" })} />)}
            </AdminListForm>
          )}
          {tab === "live-news" && <LiveNewsAdmin password={password} />}
          {tab === "shop-alerts" && <ShopAlertsAdmin password={password} />}
          {tab === "shop" && (
            <AdminListForm title="Shop Item erstellen" form={shop} setForm={setShop} fields={["name", "description", "price", "category"]} onSubmit={() => mutate("/api/admin/shop", { method: "POST", body: JSON.stringify({ ...shop, price: Number(shop.price) }) })}>
              {overview.shop_items.map((item) => <AdminRow key={item.id} title={`${item.name} · ${item.price} Chickens`} text={item.description || item.desc} onDelete={() => mutate(`/api/admin/shop/${item.id}`, { method: "DELETE" })} />)}
            </AdminListForm>
          )}
          {tab === "events" && (
            <AdminListForm title="Event erstellen" form={eventForm} setForm={setEventForm} fields={["title", "description", "event_date"]} onSubmit={() => mutate("/api/admin/events", { method: "POST", body: JSON.stringify(eventForm) })}>
              {overview.events.map((item) => <AdminRow key={item.id} title={`${item.title} · ${item.event_date || "TBA"}`} text={item.description} onDelete={() => mutate(`/api/admin/events/${item.id}`, { method: "DELETE" })} />)}
            </AdminListForm>
          )}
          {tab === "support" && <div className="list">{overview.support_messages.map((item) => <AdminRow key={item.id} title={`${item.title} · ${item.category}`} text={`${item.username}: ${item.message}`} onDelete={() => mutate(`/api/admin/support/${item.id}`, { method: "PATCH", body: "{}" }, "Meldung geschlossen.")} />)}</div>}
        </>
      )}
    </section>
  );
}

function AdminListForm({ title, form, setForm, fields, onSubmit, children }) {
  return (
    <section className="twoCol">
      <form className="panel form" onSubmit={(event) => { event.preventDefault(); onSubmit(); }}>
        <h2>{title}</h2>
        {fields.map((field) => (
          <label key={field}>{field.replace("_", " ")}
            {field === "body" || field === "description" ? <textarea value={form[field] || ""} onChange={(event) => setForm({ ...form, [field]: event.target.value })} /> : <input type={field === "price" ? "number" : "text"} value={form[field] || ""} onChange={(event) => setForm({ ...form, [field]: event.target.value })} />}
          </label>
        ))}
        <button type="submit"><Plus size={16} /> Erstellen</button>
      </form>
      <div className="list">{children}</div>
    </section>
  );
}

function AdminRow({ title, text, onDelete }) {
  return (
    <article className="rowCard">
      <div><h3>{title}</h3><p>{text}</p></div>
      <button className="ghost dangerButton" onClick={onDelete} type="button"><Trash2 size={16} /></button>
    </article>
  );
}

const galleryReactions = ["😍", "😂", "🔥", "💜", "👏"];

function GalleryPage({ user, setPage }) {
  const canvasRef = useRef(null);
  const drawingRef = useRef(false);
  const lastPointRef = useRef(null);
  const [title, setTitle] = useState("");
  const [color, setColor] = useState("#ff6fb7");
  const [size, setSize] = useState(8);
  const [message, setMessage] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);
  const { data, loading, error } = useApi("/api/gallery", [], refreshKey);

  function canvasPoint(event) {
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();
    return {
      x: (event.clientX - rect.left) / rect.width * canvas.width,
      y: (event.clientY - rect.top) / rect.height * canvas.height,
    };
  }

  function clearCanvas() {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#fffaf2";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "rgba(180, 108, 255, 0.08)";
    for (let x = 0; x < canvas.width; x += 48) ctx.fillRect(x, 0, 1, canvas.height);
    for (let y = 0; y < canvas.height; y += 48) ctx.fillRect(0, y, canvas.width, 1);
  }

  function drawTo(point) {
    const canvas = canvasRef.current;
    const last = lastPointRef.current || point;
    const ctx = canvas.getContext("2d");
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = color;
    ctx.lineWidth = Number(size);
    ctx.beginPath();
    ctx.moveTo(last.x, last.y);
    ctx.lineTo(point.x, point.y);
    ctx.stroke();
    lastPointRef.current = point;
  }

  useEffect(() => {
    clearCanvas();
  }, []);

  async function publish(event) {
    event.preventDefault();
    if (!user) {
      setPage("login");
      return;
    }
    try {
      const imageData = canvasRef.current.toDataURL("image/png");
      const result = await api("/api/gallery", { method: "POST", body: JSON.stringify({ title, image_data: imageData }) });
      setMessage(result.message);
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function react(item, emoji) {
    if (!user) {
      setPage("login");
      return;
    }
    try {
      await api("/api/gallery/reactions", { method: "POST", body: JSON.stringify({ art_id: item.id, emoji }) });
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  return (
    <section className="stack galleryPage">
      <div className="sectionHero">
        <div>
          <p className="kicker">Hall of Fame</p>
          <h1>Kreativwand</h1>
          <p>Male direkt im Browser, veroeffentliche dein Bild und gib den Werken der Community Reaktionen.</p>
        </div>
        <Palette size={64} />
      </div>
      <section className="galleryStudio">
        <form className="panel form galleryTools" onSubmit={publish}>
          <h2>Bild malen</h2>
          <label>Titel<input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="Ohne Titel" /></label>
          <div className="paintControls">
            <label>Farbe<input type="color" value={color} onChange={(event) => setColor(event.target.value)} /></label>
            <label>Strich<input type="range" min="2" max="28" value={size} onChange={(event) => setSize(event.target.value)} /></label>
          </div>
          <div className="gameActions">
            <button type="submit">In Hall of Fame veroeffentlichen</button>
            <button className="ghost" onClick={clearCanvas} type="button">Leeren</button>
          </div>
          {!user && <div className="notice">Zum Veroeffentlichen bitte einloggen.</div>}
          {message && <div className="notice">{message}</div>}
        </form>
        <div className="paintSurface">
          <canvas
            ref={canvasRef}
            width="900"
            height="520"
            onPointerDown={(event) => {
              drawingRef.current = true;
              event.currentTarget.setPointerCapture(event.pointerId);
              const point = canvasPoint(event);
              lastPointRef.current = point;
              drawTo(point);
            }}
            onPointerMove={(event) => {
              if (drawingRef.current) drawTo(canvasPoint(event));
            }}
            onPointerUp={() => {
              drawingRef.current = false;
              lastPointRef.current = null;
            }}
            onPointerCancel={() => {
              drawingRef.current = false;
              lastPointRef.current = null;
            }}
          />
        </div>
      </section>
      {loading && <div className="notice">Lade Hall of Fame...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="galleryGrid">
        {data.length ? data.map((item) => {
          const selected = user ? item.user_reactions?.[user.username] : "";
          return (
            <article className="card imageCard galleryCard" key={item.id}>
              {item.image_data && <img src={item.image_data} alt={item.title || "Hall of Fame Bild"} />}
              <h3>{item.title || "Kunstwerk"}</h3>
              <p>von {item.username}</p>
              {item.created_at && <small>{new Date(item.created_at).toLocaleDateString("de-DE")}</small>}
              <div className="reactionRow">
                {galleryReactions.map((emoji) => (
                  <button className={selected === emoji ? "active" : ""} onClick={() => react(item, emoji)} type="button" key={emoji}>
                    {emoji} {item.reactions?.[emoji] || 0}
                  </button>
                ))}
              </div>
            </article>
          );
        }) : <div className="notice">Noch keine Bilder in der Hall of Fame.</div>}
      </div>
    </section>
  );
}

function SupportPage({ user }) {
  const [form, setForm] = useState({ username: user?.username || "", category: "Problem", title: "", message: "" });
  const [wish, setWish] = useState({ title: "", description: "" });
  const [message, setMessage] = useState("");
  const { data: wishes } = useApi("/api/support/wishes", []);
  async function sendSupport(event) {
    event.preventDefault();
    try {
      const result = await api("/api/support", { method: "POST", body: JSON.stringify(form) });
      setMessage(result.message);
    } catch (err) {
      setMessage(err.message);
    }
  }
  async function sendWish(event) {
    event.preventDefault();
    try {
      const result = await api("/api/support/wishes", { method: "POST", body: JSON.stringify(wish) });
      setMessage(result.message);
    } catch (err) {
      setMessage(err.message);
    }
  }
  return (
    <section className="twoCol">
      <form className="panel form" onSubmit={sendSupport}>
        <h2>Problem melden</h2>
        <label>Name<input value={form.username} onChange={(event) => setForm({ ...form, username: event.target.value })} /></label>
        <label>Kategorie<input value={form.category} onChange={(event) => setForm({ ...form, category: event.target.value })} /></label>
        <label>Titel<input value={form.title} onChange={(event) => setForm({ ...form, title: event.target.value })} /></label>
        <label>Beschreibung<textarea value={form.message} onChange={(event) => setForm({ ...form, message: event.target.value })} /></label>
        <button type="submit">Senden</button>
        {message && <div className="notice">{message}</div>}
      </form>
      <div className="panel">
        <h2>Wuensche</h2>
        {user && (
          <form className="form" onSubmit={sendWish}>
            <label>Titel<input value={wish.title} onChange={(event) => setWish({ ...wish, title: event.target.value })} /></label>
            <label>Beschreibung<textarea value={wish.description} onChange={(event) => setWish({ ...wish, description: event.target.value })} /></label>
            <button type="submit">Wunsch veroeffentlichen</button>
          </form>
        )}
        <div className="list">{wishes.map((item) => <article className="miniCard" key={item.id}><strong>{item.title}</strong><span>{item.description}</span></article>)}</div>
      </div>
    </section>
  );
}

function EmptyLogin({ setPage }) {
  return (
    <section className="narrow">
      <div className="panel">
        <h1>Bitte anmelden</h1>
        <p>Dieser Bereich gehoert zu deinem Aviary-Profil.</p>
        <button onClick={() => setPage("login")} type="button">Zum Login</button>
      </div>
    </section>
  );
}

function App() {
  const pageFromRoute = () => {
    const [next] = routeParts();
    return nav.some((item) => item.id === next) || ["login", "support"].includes(next) ? next : "home";
  };
  const [page, setPageState] = useState(pageFromRoute);
  const [user, setUser] = useState(null);
  const [sessionNotice, setSessionNotice] = useState("");

  function setPage(next) {
    setPageState(next.split("/")[0]);
    if (window.location.hash !== `#${next}`) window.history.replaceState(null, "", `/#${next}`);
  }

  useEffect(() => {
    api("/api/auth/me")
      .then((result) => setUser(result.user))
      .catch(() => {
        setToken("");
        setUser(null);
      });
  }, []);

  useEffect(() => {
    if (!user) return undefined;
    let alive = true;
    const touch = () => api("/api/presence", { method: "POST", body: "{}" }).then((result) => {
      if (alive && result?.role) setUser((current) => current?.username === user.username ? { ...current, role: result.role } : current);
    }).catch(() => {});
    touch();
    const interval = window.setInterval(() => {
      if (alive) touch();
    }, 15000);
    return () => {
      alive = false;
      window.clearInterval(interval);
    };
  }, [user?.username]);

  useEffect(() => {
    function syncPage() { setPageState(pageFromRoute()); }
    window.addEventListener("hashchange", syncPage);
    window.addEventListener("popstate", syncPage);
    return () => {
      window.removeEventListener("hashchange", syncPage);
      window.removeEventListener("popstate", syncPage);
    };
  }, []);

  useEffect(() => {
    function syncWallet(event) {
      setUser((current) => current?.username === event.detail.username ? { ...current, ...event.detail.wallet } : current);
    }
    window.addEventListener("aviary-wallet", syncWallet);
    return () => window.removeEventListener("aviary-wallet", syncWallet);
  }, []);

  useEffect(() => {
    function endSession(event) {
      setUser(null); setSessionNotice(event.detail.message); setPage("login");
    }
    window.addEventListener("aviary-session-ended", endSession);
    return () => window.removeEventListener("aviary-session-ended", endSession);
  }, []);

  const content = useMemo(() => {
    if (page === "home") return <HomePage user={user} setPage={setPage} />;
    if (page === "login") return <LoginPage onLogin={(nextUser) => { setSessionNotice(""); setUser(nextUser); setPage("home"); }} />;
    if (page === "news") return <ListPage title="News" path="/api/news" render={(item) => <article className="card" key={item.id}><h3>{item.title}</h3><p>{item.body}</p></article>} />;
    if (page === "members") return <MembersPage user={user} setPage={setPage} />;
    if (page === "chat") return <ChatPage user={user} setPage={setPage} />;
    if (page === "profile") return <ProfilePage user={user} setUser={setUser} setPage={setPage} />;
    if (page === "shop") return <ShopPage user={user} setPage={setPage} />;
    if (page === "leaderboard") return <LeaderboardPage />;
    if (page === "events") return <EventsPage user={user} setPage={setPage} />;
    if (page === "games") return <GamesPage user={user} />;
    if (page === "systematics") return <SystematicsPage />;
    if (page === "gallery") return <GalleryPage user={user} setPage={setPage} />;
    if (page === "admin") return <AdminPage />;
    return <SupportPage user={user} />;
  }, [page, user]);

  return (
    <AppShell nav={nav} page={page} setPage={setPage} user={user} onLogout={() => { api("/api/presence", { method: "DELETE" }).catch(() => {}).finally(() => { setToken(""); setUser(null); setPage("home"); }); }}>
      {sessionNotice && <p className="notice" role="alert">{sessionNotice}</p>}
      {content}
    </AppShell>
  );
}

createRoot(document.getElementById("root")).render(<App />);
