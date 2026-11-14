import React from "react";

// Two original chibi club girls drawn as SVG. Moods: idle, cheer, hype, sad, shock, wink.
// Mimi: DJ with pink twin tails and headphones. Luna: cyan cat-ear hoodie with a glowstick.
export const CREW = {
  mimi: { name: "Mimi", hair: "#ff6fb7", hairDark: "#d9367f", iris: ["#7a1f6b", "#ff8fd0"], outfit: "#5b2a86", trim: "#ff3fb4", prop: "#ff3fb4" },
  luna: { name: "Luna", hair: "#5fe0ff", hairDark: "#1f8fc2", iris: ["#123b8a", "#6ff3ff"], outfit: "#1c1430", trim: "#3fe7ff", prop: "#3fe7ff" },
};

const ARMS = { idle: [18, -18], cheer: [124, -124], hype: [132, -132], sad: [6, -6], shock: [72, -72], wink: [18, -126] };

function Eye({ x, mood, c, side, id }) {
  const lash = <path d="M-15,-9 Q0,-21 15,-10" fill="none" stroke="#2a1030" strokeWidth="4.5" strokeLinecap="round" />;
  if (mood === "cheer" || (mood === "wink" && side === "l")) {
    return <g transform={`translate(${x},132)`}><path d="M-13,5 Q0,-11 13,5" fill="none" stroke="#2a1030" strokeWidth="5" strokeLinecap="round" /></g>;
  }
  if (mood === "shock") {
    return <g transform={`translate(${x},132)`}><ellipse rx="14" ry="17" fill="#fff" stroke="#2a1030" strokeWidth="2.5" /><circle r="3.4" fill="#2a1030" /></g>;
  }
  const look = mood === "sad" ? 4 : 0;
  return (
    <g transform={`translate(${x},132)`}>
      <ellipse rx="14" ry="17" fill="#fff" />
      <ellipse cy={2 + look} rx="11.5" ry="15" fill={`url(#iris-${id})`} />
      <ellipse cy={4 + look} rx="5" ry="7" fill="#1a0820" />
      {mood === "hype" ? (
        <path d="M0,-9 L2.6,-2.6 L9,0 L2.6,2.6 L0,9 L-2.6,2.6 L-9,0 L-2.6,-2.6 Z" transform={`translate(0,${2 + look}) scale(1.1)`} fill="#fff6a8" />
      ) : (
        <>
          <circle cx="-4.5" cy={-5 + look} r="4.6" fill="#fff" />
          <circle cx="4.5" cy={6 + look} r="2" fill="#fff" />
        </>
      )}
      {lash}
      <path d={side === "l" ? "M-15,-9 L-20,-14" : "M15,-10 L20,-15"} stroke="#2a1030" strokeWidth="3.5" strokeLinecap="round" />
      {mood === "sad" && <path d="M8,16 q4,9 0,13 q-4,-4 0,-13 Z" fill="#8fdcff" opacity="0.9" />}
    </g>
  );
}

function Mouth({ mood }) {
  if (mood === "cheer" || mood === "hype") return <g><path d="M106,155 Q120,180 134,155 Z" fill="#b8184f" /><ellipse cx="120" cy="168" rx="7" ry="4" fill="#ff7a9c" /></g>;
  if (mood === "shock") return <ellipse cx="120" cy="162" rx="6" ry="8" fill="#5a0f2a" />;
  if (mood === "sad") return <path d="M111,165 Q120,157 129,165" fill="none" stroke="#5a0f2a" strokeWidth="3.2" strokeLinecap="round" />;
  if (mood === "wink") return <path d="M109,157 q5,7 11,0 q6,7 11,0" fill="none" stroke="#5a0f2a" strokeWidth="3.2" strokeLinecap="round" />;
  return <path d="M111,158 Q120,166 129,158" fill="none" stroke="#5a0f2a" strokeWidth="3.2" strokeLinecap="round" />;
}

function Arm({ side, angle, c, who }) {
  const sx = side === "l" ? 96 : 144;
  return (
    <g className={`pbArm pbArm-${side}`} style={{ transform: `rotate(${angle}deg)`, transformOrigin: `${sx}px 194px` }}>
      <rect x={sx - 7.5} y="190" width="15" height="50" rx="7.5" fill={c.outfit} />
      <rect x={sx - 7.5} y="226" width="15" height="9" rx="3" fill={c.trim} />
      <circle cx={sx} cy="246" r="9.5" fill="#ffe6da" />
      {who === "mimi" ? (
        <g transform={`translate(${sx},252)`}>
          {[0, 1, 2, 3, 4, 5, 6, 7].map((i) => <circle key={i} cx={Math.cos(i * 0.785) * 11} cy={Math.sin(i * 0.785) * 11 + 4} r="8" fill={i % 2 ? c.prop : "#ffc2e4"} />)}
        </g>
      ) : (
        <g>
          <rect x={sx - 4} y="236" width="8" height="46" rx="4" fill={c.prop} className="pbGlowstick" />
          <rect x={sx - 2} y="240" width="4" height="38" rx="2" fill="#e8ffff" />
        </g>
      )}
    </g>
  );
}

export function ChibiGirl({ who = "mimi", mood = "idle" }) {
  const c = CREW[who];
  const [la, ra] = ARMS[mood] || ARMS.idle;
  const id = who;
  return (
    <svg className={`pbChibi pbChibi-${who}`} data-mood={mood} viewBox="0 0 240 320" role="img" aria-label={`${c.name} jubelt`}>
      <defs>
        <linearGradient id={`iris-${id}`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={c.iris[0]} /><stop offset="1" stopColor={c.iris[1]} /></linearGradient>
        <linearGradient id={`hair-${id}`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={c.hair} /><stop offset="1" stopColor={c.hairDark} /></linearGradient>
        <radialGradient id={`face-${id}`} cx="0.5" cy="0.45" r="0.6"><stop offset="0" stopColor="#fff1e8" /><stop offset="1" stopColor="#ffd6c4" /></radialGradient>
      </defs>
      <ellipse cx="120" cy="306" rx="58" ry="9" fill="#000" opacity="0.35" />
      <g className="pbBody">
        {/* back hair */}
        {who === "mimi" ? (
          <g className="pbTails">
            <ellipse cx="50" cy="180" rx="26" ry="78" transform="rotate(16 50 180)" fill={`url(#hair-${id})`} />
            <ellipse cx="190" cy="180" rx="26" ry="78" transform="rotate(-16 190 180)" fill={`url(#hair-${id})`} />
          </g>
        ) : (
          <g className="pbTail"><path d="M152,262 C200,262 214,214 196,186 C192,180 184,184 188,190 C200,214 186,246 150,248 Z" fill={c.outfit} stroke={c.trim} strokeWidth="2.5" /></g>
        )}
        <ellipse cx="120" cy={who === "mimi" ? 112 : 124} rx={who === "mimi" ? 68 : 72} ry={who === "mimi" ? 68 : 66} fill={`url(#hair-${id})`} />
        {/* legs + skirt + torso */}
        <rect x="100" y="266" width="15" height="34" rx="7" fill="#ffe6da" />
        <rect x="125" y="266" width="15" height="34" rx="7" fill="#ffe6da" />
        <rect x="100" y="282" width="15" height="18" rx="5" fill="#fff" />
        <rect x="125" y="282" width="15" height="18" rx="5" fill="#fff" />
        <ellipse cx="106" cy="302" rx="12" ry="7" fill={c.trim} />
        <ellipse cx="134" cy="302" rx="12" ry="7" fill={c.trim} />
        <path d="M82,246 L158,246 L170,276 Q120,288 70,276 Z" fill={who === "mimi" ? "#2b1240" : c.trim} />
        <path d="M95,248 L90,278 M120,248 L120,282 M145,248 L150,278" stroke="#00000033" strokeWidth="2" />
        <path d="M92,184 Q120,174 148,184 L156,252 Q120,262 84,252 Z" fill={c.outfit} />
        <path d="M108,182 L120,204 L132,182" fill="#fff" />
        <path d="M86,240 Q120,250 154,240" stroke={c.trim} strokeWidth="5" fill="none" />
        <text x="120" y="232" textAnchor="middle" fontSize="15" fontWeight="900" fill={c.trim} fontFamily="Inter, Arial">{who === "mimi" ? "DJ" : "★"}</text>
        {/* head */}
        <ellipse cx="120" cy="130" rx="57" ry="53" fill={`url(#face-${id})`} />
        {who === "luna" && (
          <g className="pbEars">
            <path d="M70,82 L58,26 L106,62 Z" fill={c.hairDark} /><path d="M74,74 L66,38 L96,62 Z" fill="#ff9ccc" />
            <path d="M170,82 L182,26 L134,62 Z" fill={c.hairDark} /><path d="M166,74 L174,38 L144,62 Z" fill="#ff9ccc" />
          </g>
        )}
        <path d="M60,124 C50,52 190,52 180,124 L170,104 L160,124 L148,96 L135,118 L120,92 L105,118 L92,96 L80,124 L70,104 Z" fill={`url(#hair-${id})`} />
        <path d="M120,58 q20,-30 34,-12 q-16,-4 -28,16 Z" fill={c.hair} className="pbAhoge" />
        {who === "mimi" ? (
          <g>
            <path d="M58,124 C56,40 184,40 182,124" fill="none" stroke="#24102f" strokeWidth="9" strokeLinecap="round" />
            <rect x="42" y="104" width="24" height="44" rx="11" fill="#24102f" /><rect x="46" y="110" width="16" height="32" rx="8" fill={c.trim} className="pbCup" />
            <rect x="174" y="104" width="24" height="44" rx="11" fill="#24102f" /><rect x="178" y="110" width="16" height="32" rx="8" fill={c.trim} className="pbCup" />
            <circle cx="62" cy="112" r="6" fill="#ffd36b" /><circle cx="178" cy="112" r="6" fill="#ffd36b" />
          </g>
        ) : (
          <path d="M150,86 l6,-10 l6,10 l11,2 l-8,8 l2,11 l-11,-5 l-10,5 l2,-11 l-8,-8 Z" fill="#ffd36b" />
        )}
        <path d={mood === "sad" ? "M84,108 L106,104" : "M84,106 Q95,100 106,104"} stroke="#2a1030" strokeWidth="3" strokeLinecap="round" fill="none" />
        <path d={mood === "sad" ? "M134,104 L156,108" : "M134,104 Q145,100 156,106"} stroke="#2a1030" strokeWidth="3" strokeLinecap="round" fill="none" />
        <Eye x={96} mood={mood} c={c} side="l" id={id} />
        <Eye x={144} mood={mood} c={c} side="r" id={id} />
        <ellipse cx="82" cy="154" rx="12" ry="6.5" fill="#ff6f9c" opacity="0.5" />
        <ellipse cx="158" cy="154" rx="12" ry="6.5" fill="#ff6f9c" opacity="0.5" />
        <path d="M76,151 l4,6 M82,150 l4,6 M152,150 l4,6 M158,151 l4,6" stroke="#ff4f86" strokeWidth="1.6" strokeLinecap="round" opacity="0.7" />
        <Mouth mood={mood} />
        <Arm side="l" angle={la} c={c} who={who} />
        <Arm side="r" angle={ra} c={c} who={who} />
        {(mood === "hype" || mood === "cheer") && (
          <g className="pbSparkles" fill="#fff6a8">
            <path d="M30,60 l4,10 l10,4 l-10,4 l-4,10 l-4,-10 l-10,-4 l10,-4 Z" />
            <path d="M206,40 l3,8 l8,3 l-8,3 l-3,8 l-3,-8 l-8,-3 l8,-3 Z" />
            <path d="M214,120 l2.5,6 l6,2.5 l-6,2.5 l-2.5,6 l-2.5,-6 l-6,-2.5 l6,-2.5 Z" />
          </g>
        )}
        {mood === "shock" && <path d="M196,70 l8,-14 M206,84 l14,-6 M190,58 l2,-16" stroke="#fff" strokeWidth="4" strokeLinecap="round" />}
      </g>
    </svg>
  );
}
