"""Snack bar machines, After Play 4.12.0.

slush-machine.glb: a granita / slush dispenser on the closed snack counter:
brushed steel base with vents and rubber feet, a rounded clear bowl with the
cooling drum and white auger spiral inside, a lumpy dried syrup crust at the
bottom (material "SlushCrust", tinted in the game), a grey lid, a front tap
with lever and red knob, and a drip tray with a grate.
napkin-dispenser.glb: a chrome napkin dispenser with a slanted face and a few
napkins sticking out.

Run: blender -b --python tools/model-after-play-slush-v4120.py   (Blender 5.0)
Output: games/kinderparadies/assets/snack-v4120/
Origin on the counter under the machine; front is Godot +Z (Blender -Y).
Bowl material "SlushBowl" is replaced by real glass in the game.
"""
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/snack-v4120'
OUT.mkdir(parents=True, exist_ok=True)
parts = []

def G(x, y, z): return (x, -z, y)

def material(name, color, rough=.5, metal=0.):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    return m

def finish(o, mat, smooth=True):
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = smooth
    parts.append(o); return o

def apply(o, kind, **kw):
    m = o.modifiers.new('m', kind)
    for k, v in kw.items(): setattr(m, k, v)
    bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier='m')

def box(c, s, mat, bev=.004, seg=2, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=G(*c), rotation=rot); o = bpy.context.object
    o.scale = (s[0], s[2], s[1]); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bev: apply(o, 'BEVEL', width=bev, segments=seg)
    return finish(o, mat, seg > 2)

def cyl(c, r, d, mat, axis='y', verts=24):
    rot = {'y': (0, 0, 0), 'z': (math.pi / 2, 0, 0), 'x': (0, math.pi / 2, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=G(*c), rotation=rot)
    return finish(bpy.context.object, mat)

def export(name):
    for o in bpy.data.objects: o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / name), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print(name, sum(len(o.data.polygons) for o in parts), 'faces')

# ---------------------------------------------------------------- slush machine
bpy.ops.wm.read_factory_settings(use_empty=True); parts = []
steel = material('SlushSteel', (.72, .73, .72), .32, .9)
dark = material('SlushDark', (.04, .04, .045), .6)
rubber = material('SlushRubber', (.03, .03, .03), .9)
bowl = material('SlushBowl', (.8, .85, .85), .05)
crust = material('SlushCrust', (.6, .2, .15), .85)
lid = material('SlushLid', (.25, .26, .27), .45)
white = material('SlushAuger', (.92, .92, .88), .4)
knob = material('SlushKnob', (.8, .1, .08), .3)
box((0, .145, 0), (.6, .27, .52), steel, .03, 4)
for i in range(8): box((-.2 + i * .057, .15, .262), (.024, .11, .006), dark, 0)
for x in (-.25, .25):
    for z in (-.21, .21): cyl((x, .006, z), .025, .012, rubber, verts=16)
# Drip tray with grate.
box((0, .02, .345), (.34, .03, .17), steel, .006, 2)
for i in range(7): box((-.13 + i * .043, .038, .345), (.01, .008, .15), dark, 0)
# Bowl, drum, auger.
b = box((0, .5, 0), (.4, .42, .46), bowl, .07, 6)
apply(b, 'SOLIDIFY', thickness=.006)
cyl((0, .43, -.02), .085, .38, steel, 'z', 32)
helix = []
for t in np.linspace(0, 1, 260):
    a = t * math.tau * 5.5
    helix.append(G(math.cos(a) * .105, .43 + math.sin(a) * .105, -.2 + t * .36))
cu = bpy.data.curves.new('auger', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = .009; cu.bevel_resolution = 2
sp = cu.splines.new('POLY'); sp.points.add(len(helix) - 1)
for p, q in zip(sp.points, helix): p.co = (*q, 1)
ob = bpy.data.objects.new('auger', cu); bpy.context.collection.objects.link(ob)
dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg)); bpy.data.objects.remove(ob)
au = bpy.data.objects.new('Auger', me); bpy.context.collection.objects.link(au); finish(au, white)
# Dried syrup crust: a lumpy slab at the bottom plus a dried tide line.
bpy.ops.mesh.primitive_cube_add(size=1, location=G(0, .35, 0)); c = bpy.context.object
c.scale = (.37, .43, .12); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
apply(c, 'BEVEL', width=.03, segments=3); apply(c, 'SUBSURF', levels=2)
tex = bpy.data.textures.new('lumps', 'CLOUDS'); tex.noise_scale = .05
apply(c, 'DISPLACE', texture=tex, strength=.035, mid_level=.5)
finish(c, crust)
for z in (-.215, .215):
    box((0, .43, z), (.37, .03, .004), crust, 0)
# Lid and tap.
box((0, .735, 0), (.42, .05, .48), lid, .02, 3)
box((0, .77, -.05), (.16, .02, .2), lid, .01, 2)
box((0, .33, .25), (.11, .08, .06), steel, .012, 3)
cyl((0, .28, .27), .016, .05, steel, 'y', 16)
bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=.011, depth=.16, location=G(0, .44, .275), rotation=(math.radians(-15), 0, 0)); finish(bpy.context.object, dark)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=.024, location=G(0, .52, .295)); finish(bpy.context.object, knob)
export('slush-machine.glb')

# ---------------------------------------------------------------- napkin dispenser
bpy.ops.wm.read_factory_settings(use_empty=True); parts = []
chrome = material('NapkinChrome', (.82, .82, .84), .18, 1.)
paper = material('NapkinPaper', (.93, .91, .86), .95)
box((0, .07, 0), (.26, .14, .17), chrome, .015, 3)
box((0, .145, -.015), (.24, .02, .12), chrome, .008, 2, rot=(math.radians(18), 0, 0))
for i, (dx, tilt) in enumerate(((-.02, .2), (.01, -.1), (.03, .35))):
    box((dx, .075 + i * .004, .095), (.16, .002, .07), paper, 0, rot=(math.radians(70 + i * 6), 0, tilt))
box((0, .002, 0), (.27, .004, .18), material('NapkinFoot', (.05, .05, .05), .9), 0)
export('napkin-dispenser.glb')
