import React from "react";

// Two original club girls drawn as layered SVG (adult proportions, glossy latex clubwear).
// Moods: idle, cheer, hype, sad, shock, wink. Mimi: DJ with pink twin tails and headphones.
// Luna: cyan bob with cat ears and a glowstick.
export const CREW = {
  mimi: { name: "Mimi", hair: ["#ff9ad5", "#ff4fae", "#c2186f"], iris: ["#5a0e4a", "#d0388f", "#ffb3e2"], latex: ["#3a1240", "#120414"], trim: "#ff3fb4", top: "#ff6fc4" },
  luna: { name: "Luna", hair: ["#9ff4ff", "#3fd0f5", "#1478b8"], iris: ["#0b2a6e", "#1fa6e0", "#b4f7ff"], latex: ["#141a3a", "#05060f"], trim: "#3fe7ff", top: "#7b5cff" },
};

const SKIN = ["#fff1e9", "#ffd9c7", "#f4b79f"];
const LINE = "#2a0f2e";
const SHOULDER_Y = 250;
const ARMS = { idle: [10, -10], cheer: [150, -150], hype: [160, -160], sad: [3, -3], shock: [62, -62], wink: [10, -165] };

function Eye({ cx, mood, side, id }) {
  const flip = side === "r" ? -1 : 1;
  if (mood === "cheer" || (mood === "wink" && side === "r")) {
    return <path d={`M${cx - 17},${142} Q${cx},${124} ${cx + 17},${142}`} fill="none" stroke={LINE} strokeWidth="4.5" strokeLinecap="round" />;
  }
  if (mood === "shock") {
    return (
      <g>
        <ellipse cx={cx} cy={140} rx="16" ry="19" fill="#fff" stroke={LINE} strokeWidth="2.6" />
        <circle cx={cx} cy={141} r="4.2" fill={LINE} />
      </g>
    );
  }
  const look = mood === "sad" ? 3 : 0;
  return (
    <g>
      {/* sclera with a flat lid line */}
      <path d={`M${cx - 18},${134} Q${cx},${121} ${cx + 18},${132} L${cx + 16},${150} Q${cx},${161} ${cx - 16},${151} Z`} fill="#fff" />
      <ellipse cx={cx + flip * 1} cy={142 + look} rx="12.5" ry="16" fill={`url(#iris-${id})`} />
      <ellipse cx={cx + flip * 1} cy={145 + look} rx="6" ry="8.5" fill="#1a0620" />
      <ellipse cx={cx + flip * 1} cy={152 + look} rx="8" ry="3.4" fill="#ffffff" opacity="0.28" />
      {mood === "hype" ? (
        <path d="M0,-10 L2.8,-2.8 L10,0 L2.8,2.8 L0,10 L-2.8,2.8 L-10,0 L-2.8,-2.8 Z" transform={`translate(${cx + flip * 1},${142 + look})`} fill="#fff9c4" />
      ) : (
        <>
          <ellipse cx={cx - flip * 4} cy={135 + look} rx="4.8" ry="5.6" fill="#fff" />
          <circle cx={cx + flip * 5} cy={150 + look} r="2.2" fill="#fff" />
        </>
      )}
      {/* upper lash with a little wing, lower lash */}
      <path d={`M${cx - 19},${135} Q${cx},${118} ${cx + 19},${131}`} fill="none" stroke={LINE} strokeWidth="5" strokeLinecap="round" />
      <path d={side === "l" ? `M${cx - 19},${135} l-7,-5 M${cx - 18},${137} l-6,1` : `M${cx + 19},${131} l7,-6 M${cx + 18},${134} l6,0`} stroke={LINE} strokeWidth="3" strokeLinecap="round" />
      <path d={`M${cx - 12},${155} Q${cx},${160} ${cx + 11},${154}`} fill="none" stroke={LINE} strokeWidth="1.6" strokeLinecap="round" opacity="0.7" />
      {mood === "sad" && <path d={`M${cx + flip * 9},${158} q${flip * 4},10 0,15 q${-flip * 4},-5 0,-15 Z`} fill="#9fe3ff" />}
    </g>
  );
}

function Mouth({ mood }) {
  if (mood === "cheer" || mood === "hype") return <g><path d="M138,176 Q150,196 162,176 Z" fill="#a8164a" /><path d="M143,186 Q150,192 157,186 Q150,183 143,186 Z" fill="#ff8aa8" /></g>;
  if (mood === "shock") return <ellipse cx="150" cy="182" rx="6" ry="8" fill="#6a1030" />;
  if (mood === "sad") return <path d="M141,185 Q150,178 159,185" fill="none" stroke="#6a1030" strokeWidth="2.6" strokeLinecap="round" />;
  if (mood === "wink") return <path d="M140,178 Q150,188 160,178" fill="none" stroke="#6a1030" strokeWidth="2.6" strokeLinecap="round" />;
  return <path d="M142,179 Q150,186 158,179" fill="none" stroke="#6a1030" strokeWidth="2.6" strokeLinecap="round" />;
}

// Arm drawn hanging down from the shoulder; mood rotates it around the shoulder joint.
function Arm({ side, angle, c, id, who, peace }) {
  const sx = side === "l" ? 112 : 188;
  const y = SHOULDER_Y;
  return (
    <g className={`pbArm pbArm-${side}`} style={{ transform: `rotate(${angle}deg)`, transformOrigin: `${sx}px ${y}px` }}>
      <g transform={`translate(${sx},${y})`}>
        <path d="M-10,-6 C-13,24 -11,48 -8,70 L8,70 C11,48 13,24 10,-6 C4,-12 -4,-12 -10,-6 Z" fill={`url(#latex-${id})`} />
        <path d="M-5,0 C-7,24 -6,46 -4,64" stroke="#fff" strokeWidth="2.4" opacity="0.6" fill="none" strokeLinecap="round" />
        <path d="M-9,64 L9,64 L9,72 L-9,72 Z" fill={c.trim} />
        <path d="M-7,70 C-8,88 -6,104 -5,116 L5,116 C6,104 8,88 7,70 Z" fill={`url(#skin-${id})`} />
        <path d="M-6,104 L6,104 L6,120 L-6,120 Z" fill={c.latex[1]} />
        <path d="M-7,118 C-9,128 -6,138 0,140 C6,138 9,128 7,118 Z" fill={SKIN[1]} />
        {peace ? (
          <g stroke={SKIN[1]} strokeWidth="5" strokeLinecap="round"><path d="M-3,136 l-4,16" /><path d="M3,136 l5,16" /></g>
        ) : who === "luna" ? (
          <g className="pbGlowstick"><rect x="-4" y="118" width="8" height="54" rx="4" fill={c.trim} /><rect x="-2" y="122" width="4" height="46" rx="2" fill="#e9ffff" /></g>
        ) : null}
      </g>
    </g>
  );
}

export function ChibiGirl({ who = "mimi", mood = "idle" }) {
  const c = CREW[who];
  const id = who;
  const [la, ra] = ARMS[mood] || ARMS.idle;
  const mimi = who === "mimi";
  return (
    <svg className={`pbChibi pbChibi-${who}`} data-mood={mood} viewBox="0 0 300 560" role="img" aria-label={`${c.name}`}>
      <defs>
        <linearGradient id={`hair-${id}`} x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stopColor={c.hair[0]} /><stop offset="0.45" stopColor={c.hair[1]} /><stop offset="1" stopColor={c.hair[2]} /></linearGradient>
        <linearGradient id={`iris-${id}`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={c.iris[0]} /><stop offset="0.55" stopColor={c.iris[1]} /><stop offset="1" stopColor={c.iris[2]} /></linearGradient>
        <linearGradient id={`skin-${id}`} x1="0" y1="0" x2="1" y2="0"><stop offset="0" stopColor={SKIN[2]} /><stop offset="0.35" stopColor={SKIN[1]} /><stop offset="0.7" stopColor={SKIN[0]} /><stop offset="1" stopColor={SKIN[1]} /></linearGradient>
        <radialGradient id={`face-${id}`} cx="0.5" cy="0.38" r="0.7"><stop offset="0" stopColor={SKIN[0]} /><stop offset="0.75" stopColor={SKIN[1]} /><stop offset="1" stopColor={SKIN[2]} /></radialGradient>
        <linearGradient id={`latex-${id}`} x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor={c.latex[0]} /><stop offset="0.5" stopColor={c.latex[1]} /><stop offset="1" stopColor={c.latex[0]} /></linearGradient>
        <linearGradient id={`top-${id}`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={c.top} /><stop offset="1" stopColor={c.trim} /></linearGradient>
        <filter id={`glow-${id}`} x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3" /></filter>
      </defs>
      <ellipse cx="150" cy="552" rx="70" ry="8" fill="#000" opacity="0.4" />
      <g className="pbBody">
        {/* back hair */}
        {mimi ? (
          <g className="pbTails">
            <path d="M92,118 C40,150 30,260 52,360 C60,400 78,430 70,450 C100,430 106,380 100,330 C96,270 104,190 120,140 Z" fill={`url(#hair-${id})`} />
            <path d="M208,118 C260,150 270,260 248,360 C240,400 222,430 230,450 C200,430 194,380 200,330 C204,270 196,190 180,140 Z" fill={`url(#hair-${id})`} />
            <path d="M70,200 C60,260 66,320 78,370" stroke="#fff" strokeWidth="3" opacity="0.35" fill="none" strokeLinecap="round" />
            <path d="M230,200 C240,260 234,320 222,370" stroke="#fff" strokeWidth="3" opacity="0.35" fill="none" strokeLinecap="round" />
            <circle cx="98" cy="116" r="9" fill="#ffd36b" /><circle cx="202" cy="116" r="9" fill="#ffd36b" />
          </g>
        ) : (
          <g className="pbTail"><path d="M196,390 C262,392 276,320 250,280 C244,270 232,276 238,286 C254,316 246,370 192,374 Z" fill={c.latex[1]} stroke={c.trim} strokeWidth="2.5" /></g>
        )}
        <path d={mimi ? "M86,128 C80,52 220,52 214,128 L214,190 L86,190 Z" : "M80,132 C74,50 226,50 220,132 L224,214 C210,226 196,206 196,190 L104,190 C104,206 90,226 76,214 Z"} fill={`url(#hair-${id})`} />
        {/* legs with knee and calf, slight contrapposto */}
        <path d="M110,398 C104,430 108,462 116,488 C118,510 118,530 120,548 L138,548 C138,528 140,508 142,488 C147,460 149,430 148,404 Z" fill={`url(#skin-${id})`} />
        <path d="M152,404 C151,430 153,460 158,488 C160,508 162,528 162,548 L180,548 C182,530 182,510 184,488 C192,462 196,430 190,398 Z" fill={`url(#skin-${id})`} />
        {/* glossy thigh-high boots */}
        <path d="M112,466 C114,486 117,508 118,548 L140,548 C140,524 141,500 144,466 Z" fill={`url(#latex-${id})`} />
        <path d="M156,466 C159,500 160,524 160,548 L182,548 C183,508 186,486 188,466 Z" fill={`url(#latex-${id})`} />
        <path d="M111,462 Q128,468 145,462 L145,470 Q128,476 111,470 Z" fill={c.trim} />
        <path d="M155,462 Q172,468 189,462 L189,470 Q172,476 155,470 Z" fill={c.trim} />
        <path d="M121,476 C122,496 124,518 125,540" stroke="#fff" strokeWidth="3" opacity="0.65" fill="none" strokeLinecap="round" />
        <path d="M166,476 C167,498 167,520 166,540" stroke="#fff" strokeWidth="2.2" opacity="0.45" fill="none" strokeLinecap="round" />
        <path d="M114,544 L144,544 L146,556 L110,556 Z" fill="#05020a" />
        <path d="M156,544 L186,544 L190,556 L154,556 Z" fill="#05020a" />
        {/* torso: shoulders, waist, hips */}
        <path d="M140,222 C130,232 114,236 108,246 C102,258 106,272 110,284 C114,302 118,318 121,332 C116,350 108,366 106,384 L194,384 C192,366 184,350 179,332 C182,318 186,302 190,284 C194,272 198,258 192,246 C186,236 170,232 160,222 Z" fill={`url(#skin-${id})`} />
        <path d="M150,312 l0,10" stroke={SKIN[2]} strokeWidth="1.6" strokeLinecap="round" opacity="0.6" />
        {mimi ? (
          <path d="M106,370 C120,360 180,360 194,370 L198,406 C184,414 166,412 156,404 L150,398 L144,404 C134,412 116,414 102,406 Z" fill={`url(#latex-${id})`} />
        ) : (
          <path d="M106,368 C120,360 180,360 194,368 L212,420 C176,434 124,434 88,420 Z" fill={`url(#latex-${id})`} />
        )}
        <path d="M106,366 C120,358 180,358 194,366 L194,374 C180,366 120,366 106,374 Z" fill={c.trim} />
        <circle cx="150" cy="370" r="5" fill="#ffd36b" />
        <path d="M116,382 C114,392 114,400 116,406" stroke="#fff" strokeWidth="3" opacity="0.6" fill="none" strokeLinecap="round" />
        <path d="M184,382 C186,392 186,400 184,404" stroke="#fff" strokeWidth="2" opacity="0.4" fill="none" strokeLinecap="round" />
        {/* fitted crop top */}
        <path d="M112,250 C120,240 180,240 188,250 C192,270 190,288 185,300 Q150,310 115,300 C110,288 108,270 112,250 Z" fill={`url(#top-${id})`} />
        <path d="M134,244 Q150,256 166,244" stroke="#fff" strokeWidth="2" opacity="0.5" fill="none" />
        <text x="150" y="285" textAnchor="middle" fontSize="17" fontWeight="900" fill="#fff" fontFamily="Inter, Arial" opacity="0.92">{mimi ? "DJ" : "★"}</text>
        {/* cropped latex bolero */}
        <path d="M106,244 C98,262 100,286 108,300 L124,296 C120,276 122,258 130,242 C122,238 112,239 106,244 Z" fill={`url(#latex-${id})`} />
        <path d="M194,244 C202,262 200,286 192,300 L176,296 C180,276 178,258 170,242 C178,238 188,239 194,244 Z" fill={`url(#latex-${id})`} />
        <path d="M112,250 C106,266 106,282 110,294" stroke="#fff" strokeWidth="3" opacity="0.6" fill="none" strokeLinecap="round" />
        <path d="M130,242 C122,258 120,276 124,296 M170,242 C178,258 180,276 176,296" stroke={c.trim} strokeWidth="2.6" fill="none" />
        {/* neck + head */}
        <path d="M140,196 L160,196 L162,234 L138,234 Z" fill={SKIN[2]} />
        <path d="M136,226 Q150,236 164,226" stroke={c.trim} strokeWidth="5" fill="none" />
        <path d="M100,118 C100,70 200,70 200,118 L198,152 C196,178 176,200 150,208 C124,200 104,178 102,152 Z" fill={`url(#face-${id})`} />
        {!mimi && (
          <g className="pbEars">
            <path d="M92,80 L78,18 L132,56 Z" fill={c.hair[2]} /><path d="M96,70 L88,34 L122,58 Z" fill="#ff9fcf" />
            <path d="M208,80 L222,18 L168,56 Z" fill={c.hair[2]} /><path d="M204,70 L212,34 L178,58 Z" fill="#ff9fcf" />
          </g>
        )}
        {/* bangs with separate strands */}
        <path d="M94,132 C86,60 214,60 206,132 L198,110 L190,140 L178,102 L164,132 L152,96 L138,132 L126,100 L114,140 L104,108 Z" fill={`url(#hair-${id})`} />
        <path d="M96,128 C92,150 94,172 100,190 L108,150 Z" fill={`url(#hair-${id})`} />
        <path d="M204,128 C208,150 206,172 200,190 L192,150 Z" fill={`url(#hair-${id})`} />
        <path d="M120,74 C140,66 166,66 182,76" stroke="#fff" strokeWidth="4" opacity="0.45" fill="none" strokeLinecap="round" />
        <path d="M150,62 q24,-34 42,-14 q-20,-4 -34,18 Z" fill={c.hair[1]} className="pbAhoge" />
        {mimi ? (
          <g>
            <path d="M92,140 C84,40 216,40 208,140" fill="none" stroke="#1a0820" strokeWidth="9" strokeLinecap="round" />
            <rect x="76" y="118" width="26" height="48" rx="12" fill="#1a0820" /><rect x="80" y="124" width="18" height="36" rx="9" fill={c.trim} className="pbCup" />
            <rect x="198" y="118" width="26" height="48" rx="12" fill="#1a0820" /><rect x="202" y="124" width="18" height="36" rx="9" fill={c.trim} className="pbCup" />
          </g>
        ) : (
          <path d="M184,90 l6,-11 l6,11 l12,2 l-9,8 l2,12 l-11,-6 l-11,6 l2,-12 l-9,-8 Z" fill="#ffd36b" />
        )}
        {/* brows, eyes, blush, mouth */}
        <path d={mood === "sad" ? "M110,118 L136,114" : "M110,116 Q123,110 136,114"} stroke={LINE} strokeWidth="2.6" strokeLinecap="round" fill="none" />
        <path d={mood === "sad" ? "M164,114 L190,118" : "M164,114 Q177,110 190,116"} stroke={LINE} strokeWidth="2.6" strokeLinecap="round" fill="none" />
        <Eye cx={124} mood={mood} side="l" id={id} />
        <Eye cx={176} mood={mood} side="r" id={id} />
        <ellipse cx="114" cy="166" rx="12" ry="6" fill="#ff6f9c" opacity="0.4" />
        <ellipse cx="186" cy="166" rx="12" ry="6" fill="#ff6f9c" opacity="0.4" />
        <path d="M150,160 l-2,6 l3,0" stroke={SKIN[2]} strokeWidth="1.6" fill="none" strokeLinecap="round" />
        <Mouth mood={mood} />
        <Arm side="l" angle={la} c={c} who={who} id={id} />
        <Arm side="r" angle={ra} c={c} who={who} id={id} peace={mood === "wink"} />
        {(mood === "hype" || mood === "cheer") && (
          <g className="pbSparkles" fill="#fff6a8">
            <path d="M40,90 l5,13 l13,5 l-13,5 l-5,13 l-5,-13 l-13,-5 l13,-5 Z" />
            <path d="M262,70 l4,10 l10,4 l-10,4 l-4,10 l-4,-10 l-10,-4 l10,-4 Z" />
            <path d="M268,190 l3,7 l7,3 l-7,3 l-3,7 l-3,-7 l-7,-3 l7,-3 Z" />
          </g>
        )}
        {mood === "shock" && <path d="M236,80 l10,-16 M248,98 l18,-6 M228,64 l2,-20" stroke="#fff" strokeWidth="5" strokeLinecap="round" />}
      </g>
    </svg>
  );
}
