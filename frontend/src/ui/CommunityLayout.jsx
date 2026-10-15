import React, { useEffect, useRef, useState } from "react";
import { ArrowRight, CalendarDays, ChevronRight, Crown, Gamepad2, Home, LogIn, LogOut, Menu, MessageCircle, Newspaper, Play, ShoppingBasket, Sparkles, Trophy, User, Users, X } from "lucide-react";

const groups = [
  { label: "Übersicht", ids: ["home"] },
  { label: "Community", ids: ["news", "members", "chat", "events", "gallery"] },
  { label: "Spielen & Sammeln", ids: ["games", "leaderboard", "shop"] },
  { label: "Konto", ids: ["profile", "systematics", "admin"] },
];
const number = (value) => Number(value || 0).toLocaleString("de-DE");

export function MemberAvatar({ user, className = "communityAvatar" }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [user?.avatar_url]);
  return <span className={className} aria-hidden="true">{user?.avatar_url && !failed ? <img src={user.avatar_url} onError={() => setFailed(true)} alt="" /> : String(user?.username || "AV").slice(0, 2)}</span>;
}

export function AppShell({ page, setPage, user, onLogout, nav, children }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const railRef = useRef(null);
  const menuRef = useRef(null);
  const label = nav.find((item) => item.id === page)?.label || (page === "login" ? "Anmelden" : "Support");

  useEffect(() => { document.title = `${label} · Aviary`; }, [label]);
  useEffect(() => {
    const media = window.matchMedia("(max-width: 900px)");
    const closeOnDesktop = () => { if (!media.matches) setMenuOpen(false); };
    media.addEventListener("change", closeOnDesktop);
    return () => media.removeEventListener("change", closeOnDesktop);
  }, []);
  useEffect(() => {
    if (!menuOpen) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    railRef.current?.querySelector("button")?.focus();
    function keydown(event) {
      if (event.key === "Escape") setMenuOpen(false);
      if (event.key !== "Tab") return;
      const buttons = [...railRef.current.querySelectorAll("button")].filter((button) => button.getClientRects().length);
      const first = buttons[0];
      const last = buttons.at(-1);
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    }
    document.addEventListener("keydown", keydown);
    return () => { document.body.style.overflow = previousOverflow; document.removeEventListener("keydown", keydown); menuRef.current?.focus(); };
  }, [menuOpen]);

  function navigate(next) { setPage(next); setMenuOpen(false); window.scrollTo({ top: 0, behavior: "instant" }); }

  return <div className="communityApp">
    <a className="skipLink" href="#main-content" onClick={(event) => { event.preventDefault(); document.getElementById("main-content")?.focus(); }}>Zum Inhalt springen</a>
    {menuOpen && <div className="menuBackdrop" aria-hidden="true" onClick={() => setMenuOpen(false)} />}
    <aside className={`communityRail ${menuOpen ? "isOpen" : ""}`} ref={railRef} aria-label="Hauptmenü" role={menuOpen ? "dialog" : undefined} aria-modal={menuOpen || undefined} id="main-navigation">
      <div className="railBrand"><button className="communityBrand" type="button" onClick={() => navigate("home")} aria-label="Aviary Home"><Crown size={29} strokeWidth={1.7} /><span>Aviary<span className="brandDot">.</span></span></button><button className="railClose quietIcon" aria-label="Menü schließen" onClick={() => setMenuOpen(false)} type="button"><X size={21} /></button></div>
      <nav>{groups.map((group) => <div className="railGroup" key={group.label}><p>{group.label}</p>{group.ids.map((id) => {
        const item = nav.find((entry) => entry.id === id);
        const Icon = item.icon;
        return <button key={id} type="button" className={`railLink ${page === id ? "isActive" : ""}`} aria-current={page === id ? "page" : undefined} onClick={() => navigate(id)}><Icon size={18} strokeWidth={1.7} /><span>{item.label}</span>{page === id && <span className="activeDot" />}</button>;
      })}</div>)}</nav>
      <button className="dailyRewardLink" type="button" onClick={() => navigate("games")}><Gamepad2 size={25} strokeWidth={1.6} /><span><strong>Chickens verdienen</strong><small>Spielen, sammeln, Rewards holen.</small></span><ChevronRight size={16} /></button>
      <div className="railFooter">Ein Platz für unseren Schwarm.</div>
    </aside>
    <div className="communityWorkspace" inert={menuOpen ? true : undefined}>
      <header className="communityTopbar">
        <div className="pageBreadcrumb"><button ref={menuRef} className="mobileMenu quietIcon" type="button" onClick={() => setMenuOpen(true)} aria-label="Menü öffnen" aria-expanded={menuOpen} aria-controls="main-navigation"><Menu size={22} /></button><Home size={17} strokeWidth={1.7} /><ChevronRight size={14} /><span>{label}</span></div>
        <div className="headerUtilities">
          {user && <div className="communityBalances"><span><ShoppingBasket size={16} /><strong>{number(user.chickens)}</strong><span>Chickens</span></span></div>}
          {user ? <><button className="accountLink" type="button" onClick={() => navigate("profile")} aria-label={`Profil von ${user.username} öffnen`}><MemberAvatar user={user} /><span>{user.username}</span></button><button className="quietIcon logoutButton" onClick={onLogout} title="Abmelden" aria-label="Abmelden" type="button"><LogOut size={17} /></button></> : <button className="signInButton" onClick={() => navigate("login")} type="button"><LogIn size={16} /> Anmelden</button>}
        </div>
      </header>
      <main id="main-content" className="communityContent" tabIndex={-1}>{children}</main>
      <footer className="communityFooter"><span>Aviary <span>·</span> Gemeinsam mehr erleben.</span><button type="button" onClick={() => navigate("support")}><MessageCircle size={15} /> Support</button></footer>
    </div>
  </div>;
}

function SectionHeading({ title, action, onClick }) {
  return <div className="communitySectionHeading"><h2>{title}</h2>{action && <button type="button" className="inlineLink" onClick={onClick}>{action}<ChevronRight size={15} /></button>}</div>;
}

function EmptyState({ children, icon: Icon }) {
  return <div className="communityEmpty">{Icon && <Icon size={22} strokeWidth={1.5} />}<span>{children}</span></div>;
}

export function Dashboard({ user, data, loading, error, setPage, games, roleBadge }) {
  const leaderboard = data.leaderboard || [];
  const online = data.active_members || [];
  const news = data.news || [];
  const events = data.events || [];
  const level = user?.level || 1;
  const earned = user?.level_progress || 0;
  const target = user?.level_target || 250;
  return <section className="communityDashboard">
    <div className="dashboardIntro"><div><h1>{user ? "Schön, dass du da bist." : "Willkommen im Aviary."}</h1><p>Dein Platz für Games, Rewards und Community.</p></div><button className="outlineButton" type="button" onClick={() => setPage(user ? "profile" : "login")}><User size={16} />{user ? "Profil anzeigen" : "Jetzt anmelden"}</button></div>
    <section className={`welcomeStrip ${!user ? "welcomeGuest" : ""}`} aria-label="Dein Fortschritt">
      <MemberAvatar user={user} className="communityAvatar welcomeAvatar" />
      <div className="welcomeProgress"><div className="welcomeName"><h2>{user?.username || "Dein nächstes Abenteuer wartet."}</h2>{user && roleBadge}</div>{user ? <><div className="progressCaption"><span>Level {level}</span><small>{earned} / {target} Chickens zum nächsten Level</small></div><div className="communityProgress" role="progressbar" aria-label="Fortschritt zum nächsten Level" aria-valuenow={earned} aria-valuemin={0} aria-valuemax={target}><span style={{ width: `${earned / target * 100}%` }} /></div></> : <p>Spiel mit, sammle Chickens und werde Teil unseres Schwarms.</p>}</div>
      <img className="welcomeMascot" src="/assets/aviary-mascot.png" alt="" />
    </section>
    {error && <div className="notice error" role="alert">Die Community-Daten konnten nicht geladen werden. Bitte versuche es später erneut.</div>}
    {loading && <div className="notice" role="status">Deine Community wird geladen …</div>}
    <div className="dashboardColumns">
      <div className="dashboardPrimary">
        <section className="dashboardPanel gameLaunchPanel"><SectionHeading title="Zeit für eine neue Bestleistung" action="Alle Minispiele" onClick={() => setPage("games")} /><div className="gameLaunchList">{Object.entries(games).filter(([id]) => id !== "dnd").map(([id, meta], index) => <button className={`gameLaunch gameLaunch${index}`} key={id} type="button" onClick={() => setPage(`games/${id}`)} aria-label={`${meta.title} spielen`}><span className="gameLaunchArtwork" /><strong>{meta.title}</strong><span className="gamePlayIcon"><Play size={16} fill="currentColor" strokeWidth={0} /></span></button>)}</div></section>
        <section className="dashboardPanel communityNews"><SectionHeading title="Neues aus dem Aviary" action="Alle News" onClick={() => setPage("news")} />{news.length ? news.slice(0, 2).map((item) => <button className="communityNewsRow" key={item.id || item.title} type="button" onClick={() => setPage("news")}><span className="newsArtwork"><Newspaper size={27} strokeWidth={1.4} /></span><span className="newsCopy"><strong>{item.title}</strong><span>{item.body}</span></span><ChevronRight size={17} /></button>) : <EmptyState icon={Newspaper}>Hier findest du bald Neuigkeiten aus der Community.</EmptyState>}</section>
      </div>
      <div className="dashboardSecondary">
        <section className="dashboardPanel communityRanking"><SectionHeading title="Chickens erspielt" action="Rangliste ansehen" onClick={() => setPage("leaderboard")} /><ol className="rankingList">{leaderboard.slice(0, 5).map((member, index) => <li key={member.username} className={user?.username === member.username ? "isYou" : ""}><span className={`rankingPosition position${index + 1}`}>{index + 1}</span><MemberAvatar user={member} /><span className="rankingName" title={member.username}>{member.username}</span><strong>{number(member.chickens_earned)}</strong><ShoppingBasket size={14} /></li>)}</ol>{!loading && !leaderboard.length && <EmptyState icon={Trophy}>Die ersten Plätze warten auf euch.</EmptyState>}</section>
        <section className="dashboardPanel communityOnline"><SectionHeading title="Gerade online" action="Mitglieder" onClick={() => setPage("members")} /><div className="onlineList">{online.slice(0, 3).map((member) => <button type="button" key={member.username} onClick={() => setPage("members")}><MemberAvatar user={member} /><span><strong>{member.username}</strong><small><span className="onlineDot" />Online</small></span></button>)}</div>{!loading && !online.length && <EmptyState icon={Users}>Gerade ist es ruhig im Schwarm.</EmptyState>}</section>
      </div>
    </div>
    <section className="dashboardPanel communityEvents"><SectionHeading title="Anstehende Events" action="Alle Events" onClick={() => setPage("events")} />{events.length ? <div className="dashboardEventList">{events.slice(0, 2).map((event) => <button type="button" key={event.id} onClick={() => setPage("events")}><CalendarDays size={22} /><span><strong>{event.title}</strong><small>{event.event_date}</small></span><ArrowRight size={16} /></button>)}</div> : <EmptyState icon={CalendarDays}>Aktuell stehen keine Events an.</EmptyState>}</section>
    <button className="galleryShortcut" type="button" onClick={() => setPage("gallery")}><Sparkles size={16} /><span>Entdecke die kreativen Köpfe unserer Community.</span><strong>Zur Hall of Fame</strong><ArrowRight size={16} /></button>
  </section>;
}
