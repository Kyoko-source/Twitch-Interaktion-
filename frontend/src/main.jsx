import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  CalendarDays,
  Check,
  Crown,
  Gamepad2,
  GitBranch,
  Home,
  Image as ImageIcon,
  Link2,
  LogIn,
  LogOut,
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
import { api, setToken } from "./api";
import "./styles.css";

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
  "chicken-jump": { title: "Chicken Jump", accent: "#ffcf8a", text: "Spring ueber Zaeune, ducke dich unter Voegel und sammle Pepples." },
  "chicken-snake": { title: "Chicken Snake", accent: "#7af4dc", text: "Fuehre die Neon-Spur durch den Kaefig und friss Energiekerne." },
  "chicken-flipper": { title: "Chicken Flipper", accent: "#ff6fb7", text: "Neon-Flipper mit Jackpot, Multiball, Streaks und viel zu viel Arcade-Energie." },
  "braincell-survivor": { title: "Pepple Survivor", accent: "#ff6fb7", text: "Weiche Schwarmdrohnen aus und sammle so lange wie moeglich Pepples." },
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

function Shell({ page, setPage, user, onLogout, children }) {
  return (
    <>
      <header className="topbar">
        <button className="brand" onClick={() => setPage("home")} type="button">
          <Crown size={22} />
          <span>Aviary</span>
        </button>
        <div className="topCounters">
          <div><ShoppingBasket size={17} /><strong>{user?.chickens ?? "4.374"}</strong><span>Chickens</span></div>
          <div><Sparkles size={17} /><strong>{user?.braincells ?? "3.612"}</strong><span>Pepples</span></div>
        </div>
        <div className="account">
          <span>{user ? `Eingeloggt als ${user.username}` : "Nicht eingeloggt"}</span>
          {user && <RoleBadge user={user} />}
          {user ? (
            <button className="iconButton" onClick={onLogout} title="Logout" type="button">
              <LogOut size={18} />
            </button>
          ) : (
            <button className="iconButton" onClick={() => setPage("login")} title="Login" type="button">
              <LogIn size={18} />
            </button>
          )}
        </div>
      </header>
      <div className="appFrame">
        <aside className="sideRail">
          <div className="sideGroup">
            <span>Uebersicht</span>
            <SideButton item={nav[0]} page={page} setPage={setPage} />
          </div>
          <div className="sideGroup">
            <span>Community</span>
            {nav.slice(1, 10).map((item) => <SideButton item={item} page={page} setPage={setPage} key={item.id} />)}
          </div>
          <div className="sideGroup">
            <span>Account</span>
            {nav.slice(10, 12).map((item) => <SideButton item={item} page={page} setPage={setPage} key={item.id} />)}
          </div>
          <div className="dailyBox">
            <Star size={20} />
            <strong>Taegliche Belohnung</strong>
            <span>Hol dir deinen Schub im Profil.</span>
            <button onClick={() => setPage("profile")} type="button">Oeffnen</button>
          </div>
        </aside>
        <main>{children}</main>
      </div>
    </>
  );
}

function SideButton({ item, page, setPage }) {
  const Icon = item.icon;
  return (
    <button className={page === item.id ? "active" : ""} onClick={() => setPage(item.id)} type="button">
      <Icon size={17} />
      <span>{item.label}</span>
    </button>
  );
}

function CageMark() {
  return (
    <div className="birdcageScene" aria-hidden="true">
      <div className="cageHalo" />
      <div className="birdcage">
        <span className="cageHook" />
        <span className="cageDome" />
        <span className="cageBase" />
        <span className="cageBar bar1" />
        <span className="cageBar bar2" />
        <span className="cageBar bar3" />
        <span className="cageBar bar4" />
        <span className="cageBar bar5" />
        <span className="cagePerch" />
        <span className="neonBird">
          <span className="birdBody" />
          <span className="birdWing" />
          <span className="birdTail" />
        </span>
        <span className="cageSpark spark1" />
        <span className="cageSpark spark2" />
        <span className="cageSpark spark3" />
      </div>
      <Sparkles className="sceneSparkle" size={30} />
    </div>
  );
}

function HomePage({ user, setPage }) {
  const { data, loading, error } = useApi("/api/dashboard", { stats: {}, leaderboard: [], active_members: [], news: [], events: [], gallery: [] });
  const topViewer = data.leaderboard[0];
  const podium = data.leaderboard.slice(0, 3);
  const nextNews = data.news[0];
  const activeMembers = data.active_members || [];
  const heroName = user?.username || "Aviary";
  const heroKicker = user ? "Willkommen zurueck" : "Willkommen";
  const heroText = user
    ? "Gemeinsam wachsen, gemeinsam glaenzen. Dein Aviary-Dashboard fuer Games, Rewards und Community-Energie."
    : "Logg dich ein, sammle Chickens, spiel Minispiele und werde Teil der Aviary-Community.";
  const heroLevel = user ? Math.max(1, Math.floor(Number(user.braincells || 0) / 140) + 1) : 1;
  const heroProgress = user ? Math.min(98, Number(user.braincells || 0) % 140) : 8;

  return (
    <section className="homePage">
      <div className="dashboardHero">
        <div className="heroCopy">
          <p className="kicker">{heroKicker}</p>
          <h1>{heroName}</h1>
          {user && <RoleBadge user={user} />}
          <p>{heroText}</p>
          <div className="levelStrip">
            <div><span>{user ? "Level" : "Start"}</span><strong>{heroLevel}</strong></div>
            <div className="levelBar"><span style={{ width: `${heroProgress}%` }} /></div>
            <small>{user ? "Naechster Rang wartet im Kaefiglicht." : "Einloggen schaltet deinen echten Fortschritt frei."}</small>
          </div>
          <div className="actions">
            <button onClick={() => setPage(user ? "profile" : "login")} type="button">{user ? "Profil oeffnen" : "Einloggen"}</button>
            <button className="ghost" onClick={() => setPage("games")} type="button">Minispiele</button>
          </div>
        </div>
        <div className="overviewPanel">
          <p className="kicker">Deine Uebersicht</p>
          <div className="overviewStats">
            <Stat label="Chickens" value={user?.chickens ?? data.stats.chickens} />
            <Stat label="Pepples" value={user?.braincells ?? data.stats.braincells} />
            <Stat label="Mitglieder" value={data.stats.users} />
          </div>
          {nextNews && (
            <button className="newsTicker" onClick={() => setPage("news")} type="button">
              <Newspaper size={16} />
              <span>{nextNews.title}</span>
            </button>
          )}
        </div>
        <CageMark />
      </div>
      {error && <div className="notice error">{error}</div>}
      {loading && <div className="notice">Lade Aviary-Daten...</div>}
      <section className="cockpitGrid">
        <div className="miniGamesPanel">
          <PanelTitle icon={Gamepad2} title="Minispiele" action="Alle Spiele anzeigen" onClick={() => setPage("games")} />
          <div className="homeGameDeck">
            {Object.entries(gameMeta).slice(0, 4).map(([id, meta], index) => (
              <button className="homeGameCard" onClick={() => setPage("games")} type="button" key={id} style={{ "--game-accent": meta.accent }}>
                <span className={`gameArt gameArt${index + 1}`}>
                  <span className="gameOrb" />
                  <span className="gameAvatarMark" />
                </span>
                <strong>{meta.title}</strong>
                <small>Highscore aktiv</small>
              </button>
            ))}
          </div>
        </div>
        <div className="rankPanel">
          <PanelTitle icon={Trophy} title="Top Rangliste" action="Komplette Rangliste" onClick={() => setPage("leaderboard")} />
          <div className="conceptPodium">
            {podium.map((item, index) => (
              <article className={`conceptPodiumItem place${index + 1}`} key={item.username}>
                <Avatar user={item} />
                <span>#{index + 1}</span>
                <strong>{item.username}</strong>
                <small>{item.braincells || 0} Pepples</small>
              </article>
            ))}
          </div>
          <div className="leaderMiniRows">
            {data.leaderboard.slice(3, 8).map((item, index) => <div key={item.username}><span>#{index + 4} {item.username}</span><b>{item.braincells || 0}</b></div>)}
          </div>
        </div>
        <div className="rightColumn">
          <div className="activePanel">
            <PanelTitle icon={Users} title="Aktive Mitglieder" action="Alle Mitglieder" onClick={() => setPage("members")} />
            <div className="activeList">
              {activeMembers.length ? activeMembers.slice(0, 5).map((item) => (
                <div className="activeRow" key={item.username}>
                  <Avatar user={item} />
                  <span><strong>{item.username}</strong><small>{item.status || "Online"}</small></span>
                  <b>{Math.max(1, Math.floor(Number(item.braincells || 0) / 120))}</b>
                </div>
              )) : <div className="activeEmpty">Gerade niemand online</div>}
            </div>
          </div>
          <div className="adminControlTeaser">
            <PanelTitle icon={Shield} title="Admin Kontrollzentrum" />
            <div className="adminTeaserGrid">
              <button onClick={() => setPage("admin")} type="button"><Users size={18} /> Benutzer</button>
              <button onClick={() => setPage("admin")} type="button"><Newspaper size={18} /> News</button>
              <button onClick={() => setPage("admin")} type="button"><CalendarDays size={18} /> Events</button>
              <button onClick={() => setPage("admin")} type="button"><Shield size={18} /> Reports</button>
            </div>
          </div>
        </div>
        <div className="newsPanel">
          <PanelTitle icon={Newspaper} title="Aktuelle Neuigkeiten" action="Alle News" onClick={() => setPage("news")} />
          {nextNews ? <div className="newsFeature"><div /><span><strong>{nextNews.title}</strong><small>{nextNews.body}</small></span></div> : <p>Keine neuen News.</p>}
        </div>
      </section>
    </section>
  );
}

function PanelTitle({ icon: Icon, title, action, onClick }) {
  return (
    <div className="panelTitle">
      <h2><Icon size={18} /> {title}</h2>
      {action && <button className="textButton" onClick={onClick} type="button">{action}</button>}
    </div>
  );
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

  async function claimDaily() {
    try {
      const result = await api("/api/daily-reward", { method: "POST", body: "{}" });
      setMessage(result.message);
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
          <Stat label="Pepples" value={user.braincells} />
          <Stat label="Chickens" value={user.chickens} />
        </div>
      </div>
      <button onClick={claimDaily} type="button">Daily Reward abholen</button>
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
    braincells: acc.braincells + Number(member.braincells || 0),
  }), { chickens: 0, braincells: 0 });

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
          <Stat label="Pepples" value={totals.braincells} />
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
          <strong>{top.braincells || 0} Pepples</strong>
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
              <span>{member.braincells || 0} Pepples</span>
              <span>{member.chickens || 0} Chickens</span>
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
  const maxScore = Math.max(1, ...data.map((item) => Number(item.braincells || 0)));

  return (
    <section className="stack">
      <div className="leaderHero">
        <div>
          <p className="kicker">Rangliste</p>
          <h1>Pepple Circuit</h1>
          <p>Podium, Fortschritt und Chicken-Power in einem ruhigeren, scanbaren Board.</p>
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
              <small>{item.rank_name} · {item.braincells || 0} Pepples</small>
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
            <div className="progressTrack"><span style={{ width: `${Math.max(4, (Number(item.braincells || 0) / maxScore) * 100)}%` }} /></div>
            <b>{item.braincells || 0}</b>
            <small>{item.chickens || 0} Chickens</small>
          </article>
        ))}
      </div>
    </section>
  );
}

function ShopPage({ user, setPage }) {
  const { data, error, loading } = useApi("/api/shop", []);
  const [message, setMessage] = useState("");
  const [cardMessages, setCardMessages] = useState({});
  const [buying, setBuying] = useState("");
  if (!user) return <EmptyLogin setPage={setPage} />;
  async function buy(item) {
    const key = item.id || item.name;
    setBuying(key);
    setCardMessages((current) => ({ ...current, [key]: "Kauf wird verarbeitet..." }));
    try {
      const result = await api("/api/shop/purchase", { method: "POST", body: JSON.stringify({ item_id: item.id }) });
      let nextMessage = result.message;
      if (item.category === "Chat Animation" && item.style) {
        await api("/api/chat/styles", { method: "POST", body: JSON.stringify({ style: item.style }) });
        nextMessage = "Gekauft und direkt im Chat aktiviert.";
      }
      setMessage(nextMessage);
      setCardMessages((current) => ({ ...current, [key]: nextMessage }));
    } catch (err) {
      setMessage(err.message);
      setCardMessages((current) => ({ ...current, [key]: err.message }));
    } finally {
      setBuying("");
    }
  }
  return (
    <section className="stack">
      <div className="sectionHero"><h1>Shop</h1><p>{user.chickens || 0} Chickens verfuegbar.</p></div>
      <div className="notice">Chat-Animationen kaufst du hier und aktivierst sie danach im Reiter Chat.</div>
      {message && <div className="notice">{message}</div>}
      {loading && <div className="notice">Lade Shop...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="grid">
        {data.map((item) => {
          const key = item.id || item.name;
          const busy = buying === key;
          return (
            <article className="card shopCard" key={key}>
              <p className="kicker">{item.category || "Reward"}</p>
              <h3>{item.name}</h3>
              <p>{item.desc || item.description}</p>
              {item.category === "Chat Animation" && <div className={`shopChatPreview ${chatStyleClass(item.style)}`}><span>So sieht dein Chatbalken aus</span></div>}
              <strong>{item.price} Chickens</strong>
              <button onClick={() => buy(item)} disabled={busy} type="button">{busy ? "Kaufe..." : "Kaufen"}</button>
              {cardMessages[key] && <div className={`shopCardMessage ${cardMessages[key].includes("Nicht genug") || cardMessages[key].includes("fehlgeschlagen") ? "error" : ""}`}>{cardMessages[key]}</div>}
            </article>
          );
        })}
      </div>
    </section>
  );
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

function Scoreboard({ game, refreshKey }) {
  const { data } = useApi(`/api/scores/${game}`, [], refreshKey);
  const best = new Map();
  data.forEach((score) => {
    const name = String(score.username || "").trim();
    if (!name) return;
    const old = best.get(name.toLowerCase());
    if (!old || Number(score.score || 0) > Number(old.score || 0)) best.set(name.toLowerCase(), score);
  });
  const rows = Array.from(best.values()).sort((a, b) => Number(b.score || 0) - Number(a.score || 0)).slice(0, 8);
  return (
    <ol className="gameScores">
      {rows.length ? rows.map((score, index) => (
        <li key={`${score.username}-${index}`}><span>#{index + 1} {score.username}</span><b>{score.score || 0}</b></li>
      )) : <li><span>Noch frei</span><b>0</b></li>}
    </ol>
  );
}

function useCanvasGame(draw, deps, onError) {
  const canvasRef = useRef(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return undefined;
    const ctx = canvas.getContext("2d");
    let frame = 0;
    let last = performance.now();
    let alive = true;
    function loop(now) {
      if (!alive) return;
      const dt = Math.min(40, now - last);
      last = now;
      try {
        draw(ctx, canvas, dt, frame++);
      } catch (err) {
        alive = false;
        if (onError) onError(err);
        else console.error(err);
        return;
      }
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
    return () => {
      alive = false;
    };
  }, deps);
  return canvasRef;
}

const survivorSettingsKey = "pepple-survivor-settings-v1";
const defaultSurvivorSettings = { audioOn: true, volume: 0.75, controlMode: "wasd" };

function readSurvivorSettings() {
  if (typeof window === "undefined") return defaultSurvivorSettings;
  try {
    const saved = JSON.parse(window.localStorage.getItem(survivorSettingsKey) || "{}");
    const volume = Number.isFinite(Number(saved.volume)) ? Math.min(1, Math.max(0, Number(saved.volume))) : defaultSurvivorSettings.volume;
    return {
      audioOn: typeof saved.audioOn === "boolean" ? saved.audioOn : defaultSurvivorSettings.audioOn,
      volume,
      controlMode: saved.controlMode === "arrows" ? "arrows" : "wasd",
    };
  } catch {
    return defaultSurvivorSettings;
  }
}

function writeSurvivorSettings(settings) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(survivorSettingsKey, JSON.stringify(settings));
  } catch {
    // Local storage can be blocked in private or hardened browsers.
  }
}

function ChickenJump({ user }) {
  const [status, setStatus] = useState("menu");
  const [message, setMessage] = useState("Springe ueber Zaeune, ducke dich unter Voegel und sammle Pepples.");
  const [snapshot, setSnapshot] = useState({ score: 0, level: 1, combo: 1, pepples: 0 });
  const [refreshKey, setRefreshKey] = useState(0);
  const keysRef = useRef({});
  const audioRef = useRef(null);
  const jumpArtRef = useRef(null);
  const stateRef = useRef({
    player: { x: 132, y: 318, vy: 0, duck: false, inv: 0, squash: 0, run: 0, lean: 0 },
    obstacles: [],
    gems: [],
    particles: [],
    score: 0,
    level: 1,
    combo: 1,
    pepples: 0,
    distance: 0,
    speed: 5.2,
    spawn: 760,
    gemSpawn: 900,
    shake: 0,
    over: false,
  });

  function tone(freq, duration = 0.08, type = "sine", gain = 0.035) {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      if (!audioRef.current) audioRef.current = new AudioCtx();
      const ctx = audioRef.current;
      const osc = ctx.createOscillator();
      const amp = ctx.createGain();
      osc.frequency.value = freq;
      osc.type = type;
      amp.gain.setValueAtTime(gain, ctx.currentTime);
      amp.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
      osc.connect(amp);
      amp.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + duration);
    } catch {
      // Audio is optional.
    }
  }

  useEffect(() => {
    const art = new Image();
    art.src = "/assets/chicken-jump-ai-v1.png?v=1";
    jumpArtRef.current = art;
  }, []);

  function jump(state) {
    const player = state.player;
    if (player.y >= 316) {
      player.vy = -15.8;
      player.squash = 1;
      state.particles.push(...Array.from({ length: 8 }, () => ({
        x: player.x - 24,
        y: 352,
        vx: -2 - Math.random() * 2,
        vy: -1.5 + Math.random() * 2.2,
        life: 360,
        ttl: 360,
        color: Math.random() > 0.5 ? "#ffcf8a" : "#ff6fb7",
      })));
      tone(620, 0.055, "triangle", 0.035);
      tone(920, 0.045, "sine", 0.022);
    }
  }

  function drawCuteChicken(ctx, player, frame) {
    const ducking = player.duck && player.y >= 312;
    const airborne = player.y < 312;
    const run = player.run || frame / 6;
    const wing = Math.sin(run * 1.6) * (ducking ? 1.8 : 4.8);
    const legA = Math.sin(run) * 9;
    const legB = Math.sin(run + Math.PI) * 9;
    const lean = ducking ? -0.18 : airborne ? 0.12 : Math.max(-0.12, Math.min(0.12, player.lean || 0));
    ctx.save();
    ctx.translate(player.x, player.y);
    ctx.rotate(lean);
    ctx.scale(1 + player.squash * 0.12, ducking ? 0.74 - player.squash * 0.05 : 1 - player.squash * 0.08);

    ctx.save();
    ctx.globalAlpha = 0.35;
    ctx.fillStyle = "#08040b";
    ctx.beginPath();
    ctx.ellipse(0, 17, ducking ? 48 : 38, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    const art = jumpArtRef.current;
    if (art?.complete && art.naturalWidth) {
      const crop = ducking
        ? [705, 18, 365, 276]
        : airborne
          ? [388, 18, 345, 304]
          : [10, 16, 350, 304];
      const drawW = ducking ? 128 : 118;
      const drawH = ducking ? 96 : 116;
      ctx.shadowColor = "rgba(255,207,138,.78)";
      ctx.shadowBlur = 22;
      ctx.drawImage(art, crop[0], crop[1], crop[2], crop[3], -drawW / 2, ducking ? -87 : -116, drawW, drawH);
      ctx.restore();
      return;
    }

    const body = ctx.createRadialGradient(4, -48, 8, -7, -32, 52);
    body.addColorStop(0, "#fff7dc");
    body.addColorStop(0.42, "#ffd178");
    body.addColorStop(0.78, "#e49a42");
    body.addColorStop(1, "#a95f2c");
    ctx.shadowColor = "rgba(255,207,138,.86)";
    ctx.shadowBlur = 24;
    ctx.fillStyle = body;
    ctx.beginPath();
    ctx.ellipse(ducking ? -2 : -8, ducking ? -30 : -36, ducking ? 47 : 39, ducking ? 25 : 34, ducking ? -0.06 : -0.02, 0, Math.PI * 2);
    ctx.fill();

    ctx.shadowBlur = 0;
    ctx.fillStyle = "rgba(255,255,255,.55)";
    ctx.beginPath();
    ctx.ellipse(ducking ? 10 : 5, ducking ? -31 : -33, ducking ? 27 : 24, ducking ? 16 : 21, 0.08, 0, Math.PI * 2);
    ctx.fill();

    const wingGradient = ctx.createLinearGradient(-32, -55, -3, -13);
    wingGradient.addColorStop(0, "#fff1bc");
    wingGradient.addColorStop(1, "#d98332");
    ctx.fillStyle = wingGradient;
    ctx.beginPath();
    ctx.ellipse(-25, -31 + wing, ducking ? 17 : 15, ducking ? 15 : 23, 0.42, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(128,72,36,.35)";
    ctx.lineWidth = 1.6;
    for (let i = 0; i < 4; i += 1) {
      ctx.beginPath();
      ctx.moveTo(-31 + i * 6, -42 + wing);
      ctx.quadraticCurveTo(-23 + i * 4, -29 + wing, -19 + i * 3, -14 + wing);
      ctx.stroke();
    }

    const head = ctx.createRadialGradient(24, -72, 4, 21, -67, 30);
    head.addColorStop(0, "#fff8df");
    head.addColorStop(0.6, "#ffe1a0");
    head.addColorStop(1, "#d9913b");
    ctx.fillStyle = head;
    ctx.beginPath();
    ctx.arc(ducking ? 29 : 21, ducking ? -55 : -68, ducking ? 22 : 25, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#ff5b7c";
    ctx.beginPath();
    ctx.arc(ducking ? 20 : 12, ducking ? -77 : -93, 6, 0, Math.PI * 2);
    ctx.arc(ducking ? 29 : 22, ducking ? -82 : -98, 7, 0, Math.PI * 2);
    ctx.arc(ducking ? 38 : 32, ducking ? -77 : -93, 6, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "rgba(109,61,34,.38)";
    ctx.beginPath();
    ctx.ellipse(ducking ? 4 : -12, ducking ? -51 : -63, 8, 4, -0.55, 0, Math.PI * 2);
    ctx.ellipse(ducking ? 13 : -3, ducking ? -57 : -70, 7, 3, -0.35, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#1b1020";
    ctx.beginPath();
    ctx.arc(ducking ? 23 : 15, ducking ? -58 : -71, 3.8, 0, Math.PI * 2);
    ctx.arc(ducking ? 37 : 31, ducking ? -58 : -71, 3.8, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.beginPath();
    ctx.arc(ducking ? 24 : 16, ducking ? -59 : -72, 1.3, 0, Math.PI * 2);
    ctx.arc(ducking ? 38 : 32, ducking ? -59 : -72, 1.3, 0, Math.PI * 2);
    ctx.fill();

    const beak = ctx.createLinearGradient(39, -65, 61, -54);
    beak.addColorStop(0, "#ffe66d");
    beak.addColorStop(1, "#ff8b1f");
    ctx.fillStyle = beak;
    ctx.beginPath();
    ctx.moveTo(ducking ? 47 : 40, ducking ? -54 : -63);
    ctx.lineTo(ducking ? 65 : 60, ducking ? -49 : -57);
    ctx.lineTo(ducking ? 47 : 40, ducking ? -43 : -51);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = "#ff9f1c";
    ctx.lineWidth = 4.4;
    const legY = ducking ? -6 : -3;
    [
      [-13, legA],
      [17, legB],
    ].forEach(([baseX, stride], index) => {
      ctx.beginPath();
      ctx.moveTo(baseX, legY);
      ctx.lineTo(baseX + stride * 0.25, 10);
      ctx.lineTo(baseX + stride * 0.48, 16);
      ctx.stroke();
      ctx.fillStyle = "#ff9f1c";
      ctx.beginPath();
      ctx.ellipse(baseX + stride * 0.48 + (index ? 5 : -5), 16, 13, 3.5, index ? 0.08 : -0.08, 0, Math.PI * 2);
      ctx.fill();
    });

    ctx.fillStyle = "rgba(255,244,233,.36)";
    for (let i = 0; i < 10; i += 1) {
      ctx.beginPath();
      ctx.ellipse(-23 + i * 6, -42 + Math.sin(i + frame / 18) * 2, 2.1, 4.5, 0.4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawFence(ctx, ob, ground) {
    const top = ground - ob.h;
    const railY = top + ob.h * 0.42;
    ctx.save();
    const art = jumpArtRef.current;
    if (art?.complete && art.naturalWidth) {
      const crops = [
        [36, 344, 288, 216],
        [378, 326, 322, 240],
        [704, 342, 310, 238],
        [1038, 318, 248, 264],
      ];
      const crop = crops[ob.variant || 0] || crops[0];
      ctx.shadowColor = "rgba(255,207,138,.58)";
      ctx.shadowBlur = 18;
      ctx.drawImage(art, crop[0], crop[1], crop[2], crop[3], ob.x - 14, top - 20, ob.w + 28, ob.h + 42);
      ctx.restore();
      return;
    }
    ctx.shadowColor = "rgba(255,207,138,.72)";
    ctx.shadowBlur = 16;
    const wood = ctx.createLinearGradient(ob.x, top, ob.x + ob.w, ground);
    wood.addColorStop(0, "#f0b36a");
    wood.addColorStop(0.42, "#a96435");
    wood.addColorStop(1, "#5a2f20");
    ctx.strokeStyle = "rgba(255,231,166,.74)";
    ctx.lineWidth = 1.6;
    for (let x = ob.x; x < ob.x + ob.w; x += 18) {
      ctx.fillStyle = wood;
      ctx.beginPath();
      ctx.roundRect(x, top, 10, ob.h, 3);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#f5c17a";
      ctx.beginPath();
      ctx.moveTo(x - 1, top);
      ctx.lineTo(x + 5, top - 10);
      ctx.lineTo(x + 11, top);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = "rgba(53,25,17,.36)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x + 3, top + 9);
      ctx.lineTo(x + 4 + Math.sin(x) * 2, ground - 5);
      ctx.moveTo(x + 7, top + 17);
      ctx.lineTo(x + 6 + Math.cos(x) * 2, ground - 10);
      ctx.stroke();
      ctx.strokeStyle = "rgba(255,231,166,.74)";
      ctx.lineWidth = 1.6;
    }
    ctx.fillStyle = "rgba(25,10,8,.22)";
    ctx.beginPath();
    ctx.ellipse(ob.x + ob.w / 2, ground + 8, ob.w * 0.62, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#8d512c";
    [railY, railY + 27].forEach((y) => {
      ctx.beginPath();
      ctx.roundRect(ob.x - 10, y, ob.w + 20, 11, 3);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "rgba(255,231,166,.18)";
      ctx.fillRect(ob.x - 7, y + 2, ob.w + 14, 2);
      ctx.fillStyle = "#8d512c";
    });
    ctx.restore();
  }

  function drawBird(ctx, ob, frame) {
    const pulse = Math.sin(frame / 7 + ob.x * 0.02) * 4;
    const y = ob.y + pulse;
    ctx.save();
    ctx.translate(ob.x + ob.w / 2, y + ob.h / 2);
    ctx.rotate(Math.sin(frame / 15 + ob.x) * 0.06);
    const art = jumpArtRef.current;
    if (art?.complete && art.naturalWidth) {
      const crops = [
        [38, 700, 260, 118],
        [330, 680, 288, 132],
        [642, 670, 282, 140],
        [930, 688, 282, 132],
      ];
      const crop = crops[ob.variant || 0] || crops[0];
      ctx.shadowColor = "rgba(122,244,220,.56)";
      ctx.shadowBlur = 18;
      ctx.drawImage(art, crop[0], crop[1], crop[2], crop[3], -ob.w / 2 - 18, -ob.h / 2 - 24, ob.w + 42, ob.h + 46);
      ctx.restore();
      return;
    }
    ctx.shadowColor = "rgba(122,244,220,.75)";
    ctx.shadowBlur = 20;
    const body = ctx.createLinearGradient(-22, -12, 28, 16);
    body.addColorStop(0, "#d8fff7");
    body.addColorStop(0.48, "#65d8c8");
    body.addColorStop(1, "#28536a");
    ctx.fillStyle = body;
    ctx.beginPath();
    ctx.ellipse(0, 0, 30, 16, -0.04, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#d8fff7";
    ctx.beginPath();
    ctx.arc(25, -5, 13, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ffcf8a";
    ctx.beginPath();
    ctx.moveTo(36, -4);
    ctx.lineTo(50, 1);
    ctx.lineTo(36, 6);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#1b1020";
    ctx.beginPath();
    ctx.arc(25, -7, 2.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#ff6fb7";
    ctx.lineWidth = 5.5;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(-3, 1);
    ctx.quadraticCurveTo(-27, -31 - pulse, -49, -3);
    ctx.moveTo(-6, 4);
    ctx.quadraticCurveTo(-24, 34 + pulse, -43, 8);
    ctx.stroke();
    ctx.strokeStyle = "rgba(255,244,233,.54)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-7, -3);
    ctx.quadraticCurveTo(-29, -21 - pulse, -42, -4);
    ctx.stroke();
    ctx.fillStyle = "#28536a";
    ctx.beginPath();
    ctx.moveTo(-27, -2);
    ctx.lineTo(-47, -12);
    ctx.lineTo(-41, 8);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  useEffect(() => {
    function down(event) {
      const key = event.key.toLowerCase();
      if ([" ", "arrowup", "w", "arrowdown", "s"].includes(key) || event.code === "Space") event.preventDefault();
      keysRef.current[key] = true;
      if (event.code === "Space" || key === "arrowup" || key === "w") {
        event.preventDefault();
        if (status === "menu" || status === "gameover") start();
        else if (status === "play") jump(stateRef.current);
      }
    }
    function up(event) {
      keysRef.current[event.key.toLowerCase()] = false;
    }
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
    };
  }, [status]);

  const canvasRef = useCanvasGame((ctx, canvas, dt, frame) => {
    const state = stateRef.current;
    const player = state.player;
    const ground = 354;
    const playing = status === "play" && !state.over;
    const scale = dt / 16;
    const bg = ctx.createLinearGradient(0, 0, 0, canvas.height);
    bg.addColorStop(0, "#21112c");
    bg.addColorStop(0.45, "#53314a");
    bg.addColorStop(0.74, "#2f4635");
    bg.addColorStop(1, "#132016");
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    const shake = state.shake > 0 ? Math.sin(frame * 1.7) * state.shake : 0;
    state.shake = Math.max(0, state.shake - dt * 0.025);
    ctx.save();
    ctx.translate(shake, 0);
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    const jumpArt = jumpArtRef.current;
    if (jumpArt?.complete && jumpArt.naturalWidth) {
      const bgScroll = (state.distance * 0.18) % canvas.width;
      ctx.save();
      ctx.globalAlpha = 0.72;
      ctx.drawImage(jumpArt, 42, 880, 1248, 254, -bgScroll, 126, canvas.width, 190);
      ctx.drawImage(jumpArt, 42, 880, 1248, 254, canvas.width - bgScroll, 126, canvas.width, 190);
      ctx.restore();
    }

    ctx.globalAlpha = 0.72;
    for (let i = 0; i < 80; i += 1) {
      const x = (i * 127 - state.distance * (0.18 + (i % 5) * 0.04)) % (canvas.width + 120);
      const y = 28 + ((i * 73) % 250);
      ctx.fillStyle = i % 9 === 0 ? "#ffcf8a" : i % 4 === 0 ? "#ff6fb7" : "#7af4dc";
      ctx.fillRect(x < -20 ? x + canvas.width + 120 : x, y, i % 6 === 0 ? 3 : 2, i % 6 === 0 ? 3 : 2);
    }
    ctx.globalAlpha = 1;

    ctx.save();
    for (let layer = 0; layer < 3; layer += 1) {
      const offset = (state.distance * (0.12 + layer * 0.08)) % 360;
      ctx.fillStyle = layer === 0 ? "rgba(25,18,38,.42)" : layer === 1 ? "rgba(62,41,54,.34)" : "rgba(22,45,37,.44)";
      ctx.beginPath();
      ctx.moveTo(-80 - offset, ground - 108 + layer * 26);
      for (let x = -80 - offset; x < canvas.width + 460; x += 180) {
        const peak = ground - (138 - layer * 24) - ((x / 180 + layer) % 2) * 34;
        ctx.lineTo(x + 90, peak);
        ctx.lineTo(x + 180, ground - 110 + layer * 28);
      }
      ctx.lineTo(canvas.width + 80, ground + 4);
      ctx.lineTo(-80, ground + 4);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();

    ctx.fillStyle = "rgba(255,207,138,.16)";
    ctx.beginPath();
    ctx.arc(770, 78, 48, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(255,244,233,.09)";
    for (let i = 0; i < 7; i += 1) {
      const cloudX = (i * 190 - state.distance * 0.23) % (canvas.width + 220) - 110;
      const cloudY = 74 + (i % 4) * 27;
      ctx.beginPath();
      ctx.ellipse(cloudX, cloudY, 42, 10, 0, 0, Math.PI * 2);
      ctx.ellipse(cloudX + 32, cloudY + 3, 38, 12, 0, 0, Math.PI * 2);
      ctx.ellipse(cloudX - 31, cloudY + 5, 30, 9, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.strokeStyle = "rgba(255,207,138,.16)";
    ctx.lineWidth = 2;
    for (let x = -80 + (state.distance * 0.55) % 80; x < canvas.width + 120; x += 80) {
      ctx.beginPath();
      ctx.moveTo(x, 120);
      ctx.lineTo(x + 65, ground + 54);
      ctx.stroke();
    }
    for (let x = -120 + (state.distance * 1.2) % 120; x < canvas.width + 160; x += 120) {
      ctx.strokeStyle = "rgba(122,244,220,.16)";
      ctx.beginPath();
      ctx.moveTo(x, ground);
      ctx.lineTo(x + 60, canvas.height);
      ctx.stroke();
    }

    const soil = ctx.createLinearGradient(0, ground - 18, 0, canvas.height);
    soil.addColorStop(0, "#6da95e");
    soil.addColorStop(0.18, "#426638");
    soil.addColorStop(0.36, "#725138");
    soil.addColorStop(1, "#2a1712");
    ctx.fillStyle = soil;
    ctx.fillRect(0, ground - 8, canvas.width, canvas.height - ground + 8);
    ctx.fillStyle = "rgba(122,244,220,.24)";
    ctx.fillRect(0, ground - 7, canvas.width, 3);
    ctx.fillStyle = "rgba(255,207,138,.26)";
    for (let x = -40 + (state.distance * 1.35) % 42; x < canvas.width; x += 42) {
      ctx.fillRect(x, ground + 22, 18, 3);
    }
    ctx.strokeStyle = "rgba(255,244,233,.20)";
    ctx.lineWidth = 1;
    for (let x = -20 + (state.distance * 1.9) % 24; x < canvas.width; x += 24) {
      const blade = 7 + (x % 5);
      ctx.beginPath();
      ctx.moveTo(x, ground - 3);
      ctx.quadraticCurveTo(x + 3, ground - blade, x + 8, ground - 2);
      ctx.stroke();
    }

    if (playing) {
      state.distance += state.speed * scale;
      state.speed = Math.min(12.5, 6.2 + state.distance / 1450);
      state.level = 1 + Math.floor(state.distance / 650);
      player.duck = Boolean(keysRef.current.arrowdown || keysRef.current.s);
      player.run += player.y >= 316 ? state.speed * 0.075 * scale : 0.055 * scale;
      player.lean += ((player.duck ? -0.18 : player.vy < -1 ? -0.08 : player.vy > 3 ? 0.12 : Math.sin(player.run) * 0.045) - player.lean) * 0.16;
      player.vy += 0.78 * scale;
      player.y = Math.min(318, player.y + player.vy * scale);
      if (player.y >= 318) player.vy = Math.min(0, player.vy);
      player.inv = Math.max(0, player.inv - dt);
      player.squash = Math.max(0, player.squash - dt * 0.006);

      state.spawn -= dt;
      if (state.spawn <= 0) {
        const roll = Math.random();
        const type = roll > 0.70 && state.level > 1 ? "bird" : roll > 0.50 && state.level > 3 ? "double" : "fence";
        if (type === "double") {
          state.obstacles.push({ type: "fence", x: canvas.width + 40, w: 66, h: 62 + Math.random() * 22, variant: Math.floor(Math.random() * 4), scored: false });
          state.obstacles.push({ type: "bird", x: canvas.width + 205, w: 82, h: 44, y: 217 + Math.random() * 17, variant: Math.floor(Math.random() * 4), scored: false });
        } else {
          state.obstacles.push({
            type,
            x: canvas.width + 44,
            w: type === "bird" ? 80 : 62 + Math.random() * 34,
            h: type === "bird" ? 44 : 58 + Math.random() * 36,
            y: type === "bird" ? 216 + Math.random() * 22 : 0,
            variant: type === "bird" ? Math.floor(Math.random() * 4) : Math.floor(Math.random() * 4),
            scored: false,
          });
        }
        state.spawn = Math.max(660, 1380 - state.level * 34 - Math.random() * 170);
      }
      state.gemSpawn -= dt;
      if (state.gemSpawn <= 0) {
        const baseY = 184 + Math.random() * 90;
        for (let i = 0; i < 5; i += 1) state.gems.push({ x: canvas.width + 60 + i * 38, y: baseY + Math.sin(i) * 28, spin: Math.random() * 8, taken: false });
        state.gemSpawn = 1350 + Math.random() * 900;
      }

      state.obstacles.forEach((ob) => { ob.x -= state.speed * scale; });
      state.gems.forEach((gem) => { gem.x -= state.speed * scale; gem.spin += 0.1 * scale; });
      state.particles.forEach((particle) => {
        particle.x += particle.vx * scale;
        particle.y += particle.vy * scale;
        particle.vy += 0.05 * scale;
        particle.life -= dt;
      });

      const hitBox = player.duck && player.y >= 312
        ? { x: player.x - 36, y: player.y - 45, w: 76, h: 43 }
        : { x: player.x - 30, y: player.y - 88, w: 62, h: 82 };

      state.gems.forEach((gem) => {
        if (!gem.taken && Math.hypot(gem.x - player.x, gem.y - (player.y - 42)) < 42) {
          gem.taken = true;
          state.pepples += 1;
          state.score += 2 * state.combo;
          state.combo = Math.min(9, state.combo + 0.25);
          tone(1040 + state.combo * 45, 0.045, "triangle", 0.018);
          state.particles.push(...Array.from({ length: 7 }, () => ({ x: gem.x, y: gem.y, vx: (Math.random() - 0.5) * 3.2, vy: (Math.random() - 0.5) * 3.2, life: 340, ttl: 340, color: "#7af4dc" })));
        }
      });

      state.obstacles = state.obstacles.filter((ob) => {
        if (!ob.scored && ob.x + ob.w < player.x - 34) {
          ob.scored = true;
          state.score += Math.round(8 * state.combo);
          state.combo = Math.min(9, state.combo + 0.15);
          tone(720, 0.035, "square", 0.018);
        }
        return ob.x > -120;
      });
      state.gems = state.gems.filter((gem) => gem.x > -50 && !gem.taken);
      state.particles = state.particles.filter((particle) => particle.life > 0).slice(-160);

      const hit = state.obstacles.some((ob) => {
        const obBox = ob.type === "bird"
          ? { x: ob.x + 10, y: ob.y + 8, w: ob.w - 18, h: ob.h - 12 }
          : { x: ob.x + 3, y: ground - ob.h - 7, w: ob.w - 2, h: ob.h + 7 };
        return hitBox.x < obBox.x + obBox.w && hitBox.x + hitBox.w > obBox.x && hitBox.y < obBox.y + obBox.h && hitBox.y + hitBox.h > obBox.y;
      });
      if (hit && player.inv <= 0) {
        state.over = true;
        state.shake = 14;
        setStatus("gameover");
        setSnapshot({ score: state.score, level: state.level, combo: state.combo.toFixed(1), pepples: state.pepples });
        setMessage(`Run beendet: ${state.score} Punkte, ${state.pepples} Pepples, Level ${state.level}`);
        tone(130, 0.2, "sawtooth", 0.055);
        tone(82, 0.26, "square", 0.035);
      }
      if (frame % 6 === 0) setSnapshot({ score: state.score, level: state.level, combo: state.combo.toFixed(1), pepples: state.pepples });
    } else {
      state.particles.forEach((particle) => {
        particle.x += particle.vx * scale;
        particle.y += particle.vy * scale;
        particle.life -= dt;
      });
      state.particles = state.particles.filter((particle) => particle.life > 0).slice(-160);
    }

    state.gems.forEach((gem) => {
      const r = 9 + Math.sin(gem.spin) * 2;
      ctx.save();
      ctx.translate(gem.x, gem.y);
      ctx.rotate(gem.spin);
      ctx.fillStyle = "#7af4dc";
      ctx.shadowColor = "#7af4dc";
      ctx.shadowBlur = 16;
      ctx.beginPath();
      ctx.moveTo(0, -r);
      ctx.lineTo(r, 0);
      ctx.lineTo(0, r);
      ctx.lineTo(-r, 0);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    });

    state.obstacles.forEach((ob) => {
      if (ob.type === "bird") {
        drawBird(ctx, ob, frame);
      } else {
        drawFence(ctx, ob, ground);
      }
    });

    state.particles.forEach((particle) => {
      ctx.globalAlpha = Math.max(0, particle.life / particle.ttl);
      ctx.fillStyle = particle.color;
      ctx.beginPath();
      ctx.arc(particle.x, particle.y, 3.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
    });

    drawCuteChicken(ctx, player, frame);
    ctx.shadowBlur = 0;

    ctx.fillStyle = "rgba(10,6,14,.72)";
    ctx.fillRect(18, 16, 338, 86);
    ctx.strokeStyle = "rgba(255,207,138,.22)";
    ctx.strokeRect(18, 16, 338, 86);
    ctx.fillStyle = "#fff4e9";
    ctx.font = "900 24px Inter, Arial";
    ctx.fillText(`Score ${state.score}`, 34, 48);
    ctx.fillStyle = "#ffcf8a";
    ctx.font = "800 15px Inter, Arial";
    ctx.fillText(`Level ${state.level}   Combo x${Number(state.combo).toFixed(1)}   Pepples ${state.pepples}`, 34, 78);

    if (status === "menu" || status === "gameover") {
      ctx.fillStyle = "rgba(10,6,14,.72)";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = "#fff4e9";
      ctx.font = "950 54px Inter, Arial";
      ctx.fillText(status === "gameover" ? "Run beendet" : "Chicken Jump", 300, 174);
      ctx.fillStyle = "#ffcf8a";
      ctx.font = "900 18px Inter, Arial";
      ctx.fillText(status === "gameover" ? "Leertaste fuer Revanche" : "Leertaste / Klick zum Starten", 332, 216);
      ctx.fillStyle = "#d8deed";
      ctx.font = "700 15px Inter, Arial";
      ctx.fillText("Springen: Space / W / Pfeil hoch    Ducken: S / Pfeil runter", 250, 250);
    }
    ctx.restore();
  }, [status]);

  function start() {
    stateRef.current = {
      player: { x: 132, y: 318, vy: 0, duck: false, inv: 0, squash: 0, run: 0, lean: 0 },
      obstacles: [],
      gems: [],
      particles: [],
      score: 0,
      level: 1,
      combo: 1,
      pepples: 0,
      distance: 0,
      speed: 5.2,
      spawn: 760,
      gemSpawn: 760,
      shake: 0,
      over: false,
    };
    setSnapshot({ score: 0, level: 1, combo: 1, pepples: 0 });
    setMessage("Space/W/Pfeil hoch springt. S/Pfeil runter duckt unter Voegel.");
    setStatus("play");
    tone(420, 0.07, "triangle", 0.04);
  }

  async function save() {
    try {
      await api("/api/scores", { method: "POST", body: JSON.stringify({ game: "chicken-jump", score: snapshot.score, level: snapshot.level }) });
      setMessage("Score gespeichert.");
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  return (
    <section className="gameFrame jumpFrame" style={{ "--game-accent": gameMeta["chicken-jump"].accent }}>
      <GameHeader meta={gameMeta["chicken-jump"]} message={message} score={snapshot.score} level={snapshot.level} />
      <div className="jumpHud">
        <span>Combo <b>x{snapshot.combo}</b></span>
        <span>Pepples <b>{snapshot.pepples}</b></span>
        <span>Tempo <b>{stateRef.current.speed.toFixed(1)}</b></span>
      </div>
      <canvas className="gameCanvas jumpCanvas" ref={canvasRef} width="920" height="420" onPointerDown={() => (status === "play" ? jump(stateRef.current) : start())} />
      <div className="gameActions">
        <button onClick={start} type="button"><RefreshCw size={16} /> {status === "play" ? "Neu starten" : "Spiel starten"}</button>
        {user && snapshot.score > 0 && status === "gameover" && <button className="ghost" onClick={save} type="button">Score speichern</button>}
      </div>
      <Scoreboard game="chicken-jump" refreshKey={refreshKey} />
    </section>
  );
}

function ChickenSnake({ user }) {
  const [running, setRunning] = useState(false);
  const [message, setMessage] = useState("WASD oder Pfeiltasten.");
  const [snapshot, setSnapshot] = useState({ score: 0, level: 1 });
  const [refreshKey, setRefreshKey] = useState(0);
  const dirRef = useRef({ x: 1, y: 0 });
  const stateRef = useRef({ snake: [{ x: 8, y: 8 }, { x: 7, y: 8 }, { x: 6, y: 8 }], food: { x: 16, y: 8 }, score: 0, acc: 0, over: false });

  useEffect(() => {
    function key(event) {
      const next = { ArrowUp: { x: 0, y: -1 }, w: { x: 0, y: -1 }, ArrowDown: { x: 0, y: 1 }, s: { x: 0, y: 1 }, ArrowLeft: { x: -1, y: 0 }, a: { x: -1, y: 0 }, ArrowRight: { x: 1, y: 0 }, d: { x: 1, y: 0 } }[event.key];
      if (next) {
        event.preventDefault();
        const old = dirRef.current;
        if (old.x + next.x !== 0 || old.y + next.y !== 0) dirRef.current = next;
      }
    }
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, []);

  const canvasRef = useCanvasGame((ctx, canvas, dt) => {
    const state = stateRef.current;
    const size = 24;
    const cols = Math.floor(canvas.width / size);
    const rows = Math.floor(canvas.height / size);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#120b18"; ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = "rgba(180,108,255,.12)";
    for (let x = 0; x < canvas.width; x += size) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke(); }
    for (let y = 0; y < canvas.height; y += size) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke(); }
    if (running && !state.over) {
      state.acc += dt;
      if (state.acc > Math.max(74, 132 - state.score * 2.2)) {
        state.acc = 0;
        const head = state.snake[0];
        const next = { x: (head.x + dirRef.current.x + cols) % cols, y: (head.y + dirRef.current.y + rows) % rows };
        if (state.snake.some((part) => part.x === next.x && part.y === next.y)) {
          state.over = true;
          setRunning(false);
          setMessage(`Game Over: ${state.score} Punkte`);
        } else {
          state.snake.unshift(next);
          if (next.x === state.food.x && next.y === state.food.y) {
            state.score += 10;
            state.food = { x: Math.floor(Math.random() * cols), y: Math.floor(Math.random() * rows) };
            setSnapshot({ score: state.score, level: state.snake.length });
          } else {
            state.snake.pop();
          }
        }
      }
    }
    ctx.fillStyle = "#ffcf8a";
    ctx.beginPath(); ctx.arc(state.food.x * size + 12, state.food.y * size + 12, 9, 0, Math.PI * 2); ctx.fill();
    state.snake.forEach((part, index) => {
      ctx.fillStyle = index === 0 ? "#7af4dc" : "#b46cff";
      ctx.fillRect(part.x * size + 3, part.y * size + 3, size - 6, size - 6);
    });
  }, [running]);

  function start() {
    stateRef.current = { snake: [{ x: 8, y: 8 }, { x: 7, y: 8 }, { x: 6, y: 8 }], food: { x: 16, y: 8 }, score: 0, acc: 0, over: false };
    dirRef.current = { x: 1, y: 0 };
    setSnapshot({ score: 0, level: 3 });
    setMessage("Sammle Kerne, vermeide deine eigene Spur.");
    setRunning(true);
  }

  async function save() {
    try {
      await api("/api/scores", { method: "POST", body: JSON.stringify({ game: "chicken-snake", score: snapshot.score, level: snapshot.level }) });
      setMessage("Score gespeichert.");
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  return <GameFrame meta={gameMeta["chicken-snake"]} canvasRef={canvasRef} message={message} score={snapshot.score} level={snapshot.level} onStart={start} onSave={user && snapshot.score > 0 ? save : null} refreshKey={refreshKey} game="chicken-snake" />;
}

function ChickenFlipper({ user }) {
  const [status, setStatus] = useState("menu");
  const [audioOn, setAudioOn] = useState(true);
  const [message, setMessage] = useState("Space zieht den Plunger. A/D oder Pfeile feuern die Flipper.");
  const [snapshot, setSnapshot] = useState({ score: 0, level: 1, balls: 3, streak: 0, mult: 1, jackpot: 2500 });
  const [refreshKey, setRefreshKey] = useState(0);
  const keysRef = useRef({ left: false, right: false, launch: false });
  const audioRef = useRef(null);
  const stateRef = useRef(makeFlipperState());

  function audio() {
    if (!audioOn) return null;
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return null;
    if (!audioRef.current) audioRef.current = new AudioCtx();
    if (audioRef.current.state === "suspended") audioRef.current.resume();
    return audioRef.current;
  }

  function blip(freq = 440, dur = 0.055, type = "triangle", vol = 0.035) {
    const ac = audio();
    if (!ac) return;
    const now = ac.currentTime;
    const osc = ac.createOscillator();
    const gain = ac.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(vol, now + 0.008);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    osc.connect(gain).connect(ac.destination);
    osc.start(now);
    osc.stop(now + dur + 0.03);
  }

  function chord(kind) {
    if (kind === "jackpot") [520, 780, 1040, 1560].forEach((f, i) => setTimeout(() => blip(f, 0.08, "square", 0.04), i * 45));
    else if (kind === "drain") [220, 146, 98].forEach((f, i) => setTimeout(() => blip(f, 0.12, "sawtooth", 0.035), i * 55));
    else if (kind === "launch") [220, 440, 880].forEach((f, i) => setTimeout(() => blip(f, 0.05, "triangle", 0.032), i * 34));
    else blip(680, 0.045, "triangle", 0.026);
  }

  const canvasRef = useCanvasGame((ctx, canvas, dt) => {
    const state = stateRef.current;
    const keys = keysRef.current;
    const scale = dt / 16.67;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    drawFlipperTable(ctx, canvas, state, keys);

    if (status === "play") {
      state.time += dt;
      state.flash = Math.max(0, state.flash - dt);
      state.noticeT = Math.max(0, state.noticeT - dt);
      if (state.ready && state.balls[0]) {
        state.balls[0].x = 652;
        state.balls[0].y = 710 - state.plunger * 18;
        state.balls[0].vx = 0;
        state.balls[0].vy = 0;
      }
      if (keys.launch && state.ready) state.plunger = Math.min(1, state.plunger + 0.015 * scale);

      state.balls.forEach((ball) => {
        if (ball.dead) return;
        if (state.ready && ball.launchBall) return;
        ball.vy += 0.25 * scale;
        ball.vx *= 0.998;
        ball.vy *= 0.998;
        preventLowerPocketStall(ball, dt);
        ball.x += ball.vx * scale;
        ball.y += ball.vy * scale;
        collideWalls(ball, canvas, state);
        if (isDrain(ball)) ball.dead = true;
        if (!ball.dead) {
          collideBumpers(ball, state, chord);
          collideTargets(ball, state, chord);
          collideFlippers(ball, keys, state, chord);
        }
        if (ball.dead || ball.y > canvas.height + 30) {
          if (state.time < state.ballSaveUntil) {
            ball.x = 350;
            ball.y = 612;
            ball.vx = (Math.random() - 0.5) * 3;
            ball.vy = -11.8;
            ball.dead = false;
            state.notice = "BALL SAVE";
            state.noticeT = 780;
            state.flash = 260;
          } else {
            ball.dead = true;
          }
        }
      });
      state.balls = state.balls.filter((ball) => !ball.dead);
      if (!state.balls.length) {
        state.ballsLeft -= 1;
        state.streak = 0;
        state.mult = 1;
        if (state.ballsLeft <= 0) {
          setStatus("gameover");
          setMessage(`Run beendet: ${state.score.toLocaleString("de-DE")} Punkte. Jackpot war bei ${state.jackpot}.`);
          chord("drain");
        } else {
          state.ready = true;
          state.plunger = 0;
          state.balls = [makeBall()];
          setMessage(`${state.ballsLeft} Kugeln uebrig. Space halten, loslassen, weiter eskalieren.`);
          chord("drain");
        }
      }
      if (state.streak >= 12 && !state.multiball) {
        state.multiball = true;
        state.balls.push(makeBall(486, 102, -4, 2.5, false), makeBall(398, 118, 4, 2, false));
        state.notice = "MULTIBALL";
        state.noticeT = 950;
        state.flash = 520;
        chord("jackpot");
      }
      if (state.time - state.lastSnapshot > 120) {
        state.lastSnapshot = state.time;
        setSnapshot({ score: state.score, level: state.level, balls: state.ballsLeft, streak: state.streak, mult: state.mult, jackpot: state.jackpot });
      }
    }
    drawFlipperBalls(ctx, state);
    drawFlipperHud(ctx, canvas, state, status);
  }, [status, audioOn]);

  useEffect(() => {
    function down(event) {
      if (event.key === "a" || event.key === "A" || event.key === "ArrowLeft") keysRef.current.left = true;
      if (event.key === "d" || event.key === "D" || event.key === "ArrowRight") keysRef.current.right = true;
      if (event.code === "Space" || event.key === "ArrowDown") {
        keysRef.current.launch = true;
        event.preventDefault();
      }
      if (event.key === "Enter" && status !== "play") start();
    }
    function up(event) {
      const state = stateRef.current;
      if (event.key === "a" || event.key === "A" || event.key === "ArrowLeft") keysRef.current.left = false;
      if (event.key === "d" || event.key === "D" || event.key === "ArrowRight") keysRef.current.right = false;
      if (event.code === "Space" || event.key === "ArrowDown") {
        keysRef.current.launch = false;
        if (status === "play" && state.ready) {
          const power = Math.max(0.32, state.plunger);
          state.ready = false;
          state.balls[0].launchBall = false;
          state.balls[0].vy = -14 - power * 12;
          state.balls[0].vx = -0.2 - power * 0.7;
          state.plunger = 0;
          state.notice = "LAUNCH";
          state.noticeT = 520;
          chord("launch");
        }
        event.preventDefault();
      }
    }
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
    };
  }, [status, audioOn]);

  function start() {
    stateRef.current = makeFlipperState();
    keysRef.current = { left: false, right: false, launch: false };
    setSnapshot({ score: 0, level: 1, balls: 3, streak: 0, mult: 1, jackpot: 2500 });
    setMessage("Space halten und loslassen. A/D oder Pfeile ballern die Flipper.");
    setStatus("play");
    chord("launch");
  }

  async function save() {
    try {
      await api("/api/scores", { method: "POST", body: JSON.stringify({ game: "chicken-flipper", score: snapshot.score, level: snapshot.level, round: snapshot.streak }) });
      setMessage("Score gespeichert.");
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  return (
    <section className="flipperShell" style={{ "--game-accent": gameMeta["chicken-flipper"].accent }}>
      <GameHeader meta={gameMeta["chicken-flipper"]} message={message} score={snapshot.score} level={snapshot.level} />
      <div className="flipperQuickActions">
        <button onClick={start} type="button"><Zap size={16} /> Start</button>
        <button className="ghost" onClick={() => setAudioOn((value) => !value)} type="button"><Zap size={16} /> Sound {audioOn ? "an" : "aus"}</button>
      </div>
      <div className="flipperLayout">
        <div className="flipperStage">
          <canvas className="flipperCanvas" ref={canvasRef} width="760" height="860" />
          {status !== "play" && (
            <div className="flipperOverlay">
              <h3>{status === "gameover" ? "Run beendet" : "Chicken Flipper"}</h3>
              <p>Jackpot-Bumper, Skillshot-Lanes, Multiball ab 12er Streak und ein sehr ungesundes Soundboard.</p>
              <button onClick={start} type="button"><Zap size={16} /> Start</button>
            </div>
          )}
        </div>
        <aside className="flipperSide">
          <div className="flipperMetric"><span>Kugeln</span><strong>{snapshot.balls}</strong><small>Drain kostet eine Kugel</small></div>
          <div className="flipperMetric hot"><span>Streak</span><strong>{snapshot.streak}</strong><small>12 startet Multiball</small></div>
          <div className="flipperMetric"><span>Multiplier</span><strong>x{snapshot.mult}</strong><small>steigt mit jedem Treffer</small></div>
          <div className="flipperMetric jackpot"><span>Jackpot</span><strong>{snapshot.jackpot}</strong><small>Center-Ring kassiert alles</small></div>
          <div className="flipperControls">
            <button onClick={start} type="button"><RefreshCw size={16} /> Start</button>
            <button className="ghost" onClick={() => setAudioOn((value) => !value)} type="button"><Zap size={16} /> Sound {audioOn ? "an" : "aus"}</button>
            {user && snapshot.score > 0 && status === "gameover" && <button className="ghost" onClick={save} type="button">Score speichern</button>}
          </div>
          <div className="flipperHelp">
            <b>Controls</b>
            <span>A/D oder Pfeile fuer Flipper</span>
            <span>Space halten und loslassen fuer Plunger</span>
            <span>Enter startet neu</span>
          </div>
          <div className="flipperScorePanel">
            <h3>Top Scores</h3>
            <Scoreboard game="chicken-flipper" refreshKey={refreshKey} />
          </div>
        </aside>
      </div>
    </section>
  );
}

function makeBall(x = 652, y = 710, vx = 0, vy = 0, launchBall = true) {
  return { x, y, vx, vy, r: 11.5, spin: Math.random() * 6, launchBall };
}

function makeFlipperState() {
  return {
    balls: [makeBall()],
    ballsLeft: 3,
    ready: true,
    plunger: 0,
    score: 0,
    level: 1,
    streak: 0,
    mult: 1,
    jackpot: 2500,
    multiball: false,
    ballSaveUntil: 7000,
    flash: 0,
    notice: "CHICKEN FLIPPER",
    noticeT: 900,
    time: 0,
    lastSnapshot: 0,
    bumpers: [
      { x: 252, y: 214, r: 42, color: "#ffcf8a", label: "PEP" },
      { x: 430, y: 222, r: 42, color: "#ff6fb7", label: "PLE" },
      { x: 342, y: 334, r: 54, color: "#7af4dc", label: "JACK" },
      { x: 206, y: 478, r: 32, color: "#b46cff", label: "x2" },
      { x: 486, y: 478, r: 32, color: "#ffcf8a", label: "x2" },
    ],
    targets: [
      { x: 136, y: 246, w: 20, h: 98, hit: 0, value: 650, color: "#7af4dc" },
      { x: 548, y: 246, w: 20, h: 98, hit: 0, value: 650, color: "#ff6fb7" },
      { x: 172, y: 578, w: 92, h: 18, hit: 0, value: 900, color: "#ffcf8a" },
      { x: 440, y: 578, w: 92, h: 18, hit: 0, value: 900, color: "#ffcf8a" },
    ],
  };
}

function flipperScore(state, points, label) {
  state.streak += 1;
  state.mult = Math.min(9, 1 + Math.floor(state.streak / 4));
  const gained = Math.round(points * state.mult);
  state.score += gained;
  state.level = Math.max(state.level, Math.floor(state.score / 12000) + 1);
  state.jackpot += Math.round(gained * 0.22);
  state.notice = label || `+${gained}`;
  state.noticeT = 520;
}

function collideWalls(ball, canvas) {
  const left = 86;
  const fieldRight = 608;
  const laneLeft = 622;
  const laneRight = 680;
  if (ball.x > laneLeft && ball.y > 126 && ball.y < 748) {
    if (ball.x < laneLeft + ball.r) { ball.x = laneLeft + ball.r; ball.vx = Math.abs(ball.vx) * 0.72; }
    if (ball.x > laneRight - ball.r) { ball.x = laneRight - ball.r; ball.vx = -Math.abs(ball.vx) * 0.72; }
  } else {
    if (ball.x < left + ball.r) { ball.x = left + ball.r; ball.vx = Math.abs(ball.vx) * 0.86; }
    if (ball.x > fieldRight - ball.r && ball.y > 146) { ball.x = fieldRight - ball.r; ball.vx = -Math.abs(ball.vx) * 0.68; }
  }
  if (ball.y < 82 + ball.r) {
    ball.y = 82 + ball.r;
    ball.vy = Math.abs(ball.vy) * 0.72;
    ball.vx -= 5.8;
  }
  if (ball.x > 606 && ball.y < 160 && ball.vy < 0) {
    ball.vy = Math.abs(ball.vy) * 0.54;
    ball.vx = -8.8;
  }
  collideLine(ball, 92, 678, 246, 594, 0.78);
  collideLine(ball, 608, 678, 454, 594, 0.78);
  collideLine(ball, 118, 154, 200, 98, 0.86);
  collideLine(ball, 496, 100, 600, 154, 0.86);
  if (ball.y > 660 && ball.y < 792) {
    if (ball.x < 142) {
      ball.vx += 0.16;
      ball.vy += 0.18;
    }
    if (ball.x > 558 && ball.x < 618) {
      ball.vx -= 0.16;
      ball.vy += 0.18;
    }
  }
  if (ball.x > canvas.width - 30) ball.vx = -Math.abs(ball.vx);
  if (ball.x < 28) ball.vx = Math.abs(ball.vx);
}

function isDrain(ball) {
  const centerGap = ball.y > 746 && ball.x > 304 && ball.x < 396;
  const leftOutlane = ball.y > 714 && ball.x < 132;
  const rightOutlane = ball.y > 714 && ball.x > 568 && ball.x < 620;
  const bottomApron = ball.y > 830;
  return centerGap || leftOutlane || rightOutlane || bottomApron;
}

function preventLowerPocketStall(ball, dt) {
  const speed = Math.hypot(ball.vx, ball.vy);
  const inLowerTrap = ball.y > 612 && ((ball.x > 92 && ball.x < 172) || (ball.x > 528 && ball.x < 612) || (ball.x > 292 && ball.x < 408 && ball.y > 704));
  if (inLowerTrap && speed < 1.2) {
    ball.stuckT = (ball.stuckT || 0) + dt;
  } else {
    ball.stuckT = 0;
  }
  if (ball.stuckT > 420) {
    ball.vy += 1.9;
    if (ball.x < 350) ball.vx += 1.2;
    else ball.vx -= 1.2;
    ball.stuckT = 0;
  }
}

function collideBumpers(ball, state, sound) {
  state.bumpers.forEach((bumper) => {
    const dx = ball.x - bumper.x;
    const dy = ball.y - bumper.y;
    const dist = Math.hypot(dx, dy) || 1;
    if (dist < ball.r + bumper.r) {
      const nx = dx / dist;
      const ny = dy / dist;
      ball.x = bumper.x + nx * (ball.r + bumper.r + 0.5);
      ball.y = bumper.y + ny * (ball.r + bumper.r + 0.5);
      const speed = Math.max(9, Math.hypot(ball.vx, ball.vy) + 3.8);
      ball.vx = nx * speed;
      ball.vy = ny * speed - 1.8;
      bumper.pulse = 180;
      state.flash = 120;
      if (bumper.label === "JACK" && state.streak >= 5) {
        flipperScore(state, state.jackpot, "JACKPOT");
        state.jackpot = 2500 + state.level * 700;
        sound("jackpot");
      } else {
        flipperScore(state, bumper.label === "JACK" ? 1400 : 760, "BUMPER");
        sound("hit");
      }
    }
    bumper.pulse = Math.max(0, (bumper.pulse || 0) - 16);
  });
}

function collideTargets(ball, state, sound) {
  state.targets.forEach((target) => {
    const hit = ball.x + ball.r > target.x && ball.x - ball.r < target.x + target.w && ball.y + ball.r > target.y && ball.y - ball.r < target.y + target.h;
    if (hit && !target.hit) {
      target.hit = 220;
      ball.vx *= -0.85;
      ball.vy = -Math.abs(ball.vy) - 2.2;
      flipperScore(state, target.value, "SKILLSHOT");
      sound("hit");
    }
    target.hit = Math.max(0, (target.hit || 0) - 16);
  });
}

function collideFlippers(ball, keys, state, sound) {
  const flippers = flipperSet(keys);
  flippers.forEach((flipper) => {
    if (ball.y > flipper.ay + 24) return;
    if (collideLine(ball, flipper.ax, flipper.ay, flipper.bx, flipper.by, flipper.on ? 1.18 : 0.78)) {
      const dx = flipper.bx - flipper.ax;
      const dy = flipper.by - flipper.ay;
      const len = Math.hypot(dx, dy) || 1;
      const contact = Math.max(0.08, Math.min(1, ((ball.x - flipper.ax) * dx + (ball.y - flipper.ay) * dy) / (len * len)));
      if (flipper.on) {
        const upKick = 13.8 + contact * 7.6;
        const centerKick = flipper.dir < 0 ? 5.8 + contact * 3.2 : -5.8 - contact * 3.2;
        ball.vy = Math.min(ball.vy, -upKick);
        ball.vx += centerKick;
        ball.y -= 3;
      } else {
        ball.vy = Math.min(ball.vy, -4.4);
        ball.vx += flipper.dir < 0 ? 1.8 : -1.8;
      }
      flipperScore(state, flipper.on ? 240 : 90, flipper.on ? "FLIP" : "SAVE");
      sound("hit");
    }
  });
}

function flipperSet(keys) {
  return [
    flipperGeometry(198, 738, -1, keys.left),
    flipperGeometry(502, 738, 1, keys.right),
  ];
}

function flipperGeometry(x, y, dir, on) {
  const rest = 0.2;
  const raised = -0.58;
  const angle = dir < 0
    ? (on ? raised : rest)
    : Math.PI - (on ? raised : rest);
  const length = 132;
  return {
    x,
    y,
    dir,
    on,
    ax: x,
    ay: y,
    bx: x + Math.cos(angle) * length,
    by: y + Math.sin(angle) * length,
  };
}

function collideLine(ball, x1, y1, x2, y2, bounce = 0.9) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const len2 = dx * dx + dy * dy || 1;
  const t = Math.max(0, Math.min(1, ((ball.x - x1) * dx + (ball.y - y1) * dy) / len2));
  const px = x1 + dx * t;
  const py = y1 + dy * t;
  const nx0 = ball.x - px;
  const ny0 = ball.y - py;
  const dist = Math.hypot(nx0, ny0) || 1;
  if (dist > ball.r + 4) return false;
  const nx = nx0 / dist;
  const ny = ny0 / dist;
  ball.x = px + nx * (ball.r + 4.5);
  ball.y = py + ny * (ball.r + 4.5);
  const dot = ball.vx * nx + ball.vy * ny;
  if (dot < 0) {
    ball.vx = (ball.vx - 2 * dot * nx) * bounce;
    ball.vy = (ball.vy - 2 * dot * ny) * bounce;
  }
  return true;
}

function drawFlipperTable(ctx, canvas, state, keys) {
  const w = canvas.width;
  const h = canvas.height;
  const frame = ctx.createLinearGradient(0, 0, 0, h);
  frame.addColorStop(0, "#5b2b21");
  frame.addColorStop(0.28, "#2a1615");
  frame.addColorStop(1, "#110708");
  ctx.fillStyle = frame;
  ctx.fillRect(0, 0, w, h);

  ctx.fillStyle = "#12080b";
  roundRect(ctx, 48, 24, 672, 812, 42);
  const playfield = ctx.createLinearGradient(0, 48, 0, 812);
  playfield.addColorStop(0, "#221223");
  playfield.addColorStop(0.35, "#111d2d");
  playfield.addColorStop(0.7, "#19101e");
  playfield.addColorStop(1, "#0a0508");
  ctx.fillStyle = playfield;
  roundRect(ctx, 74, 48, 620, 780, 36);

  ctx.save();
  ctx.globalAlpha = 0.18;
  ctx.strokeStyle = "#ffd89c";
  ctx.lineWidth = 1;
  for (let i = 0; i < 18; i += 1) {
    ctx.beginPath();
    ctx.moveTo(94 + i * 31, 62);
    ctx.lineTo(34 + i * 29, 820);
    ctx.stroke();
  }
  ctx.restore();

  ctx.save();
  ctx.shadowBlur = 22;
  ctx.shadowColor = "#ffcf8a";
  ctx.strokeStyle = "rgba(255, 222, 172, .72)";
  ctx.lineWidth = 7;
  roundRect(ctx, 74, 48, 620, 780, 36, true);
  ctx.strokeStyle = "rgba(255,255,255,.18)";
  ctx.lineWidth = 2;
  roundRect(ctx, 88, 62, 592, 752, 28, true);
  ctx.restore();

  ctx.save();
  ctx.strokeStyle = "rgba(122,244,220,.30)";
  ctx.lineWidth = 2;
  for (let i = 0; i < 8; i += 1) {
    ctx.beginPath();
    ctx.arc(350, 430, 120 + i * 34, Math.PI * 1.12, Math.PI * 1.88);
    ctx.stroke();
  }
  ctx.restore();

  drawNeonSign(ctx, 226, 96, 258, 64, "PEPPLE", "#ffcf8a");
  drawLane(ctx, 622, 126, 58, 650, state.plunger);
  drawWireRamp(ctx);
  drawSlingshots(ctx);
  drawDrainApron(ctx);

  state.bumpers.forEach((bumper) => {
    const pulse = 1 + (bumper.pulse || 0) / 520;
    ctx.save();
    ctx.translate(bumper.x, bumper.y);
    ctx.shadowColor = bumper.color;
    ctx.shadowBlur = 26 + pulse * 24;
    const rg = ctx.createRadialGradient(-11, -14, 4, 0, 0, bumper.r * pulse);
    rg.addColorStop(0, "#fff8e9");
    rg.addColorStop(0.34, bumper.color);
    rg.addColorStop(1, "#3b1624");
    ctx.fillStyle = rg;
    ctx.beginPath();
    ctx.arc(0, 0, bumper.r * pulse, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,.78)";
    ctx.lineWidth = 4;
    ctx.stroke();
    ctx.fillStyle = "#160b10";
    ctx.font = "950 13px Inter, Arial";
    ctx.textAlign = "center";
    ctx.fillText(bumper.label, 0, 5);
    ctx.restore();
  });
  state.targets.forEach((target) => {
    ctx.fillStyle = target.hit ? "#fff4e9" : target.color;
    ctx.shadowColor = target.color;
    ctx.shadowBlur = target.hit ? 30 : 16;
    roundRect(ctx, target.x, target.y, target.w, target.h, 6);
  });
  ctx.shadowBlur = 0;
  flipperSet(keys).forEach((flipper) => drawFlipper(ctx, flipper));
  drawGlass(ctx, w, h);
  if (state.flash > 0) {
    ctx.fillStyle = `rgba(255,244,233,${Math.min(0.18, state.flash / 2600)})`;
    ctx.fillRect(0, 0, w, h);
  }
}

function drawFlipper(ctx, geom) {
  const angle = Math.atan2(geom.by - geom.ay, geom.bx - geom.ax);
  const length = Math.hypot(geom.bx - geom.ax, geom.by - geom.ay);
  ctx.save();
  ctx.translate(geom.ax, geom.ay);
  ctx.rotate(angle);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.shadowColor = geom.on ? "#ffcf8a" : "#d64878";
  ctx.shadowBlur = geom.on ? 30 : 16;
  const body = ctx.createLinearGradient(0, -16, length, 18);
  body.addColorStop(0, "#fff0be");
  body.addColorStop(0.18, "#ffb351");
  body.addColorStop(0.58, "#f04d83");
  body.addColorStop(1, "#7af4dc");
  ctx.strokeStyle = body;
  ctx.lineWidth = 28;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(length - 7, 0);
  ctx.stroke();
  ctx.strokeStyle = "rgba(255,255,255,.72)";
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.moveTo(12, -7);
  ctx.lineTo(length - 30, -6);
  ctx.stroke();
  ctx.strokeStyle = "rgba(60,12,30,.58)";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(18, 8);
  ctx.lineTo(length - 16, 7);
  ctx.stroke();
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = "#f6d39a";
  ctx.shadowBlur = 18;
  ctx.beginPath();
  ctx.arc(geom.ax, geom.ay, 18, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "rgba(44,18,22,.72)";
  ctx.beginPath();
  ctx.arc(geom.ax, geom.ay, 7, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawLane(ctx, x, y, w, h, plunger) {
  ctx.save();
  ctx.fillStyle = "rgba(4, 7, 12, .62)";
  roundRect(ctx, x, y, w, h, 22);
  ctx.strokeStyle = "rgba(230, 215, 190, .58)";
  ctx.lineWidth = 4;
  roundRect(ctx, x + 4, y + 6, w - 8, h - 12, 18, true);
  ctx.strokeStyle = "rgba(255,207,138,.55)";
  ctx.lineWidth = 2;
  for (let i = 0; i < 9; i += 1) {
    ctx.beginPath();
    ctx.moveTo(x + 14, y + h - 54 - i * 16);
    ctx.lineTo(x + w - 14, y + h - 64 - i * 16);
    ctx.stroke();
  }
  ctx.fillStyle = "#2b1711";
  roundRect(ctx, x + 17, y + h - 98 - plunger * 154, 24, 112 + plunger * 154, 12);
  ctx.fillStyle = "#f2c277";
  roundRect(ctx, x + 13, y + h - 114 - plunger * 154, 32, 26, 10);
  ctx.fillStyle = "#fff4e9";
  ctx.font = "900 12px Inter, Arial";
  ctx.textAlign = "center";
  ctx.fillText("SPACE", x + w / 2, y + h - 24);
  ctx.restore();
}

function drawWireRamp(ctx) {
  ctx.save();
  ctx.strokeStyle = "rgba(230, 215, 190, .64)";
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.arc(352, 250, 218, Math.PI * 1.04, Math.PI * 1.82);
  ctx.stroke();
  ctx.strokeStyle = "rgba(122,244,220,.36)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(352, 250, 236, Math.PI * 1.04, Math.PI * 1.82);
  ctx.stroke();
  ctx.restore();
}

function drawSlingshots(ctx) {
  ctx.save();
  ctx.shadowColor = "#ffcf8a";
  ctx.shadowBlur = 20;
  ctx.strokeStyle = "rgba(255,207,138,.92)";
  ctx.lineWidth = 8;
  ctx.beginPath(); ctx.moveTo(92, 678); ctx.lineTo(246, 594); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(608, 678); ctx.lineTo(454, 594); ctx.stroke();
  ctx.fillStyle = "rgba(255,111,183,.24)";
  ctx.beginPath(); ctx.moveTo(112, 668); ctx.lineTo(246, 594); ctx.lineTo(192, 560); ctx.closePath(); ctx.fill();
  ctx.beginPath(); ctx.moveTo(588, 668); ctx.lineTo(454, 594); ctx.lineTo(508, 560); ctx.closePath(); ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,.38)";
  ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(124, 644); ctx.lineTo(226, 592); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(576, 644); ctx.lineTo(474, 592); ctx.stroke();
  ctx.restore();
}

function drawDrainApron(ctx) {
  ctx.save();
  const apron = ctx.createLinearGradient(0, 690, 0, 826);
  apron.addColorStop(0, "rgba(255,111,183,.05)");
  apron.addColorStop(0.42, "rgba(22,9,15,.12)");
  apron.addColorStop(1, "rgba(0,0,0,.52)");
  ctx.fillStyle = apron;
  ctx.beginPath();
  ctx.moveTo(88, 810);
  ctx.lineTo(180, 690);
  ctx.lineTo(302, 752);
  ctx.quadraticCurveTo(350, 786, 398, 752);
  ctx.lineTo(520, 690);
  ctx.lineTo(612, 810);
  ctx.closePath();
  ctx.fill();

  ctx.shadowColor = "#000";
  ctx.shadowBlur = 28;
  ctx.fillStyle = "rgba(0,0,0,.76)";
  ctx.beginPath();
  ctx.ellipse(350, 777, 64, 26, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,207,138,.42)";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.arc(350, 759, 56, 0.12, Math.PI - 0.12);
  ctx.stroke();

  ctx.shadowBlur = 18;
  ctx.strokeStyle = "rgba(122,244,220,.28)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(302, 752);
  ctx.quadraticCurveTo(350, 782, 398, 752);
  ctx.stroke();
  ctx.restore();
}

function drawNeonSign(ctx, x, y, w, h, text, color) {
  ctx.save();
  ctx.shadowColor = color;
  ctx.shadowBlur = 24;
  ctx.fillStyle = "rgba(5,5,12,.76)";
  roundRect(ctx, x, y, w, h, 12);
  ctx.strokeStyle = color;
  ctx.lineWidth = 3;
  roundRect(ctx, x, y, w, h, 12, true);
  ctx.fillStyle = "#fff4e9";
  ctx.font = "950 24px Inter, Arial";
  ctx.textAlign = "center";
  ctx.fillText(text, x + w / 2, y + 40);
  ctx.restore();
}

function drawGlass(ctx, w, h) {
  const glass = ctx.createLinearGradient(0, 0, w, h);
  glass.addColorStop(0, "rgba(255,255,255,.12)");
  glass.addColorStop(0.18, "rgba(255,255,255,.025)");
  glass.addColorStop(0.52, "rgba(255,255,255,.09)");
  glass.addColorStop(0.62, "rgba(255,255,255,.015)");
  glass.addColorStop(1, "rgba(255,255,255,.08)");
  ctx.fillStyle = glass;
  ctx.fillRect(74, 48, 620, 780);
}

function drawFlipperBalls(ctx, state) {
  state.balls.forEach((ball) => {
    ball.spin += 0.08;
    ctx.save();
    ctx.translate(ball.x, ball.y);
    ctx.rotate(ball.spin);
    ctx.shadowColor = "#d8efff";
    ctx.shadowBlur = 20;
    const metal = ctx.createRadialGradient(-5, -7, 2, 2, 3, ball.r + 5);
    metal.addColorStop(0, "#ffffff");
    metal.addColorStop(0.28, "#dce9f6");
    metal.addColorStop(0.58, "#8fa0af");
    metal.addColorStop(1, "#29313a");
    ctx.fillStyle = metal;
    ctx.beginPath();
    ctx.arc(0, 0, ball.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,.72)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(0, 0, ball.r - 2, -0.7, 1.6);
    ctx.stroke();
    ctx.fillStyle = "rgba(255,255,255,.88)";
    ctx.beginPath();
    ctx.arc(-4, -6, 2.8, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  });
}

function drawFlipperHud(ctx, canvas, state, status) {
  ctx.save();
  ctx.fillStyle = "rgba(8,5,13,.78)";
  ctx.fillRect(92, 70, 492, 54);
  ctx.strokeStyle = "rgba(255,207,138,.22)";
  ctx.strokeRect(92, 70, 492, 54);
  ctx.fillStyle = "#fff4e9";
  ctx.font = "950 23px Inter, Arial";
  ctx.fillText(`Score ${state.score.toLocaleString("de-DE")}`, 112, 104);
  ctx.fillStyle = "#7af4dc";
  ctx.font = "900 14px Inter, Arial";
  ctx.fillText(`Streak ${state.streak}   x${state.mult}   Jackpot ${state.jackpot}`, 332, 103);
  if (state.noticeT > 0 || status !== "play") {
    ctx.textAlign = "center";
    ctx.fillStyle = status === "play" ? "#ffcf8a" : "#fff4e9";
    ctx.font = "950 46px Inter, Arial";
    ctx.shadowColor = "#ff6fb7";
    ctx.shadowBlur = 24;
    ctx.fillText(status === "play" ? state.notice : "CHICKEN FLIPPER", canvas.width / 2, 410);
  }
  ctx.restore();
}

function roundRect(ctx, x, y, w, h, r = 8, strokeOnly = false) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  if (strokeOnly) ctx.stroke();
  else ctx.fill();
}

function PeppleSurvivor({ user }) {
  const upgradePool = [
    { id: "bolt", name: "Federblitz", kind: "weapon", icon: "feather", desc: "Feuert zielsuchende Federbolzen auf nahe Gegner.", color: "#c88cff" },
    { id: "orbit", name: "Orbit-Kaefig", kind: "weapon", icon: "orbit", desc: "Beschwoert kreisende Kaefig-Ringe um dich.", color: "#ffcf8a" },
    { id: "nova", name: "Nova-Puls", kind: "weapon", icon: "nova", desc: "Stoesst in Intervallen alle Gegner zurueck.", color: "#ff6fb7" },
    { id: "laser", name: "Sternenlaser", kind: "weapon", icon: "laser", desc: "Schneidet den staerksten Gegner mit Licht.", color: "#7af4dc" },
    { id: "egg", name: "Kosmo-Ei", kind: "weapon", icon: "egg", desc: "Laesst explosive Eier in die Schwarmbahn fallen.", color: "#fff4e9" },
    { id: "aura", name: "Nest-Aura", kind: "weapon", icon: "aura", desc: "Verbrennt nahe Drohnen mit warmer Kaefigenergie.", color: "#c88956" },
    { id: "drone", name: "Mini-Satelliten", kind: "weapon", icon: "drone", desc: "Kleine Begleiter feuern Plasma aus dem Orbit.", color: "#8f7bff" },
    { id: "thunder", name: "Kettenblitz", kind: "weapon", icon: "thunder", desc: "Springt von Alien zu Alien und knistert brutal.", color: "#ffe66d" },
    { id: "frost", name: "Kryo-Federn", kind: "weapon", icon: "frost", desc: "Verlangsamt getroffene Aliens mit Eisnebel.", color: "#9bf6ff" },
    { id: "gravity", name: "Schwarzes Pepple", kind: "weapon", icon: "gravity", desc: "Zieht Aliens in eine dunkle Singularitaet.", color: "#6d4cff" },
    { id: "speed", name: "Kometenboots", kind: "passive", icon: "boots", desc: "Mehr Tempo und bessere Ausweichfenster.", color: "#7af4dc" },
    { id: "magnet", name: "Pepple-Magnet", kind: "passive", icon: "magnet", desc: "Zieht XP-Kristalle aus groesserer Distanz an.", color: "#b46cff" },
    { id: "shield", name: "Schildfedern", kind: "passive", icon: "shield", desc: "Mehr maximale HP und weniger Kontaktschaden.", color: "#ffcf8a" },
    { id: "regen", name: "Warmnest", kind: "passive", icon: "regen", desc: "Regeneriert im Lauf langsam HP.", color: "#ff9f6e" },
    { id: "might", name: "Pepple-Fokus", kind: "passive", icon: "might", desc: "Alle Waffen verursachen mehr Schaden.", color: "#ff6fb7" },
    { id: "cooldown", name: "Taktgeber", kind: "passive", icon: "cooldown", desc: "Waffen laden schneller wieder auf.", color: "#dfb8ff" },
  ];
  const worldConfig = { width: 6200, height: 4200, spawnX: 3100, spawnY: 2100 };
  const initialSettingsRef = useRef(readSurvivorSettings());
  const [status, setStatus] = useState("menu");
  const [audioOn, setAudioOn] = useState(() => initialSettingsRef.current.audioOn);
  const [volume, setVolume] = useState(() => initialSettingsRef.current.volume);
  const [controlMode, setControlMode] = useState(() => initialSettingsRef.current.controlMode);
  const [fullscreen, setFullscreen] = useState(false);
  const [choices, setChoices] = useState([]);
  const [message, setMessage] = useState("WASD bewegen, XP sammeln, beim Level-Up Waffen waehlen.");
  const [lastRun, setLastRun] = useState(null);
  const [snapshot, setSnapshot] = useState({
    score: 0,
    level: 1,
    seconds: 0,
    kills: 0,
    hp: 150,
    maxHp: 150,
    energy: 100,
    bleeding: false,
    playerX: worldConfig.spawnX,
    playerY: worldConfig.spawnY,
    xp: 0,
    nextXp: 45,
    wave: 1,
    weapons: [{ id: "bolt", name: "Federblitz", level: 1, color: "#c88cff", icon: "feather" }],
  });
  const [refreshKey, setRefreshKey] = useState(0);
  const keysRef = useRef({});
  const musicRef = useRef(null);
  const stageRef = useRef(null);
  const bgRef = useRef(null);
  const spriteRef = useRef(null);
  const obstacleArtRef = useRef(null);
  const titleRef = useRef(null);
  const playerArtRef = useRef(null);
  const playerFaceRef = useRef(null);
  const criticalAlarmRef = useRef(0);
  const audioRef = useRef({ ctx: null, nextBeat: 0 });
  const statusRef = useRef("menu");
  const musicPlaylist = [
    "/assets/braincell-survivor-theme.mp3",
    "/assets/braincell-survivor-theme-2.mp3",
    "/assets/braincell-survivor-theme-3.mp3",
    "/assets/braincell-survivor-theme-4.mp3",
  ];
  const perfCaps = { enemies: 92, bossEnemies: 64, shots: 88, hazards: 72, particles: 230, gems: 120, potions: 8, beams: 48, bombs: 22, wells: 8 };
  const bossCooldownSeconds = 180;

  function makeObstacles() {
    const specs = [
      [940, 760, 122, 55, "starAmber", -0.35, 1.04, "#ffcf8a"],
      [1510, 1220, 92, 42, "mine", 0.14, 0.84, "#ff6fb7"],
      [2190, 880, 132, 62, "shipScout", -0.2, 1.05, "#7af4dc"],
      [2850, 1320, 108, 48, "starBlue", 0.82, 0.9, "#7af4dc"],
      [3790, 920, 142, 65, "satellite", -0.5, 1.02, "#9bf6ff"],
      [4940, 760, 128, 58, "mine", 0.52, 1.03, "#ff6fb7"],
      [5450, 1310, 174, 76, "shipWreck", -0.38, 1.12, "#ff9f6e"],
      [1220, 1940, 146, 66, "starAmber", 0.74, 1.18, "#ffe66d"],
      [1980, 2520, 188, 82, "shipWreck", -0.18, 1.3, "#826b62"],
      [2470, 1810, 108, 50, "starAmber", -0.4, 1.0, "#ffcf8a"],
      [3650, 1610, 132, 58, "shipScout", 0.32, 1.03, "#7af4dc"],
      [4150, 2160, 112, 51, "starBlue", 0.2, 0.96, "#b46cff"],
      [4760, 2600, 100, 45, "mine", 1.2, 0.92, "#dfb8ff"],
      [5360, 2190, 136, 62, "satellite", -0.86, 0.98, "#9bf6ff"],
      [780, 3100, 154, 70, "shipScout", 0.16, 1.05, "#66798b"],
      [1400, 3440, 104, 47, "starBlue", 0.62, 0.9, "#9bf6ff"],
      [2120, 3320, 126, 57, "mine", -0.78, 0.96, "#ff6fb7"],
      [2920, 3480, 162, 72, "satellite", 0.6, 1.1, "#7af4dc"],
      [3640, 3220, 174, 78, "shipWreck", -0.72, 1.12, "#6b7486"],
      [4380, 3440, 112, 50, "starAmber", 1.35, 0.94, "#dfb8ff"],
      [5120, 3300, 150, 68, "starBlue", -0.9, 1.08, "#9bf6ff"],
      [5700, 2860, 164, 72, "shipScout", 0.4, 1.05, "#7af4dc"],
      [900, 2520, 112, 50, "mine", -0.2, 0.88, "#ff6fb7"],
      [1700, 1680, 92, 42, "starAmber", 0.55, 0.78, "#ff9f6e"],
      [3350, 2620, 126, 56, "starBlue", 1.1, 1.0, "#7af4dc"],
      [4520, 1540, 186, 82, "shipWreck", 0.42, 1.22, "#617387"],
      [5700, 1840, 110, 50, "starAmber", -0.65, 0.9, "#ffcf8a"],
      [760, 1420, 146, 66, "satellite", 0.38, 1.0, "#9bf6ff"],
    ];
    return specs.map(([x, y, visualRadius, collisionRadius, type, rotation, scale, color], index) => ({
      id: `obstacle-${index}`,
      x,
      y,
      visualRadius,
      collisionRadius,
      radius: collisionRadius,
      type,
      rotation,
      scale,
      color,
    }));
  }

  function makeSurvivorState() {
    return {
      world: worldConfig,
      player: { x: worldConfig.spawnX, y: worldConfig.spawnY, hp: 150, maxHp: 150, invuln: 0 },
      energy: 100,
      bleeding: false,
      bleedStartedAt: 0,
      bleedHpStart: 150,
      camera: { x: worldConfig.spawnX - 640, y: worldConfig.spawnY - 360 },
      obstacles: makeObstacles(),
      gems: [],
      potions: [],
      enemies: [],
      shots: [],
      bombs: [],
      beams: [],
      wells: [],
      hazards: [],
      particles: [],
      score: 0,
      xp: 0,
      nextXp: 45,
      seconds: 0,
      kills: 0,
      level: 1,
      wave: 1,
      spawn: 0,
      nextBossAt: bossCooldownSeconds,
      bossActive: false,
      timers: { bolt: 0, nova: 2600, laser: 1600, egg: 900, drone: 640, thunder: 2100, gravity: 3200, regen: 1000, comfortRegen: 1000, potion: 4200 },
      weapons: { bolt: 1, orbit: 0, nova: 0, laser: 0, egg: 0, aura: 0, drone: 0, thunder: 0, frost: 0, gravity: 0, speed: 0, magnet: 0, shield: 0, regen: 0, might: 0, cooldown: 0 },
      over: false,
    };
  }

  const stateRef = useRef(makeSurvivorState());

  function setGameStatus(next) {
    statusRef.current = next;
    setStatus(next);
    if (next === "play") setTimeout(startMusic, 0);
    if (next === "gameover" || next === "menu" || next === "options" || next === "paused" || next === "crashed") stopMusic();
  }

  useEffect(() => {
    function down(event) {
      if ([" ", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(event.key.toLowerCase())) event.preventDefault();
      if (["p", "escape"].includes(event.key.toLowerCase())) {
        event.preventDefault();
        if (statusRef.current === "options") {
          setMessage("WASD bewegen, XP sammeln, beim Level-Up Waffen waehlen.");
          setGameStatus("menu");
          return;
        }
        if (statusRef.current === "play") {
          setMessage("Run pausiert. Fortsetzen bringt dich direkt zurueck ins Chaos.");
          setGameStatus("paused");
        } else if (statusRef.current === "paused") {
          setMessage("Weiter geht's. Die Aliens haben kurz gewartet.");
          setGameStatus("play");
        }
        return;
      }
      keysRef.current[event.key.toLowerCase()] = true;
    }
    function up(event) { keysRef.current[event.key.toLowerCase()] = false; }
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };
  }, []);

  useEffect(() => {
    function fullscreenChange() {
      setFullscreen(document.fullscreenElement === stageRef.current);
    }
    document.addEventListener("fullscreenchange", fullscreenChange);
    return () => document.removeEventListener("fullscreenchange", fullscreenChange);
  }, []);

  useEffect(() => () => {
    if (musicRef.current) {
      musicRef.current.pause();
      musicRef.current.src = "";
    }
    audioRef.current.ctx?.close?.();
    audioRef.current.ctx = null;
  }, []);

  useEffect(() => {
    const image = new Image();
    image.src = "/assets/pepple-survivor-space-bg.png";
    bgRef.current = image;
    const sprites = new Image();
    sprites.src = "/assets/pepple-survivor-sprites.png";
    spriteRef.current = sprites;
    const obstacleArt = new Image();
    obstacleArt.src = "/assets/survivor-obstacles-ai-v1.png?v=1";
    obstacleArtRef.current = obstacleArt;
    const title = new Image();
    title.src = "/assets/pepple-survivor-title-flori-v2.png?v=2";
    titleRef.current = title;
    const playerArt = new Image();
    playerArt.src = "/assets/player-chicken-ai-v1.png?v=1";
    playerArtRef.current = playerArt;
    const playerFace = new Image();
    playerFace.src = "/assets/player-face.jpeg?v=2";
    playerFaceRef.current = playerFace;
  }, []);

  useEffect(() => {
    writeSurvivorSettings({ audioOn, volume, controlMode });
    if (musicRef.current) musicRef.current.volume = 0.18 * volume;
  }, [audioOn, volume, controlMode]);

  useEffect(() => {
    if (!audioOn) {
      musicRef.current?.pause();
      return;
    }
    if (statusRef.current === "play") startMusic();
  }, [audioOn, volume]);

  function audio() {
    if (!audioOn) return null;
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return null;
    if (!audioRef.current.ctx) audioRef.current.ctx = new AudioCtx();
    if (audioRef.current.ctx.state === "suspended") audioRef.current.ctx.resume();
    return audioRef.current.ctx;
  }

  function sfx(type) {
    const ctxAudio = audio();
    if (!ctxAudio) return;
    const osc = ctxAudio.createOscillator();
    const gain = ctxAudio.createGain();
    const now = ctxAudio.currentTime;
    const notes = { start: 196, pepple: 740, hit: 96, shot: 520, level: 980, laser: 1320, bomb: 86, thunder: 180, nova: 160, freeze: 1180, kill: 460, heal: 880 };
    osc.type = ["hit", "bomb", "thunder"].includes(type) ? "sawtooth" : type === "shot" ? "square" : type === "heal" ? "sine" : "triangle";
    osc.frequency.setValueAtTime(notes[type] || 360, now);
    osc.frequency.exponentialRampToValueAtTime(["hit", "bomb", "thunder"].includes(type) ? 44 : type === "heal" ? 1320 : (notes[type] || 360) * 1.48, now + 0.16);
    gain.gain.setValueAtTime((type === "hit" ? 0.095 : type === "bomb" ? 0.075 : type === "heal" ? 0.065 : 0.045) * volume, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + (type === "bomb" ? 0.26 : type === "heal" ? 0.24 : 0.18));
    osc.connect(gain).connect(ctxAudio.destination);
    osc.start(now);
    osc.stop(now + (type === "bomb" ? 0.28 : type === "heal" ? 0.26 : 0.2));
    if (["bomb", "nova", "thunder"].includes(type)) noise(type === "bomb" ? 0.22 : 0.11, type === "bomb" ? 0.04 : 0.022);
  }

  function levelUpFanfare() {
    const ctxAudio = audio();
    if (!ctxAudio) return;
    const now = ctxAudio.currentTime;
    const notes = [523.25, 659.25, 783.99, 1046.5];
    notes.forEach((note, index) => {
      const startAt = now + index * 0.075;
      const osc = ctxAudio.createOscillator();
      const gain = ctxAudio.createGain();
      osc.type = index === notes.length - 1 ? "sawtooth" : "triangle";
      osc.frequency.setValueAtTime(note, startAt);
      osc.frequency.exponentialRampToValueAtTime(note * 1.12, startAt + 0.16);
      gain.gain.setValueAtTime(0.001, startAt);
      gain.gain.linearRampToValueAtTime((index === notes.length - 1 ? 0.09 : 0.06) * volume, startAt + 0.025);
      gain.gain.exponentialRampToValueAtTime(0.001, startAt + 0.32);
      osc.connect(gain).connect(ctxAudio.destination);
      osc.start(startAt);
      osc.stop(startAt + 0.36);
    });
    noise(0.16, 0.018);
  }

  function criticalAlarm() {
    const ctxAudio = audio();
    if (!ctxAudio) return;
    const now = ctxAudio.currentTime;
    for (let i = 0; i < 4; i += 1) {
      const osc = ctxAudio.createOscillator();
      const gain = ctxAudio.createGain();
      const startAt = now + i * 0.18;
      osc.type = "square";
      osc.frequency.setValueAtTime(i % 2 ? 590 : 920, startAt);
      osc.frequency.exponentialRampToValueAtTime(i % 2 ? 720 : 520, startAt + 0.12);
      gain.gain.setValueAtTime(0.001, startAt);
      gain.gain.linearRampToValueAtTime(0.11 * volume, startAt + 0.025);
      gain.gain.exponentialRampToValueAtTime(0.001, startAt + 0.145);
      osc.connect(gain).connect(ctxAudio.destination);
      osc.start(startAt);
      osc.stop(startAt + 0.16);
    }
  }

  function bleedingAlarm() {
    const ctxAudio = audio();
    if (ctxAudio) {
      const now = ctxAudio.currentTime;
      for (let i = 0; i < 6; i += 1) {
        const osc = ctxAudio.createOscillator();
        const gain = ctxAudio.createGain();
        const startAt = now + i * 0.15;
        osc.type = i % 2 ? "sawtooth" : "square";
        osc.frequency.setValueAtTime(i % 2 ? 122 : 880, startAt);
        osc.frequency.exponentialRampToValueAtTime(i % 2 ? 66 : 520, startAt + 0.12);
        gain.gain.setValueAtTime(0.001, startAt);
        gain.gain.linearRampToValueAtTime(0.13 * volume, startAt + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.001, startAt + 0.14);
        osc.connect(gain).connect(ctxAudio.destination);
        osc.start(startAt);
        osc.stop(startAt + 0.16);
      }
      noise(0.5, 0.05);
    }
    if (audioOn && "speechSynthesis" in window) {
      window.speechSynthesis.cancel();
      const voice = new SpeechSynthesisUtterance("Unstillbare Blutung entdeckt");
      voice.lang = "de-DE";
      voice.rate = 0.9;
      voice.pitch = 0.65;
      voice.volume = Math.max(0.2, Math.min(1, volume));
      window.speechSynthesis.speak(voice);
    }
  }

  function noise(duration = 0.1, level = 0.02) {
    const ctxAudio = audio();
    if (!ctxAudio) return;
    const buffer = ctxAudio.createBuffer(1, ctxAudio.sampleRate * duration, ctxAudio.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i += 1) data[i] = (Math.random() * 2 - 1) * (1 - i / data.length);
    const source = ctxAudio.createBufferSource();
    const gain = ctxAudio.createGain();
    const filter = ctxAudio.createBiquadFilter();
    source.buffer = buffer;
    filter.type = "highpass";
    filter.frequency.value = 700;
    gain.gain.setValueAtTime(level * volume, ctxAudio.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctxAudio.currentTime + duration);
    source.connect(filter).connect(gain).connect(ctxAudio.destination);
    source.start();
  }

  function startMusic() {
    const el = musicRef.current;
    if (!el || !audioOn) return;
    if (!el.src) el.src = musicPlaylist[Math.floor(Math.random() * musicPlaylist.length)];
    el.volume = 0.18 * volume;
    el.play().catch(() => {});
  }

  function stopMusic() {
    musicRef.current?.pause();
  }

  function musicTick() {
    const ctxAudio = audioOn ? audioRef.current.ctx : null;
    if (!ctxAudio || statusRef.current !== "play") return;
    const now = ctxAudio.currentTime;
    if (now < audioRef.current.nextBeat) return;
    const osc = ctxAudio.createOscillator();
    const gain = ctxAudio.createGain();
    const notes = [98, 130.81, 146.83, 196, 220, 261.63, 293.66, 220];
    const note = notes[Math.floor(now * 2.35) % notes.length];
    osc.type = "sine";
    osc.frequency.setValueAtTime(note, now);
    gain.gain.setValueAtTime(0.022, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.42);
    osc.connect(gain).connect(ctxAudio.destination);
    osc.start(now);
    osc.stop(now + 0.46);
    audioRef.current.nextBeat = now + 0.36;
  }

  function burst(x, y, color, amount = 10) {
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;
    const state = stateRef.current;
    const pressure = state.particles.length > 180 ? 0.45 : state.particles.length > 120 ? 0.7 : 1;
    const count = clamp(Math.floor((Number(amount) || 0) * pressure), 0, 38);
    for (let i = 0; i < count; i += 1) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 0.8 + Math.random() * 3.2;
      state.particles.push({ x, y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: 420 + Math.random() * 360, ttl: 800, color });
    }
  }

  function pushRing(state, x, y, radius, life, color) {
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(radius) || !Number.isFinite(life)) return;
    const safeRadius = clamp(radius, 1, 760);
    const safeLife = clamp(life, 60, 2200);
    state.particles.push({ ring: true, x, y, vx: 0, vy: 0, max: safeRadius, life: safeLife, ttl: safeLife, color });
  }

  function alienBloodBurst(x, y, color = "#9cff4a", amount = 12, force = 1) {
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;
    const state = stateRef.current;
    const pressure = state.particles.length > 180 ? 0.38 : state.particles.length > 120 ? 0.65 : 1;
    const count = clamp(Math.floor((Number(amount) || 0) * pressure), 0, 42);
    const safeForce = Number.isFinite(force) ? clamp(force, 0.1, 2.4) : 1;
    for (let i = 0; i < count; i += 1) {
      const angle = Math.random() * Math.PI * 2;
      const speed = (1.4 + Math.random() * 5.8) * safeForce;
      state.particles.push({
        type: "slime",
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        size: 2.5 + Math.random() * 7,
        life: 620 + Math.random() * 760,
        ttl: 1380,
        color,
      });
    }
  }

  function scorePopup(state, x, y, points, color = "#ffcf8a") {
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(points)) return;
    state.particles.push({
      type: "score",
      text: `+${points}`,
      x,
      y: y - 18,
      vx: (Math.random() - 0.5) * 0.9,
      vy: -1.45 - Math.random() * 0.65,
      life: 940,
      ttl: 940,
      size: points >= 100 ? 28 : points >= 30 ? 22 : 18,
      color,
    });
  }

  function bossAttack(state, canvas, boss) {
    const pattern = Math.floor(state.seconds * 1.35 + state.wave) % 5;
    if (pattern === 0) {
      state.hazards.push({ type: "ring", x: boss.x, y: boss.y, radius: 28, max: 340, life: 1280, ttl: 1280, damage: 22, hit: false, color: "#ff6fb7" });
      state.hazards.push({ type: "ring", x: state.player.x, y: state.player.y, radius: 18, max: 190, life: 920, ttl: 920, damage: 16, hit: false, color: "#ffcf8a" });
      boss.phase = 1.4;
      pushRing(state, boss.x, boss.y, 260, 520, "#ff6fb7");
    } else if (pattern === 1) {
      for (let i = 0; i < 12; i += 1) {
        const angle = i / 12 * Math.PI * 2 + state.seconds;
        state.hazards.push({ type: "orb", x: boss.x, y: boss.y, vx: Math.cos(angle) * 3.5, vy: Math.sin(angle) * 3.5, radius: 15, life: 2300, ttl: 2300, damage: 13, color: i % 2 ? "#ffcf8a" : "#b46cff" });
      }
      burst(boss.x, boss.y, "#ffcf8a", 28);
    } else if (pattern === 2) {
      const base = Math.atan2(state.player.y - boss.y, state.player.x - boss.x);
      for (let i = -1; i <= 1; i += 1) {
        const angle = base + i * 0.34;
        const length = Math.max(canvas.width, canvas.height) * 1.08;
        state.hazards.push({ type: "beam", x1: boss.x, y1: boss.y, x2: boss.x + Math.cos(angle) * length, y2: boss.y + Math.sin(angle) * length, life: 980, ttl: 980, warmup: 430, damage: 16, width: 18, hitWidth: 10, color: i === 0 ? "#ffcf8a" : "#7af4dc", hit: false });
      }
      pushRing(state, boss.x, boss.y, 150, 360, "#7af4dc");
    } else if (pattern === 3) {
      for (let i = 0; i < 7; i += 1) {
        const ox = (Math.random() - 0.5) * canvas.width * 0.85;
        const oy = (Math.random() - 0.5) * canvas.height * 0.65;
        state.hazards.push({ type: "meteor", x: state.player.x + ox, y: state.player.y + oy, radius: 34 + Math.random() * 18, life: 1150 + i * 70, ttl: 1150 + i * 70, damage: 15, color: i % 2 ? "#ff6fb7" : "#ffcf8a", hit: false, exploded: false });
      }
      sfx("bomb");
    } else {
      for (let i = 0; i < 6; i += 1) {
        const angle = i / 6 * Math.PI * 2 + state.seconds * 0.8;
        const length = Math.max(canvas.width, canvas.height) * 0.86;
        state.hazards.push({ type: "beam", x1: boss.x, y1: boss.y, x2: boss.x + Math.cos(angle) * length, y2: boss.y + Math.sin(angle) * length, life: 820, ttl: 820, warmup: 360, damage: 12, width: 14, hitWidth: 8, color: i % 2 ? "#b46cff" : "#ff6fb7", hit: false });
      }
      pushRing(state, boss.x, boss.y, 420, 720, "#b46cff");
      burst(boss.x, boss.y, "#b46cff", 30);
    }
    boss.rage = 520;
    boss.ability = Math.max(860, 1700 - Math.min(620, state.wave * 34));
    sfx(pattern === 3 ? "bomb" : "thunder");
  }

  function damageMult(state) {
    return 1 + state.weapons.might * 0.18;
  }

  function cooldownMult(state) {
    return Math.max(0.5, 1 - state.weapons.cooldown * 0.08);
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function finitePoint(entity) {
    return entity && Number.isFinite(entity.x) && Number.isFinite(entity.y);
  }

  function distanceSq(ax, ay, bx, by) {
    const dx = ax - bx;
    const dy = ay - by;
    return dx * dx + dy * dy;
  }

  function compactSurvivorCollections(state, canvas) {
    const viewLimit = Math.max(canvas.width, canvas.height);
    const keepSq = viewLimit * viewLimit * (state.bossActive ? 1.35 : 1.18);
    const player = state.player;
    const keepBoss = (enemy) => enemy.boss || distanceSq(enemy.x, enemy.y, player.x, player.y) < keepSq;
    const maxEnemies = state.bossActive ? perfCaps.bossEnemies : perfCaps.enemies;
    state.enemies = state.enemies.filter((enemy) => finitePoint(enemy) && keepBoss(enemy)).slice(-maxEnemies);
    state.shots = state.shots.filter((shot) => Number.isFinite(shot.x) && Number.isFinite(shot.y) && shot.life > 0).slice(-perfCaps.shots);
    state.hazards = state.hazards.filter((hazard) => hazard.life > 0).slice(-perfCaps.hazards);
    state.gems = state.gems.filter((gem) => finitePoint(gem) && distanceSq(gem.x, gem.y, player.x, player.y) < keepSq * 1.25).slice(-perfCaps.gems);
    state.potions = state.potions.filter((potion) => finitePoint(potion) && potion.life > 0 && distanceSq(potion.x, potion.y, player.x, player.y) < keepSq * 1.45).slice(-perfCaps.potions);
    state.beams = state.beams.filter((beam) => beam.life > 0).slice(-perfCaps.beams);
    state.bombs = state.bombs.filter((bomb) => bomb.life > 0).slice(-perfCaps.bombs);
    state.wells = state.wells.filter((well) => well.life > 0).slice(-perfCaps.wells);
  }

  function obstacleHitRadius(obstacle) {
    return (obstacle.collisionRadius || obstacle.radius) * (obstacle.scale || 1);
  }

  function collidesObstacle(state, x, y, radius = 16) {
    return (state.obstacles || []).some((obstacle) => {
      const hitRadius = obstacleHitRadius(obstacle) + radius;
      return distanceSq(x, y, obstacle.x, obstacle.y) < hitRadius * hitRadius;
    });
  }

  function segmentHitsObstacle(state, x1, y1, x2, y2, padding = 0) {
    if (![x1, y1, x2, y2].every(Number.isFinite)) return true;
    return (state.obstacles || []).some((obstacle) => {
      const vx = x2 - x1;
      const vy = y2 - y1;
      const lenSq = Math.max(1, vx * vx + vy * vy);
      const t = clamp(((obstacle.x - x1) * vx + (obstacle.y - y1) * vy) / lenSq, 0, 1);
      const px = x1 + vx * t;
      const py = y1 + vy * t;
      return Math.hypot(obstacle.x - px, obstacle.y - py) < obstacleHitRadius(obstacle) + padding;
    });
  }

  function visibleTargets(state, targets, x, y, padding = 8) {
    return targets.filter((target) => finitePoint(target) && !segmentHitsObstacle(state, x, y, target.x, target.y, padding));
  }

  function pushOutOfObstacles(state, entity, radius = 18) {
    (state.obstacles || []).forEach((obstacle) => {
      const dx = entity.x - obstacle.x;
      const dy = entity.y - obstacle.y;
      const dist = Math.max(0.001, Math.hypot(dx, dy));
      const minDist = obstacleHitRadius(obstacle) + radius;
      if (dist < minDist) {
        entity.x = obstacle.x + (dx / dist) * minDist;
        entity.y = obstacle.y + (dy / dist) * minDist;
      }
    });
    const world = state.world || worldConfig;
    entity.x = clamp(entity.x, radius, world.width - radius);
    entity.y = clamp(entity.y, radius, world.height - radius);
  }

  function roundedCanvasRect(ctx, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + r);
    ctx.lineTo(x + width, y + height - r);
    ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    ctx.lineTo(x + r, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
  }

  function movePlayer(state, dx, dy) {
    const player = state.player;
    const radius = 24;
    if (dx) {
      player.x += dx;
      pushOutOfObstacles(state, player, radius);
    }
    if (dy) {
      player.y += dy;
      pushOutOfObstacles(state, player, radius);
    }
  }

  function spawnPotion(state, canvas) {
    if (!state || state.potions.length >= perfCaps.potions) return;
    const world = state.world || worldConfig;
    const viewLeft = state.camera?.x ?? state.player.x - canvas.width / 2;
    const viewTop = state.camera?.y ?? state.player.y - canvas.height / 2;
    const margin = 90;
    for (let attempt = 0; attempt < 22; attempt += 1) {
      const nearView = attempt < 14;
      const x = nearView
        ? clamp(viewLeft + margin + Math.random() * Math.max(1, canvas.width - margin * 2), 42, world.width - 42)
        : 42 + Math.random() * Math.max(1, world.width - 84);
      const y = nearView
        ? clamp(viewTop + margin + Math.random() * Math.max(1, canvas.height - margin * 2), 42, world.height - 42)
        : 42 + Math.random() * Math.max(1, world.height - 84);
      const tooClose = distanceSq(x, y, state.player.x, state.player.y) < 150 * 150;
      const overlapsPotion = state.potions.some((potion) => distanceSq(x, y, potion.x, potion.y) < 95 * 95);
      if (!tooClose && !overlapsPotion && !collidesObstacle(state, x, y, 26)) {
        state.potions.push({ x, y, heal: 36, radius: 19, life: 36000, ttl: 36000, spin: Math.random() * Math.PI * 2 });
        return;
      }
    }
  }

  function makeChoices(state) {
    const pool = upgradePool
      .filter((upgrade) => Number(state.weapons[upgrade.id] || 0) < 8)
      .map((upgrade) => ({ ...upgrade, level: Number(state.weapons[upgrade.id] || 0) + 1 }))
      .sort(() => Math.random() - 0.5);
    return pool.slice(0, 3);
  }

  function syncSnapshot(state) {
    const weapons = upgradePool
      .filter((upgrade) => Number(state.weapons[upgrade.id] || 0) > 0)
      .map((upgrade) => ({ id: upgrade.id, name: upgrade.name, level: state.weapons[upgrade.id], color: upgrade.color, icon: upgrade.icon }));
    setSnapshot({
      score: state.score,
      level: state.level,
      seconds: Math.floor(state.seconds),
      kills: state.kills,
      hp: Math.max(0, Math.ceil(state.player.hp)),
      maxHp: state.player.maxHp,
      energy: Math.max(0, Math.min(100, Math.ceil(state.energy))),
      bleeding: Boolean(state.bleeding),
      playerX: state.player.x,
      playerY: state.player.y,
      xp: Math.floor(state.xp),
      nextXp: state.nextXp,
      wave: state.wave,
      weapons,
    });
  }

  function enforceBleeding(state) {
    if (!state.bleeding) return;
    const elapsed = Math.max(0, state.seconds - state.bleedStartedAt);
    const startHp = Math.max(1, state.bleedHpStart || state.player.maxHp);
    const bleedCap = Math.max(0, startHp * (1 - elapsed / 20));
    state.player.hp = Math.min(state.player.hp, bleedCap);
  }

  function enterLevelUp(state) {
    const nextChoices = makeChoices(state);
    if (!nextChoices.length) {
      setMessage("Alle Upgrades sind voll. Bonuspunkte aktiviert, Run laeuft weiter.");
      state.score += state.level * 75;
      syncSnapshot(state);
      return;
    }
    setChoices(nextChoices);
    setMessage("Level Up. Waehle dein naechstes Upgrade.");
    setGameStatus("levelup");
    levelUpFanfare();
    syncSnapshot(state);
  }

  function gainXp(state, amount) {
    if (statusRef.current !== "play" || state.over) return;
    state.xp += amount;
    while (state.xp >= state.nextXp) {
      state.xp -= state.nextXp;
      state.level += 1;
      state.nextXp = Math.floor(state.nextXp * 1.16 + 24);
      enterLevelUp(state);
      break;
    }
  }

  function recoverRun(err) {
    console.error(err);
    const state = stateRef.current;
    setLastRun({
      score: state.score || snapshot.score,
      level: state.level || snapshot.level,
      seconds: Math.floor(state.seconds || snapshot.seconds || 0),
      kills: state.kills || snapshot.kills,
    });
    keysRef.current = {};
    setChoices([]);
    setMessage("Ein Item-Effekt wurde abgefangen. Du kannst direkt neu starten, ohne die Webseite neu zu laden.");
    syncSnapshot(state);
    setGameStatus("crashed");
  }

  function updateCamera(state, canvas) {
    const camera = state.camera || { x: 0, y: 0 };
    const world = state.world || worldConfig;
    const screenX = state.player.x - camera.x;
    const screenY = state.player.y - camera.y;
    const leftEdge = canvas.width * 0.34;
    const rightEdge = canvas.width * 0.66;
    const topEdge = canvas.height * 0.32;
    const bottomEdge = canvas.height * 0.68;
    if (screenX > rightEdge) camera.x = state.player.x - rightEdge;
    if (screenX < leftEdge) camera.x = state.player.x - leftEdge;
    if (screenY > bottomEdge) camera.y = state.player.y - bottomEdge;
    if (screenY < topEdge) camera.y = state.player.y - topEdge;
    camera.x = clamp(camera.x, 0, Math.max(0, world.width - canvas.width));
    camera.y = clamp(camera.y, 0, Math.max(0, world.height - canvas.height));
    state.camera = camera;
  }

  function spawnBoss(state, canvas) {
    state.enemies = [];
    state.shots = [];
    state.bombs = [];
    state.wells = [];
    state.hazards = [];
    const angle = Math.random() * Math.PI * 2;
    const distance = Math.min(canvas.width, canvas.height) * 0.58;
    const waveScale = 1 + state.wave * 0.34;
    const world = state.world || worldConfig;
    const bossX = clamp(state.player.x + Math.cos(angle) * distance, 70, world.width - 70);
    const bossY = clamp(state.player.y + Math.sin(angle) * distance, 70, world.height - 70);
    state.enemies.push({
      x: bossX,
      y: bossY,
      hp: 780 * waveScale,
      maxHp: 780 * waveScale,
      speed: 0.76 + state.wave * 0.045,
      radius: 68,
      elite: true,
      boss: true,
      variant: "boss",
      wobble: Math.random() * 8,
      tint: "#ffcf8a",
      ability: 900,
      phase: 0,
      rage: 0,
    });
    state.bossActive = true;
    setMessage("BOSSALARM. Das Vieh geht jetzt komplett steil.");
    pushRing(state, state.player.x, state.player.y, 560, 980, "#ffcf8a");
    pushRing(state, bossX, bossY, 340, 820, "#ff6fb7");
    sfx("nova");
  }

  function spawnEnemy(state, canvas) {
    const world = state.world || worldConfig;
    const viewLeft = state.camera?.x ?? state.player.x - canvas.width / 2;
    const viewTop = state.camera?.y ?? state.player.y - canvas.height / 2;
    let edge = null;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const side = Math.floor(Math.random() * 4);
      const candidate = [
        { x: viewLeft - 80, y: viewTop + Math.random() * canvas.height },
        { x: viewLeft + canvas.width + 80, y: viewTop + Math.random() * canvas.height },
        { x: viewLeft + Math.random() * canvas.width, y: viewTop - 80 },
        { x: viewLeft + Math.random() * canvas.width, y: viewTop + canvas.height + 80 },
      ][side];
      candidate.x = clamp(candidate.x, 24, world.width - 24);
      candidate.y = clamp(candidate.y, 24, world.height - 24);
      if (!collidesObstacle(state, candidate.x, candidate.y, 22)) {
        edge = candidate;
        break;
      }
    }
    if (!edge) edge = { x: clamp(state.player.x + 420, 24, world.width - 24), y: clamp(state.player.y, 24, world.height - 24) };
    const elite = Math.random() < Math.min(0.24, state.seconds / 210);
    const waveScale = 1 + state.wave * 0.17;
    const variants = ["green", "pink", "blue", "gold"];
    state.enemies.push({
      ...edge,
      hp: elite ? 48 * waveScale : 20 * waveScale,
      maxHp: elite ? 48 * waveScale : 20 * waveScale,
      speed: (elite ? 0.96 : 1.42) + state.wave * 0.055,
      radius: elite ? 19 : 12,
      elite,
      boss: false,
      variant: elite ? "elite" : variants[Math.floor(Math.random() * variants.length)],
      wobble: Math.random() * 8,
      tint: elite ? "#b46cff" : "#ff6fb7",
      ability: 0,
    });
  }

  const spriteMap = {
    chicken: { x: 38, y: 24, w: 286, h: 354 },
    alienGreen: { x: 396, y: 125, w: 224, h: 236 },
    alienPink: { x: 678, y: 86, w: 226, h: 278 },
    alienBlue: { x: 957, y: 98, w: 230, h: 270 },
    alienGold: { x: 1194, y: 108, w: 248, h: 258 },
    alienElite: { x: 228, y: 410, w: 392, h: 318 },
    alienBoss: { x: 668, y: 383, w: 548, h: 326 },
    laser: { x: 24, y: 774, w: 184, h: 134 },
    feather: { x: 238, y: 734, w: 184, h: 244 },
    egg: { x: 430, y: 743, w: 178, h: 184 },
    thunder: { x: 622, y: 756, w: 174, h: 188 },
    gravity: { x: 805, y: 760, w: 178, h: 156 },
    frost: { x: 1010, y: 732, w: 170, h: 236 },
    orbit: { x: 1192, y: 760, w: 178, h: 166 },
    nova: { x: 1378, y: 760, w: 144, h: 160 },
  };

  const obstacleSpriteMap = {
    starAmber: { x: 0, y: 110, w: 418, h: 470, aspect: 1.0, glow: "#ffcf8a" },
    starBlue: { x: 418, y: 122, w: 418, h: 452, aspect: 1.0, glow: "#7af4dc" },
    shipScout: { x: 836, y: 158, w: 418, h: 326, aspect: 1.48, glow: "#7af4dc" },
    shipWreck: { x: 0, y: 660, w: 418, h: 404, aspect: 1.42, glow: "#ff6fb7" },
    satellite: { x: 418, y: 642, w: 418, h: 438, aspect: 1.1, glow: "#9bf6ff" },
    mine: { x: 836, y: 650, w: 418, h: 438, aspect: 1.0, glow: "#ff6fb7" },
  };

  function getSprite(name) {
    const sheet = spriteRef.current;
    if (!sheet?.complete || !sheet.naturalWidth) return null;
    const rect = spriteMap[name];
    if (!rect) return null;
    return { sheet, rect };
  }

  function drawSprite(ctx, name, x, y, width, height, options = {}) {
    const asset = getSprite(name);
    if (!asset) return false;
    if (![x, y, width, height].every(Number.isFinite) || width <= 0 || height <= 0) return false;
    const { sheet, rect } = asset;
    ctx.save();
    ctx.translate(x, y);
    if (options.rotate) ctx.rotate(options.rotate);
    if (options.flip) ctx.scale(-1, 1);
    if (options.alpha != null) ctx.globalAlpha = options.alpha;
    ctx.shadowBlur = options.shadowBlur ?? 0;
    ctx.shadowColor = options.shadowColor || "transparent";
    ctx.drawImage(sheet, rect.x, rect.y, rect.w, rect.h, -width / 2, -height / 2, width, height);
    ctx.restore();
    return true;
  }

  function drawObstacleSprite(ctx, obstacle, visualRadius, frame) {
    const sheet = obstacleArtRef.current;
    const rect = obstacleSpriteMap[obstacle.type];
    if (!sheet?.complete || !sheet.naturalWidth || !rect) return false;
    const pulse = 1 + Math.sin(frame / 45 + obstacle.x * 0.01) * 0.025;
    const width = visualRadius * 2 * (rect.aspect || 1) * pulse;
    const height = visualRadius * 2 * pulse;
    if (![width, height].every(Number.isFinite) || width <= 0 || height <= 0) return false;
    ctx.save();
    ctx.shadowBlur = obstacle.type.includes("star") ? 42 : 30;
    ctx.shadowColor = rect.glow || obstacle.color;
    ctx.drawImage(sheet, rect.x, rect.y, rect.w, rect.h, -width / 2, -height / 2, width, height);
    ctx.globalAlpha = 0.2;
    ctx.strokeStyle = rect.glow || obstacle.color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, 0, obstacle.collisionRadius || obstacle.radius || 40, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    return true;
  }

  function roundedRect(ctx, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + r);
    ctx.lineTo(x + width, y + height - r);
    ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    ctx.lineTo(x + r, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
  }

  function drawCanvasMeter(ctx, x, y, width, height, pct, label, value, colors, frame, danger = false) {
    const safePct = clamp(Number.isFinite(pct) ? pct : 0, 0, 1);
    const fillWidth = Math.max(0, (width - 8) * safePct);
    ctx.save();
    ctx.shadowBlur = danger ? 24 + Math.sin(frame / 5) * 8 : 18;
    ctx.shadowColor = danger ? "rgba(255, 44, 73, 0.75)" : colors.glow;
    roundedRect(ctx, x, y, width, height, 8);
    const back = ctx.createLinearGradient(x, y, x, y + height);
    back.addColorStop(0, "rgba(255,255,255,0.13)");
    back.addColorStop(0.48, "rgba(12,12,22,0.82)");
    back.addColorStop(1, "rgba(0,0,0,0.74)");
    ctx.fillStyle = back;
    ctx.fill();
    ctx.shadowBlur = 0;

    roundedRect(ctx, x + 4, y + 4, width - 8, height - 8, 6);
    ctx.fillStyle = "rgba(0,0,0,0.48)";
    ctx.fill();

    if (fillWidth > 0) {
      ctx.save();
      roundedRect(ctx, x + 4, y + 4, width - 8, height - 8, 6);
      ctx.clip();
      const fill = ctx.createLinearGradient(x + 4, y, x + width - 4, y);
      fill.addColorStop(0, colors.start);
      fill.addColorStop(0.56, colors.mid);
      fill.addColorStop(1, colors.end);
      ctx.fillStyle = fill;
      ctx.fillRect(x + 4, y + 4, fillWidth, height - 8);
      ctx.globalAlpha = 0.22;
      for (let sx = x + 4 - ((frame * 1.4) % 32); sx < x + 4 + fillWidth + 32; sx += 32) {
        ctx.fillStyle = "#fff4e9";
        ctx.beginPath();
        ctx.moveTo(sx, y + 4);
        ctx.lineTo(sx + 12, y + 4);
        ctx.lineTo(sx - 2, y + height - 4);
        ctx.lineTo(sx - 14, y + height - 4);
        ctx.closePath();
        ctx.fill();
      }
      ctx.restore();
    }

    ctx.strokeStyle = danger ? "rgba(255,255,255,0.58)" : "rgba(255,218,184,0.34)";
    ctx.lineWidth = 1.4;
    roundedRect(ctx, x, y, width, height, 8);
    ctx.stroke();
    ctx.fillStyle = "#fff4e9";
    ctx.font = "900 11px Inter, system-ui, sans-serif";
    ctx.textBaseline = "middle";
    ctx.shadowBlur = 12;
    ctx.shadowColor = colors.glow;
    ctx.fillText(label, x + 12, y + height / 2);
    ctx.textAlign = "right";
    ctx.fillText(value, x + width - 12, y + height / 2);
    ctx.restore();
  }

  function drawSurvivorHudBars(ctx, canvas, state, frame) {
    const player = state.player;
    const x = 22;
    const y = canvas.height - 128;
    const width = Math.min(330, canvas.width - 44);
    const energyPct = clamp((state.energy ?? 100) / 100, 0, 1);
    const hpPct = clamp(player.hp / Math.max(1, player.maxHp), 0, 1);
    const xpPct = clamp(state.xp / Math.max(1, state.nextXp), 0, 1);
    ctx.save();
    ctx.fillStyle = "rgba(4, 4, 12, 0.48)";
    roundedRect(ctx, x - 8, y - 10, width + 16, 116, 8);
    ctx.fill();
    ctx.strokeStyle = "rgba(255, 218, 184, 0.16)";
    ctx.stroke();
    drawCanvasMeter(ctx, x, y, width, 22, energyPct, state.bleeding ? "BLEED" : "MOVE", state.bleeding ? "ALARM" : `${Math.round(energyPct * 100)}%`, {
      start: state.bleeding ? "#ff163f" : "#ffcf33",
      mid: state.bleeding ? "#fff4e9" : "#ffe66d",
      end: state.bleeding ? "#ff5f7c" : "#5dff9a",
      glow: state.bleeding ? "rgba(255, 22, 63, 0.82)" : "rgba(255, 230, 109, 0.62)",
    }, frame, state.bleeding);
    drawCanvasMeter(ctx, x, y + 34, width, 28, hpPct, "HP", `${Math.ceil(Math.max(0, player.hp))}/${player.maxHp}`, {
      start: hpPct <= 0.22 ? "#ff163f" : "#ff3d71",
      mid: hpPct <= 0.22 ? "#fff4e9" : "#ff7f7f",
      end: hpPct <= 0.22 ? "#ffb000" : "#ffcf8a",
      glow: hpPct <= 0.22 ? "rgba(255, 30, 68, 0.82)" : "rgba(255, 95, 124, 0.56)",
    }, frame, hpPct <= 0.22);
    drawCanvasMeter(ctx, x, y + 74, width, 22, xpPct, `LVL ${state.level}`, `${state.xp}/${state.nextXp} XP`, {
      start: "#7af4dc",
      mid: "#b46cff",
      end: "#ffcf8a",
      glow: "rgba(122, 244, 220, 0.58)",
    }, frame);
    ctx.restore();
  }

  function drawUpgradeIcon(ctx, icon, x, y, size, color, frame = 0) {
    const spriteName = icon === "drone" ? "laser" : icon === "boots" ? "feather" : icon === "magnet" ? "gravity" : icon === "shield" ? "orbit" : icon === "regen" ? "egg" : icon === "might" ? "nova" : icon === "cooldown" ? "thunder" : icon;
    if (drawSprite(ctx, spriteName, x, y, size * 1.55, size * 1.55, { rotate: Math.sin(frame / 35) * 0.08, shadowBlur: 18, shadowColor: color })) return;
    ctx.save();
    ctx.translate(x, y);
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = Math.max(2, size / 16);
    ctx.shadowBlur = 16;
    ctx.shadowColor = color;
    if (icon === "feather") {
      ctx.beginPath();
      ctx.ellipse(0, 0, size * 0.18, size * 0.48, -0.75, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#fff4e9";
      ctx.beginPath();
      ctx.moveTo(-size * 0.28, size * 0.3);
      ctx.lineTo(size * 0.28, -size * 0.36);
      ctx.stroke();
    } else if (icon === "orbit") {
      for (let i = 0; i < 3; i += 1) {
        ctx.rotate(Math.PI / 3);
        ctx.beginPath();
        ctx.ellipse(0, 0, size * 0.42, size * 0.17, frame / 40 + i, 0, Math.PI * 2);
        ctx.stroke();
      }
    } else if (icon === "nova") {
      ctx.beginPath();
      ctx.arc(0, 0, size * 0.22, 0, Math.PI * 2);
      ctx.fill();
      for (let i = 0; i < 12; i += 1) {
        const a = i / 12 * Math.PI * 2;
        ctx.beginPath();
        ctx.moveTo(Math.cos(a) * size * 0.32, Math.sin(a) * size * 0.32);
        ctx.lineTo(Math.cos(a) * size * 0.52, Math.sin(a) * size * 0.52);
        ctx.stroke();
      }
    } else if (icon === "laser") {
      ctx.beginPath();
      ctx.moveTo(-size * 0.42, size * 0.22);
      ctx.lineTo(size * 0.42, -size * 0.22);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(size * 0.42, -size * 0.22, size * 0.12, 0, Math.PI * 2);
      ctx.fill();
    } else if (icon === "egg") {
      ctx.beginPath();
      ctx.ellipse(0, 0, size * 0.25, size * 0.35, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#ffcf8a";
      ctx.stroke();
    } else {
      ctx.beginPath();
      ctx.arc(0, 0, size * 0.32, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawAlien(ctx, enemy, frame) {
    const glow = enemy.slow > 0 ? "#9bf6ff" : enemy.tint || (enemy.elite ? "#b46cff" : "#ff6fb7");
    const spriteName = enemy.variant === "boss" ? "alienBoss" : enemy.variant === "elite" ? "alienElite" : `alien${(enemy.variant || "pink").replace(/^./, (char) => char.toUpperCase())}`;
    const bob = Math.sin(frame / 14 + enemy.wobble) * (enemy.boss ? 3 : 2);
    const spriteW = enemy.boss ? enemy.radius * 5.4 : enemy.elite ? enemy.radius * 4.1 : enemy.radius * 3.6;
    const spriteH = enemy.boss ? enemy.radius * 3.45 : enemy.elite ? enemy.radius * 3.25 : enemy.radius * 3.35;
    ctx.save();
    ctx.translate(enemy.x, enemy.y + bob);
    ctx.rotate(Math.sin(frame / 22 + enemy.wobble) * 0.08);
    if (enemy.boss) {
      const rageAlpha = enemy.rage > 0 ? 0.6 : 0.34;
      ctx.save();
      ctx.globalAlpha = rageAlpha;
      ctx.strokeStyle = enemy.rage > 0 ? "#ffcf8a" : "#ff6fb7";
      ctx.lineWidth = enemy.rage > 0 ? 5 : 3;
      ctx.shadowBlur = 38;
      ctx.shadowColor = enemy.rage > 0 ? "#ffcf8a" : "#ff6fb7";
      for (let i = 0; i < 3; i += 1) {
        ctx.rotate(frame / (140 + i * 45));
        ctx.beginPath();
        ctx.ellipse(0, 0, enemy.radius * (1.25 + i * 0.22), enemy.radius * (0.58 + i * 0.1), 0, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.restore();
    }
    if (enemy.slow > 0) {
      ctx.globalAlpha = 0.34;
      ctx.fillStyle = "#9bf6ff";
      ctx.shadowBlur = 26;
      ctx.shadowColor = "#9bf6ff";
      ctx.beginPath();
      ctx.arc(0, 0, Math.max(spriteW, spriteH) * 0.36, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
    }
    const usedSprite = drawSprite(ctx, spriteName, 0, 0, spriteW, spriteH, { shadowBlur: enemy.boss ? 38 : enemy.elite ? 28 : 20, shadowColor: glow });
    ctx.restore();
    if (usedSprite) {
      if (enemy.hp < enemy.maxHp) {
        const pct = Math.max(0, enemy.hp / enemy.maxHp);
        ctx.save();
        ctx.shadowBlur = 0;
        ctx.fillStyle = "rgba(2,4,11,.78)";
        ctx.fillRect(enemy.x - enemy.radius * 1.35, enemy.y - spriteH * 0.58, enemy.radius * 2.7, 4);
        ctx.fillStyle = glow;
        ctx.fillRect(enemy.x - enemy.radius * 1.35, enemy.y - spriteH * 0.58, enemy.radius * 2.7 * pct, 4);
        ctx.restore();
      }
      if (enemy.boss) {
        ctx.save();
        ctx.globalAlpha = 0.74;
        ctx.fillStyle = "#ffcf8a";
        ctx.font = "950 12px Inter, Arial";
        ctx.textAlign = "center";
        ctx.shadowBlur = 14;
        ctx.shadowColor = "#ff6fb7";
        ctx.fillText("BOSS", enemy.x, enemy.y - spriteH * 0.66);
        ctx.restore();
      }
      return;
    }
    const scale = enemy.boss ? 1.35 : enemy.elite ? 1.08 : 1;
    ctx.save();
    ctx.translate(enemy.x, enemy.y);
    ctx.rotate(Math.sin(frame / 22 + enemy.wobble) * 0.18);
    ctx.scale(scale, scale);
    ctx.shadowBlur = enemy.boss ? 34 : enemy.elite ? 24 : 17;
    ctx.shadowColor = glow;

    const body = ctx.createRadialGradient(-5, -6, 4, 0, 0, enemy.radius * 1.45);
    body.addColorStop(0, enemy.slow > 0 ? "#dcfbff" : "#f7d5ff");
    body.addColorStop(0.34, enemy.slow > 0 ? "#7af4dc" : enemy.elite ? "#9f63ff" : "#ff6fb7");
    body.addColorStop(1, enemy.boss ? "#5a2418" : "#2b1232");
    ctx.fillStyle = body;
    ctx.beginPath();
    ctx.ellipse(0, 0, enemy.radius * 1.18, enemy.radius * 0.92, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,244,233,.72)";
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.fillStyle = "#0b0610";
    ctx.beginPath();
    ctx.ellipse(-enemy.radius * 0.34, -enemy.radius * 0.12, enemy.radius * 0.22, enemy.radius * 0.34, -0.18, 0, Math.PI * 2);
    ctx.ellipse(enemy.radius * 0.34, -enemy.radius * 0.12, enemy.radius * 0.22, enemy.radius * 0.34, 0.18, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#fff4e9";
    ctx.beginPath();
    ctx.arc(-enemy.radius * 0.4, -enemy.radius * 0.22, 2.2, 0, Math.PI * 2);
    ctx.arc(enemy.radius * 0.28, -enemy.radius * 0.22, 2.2, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = glow;
    ctx.lineWidth = 2.2;
    for (let i = 0; i < 4; i += 1) {
      const side = i < 2 ? -1 : 1;
      const y = -enemy.radius * 0.2 + (i % 2) * enemy.radius * 0.52;
      ctx.beginPath();
      ctx.moveTo(side * enemy.radius * 0.8, y);
      ctx.quadraticCurveTo(side * enemy.radius * 1.35, y + Math.sin(frame / 15 + i) * 8, side * enemy.radius * 1.55, y + enemy.radius * 0.55);
      ctx.stroke();
    }

    if (enemy.hp < enemy.maxHp) {
      const pct = Math.max(0, enemy.hp / enemy.maxHp);
      ctx.shadowBlur = 0;
      ctx.fillStyle = "rgba(2,4,11,.78)";
      ctx.fillRect(-enemy.radius * 1.25, -enemy.radius * 1.65, enemy.radius * 2.5, 4);
      ctx.fillStyle = glow;
      ctx.fillRect(-enemy.radius * 1.25, -enemy.radius * 1.65, enemy.radius * 2.5 * pct, 4);
    }
    ctx.restore();
  }

  function drawPlayerFace(ctx, x, y, scale = 1) {
    const face = playerFaceRef.current;
    if (!face?.complete || !face.naturalWidth) return false;

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);

    ctx.shadowBlur = 18;
    ctx.shadowColor = "rgba(255,207,138,.48)";
    const featherBase = ctx.createRadialGradient(0, 18, 6, 0, 13, 36);
    featherBase.addColorStop(0, "#fff7dc");
    featherBase.addColorStop(0.48, "#ffcf8a");
    featherBase.addColorStop(1, "#8f573f");
    ctx.fillStyle = featherBase;
    ctx.beginPath();
    ctx.ellipse(0, 17, 30, 19, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#fff4e9";
    for (let i = -2; i <= 2; i += 1) {
      ctx.beginPath();
      ctx.ellipse(i * 10, 18 + Math.abs(i) * 2, 8, 18, i * 0.18, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);
    ctx.shadowBlur = 18;
    ctx.shadowColor = "rgba(255,207,138,.62)";
    ctx.beginPath();
    ctx.ellipse(0, -2, 26, 30, 0, 0, Math.PI * 2);
    ctx.clip();
    const size = Math.min(face.naturalWidth, face.naturalHeight);
    const sx = (face.naturalWidth - size) / 2;
    const sy = Math.max(0, (face.naturalHeight - size) * 0.16);
    ctx.drawImage(face, sx, sy, size, size, -30, -36, 60, 66);
    ctx.globalCompositeOperation = "source-atop";
    const shade = ctx.createLinearGradient(-24, -34, 24, 30);
    shade.addColorStop(0, "rgba(255,244,233,.16)");
    shade.addColorStop(0.45, "rgba(255,207,138,.04)");
    shade.addColorStop(1, "rgba(40,8,18,.24)");
    ctx.fillStyle = shade;
    ctx.fillRect(-31, -37, 62, 68);
    ctx.restore();

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);
    ctx.shadowBlur = 14;
    ctx.shadowColor = "#7af4dc";
    const glass = ctx.createRadialGradient(-11, -18, 3, 0, -3, 35);
    glass.addColorStop(0, "rgba(255,255,255,.5)");
    glass.addColorStop(0.28, "rgba(122,244,220,.16)");
    glass.addColorStop(1, "rgba(122,244,220,.02)");
    ctx.fillStyle = glass;
    ctx.beginPath();
    ctx.ellipse(0, -2, 31, 34, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(222,248,255,.88)";
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.ellipse(0, -2, 31, 34, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeStyle = "rgba(255,255,255,.56)";
    ctx.lineWidth = 3.2;
    ctx.beginPath();
    ctx.arc(-9, -16, 13, Math.PI * 1.05, Math.PI * 1.55);
    ctx.stroke();
    ctx.restore();
    return true;
  }

  function drawAstronautChicken(ctx, player, frame) {
    const bob = Math.sin(frame / 18) * 2;
    const playerArt = playerArtRef.current;
    if (playerArt?.complete && playerArt.naturalWidth) {
      const pulse = player.invuln > 0 ? 1 + Math.sin(frame / 4) * 0.04 : 1;
      const width = 94 * pulse;
      const height = 112 * pulse;
      ctx.save();
      ctx.translate(player.x, player.y + bob);
      ctx.shadowBlur = player.invuln > 0 ? 42 : 28;
      ctx.shadowColor = player.invuln > 0 ? "#fff4e9" : "#ffcf8a";
      ctx.drawImage(playerArt, -width / 2, -height * 0.68, width, height);
      ctx.strokeStyle = player.invuln > 0 ? "rgba(255,244,233,.9)" : "rgba(122,244,220,.32)";
      ctx.lineWidth = player.invuln > 0 ? 3 : 1.6;
      ctx.beginPath();
      ctx.ellipse(2, -37, 28 * pulse, 32 * pulse, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
      return;
    }
    if (drawSprite(ctx, "chicken", player.x, player.y + bob, 72, 90, { shadowBlur: 34, shadowColor: player.invuln > 0 ? "#fff4e9" : "#ffcf8a" })) {
      drawPlayerFace(ctx, player.x + 4, player.y + bob - 22, 0.84, frame);
      ctx.save();
      ctx.strokeStyle = player.invuln > 0 ? "rgba(255,244,233,.9)" : "rgba(122,244,220,.48)";
      ctx.lineWidth = player.invuln > 0 ? 3.2 : 1.8;
      ctx.shadowBlur = 22;
      ctx.shadowColor = player.invuln > 0 ? "#fff4e9" : "#7af4dc";
      ctx.beginPath();
      ctx.ellipse(player.x + 3, player.y + bob - 18, 31 + Math.sin(frame / 11) * 1.6, 36, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
      return;
    }
    ctx.save();
    ctx.translate(player.x, player.y);
    ctx.shadowBlur = 34;
    ctx.shadowColor = player.invuln > 0 ? "#fff4e9" : "#ffcf8a";

    const suit = ctx.createLinearGradient(-26, -20, 26, 24);
    suit.addColorStop(0, "#fff7dc");
    suit.addColorStop(0.48, "#ffcf8a");
    suit.addColorStop(1, "#c88956");
    ctx.fillStyle = suit;
    ctx.beginPath();
    ctx.ellipse(0, 10, 22, 18, Math.sin(frame / 14) * 0.06, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#fff4e9";
    ctx.beginPath();
    ctx.arc(7, -8, 13, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ff9f6e";
    ctx.beginPath();
    ctx.moveTo(19, -9);
    ctx.lineTo(33, -4);
    ctx.lineTo(19, 2);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#140912";
    ctx.beginPath();
    ctx.arc(10, -12, 2.5, 0, Math.PI * 2);
    ctx.fill();
    drawPlayerFace(ctx, 6, -10, 0.74, frame);

    const helmet = ctx.createRadialGradient(-10, -18, 3, 3, -9, 30);
    helmet.addColorStop(0, "rgba(255,255,255,.62)");
    helmet.addColorStop(0.35, "rgba(122,244,220,.18)");
    helmet.addColorStop(1, "rgba(122,244,220,.04)");
    ctx.fillStyle = helmet;
    ctx.beginPath();
    ctx.arc(3, -5, 29, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(222,248,255,.86)";
    ctx.lineWidth = 2.4;
    ctx.stroke();
    ctx.strokeStyle = "rgba(255,255,255,.55)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(-5, -14, 12, Math.PI * 1.05, Math.PI * 1.55);
    ctx.stroke();

    ctx.strokeStyle = "rgba(255,207,138,.38)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(0, 1, 36 + Math.sin(frame / 10) * 3, 28, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function drawWeaponProjectile(ctx, shot, frame) {
    const angle = Math.atan2(shot.vy, shot.vx) + Math.PI / 2;
    const spriteName = shot.type === "drone" ? "laser" : stateRef.current.weapons.frost ? "frost" : "feather";
    const color = shot.type === "drone" ? "#8f7bff" : stateRef.current.weapons.frost ? "#9bf6ff" : "#ffcf8a";
    ctx.save();
    ctx.strokeStyle = shot.type === "drone" ? "rgba(143,123,255,.36)" : "rgba(255,207,138,.34)";
    ctx.lineWidth = shot.type === "drone" ? 9 : 7;
    ctx.shadowBlur = 24;
    ctx.shadowColor = color;
    ctx.beginPath();
    ctx.moveTo(shot.x - shot.vx * 3.2, shot.y - shot.vy * 3.2);
    ctx.lineTo(shot.x, shot.y);
    ctx.stroke();
    ctx.restore();
    if (drawSprite(ctx, spriteName, shot.x, shot.y, shot.type === "drone" ? 42 : 34, shot.type === "drone" ? 28 : 48, { rotate: angle, shadowBlur: 18, shadowColor: color })) return;
    ctx.strokeStyle = color;
    ctx.lineWidth = shot.type === "drone" ? 3 : 4;
    ctx.beginPath();
    ctx.moveTo(shot.x - shot.vx * 1.5, shot.y - shot.vy * 1.5);
    ctx.lineTo(shot.x, shot.y);
    ctx.stroke();
  }

  function drawWorldBackdrop(ctx, canvas, state, frame) {
    const camera = state.camera || { x: 0, y: 0 };
    const world = state.world || worldConfig;
    const bgImage = bgRef.current;
    if (bgImage?.complete && bgImage.naturalWidth) {
      const scale = Math.max(canvas.width / bgImage.naturalWidth, canvas.height / bgImage.naturalHeight) * 0.82;
      const tileW = bgImage.naturalWidth * scale;
      const tileH = bgImage.naturalHeight * scale;
      const startX = Math.floor(camera.x / tileW) * tileW - camera.x;
      const startY = Math.floor(camera.y / tileH) * tileH - camera.y;
      for (let x = startX; x < canvas.width + tileW; x += tileW) {
        for (let y = startY; y < canvas.height + tileH; y += tileH) {
          ctx.drawImage(bgImage, x, y, tileW, tileH);
        }
      }
      ctx.fillStyle = "rgba(2,4,11,.22)";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    } else {
      const bg = ctx.createRadialGradient(canvas.width * 0.55, canvas.height * 0.42, 30, canvas.width * 0.5, canvas.height * 0.5, canvas.width);
      bg.addColorStop(0, "#311745");
      bg.addColorStop(0.24, "#17091f");
      bg.addColorStop(0.58, "#070913");
      bg.addColorStop(1, "#02040b");
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    ctx.save();
    for (let i = 0; i < 240; i += 1) {
      const x = (i * 379) % world.width - camera.x;
      const y = (i * 223 + Math.sin(frame / 70 + i) * 5) % world.height - camera.y;
      if (x < -4 || y < -4 || x > canvas.width + 4 || y > canvas.height + 4) continue;
      const size = i % 13 === 0 ? 2.4 : i % 7 === 0 ? 1.6 : 0.9;
      ctx.fillStyle = i % 9 ? "rgba(255,244,233,.58)" : "rgba(122,244,220,.7)";
      ctx.globalAlpha = 0.26 + (i % 6) * 0.08;
      ctx.fillRect(x, y, size, size);
    }
    ctx.restore();

    ctx.save();
    const left = -camera.x;
    const top = -camera.y;
    ctx.strokeStyle = "rgba(255,207,138,.18)";
    ctx.lineWidth = 8;
    ctx.strokeRect(left, top, world.width, world.height);
    ctx.restore();
  }

  function drawObstacle(ctx, obstacle, frame) {
    const visualRadius = obstacle.visualRadius || obstacle.radius;
    const collisionRadius = obstacle.collisionRadius || obstacle.radius;
    ctx.save();
    ctx.translate(obstacle.x, obstacle.y);
    ctx.rotate(obstacle.rotation + Math.sin(frame / 160 + obstacle.x) * 0.015);
    ctx.scale(obstacle.scale || 1, obstacle.scale || 1);
    if (drawObstacleSprite(ctx, obstacle, visualRadius, frame)) {
      ctx.restore();
      return;
    }
    ctx.shadowBlur = obstacle.type === "star" ? 46 : 32;
    ctx.shadowColor = obstacle.type === "ship" ? "#7af4dc" : obstacle.type === "wreck" ? "#ff6fb7" : obstacle.color;
    if (obstacle.type.includes("ship") || obstacle.type.includes("Wreck") || obstacle.type === "satellite") {
      const length = visualRadius * 1.6;
      const height = visualRadius * 0.7;
      const hull = ctx.createLinearGradient(-length * 0.75, -height * 0.45, length * 0.7, height * 0.38);
      hull.addColorStop(0, "#d7e8ff");
      hull.addColorStop(0.18, obstacle.color);
      hull.addColorStop(0.6, "#243141");
      hull.addColorStop(1, obstacle.type === "wreck" ? "#3d1825" : "#132b35");
      ctx.fillStyle = hull;
      ctx.beginPath();
      ctx.moveTo(length * 0.7, 0);
      ctx.lineTo(length * 0.18, -height * 0.48);
      ctx.lineTo(-length * 0.58, -height * 0.32);
      ctx.lineTo(-length * 0.82, height * 0.08);
      ctx.lineTo(-length * 0.34, height * 0.46);
      ctx.lineTo(length * 0.46, height * 0.32);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = "rgba(255,244,233,.58)";
      ctx.lineWidth = 3.2;
      ctx.stroke();

      const cockpit = ctx.createRadialGradient(length * 0.16, -height * 0.06, 2, length * 0.16, -height * 0.06, height * 0.34);
      cockpit.addColorStop(0, "#effff8");
      cockpit.addColorStop(0.4, "#7af4dc");
      cockpit.addColorStop(1, "rgba(122,244,220,.08)");
      ctx.fillStyle = cockpit;
      ctx.beginPath();
      ctx.ellipse(length * 0.1, -height * 0.08, length * 0.18, height * 0.18, 0.12, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = obstacle.type === "wreck" ? "rgba(255,111,183,.55)" : "rgba(122,244,220,.52)";
      ctx.lineWidth = 4;
      for (let i = 0; i < 3; i += 1) {
        ctx.beginPath();
        ctx.moveTo(-length * 0.5 + i * length * 0.22, -height * 0.22);
        ctx.lineTo(-length * 0.36 + i * length * 0.2, height * 0.28);
        ctx.stroke();
      }

      ctx.fillStyle = obstacle.type === "wreck" ? "rgba(255,111,183,.48)" : "rgba(255,207,138,.72)";
      ctx.beginPath();
      ctx.moveTo(-length * 0.78, -height * 0.14);
      ctx.lineTo(-length * 1.02, 0);
      ctx.lineTo(-length * 0.78, height * 0.14);
      ctx.closePath();
      ctx.fill();

      ctx.strokeStyle = obstacle.type === "wreck" ? "rgba(255,111,183,.28)" : "rgba(122,244,220,.26)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.ellipse(0, 0, collisionRadius, collisionRadius * 0.52, 0, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      const points = 10;
      const pulse = 1 + Math.sin(frame / 36 + obstacle.x) * 0.04;
      const glow = ctx.createRadialGradient(0, 0, 8, 0, 0, visualRadius * 1.35);
      glow.addColorStop(0, "rgba(255,244,233,.92)");
      glow.addColorStop(0.24, obstacle.color);
      glow.addColorStop(0.58, "rgba(180,108,255,.3)");
      glow.addColorStop(1, "rgba(122,244,220,0)");
      ctx.globalAlpha = 0.92;
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(0, 0, visualRadius * 1.12 * pulse, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;

      const crystal = ctx.createLinearGradient(-visualRadius, -visualRadius, visualRadius, visualRadius);
      crystal.addColorStop(0, "#fff4e9");
      crystal.addColorStop(0.32, obstacle.color);
      crystal.addColorStop(0.72, "#7af4dc");
      crystal.addColorStop(1, "#2a102d");
      ctx.fillStyle = crystal;
      ctx.beginPath();
      for (let i = 0; i < points * 2; i += 1) {
        const a = i / (points * 2) * Math.PI * 2;
        const r = i % 2 === 0 ? visualRadius * 0.82 : visualRadius * 0.34;
        const x = Math.cos(a) * r;
        const y = Math.sin(a) * r;
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = "rgba(255,244,233,.78)";
      ctx.lineWidth = 2.8;
      ctx.stroke();

      ctx.strokeStyle = "rgba(255,244,233,.32)";
      ctx.lineWidth = 1.4;
      for (let i = 0; i < 4; i += 1) {
        ctx.rotate(Math.PI / 4);
        ctx.beginPath();
        ctx.ellipse(0, 0, visualRadius * 0.96, visualRadius * 0.18, frame / 180, 0, Math.PI * 2);
        ctx.stroke();
      }

      ctx.fillStyle = "#fff4e9";
      ctx.beginPath();
      ctx.arc(-visualRadius * 0.16, -visualRadius * 0.18, visualRadius * 0.08, 0, Math.PI * 2);
      ctx.arc(visualRadius * 0.18, visualRadius * 0.1, visualRadius * 0.06, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = "rgba(255,244,233,.28)";
      ctx.lineWidth = 2;
      ctx.shadowBlur = 16;
      ctx.shadowColor = obstacle.color;
      ctx.beginPath();
      ctx.arc(0, 0, collisionRadius, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  const canvasRef = useCanvasGame((ctx, canvas, dt, frame) => {
    const state = stateRef.current;
    const isPlaying = statusRef.current === "play";
    musicTick();
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    drawWorldBackdrop(ctx, canvas, state, frame);

    ctx.save();
    const nebulaA = ctx.createRadialGradient(canvas.width * 0.2, canvas.height * 0.75, 20, canvas.width * 0.22, canvas.height * 0.72, 520);
    nebulaA.addColorStop(0, "rgba(180,108,255,.28)");
    nebulaA.addColorStop(0.38, "rgba(255,111,183,.13)");
    nebulaA.addColorStop(1, "rgba(255,111,183,0)");
    ctx.fillStyle = nebulaA;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    const nebulaB = ctx.createRadialGradient(canvas.width * 0.82, canvas.height * 0.22, 10, canvas.width * 0.82, canvas.height * 0.22, 390);
    nebulaB.addColorStop(0, "rgba(122,244,220,.18)");
    nebulaB.addColorStop(0.42, "rgba(180,108,255,.09)");
    nebulaB.addColorStop(1, "rgba(122,244,220,0)");
    ctx.fillStyle = nebulaB;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.restore();

    ctx.save();
    for (let i = 0; i < 150; i += 1) {
      const speed = (i % 5) + 0.2;
      const x = (i * 97 + frame * speed * 0.12 - (state.camera?.x || 0) * 0.08) % canvas.width;
      const y = (i * 53 + Math.sin(frame / 70 + i) * 7 - (state.camera?.y || 0) * 0.08) % canvas.height;
      const size = i % 11 === 0 ? 2.2 : i % 7 === 0 ? 1.5 : 0.9;
      ctx.fillStyle = i % 9 ? "rgba(255,244,233,.58)" : "rgba(122,244,220,.7)";
      ctx.globalAlpha = 0.28 + (i % 6) * 0.09;
      ctx.fillRect(x, y, size, size);
    }
    ctx.restore();

    ctx.save();
    ctx.translate(118, canvas.height - 86);
    const planet = ctx.createRadialGradient(-18, -22, 4, 0, 0, 95);
    planet.addColorStop(0, "#f5b06c");
    planet.addColorStop(0.48, "#7f493a");
    planet.addColorStop(1, "#25111b");
    ctx.fillStyle = planet;
    ctx.globalAlpha = 0.82;
    ctx.beginPath();
    ctx.arc(0, 0, 86, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,207,138,.2)";
    ctx.stroke();
    ctx.restore();

    ctx.save();
    for (let i = 0; i < 24; i += 1) {
      const x = (i * 187 - frame * (0.22 + i % 3 * 0.05)) % (canvas.width + 90) - 45;
      const y = (i * 73 + Math.sin(frame / 55 + i) * 14) % canvas.height;
      ctx.translate(x, y);
      ctx.rotate(frame / 220 + i);
      ctx.fillStyle = "rgba(88,57,53,.72)";
      ctx.beginPath();
      ctx.moveTo(-10, -5);
      ctx.lineTo(-2, -12);
      ctx.lineTo(12, -5);
      ctx.lineTo(9, 9);
      ctx.lineTo(-8, 10);
      ctx.closePath();
      ctx.fill();
      ctx.setTransform(1, 0, 0, 1, 0, 0);
    }
    ctx.restore();

    ctx.save();
    ctx.strokeStyle = "rgba(255,183,99,.2)";
    ctx.lineWidth = 1.2;
    for (let r = 110; r < 660; r += 74) {
      ctx.beginPath();
      ctx.ellipse(canvas.width / 2, canvas.height / 2, r * 1.22, r * 0.58, frame / 760, 0, Math.PI * 2);
      ctx.stroke();
    }
    for (let i = 0; i < 16; i += 1) {
      const a = i / 16 * Math.PI * 2 + frame / 1200;
      ctx.beginPath();
      ctx.moveTo(canvas.width / 2, canvas.height / 2);
      ctx.lineTo(canvas.width / 2 + Math.cos(a) * 740, canvas.height / 2 + Math.sin(a) * 340);
      ctx.stroke();
    }
    ctx.restore();

    if (isPlaying && !state.over) {
      state.seconds += dt / 1000;
      state.wave = 1 + Math.floor(state.seconds / 24);
      const speed = 3.15 + state.weapons.speed * 0.34;
      const useWasd = controlMode === "wasd";
      const mx = (useWasd ? keysRef.current.d : keysRef.current.arrowright ? 1 : 0) - (useWasd ? keysRef.current.a : keysRef.current.arrowleft ? 1 : 0);
      const my = (useWasd ? keysRef.current.s : keysRef.current.arrowdown ? 1 : 0) - (useWasd ? keysRef.current.w : keysRef.current.arrowup ? 1 : 0);
      const len = Math.max(1, Math.hypot(mx, my));
      const moving = Math.hypot(mx, my) > 0.05;
      movePlayer(state, (mx / len) * speed * (dt / 16), (my / len) * speed * (dt / 16));
      updateCamera(state, canvas);
      state.player.invuln = Math.max(0, state.player.invuln - dt);
      if ((mx || my) && frame % (state.particles.length > 170 ? 4 : 2) === 0) state.particles.push({ x: state.player.x - mx * 13, y: state.player.y - my * 13, vx: -mx * 0.5 + (Math.random() - 0.5), vy: -my * 0.5 + (Math.random() - 0.5), life: 220, ttl: 220, color: "#ffcf8a" });
      if (!state.bleeding) {
        state.energy = moving ? Math.min(100, state.energy + dt * 0.065) : Math.max(0, state.energy - dt * 0.026);
        if (state.energy <= 0) {
          state.energy = 0;
          state.bleeding = true;
          state.bleedStartedAt = state.seconds;
          state.bleedHpStart = Math.max(1, state.player.hp);
          setMessage("Unstillbare Blutung entdeckt. Bewegung kam zu spaet.");
          pushRing(state, state.player.x, state.player.y, 150, 760, "#ff163f");
          burst(state.player.x, state.player.y, "#ff163f", 32);
          bleedingAlarm();
        }
      }

      if (!state.bossActive && state.seconds >= state.nextBossAt) spawnBoss(state, canvas);

      state.spawn -= dt;
      if (!state.bossActive && state.spawn <= 0) {
        const crowdPressure = Math.max(0, state.enemies.length - 58);
        const count = crowdPressure > 18 ? 1 : 1 + Math.floor(Math.min(4, Math.max(0, state.wave - 1) / 3));
        for (let i = 0; i < count; i += 1) spawnEnemy(state, canvas);
        state.spawn = Math.max(135, 780 - state.seconds * 5.4 + crowdPressure * 8);
      }

      state.timers.potion -= dt;
      if (state.timers.potion <= 0) {
        spawnPotion(state, canvas);
        const lowHealthBoost = state.player.hp < state.player.maxHp * 0.42 ? 0.52 : 1;
        state.timers.potion = (12500 + Math.random() * 6500) * lowHealthBoost;
      }
      compactSurvivorCollections(state, canvas);

      state.timers.bolt -= dt;
      if (state.weapons.bolt && state.timers.bolt <= 0 && state.enemies.length) {
        const targetPool = state.enemies.filter((enemy) => distanceSq(enemy.x, enemy.y, state.player.x, state.player.y) < 900 * 900).slice(0, 56);
        const targets = visibleTargets(state, targetPool, state.player.x, state.player.y, 12)
          .sort((a, b) => distanceSq(a.x, a.y, state.player.x, state.player.y) - distanceSq(b.x, b.y, state.player.x, state.player.y));
        const bolts = Math.min(targets.length, 1 + Math.floor((state.weapons.bolt - 1) / 2));
        for (let i = 0; i < bolts; i += 1) {
          const target = targets[i];
          const dx = target.x - state.player.x;
          const dy = target.y - state.player.y;
          const dist = Math.max(1, Math.hypot(dx, dy));
          state.shots.push({ type: "bolt", x: state.player.x, y: state.player.y, vx: dx / dist * 10.2, vy: dy / dist * 10.2, life: 820, damage: (14 + state.weapons.bolt * 4) * damageMult(state), pierce: Math.floor(state.weapons.bolt / 3) });
        }
        state.timers.bolt = Math.max(130, (520 - state.weapons.bolt * 28) * cooldownMult(state));
        if (bolts > 0 && frame % 3 === 0) sfx("shot");
      }

      state.timers.egg -= dt;
      if (state.weapons.egg && state.timers.egg <= 0 && state.enemies.length) {
        const targets = visibleTargets(state, state.enemies.slice(0, 54), state.player.x, state.player.y, 16);
        const pool = targets.length ? targets : state.enemies.filter(finitePoint);
        const target = pool[Math.floor(Math.random() * pool.length)];
        const radius = 54 + state.weapons.egg * 8;
        const damage = (28 + state.weapons.egg * 8) * damageMult(state);
        if (finitePoint(target) && finitePoint(state.player) && Number.isFinite(radius) && Number.isFinite(damage)) {
          state.bombs.push({
            x: state.player.x,
            y: state.player.y,
            tx: target.x,
            ty: target.y,
            life: 650,
            ttl: 650,
            radius,
            damage,
            exploded: false,
          });
          sfx("bomb");
        }
        state.timers.egg = Math.max(650, (2100 - state.weapons.egg * 110) * cooldownMult(state));
      }

      state.timers.drone -= dt;
      if (state.weapons.drone && state.timers.drone <= 0 && state.enemies.length) {
        const count = Math.min(6, state.weapons.drone);
        const targets = visibleTargets(state, state.enemies.slice(0, 56), state.player.x, state.player.y, 12)
          .sort((a, b) => distanceSq(a.x, a.y, state.player.x, state.player.y) - distanceSq(b.x, b.y, state.player.x, state.player.y));
        const shots = targets.length ? count : 0;
        for (let i = 0; i < shots; i += 1) {
          const target = targets[i % targets.length];
          const angle = frame / 32 + i / count * Math.PI * 2;
          const x = state.player.x + Math.cos(angle) * 58;
          const y = state.player.y + Math.sin(angle) * 58;
          const dx = target.x - x;
          const dy = target.y - y;
          const dist = Math.max(1, Math.hypot(dx, dy));
          state.shots.push({ type: "drone", x, y, vx: dx / dist * 11.4, vy: dy / dist * 11.4, life: 720, damage: (11 + state.weapons.drone * 3.8) * damageMult(state), pierce: 0 });
        }
        state.timers.drone = Math.max(120, (660 - state.weapons.drone * 54) * cooldownMult(state));
        if (shots > 0) sfx("shot");
      }

      state.timers.thunder -= dt;
      if (state.weapons.thunder && state.timers.thunder <= 0 && state.enemies.length) {
        let ox = state.player.x;
        let oy = state.player.y;
        const chain = [];
        const pool = [...state.enemies];
        for (let step = 0; step < 2 + state.weapons.thunder && pool.length; step += 1) {
          const visible = visibleTargets(state, pool.slice(0, 58), ox, oy, 16).sort((a, b) => distanceSq(a.x, a.y, ox, oy) - distanceSq(b.x, b.y, ox, oy));
          const next = visible[0];
          if (!next) break;
          chain.push(next);
          pool.splice(pool.indexOf(next), 1);
          ox = next.x;
          oy = next.y;
        }
        ox = state.player.x;
        oy = state.player.y;
        chain.forEach((enemy, index) => {
          state.beams.push({ x1: ox, y1: oy, x2: enemy.x, y2: enemy.y, life: 190, ttl: 190, color: "#ffe66d", width: 5 - Math.min(2, index * 0.4) });
          enemy.hp -= (18 + state.weapons.thunder * 7) * damageMult(state);
          ox = enemy.x;
          oy = enemy.y;
        });
        state.timers.thunder = Math.max(720, (2700 - state.weapons.thunder * 160) * cooldownMult(state));
        sfx("thunder");
      }

      state.timers.gravity -= dt;
      if (state.weapons.gravity && state.timers.gravity <= 0 && state.enemies.length) {
        const target = [...state.enemies].sort((a, b) => b.hp - a.hp)[0];
        state.wells.push({ x: target.x, y: target.y, radius: 92 + state.weapons.gravity * 16, life: 2400, ttl: 2400, damage: (0.045 + state.weapons.gravity * 0.025) * damageMult(state) });
        state.timers.gravity = Math.max(1600, (5400 - state.weapons.gravity * 260) * cooldownMult(state));
        sfx("nova");
      }

      state.timers.nova -= dt;
      if (state.weapons.nova && state.timers.nova <= 0) {
        const radius = clamp(150 + state.weapons.nova * 26, 80, 420);
        const damage = (22 + state.weapons.nova * 8) * damageMult(state);
        state.enemies.forEach((enemy) => {
          if (!finitePoint(enemy) || !Number.isFinite(enemy.hp)) return;
          const dist = Math.hypot(enemy.x - state.player.x, enemy.y - state.player.y);
          if (dist < radius) {
            enemy.hp -= damage;
            const dx = (enemy.x - state.player.x) / Math.max(1, dist);
            const dy = (enemy.y - state.player.y) / Math.max(1, dist);
            enemy.x += dx * 22;
            enemy.y += dy * 22;
            pushOutOfObstacles(state, enemy, enemy.radius || 14);
          }
        });
        pushRing(state, state.player.x, state.player.y, radius, 420, "#ff6fb7");
        state.timers.nova = Math.max(1800, (6200 - state.weapons.nova * 390) * cooldownMult(state));
        sfx("level");
      }

      state.timers.laser -= dt;
      if (state.weapons.laser && state.timers.laser <= 0 && state.enemies.length) {
        const target = visibleTargets(state, state.enemies.slice(0, 64), state.player.x, state.player.y, 18).sort((a, b) => b.hp - a.hp)[0];
        if (target) {
          state.beams.push({ x1: state.player.x, y1: state.player.y, x2: target.x, y2: target.y, life: 220, ttl: 220, color: "#7af4dc", width: 7 });
          target.hp -= (40 + state.weapons.laser * 18) * damageMult(state);
          sfx("laser");
        }
        state.timers.laser = Math.max(950, (3600 - state.weapons.laser * 220) * cooldownMult(state));
      }

      state.timers.regen -= dt;
      if (state.weapons.regen && state.timers.regen <= 0) {
        state.player.hp = Math.min(state.player.maxHp, state.player.hp + 1.6 + state.weapons.regen * 0.8);
        state.timers.regen = 1000;
      }
      state.timers.comfortRegen -= dt;
      if (state.timers.comfortRegen <= 0) {
        state.player.hp = Math.min(state.player.maxHp, state.player.hp + 1.2);
        state.timers.comfortRegen = 1000;
      }

      state.enemies.forEach((enemy) => {
        const dx = state.player.x - enemy.x;
        const dy = state.player.y - enemy.y;
        const dist = Math.max(1, Math.hypot(dx, dy));
        enemy.slow = Math.max(0, (enemy.slow || 0) - dt);
        enemy.ability = Math.max(0, (enemy.ability || 0) - dt);
        enemy.rage = Math.max(0, (enemy.rage || 0) - dt);
        const enemySpeed = enemy.speed * (enemy.slow > 0 ? 0.48 : 1);
        const bossRush = enemy.boss && enemy.phase > 0 ? 2.35 : 1;
        let moveX = dx / dist * enemySpeed * bossRush;
        let moveY = dy / dist * enemySpeed * bossRush;
        enemy.x += (moveX + Math.sin(state.seconds * 3 + enemy.wobble) * (enemy.boss ? 0.72 : 0.24)) * (dt / 16);
        enemy.y += (moveY + Math.cos(state.seconds * 2 + enemy.wobble) * (enemy.boss ? 0.58 : 0.18)) * (dt / 16);
        pushOutOfObstacles(state, enemy, enemy.radius);
        if (enemy.boss) {
          enemy.phase = Math.max(0, enemy.phase - dt / 620);
          if (frame % 8 === 0) {
            burst(enemy.x + Math.sin(frame / 9) * 54, enemy.y + Math.cos(frame / 11) * 38, enemy.rage > 0 ? "#ffcf8a" : "#ff6fb7", 3);
          }
          if (enemy.ability <= 0) {
            bossAttack(state, canvas, enemy);
          }
        }
        if (dist < enemy.radius + 18 && state.player.invuln <= 0) {
          const contactDamage = enemy.boss ? 24 : enemy.elite ? 12 : 8;
          state.player.hp -= Math.max(3, contactDamage - state.weapons.shield * 2.2);
          state.player.invuln = enemy.boss ? 980 : 820;
          burst(state.player.x, state.player.y, "#ff6fb7", 14);
          sfx("hit");
          if (state.player.hp <= 0 && !state.over) {
            state.over = true;
            setLastRun({ score: state.score, level: state.level, seconds: Math.floor(state.seconds), kills: state.kills });
            setGameStatus("gameover");
            setMessage(`Run beendet: ${state.score} Punkte, ${state.kills} Drohnen zerlegt.`);
          }
        }
        if (state.weapons.aura && dist < 76 + state.weapons.aura * 18) {
          enemy.hp -= (0.12 + state.weapons.aura * 0.055) * dt * damageMult(state);
        }
      });

      state.shots.forEach((shot) => {
        shot.x += shot.vx * (dt / 16);
        shot.y += shot.vy * (dt / 16);
        if (collidesObstacle(state, shot.x, shot.y, shot.type === "drone" ? 12 : 8)) {
          shot.life = 0;
          burst(shot.x, shot.y, "#ffcf8a", 5);
        }
        shot.life -= dt;
      });
      const shotKeep = Math.max(canvas.width, canvas.height) * 0.95;
      state.shots = state.shots.filter((shot) => shot.life > 0 && distanceSq(shot.x, shot.y, state.player.x, state.player.y) < shotKeep * shotKeep);
      state.shots.forEach((shot) => {
        const possibleTargets = state.enemies.filter((enemy) => distanceSq(shot.x, shot.y, enemy.x, enemy.y) < 96 * 96);
        possibleTargets.forEach((enemy) => {
          const hitRadius = enemy.radius + 7;
          if (distanceSq(shot.x, shot.y, enemy.x, enemy.y) < hitRadius * hitRadius && shot.life > 0) {
            enemy.hp -= shot.damage;
            if (enemy.boss) alienBloodBurst(shot.x, shot.y, "#ff5f7c", 8, 0.75);
            if (state.weapons.frost) {
              enemy.slow = Math.max(enemy.slow || 0, 650 + state.weapons.frost * 180);
              enemy.tint = "#9bf6ff";
              if (Math.random() < 0.12) sfx("freeze");
            }
            shot.pierce -= 1;
            if (shot.pierce < 0) shot.life = 0;
            burst(shot.x, shot.y, enemy.elite ? "#b46cff" : "#ff6fb7", 5);
          }
        });
      });

      state.bombs.forEach((bomb) => {
        if (![bomb.x, bomb.y, bomb.tx, bomb.ty, bomb.life, bomb.ttl, bomb.radius, bomb.damage].every(Number.isFinite) || bomb.ttl <= 0 || bomb.radius <= 0) {
          bomb.life = 0;
          return;
        }
        const t = clamp(1 - bomb.life / Math.max(1, bomb.ttl), 0, 1);
        bomb.x += (bomb.tx - bomb.x) * 0.08;
        bomb.y += (bomb.ty - bomb.y) * 0.08;
        const world = state.world || worldConfig;
        bomb.x = clamp(bomb.x, 0, world.width);
        bomb.y = clamp(bomb.y, 0, world.height);
        bomb.life -= dt;
        if (!bomb.exploded && (t >= 0.95 || bomb.life <= 0)) {
          bomb.exploded = true;
          state.enemies.forEach((enemy) => {
            if (finitePoint(enemy) && Math.hypot(enemy.x - bomb.x, enemy.y - bomb.y) < bomb.radius) {
              enemy.hp -= bomb.damage;
              if (enemy.boss) alienBloodBurst(enemy.x, enemy.y, "#ff5f7c", 18, 1);
            }
          });
          burst(bomb.x, bomb.y, "#ffcf8a", 24);
          bomb.life = 0;
        }
      });
      state.bombs = state.bombs.filter((bomb) => bomb.life > 0);
      state.beams.forEach((beam) => { beam.life -= dt; });
      state.beams = state.beams.filter((beam) => beam.life > 0);
      state.wells.forEach((well) => {
        well.life -= dt;
        state.enemies.forEach((enemy) => {
          const dist = Math.max(1, Math.hypot(well.x - enemy.x, well.y - enemy.y));
          if (dist < well.radius) {
            enemy.hp -= well.damage * dt;
            enemy.x += (well.x - enemy.x) / dist * (2.2 + state.weapons.gravity * 0.35) * (dt / 16);
            enemy.y += (well.y - enemy.y) / dist * (2.2 + state.weapons.gravity * 0.35) * (dt / 16);
          }
        });
      });
      state.wells = state.wells.filter((well) => well.life > 0);

      state.hazards.forEach((hazard) => {
        hazard.life -= dt;
        if (hazard.type === "ring") {
          hazard.radius = hazard.max * (1 - hazard.life / hazard.ttl);
          const dist = Math.hypot(state.player.x - hazard.x, state.player.y - hazard.y);
          if (!hazard.hit && Math.abs(dist - hazard.radius) < 24 && state.player.invuln <= 0) {
            state.player.hp -= Math.max(4, hazard.damage - state.weapons.shield * 2);
            state.player.invuln = 760;
            hazard.hit = true;
            burst(state.player.x, state.player.y, "#ff6fb7", 12);
          }
        } else if (hazard.type === "orb") {
          hazard.x += hazard.vx * (dt / 16);
          hazard.y += hazard.vy * (dt / 16);
          if (Math.hypot(state.player.x - hazard.x, state.player.y - hazard.y) < hazard.radius + 19 && state.player.invuln <= 0) {
            state.player.hp -= Math.max(4, hazard.damage - state.weapons.shield * 2);
            state.player.invuln = 760;
            hazard.life = 0;
            burst(state.player.x, state.player.y, hazard.color, 12);
          }
        } else if (hazard.type === "beam") {
          const elapsed = hazard.ttl - hazard.life;
          const beamArmed = elapsed >= (hazard.warmup || 0);
          const vx = hazard.x2 - hazard.x1;
          const vy = hazard.y2 - hazard.y1;
          const lenBeam = Math.max(1, Math.hypot(vx, vy));
          const t = Math.max(0, Math.min(1, ((state.player.x - hazard.x1) * vx + (state.player.y - hazard.y1) * vy) / (lenBeam * lenBeam)));
          const px = hazard.x1 + vx * t;
          const py = hazard.y1 + vy * t;
          const hitWidth = hazard.hitWidth || Math.max(7, (hazard.width || 12) * 0.55);
          if (beamArmed && !hazard.hit && Math.hypot(state.player.x - px, state.player.y - py) < hitWidth && state.player.invuln <= 0) {
            state.player.hp -= Math.max(4, hazard.damage - state.weapons.shield * 2);
            state.player.invuln = 820;
            hazard.hit = true;
            burst(state.player.x, state.player.y, "#ffcf8a", 16);
          }
        } else if (hazard.type === "meteor") {
          const progress = 1 - hazard.life / hazard.ttl;
          if (!hazard.exploded && progress > 0.64) {
            hazard.exploded = true;
            pushRing(state, hazard.x, hazard.y, hazard.radius * 2.8, 520, hazard.color);
            burst(hazard.x, hazard.y, hazard.color, 24);
            if (Math.hypot(state.player.x - hazard.x, state.player.y - hazard.y) < hazard.radius * 1.55 && state.player.invuln <= 0) {
              state.player.hp -= Math.max(5, hazard.damage - state.weapons.shield * 2);
              state.player.invuln = 820;
              burst(state.player.x, state.player.y, "#ffcf8a", 18);
            }
          }
        }
      });
      state.hazards = state.hazards.filter((hazard) => hazard.life > 0);
      enforceBleeding(state);
      if (state.player.hp <= 0 && !state.over) {
        state.over = true;
        setLastRun({ score: state.score, level: state.level, seconds: Math.floor(state.seconds), kills: state.kills });
        setGameStatus("gameover");
        setMessage(`Run beendet: ${state.score} Punkte, ${state.kills} Aliens zerlegt.`);
      }

      if (state.weapons.orbit) {
        const count = 2 + Math.floor(state.weapons.orbit / 2);
        const radius = 58 + state.weapons.orbit * 6;
        for (let i = 0; i < count; i += 1) {
          const angle = frame / 24 + i / count * Math.PI * 2;
          const ox = state.player.x + Math.cos(angle) * radius;
          const oy = state.player.y + Math.sin(angle) * radius;
          state.enemies.slice(0, 72).forEach((enemy) => {
            const hitRadius = enemy.radius + 12;
            if (distanceSq(enemy.x, enemy.y, ox, oy) < hitRadius * hitRadius) enemy.hp -= (0.2 + state.weapons.orbit * 0.09) * dt * damageMult(state);
          });
        }
      }

      state.enemies = state.enemies.filter((enemy) => {
        if (enemy.hp > 0) return true;
        const points = enemy.boss ? 900 : enemy.elite ? 32 : 12;
        state.kills += 1;
        state.score += points;
        if (enemy.boss) {
          state.bossActive = false;
          state.nextBossAt = state.seconds + bossCooldownSeconds;
          state.hazards = [];
          setMessage("Boss zerlegt. Naechster Boss in 3 Minuten.");
          scorePopup(state, enemy.x, enemy.y, points, "#ffcf8a");
          alienBloodBurst(enemy.x, enemy.y, "#ff5f7c", 70, 1.25);
          burst(enemy.x, enemy.y, "#ff6fb7", 34);
        }
        state.gems.push({ x: enemy.x, y: enemy.y, value: enemy.boss ? 150 : enemy.elite ? 18 : 8, spin: Math.random() * 7 });
        return false;
      });

      const enemyKeep = Math.max(canvas.width, canvas.height) * 1.15;
      state.enemies = state.enemies.filter((enemy) => enemy.boss || distanceSq(enemy.x, enemy.y, state.player.x, state.player.y) < enemyKeep * enemyKeep);

      const magnetRadius = 58 + state.weapons.magnet * 44;
      state.gems = state.gems.filter((gem) => {
        const dist = Math.hypot(gem.x - state.player.x, gem.y - state.player.y);
        if (dist < magnetRadius) {
          gem.x += (state.player.x - gem.x) * Math.min(0.18, 5 / Math.max(1, dist));
          gem.y += (state.player.y - gem.y) * Math.min(0.18, 5 / Math.max(1, dist));
        }
        if (Math.hypot(gem.x - state.player.x, gem.y - state.player.y) < 24) {
          state.score += Math.floor(gem.value * 1.5);
          gainXp(state, gem.value);
          burst(gem.x, gem.y, "#7af4dc", 12);
          sfx("pepple");
          return false;
        }
        return true;
      });

      state.potions = state.potions.filter((potion) => {
        potion.life -= dt;
        if (potion.life <= 0) return false;
        const pickupRadius = (potion.radius || 19) + 23;
        if (distanceSq(potion.x, potion.y, state.player.x, state.player.y) < pickupRadius * pickupRadius && state.player.hp < state.player.maxHp) {
          const healed = Math.min(potion.heal || 36, state.player.maxHp - state.player.hp);
          state.player.hp += healed;
          scorePopup(state, potion.x, potion.y, Math.ceil(healed), "#5dff9a");
          burst(potion.x, potion.y, "#5dff9a", 16);
          pushRing(state, potion.x, potion.y, 76, 460, "#5dff9a");
          sfx("heal");
          return false;
        }
        return true;
      });
      enforceBleeding(state);
      if (state.player.hp <= 0 && !state.over) {
        state.over = true;
        setLastRun({ score: state.score, level: state.level, seconds: Math.floor(state.seconds), kills: state.kills });
        setGameStatus("gameover");
        setMessage(`Run beendet: ${state.score} Punkte, ${state.kills} Aliens zerlegt.`);
      }

      if (frame % 10 === 0) syncSnapshot(state);
    }

    state.particles.forEach((particle) => {
      particle.vx = Number.isFinite(particle.vx) ? particle.vx : 0;
      particle.vy = Number.isFinite(particle.vy) ? particle.vy : 0;
      particle.ttl = Number.isFinite(particle.ttl) && particle.ttl > 0 ? particle.ttl : 1;
      if (particle.ring) particle.max = Number.isFinite(particle.max) && particle.max > 0 ? clamp(particle.max, 1, 760) : 1;
      particle.x += particle.vx * (dt / 16);
      particle.y += particle.vy * (dt / 16);
      particle.life -= dt;
    });
    state.particles = state.particles
      .filter((particle) => {
        if (!Number.isFinite(particle.x) || !Number.isFinite(particle.y) || !Number.isFinite(particle.life) || !Number.isFinite(particle.ttl) || particle.ttl <= 0 || particle.life <= 0 || (particle.ring && !Number.isFinite(particle.max))) return false;
        const keep = Math.max(canvas.width, canvas.height) * 1.25;
        return distanceSq(particle.x, particle.y, state.player.x, state.player.y) < keep * keep;
      })
      .slice(-perfCaps.particles);

    const cameraX = statusRef.current === "menu" ? 0 : (state.camera?.x || 0);
    const cameraY = statusRef.current === "menu" ? 0 : (state.camera?.y || 0);
    ctx.save();
    ctx.translate(-cameraX, -cameraY);

    if (statusRef.current !== "menu") {
      (state.obstacles || []).forEach((obstacle) => drawObstacle(ctx, obstacle, frame));
    }

    state.potions.forEach((potion) => {
      const age = clamp(potion.life / Math.max(1, potion.ttl), 0, 1);
      const pulse = Math.sin(frame / 10 + potion.spin) * 0.08 + 1;
      ctx.save();
      ctx.translate(potion.x, potion.y);
      ctx.scale(pulse, pulse);
      ctx.shadowBlur = 26;
      ctx.shadowColor = "#5dff9a";
      ctx.fillStyle = `rgba(93,255,154,${0.12 + age * 0.12})`;
      ctx.beginPath();
      ctx.arc(0, 4, 34, 0, Math.PI * 2);
      ctx.fill();

      const glass = ctx.createLinearGradient(-15, -24, 15, 24);
      glass.addColorStop(0, "rgba(255,255,255,.95)");
      glass.addColorStop(0.36, "rgba(172,255,216,.82)");
      glass.addColorStop(1, "rgba(35,82,73,.78)");
      ctx.fillStyle = glass;
      ctx.strokeStyle = "rgba(239,255,248,.82)";
      ctx.lineWidth = 2.4;
      ctx.beginPath();
      roundedCanvasRect(ctx, -13, -17, 26, 34, 8);
      ctx.fill();
      ctx.stroke();

      const liquid = ctx.createLinearGradient(0, 1, 0, 17);
      liquid.addColorStop(0, "#ff547d");
      liquid.addColorStop(0.55, "#ff1f55");
      liquid.addColorStop(1, "#771640");
      ctx.fillStyle = liquid;
      ctx.beginPath();
      roundedCanvasRect(ctx, -9, -2, 18, 17, 6);
      ctx.fill();

      ctx.fillStyle = "#fff7df";
      ctx.fillRect(-7, -25, 14, 8);
      ctx.fillStyle = "#ffcf8a";
      ctx.fillRect(-9, -29, 18, 5);
      ctx.strokeStyle = "rgba(255,255,255,.92)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(-5, -11);
      ctx.lineTo(3, -17);
      ctx.stroke();
      ctx.restore();
    });

    state.gems.forEach((gem) => {
      const spin = frame / 18 + gem.spin;
      ctx.save();
      ctx.translate(gem.x, gem.y);
      ctx.rotate(spin);
      ctx.shadowBlur = 18;
      ctx.shadowColor = "#7af4dc";
      const grd = ctx.createLinearGradient(-10, -10, 10, 10);
      grd.addColorStop(0, "#effff8");
      grd.addColorStop(0.45, "#7af4dc");
      grd.addColorStop(1, "#b46cff");
      ctx.fillStyle = grd;
      ctx.beginPath();
      ctx.moveTo(0, -10);
      ctx.lineTo(9, 0);
      ctx.lineTo(0, 10);
      ctx.lineTo(-9, 0);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    });

    state.shots.forEach((shot) => drawWeaponProjectile(ctx, shot, frame));

    state.enemies.forEach((enemy) => drawAlien(ctx, enemy, frame));

    state.beams.forEach((beam) => {
      const alpha = Math.max(0, beam.life / beam.ttl);
      const isThunder = beam.color === "#ffe66d";
      ctx.save();
      ctx.strokeStyle = isThunder ? `rgba(255,230,109,${alpha * 0.26})` : `rgba(122,244,220,${alpha * 0.24})`;
      ctx.lineWidth = (beam.width || 6) * 4.2;
      ctx.lineCap = "round";
      ctx.shadowBlur = 34;
      ctx.shadowColor = beam.color;
      ctx.beginPath();
      ctx.moveTo(beam.x1, beam.y1);
      ctx.lineTo(beam.x2, beam.y2);
      ctx.stroke();
      ctx.strokeStyle = isThunder ? `rgba(255,252,205,${alpha * 0.92})` : `rgba(228,255,251,${alpha * 0.88})`;
      ctx.lineWidth = Math.max(2, (beam.width || 6) * 0.42);
      ctx.beginPath();
      ctx.moveTo(beam.x1, beam.y1);
      if (isThunder) {
        const steps = 9;
        for (let i = 1; i < steps; i += 1) {
          const t = i / steps;
          const nx = beam.x1 + (beam.x2 - beam.x1) * t + Math.sin(frame + i * 9) * 8;
          const ny = beam.y1 + (beam.y2 - beam.y1) * t + Math.cos(frame + i * 7) * 8;
          ctx.lineTo(nx, ny);
        }
      }
      ctx.lineTo(beam.x2, beam.y2);
      ctx.stroke();
      ctx.shadowBlur = 0;
      ctx.restore();
    });

    state.bombs.forEach((bomb) => {
      if (![bomb.x, bomb.y, bomb.life, bomb.ttl, bomb.radius].every(Number.isFinite) || bomb.ttl <= 0 || bomb.radius <= 0) return;
      const blastProgress = clamp(1 - bomb.life / Math.max(1, bomb.ttl), 0, 1);
      const blastRadius = Math.max(1, bomb.radius * blastProgress);
      ctx.save();
      ctx.translate(bomb.x, bomb.y);
      ctx.rotate(frame / 24);
      ctx.shadowBlur = 26;
      ctx.shadowColor = "#ffcf8a";
      if (!drawSprite(ctx, "egg", 0, 0, 44, 44, { shadowBlur: 24, shadowColor: "#ffcf8a" })) {
        ctx.fillStyle = "#fff4e9";
        ctx.beginPath();
        ctx.ellipse(0, 0, 10, 14, 0.2, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.strokeStyle = "rgba(255,207,138,.5)";
      ctx.lineWidth = 2.2;
      ctx.beginPath();
      ctx.arc(0, 0, blastRadius, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    });

    state.wells.forEach((well) => {
      const alpha = Math.max(0, well.life / well.ttl);
      ctx.save();
      ctx.translate(well.x, well.y);
      ctx.rotate(frame / 38);
      ctx.globalAlpha = 0.25 + alpha * 0.38;
      ctx.shadowBlur = 42;
      ctx.shadowColor = "#6d4cff";
      drawSprite(ctx, "gravity", 0, 0, well.radius * 1.05, well.radius * 0.92, { rotate: -frame / 26, shadowBlur: 38, shadowColor: "#6d4cff" });
      ctx.strokeStyle = "#6d4cff";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.ellipse(0, 0, well.radius, well.radius * 0.36, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    });

    state.hazards.forEach((hazard) => {
      const alpha = Math.max(0, hazard.life / hazard.ttl);
      ctx.save();
      ctx.globalAlpha = Math.min(1, 0.25 + alpha);
      ctx.shadowBlur = 30;
      ctx.shadowColor = hazard.color;
      if (hazard.type === "ring") {
        ctx.strokeStyle = hazard.color;
        ctx.lineWidth = 7;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, hazard.radius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = "rgba(255,244,233,.65)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, hazard.radius + 10, 0, Math.PI * 2);
        ctx.stroke();
      } else if (hazard.type === "orb") {
        const grd = ctx.createRadialGradient(hazard.x - 6, hazard.y - 8, 2, hazard.x, hazard.y, hazard.radius * 1.6);
        grd.addColorStop(0, "#fff4e9");
        grd.addColorStop(0.4, hazard.color);
        grd.addColorStop(1, "rgba(40,7,35,.12)");
        ctx.fillStyle = grd;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, hazard.radius, 0, Math.PI * 2);
        ctx.fill();
      } else if (hazard.type === "beam") {
        const elapsed = hazard.ttl - hazard.life;
        const warmup = hazard.warmup || 0;
        const armed = elapsed >= warmup;
        const charge = warmup ? clamp(elapsed / warmup, 0, 1) : 1;
        ctx.lineCap = "round";
        ctx.strokeStyle = armed ? `rgba(255,207,138,${alpha * 0.26})` : `rgba(244,220,255,${0.12 + charge * 0.32})`;
        ctx.lineWidth = armed ? hazard.width * 1.55 : Math.max(3, hazard.width * 0.62 + charge * 5);
        ctx.beginPath();
        ctx.moveTo(hazard.x1, hazard.y1);
        ctx.lineTo(hazard.x2, hazard.y2);
        ctx.stroke();
        ctx.strokeStyle = armed ? `rgba(255,244,233,${alpha * 0.86})` : `rgba(180,108,255,${0.42 + charge * 0.34})`;
        ctx.lineWidth = armed ? Math.max(3, hazard.hitWidth || 5) : 2.4;
        ctx.beginPath();
        ctx.moveTo(hazard.x1, hazard.y1);
        ctx.lineTo(hazard.x2, hazard.y2);
        ctx.stroke();
        if (!armed) {
          const cueGap = 34;
          const dx = hazard.x2 - hazard.x1;
          const dy = hazard.y2 - hazard.y1;
          const len = Math.max(1, Math.hypot(dx, dy));
          const nx = dx / len;
          const ny = dy / len;
          ctx.strokeStyle = `rgba(255,255,255,${0.24 + charge * 0.36})`;
          ctx.lineWidth = 1.6;
          ctx.setLineDash([12, 18]);
          ctx.beginPath();
          ctx.moveTo(hazard.x1 + nx * cueGap, hazard.y1 + ny * cueGap);
          ctx.lineTo(hazard.x2 - nx * cueGap, hazard.y2 - ny * cueGap);
          ctx.stroke();
          ctx.setLineDash([]);
        }
      } else if (hazard.type === "meteor") {
        const progress = 1 - alpha;
        const warnRadius = hazard.radius * (1.8 - progress * 0.5);
        ctx.strokeStyle = `rgba(255,244,233,${0.22 + progress * 0.45})`;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, warnRadius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = hazard.color;
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.arc(hazard.x, hazard.y, hazard.radius * (0.7 + progress * 0.5), 0, Math.PI * 2);
        ctx.stroke();
        if (!hazard.exploded) {
          ctx.fillStyle = hazard.color;
          ctx.globalAlpha = Math.min(1, 0.22 + progress * 0.55);
          ctx.beginPath();
          ctx.moveTo(hazard.x - 10, hazard.y - 90 + progress * 62);
          ctx.lineTo(hazard.x + 10, hazard.y - 90 + progress * 62);
          ctx.lineTo(hazard.x + 4, hazard.y - 8);
          ctx.lineTo(hazard.x - 4, hazard.y - 8);
          ctx.closePath();
          ctx.fill();
        }
      }
      ctx.restore();
    });

    const player = state.player;
    if (state.weapons.aura) {
      const radius = 76 + state.weapons.aura * 18;
      ctx.save();
      ctx.globalAlpha = 0.18;
      ctx.fillStyle = "#c88956";
      ctx.shadowBlur = 28;
      ctx.shadowColor = "#c88956";
      ctx.beginPath();
      ctx.arc(player.x, player.y, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    if (state.weapons.orbit) {
      const count = 2 + Math.floor(state.weapons.orbit / 2);
      const radius = 58 + state.weapons.orbit * 6;
      for (let i = 0; i < count; i += 1) {
        const angle = frame / 24 + i / count * Math.PI * 2;
        const ox = player.x + Math.cos(angle) * radius;
        const oy = player.y + Math.sin(angle) * radius;
        drawUpgradeIcon(ctx, "orbit", ox, oy, 28, "#ffcf8a", frame);
      }
    }

    state.particles.forEach((particle) => {
      if (!Number.isFinite(particle.x) || !Number.isFinite(particle.y) || !Number.isFinite(particle.life) || !Number.isFinite(particle.ttl) || particle.ttl <= 0) return;
      ctx.globalAlpha = clamp(particle.life / particle.ttl, 0, 1);
      if (particle.ring) {
        if (!Number.isFinite(particle.max) || particle.max <= 0) return;
        const ringRadius = clamp(particle.max * (1 - particle.life / particle.ttl), 1, 780);
        ctx.strokeStyle = particle.color;
        ctx.lineWidth = 3;
        ctx.shadowBlur = 22;
        ctx.shadowColor = particle.color;
        ctx.beginPath();
        ctx.arc(particle.x, particle.y, ringRadius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.shadowBlur = 0;
      } else if (particle.type === "score") {
        const alpha = clamp(particle.life / particle.ttl, 0, 1);
        const lift = 1 - alpha;
        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.font = `950 ${particle.size || 18}px Inter, Arial, sans-serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.lineWidth = 5;
        ctx.strokeStyle = "rgba(6, 4, 16, 0.78)";
        ctx.shadowBlur = 24;
        ctx.shadowColor = particle.color;
        ctx.strokeText(particle.text || "+0", particle.x, particle.y - lift * 16);
        ctx.fillStyle = particle.color;
        ctx.fillText(particle.text || "+0", particle.x, particle.y - lift * 16);
        ctx.fillStyle = "rgba(255,244,233,0.88)";
        ctx.font = `850 ${Math.max(10, (particle.size || 18) * 0.48)}px Inter, Arial, sans-serif`;
        ctx.fillText("PTS", particle.x, particle.y + (particle.size || 18) * 0.68 - lift * 16);
        ctx.restore();
      } else {
        ctx.fillStyle = particle.color;
        ctx.shadowBlur = particle.type === "slime" ? 12 : 0;
        ctx.shadowColor = particle.color;
        ctx.beginPath();
        if (particle.type === "slime") {
          ctx.ellipse(particle.x, particle.y, particle.size || 5, Math.max(2, (particle.size || 5) * 0.54), Math.atan2(particle.vy, particle.vx), 0, Math.PI * 2);
        } else {
          ctx.arc(particle.x, particle.y, 2.4, 0, Math.PI * 2);
        }
        ctx.fill();
        ctx.shadowBlur = 0;
      }
      ctx.globalAlpha = 1;
    });

    if (!["menu", "options"].includes(statusRef.current)) drawAstronautChicken(ctx, player, frame);

    ctx.restore();

    drawSurvivorHudBars(ctx, canvas, state, frame);

    if (["menu", "options"].includes(statusRef.current)) {
      const titleImage = titleRef.current;
      if (titleImage?.complete && titleImage.naturalWidth) {
        const scale = Math.max(canvas.width / titleImage.naturalWidth, canvas.height / titleImage.naturalHeight);
        const width = titleImage.naturalWidth * scale;
        const height = titleImage.naturalHeight * scale;
        const x = (canvas.width - width) / 2;
        const y = (canvas.height - height) / 2;
        ctx.drawImage(titleImage, x, y, width, height);
        const titleShade = ctx.createLinearGradient(0, 0, 0, canvas.height);
        titleShade.addColorStop(0, "rgba(5,2,12,.12)");
        titleShade.addColorStop(0.48, "rgba(8,3,14,.2)");
        titleShade.addColorStop(1, "rgba(4,2,10,.62)");
        ctx.fillStyle = titleShade;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        const titleGlow = ctx.createRadialGradient(canvas.width * 0.26, canvas.height * 0.26, 20, canvas.width * 0.26, canvas.height * 0.26, canvas.width * 0.42);
        titleGlow.addColorStop(0, "rgba(255,207,138,.34)");
        titleGlow.addColorStop(1, "rgba(255,207,138,0)");
        ctx.fillStyle = titleGlow;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
      } else {
        ctx.fillStyle = "rgba(3,5,12,.52)";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        drawSprite(ctx, "chicken", canvas.width / 2 - 300, canvas.height * 0.56, 128, 162, { shadowBlur: 36, shadowColor: "#ffcf8a" });
        drawPlayerFace(ctx, canvas.width / 2 - 293, canvas.height * 0.56 - 42, 1.16);
        drawSprite(ctx, "alienPink", canvas.width / 2 + 300, canvas.height * 0.54, 94, 106, { rotate: Math.sin(frame / 20) * 0.08, shadowBlur: 24, shadowColor: "#ff6fb7" });
        drawSprite(ctx, "alienGreen", canvas.width / 2 + 410, canvas.height * 0.61, 82, 88, { rotate: -0.14, shadowBlur: 20, shadowColor: "#7af4dc" });
        drawSprite(ctx, "alienGold", canvas.width / 2 + 178, canvas.height * 0.62, 88, 86, { rotate: 0.18, shadowBlur: 24, shadowColor: "#ffcf8a" });
        drawSprite(ctx, "feather", canvas.width / 2 - 108, canvas.height * 0.58, 54, 74, { rotate: -0.78, shadowBlur: 22, shadowColor: "#7af4dc" });
        drawSprite(ctx, "nova", canvas.width / 2 + 105, canvas.height * 0.58, 66, 66, { rotate: frame / 28, shadowBlur: 24, shadowColor: "#ff6fb7" });
      }
      ctx.save();
      ctx.shadowBlur = 28;
      ctx.shadowColor = "rgba(0,0,0,.85)";
      ctx.fillStyle = "#fff4e9";
      ctx.font = "900 44px Inter, Arial";
      ctx.fillText("Pepple Survivor", canvas.width * 0.08, canvas.height * 0.18);
      ctx.font = "700 16px Inter, Arial";
      ctx.fillStyle = "#ffcf8a";
      ctx.fillText("Flieh vor dem Alien-Maul. Sammle XP. Bau dein Waffenchaos.", canvas.width * 0.08, canvas.height * 0.18 + 34);
      ctx.restore();
    }
    if (statusRef.current === "levelup") {
      ctx.fillStyle = "rgba(3,5,12,.44)";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
    if (statusRef.current === "gameover") {
      ctx.fillStyle = "rgba(3,5,12,.62)";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = "#fff4e9";
      ctx.font = "900 34px Inter, Arial";
      ctx.fillText("Run beendet", canvas.width / 2 - 100, canvas.height / 2 - 12);
      ctx.font = "700 16px Inter, Arial";
      ctx.fillStyle = "#ffcf8a";
      ctx.fillText(`${state.score} Score · ${state.kills} Kills · Level ${state.level}`, canvas.width / 2 - 132, canvas.height / 2 + 22);
    }
  }, [status, audioOn, volume, controlMode], recoverRun);

  function start() {
    stateRef.current = makeSurvivorState();
    setChoices([]);
    setLastRun(null);
    if ("speechSynthesis" in window) window.speechSynthesis.cancel();
    setSnapshot({ score: 0, level: 1, seconds: 0, kills: 0, hp: 150, maxHp: 150, energy: 100, bleeding: false, playerX: worldConfig.spawnX, playerY: worldConfig.spawnY, xp: 0, nextXp: 45, wave: 1, weapons: [{ id: "bolt", name: "Federblitz", level: 1, color: "#c88cff", icon: "feather" }] });
    setMessage("Sammle XP-Kristalle. Beim Level-Up waehlt ihr den Build.");
    setGameStatus("play");
    requestAnimationFrame(() => stageRef.current?.focus?.());
    audio();
    sfx("start");
  }

  function chooseUpgrade(upgrade) {
    const state = stateRef.current;
    if (statusRef.current !== "levelup") return;
    state.weapons[upgrade.id] = Number(state.weapons[upgrade.id] || 0) + 1;
    if (upgrade.id === "shield") {
      state.player.maxHp += 24;
      state.player.hp = Math.min(state.player.maxHp, state.player.hp + 34);
    }
    if (upgrade.id === "speed") state.player.invuln = Math.max(state.player.invuln, 620);
    setChoices([]);
    setMessage(`${upgrade.name} Level ${state.weapons[upgrade.id]} aktiviert.`);
    syncSnapshot(state);
    sfx("start");
    setGameStatus("play");
  }

  function togglePause() {
    if (statusRef.current === "play") {
      keysRef.current = {};
      setMessage("Run pausiert. Fortsetzen bringt dich direkt zurueck ins Chaos.");
      setGameStatus("paused");
      return;
    }
    if (statusRef.current === "paused") {
      setMessage("Weiter geht's. Die Aliens haben kurz gewartet.");
      setGameStatus("play");
    }
  }

  async function toggleFullscreen() {
    const node = stageRef.current;
    if (!node || !document.fullscreenEnabled) return;
    try {
      if (document.fullscreenElement === node) await document.exitFullscreen();
      else await node.requestFullscreen();
    } catch (err) {
      console.error(err);
      setMessage("Vollbild konnte vom Browser nicht gestartet werden.");
    }
  }

  async function save() {
    try {
      await api("/api/scores", { method: "POST", body: JSON.stringify({ game: "braincell-survivor", score: snapshot.score, level: snapshot.level, seconds_survived: snapshot.seconds, kills: snapshot.kills, build: "web-survivor" }) });
      setMessage("Score gespeichert.");
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  const healthPct = Math.max(0, Math.min(100, snapshot.hp / Math.max(1, snapshot.maxHp || 150) * 100));
  const bleeding = Boolean(snapshot.bleeding);
  const xpPct = Math.max(0, Math.min(100, snapshot.xp / Math.max(1, snapshot.nextXp) * 100));
  const bloodIntensity = status === "play" || status === "paused" || status === "levelup" ? Math.max(0, Math.min(1, (55 - healthPct) / 55)) : 0;
  const criticalHealth = status === "play" && healthPct > 0 && healthPct <= 20;
  const playerX = Number.isFinite(snapshot.playerX) ? snapshot.playerX : worldConfig.spawnX;
  const playerY = Number.isFinite(snapshot.playerY) ? snapshot.playerY : worldConfig.spawnY;
  const edgeDistance = Math.min(playerX, playerY, worldConfig.width - playerX, worldConfig.height - playerY);
  const simulationEdge = status === "play" && !criticalHealth && edgeDistance <= 260;

  useEffect(() => {
    if (!criticalHealth) {
      if (status !== "play" || healthPct > 28) criticalAlarmRef.current = 0;
      return;
    }
    const now = performance.now();
    if (now - criticalAlarmRef.current < 4200) return;
    criticalAlarmRef.current = now;
    criticalAlarm();
  }, [criticalHealth, healthPct, status, audioOn, volume]);

  return (
    <section className="survivorFrame survivorComplete" style={{ "--game-accent": gameMeta["braincell-survivor"].accent }}>
      <div className="survivorHeader">
        <div>
          <h2>Pepple Survivor</h2>
          <p>{message}</p>
        </div>
        <div className="survivorHud">
          <Stat label="Score" value={snapshot.score} />
          <Stat label="Level" value={snapshot.level} />
          <Stat label="Welle" value={snapshot.wave} />
          <Stat label="Kills" value={snapshot.kills} />
          <Stat label="Zeit" value={`${snapshot.seconds}s`} />
        </div>
      </div>
      <div className="survivorBars">
        <div className="survivorMeter healthMeter" style={{ "--pct": `${healthPct}%` }}>
          <div className="meterIcon"><Shield size={17} /></div>
          <div className="meterCopy">
            <span>Lebensenergie</span>
            <b>{snapshot.hp}<small>/{snapshot.maxHp}</small></b>
          </div>
          <i><em style={{ width: `${healthPct}%` }} /></i>
          <strong>{Math.round(healthPct)}%</strong>
        </div>
        <div className="survivorMeter xpMeter" style={{ "--pct": `${xpPct}%` }}>
          <div className="meterIcon"><Sparkles size={17} /></div>
          <div className="meterCopy">
            <span>Level {snapshot.level}</span>
            <b>{snapshot.xp}<small>/{snapshot.nextXp} XP</small></b>
          </div>
          <i><em className="xpFill" style={{ width: `${xpPct}%` }} /></i>
          <strong>{Math.round(xpPct)}%</strong>
        </div>
      </div>
      <div className="survivorBuild">
        <span>Build</span>
        {snapshot.weapons.map((weapon) => (
          <div className="weaponChip" key={weapon.id} style={{ "--weapon": weapon.color }}>
            <b>{weapon.name}</b><small>Lv {weapon.level}</small>
          </div>
        ))}
      </div>
      <div className="survivorStage" ref={stageRef} style={{ "--blood": bloodIntensity }} tabIndex={-1}>
        <audio
          ref={musicRef}
          preload="auto"
          onEnded={() => {
            if (!musicRef.current) return;
            musicRef.current.src = musicPlaylist[Math.floor(Math.random() * musicPlaylist.length)];
            startMusic();
          }}
        />
        <canvas className="gameCanvas survivorCanvas" ref={canvasRef} width="1280" height="720" />
        <div className="bloodEdge" aria-hidden="true" />
        {bleeding && status === "play" && <div className="bleedingWarning" aria-live="assertive">Unstillbare Blutung entdeckt!</div>}
        {criticalHealth && <div className="criticalHealthWarning" aria-live="assertive">Leben Kritisch!</div>}
        {simulationEdge && <div className="simulationEdgeWarning" aria-live="polite">Rande der Simulation</div>}
        {status === "menu" && (
          <div className="survivorMainMenu">
            <button onClick={start} type="button"><Gamepad2 size={19} /> Spiel starten</button>
            <button className="ghost" onClick={() => setGameStatus("options")} type="button"><Zap size={18} /> Optionen</button>
          </div>
        )}
        {status === "options" && (
          <div className="levelUpOverlay">
            <div className="levelUpPanel optionsPanel">
              <h3>Optionen</h3>
              <div className="optionRows">
                <div className="optionRow">
                  <span>Bewegung</span>
                  <div className="segmented">
                    <button className={controlMode === "wasd" ? "active" : ""} onClick={() => setControlMode("wasd")} type="button">WASD</button>
                    <button className={controlMode === "arrows" ? "active" : ""} onClick={() => setControlMode("arrows")} type="button">Pfeiltasten</button>
                  </div>
                </div>
                <div className="optionRow">
                  <span>Ton</span>
                  <button className={audioOn ? "activeToggle" : "ghost"} onClick={() => setAudioOn((value) => !value)} type="button">{audioOn ? "An" : "Aus"}</button>
                </div>
                <label className="optionRow rangeRow">
                  <span>Lautstaerke</span>
                  <input min="0" max="1" step="0.05" type="range" value={volume} onChange={(event) => setVolume(Number(event.target.value))} />
                </label>
              </div>
              <div className="gameActions survivorActions">
                <button onClick={start} type="button"><Gamepad2 size={16} /> Spiel starten</button>
                <button className="ghost" onClick={() => setGameStatus("menu")} type="button">Zurueck</button>
              </div>
            </div>
          </div>
        )}
        {status === "levelup" && (
          <div className="levelUpOverlay">
            <div className="levelUpPanel">
              <h3>Level Up</h3>
              <p>Waehle ein Upgrade</p>
              <div className="upgradeGrid">
                {choices.map((choice) => (
                  <button className="upgradeCard" key={choice.id} onClick={() => chooseUpgrade(choice)} type="button" style={{ "--weapon": choice.color }}>
                    <span className={`upgradeIcon upgradeIcon-${choice.icon}`} />
                    <strong>{choice.name}</strong>
                    <small>{choice.kind === "weapon" && choice.level === 1 ? "Neue Waffe" : `Level ${choice.level}`}</small>
                    <em>{choice.desc}</em>
                    <b>Waehlen</b>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}
        {status === "paused" && (
          <div className="levelUpOverlay">
            <div className="levelUpPanel compactPanel">
              <h3>Pause</h3>
              <p>Der Run ist eingefroren, aber die Seite lebt weiter.</p>
              <div className="gameActions survivorActions">
                <button onClick={togglePause} type="button"><Zap size={16} /> Fortsetzen</button>
                <button className="ghost" onClick={start} type="button"><RefreshCw size={16} /> Neu starten</button>
              </div>
            </div>
          </div>
        )}
        {status === "crashed" && (
          <div className="levelUpOverlay">
            <div className="levelUpPanel compactPanel">
              <h3>Run reparieren</h3>
              <p>Ein Item-Effekt wurde abgefangen. Neustart geht direkt hier, ohne die Webseite neu zu laden.</p>
              {lastRun && <small>{lastRun.score} Score · Level {lastRun.level} · {lastRun.kills} Kills · {lastRun.seconds}s</small>}
              <div className="gameActions survivorActions">
                <button onClick={start} type="button"><RefreshCw size={16} /> Run neu starten</button>
              </div>
            </div>
          </div>
        )}
        {status === "gameover" && (
          <div className="levelUpOverlay">
            <div className="levelUpPanel compactPanel">
              <h3>Run beendet</h3>
              <p>{snapshot.score} Score · {snapshot.kills} Kills · Level {snapshot.level}</p>
              <div className="gameActions survivorActions">
                <button onClick={start} type="button"><RefreshCw size={16} /> Run neu starten</button>
                {user && snapshot.score > 0 && <button className="ghost" onClick={save} type="button">Score speichern</button>}
                <button className="ghost" onClick={toggleFullscreen} type="button"><Gamepad2 size={16} /> {fullscreen ? "Vollbild aus" : "Vollbild"}</button>
              </div>
            </div>
          </div>
        )}
      </div>
      <div className="gameActions survivorActions">
        <button onClick={start} type="button"><RefreshCw size={16} /> {status === "play" ? "Neu starten" : "Start"}</button>
        {(status === "play" || status === "paused") && <button className="ghost" onClick={togglePause} type="button"><Zap size={16} /> {status === "paused" ? "Fortsetzen" : "Pause"}</button>}
        <button className="ghost" onClick={toggleFullscreen} type="button"><Gamepad2 size={16} /> {fullscreen ? "Vollbild aus" : "Vollbild"}</button>
        <button className="ghost" onClick={() => setAudioOn((value) => !value)} type="button"><Zap size={16} /> Ton {audioOn ? "an" : "aus"}</button>
        {user && snapshot.score > 0 && status === "gameover" && <button className="ghost" onClick={save} type="button">Score speichern</button>}
      </div>
      <div className="survivorScorePanel">
        <h3>Top Scores</h3>
        <Scoreboard game="braincell-survivor" refreshKey={refreshKey} />
      </div>
    </section>
  );
}

function GameHeader({ meta, message, score, level }) {
  return (
    <div className="gameHeader" style={{ "--game-accent": meta.accent }}>
      <div>
        <p className="kicker">Arcade Lobby</p>
        <h2>{meta.title}</h2>
        <p>{message || meta.text}</p>
      </div>
      <div className="gameHud">
        <Stat label="Score" value={score} />
        <Stat label="Level" value={level} />
      </div>
    </div>
  );
}

function GameFrame({ meta, canvasRef, message, score, level, onStart, onSave, refreshKey, game }) {
  return (
    <section className="gameFrame" style={{ "--game-accent": meta.accent }}>
      <GameHeader meta={meta} message={message} score={score} level={level} />
      <canvas className="gameCanvas" ref={canvasRef} width="920" height="420" />
      <div className="gameActions">
        <button onClick={onStart} type="button"><RefreshCw size={16} /> Spiel starten</button>
        {onSave && <button className="ghost" onClick={onSave} type="button">Score speichern</button>}
      </div>
      <Scoreboard game={game} refreshKey={refreshKey} />
    </section>
  );
}

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
    "chicken-jump": <ChickenJump user={user} />,
    "chicken-snake": <ChickenSnake user={user} />,
    "chicken-flipper": <ChickenFlipper user={user} />,
    "braincell-survivor": <PeppleSurvivor user={user} />,
  }[game];

  return (
    <section className="gamesShell">
      <div className="sectionHero arcadeHero">
        <div>
          <p className="kicker">Minispiele</p>
          <h1>Arcade Kaefig</h1>
          <p>Vier Spiele sind wieder direkt spielbar. Scores speichern funktioniert, sobald du eingeloggt bist.</p>
        </div>
        <Zap size={64} />
      </div>
      <div className="gameTabs">
        {Object.entries(gameMeta).map(([id, meta]) => (
          <button className={game === id ? "active" : ""} key={id} onClick={() => id !== "dnd" && setGame(id)} disabled={id === "dnd"} type="button">
            <Gamepad2 size={16} /> {meta.title}
          </button>
        ))}
      </div>
      {current}
      <div className="notice">DnD war in Streamlit ein sehr grosses eigenes System. Ich habe es markiert, damit es sauber als naechstes Modul portiert werden kann.</div>
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
  const [points, setPoints] = useState({ username: "", chickens_delta: 0, braincells_delta: 0 });
  const [roleForm, setRoleForm] = useState({ username: "", role: "member" });
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
    ["points", "Punkte"],
    ["roles", "Rollen"],
    ["news", "News"],
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
          <p>Registrierungen, Punkte, News, Shop, Events und Meldungen sind jetzt bedienbar.</p>
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
          {tab === "points" && (
            <form className="panel form" onSubmit={(event) => { event.preventDefault(); mutate("/api/admin/points", { method: "POST", body: JSON.stringify({ ...points, chickens_delta: Number(points.chickens_delta), braincells_delta: Number(points.braincells_delta) }) }); }}>
              <label>User<input value={points.username} onChange={(event) => setPoints({ ...points, username: event.target.value })} /></label>
              <label>Chickens Delta<input type="number" value={points.chickens_delta} onChange={(event) => setPoints({ ...points, chickens_delta: event.target.value })} /></label>
              <label>Pepples Delta<input type="number" value={points.braincells_delta} onChange={(event) => setPoints({ ...points, braincells_delta: event.target.value })} /></label>
              <button type="submit"><Plus size={16} /> Punkte buchen</button>
            </form>
          )}
          {tab === "roles" && (
            <section className="twoCol">
              <form className="panel form" onSubmit={(event) => { event.preventDefault(); mutate("/api/admin/role", { method: "POST", body: JSON.stringify(roleForm) }); }}>
                <h2>Rolle setzen</h2>
                <label>User<input value={roleForm.username} onChange={(event) => setRoleForm({ ...roleForm, username: event.target.value })} /></label>
                <label>Rolle
                  <select value={roleForm.role} onChange={(event) => setRoleForm({ ...roleForm, role: event.target.value })}>
                    {Object.entries(roleMeta).map(([id, meta]) => <option key={id} value={id}>{meta.label}</option>)}
                  </select>
                </label>
                <button type="submit"><Shield size={16} /> Rolle speichern</button>
              </form>
              <div className="list">
                {overview.users.map((item) => (
                  <article className="miniCard roleAdminRow" key={item.username}>
                    <span><strong>{item.username}</strong><RoleBadge user={item} /></span>
                    <button className="ghost" type="button" onClick={() => setRoleForm({ username: item.username, role: userRole(item) })}>Auswaehlen</button>
                  </article>
                ))}
              </div>
            </section>
          )}
          {tab === "news" && (
            <AdminListForm title="News erstellen" form={news} setForm={setNews} fields={["title", "body", "image_url"]} onSubmit={() => mutate("/api/admin/news", { method: "POST", body: JSON.stringify(news) })}>
              {overview.news_posts.map((item) => <AdminRow key={item.id} title={item.title} text={item.body} onDelete={() => mutate(`/api/admin/news/${item.id}`, { method: "DELETE" })} />)}
            </AdminListForm>
          )}
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

  function setPage(next) {
    setPageState(next);
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
    const touch = () => api("/api/presence", { method: "POST", body: "{}" }).catch(() => {});
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

  const content = useMemo(() => {
    if (page === "home") return <HomePage user={user} setPage={setPage} />;
    if (page === "login") return <LoginPage onLogin={(nextUser) => { setUser(nextUser); setPage("home"); }} />;
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
    <Shell page={page} setPage={setPage} user={user} onLogout={() => { api("/api/presence", { method: "DELETE" }).catch(() => {}).finally(() => { setToken(""); setUser(null); setPage("home"); }); }}>
      {content}
      <button className="supportFab" onClick={() => setPage("support")} type="button">Support</button>
    </Shell>
  );
}

createRoot(document.getElementById("root")).render(<App />);
