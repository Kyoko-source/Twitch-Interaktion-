import React from "react";

// Hand-drawn vector portraits for the bestiary. Every portrait lives in a
// 100×100 box, bottom-anchored like a bust; glowing parts carry the
// `mEye` class so CSS can make them flicker. The coloured backdrop comes
// from the wrapper (.monsterArt, --tok) so the SVGs need no gradients.

const Eye = ({ x, y, r = 3.4, c = "#ffd23a", slit }) => <>
  <circle className="mEye" cx={x} cy={y} r={r} fill={c} />
  {slit ? <rect x={x - .7} y={y - r + .6} width="1.4" height={r * 2 - 1.2} rx=".7" fill="#120806" /> : null}
</>;

const ART = {
  rat: <>
    <path d="M14 100c4-22 18-32 36-32s32 10 36 32Z" fill="#6e5546" />
    <circle cx="27" cy="36" r="13" fill="#7c6152" /><circle cx="27" cy="36" r="8" fill="#d58f8f" />
    <circle cx="73" cy="36" r="13" fill="#7c6152" /><circle cx="73" cy="36" r="8" fill="#d58f8f" />
    <path d="M30 50c0-14 9-22 20-22s20 8 20 22c0 10-8 24-20 30-12-6-20-20-20-30Z" fill="#8f7262" />
    <path d="M42 62c2-4 14-4 16 0l-3 14c-3 3-7 3-10 0Z" fill="#a98b7a" />
    <circle cx="50" cy="77" r="3.2" fill="#e88a9a" />
    <path d="M47 80h6v7h-6Z" fill="#fff4d6" /><path d="M50 80v7" stroke="#b9a37c" strokeWidth=".8" />
    <path d="M44 76 22 70M44 78 20 80M56 76l22-6M56 78l24 2" stroke="#e8dccf" strokeWidth=".9" opacity=".7" />
    <Eye x={41} y={52} r={3.6} c="#ff3b3b" /><Eye x={59} y={52} r={3.6} c="#ff3b3b" />
  </>,
  kobold: <>
    <path d="M20 100c3-20 15-28 30-28s27 8 30 28Z" fill="#7a3f22" />
    <path d="M38 80h24l-4 20H42Z" fill="#c9a173" opacity=".55" />
    <path d="M36 32 26 10l14 16ZM64 32l10-22-14 16Z" fill="#efdcae" />
    <path d="M30 50c0-16 9-24 20-24s20 8 20 24c0 12-8 20-20 22-12-2-20-10-20-22Z" fill="#c8662f" />
    <path d="M38 42c4-3 8-3 10 0M52 42c2-3 6-3 10 0" stroke="#7a3315" strokeWidth="2.2" fill="none" strokeLinecap="round" />
    <ellipse cx="50" cy="61" rx="13" ry="9" fill="#d97f43" />
    <circle cx="45" cy="57" r="1.3" fill="#3a1608" /><circle cx="55" cy="57" r="1.3" fill="#3a1608" />
    <path d="M39 65q11 6 22 0" stroke="#3a1608" strokeWidth="1.6" fill="none" />
    <path d="M42 66l1.5 3 1.5-2.5M55 66.5l1.5 2.5 1.5-3" fill="#fff" />
    <Eye x={41} y={47} r={4} slit /><Eye x={59} y={47} r={4} slit />
  </>,
  cultist: <>
    <path d="M12 100c2-26 16-44 38-44s36 18 38 44Z" fill="#5a0f1c" />
    <path d="M26 100c2-18 10-30 24-30s22 12 24 30Z" fill="#7d1626" />
    <path d="M24 66C22 34 34 16 50 14c16 2 28 20 26 52-6 6-16 9-26 9s-20-3-26-9Z" fill="#8f1b2d" />
    <path d="M32 64c0-22 8-36 18-36s18 14 18 36c-5 4-11 6-18 6s-13-2-18-6Z" fill="#14070b" />
    <path d="M38 58q12 6 24 0" stroke="#2c0e15" strokeWidth="2" fill="none" />
    <circle cx="50" cy="86" r="7" fill="none" stroke="#ffc65a" strokeWidth="1.8" />
    <path d="M50 80v12M45 84l10 4M55 84l-10 4" stroke="#ffc65a" strokeWidth="1.3" />
    <Eye x={43} y={48} r={2.6} c="#ff5a2f" /><Eye x={57} y={48} r={2.6} c="#ff5a2f" />
  </>,
  bandit: <>
    <path d="M14 100c3-22 18-32 36-32s33 10 36 32Z" fill="#4b3a2a" />
    <path d="M70 70 92 46l3 3-20 26Z" fill="#c8ccd6" /><path d="M71 73l-4-4 6-3 3 4Z" fill="#6b4a2a" />
    <path d="M26 58c-2-26 10-40 24-40s26 14 24 40Z" fill="#3a2a1d" />
    <path d="M33 54c0-16 7-26 17-26s17 10 17 26Z" fill="#d6a47c" />
    <path d="M32 54h36c0 12-6 22-18 24-12-2-18-12-18-24Z" fill="#8e2f24" />
    <path d="M34 60h32M35 66h30" stroke="#6e2219" strokeWidth="1" />
    <path d="M37 41q5-3 10 0M53 41q5-3 10 0" stroke="#3b2414" strokeWidth="2" fill="none" />
    <ellipse cx="42" cy="47" rx="3.6" ry="2.6" fill="#fff" /><ellipse cx="58" cy="47" rx="3.6" ry="2.6" fill="#fff" />
    <circle cx="42.6" cy="47" r="1.7" fill="#2a1a10" /><circle cx="58.6" cy="47" r="1.7" fill="#2a1a10" />
  </>,
  goblin: <>
    <path d="M20 100c3-20 15-28 30-28s27 8 30 28Z" fill="#5a4128" />
    <path d="M34 46 4 30l26 26ZM66 46l30-16-26 26Z" fill="#69b048" /><path d="M32 47 14 37l16 15ZM68 47l18-10-16 15Z" fill="#a85a5a" opacity=".6" />
    <path d="M30 48c0-16 9-26 20-26s20 10 20 26c0 16-8 26-20 26S30 64 30 48Z" fill="#7bd35a" />
    <path d="M37 40l10 4M63 40l-10 4" stroke="#2b4a1a" strokeWidth="2.6" strokeLinecap="round" />
    <path d="M50 44c-5 6-6 14 0 16 6-2 5-10 0-16Z" fill="#5fae40" />
    <path d="M37 63q13 10 26 0-13 4-26 0Z" fill="#2a160e" />
    <path d="M40 64l2 3 2-2.4 2 2.6 2-2.6 2 2.6 2-2.6 2 2.6 2-2.4 2 2.2 1-2.6" stroke="#fff6d8" strokeWidth="1.2" fill="none" />
    <Eye x={41} y={49} r={3.6} c="#ffcf3a" /><Eye x={59} y={49} r={3.6} c="#ffcf3a" />
  </>,
  wolf: <>
    <path d="M10 100c6-18 22-26 40-26s34 8 40 26Z" fill="#6e7586" />
    <path d="M50 86c-11 0-18-9-22-20-6-11-7-23-3-31l-6-25 19 16c5-2 19-2 24 0l19-16-6 25c4 8 3 20-3 31-4 11-11 20-22 20Z" fill="#8c94a6" />
    <path d="M24 12l12 14-6 4ZM76 12 64 26l6 4Z" fill="#4a3a44" />
    <path d="M38 58c2-7 22-7 24 0l-2 16c-2 8-18 8-20 0Z" fill="#cdd2dc" />
    <ellipse cx="50" cy="61" rx="6.5" ry="4.2" fill="#15151c" />
    <path d="M44 74q6 4 12 0" stroke="#3a2a30" strokeWidth="1.6" fill="none" />
    <path d="M28 40l14 4-10 6Z M72 40l-14 4 10 6Z" fill="#1b1b22" />
    <Eye x={37} y={45} r={2.6} c="#ffd23a" /><Eye x={63} y={45} r={2.6} c="#ffd23a" />
  </>,
  skeleton: <>
    <path d="M50 70v30" stroke="#d8d1bb" strokeWidth="4" />
    {[76, 83, 90, 97].map((y) => <path key={y} d={`M50 ${y}c-10-3-18 0-24 6M50 ${y}c10-3 18 0 24 6`} stroke="#d8d1bb" strokeWidth="3" fill="none" strokeLinecap="round" />)}
    <path d="M30 42c0-18 10-26 20-26s20 8 20 26c0 8-4 12-6 14v9H36v-9c-2-2-6-6-6-14Z" fill="#ece6d3" />
    <path d="M38 65h24l-2 9H40Z" fill="#ddd5bf" />
    <path d="M42 65v9M46 65v9M50 65v9M54 65v9M58 65v9" stroke="#8a826e" strokeWidth=".9" />
    <ellipse cx="41" cy="44" rx="6.5" ry="7.5" fill="#171320" /><ellipse cx="59" cy="44" rx="6.5" ry="7.5" fill="#171320" />
    <path d="M50 52l-3.5 6h7Z" fill="#171320" />
    <path d="M60 22l-4 8 3 4" stroke="#b5ad96" strokeWidth="1" fill="none" />
    <Eye x={41} y={45} r={2} c="#7ad0ff" /><Eye x={59} y={45} r={2} c="#7ad0ff" />
  </>,
  zombie: <>
    <path d="M16 100c3-22 18-30 34-30s31 8 34 30Z" fill="#4c5a6c" />
    <path d="M30 76l6 10 4-8 6 12 6-12 4 8 6-10" stroke="#2c3644" strokeWidth="2" fill="none" />
    <path d="M30 46c0-18 9-26 20-26s21 8 21 26c0 16-8 28-20 28-13 0-21-12-21-28Z" fill="#8ba774" />
    <path d="M34 28c4-8 10-10 12-6 4-6 10-5 12 0 4-2 8 2 8 6" stroke="#2a2a1c" strokeWidth="3" fill="none" strokeLinecap="round" />
    <path d="M56 30v14M53 34h6M53 39h6" stroke="#3c4a2c" strokeWidth="1.2" />
    <ellipse cx="41" cy="46" rx="6" ry="5.5" fill="#2e3622" /><ellipse cx="60" cy="47" rx="4" ry="3.6" fill="#2e3622" />
    <path d="M38 62c4 6 16 8 24 1l-2 6c-6 4-14 4-20 0Z" fill="#3a1616" />
    <path d="M42 63v3M48 64v3M54 64v3" stroke="#e4dcb8" strokeWidth="1.4" />
    <Eye x={41} y={46} r={2.6} c="#e8f27a" /><Eye x={60} y={47} r={1.8} c="#e8f27a" />
  </>,
  orc: <>
    <path d="M12 100c4-22 18-30 38-30s34 8 38 30Z" fill="#4a3a2a" />
    <path d="M18 84c4-6 12-8 18-6l-4 12ZM82 84c-4-6-12-8-18-6l4 12Z" fill="#8a8f9a" />
    <path d="M44 22c0-8 12-8 12 0l-2 6h-8Z" fill="#1c1410" />
    <path d="M28 50c0-16 10-26 22-26s22 10 22 26c0 16-10 26-22 26S28 66 28 50Z" fill="#6fae4f" />
    <path d="M30 42c6-4 14-4 18 0M70 42c-6-4-14-4-18 0" stroke="#2d4a1e" strokeWidth="4" strokeLinecap="round" />
    <path d="M44 50c-2 5 0 9 6 9s8-4 6-9" fill="#5a9440" />
    <path d="M36 64q14 6 28 0l-2 6q-12 5-24 0Z" fill="#2a160e" />
    <path d="M38 66l3-10 3 10ZM56 66l3-10 3 10Z" fill="#f4ead0" />
    <path d="M60 30l6 14" stroke="#3d6a2a" strokeWidth="1.4" />
    <Eye x={40} y={47} r={2.8} c="#ff4f2f" /><Eye x={60} y={47} r={2.8} c="#ff4f2f" />
  </>,
  ghoul: <>
    <path d="M18 100c3-20 16-28 32-28s29 8 32 28Z" fill="#4e5444" />
    <path d="M44 74v26M56 74v26M38 82l24 0M38 90h24" stroke="#38402f" strokeWidth="1.4" />
    <path d="M32 46 8 26l26 30ZM68 46l24-20-26 30Z" fill="#8f9a78" />
    <path d="M32 46c0-18 8-26 18-26s18 8 18 26c0 18-8 30-18 30S32 64 32 46Z" fill="#a3b08a" />
    <path d="M36 54c4 4 4 10 0 14M64 54c-4 4-4 10 0 14" stroke="#77825e" strokeWidth="1.6" fill="none" />
    <path d="M40 60h20c0 6-4 12-10 12s-10-6-10-12Z" fill="#2a0f12" />
    <path d="M41 60l2 4 2-4 2 4 2-4 2 4 2-4 2 4 2-4 2 4" stroke="#f0ead0" strokeWidth="1.1" fill="none" />
    <path d="M50 66c2 8-2 14 2 20" stroke="#b5465a" strokeWidth="3" fill="none" strokeLinecap="round" />
    <ellipse cx="42" cy="44" rx="5" ry="6" fill="#1e2218" /><ellipse cx="58" cy="44" rx="5" ry="6" fill="#1e2218" />
    <Eye x={42} y={44} r={2.4} c="#f4fff0" /><Eye x={58} y={44} r={2.4} c="#f4fff0" />
  </>,
  harpy: <>
    <path d="M50 64C30 40 10 44 2 60c10-2 14 2 16 8-8 0-10 6-10 10 10-6 18-2 22 4ZM50 64c20-24 40-20 48-4-10-2-14 2-16 8 8 0 10 6 10 10-10-6-18-2-22 4Z" fill="#7a4a8a" />
    <path d="M30 100c2-16 10-26 20-26s18 10 20 26Z" fill="#9a6aa8" />
    <path d="M34 50c-6-14 2-34 16-34s22 20 16 34c4 8 6 16 2 22-6-10-10-6-18-6s-12-4-18 6c-4-6-2-14 2-22Z" fill="#3a1f4a" />
    <path d="M38 48c0-12 5-18 12-18s12 6 12 18c0 10-5 18-12 18s-12-8-12-18Z" fill="#e6c2b0" />
    <path d="M44 58q6 4 12 0" stroke="#7a2a3a" strokeWidth="1.6" fill="none" />
    <path d="M40 40l6 3M60 40l-6 3" stroke="#3a1f4a" strokeWidth="1.6" />
    <Eye x={44.5} y={46} r={2.2} c="#ffb84f" /><Eye x={55.5} y={46} r={2.2} c="#ffb84f" />
  </>,
  spider: <>
    {["M40 60Q18 42 0 54", "M38 64Q14 58 -4 74", "M38 68Q16 74 2 94", "M40 72Q26 82 18 100",
      "M60 60Q82 42 100 54", "M62 64Q86 58 104 74", "M62 68Q84 74 98 94", "M60 72Q74 82 82 100"].map((d) => <path key={d} d={d} stroke="#2e2440" strokeWidth="4.2" fill="none" strokeLinecap="round" />)}
    <ellipse cx="50" cy="36" rx="26" ry="22" fill="#3b2f4f" />
    <path d="M50 22l-6 8 6 6 6-6Zm0 18-5 6 5 5 5-5Z" fill="#c23a4a" />
    <ellipse cx="50" cy="66" rx="16" ry="13" fill="#4a3c5e" />
    <path d="M42 76q-2 8 3 10l2-8ZM58 76q2 8-3 10l-2-8Z" fill="#d8cfe6" />
    {[[44, 60, 3], [56, 60, 3], [40, 64, 2], [60, 64, 2], [46, 55, 1.6], [54, 55, 1.6], [37, 59, 1.4], [63, 59, 1.4]].map(([x, y, r]) => <Eye key={`${x}-${y}`} x={x} y={y} r={r} c="#ff3b3b" />)}
  </>,
  cube: <>
    <path d="M18 34 50 18l32 16v40L50 92 18 74Z" fill="#4fe0c0" opacity=".28" />
    <path d="M18 34 50 50l32-16M50 50v42" stroke="#9ffbe6" strokeWidth="1.4" fill="none" opacity=".8" />
    <path d="M18 34 50 18l32 16v40L50 92 18 74Z" stroke="#c8fff2" strokeWidth="1.8" fill="none" />
    <circle cx="42" cy="54" r="7" fill="#e6e0cc" opacity=".75" /><circle cx="39.5" cy="53" r="1.8" fill="#2a3a36" /><circle cx="44.5" cy="53" r="1.8" fill="#2a3a36" />
    <path d="M58 40l10 28" stroke="#c8ccd6" strokeWidth="2.4" opacity=".75" /><path d="M55 46l7-3" stroke="#a87a3a" strokeWidth="2" opacity=".75" />
    <circle cx="30" cy="66" r="3" fill="#ffc65a" opacity=".8" /><circle cx="36" cy="72" r="2.4" fill="#ffc65a" opacity=".8" />
    <circle className="mEye" cx="62" cy="76" r="2" fill="#dcfff6" /><circle className="mEye" cx="28" cy="44" r="1.4" fill="#dcfff6" />
  </>,
  ogre: <>
    <path d="M6 100c4-26 22-36 44-36s40 10 44 36Z" fill="#7a5a3a" />
    <path d="M26 74c6 4 14 6 24 6s18-2 24-6" stroke="#5a3f24" strokeWidth="3" fill="none" />
    <circle cx="22" cy="48" r="7" fill="#b07a4c" /><circle cx="78" cy="48" r="7" fill="#b07a4c" />
    <path d="M24 46c0-20 12-30 26-30s26 10 26 30c0 18-10 30-26 30S24 64 24 46Z" fill="#c08a5a" />
    <path d="M40 18c2-4 6-4 6 0M52 17c2-4 6-4 6 0" stroke="#3a2614" strokeWidth="1.4" fill="none" />
    <path d="M34 36h12M54 36h12" stroke="#5a3a22" strokeWidth="3.4" strokeLinecap="round" />
    <path d="M44 42c-6 8-4 14 6 14s12-6 6-14Z" fill="#a8744a" />
    <path d="M34 62q16 10 32 0v4q-16 8-32 0Z" fill="#3a1a10" />
    <path d="M37 64l2-6 2 6ZM59 64l2-6 2 6Z" fill="#f4ead0" />
    <Eye x={40} y={42} r={2} c="#ffe08a" /><Eye x={60} y={42} r={2} c="#ffe08a" />
  </>,
  mimic: <>
    <path d="M16 62h68v30H16Z" fill="#7a4a22" />
    <path d="M16 70h68M16 84h68" stroke="#4a2a12" strokeWidth="1.4" />
    <path d="M16 62h68v6H16Z" fill="#c69a4a" /><path d="M24 62v30M76 62v30" stroke="#c69a4a" strokeWidth="4" />
    <path d="M14 40 50 16l36 24-4 22H18Z" fill="#8a5428" /><path d="M14 40 50 16l36 24" stroke="#c69a4a" strokeWidth="3" fill="none" />
    <path d="M18 62h64L76 50H24Z" fill="#3a0a14" />
    <path d="M20 62l4-8 4 8 4-8 4 8 4-8 4 8 4-8 4 8 4-8 4 8 4-8 4 8 4-8 4 8" fill="#fff6dc" />
    <path d="M24 50l4 7 4-7 4 7 4-7 4 7 4-7 4 7 4-7 4 7 4-7 4 7 4-7" fill="#fff6dc" />
    <path d="M58 62c8 4 16 10 14 22-2 6-8 6-10 2" stroke="#e45a8a" strokeWidth="6" fill="none" strokeLinecap="round" />
    <path d="M46 70h8v8h-8Z" fill="#c69a4a" />
    <ellipse cx="50" cy="32" rx="7" ry="5" fill="#fff4c8" /><Eye x={50} y={32} r={3} c="#ff8a1a" slit />
  </>,
  owlbear: <>
    <path d="M8 100c4-26 20-38 42-38s38 12 42 38Z" fill="#6b4a32" />
    <circle cx="22" cy="24" r="9" fill="#6b4a32" /><circle cx="78" cy="24" r="9" fill="#6b4a32" /><circle cx="22" cy="24" r="4.5" fill="#3a2618" /><circle cx="78" cy="24" r="4.5" fill="#3a2618" />
    <path d="M18 48c0-20 14-30 32-30s32 10 32 30c0 22-14 34-32 34S18 70 18 48Z" fill="#8b6a4a" />
    <ellipse cx="38" cy="46" rx="13" ry="14" fill="#d8c4a0" /><ellipse cx="62" cy="46" rx="13" ry="14" fill="#d8c4a0" />
    <path d="M26 32l24 12 24-12" stroke="#4a3220" strokeWidth="3.4" fill="none" strokeLinecap="round" />
    <path d="M44 54h12l-6 16Z" fill="#f2c24a" /><path d="M50 70l-3-6h6Z" fill="#a8761a" />
    <circle cx="38" cy="46" r="7" fill="#ff9a2a" className="mEye" /><circle cx="62" cy="46" r="7" fill="#ff9a2a" className="mEye" />
    <circle cx="38" cy="46" r="3.4" fill="#120806" /><circle cx="62" cy="46" r="3.4" fill="#120806" />
    <path d="M30 86l4-8 4 8M62 86l4-8 4 8" stroke="#3a2618" strokeWidth="1.6" fill="none" />
  </>,
  minotaur: <>
    <path d="M8 100c4-24 20-34 42-34s38 10 42 34Z" fill="#5a3422" />
    <path d="M30 32C18 30 8 22 6 8c8 8 16 12 26 12ZM70 32c12-2 22-10 24-24-8 8-16 12-26 12Z" fill="#efe2c2" />
    <path d="M26 30 14 26l8 10ZM74 30l12-4-8 10Z" fill="#7a4a30" />
    <path d="M30 40c0-14 8-22 20-22s20 8 20 22c0 6-2 10-2 14l4 12c-4 10-12 14-22 14S32 76 28 66l4-12c0-4-2-8-2-14Z" fill="#8a5232" />
    <path d="M38 58c0-6 24-6 24 0v12c0 6-24 6-24 0Z" fill="#b07a5a" />
    <ellipse cx="44" cy="64" rx="2.4" ry="3" fill="#2a120a" /><ellipse cx="56" cy="64" rx="2.4" ry="3" fill="#2a120a" />
    <circle cx="50" cy="74" r="5" fill="none" stroke="#ffc65a" strokeWidth="2" />
    <path d="M36 40l10 4M64 40l-10 4" stroke="#2a120a" strokeWidth="2.4" strokeLinecap="round" />
    <Eye x={41} y={47} r={2.8} c="#ff3b2f" /><Eye x={59} y={47} r={2.8} c="#ff3b2f" />
  </>,
  troll: <>
    <path d="M14 100c4-20 18-30 36-30s32 10 36 30Z" fill="#3a5a3a" />
    <path d="M30 46 6 54l26 4ZM70 46l24 8-26 4Z" fill="#4f8a5a" />
    <path d="M30 38c0-16 8-26 20-26s20 10 20 26c0 20-8 38-20 38S30 58 30 38Z" fill="#5a9a64" />
    <path d="M28 30c0-14 10-22 22-22s22 8 22 22c-4-8-10-10-14-6-2-6-10-6-14 0-4-4-12-2-16 6Z" fill="#1e2a20" />
    <path d="M48 40c-2 10-6 22 2 30 4 2 6-4 4-10-2-6-2-14-2-20Z" fill="#4a8452" />
    <circle cx="38" cy="58" r="2" fill="#3f7646" /><circle cx="62" cy="54" r="2.4" fill="#3f7646" /><circle cx="60" cy="64" r="1.6" fill="#3f7646" />
    <path d="M38 70q12 6 24 0" stroke="#1e2a20" strokeWidth="2.4" fill="none" />
    <path d="M40 71l2 5 2-4M56 71l2 4 2-5" fill="#f0e6c0" />
    <Eye x={41} y={40} r={2.6} c="#ffe04f" /><Eye x={59} y={40} r={2.6} c="#ffe04f" />
  </>,
  dragon: <>
    <path d="M30 100c2-16 8-26 20-30 12 4 18 14 20 30Z" fill="#9a2418" />
    <path d="M40 76h20M42 84h16M44 92h12" stroke="#e8a060" strokeWidth="2" />
    <path d="M32 34C24 22 22 10 26 2c2 10 8 18 16 22ZM68 34c8-12 10-24 6-32-2 10-8 18-16 22Z" fill="#3a1a12" />
    <path d="M28 46 10 40l14 12ZM72 46l18-6-14 12Z" fill="#c23420" />
    <path d="M30 44c0-14 8-22 20-22s20 8 20 22c0 6-2 10-4 14 2 4 2 10 0 14-4 6-10 8-16 8s-12-2-16-8c-2-4-2-10 0-14-2-4-4-8-4-14Z" fill="#e2442f" />
    <path d="M36 66c4 6 24 6 28 0" stroke="#7a1a10" strokeWidth="2" fill="none" />
    <path d="M38 67l2 4 2-4M58 67l2 4 2-4" fill="#fff6dc" />
    <ellipse cx="44" cy="60" rx="2" ry="1.4" fill="#3a0a06" /><ellipse cx="56" cy="60" rx="2" ry="1.4" fill="#3a0a06" />
    <path d="M34 38l12 6M66 38l-12 6" stroke="#7a1a10" strokeWidth="3" strokeLinecap="round" />
    <path className="mFlame" d="M44 58c-6-4-10-10-6-16 0 6 4 8 6 8M56 58c6-4 10-10 6-16 0 6-4 8-6 8" stroke="#ffd2a0" strokeWidth="1.2" fill="none" opacity=".6" />
    <Eye x={40} y={47} r={3.4} c="#ffb21a" slit /><Eye x={60} y={47} r={3.4} c="#ffb21a" slit />
  </>,
  "dragon-elder": <>
    <path className="mFlame" d="M50 96c-18-4-30-16-26-32 4 8 10 10 14 8-6-10-2-22 8-28-2 10 2 16 4 18 2-2 6-8 4-18 10 6 14 18 8 28 4 2 10 0 14-8 4 16-8 28-26 32Z" fill="#ff7a1a" opacity=".55" />
    <path d="M30 100c2-14 8-22 20-26 12 4 18 12 20 26Z" fill="#8a1a10" />
    <path d="M30 32C18 22 14 8 18 0c4 10 10 16 18 20ZM70 32c12-10 16-24 12-32-4 10-10 16-18 20Z" fill="#2a120c" />
    <path d="M28 40C16 36 8 30 4 22c8 4 16 6 26 6ZM72 40c12-4 20-10 24-18-8 4-16 6-26 6Z" fill="#3a1a12" />
    <path d="M26 46 6 42l16 12ZM74 46l20-4-16 12Z" fill="#c23420" />
    <path d="M30 42c0-14 8-22 20-22s20 8 20 22c0 6-2 10-4 14 2 4 2 10 0 14-4 6-10 8-16 8s-12-2-16-8c-2-4-2-10 0-14-2-4-4-8-4-14Z" fill="#ff3b2f" />
    <path d="M38 24l4 6 4-6 4 6 4-6 4 6 4-6" stroke="#2a120c" strokeWidth="2" fill="none" />
    <path d="M36 64c4 8 24 8 28 0" stroke="#6a1008" strokeWidth="2.2" fill="none" />
    <path d="M38 65l2 5 2-5M47 66l2 4 2-4M58 65l2 5 2-5" fill="#fff6dc" />
    <path d="M34 36l12 6M66 36l-12 6" stroke="#6a1008" strokeWidth="3.2" strokeLinecap="round" />
    <Eye x={40} y={45} r={3.6} c="#ffe04f" slit /><Eye x={60} y={45} r={3.6} c="#ffe04f" slit />
  </>,
  vampire: <>
    <path d="M6 100 20 54c10 8 18 12 30 12s20-4 30-12l14 46Z" fill="#14060c" />
    <path d="M20 54 30 100h-8ZM80 54 70 100h8Z" fill="#a0142a" />
    <path d="M38 74h24l-4 26H42Z" fill="#e8e2ee" /><path d="M46 74l4 8 4-8" fill="#a0142a" />
    <path d="M34 42c0-16 7-24 16-24s16 8 16 24c0 16-7 30-16 30S34 58 34 42Z" fill="#e6e2ee" />
    <path d="M32 40c0-18 8-26 18-26s18 8 18 26c-2-8-6-14-12-14l-6 8-6-8c-6 0-10 6-12 14Z" fill="#120a14" />
    <path d="M38 40l9 3M62 40l-9 3" stroke="#120a14" strokeWidth="1.8" />
    <path d="M42 60q8 4 16 0" stroke="#8a1a2a" strokeWidth="1.6" fill="none" />
    <path d="M45 60.5l1.4 4.5 1.4-4M52.2 61l1.4 4 1.4-4.5" fill="#fff" />
    <Eye x={44} y={47} r={2.4} c="#ff1a3a" /><Eye x={56} y={47} r={2.4} c="#ff1a3a" />
  </>,
  lich: <>
    <path d="M10 100c2-28 16-46 40-46s38 18 40 46Z" fill="#1a1440" />
    <path d="M24 100c2-18 10-28 26-28s24 10 26 28Z" fill="#2a2060" />
    <path d="M22 62C20 32 32 16 50 14c18 2 30 18 28 48-6 6-16 10-28 10s-22-4-28-10Z" fill="#241a52" />
    <path d="M34 50c0-14 7-22 16-22s16 8 16 22c0 6-2 9-4 11v6H38v-6c-2-2-4-5-4-11Z" fill="#d8d6c4" />
    <path d="M40 67h20l-2 6H42Z" fill="#c4c2ae" />
    <ellipse cx="43" cy="50" rx="4.6" ry="5.4" fill="#0a0818" /><ellipse cx="57" cy="50" rx="4.6" ry="5.4" fill="#0a0818" />
    <path d="M36 28l4-12 5 8 5-12 5 12 5-8 4 12Z" fill="#ffc65a" />
    <circle cx="50" cy="20" r="2.2" fill="#ff4fd8" className="mEye" />
    <path d="M50 80l-6 8 6 8 6-8Z" fill="#3ee8ff" className="mEye" />
    <Eye x={43} y={50} r={2.2} c="#7ad0ff" /><Eye x={57} y={50} r={2.2} c="#7ad0ff" />
  </>,
  shadow: <>
    <path className="mWisp" d="M14 100c2-24 10-36 20-40-8-10-8-26 2-36 6-6 22-8 30 0 10 10 10 26 2 36 10 4 18 16 20 40-6-6-10-4-14 2-4-6-10-6-14 0-4-6-10-6-14 0-4-6-8-8-18-2-4-6-10-6-14 0Z" fill="#100a1c" />
    <path d="M30 60c4 4 10 6 20 6s16-2 20-6" stroke="var(--tok)" strokeWidth="1.2" fill="none" opacity=".5" />
    <Eye x={42} y={42} r={3} c="var(--tok)" /><Eye x={58} y={42} r={3} c="var(--tok)" />
  </>,
  demon: <>
    <path d="M6 100c4-24 20-34 44-34s40 10 44 34Z" fill="#3a0c14" />
    <path d="M50 66C30 46 8 46 0 30c14 4 20 2 26-6 2 10 10 18 24 22ZM50 66c20-20 42-20 50-36-14 4-20 2-26-6-2 10-10 18-24 22Z" fill="#5a1220" />
    <path d="M32 34C26 20 30 8 38 2c-2 10 0 18 6 24ZM68 34c6-14 2-26-6-32 2 10 0 18-6 24Z" fill="#2a1410" />
    <path d="M30 46c0-16 9-24 20-24s20 8 20 24c0 16-8 28-20 28S30 62 30 46Z" fill="#b8243a" />
    <path d="M36 40l10 5M64 40l-10 5" stroke="#3a0a10" strokeWidth="3" strokeLinecap="round" />
    <path d="M38 60q12 10 24 0-12 4-24 0Z" fill="#1a0408" /><path d="M41 61l2 5 2-4M55 62l2 4 2-5" fill="#fff" />
    <Eye x={41} y={48} r={3} c="#ffc65a" slit /><Eye x={59} y={48} r={3} c="#ffc65a" slit />
  </>,
  elemental: <>
    <path className="mFlame" d="M50 98c-24 0-36-16-30-38 4 10 10 12 12 10-6-14 0-32 14-42-2 12 2 20 6 22 2-8 8-14 14-16-4 12 2 22 6 28 2-4 2-8 0-12 10 10 12 30 2 40-6 6-14 8-24 8Z" fill="#ff7a1a" />
    <path className="mFlame" d="M50 96c-14 0-22-10-18-24 4 6 8 6 10 4-2-10 2-18 8-24 0 8 4 12 8 14 4-4 6-8 6-12 6 10 6 22 0 30-4 6-8 12-14 12Z" fill="#ffd23a" />
    <Eye x={43} y={66} r={2.6} c="#fff" /><Eye x={57} y={66} r={2.6} c="#fff" />
  </>,
};

export const hasArt = (key) => Boolean(key && ART[key]);

export function MonsterArt({ art, image, name = "", color = "#ff4f6d", className = "", size, style: extra }) {
  const style = { "--tok": color, ...(size ? { width: size, height: size } : null), ...extra };
  if (image) return <span className={`monsterArt hasImage ${className}`} style={style}><img src={image} alt="" draggable="false" loading="lazy" /></span>;
  if (!hasArt(art)) {
    const initials = String(name || "?").split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();
    return <span className={`monsterArt isPlain ${className}`} style={style}><b>{initials}</b></span>;
  }
  return <span className={`monsterArt art-${art} ${className}`} style={style}>
    <svg viewBox="0 0 100 100" aria-hidden="true" focusable="false">{ART[art]}</svg>
  </span>;
}
