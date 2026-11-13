import React from "react";

// Flat neon silhouettes of the polyhedral dice.
const SHAPES = {
  4: <><path d="M32 6 58 54H6Z" /><path d="M32 6v48M6 54l26-18 26 18" className="dieEdge" /></>,
  6: <><rect x="10" y="10" width="44" height="44" rx="6" /><path d="M10 10l10 8h24l10-8M20 18v36M44 18v36" className="dieEdge" /></>,
  8: <><path d="M32 4 58 32 32 60 6 32Z" /><path d="M6 32h52M32 4 20 32l12 28 12-28Z" className="dieEdge" /></>,
  10: <><path d="M32 4 58 26 50 52 32 60 14 52 6 26Z" /><path d="M32 4 22 34l10 10 10-10ZM6 26l16 8M58 26l-16 8M32 44v16" className="dieEdge" /></>,
  12: <><path d="M32 4 58 22 50 54H14L6 22Z" /><path d="M32 16 44 26 40 42H24L20 26Z M32 4v12M58 22l-14 4M50 54l-10-12M14 54l10-12M6 22l14 4" className="dieEdge" /></>,
  20: <><path d="M32 3 57 17v30L32 61 7 47V17Z" /><path d="M32 3 20 26h24ZM20 26 32 46 44 26M7 17l13 9M57 17 44 26M7 47l25-1 25 1M32 46v15" className="dieEdge" /></>,
  100: <><path d="M22 6 40 22 34 46 22 52 10 46 4 22Z" /><path d="M42 12 60 28 54 52 42 58 30 52" /><path d="M22 6 15 28l7 8 7-8Z" className="dieEdge" /></>,
};

export function DieIcon({ sides, size = 40, label = true, className = "" }) {
  return <span className={`dieIcon d${sides} ${className}`} style={{ width: size, height: size }}>
    <svg viewBox="0 0 64 64" aria-hidden="true">{SHAPES[sides] || SHAPES[20]}</svg>
    {label && <b>{sides === 100 ? "%" : sides}</b>}
  </span>;
}
