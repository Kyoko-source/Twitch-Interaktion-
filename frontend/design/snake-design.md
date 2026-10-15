# Chicken Snake · Nachtgarten

Built-in Image Gen concept: `exec-83a201d4-2cce-45a8-a76b-ce237eb81896.png`.

The game keeps the Aviary shell and replaces the old square-only canvas with a
top-down midnight garden. One illustrated arena is the focal point. Native React
controls, results and the real API leaderboard sit around it.

## Visual system

- Charcoal plum `#141219`; dark teal ground `#07262b`; mint `#81f4d3`;
  golden eggs/title `#ffe1a1`; lavender secondary text `#bcb3df`.
- Georgia bold display titles; existing Segoe UI/Inter body and controls.
- Header: title, “Kleine Schlange. Große Ambitionen.”, Score / Level / Rekord.
- Arena: thin luminous mint border, 18px corners, generated garden background
  without a color wash; generated transparent jade head/body/tail and golden egg.
- Ready overlay: “Hungrig auf den Highscore?”, “Sammle goldene Eier. Wachse über
  dich hinaus.”, “Spiel starten”, keyboard hint. Paused and finished states reuse
  the same native overlay family. No image-baked controls or text.
- Toolbar: keycaps, pause, finish; sound/fullscreen in the arena corner.
- Continuation: “Dein nächster Rekord”, “Score speichern und Chickens sichern.”,
  real ranked scores. No invented scores in production.
- Lucide 18–20px outline icons; 44px minimum interactive targets. Responsive HUD,
  swipe input and directional pad; contained fullscreen mode.

## Functional adaptations from concept

The playable grid is 36 × 20, with a taller arena than the panoramic mockup so
cells stay readable. Mobile uses the same undistorted board and additional touch
controls. Existing global records and server-authoritative Chicken payouts stay
unchanged. Ten points per egg; five eggs per level. Combo streaks only affect
feedback, not points or currency. Edge wrapping stays available and is explained
as portals. Keyboard hints and record guidance include this necessary rule.
The board has room for 7,150 points, exceeding the old arena's maximum legal
6,430 points so existing records remain beatable without inflating egg values.

Generated sprite artwork defines characters and collectibles. Code draws the
grid, particle effects, portal cues and score popups; these are intentional native
game effects. Audio is synthesized locally after user interaction, with a mute
control. No third-party art/audio downloads or additional dependencies.
