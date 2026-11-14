import React from "react";

// Royal chicken casino symbols, drawn as SVG (viewBox 0 0 100 100). The ids stay the classic
// slot ids the server uses (cherry, lemon, ...); only the artwork and display names changed.
// Every symbol has a ".symBody" group (whole symbol) and optional parts that the win
// animations in slots.css move (wings, crown, shine, ...).
const defs = (
  <defs>
    <linearGradient id="sgGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#fff6c4" /><stop offset="0.45" stopColor="#ffcf4a" /><stop offset="1" stopColor="#b8740a" /></linearGradient>
    <linearGradient id="sgGoldDark" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#ffd36b" /><stop offset="1" stopColor="#8a4a00" /></linearGradient>
    <radialGradient id="sgCoin" cx="0.38" cy="0.32" r="0.8"><stop offset="0" stopColor="#fff8d8" /><stop offset="0.35" stopColor="#ffd34a" /><stop offset="0.85" stopColor="#c98a0a" /><stop offset="1" stopColor="#8a5200" /></radialGradient>
    <radialGradient id="sgPurple" cx="0.38" cy="0.3" r="0.85"><stop offset="0" stopColor="#f3e2ff" /><stop offset="0.35" stopColor="#c48bff" /><stop offset="0.8" stopColor="#8a3ee8" /><stop offset="1" stopColor="#4a1590" /></radialGradient>
    <radialGradient id="sgBelly" cx="0.5" cy="0.35" r="0.7"><stop offset="0" stopColor="#ffffff" /><stop offset="1" stopColor="#e2c9ff" /></radialGradient>
    <radialGradient id="sgChick" cx="0.38" cy="0.3" r="0.85"><stop offset="0" stopColor="#fffbe0" /><stop offset="0.45" stopColor="#ffe14a" /><stop offset="1" stopColor="#e09a00" /></radialGradient>
    <linearGradient id="sgFeather" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#ffd0f4" /><stop offset="0.45" stopColor="#c86bff" /><stop offset="1" stopColor="#5a1aa8" /></linearGradient>
    <linearGradient id="sgCorn" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#fff2a0" /><stop offset="0.5" stopColor="#ffc824" /><stop offset="1" stopColor="#d88a00" /></linearGradient>
    <linearGradient id="sgHusk" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#8af07a" /><stop offset="1" stopColor="#1f8a3a" /></linearGradient>
    <linearGradient id="sgSeven" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#ffe4ff" /><stop offset="0.4" stopColor="#ff5ad6" /><stop offset="1" stopColor="#8a0a6a" /></linearGradient>
    <radialGradient id="sgEgg" cx="0.38" cy="0.3" r="0.78"><stop offset="0" stopColor="#ffffff" /><stop offset="0.28" stopColor="#fff1a8" /><stop offset="0.7" stopColor="#ffc124" /><stop offset="1" stopColor="#a86400" /></radialGradient>
  </defs>
);

const sparkle = (x, y, s = 1, cls = "symTwinkle") => (
  <path className={cls} d={`M${x} ${y - 9 * s} L${x + 2.4 * s} ${y - 2.4 * s} L${x + 9 * s} ${y} L${x + 2.4 * s} ${y + 2.4 * s} L${x} ${y + 9 * s} L${x - 2.4 * s} ${y + 2.4 * s} L${x - 9 * s} ${y} L${x - 2.4 * s} ${y - 2.4 * s} Z`} fill="#fff" />
);

const crown = (
  <g className="symCrown">
    <path d="M30 26 L34 8 L42 18 L50 4 L58 18 L66 8 L70 26 Z" fill="url(#sgGold)" stroke="#7a4300" strokeWidth="2.5" strokeLinejoin="round" />
    <rect x="29" y="23" width="42" height="7" rx="2.5" fill="url(#sgGold)" stroke="#7a4300" strokeWidth="2" />
    <circle cx="50" cy="4" r="3.6" fill="#ff5ad6" stroke="#fff" strokeWidth="1.2" />
    <circle cx="34" cy="8" r="2.8" fill="#9a4dff" stroke="#fff" strokeWidth="1" />
    <circle cx="66" cy="8" r="2.8" fill="#9a4dff" stroke="#fff" strokeWidth="1" />
    <path d="M47 26.5 l3 -3 l3 3 l-3 3 Z" fill="#c48bff" stroke="#fff" strokeWidth="0.8" />
  </g>
);

const ART = {
  // Maiskolben
  cherry: (
    <g className="symBody">
      <path className="symLeafL" d="M50 92 C30 84 22 62 26 40 C34 56 42 70 50 92 Z" fill="url(#sgHusk)" stroke="#145a26" strokeWidth="2" />
      <path className="symLeafR" d="M50 92 C70 84 78 62 74 40 C66 56 58 70 50 92 Z" fill="url(#sgHusk)" stroke="#145a26" strokeWidth="2" />
      <path d="M50 8 C64 8 68 30 66 56 C64 74 58 84 50 86 C42 84 36 74 34 56 C32 30 36 8 50 8 Z" fill="url(#sgCorn)" stroke="#8a5200" strokeWidth="2.5" />
      {[16, 26, 36, 46, 56, 66, 76].map((y) => [-9, 0, 9].map((dx) => (
        <ellipse key={`${y}${dx}`} cx={50 + dx * (y < 20 || y > 70 ? 0.7 : 1)} cy={y} rx="4" ry="4.4" fill="#ffd94a" stroke="#c98a0a" strokeWidth="1" />
      )))}
      <path d="M42 14 C39 30 39 50 41 70" stroke="#fff" strokeWidth="3.5" opacity="0.55" strokeLinecap="round" fill="none" />
    </g>
  ),
  // Lila Feder
  lemon: (
    <g className="symBody">
      <path className="symFeather" d="M80 10 C46 14 22 40 18 78 C24 72 30 68 36 66 C32 74 30 80 30 88 C56 80 82 52 80 10 Z" fill="url(#sgFeather)" stroke="#3a0a70" strokeWidth="2.5" strokeLinejoin="round" />
      <path d="M80 10 C62 34 42 60 14 94" stroke="#fff3c4" strokeWidth="3" strokeLinecap="round" fill="none" />
      {[[66, 28, 54, 22], [60, 38, 44, 34], [52, 48, 36, 46], [70, 34, 74, 46], [62, 46, 68, 58], [54, 56, 58, 68]].map(([x1, y1, x2, y2], i) => (
        <path key={i} d={`M${x1} ${y1} L${x2} ${y2}`} stroke="#f4d8ff" strokeWidth="1.6" opacity="0.7" strokeLinecap="round" />
      ))}
      {sparkle(28, 26, 0.8)}
    </g>
  ),
  // Küken
  grape: (
    <g className="symBody">
      <ellipse cx="50" cy="90" rx="26" ry="4" fill="#000" opacity="0.18" />
      <g className="symHop">
        <path d="M48 16 C46 8 52 6 54 12 C56 6 62 8 58 16" fill="#ffd34a" stroke="#c98a0a" strokeWidth="1.8" />
        <circle cx="50" cy="54" r="34" fill="url(#sgChick)" stroke="#b87400" strokeWidth="2.5" />
        <path className="symWingL" d="M18 58 C8 54 8 68 20 70 Z" fill="#ffd34a" stroke="#b87400" strokeWidth="2" />
        <path className="symWingR" d="M82 58 C92 54 92 68 80 70 Z" fill="#ffd34a" stroke="#b87400" strokeWidth="2" />
        <ellipse cx="38" cy="48" rx="6" ry="7.5" fill="#2a1240" /><ellipse cx="62" cy="48" rx="6" ry="7.5" fill="#2a1240" />
        <circle cx="40" cy="45" r="2.4" fill="#fff" /><circle cx="64" cy="45" r="2.4" fill="#fff" />
        <path d="M44 58 L56 58 L50 67 Z" fill="#ff8a1f" stroke="#a84a00" strokeWidth="1.5" strokeLinejoin="round" />
        <ellipse cx="29" cy="62" rx="6" ry="3.5" fill="#ff8ab4" opacity="0.6" /><ellipse cx="71" cy="62" rx="6" ry="3.5" fill="#ff8ab4" opacity="0.6" />
        <path d="M30 34 C34 28 40 26 44 26" stroke="#fff" strokeWidth="4" opacity="0.6" strokeLinecap="round" fill="none" />
      </g>
    </g>
  ),
  // Goldene Glocke
  bell: (
    <g className="symBody">
      <g className="symSwing">
        <path d="M44 10 Q50 4 56 10" stroke="#7a4300" strokeWidth="4" fill="none" strokeLinecap="round" />
        <path d="M50 12 C30 14 26 34 26 52 C26 62 20 68 14 74 L86 74 C80 68 74 62 74 52 C74 34 70 14 50 12 Z" fill="url(#sgGold)" stroke="#7a4300" strokeWidth="3" />
        <rect x="12" y="72" width="76" height="9" rx="4.5" fill="url(#sgGoldDark)" stroke="#7a4300" strokeWidth="2.5" />
        <path d="M26 52 C40 58 60 58 74 52" stroke="#9a4dff" strokeWidth="5" fill="none" />
        <path d="M46 55 l4 -4 l4 4 l-4 4 Z" fill="#ff5ad6" stroke="#fff" strokeWidth="1" />
        <circle className="symClapper" cx="50" cy="87" r="7" fill="url(#sgGold)" stroke="#7a4300" strokeWidth="2.5" />
        <path d="M38 24 C33 34 32 44 33 54" stroke="#fff" strokeWidth="5" opacity="0.6" strokeLinecap="round" fill="none" />
      </g>
    </g>
  ),
  // Hühner-Goldmünze
  bar: (
    <g className="symBody">
      <g className="symSpinY">
        <circle cx="50" cy="50" r="40" fill="url(#sgCoin)" stroke="#7a4300" strokeWidth="3" />
        <circle cx="50" cy="50" r="31" fill="none" stroke="#a86400" strokeWidth="2.5" strokeDasharray="3 3" />
        <path d="M36 66 C30 56 34 42 46 40 C46 32 54 28 60 34 C64 30 70 34 66 38 C70 44 68 50 64 52 C66 60 60 68 50 68 Z" fill="#b86c00" opacity="0.85" />
        <path d="M58 36 l6 -2 l-3 5 Z" fill="#b86c00" />
        <circle cx="58" cy="40" r="1.8" fill="#ffe8a0" />
        <path d="M24 38 C28 28 36 22 44 20" stroke="#fff" strokeWidth="4" opacity="0.7" strokeLinecap="round" fill="none" />
      </g>
    </g>
  ),
  // Lucky 7
  seven: (
    <g className="symBody">
      <text x="50" y="86" textAnchor="middle" fontSize="88" fontWeight="900" fontStyle="italic" fontFamily="Inter, Arial" fill="url(#sgSeven)" stroke="#ffd36b" strokeWidth="4" paintOrder="stroke" className="symSevenText">7</text>
      <text x="50" y="86" textAnchor="middle" fontSize="88" fontWeight="900" fontStyle="italic" fontFamily="Inter, Arial" fill="none" stroke="#fff" strokeWidth="1" opacity="0.5">7</text>
      {sparkle(80, 22, 0.9)}
      {sparkle(20, 70, 0.6, "symTwinkle late")}
    </g>
  ),
  // Königsvogel (Wild)
  wild: (
    <g className="symBody">
      <g className="symHop">
        <path className="symWingL" d="M22 58 C6 50 4 70 18 78 C24 80 28 74 30 68 Z" fill="url(#sgPurple)" stroke="#3a0a70" strokeWidth="2" />
        <path className="symWingR" d="M78 58 C94 50 96 70 82 78 C76 80 72 74 70 68 Z" fill="url(#sgPurple)" stroke="#3a0a70" strokeWidth="2" />
        <ellipse cx="50" cy="60" rx="30" ry="28" fill="url(#sgPurple)" stroke="#3a0a70" strokeWidth="2.5" />
        <ellipse cx="50" cy="70" rx="17" ry="15" fill="url(#sgBelly)" />
        <ellipse cx="39" cy="54" rx="6.5" ry="8" fill="#1a0630" /><ellipse cx="61" cy="54" rx="6.5" ry="8" fill="#1a0630" />
        <circle cx="41" cy="51" r="2.6" fill="#fff" /><circle cx="63" cy="51" r="2.6" fill="#fff" />
        <circle cx="37.5" cy="57" r="1.2" fill="#fff" /><circle cx="59.5" cy="57" r="1.2" fill="#fff" />
        <path d="M45 62 L55 62 L50 69 Z" fill="#ffad1f" stroke="#a85a00" strokeWidth="1.5" strokeLinejoin="round" />
        <g transform="translate(0 6)">{crown}</g>
      </g>
      <g className="symRibbon">
        <path d="M10 82 L90 82 L86 98 L14 98 Z" fill="#ff3fb4" stroke="#fff3c4" strokeWidth="2" />
        <text x="50" y="95" textAnchor="middle" fontSize="13" fontWeight="900" fontFamily="Inter, Arial" fill="#fff" letterSpacing="3">WILD</text>
      </g>
    </g>
  ),
  // Goldenes Ei (Bonus)
  egg: (
    <g className="symBody">
      <g className="symWobble">
        <path d="M50 8 C28 8 17 46 17 60 C17 80 32 93 50 93 C68 93 83 80 83 60 C83 46 72 8 50 8 Z" fill="url(#sgEgg)" stroke="#8a5200" strokeWidth="3" />
        <path className="symCrack" d="M24 56 L34 50 L40 58 L50 48 L58 58 L66 50 L76 56" stroke="#7a3a00" strokeWidth="2.5" fill="none" strokeLinejoin="round" />
        <path d="M34 22 C28 32 26 44 26 52" stroke="#fff" strokeWidth="6" opacity="0.75" strokeLinecap="round" fill="none" />
        <rect x="24" y="64" width="52" height="14" rx="7" fill="#7a2ae0" stroke="#fff3c4" strokeWidth="1.5" />
        <text x="50" y="75" textAnchor="middle" fontSize="10.5" fontWeight="900" fontFamily="Inter, Arial" fill="#fff" letterSpacing="1.5">BONUS</text>
      </g>
      {sparkle(80, 16, 1)}
      {sparkle(16, 30, 0.6, "symTwinkle late")}
    </g>
  ),
};

export const SYMBOL_NAMES = { cherry: "Maiskolben", lemon: "Feder", grape: "Küken", bell: "Glocke", bar: "Hühner-Münze", seven: "Lucky 7", wild: "Königsvogel (Wild)", egg: "Goldenes Ei" };
export const ALL_SYMBOLS = Object.keys(ART);

export function SlotSymbol({ name, className = "" }) {
  return <svg className={`slSym sym-${name} ${className}`} viewBox="0 0 100 100" aria-label={SYMBOL_NAMES[name]} role="img">{defs}{ART[name]}</svg>;
}
