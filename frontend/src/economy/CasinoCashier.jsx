import React, { useEffect, useRef, useState } from "react";
import { ArrowRightLeft, Coins, Ticket } from "lucide-react";
import { api } from "../api";
import { publishWallet, requestId } from "./useGameRewards";
import { celebratePurchase, preloadPurchaseSounds } from "./PurchaseCelebration";
import "./casino-cashier.css";

export const gscText = (n) => Math.round(n || 0).toLocaleString("de-DE");
export function gscShort(n) {
  const v = Number(n || 0);
  if (v >= 1e9) return `${(v / 1e9).toLocaleString("de-DE", { maximumFractionDigits: 1 })} Mrd`;
  if (v >= 1e6) return `${(v / 1e6).toLocaleString("de-DE", { maximumFractionDigits: 1 })} Mio`;
  return v.toLocaleString("de-DE");
}

// Casino cashier: Chickens -> Credits, Glücksspiel-Coins -> Chickens.
export function CasinoCashier({ user, setPage }) {
  const [info, setInfo] = useState(null);
  const [busy, setBusy] = useState("");
  const [message, setMessage] = useState(null);
  const ids = useRef(new Map());

  useEffect(() => {
    if (!user) return;
    api("/api/casino").then(setInfo).catch(() => {});
  }, [user?.username]);

  async function act(path, body, key, event, show) {
    const from = event?.currentTarget?.getBoundingClientRect?.();
    if (!user) { setPage?.("login"); return; }
    if (busy) return;
    preloadPurchaseSounds();
    if (!ids.current.has(key)) ids.current.set(key, requestId());
    setBusy(key); setMessage(null);
    try {
      const result = await api(path, { method: "POST", body: JSON.stringify({ ...body, request_id: ids.current.get(key) }) });
      ids.current.delete(key);
      setInfo(result);
      publishWallet(user.username, result.wallet);
      setMessage({ text: result.message, error: false });
      if (show) celebratePurchase({ ...show, from });
    } catch (e) { setMessage({ text: e.message, error: true }); }
    setBusy("");
  }

  const w = info?.wallet || { chickens: user?.chickens || 0, credits: user?.credits || 0, gsc: user?.gsc || 0 };
  const price = info?.credit_price || 10;
  const packs = info?.credit_packs || [1, 5, 10, 25];
  const exchange = info?.exchange_packs || [{ chickens: 10, gsc: 250000 }, { chickens: 50, gsc: 1250000 }, { chickens: 100, gsc: 2500000 }];
  const left = Math.max(0, (info?.exchange_cap ?? 100) - (info?.exchange_today ?? 0));

  return (
    <section className="cashier" aria-label="Casino-Kasse">
      <span className="cashierBulbs" aria-hidden="true" />
      <header>
        <div><span>CASINO-KASSE</span><h2>Credits & Glücksspiel-Coins</h2><p>1 Credit = 1 Runde PEPPLE Pinball oder 1 Spin am Chicken Jackpot. Dort gewinnst du GSC – und GSC tauschst du hier gegen Chickens.</p></div>
        <div className="cashierWallet">
          <div><Ticket size={20} /><strong data-testid="cashier-credits">{w.credits}</strong><small>Credits</small></div>
          <div><Coins size={20} /><strong data-testid="cashier-gsc">{gscText(w.gsc)}</strong><small>GSC</small></div>
        </div>
      </header>
      {message && <div className={`notice ${message.error ? "error" : "purchaseSuccess"}`} role={message.error ? "alert" : "status"}>{message.text}</div>}
      <div className="cashierGrid">
        <div className="cashierBox">
          <h3><Ticket size={18} /> Credits kaufen <small>{price} Chickens pro Credit</small></h3>
          <div className="cashierPacks">
            {packs.map((count) => {
              const cost = count * price, missing = user && (w.chickens ?? 0) < cost;
              return (
                <button key={count} type="button" className="credit" disabled={Boolean(busy) || Boolean(missing)} onClick={(event) => act("/api/casino/credits", { count }, `c${count}`, event, { kind: "credits", title: `${count} Credit${count > 1 ? "s" : ""}`, sub: "Bereit für Pinball und Chicken Jackpot!", cost: `−${cost} Chickens`, gain: `+${count} Credit${count > 1 ? "s" : ""}` })}>
                  <b>{count}</b><span>Credit{count > 1 ? "s" : ""}</span><em>{busy === `c${count}` ? "…" : `${cost} Chickens`}</em>
                </button>
              );
            })}
          </div>
        </div>
        <div className="cashierBox">
          <h3><ArrowRightLeft size={18} /> GSC eintauschen <small>Heute noch {left} Chickens möglich</small></h3>
          <div className="cashierPacks">
            {exchange.map((p) => {
              const missing = user && (w.gsc ?? 0) < p.gsc;
              return (
                <button key={p.chickens} type="button" className="swap" disabled={Boolean(busy) || Boolean(missing) || p.chickens > left} onClick={(event) => act("/api/casino/exchange", { chickens: p.chickens }, `x${p.chickens}`, event, { kind: "exchange", title: `${p.chickens} Chickens`, sub: "Deine Glücksspiel-Coins wurden ausgezahlt.", cost: `−${gscShort(p.gsc)} GSC`, gain: `+${p.chickens} Chickens` })}>
                  <b>{p.chickens}</b><span>Chickens</span><em>{busy === `x${p.chickens}` ? "…" : `${gscShort(p.gsc)} GSC`}</em>
                </button>
              );
            })}
          </div>
        </div>
      </div>
      <p className="cashierFine">Alles virtuell, kein echtes Geld. GSC gibt es nur beim PEPPLE Pinball (Score ÷ 10) und am Chicken Jackpot.</p>
    </section>
  );
}
