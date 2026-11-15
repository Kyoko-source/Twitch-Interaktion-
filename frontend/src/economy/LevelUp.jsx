import React, { useEffect, useRef, useState } from "react";
import { Award, Coins, Gift, Lock, Sparkles, Star, Ticket, TrendingUp, Unlock, X } from "lucide-react";
import { api } from "../api";
import { SlotFx } from "../slots/fx.js";
import "./level-up.css";

const SOURCES = { start: "Runde gestartet", game: "Runde gespielt", casino: "Casino & Derby", shop: "Einkauf", chat: "Chat", daily: "Täglicher Besuch", bonus: "Bonus" };

function playSound(name, gain = 0.6) {
  try { const a = new Audio(`/audio/pinball/${name}.ogg`); a.volume = gain; a.play().catch(() => {}); } catch { /* no audio */ }
}

// Watches the signed-in user: a higher level shows the celebration, more XP shows a small "+XP" toast.
export function LevelUpCelebration({ user }) {
  const seen = useRef({ name: null, level: null, xp: null });
  const [show, setShow] = useState(null);
  const [toasts, setToasts] = useState([]);
  const canvas = useRef(null);
  const fx = useRef(null);

  useEffect(() => {
    if (!user?.username) { seen.current = { name: null, level: null, xp: null }; return; }
    const prev = seen.current;
    const level = user.level || 1, xp = user.xp ?? null;
    if (prev.name === user.username) {
      if (xp !== null && prev.xp !== null && xp > prev.xp) {
        const id = Math.random();
        setToasts((t) => [...t.slice(-2), { id, amount: xp - prev.xp }]);
        setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 2600);
      }
      if (prev.level !== null && level > prev.level) {
        const from = prev.level;
        api("/api/levels").then((info) => setShow({ from, to: level, info })).catch(() => setShow({ from, to: level, info: null }));
      }
    }
    seen.current = { name: user.username, level, xp };
  }, [user?.username, user?.level, user?.xp]);

  useEffect(() => {
    if (!show) return undefined;
    playSound("super-jackpot", 0.7);
    setTimeout(() => playSound("vo-f-level-up", 0.9), 500);
    fx.current = canvas.current ? new SlotFx(canvas.current) : null;
    fx.current?.burst("star", 0.5, 0.4, 70, 1.5);
    fx.current?.rain("coin", 30, 2.5);
    fx.current?.rain("feather", 6, 3);
    return () => fx.current?.dispose();
  }, [show]);

  const levels = show ? Array.from({ length: show.to - show.from }, (_, i) => show.from + 1 + i) : [];
  const rewards = levels.reduce((sum, l) => {
    const r = show?.info?.rewards?.[String(l)];
    return r ? { chickens: sum.chickens + r.chickens, credits: sum.credits + r.credits } : sum;
  }, { chickens: 0, credits: 0 });
  const unlocks = (show?.info?.unlock_list || []).filter((u) => levels.includes(u.level));
  const newTitle = (show?.info?.titles || []).filter((t) => levels.includes(t.level)).pop();

  return (
    <>
      <div className="xpToasts" aria-live="polite">{toasts.map((t) => <span key={t.id} className="xpToast"><Sparkles size={14} /> +{t.amount} XP</span>)}</div>
      {show && (
        <div className="levelUp" role="dialog" aria-label={`Level ${show.to} erreicht`} onClick={() => setShow(null)}>
          <canvas ref={canvas} className="levelUpFx" aria-hidden="true" />
          <div className="levelUpCard" onClick={(e) => e.stopPropagation()}>
            <button type="button" className="levelUpClose" aria-label="Schließen" onClick={() => setShow(null)}><X size={18} /></button>
            <span className="levelUpKicker"><TrendingUp size={15} /> LEVEL UP</span>
            <div className="levelUpBadge"><b>{show.to}</b></div>
            <h3>{show.info?.level_title || user?.level_title || "Aufgestiegen!"}</h3>
            {newTitle && <p className="levelUpTitle"><Award size={16} /> Neuer Titel: <b>{newTitle.name}</b></p>}
            <div className="levelUpRewards">
              {rewards.chickens > 0 && <span><Coins size={16} /> +{rewards.chickens} Chickens</span>}
              {rewards.credits > 0 && <span><Ticket size={16} /> +{rewards.credits} Credits</span>}
            </div>
            {unlocks.map((u) => <p key={u.id} className="levelUpUnlock"><Unlock size={16} /> <b>{u.name}</b> – {u.text}</p>)}
            <button type="button" className="levelUpOk" onClick={() => setShow(null)}>Weiter</button>
          </div>
        </div>
      )}
    </>
  );
}

// Profile section: level card, what comes next, unlocks, how to earn XP, recent XP and top levels.
export function LevelPanel({ user }) {
  const [info, setInfo] = useState(null);
  useEffect(() => { if (user?.username) api("/api/levels").then(setInfo).catch(() => {}); }, [user?.username, user?.level, user?.xp]);
  if (!info || !Array.isArray(info.titles) || !Array.isArray(info.unlock_list)) return null;
  const pct = Math.min(100, (info.level_progress / info.level_target) * 100);
  const nextTitle = info.titles.find((t) => t.level > info.level);
  const nextReward = info.rewards?.[String(info.level + 1)];
  return (
    <section className="panel levelPanel">
      <div className="levelHead">
        <div className="levelBadgeBig"><small>LEVEL</small><b>{info.level}</b></div>
        <div className="levelMain">
          <h3>{info.level_title}</h3>
          <div className="levelBar"><i style={{ width: `${pct}%` }} /></div>
          <p>{info.level_progress} / {info.level_target} XP bis Level {info.level + 1}{nextReward ? ` · Belohnung: ${nextReward.chickens} Chickens + ${nextReward.credits} Credits` : ""}</p>
          {nextTitle && <p className="levelNext"><Star size={14} /> Nächster Titel: <b>{nextTitle.name}</b> ab Level {nextTitle.level}</p>}
          {info.streak > 1 && <p className="levelStreak">🔥 {info.streak} Tage in Folge da</p>}
        </div>
      </div>
      <div className="levelGrid">
        <div>
          <h4><Gift size={16} /> Freischaltungen</h4>
          {info.unlock_list.map((u) => {
            const open = info.level >= u.level;
            return <div key={u.id} className={`levelUnlock${open ? " open" : ""}`}>{open ? <Unlock size={16} /> : <Lock size={16} />}<span><b>{u.name}</b><small>{u.text}</small></span><em>Lv {u.level}</em></div>;
          })}
        </div>
        <div>
          <h4><Sparkles size={16} /> So bekommst du XP</h4>
          <ul className="levelHow">
            <li>Jede gespielte Runde, länger und besser gibt mehr (bis 75 XP)</li>
            <li>Chicken Derby: 20 XP, bei Sieg 40 XP</li>
            <li>Chicken Jackpot: 2 XP pro Credit</li>
            <li>Täglich vorbeischauen: 20 XP + Streak-Bonus</li>
            <li>Chat-Nachrichten und Einkäufe im Shop</li>
          </ul>
          <h4>Zuletzt</h4>
          <div className="levelLog">{info.recent?.length ? info.recent.map((r, i) => <span key={i}>{SOURCES[r.source] || r.source}<b>+{r.amount}</b></span>) : <small>Noch keine XP gesammelt.</small>}</div>
        </div>
      </div>
      <h4><TrendingUp size={16} /> Höchste Level</h4>
      <ol className="levelTop">{(info.leaderboard || []).slice(0, 10).map((r) => <li key={r.username} className={r.username === user.username ? "me" : ""}><b>{r.username}</b><span>Lv {r.level} · {r.level_title}</span></li>)}</ol>
    </section>
  );
}
