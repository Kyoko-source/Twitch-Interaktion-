# Windows edition — art and rendering specification

User priority: flagship downloadable Windows version; Web may retain a lighter
rendering path. Approved direction: `gameplay-v1.1-concept.png`, with its tactile
soft-play materials, believable furnishings, deep warm/cold lighting and haze.
The native build must be judged from actual RTX 4080 captures, not a concept.

Native: Forward+, contact shadows, environment reflections, indirect illumination,
volumetric fog reacting to practical lights/torch, temporal antialiasing and a
carefully exposed warm/cold palette. Web: Compatibility, bounded original props
and shader fog. Gameplay, anomaly semantics and saves stay shared.

Assets: eight Poly Haven CC0 models (school chair, worn bookshelf, cardboard box,
articulated desk lamp, rubber duck, industrial pendant, metal office desk,
electrical box) with 2K diffuse, normal and packed ORM maps. Five CC0 PBR surface
sets replace the uniform floor/cloth/plaster response. Provider checksums and
source URLs are kept in `assets/polyhaven-provenance.json`.

Own hero assets are authored in Blender with UVs and sculpted irregular forms:
creased stitched plush rabbit, draped/torn fabric and upholstered seating. New
plush-fur albedo generated with built-in image_gen. Blender source generator is
versioned; portable Blender is a local build dependency, not shipped in the game.

Composition: make reception an inhabited workstation; add shelves, boxes and
believable lighting fixtures, a padded waiting corner, a less uniform play-frame
silhouette and rope details. Preserve the accessible four-area patrol and clear
red/green door recognition. Required UI changes: native graphics options and
accurate Windows/Web feature descriptions, no unrelated HUD or game modes.

Acceptance: actual GPU capture and performance sample, all existing patrol,
anomaly, save, jump and physics checks, native effect-quality toggles and clean
Web export without native asset payload. Compare layout, materials, props,
lighting, atmospheric depth and UI against the reference. Record remaining
differences honestly; don't call this a photographic match or an AAA production.

## Completed visual / functional review

The approved cinematic reference and actual GPU captures were inspected with
view_image. 1536x1024 was checked at the reference's native size. A second
exported-EXE capture requested 1920x1080; the Windows window manager constrained
the client viewport to 1920x1061, recorded explicitly in its report. Browser
validation uses Edge/Playwright because the Browser plugin is unavailable.

| Comparison | Actual implementation / deliberate limit |
| --- | --- |
| Composition | Counter left, play frame right, readable green/red exits; bunny moved beside the play frame to become visible in the primary patrol view. |
| Materials | Five 2K PBR sets and full imported model ORM/normal maps; cracked cave-like plaster was rejected for painted plaster with existing dirt decals. |
| Props | 32 placed instances from eight CC0 model types and four authored Blender GLBs; cloth folds, tailored ears, sewn belly, real rope geometry and detailed cake. |
| Lighting | Forward+ SDFGI/SSIL/SSAO, soft shadows, amber practicals and cold fill; wet floor SSR and room reflection probes. |
| Atmosphere | Participating-media fog responds to light; old unshaded mist/puddle approximations hidden on PC; native interior reverb. |
| UI and copy | Existing game HUD, controls and rules retained. Website explicitly labels its image as a native Windows capture and explains the reduced Web graphics. |
| Interaction | Exported EXE performs real movement/jump, all three quality profiles, pause/settings and three representative rendered anomalies. |

177 headless checks pass in the exported EXE. Six browser cases pass, including
the complete patrol, 13-win ending, wrong-choice reset, save/settings, real
jump/carry/throw/pause, release embed and mobile launcher. The QA Web export
reports Compatibility renderer and no native model asset. Shader/asset/runtime
errors found during iteration were fixed. A projected-texture flashlight exposed
a Godot atlas issue, so the stable soft spotlight is used with volume scattering.

RTX 4080 / Vulkan / High: stationary 180-frame sample about 102 FPS at
1920x1061, approximately 100 FPS at 1536x1024. This is a short warm sample,
not a worst-case frame-rate guarantee. No tests on other GPU families or at 4K.

Known engine shutdown warning: seven reflection-atlas texture RIDs on exit,
matching https://github.com/godotengine/godot/issues/122498. No associated runtime
error; repeated scene rebuilds leave the same seven-RID shutdown count.

The environment is still authored stylized real-time geometry. Its lighting and
material direction were checked against the reference, while the photographic
detail, exact prop placement and scale of a large studio production are not
claimed. The shipped launcher and final evidence use actual game captures.
