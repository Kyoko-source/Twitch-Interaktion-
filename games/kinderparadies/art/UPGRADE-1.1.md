# Kinderparadies 1.1 — abandoned soft-play facility

User brief: replace the clean geometric impression with a substantially more
detailed frightening place; jumping, real physics, blood and denser fog in both
native Windows and Web. Existing four-area patrol and 13-in-a-row rules remain.

Reference: `gameplay-v1.1-concept.png`. Olive-gray peeling plaster, worn navy,
mustard and coral padding, aged wood, amber practicals against cold teal spill.
Layered low mist, flashlight-lit dust, cloth hanging under pipes, mesh netting,
rounded stitched plush bunny, small scattered toys, cups and abandoned papers.
Green/red exit signage remains readable through the haze. The reference is
direction for real geometry/materials, never a flat background in gameplay.

Assets: built-in image generation produced `aged-plaster.png` and the transparent
2x2 `horror-decals.png` (dried smear, handprint, damp peeling patch, blood pool).
Atlas regions are sampled on alpha quads: supported in WebGL as well as native.
Existing vinyl, wood, floor and mural images remain production materials.
Material micro-normal detail, mist and dust are shader-native supplements;
sculpted props are real multi-part 3D meshes with matching physical collision.

Visible UI inventory remains NACHTWACHE, Kinderparadies, SERIE, four inspection
areas, contextual prompt, notice and controls. Required additions: SPACE jump,
G pick up/drop, left mouse throw, updated baseline instructions. No new health
bar or unrelated horror mechanic. Menu/layout/type remain consistent with v1.0.

Physics: continuous-collision rigid balls, wooden blocks, bucket and plush toy;
spring-force carry with wall obstruction check, impulse throw, character push,
floor-only jump, and frozen simulation during pause. Props reset on a new round;
moving a prop yourself is explicitly not an anomaly. World transition drops held
objects before freeing the old scene. Saves preserve patrol/RNG compatibility.

Blood: baseline has a fixed old dried smear in maintenance, described in notes.
New wet trails, handprints, bloody pool, bleeding mural, inverted bunny and
excess fog are separate shuffled anomalies. No injured children or bodies.

Performance: retain instanced decorative pit balls; only loose objects have
rigid bodies. Bounded mist/dust instances, cached geometry, optional shadows,
and no unsupported volumetric-fog dependency in the Compatibility renderer.

## Render comparison and QA

Reference and actual 1536x1024 screenshots inspected with view_image. The shipped
scene follows the reference's aging, environmental detail, tactile toys and
amber/teal horror direction. It intentionally remains a stylized real-time scene,
not a pixel-identical photographic recreation of the cinematic reference.

| Point | Rendered evidence / decision |
| --- | --- |
| Layout | Retained counter left, soft-play frame right, red/green exits rear; patrol remains navigable. |
| Palette | Olive plaster, subdued navy/coral/mustard padding, amber practicals, cool spill. |
| Materials | Generated peeling plaster, wood/vinyl and micro-normal detail; atlas UV bug fixed on actual 3D mesh. |
| Props | Stitched multi-part bunny, rocking horse, rope bridge, hanging rollers, phone, desk lamp and tableware. |
| Atmosphere | Dense distance fog, soft ellipsoid ground clouds and dust; hard horizontal fog planes removed. |
| UI/type | Existing Oswald/HUD preserved; only requested jump and physics controls added. Reference's invented R/C controls rejected in favor of actual E/G/Space inputs. |
| Blood | Darkened atlas tint and varied stain sizes/rotations prevent glowing uniformly repeated marks. |
| Interaction | Real floor-aligned collision, jump/landing without double jump, raycast G pickup, spring force carry, mouse impulse throw and paused rigid bodies. |

Above-the-fold copy diff: only Space/G/LMB control hints added, as required by
the user. Notes describe baseline stains and self-moved objects so the visual
upgrade doesn't make normal rounds unfair. Launcher now states 36 anomalies.

Windows exported EXE passes 160 headless checks. Six Playwright/Edge scenarios
cover actual patrol, both doors/13-win ending, settings and save, jump and prop
physics, release Web embed and native ZIP, plus mobile launcher (390x844).
Browser plugin unavailable; existing Playwright workflow used. Native graphical
performance across different GPUs and browsers other than Edge remain untested.

The bulk of the pit's decorative balls remain instanced; the 28 loose toys are
the bounded rigid-body set. Fog clouds are shader-based surface volumes with
distance fog, not physically simulated participating-media fog or soft bodies.
