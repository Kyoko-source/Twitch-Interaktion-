"""Prize plush bunny for the arcade prize cabinet, After Play 4.12.0.

A sitting plush rabbit about 34 cm tall: pear-shaped body, round head with
fat cheeks, one upright and one floppy ear with lighter inner felt, stubby
arms, big oval feet with pads, a pom-pom tail, black button eyes, a pink felt
nose and a stitched smile. Materials: "PlushFur" (tinted in the game),
"PlushInner", "PlushButton", "PlushNose", "PlushStitch".

Run: blender -b --python tools/model-after-play-prize-bunny-v4120.py   (Blender 5.0)
Output: games/kinderparadies/assets/arcade-v4120/prize-bunny.glb
Origin on the shelf under the body; front is Godot +Z (Blender -Y).
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/arcade-v4120'
bpy.ops.wm.read_factory_settings(use_empty=True)
parts = []

def material(name, color, rough=.9):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1); b.inputs['Roughness'].default_value = rough
    return m

FUR = material('PlushFur', (.85, .8, .72)); INNER = material('PlushInner', (.95, .78, .78))
BUTTON = material('PlushButton', (.02, .02, .02), .2); NOSE = material('PlushNose', (.85, .45, .5)); STITCH = material('PlushStitch', (.15, .08, .08))

def blob(loc, scale, mat, rot=(0, 0, 0), sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=loc, rotation=rot); o = bpy.context.object
    o.scale = scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    m = o.modifiers.new('s', 'SUBSURF'); m.levels = 1; bpy.ops.object.modifier_apply(modifier='s')
    o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = True
    parts.append(o); return o

# Body and head.
blob((0, 0, .1), (.085, .075, .1), FUR)
blob((0, -.005, .225), (.075, .068, .068), FUR)
for s in (-1, 1):
    blob((s * .04, -.045, .205), (.032, .025, .028), FUR)          # cheeks
    blob((s * .07, -.035, .12), (.025, .022, .045), FUR, rot=(0, s * .5, 0))   # arms
    blob((s * .045, -.07, .025), (.035, .055, .025), FUR)          # feet
    blob((s * .045, -.122, .028), (.022, .006, .016), INNER, sub=1)  # foot pads
    blob((s * .03, -.062, .24), (.011, .006, .011), BUTTON, sub=1)    # button eyes
# Ears: right one stands, left one flops over.
ear = blob((.03, .0, .335), (.022, .012, .07), FUR, rot=(0, .15, 0)); blob((.03, -.008, .335), (.014, .006, .055), INNER, rot=(0, .15, 0), sub=2)
fl = blob((-.075, -.005, .27), (.022, .012, .065), FUR, rot=(0, -2.0, 0)); blob((-.075, -.013, .27), (.014, .006, .05), INNER, rot=(0, -2.0, 0), sub=2)
blob((0, -.07, .218), (.012, .008, .009), NOSE, sub=1)
blob((0, .075, .07), (.03, .03, .03), INNER)   # pom-pom tail
# Stitched smile.
for k in range(7):
    a = math.radians(-60 + k * 20); p = Vector((math.sin(a) * .022, -.071 + abs(math.sin(a)) * .006, .2 - math.cos(a) * .008))
    blob(p, (.0035, .0025, .0018), STITCH, sub=1)
for o in bpy.data.objects: o.select_set(o in parts)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.export_scene.gltf(filepath=str(OUT / 'prize-bunny.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print('bunny', sum(len(o.data.polygons) for o in parts), 'faces')
