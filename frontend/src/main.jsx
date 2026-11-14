import React, { Suspense, useEffect, useMemo, useState, lazy } from "react";
import { createRoot } from "react-dom/client";
import { api, setToken } from "./api";
import { AppShell } from "./ui/CommunityLayout";
import { ChatToasts, useChatUnread } from "./ui/ChatNotifier";
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
import { ShopPage } from "./pages/ShopPage";
import { SupportPage } from "./pages/SupportPage";
import { SystematicsPage } from "./pages/SystematicsPage";
import { ListPage, isAdmin, nav, routeParts } from "./pages/shared";
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
    return nav.some((item) => item.id === next) || ["login", "support", "nullsignal"].includes(next) ? next : "home";
  };
  const [page, setPageState] = useState(pageFromRoute);
  const [user, setUser] = useState(null);
  const [sessionNotice, setSessionNotice] = useState("");
  const chatUnread = useChatUnread(user);

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
    if (page === "nullsignal") return <Suspense fallback={<div className="notice">Handbuch wird vorbereitet …</div>}><Nullsignal user={user}/></Suspense>;
    if (page === "home") return <HomePage user={user} setPage={setPage} />;
    if (page === "advent") return <AdventPage user={user} />;
    if (page === "login") return <LoginPage onLogin={(nextUser) => { setSessionNotice(""); setUser(nextUser); setPage("home"); }} />;
    if (page === "news") return <ListPage title="News" path="/api/news" render={(item) => <article className="card" key={item.id}><h3>{item.title}</h3><p>{item.body}</p></article>} />;
    if (page === "members") return <MembersPage user={user} setPage={setPage} />;
    if (page === "chat") return <ChatPage user={user} setPage={setPage} unread={chatUnread.summary} />;
    if (page === "profile") return <ProfilePage user={user} setUser={setUser} setPage={setPage} />;
    if (page === "shop") return <ShopPage user={user} setPage={setPage} />;
    if (page === "leaderboard") return <LeaderboardPage />;
    if (page === "events") return <EventsPage user={user} setPage={setPage} />;
    if (page === "games") return <GamesPage user={user} />;
    if (page === "systematics") return <SystematicsPage user={user} />;
    if (page === "gallery") return <GalleryPage user={user} setPage={setPage} />;
    if (page === "admin") return <AdminPage />;
    return <SupportPage user={user} />;
  }, [page, user, chatUnread.summary]);

  return (
    <AppShell chatUnread={chatUnread.summary.total} nav={nav} hiddenIds={isAdmin(user) ? [] : ["admin"]} page={page} setPage={setPage} user={user} onLogout={() => { api("/api/presence", { method: "DELETE" }).catch(() => {}).finally(() => { setToken(""); setUser(null); setPage("home"); }); }}>
      {sessionNotice && <p className="notice" role="alert">{sessionNotice}</p>}
      {content}
      <ChatToasts toasts={chatUnread.toasts} dismiss={chatUnread.dismiss} setPage={setPage} />
    </AppShell>
  );
}

createRoot(document.getElementById("root")).render(<App />);
