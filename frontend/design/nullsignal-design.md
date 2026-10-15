# Nullsignal — design and implementation contract

Original two-player cooperative 3D defusal game. Host signs into Aviary; one
invited expert joins by nickname without an account. Bomb and manual are separate
server projections. No copied artwork, module text, names, layouts or audio from
the reference game.

## Primary screen specifications (viewed before implementation)

Image Gen concepts, native 1536 × 1024, under
`C:/Users/Flori/.codex/generated_images/01a13ead-15b6-78f1-bc15-d0fb38b4edf7/`:

- Host: `exec-54040b30-3235-4831-af4f-c4de319ac96f.png`.
- Expert manual: `exec-15d45aee-f3df-4a44-91b2-f0212785889e.png`.
- Lobby: `exec-54789b71-0d16-431b-843e-b11bcd81fc3b.png`.

Host: full-screen workshop, dominant tangible dark metal device, copper corner
braces, actual curved cable geometry, screws, vents and handle. Six modules on
front, two additional modules on back for Blackout. Narrow right module rail;
timer and mistake lamps on physical device. Bottom camera toolbar. Controls
operate actual 3D hit targets; equivalent focused-module controls support keyboard
and touch. Transparent WebGL scene over un-tinted generated workshop art.

Manual: same compact dark header; left eight-page contents rail; bright cool grey
technical page with numbered rules, clear tables, original vector schematics and
previous/next controls. It never includes the live device layout or secret answer.

Lobby: closed 3D case on left, mission list on right, invitation and two-person
status beneath. Create, copy link, guest nickname, ready, start. Mission buttons
are disabled during an active lobby; new mission is selected between rounds.

## Design tokens / component inventory

- Background `#101d25`; steel `#263943`; borders `#3c515c`.
- Copper action `#ff9c52`; mint success `#83e5cd`; error `#ff685f`.
- Ivory text `#f2eee4`; muted `#9bb2ba`.
- Manual paper **cool grey** `#e6e9e7`, ink `#223438`; no cream substitute.
- Headings Bahnschrift / Arial Narrow, condensed uppercase and tracked; body
  Segoe UI / Arial, minimum 14 px readable manual body, tabular monospace numbers.
- Physical surfaces: generated brushed-steel diffuse/bump asset, native 3D
  beveled shapes and modeled components, warm key light and blue fill light,
  contact shadows and restrained emissive bloom. No flat screenshot bomb.
- Flat list rows and fine dividers; small 4–8 px radii; no dashboard tile grid.
- Lucide 18–20 px outline icons for audio, fullscreen, copy, navigation and camera;
  custom schematic/glyph geometry where a generic icon cannot represent a puzzle.
- Motion: short focus-camera easing, physical button/lever motion, readable pulse
  signal, brief sparks/smoke for mistakes/explosion. Reduced motion removes camera
  shake, decorative sparks and automatic scene movement.

Allowed main copy: NULLSIGNAL; Zwei Stimmen. Eine Chance.; Wählt eure Mission.;
Erstkontakt; Störfall; Blackout; Lobby erstellen; Deine Lobby; Entschärfer; Experte;
Einladungslink; Link kopieren; Mission starten; Handbuch; Inhalt; eight module
names; Vorderseite; Rückseite; Ansicht zurücksetzen. Additional connection,
error, accessibility and result copy must explain a real functional state.

## Required functional adaptations

Generated illustrative rule text is replaced by the actual server-generated rules
for that room. Placeholder invite domain is replaced by the real HTTPS origin.
Actual participant names, time, strikes and progress replace concept examples.
Lobby select/create and occupied-room controls use their actual lifecycle states.
Mobile stacks scene and lobby, collapses manual navigation to a select, and keeps
all puzzle controls touch-sized. Team results and server-confirmed Chicken rewards
are shown after completion, respecting the existing global daily cap.

## Verification ledger

Compared native 1536 × 1024 host, lobby and manual screenshots against their
respective concepts; inspected 390 × 844 host and manual screenshots after the
final mobile fix. Evidence: `%TEMP%/nullsignal-{host,lobby,manual}-desktop.png`,
`nullsignal-{host,manual}-mobile.png`, `nullsignal-result-desktop.png`.

| Check | Observed result / resolution |
| --- | --- |
| Composition | Workshop/device dominate the host; narrow right module rail, compact header and camera footer. Lobby preserves left case/right mission hierarchy. Removed inherited global main max-width so the game fills its viewport. |
| 3D and materials | Actual beveled case, copper corners, screws, handle, curved wires, controls and workbench. Generated brushed steel supplies surface detail. Added correct OutputPass and restrained bloom after checking contrast. Runtime geometry deliberately simplifies the raster concept's fine wear and props; it is not a claim of photographic parity. |
| Typography | Condensed tracked headings, readable body and tabular timer preserved. Shared site paragraph/button styles were overridden locally after spotting colour bleed in the manual. |
| Colour | Blue charcoal, copper orange and mint match the contract; the manual stays cool grey with dark ink. Live error/success colours distinguish functional states. |
| Copy and hierarchy | Mission names and counts match. Actual names, invitation origin, countdown and generated rules replace illustrative concept data. Dedicated connection/status row and volume/fullscreen controls explain genuine runtime states. |
| Manual | Left contents, numbered rules, schematic/table body and previous/next controls follow the concept. Original code-native SVG schematic is intentionally simpler and sharper than the concept illustration. All eight chapters remain readable. |
| Controls | Numbered module rail intentionally replaces concept icon navigation to align spoken instructions with the handbook. Genuine raycast clicks tested on all eight module types, including rear modules; curved-wire pick volume widened after testing. Equivalent accessible controls remain available. |
| Mobile | Scene and rail stack without horizontal overflow. Manual chapter select and scrolling paper replace desktop columns. Fixed shrinking ready notice; keyed lobby/play containers prevent carrying lobby scroll into the mission. Regression assertion confirms mission scrollTop is zero and full device is visible. |
| Assets and roles | Original generated workshop and steel are used unchanged. Two real browser contexts confirm expert receives only rules and does not load the 3D scene; host receives the device without answers. |
| Motion and sound | Camera focus, module changes, sparks and one-shot CC0 audio work; actual decoded sample starts verified, no oscillators/music loop. Reduced Motion removes decorative movement. |

Validation: 61 backend + 54 browser + 15 engine tests passed (130 total).
After the final lobby/play key change the five Nullsignal browser tests passed
again, including complete eight-module defusal and the mobile start regression.
Production Vite build passed. Browser plugin unavailable; used Playwright with
installed Microsoft Edge, desktop and mobile emulation. Firefox, Safari and
physical mobile GPUs have not been separately validated.
