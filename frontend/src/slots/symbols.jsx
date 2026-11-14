import React from "react";

// Neon slot symbols drawn as SVG (viewBox 0 0 100 100).
const defs = (
  <defs>
    <radialGradient id="sgRed" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stopColor="#ffb3c1" /><stop offset="0.4" stopColor="#ff2a4a" /><stop offset="1" stopColor="#7a0016" /></radialGradient>
    <radialGradient id="sgLemon" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stopColor="#fffbd0" /><stop offset="0.45" stopColor="#ffe14a" /><stop offset="1" stopColor="#c99600" /></radialGradient>
    <radialGradient id="sgGrape" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stopColor="#e9c4ff" /><stop offset="0.45" stopColor="#9b3dff" /><stop offset="1" stopColor="#3a0a7a" /></radialGradient>
    <linearGradient id="sgGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#fff6c4" /><stop offset="0.4" stopColor="#ffd36b" /><stop offset="1" stopColor="#b8740a" /></linearGradient>
    <linearGradient id="sgSeven" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#ffd0d8" /><stop offset="0.45" stopColor="#ff2a4a" /><stop offset="1" stopColor="#8a0018" /></linearGradient>
    <radialGradient id="sgEgg" cx="0.38" cy="0.32" r="0.75"><stop offset="0" stopColor="#ffffff" /><stop offset="0.3" stopColor="#fff1a8" /><stop offset="0.7" stopColor="#ffc94a" /><stop offset="1" stopColor="#b8740a" /></radialGradient>
  </defs>
);

const ART = {
  cherry: (
    <g>
      <path d="M50 18 C46 34 36 44 30 56 M50 18 C56 34 64 44 70 52" stroke="#2fbf4a" strokeWidth="5" fill="none" strokeLinecap="round" />
      <path d="M50 18 C62 12 74 16 80 24 C70 26 60 24 50 18 Z" fill="#46e06a" />
      <circle cx="30" cy="66" r="19" fill="url(#sgRed)" stroke="#5a0010" strokeWidth="2.5" />
      <circle cx="70" cy="62" r="19" fill="url(#sgRed)" stroke="#5a0010" strokeWidth="2.5" />
      <ellipse cx="24" cy="58" rx="5" ry="3.5" fill="#fff" opacity="0.8" /><ellipse cx="64" cy="54" rx="5" ry="3.5" fill="#fff" opacity="0.8" />
    </g>
  ),
  lemon: (
    <g>
      <ellipse cx="50" cy="52" rx="36" ry="27" fill="url(#sgLemon)" stroke="#8a6400" strokeWidth="2.5" transform="rotate(-18 50 52)" />
      <path d="M16 62 l-6 4 M84 42 l6 -4" stroke="#8a6400" strokeWidth="4" strokeLinecap="round" />
      <ellipse cx="38" cy="42" rx="10" ry="5" fill="#fff" opacity="0.7" transform="rotate(-18 38 42)" />
    </g>
  ),
  grape: (
    <g>
      <path d="M50 12 L50 24" stroke="#5a3a10" strokeWidth="5" strokeLinecap="round" />
      <path d="M50 18 C60 8 74 12 76 20 C66 22 58 22 50 18 Z" fill="#46e06a" />
      {[[36, 32], [52, 30], [68, 34], [28, 48], [44, 48], [60, 48], [74, 50], [36, 64], [52, 64], [66, 66], [44, 80], [58, 80]].map(([x, y], i) => (
        <g key={i}><circle cx={x} cy={y} r="10" fill="url(#sgGrape)" stroke="#2a0660" strokeWidth="1.5" /><circle cx={x - 3} cy={y - 3} r="2.5" fill="#fff" opacity="0.75" /></g>
      ))}
    </g>
  ),
  bell: (
    <g>
      <path d="M50 12 C30 14 26 34 26 52 C26 62 20 68 14 74 L86 74 C80 68 74 62 74 52 C74 34 70 14 50 12 Z" fill="url(#sgGold)" stroke="#7a4a00" strokeWidth="3" />
      <rect x="12" y="72" width="76" height="8" rx="4" fill="url(#sgGold)" stroke="#7a4a00" strokeWidth="2.5" />
      <circle cx="50" cy="86" r="7" fill="url(#sgGold)" stroke="#7a4a00" strokeWidth="2.5" />
      <path d="M38 26 C34 34 34 46 34 56" stroke="#fff" strokeWidth="5" opacity="0.6" strokeLinecap="round" fill="none" />
    </g>
  ),
  bar: (
    <g>
      <rect x="8" y="28" width="84" height="44" rx="10" fill="#120414" stroke="url(#sgGold)" strokeWidth="5" />
      <text x="50" y="62" textAnchor="middle" fontSize="30" fontWeight="900" fontFamily="Inter, Arial" fill="url(#sgGold)" stroke="#5a2a00" strokeWidth="1.2" letterSpacing="2">BAR</text>
    </g>
  ),
  seven: (
    <text x="50" y="84" textAnchor="middle" fontSize="86" fontWeight="900" fontStyle="italic" fontFamily="Inter, Arial" fill="url(#sgSeven)" stroke="#ffd36b" strokeWidth="3.5" paintOrder="stroke">7</text>
  ),
  wild: (
    <g>
      <path d="M14 66 L20 28 L36 46 L50 18 L64 46 L80 28 L86 66 Z" fill="url(#sgGold)" stroke="#7a4a00" strokeWidth="3" strokeLinejoin="round" />
      <rect x="14" y="64" width="72" height="12" rx="4" fill="url(#sgGold)" stroke="#7a4a00" strokeWidth="3" />
      {[[20, 28], [50, 18], [80, 28]].map(([x, y], i) => <circle key={i} cx={x} cy={y} r="5" fill="#ff3fb4" stroke="#fff" strokeWidth="1.5" />)}
      <text x="50" y="94" textAnchor="middle" fontSize="17" fontWeight="900" fontFamily="Inter, Arial" fill="#fff" stroke="#ff3fb4" strokeWidth="1.2" paintOrder="stroke" letterSpacing="2">WILD</text>
    </g>
  ),
  egg: (
    <g>
      <path d="M50 10 C28 10 18 46 18 60 C18 80 32 92 50 92 C68 92 82 80 82 60 C82 46 72 10 50 10 Z" fill="url(#sgEgg)" stroke="#8a5a00" strokeWidth="3" />
      <path d="M36 26 C30 36 28 46 28 54" stroke="#fff" strokeWidth="6" opacity="0.7" strokeLinecap="round" fill="none" />
      <text x="50" y="68" textAnchor="middle" fontSize="15" fontWeight="900" fontFamily="Inter, Arial" fill="#8a3a00" letterSpacing="1">BONUS</text>
      <path d="M78 14 l3 8 l8 3 l-8 3 l-3 8 l-3 -8 l-8 -3 l8 -3 Z" fill="#fff" />
    </g>
  ),
};

export const SYMBOL_NAMES = { cherry: "Kirsche", lemon: "Zitrone", grape: "Trauben", bell: "Glocke", bar: "BAR", seven: "Sieben", wild: "Wild (Krone)", egg: "Goldenes Ei" };
export const ALL_SYMBOLS = Object.keys(ART);

export function SlotSymbol({ name, className = "" }) {
  return <svg className={`slotSym sym-${name} ${className}`} viewBox="0 0 100 100" aria-label={SYMBOL_NAMES[name]} role="img">{defs}{ART[name]}</svg>;
}
