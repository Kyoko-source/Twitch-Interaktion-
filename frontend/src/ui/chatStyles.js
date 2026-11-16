// Every chat look that can be bought in the shop. Keep in sync with CHAT_STYLE_SHOP_ITEMS in
// backend/app/main.py; the visuals live in styles.css (first four) and chat-styles.css.
import "./chat-styles.css";

export const CHAT_STYLE_IDS = ["sparkle", "cotton", "neon", "royal", "sakura", "ocean", "frost", "fire", "matrix", "glitch", "galaxy", "rainbow", "gold", "unicorn"];

export function chatStyleClass(style) {
  return `chatStyle-${CHAT_STYLE_IDS.includes(style) ? style : "default"}`;
}
