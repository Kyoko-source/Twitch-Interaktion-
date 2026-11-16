import React, { Suspense, useEffect, useMemo, useState, lazy } from "react";
import { createRoot } from "react-dom/client";
import { flushSync } from "react-dom";
import { api, setToken } from "./api";
import { AppShell } from "./ui/CommunityLayout";
import { ChatToasts, useChatUnread } from "./ui/ChatNotifier";
import { PurchaseCelebration } from "./economy/PurchaseCelebration";
import { LevelUpCelebration } from "./economy/LevelUp";
import { AdminPage } from "./pages/AdminPage";
import { AdventPage } from "./pages/AdventPage";
import { ChatPage } from "./pages/ChatPage";
import { EventsPage } from "./pages/EventsPage";
import { GalleryPage } from "./pages/GalleryPage";
import { GamesPage } from "./pages/GamesPage";
import { HomePage } from "./pages/HomePage";
import { LeaderboardPage } from "./pages/LeaderboardPage";
import { LoginPage } from "./pages/LoginPage";
import { MembersPage } from "./pages/MembersPage";
import { ProfilePage } from "./pages/ProfilePage";
import { ProfileView } from "./profile/ProfileView";
import { ChristmasLayer, ChristmasPrompt } from "./christmas/Christmas";
import { ShopPage } from "./pages/ShopPage";
import { SupportPage } from "./pages/SupportPage";
import { SystematicsPage } from "./pages/SystematicsPage";
import { ListPage, isAdmin, nav, routeParts } from "./pages/shared";
const StreamControlOverlay = lazy(() => import("./stream/StreamControlOverlay").then((module) => ({ default: module.StreamControlOverlay })));
const DerbyOverlay = lazy(() => import("./horses/DerbyOverlay").then((module) => ({ default: module.DerbyOverlay })));
const Nullsignal = lazy(() => import("./nullsignal/Nullsignal").then((module) => ({ default: module.Nullsignal })));
import "./economy/account-tools.css";
import "./styles.css";
import "./ui/community-theme.css";
import "@fontsource/inter/latin-400.css";
import "@fontsource/inter/latin-500.css";
import "@fontsource/inter/latin-600.css";
import "@fontsource/inter/latin-700.css";
import "@fontsource/space-grotesk/latin-500.css";
import "@fontsource/space-grotesk/latin-700.css";
import "./ui/neon-theme.css";

function App() {
  const pageFromRoute = () => {
    const [next] = routeParts();
    return nav.some((item) => item.id === next) || ["login", "support", "nullsignal", "u"].includes(next) ? next : "home";
  };
  const [page, setPageState] = useState(pageFromRoute);
  const [routeKey, setRouteKey] = useState(() => window.location.hash);
  const [user, setUser] = useState(null);
  const [sessionNotice, setSessionNotice] = useState("");
  const chatUnread = useChatUnread(user);
  // Christmas look: asked once per visit/login until the member says yes; switchable in the profile.
  const [xmasAsk, setXmasAsk] = useState(false);
  const [logins, setLogins] = useState(0);
  const [xmasIntro, setXmasIntro] = useState(false);
  const [xmasLeaving, setXmasLeaving] = useState(false);
  // Only the real server sends this field; without it nobody is asked.
  const xmasMode = user?.christmas || "";
  const askedKey = user ? `aviary_xmas_asked_${user.username}` : "";

  useEffect(() => {
    if (!user || !["ask", "declined"].includes(xmasMode)) { setXmasAsk(false); return undefined; }
    let asked = false;
    try { asked = sessionStorage.getItem(askedKey) === "1"; } catch { /* ask anyway */ }
    if (asked) return undefined;
    const timer = window.setTimeout(() => setXmasAsk(true), 900);
    return () => window.clearTimeout(timer);
  }, [user?.username, xmasMode, logins]);

  // Switching on or off spreads as a circle from where the member clicked (View Transitions);
  // browsers without it fade the decorations out instead.
  function setChristmas(mode, origin) {
    try { sessionStorage.setItem(askedKey, "1"); } catch { /* fine */ }
    api("/api/profile/christmas", { method: "PUT", body: JSON.stringify({ mode }) }).catch(() => {});
    const turningOn = mode === "on";
    const switching = turningOn !== (xmasMode === "on");
    const apply = () => flushSync(() => {
      setXmasAsk(false);
      setXmasLeaving(false);
      if (turningOn) setXmasIntro(true);
      setUser((current) => (current ? { ...current, christmas: mode } : current));
    });
    if (turningOn) window.setTimeout(() => setXmasIntro(false), 10000);
    const root = document.documentElement;
    const calm = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (switching && document.startViewTransition && !calm) {
      root.style.setProperty("--xm-x", `${origin?.x ?? window.innerWidth / 2}px`);
      root.style.setProperty("--xm-y", `${origin?.y ?? window.innerHeight / 2}px`);
      root.classList.add("xmReveal");
      const transition = document.startViewTransition(apply);
      transition.finished.finally(() => root.classList.remove("xmReveal"));
    } else if (switching && !turningOn) {
      setXmasLeaving(true);
      window.setTimeout(apply, 700);
    } else {
      apply();
    }
  }

  function toggleChristmas(event) {
    const rect = event?.currentTarget?.getBoundingClientRect?.();
    setChristmas(xmasMode === "on" ? "off" : "on", rect ? { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 } : null);
  }


  function setPage(next) {
    setPageState(next.split("/")[0]);
    if (window.location.hash !== `#${next}`) window.history.replaceState(null, "", `/#${next}`);
    setRouteKey(`#${next}`);
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
    function syncPage() { setPageState(pageFromRoute()); setRouteKey(window.location.hash); }
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
    if (page === "nullsignal") return <Suspense fallback={<div className="notice">Handbuch wird vorbereitet …</div>}><Nullsignal user={user}/></Suspense>;
    if (page === "home") return <HomePage user={user} setPage={setPage} />;
    if (page === "advent") return <AdventPage user={user} />;
    if (page === "login") return <LoginPage onLogin={(nextUser) => { try { sessionStorage.removeItem(`aviary_xmas_asked_${nextUser.username}`); } catch { /* fine */ } setLogins((n) => n + 1); setSessionNotice(""); setUser(nextUser); setPage("home"); }} />;
    if (page === "news") return <ListPage title="News" path="/api/news" render={(item) => <article className="card" key={item.id}><h3>{item.title}</h3><p>{item.body}</p></article>} />;
    if (page === "members") return <MembersPage user={user} setPage={setPage} />;
    if (page === "chat") return <ChatPage user={user} setPage={setPage} unread={chatUnread.summary} />;
    if (page === "u") return <ProfileView username={decodeURIComponent(routeParts()[1] || "")} me={user} setUser={setUser} setPage={setPage} />;
    if (page === "profile") return <ProfilePage user={user} setUser={setUser} setPage={setPage} christmas={xmasMode} setChristmas={setChristmas} />;
    if (page === "shop") return <ShopPage user={user} setPage={setPage} />;
    if (page === "leaderboard") return <LeaderboardPage />;
    if (page === "events") return <EventsPage user={user} setPage={setPage} />;
    if (page === "games") return <GamesPage user={user} />;
    if (page === "systematics") return <SystematicsPage user={user} />;
    if (page === "gallery") return <GalleryPage user={user} setPage={setPage} />;
    if (page === "admin") return <AdminPage />;
    return <SupportPage user={user} />;
  }, [page, routeKey, user, chatUnread.summary, xmasMode]);
  const xmasOn = Boolean(user) && xmasMode === "on";

  return (
    <AppShell xmas={xmasOn ? { intro: xmasIntro } : null} onToggleXmas={user && xmasMode ? toggleChristmas : null} chatUnread={chatUnread.summary.total} nav={nav} hiddenIds={isAdmin(user) ? [] : ["admin"]} page={page} setPage={setPage} user={user} onLogout={() => { api("/api/presence", { method: "DELETE" }).catch(() => {}).finally(() => { setToken(""); setUser(null); setPage("home"); }); }}>
      {sessionNotice && <p className="notice" role="alert">{sessionNotice}</p>}
      {content}
      <ChatToasts toasts={chatUnread.toasts} dismiss={chatUnread.dismiss} setPage={setPage} />
      <PurchaseCelebration />
      <LevelUpCelebration user={user} />
      {xmasOn && <ChristmasLayer intro={xmasIntro} page={page} leaving={xmasLeaving} />}
      {xmasAsk && <ChristmasPrompt again={xmasMode === "declined"} onYes={(event) => setChristmas("on", event?.clientX ? { x: event.clientX, y: event.clientY } : null)} onNo={() => setChristmas("declined")} />}
    </AppShell>
  );
}

// OBS browser sources (Chicken Derby, Admin Stream Control): only the overlay, no site around it.
const overlayPath = window.location.pathname.replace(/\/+$/, "");
const Overlay = { "/stream/derby": DerbyOverlay, "/stream/control": StreamControlOverlay }[overlayPath];
createRoot(document.getElementById("root")).render(Overlay ? <Suspense fallback={null}><Overlay /></Suspense> : <App />);
