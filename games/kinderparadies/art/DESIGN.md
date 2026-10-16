# NACHTWACHE — Kinderparadies

Original Windows and Web 3D anomaly game. First-person adult night guard,
dark closed indoor soft-play facility, green door for normal, red for anomaly,
thirteen consecutive correct inspections. WASD/mouse, desktop-first.

Concepts: `gameplay-concept.png` (1536×1024) and `menu-concept.png` (1536×1024).
Own generated production assets: padded vinyl, worn rubber floor, painted plaster,
oak countertop, original moon/castle mural, and two-door app icon. Exact prompts
are in `PROMPTS.md`. Raster concepts are never used as a static playable scene.

Palette: petroleum #071014, aged warm ivory #eee7d6, padded navy #294d70,
coral #974442, mustard #b49842, teal #3c7370. Light comes from warm pendants,
cool emergency spill, colored exit signs and a real shadow-casting flashlight.
Oswald headings, built-in Noto Sans body, restrained grain and vignette.

Scene plan: reception on the left of the entrance patrol corridor, climbing
structure and ball pit to the right; party room behind the structure and
maintenance/mural zone on the left at the back. Adjacent red/green exits at
the rear. Geometry includes beveled furniture, padded cylindrical posts,
safety nets, curved slide, instanced colored balls, tube windows, ventilation,
ceiling trusses, papers, keyboard, pens, shoes, signage, balloons and chairs.
Major furniture and walls collide with the actual CharacterBody3D player.

Above-the-fold UI inventory: NACHTWACHE, Kinderparadies, SERIE 00/13,
four inspection names, initial reference-round instruction, crosshair, keyboard
help and contextual E prompt. Menu: Neue Nachtschicht, Schicht fortsetzen,
Einstellungen, Dienstanweisung, Spiel beenden (native) / Zur Webseite (web).
No health bars, countdown, online economy, account gate or extra game modes.

Implementation constraints: true shared Godot geometry and GDScript on Windows
and WebGL; the map is built as actual meshes with generated material textures.
This is intentionally a compact authored facility rather than the exact prop
placement of the raster concept. Instanced tiles/balls and optional shadows keep
Web export viable. No photorealism claim or baked concept image masquerading as
3D. Anomalies are authored visual changes to that same normal baseline.
The UI says SERIE instead of RUNDE to accurately communicate consecutive wins.

Validation covers catalog, randomization, saved RNG, thirteen-in-a-row ending,
wrong-choice reset, real movement/floor collisions, checkpoint visits and both
door raycasts. Separate QA Web build enables automated scene setup; release
exports have no callable QA bridge or anomaly ID. Native headless tests use
separate QA saves. Browser screenshots are stored outside the repository.

## Final visual and interaction review

Concepts and rendered screenshots inspected with view_image at 1536×1024.
The website launcher was also inspected at 390×844. The in-game target is desktop
with mouse/keyboard, so the mobile launcher explains that requirement.

| Comparison | Result |
| --- | --- |
| Composition | Reception left, play structure right, paired exits at rear, minimal first-person HUD. |
| Typography | Oswald game headings, readable body text, clear 13-in-a-row counter. |
| Palette | Aged ivory, navy/coral/mustard padding, warm lamps, cool spill, distinct red/green exits. |
| Art/materials | Own vinyl, plaster, oak, rubber and mural assets on real beveled/curved meshes. |
| UI copy | Menu and control inventory preserved; SERIE clarifies consecutive wins; real feedback and ending added as required by the game loop. |
| Responsive | Website download/launch screen fits mobile; gameplay retains desktop controls. |
| Interaction | Full WASD patrol, four checkpoints, both physical door raycasts, wrong reset, 13-win ending, pause, flashlight and persisted settings. |

Intentional visual deviation: the raster art is cinematic reference, while the
shipping environment is an authored stylized real-time Godot scene with a fixed
WebGL performance budget. It does not reproduce the reference's photographic
detail or exact furniture placement. Its real gameplay is shown honestly in
the website preview. No static concept image is presented as a playable world.
The too-narrow patrol passage found during testing was widened. Camera/menu,
door fade timing, save recovery and runtime audio cleanup were verified.
No blank screens, framework overlays or app console errors in the final five
browser scenarios. Native exported executable passed 129 headless validations;
rendered graphical QA was performed in Edge/WebGL, not across different PC GPUs.
