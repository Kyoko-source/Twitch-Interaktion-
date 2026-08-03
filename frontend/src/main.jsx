import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  CalendarDays,
  Check,
  Crown,
  Gamepad2,
  Home,
  LogIn,
  LogOut,
  Newspaper,
  Palette,
  Plus,
  RefreshCw,
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
            <button className={page === item.id ? "active" : ""} key={item.id} onClick={() => setPage(item.id)} type="button">
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
      <div className="hero">
        <div className="heroCopy">
          <p className="kicker">Aviary</p>
          <h1>{user ? `Willkommen zurueck, ${user.username}` : "Willkommen in der Aviary"}</h1>
          <p>Dein Community-Hub fuer Pepples, Chickens, Rewards, Events, Galerie und flimmernde Arcade-Runs.</p>
          <div className="actions">
            <button onClick={() => setPage(user ? "profile" : "login")} type="button">{user ? "Profil oeffnen" : "Einloggen"}</button>
            <button className="ghost" onClick={() => setPage("games")} type="button">Minispiele</button>
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
        <CageMark />
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
          <Avatar user={item} />
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
  const [running, setRunning] = useState(false);
  const [message, setMessage] = useState("WASD bewegen, laenger ueberleben.");
  const [snapshot, setSnapshot] = useState({ score: 0, level: 1, seconds: 0, kills: 0 });
  const [refreshKey, setRefreshKey] = useState(0);
  const keysRef = useRef({});
  const stateRef = useRef({ player: { x: 460, y: 200 }, gems: [], enemies: [], score: 0, seconds: 0, spawn: 0, over: false });

  useEffect(() => {
    function down(event) { keysRef.current[event.key.toLowerCase()] = true; }
    function up(event) { keysRef.current[event.key.toLowerCase()] = false; }
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };
  }, []);

  const canvasRef = useCanvasGame((ctx, canvas, dt) => {
    const state = stateRef.current;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#100916"; ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "rgba(180,108,255,.08)";
    for (let i = 0; i < 70; i += 1) ctx.fillRect((i * 113) % canvas.width, (i * 67) % canvas.height, 2, 2);
    if (running && !state.over) {
      state.seconds += dt / 1000;
      const speed = 4.2;
      if (keysRef.current.w || keysRef.current.arrowup) state.player.y -= speed;
      if (keysRef.current.s || keysRef.current.arrowdown) state.player.y += speed;
      if (keysRef.current.a || keysRef.current.arrowleft) state.player.x -= speed;
      if (keysRef.current.d || keysRef.current.arrowright) state.player.x += speed;
      state.player.x = Math.max(20, Math.min(canvas.width - 20, state.player.x));
      state.player.y = Math.max(20, Math.min(canvas.height - 20, state.player.y));
      state.spawn -= dt;
      if (state.spawn <= 0) {
        state.enemies.push({ x: Math.random() * canvas.width, y: -20, speed: 1.5 + state.seconds / 28 });
        state.gems.push({ x: 30 + Math.random() * (canvas.width - 60), y: 30 + Math.random() * (canvas.height - 60) });
        state.spawn = Math.max(260, 900 - state.seconds * 8);
      }
      state.enemies.forEach((enemy) => {
        const dx = state.player.x - enemy.x;
        const dy = state.player.y - enemy.y;
        const dist = Math.max(1, Math.hypot(dx, dy));
        enemy.x += dx / dist * enemy.speed;
        enemy.y += dy / dist * enemy.speed;
        if (dist < 25) {
          state.over = true;
          setRunning(false);
          setMessage(`Run beendet: ${state.score} Punkte`);
        }
      });
      state.gems = state.gems.filter((gem) => {
        if (Math.hypot(gem.x - state.player.x, gem.y - state.player.y) < 24) {
          state.score += 8 + Math.floor(state.seconds / 10);
          setSnapshot({ score: state.score, level: 1 + Math.floor(state.seconds / 20), seconds: Math.floor(state.seconds), kills: Math.floor(state.score / 18) });
          return false;
        }
        return true;
      });
    }
    state.gems.forEach((gem) => { ctx.fillStyle = "#7af4dc"; ctx.beginPath(); ctx.arc(gem.x, gem.y, 7, 0, Math.PI * 2); ctx.fill(); });
    state.enemies.forEach((enemy) => { ctx.fillStyle = "#ff6fb7"; ctx.beginPath(); ctx.arc(enemy.x, enemy.y, 13, 0, Math.PI * 2); ctx.fill(); });
    ctx.fillStyle = "#ffcf8a"; ctx.beginPath(); ctx.arc(state.player.x, state.player.y, 18, 0, Math.PI * 2); ctx.fill();
  }, [running]);

  function start() {
    stateRef.current = { player: { x: 460, y: 200 }, gems: [], enemies: [], score: 0, seconds: 0, spawn: 0, over: false };
    setSnapshot({ score: 0, level: 1, seconds: 0, kills: 0 });
    setMessage("Sammle Pepple-Kerne und bleib in Bewegung.");
    setRunning(true);
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

  return <GameFrame meta={gameMeta["braincell-survivor"]} canvasRef={canvasRef} message={message} score={snapshot.score} level={snapshot.level} onStart={start} onSave={user && snapshot.score > 0 ? save : null} refreshKey={refreshKey} game="braincell-survivor" />;
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
  const [game, setGame] = useState("chicken-jump");
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
  const [page, setPage] = useState("home");
  const [user, setUser] = useState(null);

  useEffect(() => {
    api("/api/auth/me").then((result) => setUser(result.user)).catch(() => {});
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
