// Bestrafungsrad as an OBS/Streamlabs browser source (1920 × 1080, transparent).
//   /stream/wheel           live: every spin started in the admin tab plays full screen, then hides again
//   /stream/wheel?muted=1   silent copy (preview)
//   /stream/wheel?demo=1    endless demo spins for setting up the scene
import React, { useEffect, useMemo, useState } from "react";
import { WheelAudio } from "./audio.js";
import { WheelStage } from "./WheelStage.jsx";
import { TAU, spans } from "./engine.js";

const DEMO = [
  ["10 Liegestütze", 3, ["alice", "bob", "carla"]], ["Kein Englisch für 15 Min", 2, ["dino", "eli"]], ["Mit Akzent reden", 1, ["fritz"]],
  ["Nur mit Maus spielen", 1, ["gina"]], ["Chicken-Tanz", 2, ["hans", "hans"]], ["Eiswürfel essen", 1, ["ida"]], ["Singen!", 1, ["jo"]],
].map(([name, weight, buyers]) => ({ key: name.toLowerCase(), name, weight, buyers: Object.entries(buyers.reduce((m, b) => ({ ...m, [b]: (m[b] || 0) + 1 }), {})).map(([username, count]) => ({ username, count })) }));

export function demoSpin(entries, id, startAngle, created) {
  const segs = spans(entries);
  const total = entries.reduce((s, e) => s + e.weight, 0);
  let ticket = Math.random() * total, pick = 0;
  for (let i = 0; i < entries.length; i++) { ticket -= entries[i].weight; if (ticket < 0) { pick = i; break; } }
  const seg = segs[pick], margin = (seg.to - seg.from) * 0.12;
  const target = seg.from + margin + Math.random() * (seg.to - seg.from - 2 * margin);
  const rest = (((-target - startAngle) % TAU) + TAU) % TAU;
  return { id, created, entries, winner: entries[pick].key, start_angle: startAngle, final_angle: startAngle + 7 * TAU + rest, status: "open", intro: 2.2, spin: 11, reveal: 9 };
}

export function WheelOverlay() {
  const params = useMemo(() => new URLSearchParams(window.location.search), []);
  const muted = params.get("muted") === "1";
  const demo = params.get("demo") === "1";
  const audio = useMemo(() => new WheelAudio(), []);
  const [state, setState] = useState({ entries: demo ? DEMO : [], spin: null, offset: 0 });

  useEffect(() => {
    document.documentElement.classList.add("streamOverlay");
    if (muted) { audio.setSfx(false); audio.setMusic(false); }
    audio.ensure();
    return () => { document.documentElement.classList.remove("streamOverlay"); audio.end(); audio.dispose?.(); };
  }, [audio, muted]);

  useEffect(() => {
    let alive = true, timer = 0;
    if (demo) {
      let id = 1, angle = 0;
      const next = () => {
        if (!alive) return;
        const spin = demoSpin(DEMO, id++, angle, Date.now() / 1000 + 1);
        angle = spin.final_angle % TAU;
        setState({ entries: DEMO, spin, offset: 0 });
        timer = setTimeout(next, 26000);
      };
      next();
      return () => { alive = false; clearTimeout(timer); };
    }
    let offset = null;
    const poll = async () => {
      const ctrl = typeof AbortController === "function" ? new AbortController() : null;
      const abort = setTimeout(() => ctrl?.abort(), 4000);
      const sent = Date.now() / 1000;
      try {
        const response = await fetch("/api/stream/wheel", { cache: "no-store", signal: ctrl?.signal });
        if (response.ok) {
          const data = await response.json();
          const got = Date.now() / 1000;
          const measured = data.server_time - (sent + got) / 2;
          // Keep the steadiest clock offset so the spin never jumps.
          offset = offset === null || Math.abs(measured - offset) > 2 ? measured : offset * 0.9 + measured * 0.1;
          if (alive) setState((s) => ({ entries: data.entries || [], spin: data.spin && (!s.spin || s.spin.id !== data.spin.id) ? data.spin : (s.spin && data.spin ? s.spin : data.spin), offset }));
        }
      } catch { /* keep polling */ }
      clearTimeout(abort);
      if (alive) timer = setTimeout(poll, 1000);
    };
    poll();
    return () => { alive = false; clearTimeout(timer); };
  }, [demo]);

  return <WheelStage entries={state.entries} spin={state.spin} offset={state.offset} audio={audio} />;
}
