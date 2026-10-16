# Version 1.1 image-generation prompts

Tool: built-in image_gen, original files retained in Codex generated_images.
Final project assets: `assets/horror-decals.png`, `assets/aged-plaster.png`.
Reference: `art/gameplay-v1.1-concept.png`. No reference raster is used as a room.

## Decal atlas (transparent_background=true)

Production texture atlas for a real 3D abandoned indoor playground horror game. 1536x1024 RGBA image, truly transparent background, no opaque background at all. Divide into a clean 2 columns x 2 rows grid with clear transparent margins between four independent flat surface decals. TOP LEFT: one irregular dark maroon dried blood smear with a dragged tail, small separated droplets, realistic dried texture and cracked edges, viewed perfectly top-down. TOP RIGHT: single adult-sized bloody palm print with five distinct smeared fingers and thin downward drips, frontal orthographic. BOTTOM LEFT: peeling old olive-gray paint, damp mold stains, small cracks and rusty dirty streaks in an irregular faded patch, mostly translucent, no background rectangular sheet. BOTTOM RIGHT: irregular fresh red blood pool splatter with tiny drops and darker coagulated center, perfectly top-down. These are surface marks only, no people, no body parts, no wounds, no text, no symbols, no drop shadows, no ambient lighting, no perspective, no floor surface behind the marks. Physically detailed material, not cartoon. Each mark completely within its own grid cell. Alpha edges clean and softly faded where needed. Used as alpha-cutout quad textures on 3D floor and wall geometry.

## Weathered plaster (transparent_background=false)

Seamless physically detailed albedo texture for a 3D horror game abandoned children's indoor playground wall: aged dirty pale sage and faded warm gray plaster, flaking cracked paint, irregular peeling layers revealing brownish plaster, small mildew spots, old damp water streaks, sparse scraps of faded colored crayon scribbles almost rubbed away. Perfectly flat front orthographic PBR base-color texture, evenly lit diffuse, no directional shadows or highlights, no perspective, no frame, no people, no text. Material should read at room scale 2 meters wide: mostly pale gray-green paint with 20 percent chipped irregular patches. Avoid giant cracks, avoid a comic style, avoid repetitive brick patterns. Tileable left/right top/bottom edges, 1536x1024. Creepy richly textured and believable used interior surface rather than plain color. This will replace clean flat plaster on actual 3D wall geometry, not be used as a room background.

## Gameplay art direction (transparent_background=false)

Create a practical real-time 3D game art-direction concept for NACHTWACHE
Kinderparadies v1.1: first-person night guard in an abandoned indoor children's
soft-play paradise, no people. Full 1536x1024 landscape game screen composition,
eye height 1.65m, architecture realistic scale. Important achievable Godot WebGL
art direction: rounded detailed modeled props and textured surfaces, not
photorealistic movie still. Left worn reception wood counter with papers, desk
lamp, abandoned shoes. Right huge padded tubular play frame with nets, rope
bridge, curved slide and colorful ball pit, with a seated worn plush bunny on a
bench beside it. Overhead pipes with joints and chains, hanging torn translucent
cloth, faded children's drawings and peeling paint. At rear paired green and red
emergency doors. Moody olive-gray low ground mist curling in layers, desaturated
teal shadows, small pools of amber lamps, white flashlight beam illuminates dust.
Damp scuffed floor, scattered physical toy balls, overturned small bucket,
wooden blocks. A dark maroon dried blood smear and sparse bloody shoe prints lead
toward the maintenance side, no bodies, no injured children, no gore. Dense
environmental storytelling and strong creepy atmosphere while retaining enough
visibility to inspect anomalies. Preserve minimal game HUD: top left NACHTWACHE
and Kinderparadies, top right SERIE 00 / 13, tiny crosshair, small controls bottom.
Do not invent extra menus/health bars. No square placeholder furniture, no
photographic textures stretched everywhere, no obvious flat 2D illustration.
Rounded plush fabric, folds, worn joints and distinct prop silhouettes. This is
an implementation reference for a fully playable 3D scene.
