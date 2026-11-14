import React, { useEffect, useRef, useState } from "react";
import { ChibiGirl } from "./crew.jsx";
import "./hype.css";

// "In your face" layer: giant slam text, speed lines, cabinet quake, the osu!-style hit streak
// and two chibi girls who pop in from the sides and react to everything that happens.
const LINES = {
  combo: ["SUGOI!!", "Kyaa~ Combo!", "Weiter so!!", "Waaah, krass!", "Noch einer!", "Uooooh!"],
  big: ["JACKPOT!!", "Reich! Reich!", "Kawaii~!", "Unglaublich!!", "Du bist ein Gott!"],
  sad: ["Nooo…", "Schade~", "Nächstes Mal!", "Uuuh…"],
  shock: ["Hey!! Nicht schubsen!", "Eeeh?!", "Vorsicht!!"],
  peek: ["Du schaffst das!", "Ziel auf die Rampe!", "Fighto~!", "Ich glaub an dich!", "Combo! Combo!", "Mehr! Mehr!", "Hihi~"],
  streak: ["{n} Treffer!!", "Unaufhaltsam!", "x{n}! Waaah!"],
};
const pick = (list, n) => list[Math.floor(Math.random() * list.length)].replace("{n}", n);
const fmt = (n) => Math.round(n || 0).toLocaleString("de-DE");

export function HypeLayer({ sysRef, snap, best, reduced }) {
  const [girls, setGirls] = useState({ mimi: { mood: "idle", show: false, line: "" }, luna: { mood: "idle", show: false, line: "" } });
  const [hype, setHype] = useState(null);
  const timers = useRef({});
  const rootRef = useRef(null);
  const bestRef = useRef(best);
  const busyUntil = useRef(0);
  bestRef.current = best;

  useEffect(() => {
    const girl = (who, mood, line, ms = 2600) => {
      clearTimeout(timers.current[who]);
      busyUntil.current = Math.max(busyUntil.current, Date.now() + ms);
      setGirls((g) => ({ ...g, [who]: { mood, show: true, line, nonce: Math.random() } }));
      timers.current[who] = setTimeout(() => setGirls((g) => ({ ...g, [who]: { ...g[who], mood: "idle", show: false, line: "" } })), ms);
    };
    const both = (mood, list, ms) => { girl("mimi", mood, pick(list), ms); girl("luna", mood, pick(list), ms); };
    const quake = (strength = 1) => {
      if (reduced) return;
      const m = rootRef.current?.closest(".pbMachine");
      if (!m) return;
      m.style.setProperty("--quake", String(strength));
      m.classList.remove("pbQuake"); void m.offsetWidth; m.classList.add("pbQuake");
      clearTimeout(timers.current.quake);
      timers.current.quake = setTimeout(() => m.classList.remove("pbQuake"), 520);
    };
    const slam = (big, word, { sub = "", tone = "pink", scale = 1, flash = false, ms = 1350 } = {}) => {
      clearTimeout(timers.current.hype);
      setHype({ big, word, sub, tone, scale, flash, key: Math.random() });
      timers.current.hype = setTimeout(() => setHype(null), ms);
    };
    const handler = (type, d = {}) => {
      switch (type) {
        case "combo": {
          const n = d.count;
          slam(`${n}×`, "COMBO!", { tone: n >= 4 ? "rainbow" : n === 3 ? "gold" : "pink", scale: Math.min(1.5, 0.85 + n * 0.12), flash: n >= 4 });
          if (n >= 3) quake(Math.min(2, n * 0.4));
          both(n >= 4 ? "hype" : "cheer", LINES.combo, 2400);
          break;
        }
        case "jackpot": slam(d.wizard ? "1 MIO" : "JACKPOT", d.wizard ? "LAST CALL!" : "", { sub: fmt(d.value), tone: "gold", scale: 1.1, flash: true }); quake(1.4); both("hype", LINES.big, 2600); break;
        case "superJackpot": slam("SUPER", "JACKPOT!!", { sub: fmt(d.value), tone: "rainbow", scale: 1.3, flash: true, ms: 1900 }); quake(2.2); both("hype", LINES.big, 3200); break;
        case "multiball": slam("MULTI", "BALL!!", { tone: "rainbow", scale: 1.2, flash: true, ms: 1700 }); quake(1.8); both("hype", ["Party time!!", "Alle Kugeln los!", "Tanzen!!"], 3000); break;
        case "wizard": slam("LAST", "CALL!!", { tone: "rainbow", scale: 1.3, flash: true, ms: 2200 }); quake(2.4); both("hype", ["DAS FINALE!!", "Alles geben!!"], 3600); break;
        case "skillShot": slam("SKILL", "SHOT!", { sub: fmt(d.value), tone: "cyan", scale: 1, flash: true }); quake(1); girl("luna", "hype", "Perfekt gezielt!!"); break;
        case "missionStart": girl("luna", "wink", "Mission! Los geht's~", 2600); break;
        case "missionComplete": slam("MISSION", "GESCHAFFT!", { tone: "green", scale: 0.9, flash: true, ms: 1700 }); quake(1.2); both("cheer", ["Yatta!!", "Geschafft!!", "Sugoi~!"], 3000); break;
        case "missionFail": both("sad", LINES.sad, 2400); break;
        case "missionHurry": girl("mimi", "shock", "Schnell, schnell!!", 2200); break;
        case "extraBall": slam("EXTRA", "BALL!", { tone: "green", scale: 1, flash: true }); both("cheer", ["Noch ein Leben!", "Yay~!"], 2600); break;
        case "lock": girl("mimi", "wink", d.count === 2 ? "Noch einer bis Multiball!" : "Gesperrt~ ♪", 2200); break;
        case "streak": slam(`${d.count}`, "HIT STREAK", { tone: d.count >= 50 ? "rainbow" : "cyan", scale: d.count >= 100 ? 1.35 : 1.05, flash: d.count >= 50 }); if (d.count >= 25) quake(1); girl(d.count % 2 ? "mimi" : "luna", "hype", pick(LINES.streak, d.count)); break;
        case "streakBreak": slam("COMBO", "BREAKER", { sub: `${d.count} Treffer`, tone: "red", scale: 1 }); quake(1.2); both("shock", ["Neeein!!", "Meine Combo!!", "Eeeeh?!"], 2400); break;
        case "ballSave": girl("luna", "cheer", "Gerettet! Puh~", 2000); break;
        case "drain": both("sad", LINES.sad, 2600); break;
        case "tilt": slam("TILT", "", { tone: "red", scale: 1.2 }); quake(2); both("shock", LINES.shock, 3000); break;
        case "tiltWarning": girl("mimi", "shock", "Nicht so wild!!", 1800); break;
        case "gameStart": both("cheer", ["Let's go!!", "Showtime~!", "Viel Glück!"], 2400); break;
        case "gameOver":
          if (d.score > (bestRef.current || 0) && d.score > 0) { slam("NEUER", "REKORD!!", { sub: fmt(d.score), tone: "rainbow", scale: 1.15, flash: true, ms: 2600 }); quake(1.6); both("hype", ["LEGENDE!!", "Neuer Rekord!!", "Sugoi sugoi!!"], 4200); }
          else both("sad", ["Game over…", "Nochmal?", "Ich will mehr!"], 3600);
          break;
        default: break;
      }
    };
    const s = sysRef.current;
    s.hype = handler;
    // Idle peeks while a ball is in play keep the girls around between big moments.
    const peek = setInterval(() => {
      const st = s.engine?.status;
      if (st !== "play" || Date.now() < busyUntil.current || Math.random() < 0.4) return;
      girl(Math.random() < 0.5 ? "mimi" : "luna", Math.random() < 0.5 ? "wink" : "idle", pick(LINES.peek), 2400);
    }, 9000);
    const t = timers.current;
    return () => { clearInterval(peek); if (s.hype === handler) s.hype = null; Object.values(t).forEach(clearTimeout); };
  }, [sysRef, reduced]);

  const streak = snap.streak || 0;
  return (
    <div className="pbHypeRoot" ref={rootRef} aria-hidden="true">
      {["mimi", "luna"].map((who) => (
        <div key={who} className={`pbGirl pbGirl-${who === "mimi" ? "left" : "right"}${girls[who].show ? " show" : ""}`} data-mood={girls[who].mood}>
          <ChibiGirl who={who} mood={girls[who].mood} />
          {girls[who].line && <span key={girls[who].nonce} className="pbBubble">{girls[who].line}</span>}
        </div>
      ))}
      {streak >= 3 && (
        <div className={`pbStreak${streak >= 50 ? " hot" : streak >= 25 ? " warm" : ""}`}>
          <b key={streak}>{streak}<i>×</i></b>
        </div>
      )}
      {hype && (
        <div key={hype.key} className={`pbSlam tone-${hype.tone}`} style={{ "--slam": hype.scale, "--fit": Math.min(1, 3.4 / hype.big.length), "--fitw": Math.min(1, 6.5 / Math.max(1, hype.word.length)) }}>
          {hype.flash && <span className="pbFlash" />}
          <span className="pbLines" />
          <strong data-text={hype.big}>{hype.big}</strong>
          {hype.word && <em data-text={hype.word}>{hype.word}</em>}
          {hype.sub && <small>{hype.sub}</small>}
        </div>
      )}
    </div>
  );
}
