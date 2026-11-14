import React, { forwardRef, useEffect, useImperativeHandle, useLayoutEffect, useRef, useState } from "react";
import { ALL_SYMBOLS, SlotSymbol } from "./symbols.jsx";

const randomSym = () => ALL_SYMBOLS[Math.floor(Math.random() * ALL_SYMBOLS.length)];
const LOOP = 12;   // symbols in the endless spinning loop
const RUNWAY = 8;  // symbols that fly past during the landing
const easeOutBack = (t) => { const c = 1.9; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); };

// One reel. While spinning it scrolls an endless strip with motion blur (driven by
// requestAnimationFrame, not CSS, so speed can change smoothly for the tension phase);
// stop() swaps in a runway that ends on the final symbols and lands with an overshoot.
export const Reel = forwardRef(function Reel({ symbols, index, hits, line, tense }, ref) {
  const [mode, setMode] = useState("still");
  const [strip, setStrip] = useState(null);
  const box = useRef(null);
  const el = useRef(null);
  const s = useRef({ frame: 0, pos: 0, speed: 0, pending: null });
  const tenseRef = useRef(tense);
  tenseRef.current = tense;

  const cell = () => (box.current?.clientHeight || 300) / 3;
  const paint = (y, blur) => {
    if (!el.current) return;
    el.current.style.transform = `translate3d(0, ${y}px, 0)`;
    el.current.style.filter = blur > 0.3 ? `blur(${blur.toFixed(1)}px) brightness(1.08)` : "";
  };

  useEffect(() => () => cancelAnimationFrame(s.current.frame), []);

  // Animations start after React has rendered the matching strip.
  useLayoutEffect(() => {
    const st = s.current;
    if (mode === "still" && el.current) { el.current.style.transform = ""; el.current.style.filter = ""; }
    if (st.pending) { const run = st.pending; st.pending = null; run(); }
  }, [strip, mode]);

  useImperativeHandle(ref, () => ({
    spin() {
      const st = s.current;
      cancelAnimationFrame(st.frame);
      const filler = Array.from({ length: LOOP }, randomSym);
      st.pending = () => {
        const t0 = performance.now();
        let last = t0;
        st.pos = 0; st.speed = 0;
        const loop = (now) => {
          const dt = Math.min(0.05, (now - last) / 1000);
          last = now;
          const c = cell(), span = LOOP * c, age = (now - t0) / 1000;
          if (age < 0.14) {
            // Wind-up: the reel twitches up a little before it rips down.
            paint(-span - Math.sin((age / 0.14) * Math.PI) * c * 0.22, 0);
          } else {
            const target = tenseRef.current ? 9 : 26; // symbols per second
            st.speed += Math.sign(target - st.speed) * Math.min(Math.abs(target - st.speed), 90 * dt);
            st.pos = (st.pos + st.speed * c * dt) % span;
            paint(-span + st.pos, Math.min(5, st.speed / 5));
          }
          st.frame = requestAnimationFrame(loop);
        };
        st.frame = requestAnimationFrame(loop);
      };
      setStrip([...filler, ...filler]);
      setMode("spin");
    },
    stop(final, ms = 520) {
      const st = s.current;
      return new Promise((resolve) => {
        cancelAnimationFrame(st.frame);
        const landing = [randomSym(), ...final, ...Array.from({ length: RUNWAY }, randomSym)];
        st.pending = () => {
          const c = cell(), from = -(RUNWAY + 1) * c, to = -c, t0 = performance.now();
          const startBlur = Math.min(5, (st.speed || 20) / 5);
          const loop = (now) => {
            const t = Math.min(1, (now - t0) / ms);
            paint(from + (to - from) * easeOutBack(t), startBlur * Math.max(0, 1 - t * 1.6));
            if (t < 1) st.frame = requestAnimationFrame(loop);
            else { st.speed = 0; setStrip(null); setMode("still"); resolve(); }
          };
          st.frame = requestAnimationFrame(loop);
        };
        setStrip(landing);
        setMode("land");
      });
    },
  }), []);

  const moving = mode !== "still";
  const items = moving && strip ? strip : symbols;
  return (
    <div ref={box} className={`slReel${moving ? " moving" : ""}${tense && moving ? " tenseReel" : ""}`}>
      <div className="slStrip" ref={el}>
        {items.map((sym, i) => {
          const hit = !moving && hits?.has(`${index}-${i}`);
          const inLine = !moving && line?.some(([r, row]) => r === index && row === i);
          return <div key={moving ? `m${i}` : `s${i}`} className={`slCell${hit ? " hit" : ""}${inLine ? " inLine" : ""}`}><SlotSymbol name={sym} /></div>;
        })}
      </div>
    </div>
  );
});
