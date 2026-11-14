import React from "react";

// The royal purple chicken that lives next to the machine. Pure SVG; the mood class drives
// the CSS animations in slots.css: idle (breathing + blinking), spin (bouncing along),
// tense (shaking, eyes wide), win (jump + flap), big (wild dance), bonus (glowing hype),
// sad (droopy).
export function RoyalBird({ mood = "idle", say = "" }) {
  return (
    <div className={`slBird mood-${mood}`} aria-hidden="true">
      {say && <div className="slBubble" key={say}>{say}</div>}
      <svg viewBox="0 0 200 220">
        <defs>
          <radialGradient id="rbBody" cx="0.4" cy="0.3" r="0.85"><stop offset="0" stopColor="#f0dcff" /><stop offset="0.35" stopColor="#c08aff" /><stop offset="0.8" stopColor="#8a3ee8" /><stop offset="1" stopColor="#4a1590" /></radialGradient>
          <radialGradient id="rbBelly" cx="0.5" cy="0.3" r="0.75"><stop offset="0" stopColor="#fff" /><stop offset="1" stopColor="#e4ccff" /></radialGradient>
          <linearGradient id="rbGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#fff6c4" /><stop offset="0.45" stopColor="#ffcf4a" /><stop offset="1" stopColor="#b8740a" /></linearGradient>
          <radialGradient id="rbAura" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stopColor="#ff8ae6" stopOpacity="0.7" /><stop offset="1" stopColor="#b56cff" stopOpacity="0" /></radialGradient>
        </defs>
        <ellipse className="rbAura" cx="100" cy="120" rx="98" ry="98" fill="url(#rbAura)" />
        <ellipse cx="100" cy="210" rx="56" ry="8" fill="#000" opacity="0.35" />
        <g className="rbAll">
          <g className="rbFeet">
            <path d="M80 190 l-10 12 M80 190 l0 14 M80 190 l10 12" stroke="#ffad1f" strokeWidth="6" strokeLinecap="round" />
            <path d="M120 190 l-10 12 M120 190 l0 14 M120 190 l10 12" stroke="#ffad1f" strokeWidth="6" strokeLinecap="round" />
          </g>
          <g className="rbBody">
            <path className="rbWing left" d="M46 112 C14 96 6 136 26 156 C40 168 54 156 58 140 Z" fill="url(#rbBody)" stroke="#3a0a70" strokeWidth="3" />
            <path className="rbWing right" d="M154 112 C186 96 194 136 174 156 C160 168 146 156 142 140 Z" fill="url(#rbBody)" stroke="#3a0a70" strokeWidth="3" />
            <ellipse cx="100" cy="128" rx="60" ry="66" fill="url(#rbBody)" stroke="#3a0a70" strokeWidth="3" />
            <path d="M74 66 C70 54 80 50 84 60 C86 48 98 48 96 62" fill="#c08aff" stroke="#3a0a70" strokeWidth="2.5" />
            <ellipse cx="100" cy="150" rx="36" ry="38" fill="url(#rbBelly)" />
            <path d="M84 140 q6 6 12 0 q6 6 12 0 q6 6 12 0 M90 156 q6 6 12 0 q6 6 12 0" stroke="#d7b8ff" strokeWidth="2.5" fill="none" strokeLinecap="round" />
            <g className="rbFace">
              <g className="rbEyes">
                <ellipse cx="78" cy="110" rx="13" ry="16" fill="#1a0630" />
                <ellipse cx="122" cy="110" rx="13" ry="16" fill="#1a0630" />
                <ellipse cx="78" cy="113" rx="9" ry="11" fill="#6a2ab8" />
                <ellipse cx="122" cy="113" rx="9" ry="11" fill="#6a2ab8" />
                <circle cx="82" cy="104" r="5" fill="#fff" /><circle cx="126" cy="104" r="5" fill="#fff" />
                <circle cx="74" cy="118" r="2.2" fill="#fff" /><circle cx="118" cy="118" r="2.2" fill="#fff" />
              </g>
              <g className="rbLids">
                <rect x="63" y="92" width="30" height="36" rx="13" fill="#a668f4" />
                <rect x="107" y="92" width="30" height="36" rx="13" fill="#a668f4" />
              </g>
              <g className="rbHappy">
                <path d="M66 112 Q78 98 90 112" stroke="#1a0630" strokeWidth="5" fill="none" strokeLinecap="round" />
                <path d="M110 112 Q122 98 134 112" stroke="#1a0630" strokeWidth="5" fill="none" strokeLinecap="round" />
              </g>
              <ellipse cx="62" cy="130" rx="10" ry="6" fill="#ff7ac0" opacity="0.55" />
              <ellipse cx="138" cy="130" rx="10" ry="6" fill="#ff7ac0" opacity="0.55" />
              <g className="rbBeak">
                <path d="M88 126 L112 126 L100 138 Z" fill="#ffad1f" stroke="#a85a00" strokeWidth="2.5" strokeLinejoin="round" />
                <path className="rbBeakLow" d="M90 128 L110 128 L100 146 Z" fill="#ff8a1f" stroke="#a85a00" strokeWidth="2.5" strokeLinejoin="round" />
              </g>
              <g className="rbSweat"><path d="M150 84 C146 92 146 98 150 100 C154 98 154 92 150 84 Z" fill="#8fe8ff" stroke="#fff" strokeWidth="1.5" /></g>
              <g className="rbTear"><path d="M72 128 C69 134 69 138 72 140 C75 138 75 134 72 128 Z" fill="#8fe8ff" /></g>
            </g>
            <g className="rbCrown">
              <path d="M66 70 L70 40 L84 56 L100 30 L116 56 L130 40 L134 70 Z" fill="url(#rbGold)" stroke="#7a4300" strokeWidth="3" strokeLinejoin="round" />
              <rect x="64" y="66" width="72" height="11" rx="4" fill="url(#rbGold)" stroke="#7a4300" strokeWidth="2.5" />
              <circle cx="100" cy="30" r="6" fill="#ff5ad6" stroke="#fff" strokeWidth="2" />
              <circle cx="70" cy="40" r="4.5" fill="#9a4dff" stroke="#fff" strokeWidth="1.5" />
              <circle cx="130" cy="40" r="4.5" fill="#9a4dff" stroke="#fff" strokeWidth="1.5" />
              <path d="M95 71.5 l5 -5 l5 5 l-5 5 Z" fill="#c48bff" stroke="#fff" strokeWidth="1.2" />
            </g>
          </g>
        </g>
      </svg>
    </div>
  );
}
