import React, { useEffect, useRef, useState } from "react";
import { ArrowRight, Check, Gamepad2, Gift, Radio, ShoppingBasket, Sparkles } from "lucide-react";
import { api } from "../api";
import { publishWallet, requestId } from "./useGameRewards";
import "./economy.css";

export function CommunityShop({ user, setPage, data, loading, error }) {
  const [category, setCategory] = useState("Alle");
  const [message, setMessage] = useState(null);
  const [buying, setBuying] = useState(null);
  const [owned, setOwned] = useState(new Set());
  const attempts = useRef(new Map());
  const pending = useRef(false);
  const categories = ["Alle", ...new Set(data.map((item) => item.category || "Rewards"))];
  const items = category === "Alle" ? data : data.filter((item) => (item.category || "Rewards") === category);
  useEffect(() => {
    let alive = true;
    if (user) api("/api/chat/styles").then((result) => { if (alive) setOwned(new Set((result.styles || []).filter((style) => style.owned).map((style) => style.id))); }).catch(() => {});
    return () => { alive = false; };
  }, [user?.username]);

  async function buy(item) {
    if (pending.current) return;
    if (!user) { setPage("login"); return; }
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
      setMessage({ text: result.message, error: false });
    } catch (err) {
      setMessage({ text: err.message, error: true });
    } finally { pending.current = false; setBuying(null); }
  }

  return <section className="stack shopPage">
    <div className="sectionHero"><div><h1>Deine Chickens. Dein Stream-Moment.</h1><p>Spiele, sammle und mach dem Streamer das Leben ein bisschen spannender.</p></div><div className="shopWallet"><ShoppingBasket size={22} /><span><strong>{Number(user?.chickens || 0).toLocaleString("de-DE")}</strong><small>Chickens verfügbar</small></span></div></div>
    <div className="shopEarnBanner"><Gamepad2 size={22} /><span><strong>Verdiene deine Rewards im Spiel.</strong><small>Bis zu 25 Chickens pro Runde · maximal 120 pro Tag · ab 15 Sekunden Spielzeit.</small></span><button className="inlineLink" type="button" onClick={() => setPage("games")}>Jetzt spielen<ArrowRight size={16} /></button></div>
    <div className="shopCategoryTabs" role="group" aria-label="Shop-Kategorien">{categories.map((value) => <button key={value} type="button" aria-pressed={category === value} className={category === value ? "active" : ""} onClick={() => setCategory(value)}>{value}</button>)}</div>
    {message && <div className={`notice ${message.error ? "error" : "purchaseSuccess"}`} role={message.error ? "alert" : "status"}>{!message.error && <Check size={18} />}{message.text}</div>}
    {loading && <div className="notice" role="status">Shop wird geladen …</div>}
    {error && <div className="notice error" role="alert">{error}</div>}
    <div className="shopCatalog">{items.map((item) => {
      const punishment = ["Bestrafungs Ideen", "Idee Bestrafungsrad"].includes(item.category);
      const isOwned = item.style && owned.has(item.style);
      const missing = Math.max(0, item.price - Number(user?.chickens || 0));
      return <article className={`shopRewardCard ${punishment ? "isPunishment" : ""}`} key={item.id}>
        <div className="shopCardTop"><span className="shopRewardIcon">{punishment ? <Gift size={25} /> : item.style ? <Sparkles size={25} /> : <ShoppingBasket size={25} />}</span>{punishment && <span className="shopLiveLabel"><Radio size={13} />Live im Stream</span>}</div>
        <span className="shopRewardCategory">{item.category || "Reward"}</span><h2>{item.name}</h2>
        <p>{item.description || item.desc || (punishment ? "Du kaufst die Bestrafung – dein Name und deine Auswahl erscheinen live im Stream." : "Ein Reward für deinen nächsten Community-Moment.")}</p>
        <div className="shopRewardPrice"><ShoppingBasket size={15} /><strong>{Number(item.price).toLocaleString("de-DE")}</strong><span>Chickens</span></div>
        <button type="button" className={isOwned || missing ? "ghost" : ""} disabled={Boolean(buying) || Boolean(isOwned) || Boolean(user && missing)} onClick={() => buy(item)}>{buying === String(item.id) ? "Wird gekauft …" : isOwned ? "Bereits freigeschaltet" : !user ? "Zum Kaufen anmelden" : missing ? `Noch ${missing.toLocaleString("de-DE")} Chickens` : `Für ${Number(item.price).toLocaleString("de-DE")} Chickens kaufen`}</button>
      </article>;
    })}</div>
    {!loading && !error && !items.length && <div className="notice">In dieser Kategorie gibt es noch keine Rewards.</div>}
  </section>;
}
