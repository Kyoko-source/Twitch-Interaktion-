import React, { useEffect, useMemo, useRef, useState } from "react";
import {
  Activity, ArrowLeft, Award, CalendarCheck, Check, Coins, Cookie, Copy, Crown, Dices, Egg, Feather, Flag, Flame, Gamepad2, Gem,
  Home, Lock, Mail, Medal, Palette, Pencil, ShoppingBag, Sparkles, Star, Trophy, X, Zap,
} from "lucide-react";
import { api } from "../api";
import { LOOKS, drawHorse } from "../horses/horse.js";
import { PhoenixPreview } from "../economy/LevelTree";
import { RoleBadge, gameMeta, profileHref } from "../pages/shared";
import "./profile.css";

const fmt = (n) => Math.round(Number(n) || 0).toLocaleString("de-DE");
const BADGE_ICONS = { horse: Award, flag: Flag, flame: Flame, egg: Egg, gem: Gem, sparkles: Sparkles, gamepad: Gamepad2, trophy: Crown, medal: Medal, bag: ShoppingBag, calendar: CalendarCheck, home: Home, coins: Coins, star: Star, phoenix: Feather, cookie: Cookie };
const TIER_NAMES = { bronze: "Bronze", silver: "Silber", gold: "Gold", legend: "Legendär" };
const SOURCE_NAMES = { game: "Minispiel gespielt", casino: "Im Casino gespielt", shop: "Im Shop gekauft", chat: "Im Chat geschrieben", daily: "Täglicher Besuch", start: "Willkommensbonus", bonus: "Bonus" };
const HORSE_NAMES = ["Donnerhuf", "Goldmähne", "Sturmwind", "Mitternacht", "Feuerfunke", "Silberpfeil", "Kleiner Keks", "Royal Gacker", "Nebelläufer"];
const reducedMotion = () => typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;

function relDate(ts) {
  if (!ts) return "";
  const d = new Date(ts * 1000);
  const diff = (Date.now() - d.getTime()) / 1000;
  if (diff < 60) return "gerade eben";
  if (diff < 3600) return `vor ${Math.floor(diff / 60)} Min.`;
  if (diff < 86400) return `vor ${Math.floor(diff / 3600)} Std.`;
  if (diff < 86400 * 7) return `vor ${Math.floor(diff / 86400)} Tagen`;
  return d.toLocaleDateString("de-DE", { day: "numeric", month: "short" });
}

// Numbers count up once when the profile appears.
function CountUp({ value, decimals = 0, suffix = "" }) {
  const [shown, setShown] = useState(reducedMotion() ? value : 0);
  useEffect(() => {
    if (reducedMotion()) { setShown(value); return undefined; }
    let raf = 0;
    const start = performance.now(), from = 0, to = Number(value) || 0;
    const step = (now) => {
      const t = Math.min(1, (now - start) / 1100);
      setShown(from + (to - from) * (1 - Math.pow(1 - t, 3)));
      if (t < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [value]);
  const text = decimals ? Number(shown).toLocaleString("de-DE", { minimumFractionDigits: decimals, maximumFractionDigits: decimals }) : fmt(shown);
  return <>{text}{suffix}</>;
}

// Avatar inside a ring that fills with the level progress.
function LevelRing({ user, level, online }) {
  const pct = level.level_target ? Math.min(1, level.level_progress / level.level_target) : 1;
  const r = 70, c = 2 * Math.PI * r;
  return (
    <div className="pfRing">
      <svg viewBox="0 0 160 160" aria-hidden="true">
        <defs>
          <linearGradient id="pfRingGrad" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="var(--pf-a)" /><stop offset="1" stopColor="var(--pf-b)" /></linearGradient>
        </defs>
        <circle cx="80" cy="80" r={r} className="pfRingTrack" />
        <circle cx="80" cy="80" r={r} className="pfRingFill" stroke="url(#pfRingGrad)" strokeDasharray={c} strokeDashoffset={c * (1 - pct)} />
      </svg>
      <div className="pfAvatar">{user.avatar_url ? <img src={user.avatar_url} alt="" /> : String(user.username || "?").slice(0, 2)}</div>
      <span className="pfRingLevel" title={`${fmt(level.level_progress)} / ${fmt(level.level_target)} XP zum nächsten Level`}><small>LV</small>{level.level}</span>
      {online && <span className="pfOnline" title="Gerade online" />}
    </div>
  );
}

function HorseCanvas({ index, crown, phoenix, size = 220 }) {
  const ref = useRef(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return undefined;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = size, h = Math.round(size * 0.72);
    canvas.width = w * dpr; canvas.height = h * dpr;
    const c = canvas.getContext("2d");
    const calm = reducedMotion();
    let raf = 0, phase = 0, last = performance.now();
    const draw = (now) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      phase = (phase + dt * 2.3) % 1;
      c.setTransform(dpr, 0, 0, dpr, 0, 0);
      c.clearRect(0, 0, w, h);
      const k = size / 165;
      c.translate(w * 0.5, h * 0.92); c.scale(k, k);
      drawHorse(c, { look: LOOKS[index], number: index + 1, phase, gait: calm ? 0.3 : 1, time: now / 1000, crown, skin: phoenix ? "phoenix" : null });
      if (!calm) raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [index, crown, phoenix, size]);
  return <canvas ref={ref} className="pfHorse" style={{ width: size, height: Math.round(size * 0.72) }} role="img" aria-label={`${HORSE_NAMES[index]} im Galopp`} />;
}

function BadgeIcon({ badge, size = 22 }) {
  const Icon = BADGE_ICONS[badge.icon] || Award;
  return <Icon size={size} />;
}

function Showcase({ ids, badges }) {
  const picked = ids.map((id) => badges.find((b) => b.id === id && b.earned)).filter(Boolean);
  if (!picked.length) return null;
  return (
    <div className="pfShowcase" aria-label="Ausgestellte Erfolge">
      {picked.map((b) => (
        <span key={b.id} className={`pfMedal tier-${b.tier}`} title={`${b.name}: ${b.text}`}><BadgeIcon badge={b} size={20} /></span>
      ))}
    </div>
  );
}

// Half a year of activity (XP per day), one column per week, Monday on top.
function Heatmap({ activity }) {
  const [tip, setTip] = useState(null);
  const cells = useMemo(() => {
    const start = new Date(`${activity.start}T00:00:00Z`);
    const offset = (start.getUTCDay() + 6) % 7;
    const list = Array.from({ length: offset }, () => null);
    const today = new Date().toISOString().slice(0, 10);
    for (let i = 0; i < 26 * 7; i++) {
      const d = new Date(start.getTime() + i * 86400000);
      const key = d.toISOString().slice(0, 10);
      if (key > today) break;
      list.push({ key, xp: activity.days[key] || 0, date: d });
    }
    return list;
  }, [activity]);
  const max = Math.max(1, ...Object.values(activity.days));
  const lvl = (xp) => (xp <= 0 ? 0 : xp < max * 0.25 ? 1 : xp < max * 0.5 ? 2 : xp < max * 0.8 ? 3 : 4);
  const total = Object.values(activity.days).reduce((a, b) => a + b, 0);
  return (
    <div className="pfHeat">
      <div className="pfHeatGrid" role="img" aria-label={`Aktivität der letzten 26 Wochen: ${fmt(total)} XP an ${Object.keys(activity.days).length} Tagen`}>
        {cells.map((cell, i) => cell ? (
          <i key={cell.key} className={`l${lvl(cell.xp)}`} onMouseEnter={() => setTip(cell)} onMouseLeave={() => setTip(null)} />
        ) : <i key={`pad${i}`} className="pad" />)}
      </div>
      <div className="pfHeatFoot">
        <span>{tip ? <><b>{tip.xp ? `${fmt(tip.xp)} XP` : "Keine Aktivität"}</b> am {tip.date.toLocaleDateString("de-DE", { weekday: "short", day: "numeric", month: "long" })}</> : <>{fmt(total)} XP im letzten halben Jahr</>}</span>
        <span className="pfHeatLegend">weniger <i className="l0" /><i className="l1" /><i className="l2" /><i className="l3" /><i className="l4" /> mehr</span>
      </div>
    </div>
  );
}

function StatTile({ icon: Icon, label, value, sub, decimals, suffix, accent }) {
  return (
    <div className={`pfTile${accent ? " accent" : ""}`}>
      <span className="pfTileIcon"><Icon size={18} /></span>
      <strong><CountUp value={value} decimals={decimals} suffix={suffix} /></strong>
      <small>{label}</small>
      {sub && <em>{sub}</em>}
    </div>
  );
}

function Editor({ data, me, setUser, onClose, onSaved }) {
  const [form, setForm] = useState({ bio: me.bio || "", favorite_game: me.favorite_game || "", avatar_url: me.avatar_url || "" });
  const [theme, setTheme] = useState(data.prefs.theme);
  const [showcase, setShowcase] = useState(data.prefs.showcase);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const earned = data.badges.filter((b) => b.earned);

  function toggleBadge(id) {
    setShowcase((list) => (list.includes(id) ? list.filter((x) => x !== id) : list.length >= 3 ? list : [...list, id]));
  }

  async function save(event) {
    event.preventDefault();
    setBusy(true); setMessage("");
    try {
      const [profile] = await Promise.all([
        api("/api/profile", { method: "PATCH", body: JSON.stringify(form) }),
        api("/api/profile/look", { method: "PATCH", body: JSON.stringify({ theme, showcase }) }),
      ]);
      setUser?.(profile.user);
      onSaved();
      onClose();
    } catch (err) {
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="pfEditor" onSubmit={save} aria-label="Profil bearbeiten">
      <div className="pfEditorHead">
        <h2><Pencil size={18} /> Profil bearbeiten</h2>
        <button type="button" className="pfIconBtn" onClick={onClose} aria-label="Schließen"><X size={18} /></button>
      </div>
      <div className="pfEditorGrid">
        <div className="pfEditorCol">
          <label>Über mich<textarea maxLength={280} rows={4} value={form.bio} placeholder="Erzähl dem Schwarm, wer du bist …" onChange={(e) => setForm({ ...form, bio: e.target.value })} /><small>{form.bio.length} / 280</small></label>
          <label>Lieblingsspiel
            <select value={form.favorite_game} onChange={(e) => setForm({ ...form, favorite_game: e.target.value })}>
              <option value="">– keins –</option>
              {Object.values(gameMeta).map((g) => <option key={g.title} value={g.title}>{g.title}</option>)}
              {form.favorite_game && !Object.values(gameMeta).some((g) => g.title === form.favorite_game) && <option value={form.favorite_game}>{form.favorite_game}</option>}
            </select>
          </label>
          <label>Profilbild-URL<input value={form.avatar_url} placeholder="https://…" onChange={(e) => setForm({ ...form, avatar_url: e.target.value })} /></label>
        </div>
        <div className="pfEditorCol">
          <span className="pfLabel"><Palette size={15} /> Profil-Look</span>
          <div className="pfThemes">
            {data.themes.map((t) => (
              <button key={t.id} type="button" className={`pfSwatch pfTheme-${t.id}${theme === t.id ? " on" : ""}`} disabled={!t.unlocked} onClick={() => setTheme(t.id)} aria-pressed={theme === t.id} title={t.unlocked ? t.name : `Ab Level ${t.level}`}>
                <i />
                <span>{t.name}</span>
                {!t.unlocked && <small><Lock size={11} /> Lv {t.level}</small>}
              </button>
            ))}
          </div>
          <span className="pfLabel"><Trophy size={15} /> Vitrine – bis zu 3 Erfolge neben deinem Namen</span>
          {earned.length ? (
            <div className="pfPick">
              {earned.map((b) => (
                <button key={b.id} type="button" className={`pfMedal tier-${b.tier}${showcase.includes(b.id) ? " on" : ""}`} onClick={() => toggleBadge(b.id)} aria-pressed={showcase.includes(b.id)} title={b.name}>
                  <BadgeIcon badge={b} size={18} />
                  {showcase.includes(b.id) && <Check size={12} className="pfPickCheck" />}
                </button>
              ))}
            </div>
          ) : <p className="pfMuted">Noch keine Erfolge – spiel Derby, Slots oder Minispiele, dann füllt sich deine Vitrine.</p>}
        </div>
      </div>
      <div className="pfEditorFoot">
        {message && <span className="pfError" role="alert">{message}</span>}
        <button type="button" className="ghost" onClick={onClose}>Abbrechen</button>
        <button type="submit" disabled={busy}>{busy ? "Speichert …" : "Speichern"}</button>
      </div>
    </form>
  );
}

export function ProfileView({ username, me, setUser, setPage }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [reload, setReload] = useState(0);
  const [editing, setEditing] = useState(false);
  const [copied, setCopied] = useState(false);
  const own = me && username && me.username === username;

  useEffect(() => {
    if (!username) return undefined;
    let alive = true;
    setError("");
    api(`/api/profile/${encodeURIComponent(username)}/card`).then((d) => { if (!alive) return; if (d?.user?.username) setData(d); else setError("Profil konnte nicht geladen werden."); }).catch((err) => alive && setError(err.message));
    return () => { alive = false; };
  }, [username, reload, me?.level]);

  useEffect(() => { setEditing(false); window.scrollTo?.({ top: 0 }); }, [username]);

  if (error && own) return <div className="notice">Deine Profilkarte lädt gerade nicht – versuch es gleich nochmal.</div>;
  if (error) return <section className="narrow"><div className="panel"><h1>Profil nicht gefunden</h1><p>{error}</p><button type="button" onClick={() => setPage("members")}>Zu den Mitgliedern</button></div></section>;
  if (!data || data.user.username !== username) return <div className="pfSkeleton" aria-busy="true"><div /><div /><div /></div>;

  const { user, level, derby, slots, games, badges, activity, unlocks, shop } = data;
  const theme = data.prefs.theme || "neon";
  const earnedCount = badges.filter((b) => b.earned).length;
  const hasCrown = unlocks.some((u) => u.id === "derby-crown");
  const hasPhoenix = unlocks.some((u) => u.id === "derby-phoenix");
  const fav = derby.favorite;
  const link = `${window.location.origin}/${profileHref(user.username)}`;
  const hitRate = derby.races ? (derby.won / derby.races) * 100 : 0;
  const maxPick = Math.max(1, ...derby.horses);

  async function copyLink() {
    try { await navigator.clipboard.writeText(link); } catch { /* the link stays visible in the title */ }
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1800);
  }

  function openChat() {
    try { localStorage.setItem("aviary_chat_target", user.username); } catch { /* optional */ }
    setPage("chat");
  }

  return (
    <section className={`pf pfTheme-${theme}`} data-testid="profile-view">
      <header className="pfHero">
        <div className="pfHeroBg" aria-hidden="true"><i /><i /><i /></div>
        <LevelRing user={user} level={level} online={data.online} />
        <div className="pfIdentity">
          <div className="pfNameRow">
            <h1>{user.username}</h1>
            <Showcase ids={data.prefs.showcase} badges={badges} />
          </div>
          <p className="pfTitle">{level.level_title}</p>
          <div className="pfChips">
            <RoleBadge user={user} />
            <span className="pfChip"><Trophy size={13} /> #{data.rank} von {data.members}</span>
            <span className="pfChip"><Zap size={13} /> {fmt(level.xp)} XP · #{level.xp_rank} nach XP</span>
            {user.favorite_game && <span className="pfChip"><Gamepad2 size={13} /> {user.favorite_game}</span>}
            {activity.first_seen && <span className="pfChip"><CalendarCheck size={13} /> dabei seit {new Date(activity.first_seen * 1000).toLocaleDateString("de-DE", { month: "long", year: "numeric" })}</span>}
          </div>
          <p className={`pfBio${user.bio ? "" : " empty"}`}>{user.bio || (own ? "Noch keine Bio – erzähl dem Schwarm etwas über dich." : "Noch keine Bio.")}</p>
          <div className="pfLevelBar" aria-label={`Level ${level.level}: ${fmt(level.level_progress)} von ${fmt(level.level_target)} XP`}>
            <span style={{ width: `${Math.min(100, (level.level_progress / Math.max(1, level.level_target)) * 100)}%` }} />
            <small>{fmt(level.level_progress)} / {fmt(level.level_target)} XP bis Level {level.level + 1}{data.next_unlock ? ` · nächste Belohnung: ${data.next_unlock.name} (Lv ${data.next_unlock.level})` : ""}</small>
          </div>
        </div>
        <div className="pfActions">
          {own ? (
            <button type="button" onClick={() => setEditing(!editing)} aria-expanded={editing}><Pencil size={16} /> Bearbeiten</button>
          ) : me ? (
            <button type="button" onClick={openChat}><Mail size={16} /> Nachricht</button>
          ) : null}
          <button type="button" className="ghost" onClick={copyLink} data-testid="profile-share">{copied ? <><Check size={16} /> Kopiert!</> : <><Copy size={16} /> Profil-Link</>}</button>
          {!own && me && <button type="button" className="ghost pfBack" onClick={() => window.history.length > 1 ? window.history.back() : setPage("members")}><ArrowLeft size={16} /> Zurück</button>}
        </div>
      </header>

      {editing && own && <Editor data={data} me={user} setUser={setUser} onClose={() => setEditing(false)} onSaved={() => setReload((n) => n + 1)} />}

      <div className="pfTiles">
        <StatTile icon={Coins} label="Chickens erspielt" value={user.chickens_earned} accent />
        <StatTile icon={Flag} label="Derby-Siege" value={derby.won} sub={derby.races ? `von ${fmt(derby.races)} Rennen` : "noch keine Rennen"} />
        <StatTile icon={Gem} label="Größter Slot-Gewinn" value={slots.best_win} sub={slots.best_mult ? `×${slots.best_mult.toLocaleString("de-DE")} Einsatz` : "noch nicht gedreht"} />
        <StatTile icon={Award} label="Erfolge" value={earnedCount} sub={`von ${badges.length}`} />
        <StatTile icon={Activity} label="Aktive Tage" value={activity.active_days} sub={level.streak ? `${level.streak} Tage Serie` : ""} />
      </div>

      <div className="pfGrid">
        <article className="pfCard pfDerby">
          <h2><Flag size={18} /> Chicken Derby</h2>
          {fav ? (
            <>
              <div className="pfDerbyStage">
                <HorseCanvas index={fav.id} crown={hasCrown} phoenix={hasPhoenix} />
                <div>
                  <small>Lieblingspferd</small>
                  <b>#{fav.id + 1} {hasPhoenix ? `${fav.name} · Phönix` : fav.name}</b>
                  <span>{fmt(fav.bets)}× gesetzt · {fmt(fav.wins)} Siege</span>
                </div>
              </div>
              <div className="pfPicks" aria-label="Wetten pro Pferd">
                {derby.horses.map((n, i) => (
                  <span key={i} title={`#${i + 1} ${HORSE_NAMES[i]}: ${n}× gesetzt`} className={fav.id === i ? "fav" : ""}>
                    <i style={{ height: `${Math.max(4, (n / maxPick) * 100)}%`, "--silk": LOOKS[i].silk, "--silk2": LOOKS[i].silk2 }} />
                    <small>{i + 1}</small>
                  </span>
                ))}
              </div>
              <dl className="pfFacts">
                <div><dt>Trefferquote</dt><dd>{hitRate.toLocaleString("de-DE", { maximumFractionDigits: 1 })} %</dd></div>
                <div><dt>Längste Siegesserie</dt><dd>{derby.streak}</dd></div>
                <div><dt>Bilanz</dt><dd className={derby.net >= 0 ? "up" : "down"}>{derby.net >= 0 ? "+" : ""}{fmt(derby.net)} Credits</dd></div>
              </dl>
            </>
          ) : <div className="pfEmpty"><HorseCanvas index={4} crown={false} phoenix={false} size={180} /><p>Noch kein Rennen gewettet.</p></div>}
        </article>

        <article className="pfCard pfCasino">
          <h2><Dices size={18} /> Chicken Jackpot</h2>
          {slots.spins ? (
            <>
              <div className="pfJackpot">
                <small>Größter Gewinn</small>
                <strong><CountUp value={slots.best_win} /></strong>
                <span>GSC · ×{slots.best_mult.toLocaleString("de-DE")} des Einsatzes</span>
              </div>
              <dl className="pfFacts">
                <div><dt>Spins</dt><dd>{fmt(slots.spins)}</dd></div>
                <div><dt>Eier-Boni</dt><dd>{fmt(slots.bonuses)}</dd></div>
                <div><dt>Bestes Freispiel-Rad</dt><dd>{slots.best_wheel ? `${slots.best_wheel} Freispiele` : "–"}</dd></div>
                <div><dt>Gesamt gewonnen</dt><dd>{fmt(slots.won)} GSC</dd></div>
              </dl>
            </>
          ) : <div className="pfEmpty"><Dices size={40} /><p>Noch keinen Spin gedreht.</p></div>}
        </article>

        <article className="pfCard pfRecords">
          <h2><Trophy size={18} /> Rekorde</h2>
          {games.length ? (
            <ol>
              {games.map((g) => (
                <li key={g.game} style={{ "--game": gameMeta[g.game]?.accent || "var(--pf-a)" }}>
                  <span className={`pfPlace p${Math.min(g.place, 4)}`}>{g.place <= 3 ? <Medal size={16} /> : null}#{g.place}</span>
                  <span><b>{g.name}</b><small>{fmt(g.plays)} Runden</small></span>
                  <strong>{fmt(g.best)}</strong>
                </li>
              ))}
            </ol>
          ) : <div className="pfEmpty"><Gamepad2 size={40} /><p>Noch keine Minispiel-Rekorde.</p></div>}
        </article>

        <article className="pfCard pfActivity">
          <h2><Activity size={18} /> Aktivität</h2>
          <Heatmap activity={activity} />
          {activity.recent.length > 0 && (
            <ul className="pfFeed">
              {activity.recent.slice(0, 6).map((r, i) => (
                <li key={i}><span>{SOURCE_NAMES[r.source] || r.source}</span><b>+{fmt(r.amount)} XP</b><time>{relDate(r.created)}</time></li>
              ))}
            </ul>
          )}
        </article>

        <article className="pfCard pfBadges">
          <h2><Award size={18} /> Erfolge <small>{earnedCount} / {badges.length}</small></h2>
          <div className="pfBadgeGrid">
            {badges.map((b) => (
              <div key={b.id} className={`pfBadge tier-${b.tier}${b.earned ? " earned" : ""}`} tabIndex={0} aria-label={`${b.name} (${TIER_NAMES[b.tier]}): ${b.text}${b.earned ? " – erreicht" : ` – ${fmt(b.value)} von ${fmt(b.goal)}`}`}>
                <span className="pfMedal"><BadgeIcon badge={b} />{!b.earned && <Lock size={11} className="pfLock" />}</span>
                <b>{b.name}</b>
                <small>{b.text}</small>
                {!b.earned && b.goal > 1 && <><span className="pfProg"><i style={{ width: `${b.progress * 100}%` }} /></span><em className="pfProgText">{fmt(b.value)} / {fmt(b.goal)}</em></>}
                {b.earned && <em className="pfTier">{TIER_NAMES[b.tier]}</em>}
              </div>
            ))}
          </div>
        </article>

        <article className="pfCard pfCollection">
          <h2><Sparkles size={18} /> Sammlung</h2>
          {hasPhoenix && (
            <div className="pfPhoenix">
              <PhoenixPreview size={190} />
              <span><small>DERBY-SKIN · LEVEL 25</small><b>Phönix-Hengst</b></span>
            </div>
          )}
          <ul className="pfItems">
            {unlocks.filter((u) => !u.skin).map((u) => <li key={u.id}><Star size={14} /><span><b>{u.name}</b><small>Level {u.level} · {u.text}</small></span></li>)}
            {shop.map((s) => <li key={s.name} className="shop"><ShoppingBag size={14} /><span><b>{s.name}</b><small>Shop</small></span></li>)}
          </ul>
          {!unlocks.length && !shop.length && <p className="pfMuted">Noch leer. Level-Belohnungen und Shop-Käufe landen hier.</p>}
          {data.chat_style && data.chat_style !== "default" && (
            <div className="pfChatPreview">
              <small>Chat-Stil</small>
              <div className={`chatBubble chatStyle-${data.chat_style}`}><div>Hallo Schwarm! 👋</div></div>
            </div>
          )}
        </article>
      </div>

    </section>
  );
}
