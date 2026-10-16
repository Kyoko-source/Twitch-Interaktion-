# Crocodile redesign

Built-in `image_gen` mode was used for these three raster inputs. Selected
images were copied into the workspace; the concept is a reference only.

- Concept: `art/crocodile-redesign-concept.png`
- Skin: `assets/creatures/aged-croc-pvc.png`
- Iris: `assets/creatures/croc-eye.png`
- Runtime 3D model: `assets/creatures/night-crocodile.glb`
- Geometry authoring: `tools/model-nachtwache-crocodile-v2.py`

Godot's extracted `night-crocodile_*.png` textures are runtime dependencies.
Raw authoring PNGs and the legacy model are excluded from release packages.
The same body, upper jaw and eye geometry is included in Web and Windows.
Windows retains its separate indirect lighting, shadows and fog renderer.

## Concept prompt

Create one highly specific production concept for an ORIGINAL 3D game prop: a gigantic abandoned inflatable crocodile bounce attraction inside a dark derelict children's indoor soft-play centre at night. No people. The attraction must LOOK unmistakably like a crocodile with a long broad flattened wedge snout, thick creased brow, SMALL recessed reptilian eyes on the sides under overhanging lids (absolutely no stalked, bulging or googly eyes), an unsettling asymmetric dead stare, and a tall gaping mouth entrance between upper and lower jaw that opens into its long padded inflatable jumping bed. Industrial heat-welded PVC chambers and heavy welded seams, faded olive paint, old yellowed belly mattress, realistic soft wrinkles at joins, frayed warning label and grimy patches, scratched painted scales, a few dark reddish stains along irregular tapered soft rubber teeth, torn superficial patches revealing dark backing. Menacing yet clearly an abandoned manufactured kids attraction, not a biological monster, not a smiling toy frog. Thick upper jaw remains readable in silhouette. Shape should be buildable as a medium-complexity UV mapped real-time mesh, avoid fine hair, complex fur or impossible detail. Three-quarter frontal eye-level view in torch light, enough dim cold ambient fill to read the entire object, slight warm light in distance. 4m broad mouth, about 3m tall and 10m long, believable human scale. No typography/HUD, no illustration frame, no extra mascots. Strong art direction, tactile materials, unsettling horror game production design.

## Skin prompt

A seamless repeatable flat ALBEDO material texture for a real-time 3D horror-game inflatable crocodile attraction. Fill entire square image with worn dark olive green industrial PVC fabric coating, age-faded yellow olive rubbed patches, hairline cracked printed reptile scale pattern (large irregular broad crocodile scutes printed in slightly darker green, NOT raised biological skin), shallow dense textile wrinkles, rubbed black grime at scattered spots, scattered small beige scratches and scuffed chipped coating revealing darker backing. Physically plausible manufactured rubberized fabric, old abandoned 1990s children's attraction. Fine tactile microdetail. Flat neutral even illumination; no directional light, no cast shadows, no 3D perspective, no object outlines, no eyes, teeth, animals or typography. Do not bake strong specular highlights or ambient shadows. Low contrast mottled olive-green overall; seamlessly tileable on all edges.

## Iris prompt

A square high-resolution production ALBEDO texture of a single eerie crocodile iris and narrow vertical black slit pupil, viewed perfectly straight on, orthographic, centered and filling the frame. The iris is desaturated dirty amber and olive with intricate fine radial fibres, uneven muddy concentric pigment rings, worn cracked lacquer appearance like a very realistic old glass eye embedded in an abandoned horror animatronic/inflatable mascot. Pupil is deep nearly black, thin vertical slit, sharp but organic edges. Dark charcoal limbal ring at the outer edge. No white sclera, no eyelids, no skin, no eyebrow, no face, no text, no environment, no tears. Extremely subtle neutral flat diffuse illumination, NO painted specular highlight or directional shadow; runtime engine supplies reflections. Completely circular iris takes almost the entire square, dark charcoal corners. The unsettling dead eye should look tangible and realistic rather than a cartoon or neon glowing eye.

## Implementation / comparison

The full muzzle, convex corneal caps, irregular tapered teeth, welded lips,
separate jaw hinge, skin wear and pressure-chamber bed are real geometry and
textures. Uniform triplanar texel density replaces stretched skin on pillars.
Front, three-quarter and close views are reviewed in both renderers. The
cinematic reference has richer photographic wear and lighting; the game uses
an authored, stylized real-time mesh and is not presented as a photographic
match. The legacy Web shape lacked its entire upper muzzle and is replaced.
