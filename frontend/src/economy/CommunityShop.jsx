import React, { useEffect, useMemo, useRef, useState } from "react";
import { ArrowRight, CalendarClock, Check, Crown, FerrisWheel, Flame, Gamepad2, Gift, LayoutGrid, MessageCircle, Radio, Star, Target, Timer } from "lucide-react";
import { api } from "../api";
import { publishWallet, requestId } from "./useGameRewards";
import { CasinoCashier, gscShort } from "./CasinoCashier";
import { celebratePurchase, preloadPurchaseSounds } from "./PurchaseCelebration";
import { colorFor } from "../wheel/engine.js";
import { LOOKS, drawHorse } from "../horses/horse.js";
import "../ui/chatStyles.js";
import "./economy.css";
import "./shop.css";

const PUNISHMENT = ["Bestrafungs Ideen", "Idee Bestrafungsrad"];
const nf = (n) => Number(n || 0).toLocaleString("de-DE");
const pct = (x) => `${x >= 0.1 ? Math.round(x * 100) : (x * 100).toFixed(1).replace(".", ",")} %`;
// Same key as the server (Python casefold): collapse spaces, lower case, ß -> ss.
const wheelKey = (name) => String(name || "").split(/\s+/).filter(Boolean).join(" ").toLowerCase().replace(/ß/g, "ss");

export function shopTheme(category = "") {
  if (/bestraf/i.test(category)) return { key: "punish", icon: Flame, emoji: "😈", text: "Landet auf dem Glücksrad – und dein Name erscheint live im Stream." };
  if (/aufgab/i.test(category)) return { key: "task", icon: Target, emoji: "🎯", text: "Eine Aufgabe für den Streamer – live im nächsten Stream erledigt." };
  if (/skin/i.test(category)) return { key: "skin", icon: Crown, emoji: "🐎", text: "Ein Skin für dein Pferd im Chicken Derby – auch live im Stream zu sehen." };
  if (/chat/i.test(category)) return { key: "chat", icon: MessageCircle, emoji: "💬", text: "Dauerhaft freigeschaltet für deine Chat-Nachrichten." };
  if (/out of stream/i.test(category)) return { key: "outside", icon: Star, emoji: "🌟", text: "Ein Reward außerhalb des Streams – ganz persönlich." };
  return { key: "reward", icon: Gift, emoji: "🎁", text: "Ein Reward für deinen nächsten Community-Moment." };
}

// A fitting illustration from the item name; the category emoji is the fallback.
const EMOJI = [
  [/squat|kniebeuge/, "🏋️"], [/liegest|push.?up|sit.?up|plank/, "💪"], [/wasser|trink/, "💧"], [/englisch|deutsch|sprache|akzent|reden|sprechen/, "🗣️"],
  [/dpi|maus|sensi/, "🖱️"], [/sprint|renn|lauf/, "🏃"], [/hand/, "✋"], [/chat/, "💬"], [/sing|lied|song/, "🎤"], [/tanz|dance/, "💃"],
  [/eis|kalt/, "🧊"], [/scharf|chili/, "🌶️"], [/ess|food|snack/, "🍽️"], [/musik|music/, "🎵"], [/horror|angst|grusel/, "👻"],
  [/blind|augen|sehen/, "🙈"], [/stumm|mute|leise|ohne ton/, "🔇"], [/laut|schrei/, "📢"], [/kamera|cam\b|webcam/, "📷"],
  [/hut|outfit|kostüm|perücke/, "🎩"], [/controller|gamepad/, "🎮"], [/spiel|game|zocken/, "🎮"], [/emote|lach/, "😂"],
  [/ziel|aufgabe/, "🎯"], [/timeout|bann/, "⛔"], [/licht|lampe/, "💡"], [/credit/, "🎟️"], [/zeit|min|stunde/, "⏱️"],
];
export function itemEmoji(name, theme) {
  const n = String(name || "").toLowerCase();
  return (EMOJI.find(([re]) => re.test(n)) || [null, theme.emoji])[1];
}

function useTilt() {
  const ref = useRef(null);
  const calm = useMemo(() => typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches, []);
  function move(event) {
    const el = ref.current;
    if (!el || calm || event.pointerType === "touch") return;
    const r = el.getBoundingClientRect();
    const x = (event.clientX - r.left) / r.width, y = (event.clientY - r.top) / r.height;
    el.style.setProperty("--mx", `${(x * 100).toFixed(1)}%`);
    el.style.setProperty("--my", `${(y * 100).toFixed(1)}%`);
    el.style.setProperty("--ry", `${((x - 0.5) * 9).toFixed(2)}deg`);
    el.style.setProperty("--rx", `${((0.5 - y) * 7).toFixed(2)}deg`);
  }
  function leave() { const el = ref.current; if (el) { el.style.setProperty("--rx", "0deg"); el.style.setProperty("--ry", "0deg"); } }
  return { ref, onPointerMove: move, onPointerLeave: leave };
}

// Galloping preview of a Derby skin, drawn with the same code as the race itself.
function HorsePreview({ skin }) {
  const ref = useRef(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return undefined;
    const dpr = Math.min(2, window.devicePixelRatio || 1), w = 240, h = 150;
    canvas.width = w * dpr; canvas.height = h * dpr;
    const c = canvas.getContext("2d");
    const calm = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
    let raf = 0, phase = 0, last = performance.now(), visible = true;
    const io = typeof IntersectionObserver === "function" ? new IntersectionObserver(([e]) => { visible = e.isIntersecting; }) : null;
    io?.observe(canvas);
    const frame = (now) => {
      raf = requestAnimationFrame(frame);
      if (!visible) return;
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      phase = (phase + dt * (calm ? 0 : 1.9)) % 1;
      c.setTransform(dpr, 0, 0, dpr, 0, 0); c.clearRect(0, 0, w, h);
      c.translate(w / 2 - 6, h - 16); c.scale(1.05, 1.05);
      drawHorse(c, { look: LOOKS[0], number: 1, phase, gait: calm ? 0 : 1, time: now / 1000, skin });
    };
    raf = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(raf); io?.disconnect(); };
  }, [skin]);
  return <canvas ref={ref} className="shHorse" aria-label="Vorschau des Derby-Skins" role="img" />;
}

function MemberCard({ user, setPage }) {
  const tilt = useTilt();
  return (
    <div className="shMember" {...tilt}>
      <span className="shMemberSheen" aria-hidden="true" />
      <div className="shMemberTop"><span>AVIARY · MEMBER</span><span className="shChip" aria-hidden="true" /></div>
      {user ? (
        <>
          <div className="shMemberBalance"><span className="shCoin big" aria-hidden="true">🐔</span><strong>{nf(user.chickens)}</strong><small>Chickens</small></div>
          <div className="shMemberRow"><span>🎟️ {nf(user.credits)} Credits</span><span>🪙 {gscShort(user.gsc)} GSC</span></div>
          <div className="shMemberName"><b>{user.username}</b>{user.level ? <em>Level {user.level}</em> : null}</div>
        </>
      ) : (
        <>
          <div className="shMemberBalance"><span className="shCoin big" aria-hidden="true">🐔</span><strong>Willkommen</strong></div>
          <button type="button" className="shMemberLogin" onClick={() => setPage("login")}>Anmelden & Chickens sammeln <ArrowRight size={16} /></button>
        </>
      )}
    </div>
  );
}

function WheelSpotlight({ wheel, onShow }) {
  const entries = wheel?.entries || [];
  if (!entries.length) return null;
  const total = entries.reduce((s, e) => s + e.weight, 0);
  let at = 0;
  const stops = entries.map((e, i) => { const from = at; at += (e.weight / total) * 360; return `${colorFor(i, entries.length).light} ${from}deg ${at}deg`; }).join(", ");
  const top = [...entries].sort((a, b) => b.weight - a.weight).slice(0, 3);
  return (
    <section className="shSpot" aria-label="Glücksrad">
      <div className="shSpotWheel" aria-hidden="true"><div className="shSpotDisc" style={{ background: `conic-gradient(${stops})` }} /><span className="shSpotHub">😈</span><span className="shSpotPin" /></div>
      <div className="shSpotText">
        <span className="shKicker"><FerrisWheel size={14} /> Das Bestrafungsrad</span>
        <h2>{entries.length} {entries.length === 1 ? "Bestrafung wartet" : "Bestrafungen warten"} auf den nächsten Dreh</h2>
        <p>Jeder Kauf ist ein Los. Kaufen mehrere dieselbe Bestrafung, wird sie wahrscheinlicher – und dein Name erscheint live im Stream.</p>
        <ol className="shSpotTop">
          {top.map((e) => (
            <li key={e.key}><span>{e.name}</span><b>{pct(e.weight / total)}</b><i style={{ width: `${(e.weight / top[0].weight) * 100}%` }} /></li>
          ))}
        </ol>
        <button type="button" className="shSpotBtn" onClick={onShow}>Bestrafungen ansehen <ArrowRight size={16} /></button>
      </div>
    </section>
  );
}

function ShopCard({ item, user, owned, ownedSkins, buying, wheelInfo, hot, onBuy }) {
  const tilt = useTilt();
  const theme = shopTheme(item.category);
  const punishment = PUNISHMENT.includes(item.category);
  const isOwned = Boolean((item.style && owned.has(item.style)) || (item.skin && ownedSkins.has(item.skin)));
  const balance = Number(user?.chickens || 0);
  const missing = Math.max(0, item.price - balance);
  const progress = item.price > 0 ? Math.min(100, (balance / item.price) * 100) : 100;
  const label = buying === String(item.id) ? "Wird gekauft …" : isOwned ? "Bereits freigeschaltet" : !user ? "Zum Kaufen anmelden" : missing ? `Noch ${nf(missing)} Chickens` : `Für ${nf(item.price)} Chickens kaufen`;
  const ThemeIcon = theme.icon;
  return (
    <article className={`shopRewardCard shCard theme-${theme.key}${item.skin ? ` skin-${item.skin}` : ""}${item.style ? ` look-${item.style}` : ""}${punishment ? " isPunishment" : ""}${isOwned ? " isOwned" : ""}`} {...tilt}>
      <div className="shArt">
        <span className="shArtPattern" aria-hidden="true" />
        <span className="shArtGlow" aria-hidden="true" />
        {item.skin ? (
          <HorsePreview skin={item.skin} />
        ) : item.style ? (
          <div className={`chatBubble chatStyle-${item.style} shChat`} aria-label="Vorschau der Chat-Animation"><div><b>{user?.username || "Du"}</b> Hallo Chat! 👋</div></div>
        ) : (
          <span className="shEmoji" aria-hidden="true">{itemEmoji(item.name, theme)}</span>
        )}
        <div className="shBadges">
          {punishment && <span className="shBadge live"><Radio size={12} /> Live</span>}
          {hot && <span className="shBadge hot"><Flame size={12} /> Beliebt</span>}
          {isOwned && <span className="shBadge owned"><Check size={12} /> Deins</span>}
        </div>
        {wheelInfo && <span className="shWheelChip"><FerrisWheel size={13} /> {pct(wheelInfo.chance)} auf dem Rad</span>}
      </div>
      <div className="shBody">
        <span className="shEyebrow"><ThemeIcon size={13} aria-hidden="true" />{item.category || "Reward"}</span>
        <h2>{item.name}</h2>
        <p>{item.description || item.desc || theme.text}</p>
        {(item.sold > 0 || wheelInfo) && (
          <div className="shMeta">
            {item.sold > 0 && <span>{nf(item.sold)}× gekauft</span>}
            {wheelInfo && <span>{wheelInfo.weight} {wheelInfo.weight === 1 ? "Los" : "Lose"} im Rad</span>}
          </div>
        )}
      </div>
      <div className="shPerf" aria-hidden="true" />
      <div className="shFoot">
        <div className="shPrice"><span className="shCoin" aria-hidden="true">🐔</span><strong>{nf(item.price)}</strong><small>Chickens</small></div>
        {user && missing > 0 && !isOwned && <div className="shProgress" title={`Du hast ${nf(balance)} von ${nf(item.price)} Chickens`}><i style={{ width: `${progress}%` }} /></div>}
        <button type="button" className={`shBuy${isOwned || missing ? " ghost" : ""}`} disabled={Boolean(buying) || isOwned || Boolean(user && missing)} onClick={(event) => onBuy(item, event)}>{label}</button>
      </div>
      <span className="shSheen" aria-hidden="true" />
    </article>
  );
}

export function CommunityShop({ user, setPage, data, loading, error }) {
  const [category, setCategory] = useState("Alle");
  const [message, setMessage] = useState(null);
  const [buying, setBuying] = useState(null);
  const [owned, setOwned] = useState(new Set());
  const [wheel, setWheel] = useState(null);
  const [ownedSkins, setOwnedSkins] = useState(new Set());
  const attempts = useRef(new Map());
  const pending = useRef(false);
  const catalogRef = useRef(null);
  const categories = ["Alle", ...new Set(data.map((item) => item.category || "Rewards"))];
  const items = category === "Alle" ? data : data.filter((item) => (item.category || "Rewards") === category);
  const counts = data.reduce((m, item) => { const c = item.category || "Rewards"; m[c] = (m[c] || 0) + 1; return m; }, {});

  useEffect(() => {
    let alive = true;
    if (user) api("/api/chat/styles").then((result) => { if (alive) setOwned(new Set((result.styles || []).filter((style) => style.owned).map((style) => style.id))); }).catch(() => {});
    if (user) api("/api/horses").then((result) => { if (alive && result?.skins) setOwnedSkins(new Set(result.skins.owned || [])); }).catch(() => {});
    return () => { alive = false; };
  }, [user?.username]);

  const loadWheel = () => api("/api/stream/wheel").then((w) => setWheel(w && Array.isArray(w.entries) ? w : null)).catch(() => {});
  useEffect(() => { loadWheel(); }, []);

  const wheelByKey = useMemo(() => {
    const entries = wheel?.entries || [];
    const total = entries.reduce((s, e) => s + e.weight, 0);
    return new Map(entries.map((e) => [e.key, { weight: e.weight, chance: total ? e.weight / total : 0 }]));
  }, [wheel]);

  const hotIds = useMemo(() => new Set([...data].filter((i) => (i.sold || 0) >= 2).sort((a, b) => (b.sold || 0) - (a.sold || 0)).slice(0, 3).map((i) => String(i.id))), [data]);

  async function buy(item, event) {
    const from = event?.currentTarget?.getBoundingClientRect?.();
    if (pending.current) return;
    if (!user) { setPage("login"); return; }
    preloadPurchaseSounds();
    pending.current = true;
    const key = String(item.id);
    if (!attempts.current.has(key)) attempts.current.set(key, requestId());
    setBuying(key);
    setMessage(null);
    try {
      const result = await api("/api/shop/purchase", { method: "POST", body: JSON.stringify({ item_id: key, request_id: attempts.current.get(key) }) });
      publishWallet(user.username, result.wallet);
      attempts.current.delete(key);
      if (item.style) setOwned((current) => new Set([...current, item.style]));
      if (item.skin) setOwnedSkins((current) => new Set([...current, item.skin]));
      setMessage({ text: result.message, error: false });
      const punishment = PUNISHMENT.includes(item.category);
      if (punishment) loadWheel();
      celebratePurchase({
        kind: item.style || item.skin ? "style" : punishment ? "punishment" : "reward",
        title: item.name,
        sub: punishment ? "Erscheint gleich live im Stream!" : item.style ? "Im Chat unter Chat-Animationen auswählbar." : item.skin ? "Läuft ab jetzt im Chicken Derby für dich!" : result.message,
        cost: `−${nf(item.price)} Chickens`,
        from,
      });
    } catch (err) {
      setMessage({ text: err.message, error: true });
    } finally { pending.current = false; setBuying(null); }
  }

  function showPunishments() {
    const target = categories.find((c) => PUNISHMENT.includes(c));
    if (target) setCategory(target);
    catalogRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  return <section className="stack shopPage shStore">
    <header className="shHero">
      <span className="shHeroAurora" aria-hidden="true" />
      <div className="shHeroText">
        <span className="shKicker">Aviary Store</span>
        <h1>Deine Chickens.<br /><em>Dein Stream-Moment.</em></h1>
        <p>Bestrafungen, Aufgaben und Rewards – alles, womit du den Stream ein bisschen spannender machst.</p>
        <div className="shHeroChips">
          <button type="button" onClick={() => setPage("games")}><Gamepad2 size={15} /> Bis zu 25 pro Runde <ArrowRight size={14} /></button>
          <span><Timer size={15} /> ab 15 Sek. Spielzeit</span>
          <span><CalendarClock size={15} /> max. 120 pro Tag</span>
        </div>
      </div>
      <MemberCard user={user} setPage={setPage} />
    </header>

    <WheelSpotlight wheel={wheel} onShow={showPunishments} />

    <div className="shTabs" ref={catalogRef}>
      <div className="shopCategoryTabs" role="group" aria-label="Shop-Kategorien">
        {categories.map((value) => {
          const Icon = value === "Alle" ? LayoutGrid : shopTheme(value).icon;
          return (
            <button key={value} type="button" aria-label={value} aria-pressed={category === value} className={`${category === value ? "active" : ""} theme-${value === "Alle" ? "all" : shopTheme(value).key}`} onClick={() => setCategory(value)}>
              <Icon size={15} aria-hidden="true" /><span>{value}</span><small aria-hidden="true">{value === "Alle" ? data.length : counts[value]}</small>
            </button>
          );
        })}
      </div>
    </div>
    {message && <div className={`notice ${message.error ? "error" : "purchaseSuccess"}`} role={message.error ? "alert" : "status"}>{!message.error && <Check size={18} />}{message.text}</div>}
    {loading && <div className="notice" role="status">Shop wird geladen …</div>}
    {error && <div className="notice error" role="alert">{error}</div>}
    <div className="shopCatalog shGrid">
      {items.map((item) => (
        <ShopCard key={item.id} item={item} user={user} owned={owned} ownedSkins={ownedSkins} buying={buying} hot={hotIds.has(String(item.id))}
          wheelInfo={PUNISHMENT.includes(item.category) ? wheelByKey.get(wheelKey(item.name)) : null} onBuy={buy} />
      ))}
    </div>
    {!loading && !error && !items.length && <div className="notice">In dieser Kategorie gibt es noch keine Rewards.</div>}

    <CasinoCashier user={user} setPage={setPage} />
  </section>;
}
