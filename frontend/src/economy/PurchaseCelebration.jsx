import React, { useEffect, useRef, useState } from "react";
import { ArrowRightLeft, Check, Gift, Radio, ShoppingBasket, Sparkles, Ticket, X } from "lucide-react";
import { SlotFx } from "../slots/fx.js";
import "./purchase-celebration.css";

// Fire from anywhere after a successful purchase:
//   celebratePurchase({ kind, title, sub, cost, gain, from })
// kind: "reward" | "punishment" | "style" | "credits" | "exchange"; from: DOMRect of the button.
export function celebratePurchase(detail) {
  window.dispatchEvent(new CustomEvent("aviary-purchase", { detail }));
}

// Small sample player that only loads the handful of casino sounds it needs.
const NAMES = ["bonus-total", "coin-1", "coin-2", "coin-3", "coin-4", "coin-5", "mission-start", "jackpot", "skill-shot"];
const kit = { ctx: null, buffers: new Map() };
export function preloadPurchaseSounds() {
  try {
    if (!kit.ctx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      kit.ctx = new Ctx();
    }
    for (const name of NAMES) {
      if (!kit.buffers.has(name)) kit.buffers.set(name, fetch(`/audio/pinball/${name}.ogg`).then((r) => (r.ok ? r.arrayBuffer() : null)).then((b) => (b ? kit.ctx.decodeAudioData(b) : null)).catch(() => null));
    }
  } catch { /* no audio */ }
}
async function play(name, gain = 0.5, rate = 1, delay = 0) {
  preloadPurchaseSounds();
  const ctx = kit.ctx;
  if (!ctx) return;
  if (ctx.state === "suspended") await ctx.resume().catch(() => {});
  const buffer = await kit.buffers.get(name);
  if (!buffer || ctx.state !== "running") return;
  const src = ctx.createBufferSource(), g = ctx.createGain();
  src.buffer = buffer; src.playbackRate.value = rate; g.gain.value = gain;
  src.connect(g).connect(ctx.destination);
  src.start(ctx.currentTime + delay);
}
function sound(kind) {
  play("bonus-total", 0.5);
  for (let i = 0; i < 6; i++) play(`coin-${1 + (i % 5)}`, 0.4, 0.9 + Math.random() * 0.4, 0.12 + i * 0.07);
  if (kind === "punishment") play("mission-start", 0.55, 1, 0.25);
  else play(kind === "credits" || kind === "exchange" ? "jackpot" : "skill-shot", 0.45, 1, 0.26);
}

const ICONS = { reward: ShoppingBasket, punishment: Gift, style: Sparkles, credits: Ticket, exchange: ArrowRightLeft };
const STAMP = { reward: "GEKAUFT!", punishment: "GEKAUFT!", style: "FREIGESCHALTET!", credits: "AUFGELADEN!", exchange: "EINGETAUSCHT!" };

export function PurchaseCelebration() {
  const [show, setShow] = useState(null);
  const canvas = useRef(null);
  const fx = useRef(null);
  const timer = useRef(0);

  useEffect(() => {
    fx.current = canvas.current ? new SlotFx(canvas.current) : null;
    function onPurchase(event) {
      const d = event.detail || {};
      clearTimeout(timer.current);
      setShow({ ...d, key: Math.random() });
      sound(d.kind);
      const f = fx.current;
      if (f) {
        f.resize();
        if (d.from) {
          const x = (d.from.left + d.from.width / 2) / window.innerWidth, y = (d.from.top + d.from.height / 2) / window.innerHeight;
          f.burst("spark", x, y, 26, 0.7);
          f.burst("star", x, y, 10, 0.6);
        }
        setTimeout(() => {
          f.burst("star", 0.5, 0.45, 40, 1.4);
          f.burst(d.kind === "style" ? "star" : "coin", 0.5, 0.45, 26, 1.2);
          if (d.kind === "credits" || d.kind === "exchange") f.fountain(40, 1);
          f.rain(d.kind === "punishment" ? "star" : "feather", 14, 1.6);
        }, 160);
      }
      timer.current = setTimeout(() => setShow(null), 3200);
    }
    window.addEventListener("aviary-purchase", onPurchase);
    return () => { window.removeEventListener("aviary-purchase", onPurchase); clearTimeout(timer.current); fx.current?.dispose(); };
  }, []);

  const Icon = ICONS[show?.kind] || ShoppingBasket;
  return <>
    <canvas ref={canvas} className="buyFx" aria-hidden="true" />
    {show && (
      <div className={`buyCelebration kind-${show.kind || "reward"}`} key={show.key} role="status" aria-live="polite" onClick={() => setShow(null)}>
        <div className="buyRays" aria-hidden="true" />
        <div className="buyCard">
          <button type="button" className="buyClose" aria-label="Schließen" onClick={() => setShow(null)}><X size={18} /></button>
          <span className="buyIcon"><Icon size={46} strokeWidth={1.8} /><i /></span>
          <strong className="buyStamp">{STAMP[show.kind] || "GEKAUFT!"}</strong>
          <h3>{show.title}</h3>
          {show.sub && <p>{show.kind === "punishment" && <Radio size={15} />}{show.sub}</p>}
          <div className="buyDeltas">
            {show.cost && <b className="minus">{show.cost}</b>}
            {show.gain && <b className="plus">{show.gain}</b>}
          </div>
          <span className="buyCheck" aria-hidden="true"><Check size={22} strokeWidth={3} /></span>
        </div>
      </div>
    )}
  </>;
}
