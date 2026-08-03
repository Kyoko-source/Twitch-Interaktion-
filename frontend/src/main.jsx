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
  MousePointer2,
  Newspaper,
  Palette,
  Plus,
  RefreshCw,
  Save,
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
  "chicken-jump": { title: "Chicken Jump", accent: "#ffcf8a", text: "Spring ueber kupferne Zaun-Laser und sammle Pepples." },
  "chicken-snake": { title: "Chicken Snake", accent: "#7af4dc", text: "Fuehre die Neon-Spur durch den Kaefig und friss Energiekerne." },
  "chicken-racer": { title: "Chicken Racer", accent: "#b46cff", text: "Setze auf dein Chicken und ueberlebe schnelle Rennrunden." },
  "braincell-survivor": { title: "Pepple Survivor", accent: "#ff6fb7", text: "Weiche Schwarmdrohnen aus und sammle so lange wie moeglich Pepples." },
  dnd: { title: "Dungeons and Dragons", accent: "#c88956", text: "Die grosse DnD-Lobby kommt als eigenes Modul zurueck." },
};

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
            {nav.slice(1, 9).map((item) => <SideButton item={item} page={page} setPage={setPage} key={item.id} />)}
          </div>
          <div className="sideGroup">
            <span>Account</span>
            {nav.slice(9, 11).map((item) => <SideButton item={item} page={page} setPage={setPage} key={item.id} />)}
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
  const { data, loading, error } = useApi("/api/dashboard", { stats: {}, leaderboard: [], news: [], events: [], gallery: [] });
  const topViewer = data.leaderboard[0];
  const podium = data.leaderboard.slice(0, 3);
  const nextNews = data.news[0];

  return (
    <section className="homePage">
      <div className="dashboardHero">
        <div className="heroCopy">
          <p className="kicker">Willkommen zurueck</p>
          <h1>{user?.username || "magical_kyoko_"}</h1>
          <p>Gemeinsam wachsen, gemeinsam glaenzen. Dein Aviary-Dashboard fuer Games, Rewards und Community-Energie.</p>
          <div className="levelStrip">
            <div><span>Level</span><strong>{user ? Math.max(1, Math.floor(Number(user.braincells || 0) / 140) + 1) : 27}</strong></div>
            <div className="levelBar"><span style={{ width: `${user ? Math.min(98, Number(user.braincells || 0) % 140) : 72}%` }} /></div>
            <small>Naechster Rang wartet im Kaefiglicht.</small>
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
              {data.leaderboard.slice(0, 5).map((item, index) => (
                <div key={item.username}>
                  <Avatar user={item} />
                  <span><strong>{item.username}</strong><small>{index % 3 === 0 ? "Im Spiel" : "Online"}</small></span>
                  <b>{Math.max(1, Math.floor(Number(item.braincells || 0) / 120))}</b>
                </div>
              ))}
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

function MembersPage() {
  const { data, loading, error } = useApi("/api/users", []);
  const [query, setQuery] = useState("");
  const filtered = data.filter((member) => String(member.username || "").toLowerCase().includes(query.toLowerCase()));
  const top = data[0];
  const totals = data.reduce((acc, member) => ({
    chickens: acc.chickens + Number(member.chickens || 0),
    braincells: acc.braincells + Number(member.braincells || 0),
  }), { chickens: 0, braincells: 0 });

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
            <p>{member.favorite_game || "Kein Lieblingsspiel gesetzt"}</p>
            <div className="miniStats">
              <span>{member.braincells || 0} Pepples</span>
              <span>{member.chickens || 0} Chickens</span>
            </div>
          </article>
        ))}
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
              <small>{item.rank_name}</small>
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
  if (!user) return <EmptyLogin setPage={setPage} />;
  async function buy(item) {
    try {
      const result = await api("/api/shop/purchase", { method: "POST", body: JSON.stringify({ item_id: item.id }) });
      setMessage(result.message);
    } catch (err) {
      setMessage(err.message);
    }
  }
  return (
    <section className="stack">
      <div className="sectionHero"><h1>Shop</h1><p>{user.chickens || 0} Chickens verfuegbar.</p></div>
      {message && <div className="notice">{message}</div>}
      {loading && <div className="notice">Lade Shop...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="grid">
        {data.map((item) => (
          <article className="card shopCard" key={item.id || item.name}>
            <p className="kicker">{item.category || "Reward"}</p>
            <h3>{item.name}</h3>
            <p>{item.desc || item.description}</p>
            <strong>{item.price} Chickens</strong>
            <button onClick={() => buy(item)} type="button">Kaufen</button>
          </article>
        ))}
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

function useCanvasGame(draw, deps) {
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
      draw(ctx, canvas, dt, frame++);
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
    return () => {
      alive = false;
    };
  }, deps);
  return canvasRef;
}

function ChickenJump({ user }) {
  const [running, setRunning] = useState(false);
  const [message, setMessage] = useState("Bereit fuer den Sprung.");
  const [snapshot, setSnapshot] = useState({ score: 0, level: 1 });
  const [refreshKey, setRefreshKey] = useState(0);
  const stateRef = useRef({ y: 310, vy: 0, obstacles: [], score: 0, level: 1, over: false, spawn: 0 });

  useEffect(() => {
    function key(event) {
      if (event.code === "Space" || event.key === "ArrowUp") {
        event.preventDefault();
        const state = stateRef.current;
        if (!running) return;
        if (state.y >= 308) state.vy = -14.5;
      }
    }
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [running]);

  const canvasRef = useCanvasGame((ctx, canvas, dt, frame) => {
    const state = stateRef.current;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const grd = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    grd.addColorStop(0, "#201126");
    grd.addColorStop(1, "#100915");
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = "rgba(255,207,138,.24)";
    for (let x = (frame % 40) - 40; x < canvas.width; x += 40) {
      ctx.beginPath(); ctx.moveTo(x, 340); ctx.lineTo(x + 20, 420); ctx.stroke();
    }
    ctx.fillStyle = "#c88956";
    ctx.fillRect(0, 340, canvas.width, 8);
    if (running && !state.over) {
      state.vy += 0.75;
      state.y = Math.min(310, state.y + state.vy);
      state.spawn -= dt;
      if (state.spawn <= 0) {
        state.obstacles.push({ x: canvas.width + 20, w: 24 + Math.random() * 24, h: 42 + Math.random() * 38 });
        state.spawn = Math.max(620, 1320 - state.score * 18);
      }
      state.obstacles.forEach((ob) => { ob.x -= 5.5 + state.level * 0.38; });
      state.obstacles = state.obstacles.filter((ob) => {
        if (!ob.passed && ob.x + ob.w < 96) {
          ob.passed = true;
          state.score += 1;
          state.level = 1 + Math.floor(state.score / 6);
          setSnapshot({ score: state.score, level: state.level });
        }
        return ob.x > -80;
      });
      const hit = state.obstacles.some((ob) => ob.x < 126 && ob.x + ob.w > 78 && state.y + 30 > 340 - ob.h);
      if (hit) {
        state.over = true;
        setRunning(false);
        setMessage(`Game Over: ${state.score} Punkte, Level ${state.level}`);
      }
    }
    ctx.fillStyle = "#ffcf8a";
    ctx.shadowColor = "#b46cff"; ctx.shadowBlur = 18;
    ctx.beginPath(); ctx.ellipse(96, state.y, 33, 24, 0, 0, Math.PI * 2); ctx.fill();
    ctx.shadowBlur = 0;
    ctx.fillStyle = "#ff6fb7"; ctx.fillRect(61, state.y + 6, 22, 10);
    state.obstacles.forEach((ob) => {
      ctx.fillStyle = "#7af4dc";
      ctx.fillRect(ob.x, 340 - ob.h, ob.w, ob.h);
      ctx.fillStyle = "rgba(122,244,220,.3)";
      ctx.fillRect(ob.x - 4, 340 - ob.h - 6, ob.w + 8, 6);
    });
    ctx.fillStyle = "#fff4e9";
    ctx.font = "800 24px Inter, Arial";
    ctx.fillText(`Score ${state.score}`, 24, 38);
  }, [running]);

  function start() {
    stateRef.current = { y: 310, vy: 0, obstacles: [], score: 0, level: 1, over: false, spawn: 400 };
    setSnapshot({ score: 0, level: 1 });
    setMessage("Leertaste oder Pfeil hoch zum Springen.");
    setRunning(true);
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

  return <GameFrame meta={gameMeta["chicken-jump"]} canvasRef={canvasRef} message={message} score={snapshot.score} level={snapshot.level} onStart={start} onSave={user && snapshot.score > 0 ? save : null} refreshKey={refreshKey} game="chicken-jump" />;
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

function ChickenRacer({ user }) {
  const [running, setRunning] = useState(false);
  const [pick, setPick] = useState(0);
  const [message, setMessage] = useState("Waehle ein Chicken und starte das Rennen.");
  const [snapshot, setSnapshot] = useState({ score: 0, level: 1 });
  const [refreshKey, setRefreshKey] = useState(0);
  const stateRef = useRef({ racers: [], done: false, score: 0, round: 1 });
  const colors = ["#ffcf8a", "#b46cff", "#7af4dc", "#ff6fb7"];

  const canvasRef = useCanvasGame((ctx, canvas, dt) => {
    const state = stateRef.current;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#110914"; ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = "rgba(255,207,138,.18)";
    for (let y = 70; y < 350; y += 70) { ctx.beginPath(); ctx.moveTo(20, y); ctx.lineTo(canvas.width - 30, y); ctx.stroke(); }
    ctx.fillStyle = "rgba(255,207,138,.75)"; ctx.fillRect(canvas.width - 70, 26, 6, 318);
    if (running && !state.done) {
      state.racers.forEach((racer) => {
        racer.x += (racer.speed + Math.random() * 1.8) * dt / 16;
        if (racer.x > canvas.width - 86 && !state.done) {
          state.done = true;
          setRunning(false);
          const won = racer.id === pick;
          state.score = won ? state.round * 25 : Math.max(0, state.score - 5);
          setSnapshot({ score: state.score, level: state.round });
          setMessage(won ? `Gewonnen. Score ${state.score}` : `${racer.name} gewinnt. Nochmal setzen?`);
        }
      });
    }
    state.racers.forEach((racer) => {
      ctx.fillStyle = racer.color;
      ctx.beginPath(); ctx.ellipse(racer.x, racer.y, 28, 18, 0, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = "#fff4e9"; ctx.font = "800 15px Inter, Arial"; ctx.fillText(racer.name, 30, racer.y + 5);
    });
  }, [running, pick]);

  function start() {
    stateRef.current = {
      racers: colors.map((color, index) => ({ id: index, name: `Chicken ${index + 1}`, x: 110, y: 80 + index * 70, speed: 2.4 + Math.random() * 2.2, color })),
      done: false,
      score: snapshot.score,
      round: snapshot.level + 1,
    };
    setMessage(`Runde ${snapshot.level + 1}: du setzt auf Chicken ${pick + 1}.`);
    setRunning(true);
  }

  async function save() {
    try {
      await api("/api/scores", { method: "POST", body: JSON.stringify({ game: "chicken-racer", score: snapshot.score, round: snapshot.level }) });
      setMessage("Score gespeichert.");
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  return (
    <section className="gameFrame">
      <GameHeader meta={gameMeta["chicken-racer"]} message={message} score={snapshot.score} level={snapshot.level} />
      <div className="racePicker">{colors.map((color, index) => <button style={{ "--pick": color }} className={pick === index ? "active" : ""} onClick={() => setPick(index)} type="button" key={color}>#{index + 1}</button>)}</div>
      <canvas className="gameCanvas" ref={canvasRef} width="920" height="390" />
      <div className="gameActions"><button onClick={start} type="button"><RefreshCw size={16} /> Rennen starten</button>{user && snapshot.score > 0 && <button className="ghost" onClick={save} type="button">Score speichern</button>}</div>
      <Scoreboard game="chicken-racer" refreshKey={refreshKey} />
    </section>
  );
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
  const [status, setStatus] = useState("menu");
  const [audioOn, setAudioOn] = useState(true);
  const [choices, setChoices] = useState([]);
  const [message, setMessage] = useState("WASD bewegen, XP sammeln, beim Level-Up Waffen waehlen.");
  const [snapshot, setSnapshot] = useState({
    score: 0,
    level: 1,
    seconds: 0,
    kills: 0,
    hp: 110,
    maxHp: 110,
    xp: 0,
    nextXp: 60,
    wave: 1,
    weapons: [{ id: "bolt", name: "Federblitz", level: 1, color: "#c88cff", icon: "feather" }],
  });
  const [refreshKey, setRefreshKey] = useState(0);
  const keysRef = useRef({});
  const musicRef = useRef(null);
  const audioRef = useRef({ ctx: null, nextBeat: 0 });
  const statusRef = useRef("menu");
  const musicPlaylist = [
    "/assets/braincell-survivor-theme.mp3",
    "/assets/braincell-survivor-theme-2.mp3",
    "/assets/braincell-survivor-theme-3.mp3",
    "/assets/braincell-survivor-theme-4.mp3",
  ];
  const stateRef = useRef({
    player: { x: 460, y: 250, hp: 110, maxHp: 110, invuln: 0 },
    gems: [],
    enemies: [],
    shots: [],
    bombs: [],
    beams: [],
    wells: [],
    particles: [],
    score: 0,
    xp: 0,
    nextXp: 60,
    seconds: 0,
    kills: 0,
    level: 1,
    wave: 1,
    spawn: 0,
    timers: { bolt: 0, nova: 2600, laser: 1600, egg: 900, drone: 640, thunder: 2100, gravity: 3200, regen: 1000 },
    weapons: { bolt: 1, orbit: 0, nova: 0, laser: 0, egg: 0, aura: 0, drone: 0, thunder: 0, frost: 0, gravity: 0, speed: 0, magnet: 0, shield: 0, regen: 0, might: 0, cooldown: 0 },
    over: false,
  });

  function setGameStatus(next) {
    statusRef.current = next;
    setStatus(next);
    if (next === "play") setTimeout(startMusic, 0);
    if (next === "gameover" || next === "menu") stopMusic();
  }

  useEffect(() => {
    function down(event) {
      if ([" ", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(event.key.toLowerCase())) event.preventDefault();
      keysRef.current[event.key.toLowerCase()] = true;
    }
    function up(event) { keysRef.current[event.key.toLowerCase()] = false; }
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };
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
    if (!audioOn) {
      musicRef.current?.pause();
      return;
    }
    if (statusRef.current === "play") startMusic();
  }, [audioOn]);

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
    const notes = { start: 196, pepple: 740, hit: 96, shot: 520, level: 980, laser: 1320, bomb: 86, thunder: 180, nova: 160, freeze: 1180, kill: 460 };
    osc.type = ["hit", "bomb", "thunder"].includes(type) ? "sawtooth" : type === "shot" ? "square" : "triangle";
    osc.frequency.setValueAtTime(notes[type] || 360, now);
    osc.frequency.exponentialRampToValueAtTime(["hit", "bomb", "thunder"].includes(type) ? 44 : (notes[type] || 360) * 1.48, now + 0.16);
    gain.gain.setValueAtTime(type === "hit" ? 0.095 : type === "bomb" ? 0.075 : 0.045, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + (type === "bomb" ? 0.26 : 0.18));
    osc.connect(gain).connect(ctxAudio.destination);
    osc.start(now);
    osc.stop(now + (type === "bomb" ? 0.28 : 0.2));
    if (["bomb", "nova", "thunder"].includes(type)) noise(type === "bomb" ? 0.22 : 0.11, type === "bomb" ? 0.04 : 0.022);
  }

  function noise(duration = 0.1, volume = 0.02) {
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
    gain.gain.setValueAtTime(volume, ctxAudio.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctxAudio.currentTime + duration);
    source.connect(filter).connect(gain).connect(ctxAudio.destination);
    source.start();
  }

  function startMusic() {
    const el = musicRef.current;
    if (!el || !audioOn) return;
    if (!el.src) el.src = musicPlaylist[Math.floor(Math.random() * musicPlaylist.length)];
    el.volume = 0.18;
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
    const state = stateRef.current;
    for (let i = 0; i < amount; i += 1) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 0.8 + Math.random() * 3.2;
      state.particles.push({ x, y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: 420 + Math.random() * 360, ttl: 800, color });
    }
  }

  function damageMult(state) {
    return 1 + state.weapons.might * 0.18;
  }

  function cooldownMult(state) {
    return Math.max(0.5, 1 - state.weapons.cooldown * 0.08);
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
      xp: Math.floor(state.xp),
      nextXp: state.nextXp,
      wave: state.wave,
      weapons,
    });
  }

  function enterLevelUp(state) {
    const nextChoices = makeChoices(state);
    setChoices(nextChoices);
    setMessage("Level Up. Waehle dein naechstes Upgrade.");
    setGameStatus("levelup");
    sfx("level");
    syncSnapshot(state);
  }

  function gainXp(state, amount) {
    state.xp += amount;
    while (state.xp >= state.nextXp) {
      state.xp -= state.nextXp;
      state.level += 1;
      state.nextXp = Math.floor(state.nextXp * 1.22 + 34);
      enterLevelUp(state);
      break;
    }
  }

  function spawnEnemy(state, canvas) {
    const side = Math.floor(Math.random() * 4);
    const edge = [
      { x: -36, y: Math.random() * canvas.height },
      { x: canvas.width + 36, y: Math.random() * canvas.height },
      { x: Math.random() * canvas.width, y: -36 },
      { x: Math.random() * canvas.width, y: canvas.height + 36 },
    ][side];
    const boss = state.seconds > 55 && Math.floor(state.seconds) % 45 < 2 && Math.random() < 0.18;
    const elite = boss || Math.random() < Math.min(0.26, state.seconds / 190);
    const waveScale = 1 + state.wave * 0.16;
    state.enemies.push({
      ...edge,
      hp: boss ? 220 * waveScale : elite ? 54 * waveScale : 22 * waveScale,
      maxHp: boss ? 220 * waveScale : elite ? 54 * waveScale : 22 * waveScale,
      speed: (boss ? 0.68 : elite ? 1.05 : 1.72) + state.wave * 0.08,
      radius: boss ? 31 : elite ? 19 : 12,
      elite,
      boss,
      wobble: Math.random() * 8,
      tint: boss ? "#ffcf8a" : elite ? "#b46cff" : "#ff6fb7",
    });
  }

  function drawUpgradeIcon(ctx, icon, x, y, size, color, frame = 0) {
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

  function drawAstronautChicken(ctx, player, frame) {
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

  const canvasRef = useCanvasGame((ctx, canvas, dt, frame) => {
    const state = stateRef.current;
    const isPlaying = statusRef.current === "play";
    musicTick();
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    const bg = ctx.createRadialGradient(canvas.width * 0.55, canvas.height * 0.42, 30, canvas.width * 0.5, canvas.height * 0.5, canvas.width);
    bg.addColorStop(0, "#311745");
    bg.addColorStop(0.24, "#17091f");
    bg.addColorStop(0.58, "#070913");
    bg.addColorStop(1, "#02040b");
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

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
      const x = (i * 97 + frame * speed * 0.12) % canvas.width;
      const y = (i * 53 + Math.sin(frame / 70 + i) * 7) % canvas.height;
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
      const mx = (keysRef.current.d || keysRef.current.arrowright ? 1 : 0) - (keysRef.current.a || keysRef.current.arrowleft ? 1 : 0);
      const my = (keysRef.current.s || keysRef.current.arrowdown ? 1 : 0) - (keysRef.current.w || keysRef.current.arrowup ? 1 : 0);
      const len = Math.max(1, Math.hypot(mx, my));
      state.player.x += (mx / len) * speed * (dt / 16);
      state.player.y += (my / len) * speed * (dt / 16);
      state.player.x = Math.max(30, Math.min(canvas.width - 30, state.player.x));
      state.player.y = Math.max(30, Math.min(canvas.height - 30, state.player.y));
      state.player.invuln = Math.max(0, state.player.invuln - dt);
      if (mx || my) state.particles.push({ x: state.player.x - mx * 13, y: state.player.y - my * 13, vx: -mx * 0.5 + (Math.random() - 0.5), vy: -my * 0.5 + (Math.random() - 0.5), life: 260, ttl: 260, color: "#ffcf8a" });

      state.spawn -= dt;
      if (state.spawn <= 0) {
        const count = 1 + Math.floor(Math.min(4, state.wave / 3));
        for (let i = 0; i < count; i += 1) spawnEnemy(state, canvas);
        state.spawn = Math.max(90, 640 - state.seconds * 8);
      }

      state.timers.bolt -= dt;
      if (state.weapons.bolt && state.timers.bolt <= 0 && state.enemies.length) {
        const targets = [...state.enemies].sort((a, b) => Math.hypot(a.x - state.player.x, a.y - state.player.y) - Math.hypot(b.x - state.player.x, b.y - state.player.y));
        const bolts = Math.min(targets.length, 1 + Math.floor((state.weapons.bolt - 1) / 2));
        for (let i = 0; i < bolts; i += 1) {
          const target = targets[i];
          const dx = target.x - state.player.x;
          const dy = target.y - state.player.y;
          const dist = Math.max(1, Math.hypot(dx, dy));
          state.shots.push({ type: "bolt", x: state.player.x, y: state.player.y, vx: dx / dist * 10.2, vy: dy / dist * 10.2, life: 820, damage: (14 + state.weapons.bolt * 4) * damageMult(state), pierce: Math.floor(state.weapons.bolt / 3) });
        }
        state.timers.bolt = Math.max(130, (520 - state.weapons.bolt * 28) * cooldownMult(state));
        if (frame % 3 === 0) sfx("shot");
      }

      state.timers.egg -= dt;
      if (state.weapons.egg && state.timers.egg <= 0 && state.enemies.length) {
        const target = state.enemies[Math.floor(Math.random() * state.enemies.length)];
        state.bombs.push({ x: state.player.x, y: state.player.y, tx: target.x, ty: target.y, life: 650, ttl: 650, radius: 54 + state.weapons.egg * 8, damage: (28 + state.weapons.egg * 8) * damageMult(state) });
        state.timers.egg = Math.max(650, (2100 - state.weapons.egg * 110) * cooldownMult(state));
        sfx("bomb");
      }

      state.timers.drone -= dt;
      if (state.weapons.drone && state.timers.drone <= 0 && state.enemies.length) {
        const count = Math.min(6, state.weapons.drone);
        const targets = [...state.enemies].sort((a, b) => Math.hypot(a.x - state.player.x, a.y - state.player.y) - Math.hypot(b.x - state.player.x, b.y - state.player.y));
        for (let i = 0; i < count; i += 1) {
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
        sfx("shot");
      }

      state.timers.thunder -= dt;
      if (state.weapons.thunder && state.timers.thunder <= 0 && state.enemies.length) {
        let ox = state.player.x;
        let oy = state.player.y;
        const chain = [...state.enemies].sort((a, b) => Math.hypot(a.x - ox, a.y - oy) - Math.hypot(b.x - ox, b.y - oy)).slice(0, 2 + state.weapons.thunder);
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
        const radius = 150 + state.weapons.nova * 26;
        state.enemies.forEach((enemy) => {
          const dist = Math.hypot(enemy.x - state.player.x, enemy.y - state.player.y);
          if (dist < radius) {
            enemy.hp -= (22 + state.weapons.nova * 8) * damageMult(state);
            const dx = (enemy.x - state.player.x) / Math.max(1, dist);
            const dy = (enemy.y - state.player.y) / Math.max(1, dist);
            enemy.x += dx * 22;
            enemy.y += dy * 22;
          }
        });
        state.particles.push({ ring: true, x: state.player.x, y: state.player.y, vx: 0, vy: 0, max: radius, life: 420, ttl: 420, color: "#ff6fb7" });
        state.timers.nova = Math.max(1800, (6200 - state.weapons.nova * 390) * cooldownMult(state));
        sfx("level");
      }

      state.timers.laser -= dt;
      if (state.weapons.laser && state.timers.laser <= 0 && state.enemies.length) {
        const target = [...state.enemies].sort((a, b) => b.hp - a.hp)[0];
        state.beams.push({ x1: state.player.x, y1: state.player.y, x2: target.x, y2: target.y, life: 220, ttl: 220, color: "#7af4dc", width: 7 });
        target.hp -= (40 + state.weapons.laser * 18) * damageMult(state);
        state.timers.laser = Math.max(950, (3600 - state.weapons.laser * 220) * cooldownMult(state));
        sfx("laser");
      }

      state.timers.regen -= dt;
      if (state.weapons.regen && state.timers.regen <= 0) {
        state.player.hp = Math.min(state.player.maxHp, state.player.hp + 1.6 + state.weapons.regen * 0.8);
        state.timers.regen = 1000;
      }

      state.enemies.forEach((enemy) => {
        const dx = state.player.x - enemy.x;
        const dy = state.player.y - enemy.y;
        const dist = Math.max(1, Math.hypot(dx, dy));
        enemy.slow = Math.max(0, (enemy.slow || 0) - dt);
        const enemySpeed = enemy.speed * (enemy.slow > 0 ? 0.48 : 1);
        enemy.x += (dx / dist * enemySpeed + Math.sin(state.seconds * 3 + enemy.wobble) * 0.22) * (dt / 16);
        enemy.y += (dy / dist * enemySpeed + Math.cos(state.seconds * 2 + enemy.wobble) * 0.16) * (dt / 16);
        if (dist < enemy.radius + 18 && state.player.invuln <= 0) {
          state.player.hp -= Math.max(5, (enemy.boss ? 31 : enemy.elite ? 20 : 13) - state.weapons.shield * 2.2);
          state.player.invuln = 720;
          burst(state.player.x, state.player.y, "#ff6fb7", 14);
          sfx("hit");
          if (state.player.hp <= 0) {
            state.over = true;
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
        shot.life -= dt;
      });
      state.shots = state.shots.filter((shot) => shot.life > 0 && shot.x > -30 && shot.x < canvas.width + 30 && shot.y > -30 && shot.y < canvas.height + 30);
      state.shots.forEach((shot) => {
        state.enemies.forEach((enemy) => {
          if (Math.hypot(shot.x - enemy.x, shot.y - enemy.y) < enemy.radius + 7 && shot.life > 0) {
            enemy.hp -= shot.damage;
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
        const t = 1 - bomb.life / bomb.ttl;
        bomb.x += (bomb.tx - bomb.x) * 0.08;
        bomb.y += (bomb.ty - bomb.y) * 0.08;
        bomb.life -= dt;
        if (t >= 0.95 || bomb.life <= 0) {
          state.enemies.forEach((enemy) => {
            if (Math.hypot(enemy.x - bomb.x, enemy.y - bomb.y) < bomb.radius) enemy.hp -= bomb.damage;
          });
          burst(bomb.x, bomb.y, "#ffcf8a", 24);
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

      if (state.weapons.orbit) {
        const count = 2 + Math.floor(state.weapons.orbit / 2);
        const radius = 58 + state.weapons.orbit * 6;
        for (let i = 0; i < count; i += 1) {
          const angle = frame / 24 + i / count * Math.PI * 2;
          const ox = state.player.x + Math.cos(angle) * radius;
          const oy = state.player.y + Math.sin(angle) * radius;
          state.enemies.forEach((enemy) => {
            if (Math.hypot(enemy.x - ox, enemy.y - oy) < enemy.radius + 12) enemy.hp -= (0.2 + state.weapons.orbit * 0.09) * dt * damageMult(state);
          });
        }
      }

      state.enemies = state.enemies.filter((enemy) => {
        if (enemy.hp > 0) return true;
        state.kills += 1;
        state.score += enemy.boss ? 120 : enemy.elite ? 32 : 12;
        state.gems.push({ x: enemy.x, y: enemy.y, value: enemy.boss ? 55 : enemy.elite ? 18 : 8, spin: Math.random() * 7 });
        burst(enemy.x, enemy.y, enemy.elite ? "#b46cff" : "#ff6fb7", enemy.elite ? 18 : 10);
        return false;
      });

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

      if (frame % 10 === 0) syncSnapshot(state);
    }

    state.particles.forEach((particle) => {
      particle.x += particle.vx * (dt / 16);
      particle.y += particle.vy * (dt / 16);
      particle.life -= dt;
    });
    state.particles = state.particles.filter((particle) => particle.life > 0).slice(-180);

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

    state.shots.forEach((shot) => {
      const shotColor = shot.type === "drone" ? "#8f7bff" : "#ffcf8a";
      ctx.strokeStyle = shot.type === "drone" ? "rgba(143,123,255,.9)" : "rgba(255,207,138,.88)";
      ctx.lineWidth = shot.type === "drone" ? 3 : 4;
      ctx.shadowBlur = 16;
      ctx.shadowColor = shotColor;
      ctx.beginPath();
      ctx.moveTo(shot.x - shot.vx * 1.5, shot.y - shot.vy * 1.5);
      ctx.lineTo(shot.x, shot.y);
      ctx.stroke();
      ctx.shadowBlur = 0;
    });

    state.enemies.forEach((enemy) => drawAlien(ctx, enemy, frame));

    state.beams.forEach((beam) => {
      const alpha = Math.max(0, beam.life / beam.ttl);
      const isThunder = beam.color === "#ffe66d";
      ctx.strokeStyle = isThunder ? `rgba(255,230,109,${alpha * 0.86})` : `rgba(122,244,220,${alpha * 0.82})`;
      ctx.lineWidth = beam.width || 6;
      ctx.shadowBlur = 24;
      ctx.shadowColor = beam.color;
      ctx.beginPath();
      ctx.moveTo(beam.x1, beam.y1);
      ctx.lineTo(beam.x2, beam.y2);
      ctx.stroke();
      ctx.shadowBlur = 0;
    });

    state.bombs.forEach((bomb) => {
      ctx.save();
      ctx.translate(bomb.x, bomb.y);
      ctx.shadowBlur = 18;
      ctx.shadowColor = "#ffcf8a";
      ctx.fillStyle = "#fff4e9";
      ctx.beginPath();
      ctx.ellipse(0, 0, 10, 14, 0.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(255,207,138,.5)";
      ctx.beginPath();
      ctx.arc(0, 0, bomb.radius * (1 - bomb.life / bomb.ttl), 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    });

    state.wells.forEach((well) => {
      const alpha = Math.max(0, well.life / well.ttl);
      ctx.save();
      ctx.translate(well.x, well.y);
      ctx.rotate(frame / 38);
      ctx.globalAlpha = 0.18 + alpha * 0.24;
      ctx.fillStyle = "#05030a";
      ctx.shadowBlur = 34;
      ctx.shadowColor = "#6d4cff";
      ctx.beginPath();
      ctx.arc(0, 0, well.radius * (0.45 + 0.08 * Math.sin(frame / 8)), 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#6d4cff";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.ellipse(0, 0, well.radius, well.radius * 0.36, 0, 0, Math.PI * 2);
      ctx.stroke();
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
        drawUpgradeIcon(ctx, "orbit", ox, oy, 22, "#ffcf8a", frame);
      }
    }

    state.particles.forEach((particle) => {
      ctx.globalAlpha = Math.max(0, particle.life / particle.ttl);
      if (particle.ring) {
        ctx.strokeStyle = particle.color;
        ctx.lineWidth = 3;
        ctx.shadowBlur = 22;
        ctx.shadowColor = particle.color;
        ctx.beginPath();
        ctx.arc(particle.x, particle.y, particle.max * (1 - particle.life / particle.ttl), 0, Math.PI * 2);
        ctx.stroke();
        ctx.shadowBlur = 0;
      } else {
        ctx.fillStyle = particle.color;
        ctx.beginPath();
        ctx.arc(particle.x, particle.y, 2.4, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    });

    drawAstronautChicken(ctx, player, frame);

    const barX = 24;
    ctx.fillStyle = "rgba(5,7,14,.66)";
    ctx.fillRect(barX, canvas.height - 62, 210, 16);
    ctx.fillStyle = "#ff6f7f";
    ctx.fillRect(barX, canvas.height - 62, 210 * Math.max(0, player.hp) / player.maxHp, 16);
    ctx.fillStyle = "rgba(5,7,14,.66)";
    ctx.fillRect(barX, canvas.height - 38, 210, 12);
    ctx.fillStyle = "#b46cff";
    ctx.fillRect(barX, canvas.height - 38, 210 * Math.max(0, state.xp) / Math.max(1, state.nextXp), 12);
    ctx.strokeStyle = "rgba(255,218,184,.25)";
    ctx.strokeRect(barX, canvas.height - 62, 210, 16);
    ctx.strokeRect(barX, canvas.height - 38, 210, 12);

    if (statusRef.current === "menu") {
      ctx.fillStyle = "rgba(3,5,12,.52)";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = "#fff4e9";
      ctx.font = "900 34px Inter, Arial";
      ctx.fillText("Pepple Survivor", canvas.width / 2 - 148, canvas.height / 2 - 12);
      ctx.font = "700 16px Inter, Arial";
      ctx.fillStyle = "#d9c4d2";
      ctx.fillText("Start druecken, XP sammeln, Waffen-Build eskalieren.", canvas.width / 2 - 212, canvas.height / 2 + 22);
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
  }, [status, audioOn]);

  function start() {
    stateRef.current = {
      player: { x: 460, y: 250, hp: 110, maxHp: 110, invuln: 0 },
      gems: [],
      enemies: [],
      shots: [],
      bombs: [],
      beams: [],
      wells: [],
      particles: [],
      score: 0,
      xp: 0,
      nextXp: 60,
      seconds: 0,
      kills: 0,
      level: 1,
      wave: 1,
      spawn: 0,
      timers: { bolt: 0, nova: 2600, laser: 1600, egg: 900, drone: 640, thunder: 2100, gravity: 3200, regen: 1000 },
      weapons: { bolt: 1, orbit: 0, nova: 0, laser: 0, egg: 0, aura: 0, drone: 0, thunder: 0, frost: 0, gravity: 0, speed: 0, magnet: 0, shield: 0, regen: 0, might: 0, cooldown: 0 },
      over: false,
    };
    setChoices([]);
    setSnapshot({ score: 0, level: 1, seconds: 0, kills: 0, hp: 110, maxHp: 110, xp: 0, nextXp: 60, wave: 1, weapons: [{ id: "bolt", name: "Federblitz", level: 1, color: "#c88cff", icon: "feather" }] });
    setMessage("Sammle XP-Kristalle. Beim Level-Up waehlt ihr den Build.");
    audio();
    sfx("start");
    setGameStatus("play");
  }

  function chooseUpgrade(upgrade) {
    const state = stateRef.current;
    state.weapons[upgrade.id] = Number(state.weapons[upgrade.id] || 0) + 1;
    if (upgrade.id === "shield") {
      state.player.maxHp += 18;
      state.player.hp = Math.min(state.player.maxHp, state.player.hp + 24);
    }
    if (upgrade.id === "speed") state.player.invuln = Math.max(state.player.invuln, 420);
    setChoices([]);
    setMessage(`${upgrade.name} Level ${state.weapons[upgrade.id]} aktiviert.`);
    syncSnapshot(state);
    sfx("start");
    setGameStatus("play");
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
        <div><span>HP</span><b>{snapshot.hp}</b><i><em style={{ width: `${Math.max(0, Math.min(100, snapshot.hp / Math.max(1, snapshot.maxHp || 110) * 100))}%` }} /></i></div>
        <div><span>XP</span><b>{snapshot.xp}/{snapshot.nextXp}</b><i><em className="xpFill" style={{ width: `${Math.max(0, Math.min(100, snapshot.xp / Math.max(1, snapshot.nextXp) * 100))}%` }} /></i></div>
      </div>
      <div className="survivorBuild">
        <span>Build</span>
        {snapshot.weapons.map((weapon) => (
          <div className="weaponChip" key={weapon.id} style={{ "--weapon": weapon.color }}>
            <b>{weapon.name}</b><small>Lv {weapon.level}</small>
          </div>
        ))}
      </div>
      <div className="survivorStage">
        <audio
          ref={musicRef}
          preload="auto"
          onEnded={() => {
            if (!musicRef.current) return;
            musicRef.current.src = musicPlaylist[Math.floor(Math.random() * musicPlaylist.length)];
            startMusic();
          }}
        />
        <canvas className="gameCanvas survivorCanvas" ref={canvasRef} width="920" height="500" />
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
      </div>
      <div className="gameActions survivorActions">
        <button onClick={start} type="button"><RefreshCw size={16} /> {status === "play" ? "Neu starten" : "Start"}</button>
        <button className="ghost" onClick={() => setAudioOn((value) => !value)} type="button"><Zap size={16} /> Musik {audioOn ? "an" : "aus"}</button>
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
  const gameFromHash = () => {
    const [, nextGame] = window.location.hash.replace("#", "").split("/");
    return gameMeta[nextGame] && nextGame !== "dnd" ? nextGame : "chicken-jump";
  };
  const [game, setGameState] = useState(gameFromHash);
  function setGame(nextGame) {
    setGameState(nextGame);
    window.history.replaceState(null, "", `#games/${nextGame}`);
  }
  useEffect(() => {
    function syncGame() { setGameState(gameFromHash()); }
    window.addEventListener("hashchange", syncGame);
    return () => window.removeEventListener("hashchange", syncGame);
  }, []);
  const current = {
    "chicken-jump": <ChickenJump user={user} />,
    "chicken-snake": <ChickenSnake user={user} />,
    "chicken-racer": <ChickenRacer user={user} />,
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
  const pageFromHash = () => {
    const next = window.location.hash.replace("#", "").split("/")[0];
    return nav.some((item) => item.id === next) || ["login", "support"].includes(next) ? next : "home";
  };
  const [page, setPageState] = useState(pageFromHash);
  const [user, setUser] = useState(null);

  function setPage(next) {
    setPageState(next);
    if (window.location.hash !== `#${next}`) window.history.replaceState(null, "", `#${next}`);
  }

  useEffect(() => {
    api("/api/auth/me").then((result) => setUser(result.user)).catch(() => {});
  }, []);

  useEffect(() => {
    function syncPage() { setPageState(pageFromHash()); }
    window.addEventListener("hashchange", syncPage);
    return () => window.removeEventListener("hashchange", syncPage);
  }, []);

  const content = useMemo(() => {
    if (page === "home") return <HomePage user={user} setPage={setPage} />;
    if (page === "login") return <LoginPage onLogin={(nextUser) => { setUser(nextUser); setPage("home"); }} />;
    if (page === "news") return <ListPage title="News" path="/api/news" render={(item) => <article className="card" key={item.id}><h3>{item.title}</h3><p>{item.body}</p></article>} />;
    if (page === "members") return <MembersPage />;
    if (page === "profile") return <ProfilePage user={user} setUser={setUser} setPage={setPage} />;
    if (page === "shop") return <ShopPage user={user} setPage={setPage} />;
    if (page === "leaderboard") return <LeaderboardPage />;
    if (page === "events") return <EventsPage user={user} setPage={setPage} />;
    if (page === "games") return <GamesPage user={user} />;
    if (page === "systematics") return <SystematicsPage />;
    if (page === "gallery") return <ListPage title="Hall of Fame" path="/api/gallery" render={(item) => <article className="card imageCard" key={item.id}>{item.image_data && <img src={item.image_data} alt="" />}<h3>{item.title || "Kunstwerk"}</h3><p>{item.username}</p></article>} />;
    if (page === "admin") return <AdminPage />;
    return <SupportPage user={user} />;
  }, [page, user]);

  return (
    <Shell page={page} setPage={setPage} user={user} onLogout={() => { setToken(""); setUser(null); setPage("home"); }}>
      {content}
      <button className="supportFab" onClick={() => setPage("support")} type="button">Support</button>
    </Shell>
  );
}

createRoot(document.getElementById("root")).render(<App />);
