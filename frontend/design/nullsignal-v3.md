# NULLSIGNAL — overhaul, 2026-10-16

Visual specification: `nullsignal-v3-host.png` and `nullsignal-v3-manual.png`.
Built-in Image Gen generated both complete screens and the separately rendered
`public/assets/nullsignal/workshop-v3.png` environment. Original generation files
remain in Codex's generated_images directory. Exact prompts are recorded in
`nullsignal-v3-prompts.md`.

Palette: near-black petroleum #0c171e; white manual paper #ffffff;
ink #18323e; copper #ffa85b; mint #7ee1c5; teal #169b8a; violet #8762d5.
Bahnschrift condensed headings, readable system body, monospace timer and tables.
Controls have 4–6px radii, subtle borders, 44px touch targets. Module identities
use a color AND an icon, not color alone. Desktop: canvas plus 300px module rail;
manual: dark 260px contents rail and generous white reading area. Mobile stacks
the existing bomb controls and uses a searchable chapter selector.

Manual anatomy: breadcrumb, module icon/title, short mission statement, Observe
and Decide steps, generated rules, visual examples, error/confirmation advice,
chapter navigation. The expert receives only server-generated rules, never the
actual device state or answer. Glyphs retain their unlabelled visual presentation.

Intentional implementation constraints: retain real interactive Three.js geometry
and its stable panel sockets instead of baking the concept's fictional device into
a picture. Randomly assign real modules to these sockets, improve metal/light and
add colored physical identity strips. Existing user music files and controls stay;
the conceptual microphone icon is omitted because there is no voice-chat service.
The original NULLSIGNAL brand remains code-native. Example colors and numbers
must follow the actual generated rules rather than concept placeholder values.
No figures, jumpscares or automatic scary audio. Keep the responsive zoom cap.

Ambient audio: original offline-rendered non-musical rain/ventilation textures,
quiet irregular mechanical samples, independent persisted ambience volume,
pause/mute/dispose handling and low-power ambience during outages. No melody,
continuous oscillator or replacement of the user's menu/ingame MP3s.

## Rendered review

Compared both generated concepts with the final Edge/Playwright screenshots at
1536×1024; also inspected 390×844 host and manual views using view_image.

| Point | Rendered result / intentional constraint |
| --- | --- |
| Palette | Petroleum chrome, copper title, true-white reading surface verified. |
| Layout | Dedicated module rail and white paper/260px contents navigation; real game status and ready controls retained above paper for reconnect visibility. |
| Typography | Large readable chapter headings, 15–17px instructions, monospace timing and directional values. |
| Copy | Real round data replaces concept placeholders; Observe/Decide, generated conditions, examples, and all actual controls remain code-native. |
| Art | Generated rain-window workshop, brighter physical metal detail, fixed tabletop, real interactive 3D modules and restrained dust. Geometry intentionally retains the tested socket layout rather than copying the conceptual device. |
| Icons | Consistent Lucide module symbols with both color and shape; original brand retained. |
| Responsive | Search and chapter selector remain usable on mobile, reading content scrolls; no horizontal overflow. |
| Interaction | New modules solved physically and through accessible controls; search, chapter switching, ambience level, mute, pause and blackout verified. |

Above-the-fold copy checked against the inventory: real mission names, variable
timer, player name and generated module list are intentional live data; the lobby
adds the approved functional explanation of ten randomly combined types. The
concept's decorative microphone is absent because communication uses existing
voice chat. No added figures or jumpscares. No unresolved clipping or interaction
defects in the checked desktop/mobile screens.
