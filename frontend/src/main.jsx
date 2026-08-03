import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  CalendarDays,
  Crown,
  Gamepad2,
  Home,
  LogIn,
  LogOut,
  Newspaper,
  Palette,
  Shield,
  Sparkles,
  ShoppingBasket,
  Star,
  Trophy,
  User,
  Users,
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
  { id: "gallery", label: "Hall of Fame", icon: Palette },
  { id: "admin", label: "Admin", icon: Shield },
];

function useApi(path, fallback) {
  const [data, setData] = useState(fallback);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    api(path)
      .then((next) => alive && setData(next))
      .catch((err) => alive && setError(err.message))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [path]);

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

function Shell({ page, setPage, user, onLogout, children }) {
  return (
    <>
      <header className="topbar">
        <button className="brand" onClick={() => setPage("home")} type="button">
          <Crown size={22} />
          <span>Aviary</span>
        </button>
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
      <nav className="mainnav">
        {nav.map((item) => {
          const Icon = item.icon;
          return (
            <button
              className={page === item.id ? "active" : ""}
              key={item.id}
              onClick={() => setPage(item.id)}
              type="button"
            >
              <Icon size={17} />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>
      <main>{children}</main>
    </>
  );
}

function HomePage({ user, setPage }) {
  const { data, loading, error } = useApi("/api/dashboard", {
    stats: {},
    leaderboard: [],
    news: [],
    events: [],
    gallery: [],
  });
  const topViewer = data.leaderboard[0];
  const podium = data.leaderboard.slice(0, 3);
  const nextNews = data.news[0];

  return (
    <section className="homePage">
      <div className="hero">
        <div className="heroCopy">
          <p className="kicker">Aviary</p>
          <h1>{user ? `Willkommen zurueck, ${user.username}` : "Willkommen in der Aviary"}</h1>
          <p>Dein Community-Hub fuer Pepples, Chickens, Rewards, Events, Galerie und Arcade-Momente.</p>
          <div className="actions">
            <button onClick={() => setPage(user ? "profile" : "login")} type="button">
              {user ? "Profil oeffnen" : "Einloggen"}
            </button>
            <button className="ghost" onClick={() => setPage("games")} type="button">
              Minispiele
            </button>
          </div>
          {nextNews && (
            <button className="newsTicker" onClick={() => setPage("news")} type="button">
              <Newspaper size={16} />
              <span>{nextNews.title}</span>
            </button>
          )}
        </div>
        <div className="heroPanel">
          <Stat label="Pepples gesamt" value={data.stats.braincells} />
          <Stat label="Chickens im Umlauf" value={data.stats.chickens} />
          <Stat label="Mitglieder" value={data.stats.users} />
        </div>
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
      </div>
      {error && <div className="notice error">{error}</div>}
      {loading && <div className="notice">Lade Aviary-Daten...</div>}
      <section className="dashboardSplit">
        <div className="spotlightPanel">
          <p className="kicker">Aktuelle Nummer 1</p>
          <h2>{topViewer?.username || "Noch frei"}</h2>
          <p>{topViewer ? `${topViewer.braincells || 0} Pepples und ${topViewer.chickens || 0} Chickens` : "Der naechste Run kann alles drehen."}</p>
          <div className="podium">
            {podium.map((item, index) => (
              <article className={`podiumCard place${index + 1}`} key={item.username}>
                <span>#{index + 1}</span>
                <strong>{item.username}</strong>
                <small>{item.braincells || 0} Pepples</small>
              </article>
            ))}
          </div>
        </div>
        <div className="activityPanel">
          <p className="kicker">Live-Schwarm</p>
          <h2>Heute in der Aviary</h2>
          <div className="activityList">
            <div><Star size={17} /><span>{data.news.length ? `${data.news.length} News aktiv` : "Keine neuen News"}</span></div>
            <div><CalendarDays size={17} /><span>{data.events.length ? `${data.events.length} Events geplant` : "Keine Events geplant"}</span></div>
            <div><Palette size={17} /><span>{data.gallery.length ? `${data.gallery.length} Hall-of-Fame Bilder` : "Galerie wartet auf Kunst"}</span></div>
          </div>
        </div>
      </section>
      <CardGrid title="Top Viewer" items={data.leaderboard.slice(0, 8)} render={(item, index) => (
        <article className="viewerCard" key={item.username}>
          <span className="rank">#{index + 1}</span>
          <div className="viewerAvatar">{item.avatar_url ? <img src={item.avatar_url} alt="" /> : item.username?.slice(0, 2)}</div>
          <h3>{item.username}</h3>
          <p>{item.braincells || 0} Pepples</p>
          <small>{item.chickens || 0} Chickens</small>
        </article>
      )} />
    </section>
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
        <h1>{mode === "login" ? "Anmelden" : "Registrierung anfragen"}</h1>
        <div className="segmented">
          <button className={mode === "login" ? "active" : ""} onClick={() => setMode("login")} type="button">Login</button>
          <button className={mode === "request" ? "active" : ""} onClick={() => setMode("request")} type="button">Anfrage</button>
          <button className={mode === "complete" ? "active" : ""} onClick={() => setMode("complete")} type="button">Code</button>
        </div>
        <form onSubmit={submit} className="form">
          <label>Twitch-Name<input value={form.username} onChange={(event) => setForm({ ...form, username: event.target.value })} /></label>
          <label>Passwort<input type="password" value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} /></label>
          {mode === "complete" && (
            <label>Einmalcode<input value={form.code} onChange={(event) => setForm({ ...form, code: event.target.value })} /></label>
          )}
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

  if (!user) {
    return <EmptyLogin setPage={setPage} />;
  }

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
        <div className="avatar">{user.avatar_url ? <img src={user.avatar_url} alt="" /> : user.username?.slice(0, 2)}</div>
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
      <h1>Shop</h1>
      {message && <div className="notice">{message}</div>}
      {loading && <div className="notice">Lade Shop...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="grid">
        {data.map((item) => (
          <article className="card" key={item.id || item.name}>
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
          <article className="rowCard" key={event.id}>
            <div><h3>{event.title}</h3><p>{event.description}</p><span>{event.event_date}</span></div>
            <button onClick={() => signup(event.id)} type="button">Anmelden</button>
          </article>
        ))}
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
        <div className="list">
          {wishes.map((item) => <article className="miniCard" key={item.id}><strong>{item.title}</strong><span>{item.description}</span></article>)}
        </div>
      </div>
    </section>
  );
}

function GamesPage() {
  const games = [
    "Chicken Jump",
    "Chicken Snake",
    "Chicken Racer",
    "Chicken Football",
    "Pepple Survivor",
    "Dungeons and Dragons",
  ];
  return <CardGrid title="Minispiele" items={games} render={(game) => <article className="card" key={game}><Gamepad2 /><h3>{game}</h3><p>Migration aus der Streamlit-Komponente in Arbeit. Scores laufen schon ueber die neue API.</p></article>} />;
}

function AdminPage() {
  const [password, setPassword] = useState("");
  const [overview, setOverview] = useState(null);
  const [message, setMessage] = useState("");
  async function load() {
    try {
      const result = await api("/api/admin/overview", { headers: { "X-Admin-Password": password } });
      setOverview(result);
    } catch (err) {
      setMessage(err.message);
    }
  }
  return (
    <section className="stack">
      <div className="panel form">
        <h1>Admin</h1>
        <label>Admin Passwort<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} /></label>
        <button onClick={load} type="button">Dashboard laden</button>
        {message && <div className="notice">{message}</div>}
      </div>
      {overview && <CardGrid title="Registrierungen" items={overview.registration_requests} render={(item) => <article className="card" key={item.id}><h3>{item.username}</h3><p>{item.status}</p></article>} />}
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
  const [page, setPage] = useState("home");
  const [user, setUser] = useState(null);

  useEffect(() => {
    api("/api/auth/me").then((result) => setUser(result.user)).catch(() => {});
  }, []);

  const content = useMemo(() => {
    if (page === "home") return <HomePage user={user} setPage={setPage} />;
    if (page === "login") return <LoginPage onLogin={(nextUser) => { setUser(nextUser); setPage("home"); }} />;
    if (page === "news") return <ListPage title="News" path="/api/news" render={(item) => <article className="card" key={item.id}><h3>{item.title}</h3><p>{item.body}</p></article>} />;
    if (page === "members") return <ListPage title="Mitglieder" path="/api/users" render={(item) => <article className="card" key={item.username}><h3>{item.username}</h3><p>{item.braincells || 0} Pepples · {item.chickens || 0} Chickens</p></article>} />;
    if (page === "profile") return <ProfilePage user={user} setUser={setUser} setPage={setPage} />;
    if (page === "shop") return <ShopPage user={user} setPage={setPage} />;
    if (page === "leaderboard") return <ListPage title="Rangliste" path="/api/leaderboard" render={(item, index) => <article className="rowCard" key={item.username}><strong>#{index + 1} {item.username}</strong><span>{item.rank_name} · {item.braincells || 0} Pepples</span></article>} />;
    if (page === "events") return <EventsPage user={user} setPage={setPage} />;
    if (page === "games") return <GamesPage />;
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
