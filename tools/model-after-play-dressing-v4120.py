"""Costume room dressing, After Play 4.12.0.

vanity-clutter.glb: what is left on the backstage make-up counter: a face-paint
palette (one pan dug empty), an open powder compact with its puff, a ceramic
cup of brushes, a hairspray can, a lipstick with its cap off, and a foam wig
head wearing a curly orange clown wig.
sewing-machine.glb: an old black cast-iron sewing machine on a walnut plinth,
swan-neck arm with gold pinstripes, chrome face plate, needle bar and presser
foot, a hand wheel, spool pin with red thread.

Run: blender -b --python tools/model-after-play-dressing-v4120.py   (Blender 5.0)
Output: games/kinderparadies/assets/costume-v4120/
Blender up +Z; Godot front (+Z) is Blender -Y.
vanity-clutter: origin on the counter top. sewing-machine: origin under the bed
centre, the guard sees its +Y side (Godot -Z).
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/costume-v4120'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(41201)
parts = []

def reset():
    global parts
    bpy.ops.wm.read_factory_settings(use_empty=True); parts = []

def material(name, color, rough=.5, metal=0., emit=0.):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1)
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    return m

def finish(o, mat, smooth=True):
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = smooth
    parts.append(o); return o

def bevel(o, width, seg=2):
    m = o.modifiers.new('b', 'BEVEL'); m.width = width; m.segments = seg; m.limit_method = 'ANGLE'
    bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier='b')

def box(loc, size, mat, bev=.003, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot); o = bpy.context.object
    o.scale = size; bpy.ops.object.transform_apply(scale=True)
    if bev: bevel(o, bev)
    return finish(o, mat, False)

def cyl(loc, r, h, mat, rot=(0, 0, 0), verts=24, r2=None):
    if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else: bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    return finish(bpy.context.object, mat)

def ball(loc, r, mat, scale=(1, 1, 1), seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc); o = bpy.context.object
    o.scale = scale; bpy.ops.object.transform_apply(scale=True); return finish(o, mat)

def rod(a, b, r, mat, verts=10):
    a, b = Vector(a), Vector(b); d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = d.to_track_quat('Z', 'Y'); return finish(o, mat)

def curve(pts, radius, mat, flat=1.):
    cu = bpy.data.curves.new('c', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = radius; cu.bevel_resolution = 2
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts): p.co = (*q, 1)
    ob = bpy.data.objects.new('c', cu); bpy.context.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg)); bpy.data.objects.remove(ob)
    o = bpy.data.objects.new('curve', me); bpy.context.collection.objects.link(o); return finish(o, mat)

def export(name):
    for o in bpy.data.objects: o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / name), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print(name, sum(len(o.data.polygons) for o in parts), 'faces')

# ------------------------------------------------------------------ make-up counter
reset()
plastic = material('PaletteBlackPlastic', (.06, .06, .065), .45)
pans = [(.95, .94, .9), (.78, .12, .12), (.04, .04, .04), (.95, .78, .15), (.15, .3, .75), (.2, .6, .3), (.92, .5, .6), (.45, .28, .15)]
# Face-paint palette, two rows of four pans; the white one dug almost empty.
box((-.55, -.02, .011), (.23, .125, .022), plastic, .004)
for i, col in enumerate(pans):
    x = -.55 + ((i % 4) - 1.5) * .053; y = -.02 + (.028 if i < 4 else -.028)
    depth = .0035 if i == 0 else .0012
    cyl((x, y, .0225 - depth), .021, .004, material(f'FacePaint{i}', col, .35 if i != 2 else .2), verts=20)
    cyl((x, y, .0212), .0225, .0015, plastic, verts=20)
# Open powder compact with mirror lid and puff.
gold = material('CompactBrass', (.75, .58, .3), .35, .9)
cyl((-.25, .0, .007), .042, .014, gold, verts=32)
cyl((-.25, .0, .0145), .036, .002, material('PressedPowder', (.86, .72, .6), .9), verts=32)
lid = cyl((-.25, .043, .05), .042, .006, gold, rot=(math.radians(-100), 0, 0), verts=32)
cyl((-.25, .0405, .05), .036, .001, material('CompactMirror', (.9, .9, .92), .04, 1.), rot=(math.radians(-100), 0, 0), verts=32)
ball((-.17, -.04, .009), .028, material('PowderPuff', (.92, .82, .78), .95), scale=(1, 1, .32))
# Ceramic brush cup with five brushes.
cup = material('CupCeramic', (.82, .8, .74), .3)
bpy.ops.mesh.primitive_cylinder_add(vertices=28, radius=.034, depth=.095, location=(.1, .07, .0475)); c = bpy.context.object
bm = bmesh.new(); bm.from_mesh(c.data); top = [f for f in bm.faces if f.normal.z > .9]; bmesh.ops.delete(bm, geom=top, context='FACES'); bm.to_mesh(c.data); bm.free()
s = c.modifiers.new('s', 'SOLIDIFY'); s.thickness = .004; bpy.context.view_layer.objects.active = c; bpy.ops.object.modifier_apply(modifier='s'); finish(c, cup)
handle = material('BrushHandle', (.15, .08, .05), .4); ferrule = material('BrushFerrule', (.7, .7, .72), .3, 1.); bristle = material('BrushBristle', (.55, .42, .3), .9)
for k in range(5):
    a = k / 5 * math.tau; tilt = .18 + .1 * (k % 2)
    base = Vector((.1 + math.cos(a) * .012, .07 + math.sin(a) * .012, .01))
    d = Vector((math.cos(a) * tilt, math.sin(a) * tilt, 1)).normalized()
    rod(base, base + d * .15, .0042, handle, 8)
    rod(base + d * .15, base + d * .175, .0048, ferrule, 8)
    tip = .035 if k % 2 else .022
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=.006 + .004 * (k % 3 == 0), radius2=.001, depth=tip, location=base + d * (.175 + tip / 2))
    o = bpy.context.object; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = d.to_track_quat('Z', 'Y'); finish(o, bristle)
# Hairspray can.
can = material('HairsprayCan', (.6, .15, .5), .35, .6)
cyl((.36, .1, .09), .029, .18, can, verts=28)
cyl((.36, .1, .186), .024, .014, material('CanShoulder', (.75, .75, .78), .3, 1.), verts=28, r2=.012)
cyl((.36, .1, .2), .009, .014, material('CanNozzle', (.9, .9, .88), .5), verts=16)
cyl((.36, .1, .093), .0292, .07, material('CanLabel', (.92, .88, .8), .5), verts=28)
# Lipstick, cap off, lying beside.
lip_case = material('LipstickCase', (.75, .58, .3), .3, .9)
cyl((0, -.09, .025), .009, .05, lip_case, verts=16)
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=.0072, depth=.018, location=(0, -.09, .058)); bul = bpy.context.object
for v in bul.data.vertices:
    if v.co.z > 0: v.co.z -= v.co.y * .9 + .004
finish(bul, material('LipstickRed', (.7, .05, .08), .3))
cyl((.045, -.11, .0095), .0095, .045, lip_case, rot=(0, math.radians(90), .4), verts=16)
# Foam wig head with a curly orange clown wig.
foam = material('FoamHead', (.85, .84, .8), .95)
cyl((.72, .03, .012), .055, .024, foam, verts=24)
cyl((.72, .03, .07), .03, .1, foam, verts=20, r2=.038)
head = ball((.72, .03, .21), .1, foam, scale=(.8, .9, 1.15), seg=32)
ball((.72, -.052, .2), .014, foam, scale=(.8, 1, 1.3))
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=.125, location=(.72, .045, .25)); wig = bpy.context.object
tex = bpy.data.textures.new('curls', 'VORONOI'); tex.noise_scale = .022
d = wig.modifiers.new('d', 'DISPLACE'); d.texture = tex; d.strength = .035; d.mid_level = .2
bpy.context.view_layer.objects.active = wig; bpy.ops.object.modifier_apply(modifier='d')
bm = bmesh.new(); bm.from_mesh(wig.data)
cut = [v for v in bm.verts if (v.co.z < -.02) or (v.co.y < -.04 and v.co.z < .06)]
bmesh.ops.delete(bm, geom=cut, context='VERTS'); bm.to_mesh(wig.data); bm.free()
for side in (-1, 1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=.075, location=(.72 + side * .1, .04, .2)); tuft = bpy.context.object
    d = tuft.modifiers.new('d', 'DISPLACE'); d.texture = tex; d.strength = .03; d.mid_level = .2
    bpy.context.view_layer.objects.active = tuft; bpy.ops.object.modifier_apply(modifier='d'); finish(tuft, bpy.data.materials.get('ClownWig') or material('ClownWig', (.9, .35, .08), .85))
finish(wig, bpy.data.materials['ClownWig'])
export('vanity-clutter.glb')

# ------------------------------------------------------------------ sewing machine
reset()
iron = material('MachineBlackEnamel', (.035, .035, .038), .28, .2)
chrome = material('MachineChrome', (.8, .8, .82), .18, 1.)
goldline = material('MachineGoldDecal', (.85, .65, .28), .35, .8)
walnut = material('MachinePlinthWalnut', (.36, .2, .1), .55)
box((0, 0, .015), (.66, .34, .03), walnut, .006)
box((0, 0, .06), (.62, .30, .06), iron, .012)
box((-.2, -.02, .0915), (.16, .1, .003), chrome, .001)
# Swan-neck arm: an extruded silhouette with rounded edges.
outline = [(.27, .09), (.27, .33), (.255, .39), (.2, .425), (.05, .435), (-.2, .43), (-.265, .415), (-.29, .38), (-.29, .26), (-.17, .26),
           (-.17, .305), (.1, .31), (.135, .29), (.14, .09)]
bm = bmesh.new(); vs = [bm.verts.new((x, -.065, z)) for x, z in outline]; f = bm.faces.new(vs)
r = bmesh.ops.extrude_face_region(bm, geom=[f]); bmesh.ops.translate(bm, verts=[e for e in r['geom'] if isinstance(e, bmesh.types.BMVert)], vec=(0, .13, 0))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new('arm'); bm.to_mesh(me); bm.free(); arm = bpy.data.objects.new('arm', me); bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm; arm.select_set(True)
m = arm.modifiers.new('b', 'BEVEL'); m.width = .018; m.segments = 4; bpy.ops.object.modifier_apply(modifier='b')
finish(arm, iron)
# Gold pinstripes inset on both side faces, following the silhouette.
inner = [(.25, .1), (.25, .33), (.235, .38), (.19, .41), (.05, .418), (-.19, .414), (-.25, .4), (-.27, .37)]
for y in (-.0665, .0665):
    curve([(x, y, z) for x, z in inner], .0022, goldline)
    for k in range(3):
        cx = -.08 + k * .09
        curve([(cx + math.cos(t) * .022, y, .37 + math.sin(t) * .022) for t in np.linspace(0, math.tau * .85, 24)], .0016, goldline)
# Head: chrome face plate, needle bar, needle, presser foot, tension disc.
box((-.295, 0, .33), (.012, .1, .12), chrome, .004)
rod((-.235, -.02, .27), (-.235, -.02, .17), .006, chrome)
rod((-.235, -.02, .17), (-.235, -.02, .115), .0015, chrome, 6)
rod((-.215, -.02, .27), (-.215, -.02, .13), .004, chrome)
box((-.215, -.02, .1), (.05, .02, .008), chrome, .002)
cyl((-.297, -.03, .36), .016, .008, chrome, rot=(0, math.radians(90), 0), verts=20)
# Hand wheel and bobbin winder.
cyl((.295, 0, .34), .09, .035, iron, rot=(0, math.radians(90), 0), verts=40)
cyl((.315, 0, .34), .092, .008, chrome, rot=(0, math.radians(90), 0), verts=40)
cyl((.32, 0, .34), .022, .02, chrome, rot=(0, math.radians(90), 0), verts=20)
cyl((.19, .04, .455), .018, .01, chrome, rot=(math.radians(90), 0, 0), verts=20)
# Spool pin with red thread, the thread running to the head.
rod((.06, 0, .43), (.06, 0, .5), .003, chrome, 8)
cyl((.06, 0, .46), .017, .036, material('ThreadRed', (.7, .08, .08), .8), verts=20)
for z in (.441, .479): cyl((.06, 0, z), .02, .004, walnut, verts=20)
curve([(.06, -.017, .465), (-.05, -.068, .44), (-.29, -.06, .36), (-.24, -.025, .26)], .0007, bpy.data.materials['ThreadRed'])
export('sewing-machine.glb')
