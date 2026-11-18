"""Costume room upgrade, After Play 4.12.0.

Empty mascot suits that hang limp from a wooden hanger: a skin-modifier body
(torso, arms with mittens, legs with big feet) is deflated with a cloth
simulation (pinned at the shoulders, negative pressure, gravity, floor
collision), so the fabric folds, the belly sags and the feet crumple on the
floor. Three variants. Plus a wooden hanger with a steel hook over the rail.

Run: blender -b --python tools/model-after-play-costume-room-v4120.py   (Blender 5.0)
Output: games/kinderparadies/assets/costume-v4120/hanging-suit-{a,b,c}.glb
Blender up +Z, front -Y. Origin = costume root (Godot local), floor at z -0.04,
rail at z 2.54 / y +0.03.
Material names: "canvas" gets the plush fur + tint in the game, "walnut" wood.
"""
import math, sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/costume-v4120'
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW = '--preview' in sys.argv

def material(name, color, rough=.9, metal=0.):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    return m

def skeleton(variant):
    rng = np.random.default_rng(4120 + variant)
    j = lambda *a: rng.normal(0, .012, 3) + np.array(a)
    pts, rad, edges = [], [], []
    def add(p, r, parent=None):
        pts.append(p); rad.append(r)
        if parent is not None: edges.append((parent, len(pts) - 1))
        return len(pts) - 1
    neck = add(j(0, 0, 1.63), (.15, .12))
    chest = add(j(0, 0, 1.40), (.31, .21), neck)
    belly = add(j(0, -.02, 1.05), (.31, .23), chest)
    hips = add(j(0, 0, .78), (.27, .19), belly)
    for s in (-1, 1):
        fwd = -.06 if (variant == 1 and s == 1) else 0
        sh = add(j(s * .31, 0, 1.52), (.12, .11), chest)
        el = add(j(s * .39, -.02 + fwd, 1.16), (.105, .10), sh)
        wr = add(j(s * .41, -.04 + fwd * 2, .86), (.09, .09), el)
        add(j(s * .42, -.07 + fwd * 2, .73), (.12, .085), wr)
        hp = add(j(s * .15, 0, .70), (.145, .14), hips)
        kn = add(j(s * .17, -.01, .40), (.13, .13), hp)
        an = add(j(s * .17, 0, .13), (.12, .12), kn)
        add(j(s * .17, -.15, .06), (.14, .09), an)
    return pts, rad, edges

def body(variant):
    pts, rad, edges = skeleton(variant)
    me = bpy.data.meshes.new('skel'); me.from_pydata([tuple(p) for p in pts], edges, []); me.update()
    o = bpy.data.objects.new('Suit', me); bpy.context.collection.objects.link(o)
    sk = o.modifiers.new('skin', 'SKIN')
    for i, v in enumerate(me.skin_vertices[0].data): v.radius = rad[i]
    me.skin_vertices[0].data[0].use_root = True
    sub = o.modifiers.new('sub', 'SUBSURF'); sub.levels = 2
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); o.modifiers.clear(); o.data = mesh
    # Pin the shoulder line that rests on the hanger.
    pin = o.vertex_groups.new(name='pin')
    for v in mesh.vertices:
        w = 1. if v.co.z > 1.5 and abs(v.co.x) < .40 else 0.
        if w: pin.add([v.index], w, 'REPLACE')
    return o

def simulate(o, variant):
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, -.04)); floor = bpy.context.object
    floor.modifiers.new('col', 'COLLISION')
    cl = o.modifiers.new('Cloth', 'CLOTH'); s = cl.settings
    s.quality = 8; s.mass = .5; s.air_damping = 2.
    s.tension_stiffness = 15; s.compression_stiffness = 2; s.shear_stiffness = 4; s.bending_stiffness = .03 + variant * .02
    s.vertex_group_mass = 'pin'; s.pin_stiffness = 1.
    s.use_pressure = True; s.uniform_pressure_force = -(9 + variant * 3); s.pressure_factor = 1.
    s.shrink_min = -.06  # excess fabric: it has to fold
    c = cl.collision_settings; c.use_collision = True; c.distance_min = .006
    c.use_self_collision = True; c.self_distance_min = .006; c.collision_quality = 3
    frames = 130
    bpy.context.scene.frame_start = 1; bpy.context.scene.frame_end = frames; cl.point_cache.frame_end = frames
    for f in range(1, frames + 1): bpy.context.scene.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); o.modifiers.clear(); o.data = mesh
    bpy.data.objects.remove(floor)

def dress(o, mats):
    o.data.materials.clear()
    for m in mats: o.data.materials.append(m)
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    # Open the neck: the mask sits on it, the two headless suits show the hole.
    top = max(v.co.z for v in bm.verts)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > top - .045 and abs(f.calc_center_median().x) < .16], context='FACES')
    for f in bm.faces:
        c = f.calc_center_median(); f.smooth = True
        f.material_index = 0
    bm.to_mesh(o.data); bm.free()
    so = o.modifiers.new('thick', 'SOLIDIFY'); so.thickness = .012; so.offset = 1; so.material_offset = 1; so.use_rim = True
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); o.modifiers.clear(); o.data = mesh

def hanger(wood, steel):
    parts = []
    def curve(name, pts, radius, mat, rect=None):
        cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = radius; cu.bevel_resolution = 3
        sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
        for p, q in zip(sp.points, pts): p.co = (*q, 1)
        ob = bpy.data.objects.new(name, cu); bpy.context.collection.objects.link(ob)
        if rect: ob.scale = (1, rect, 1)
        dg = bpy.context.evaluated_depsgraph_get(); mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        bpy.data.objects.remove(ob); res = bpy.data.objects.new(name, mesh); bpy.context.collection.objects.link(res)
        res.data.materials.append(mat)
        for p in res.data.polygons: p.use_smooth = True
        parts.append(res)
    arm = [(x, 0, 1.585 + .06 * math.cos(x / .36 * math.pi / 2) ** 1.4) for x in np.linspace(-.35, .35, 24)]
    curve('HangerArm', arm, .018, wood)
    hook = [(0, 0, 1.64), (0, 0, 2.53), (0, .006, 2.565), (0, .03, 2.585), (0, .054, 2.57), (0, .066, 2.54)]
    curve('HangerHook', hook, .0045, steel)
    return parts

def export(objs, name):
    for ob in bpy.data.objects: ob.select_set(ob in objs)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / name), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print(name, sum(len(ob.data.polygons) for ob in objs), 'faces')

def preview(name):
    scn = bpy.context.scene; scn.render.engine = 'BLENDER_WORKBENCH'; scn.render.resolution_x = 700; scn.render.resolution_y = 900
    scn.display.shading.light = 'STUDIO'; scn.display.shading.color_type = 'MATERIAL'
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); bpy.context.collection.objects.link(cam)
    cam.location = (1.0, -3.0, 1.1); cam.rotation_euler = (math.radians(88), 0, math.radians(18)); scn.camera = cam
    scn.render.filepath = str(ROOT / 'tmp' / f'{name}.png'); bpy.ops.render.render(write_still=True)

for variant, letter in enumerate('abc'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = (material('Empty costume canvas', (.40, .33, .23)), material('Empty black lining', (.01, .012, .011), 1.))
    wood = material('Hanger walnut', (.25, .14, .07), .6); steel = material('Hook steel', (.4, .42, .42), .4, .9)
    o = body(variant); simulate(o, variant); dress(o, mats)
    objs = [o] + hanger(wood, steel)
    if PREVIEW: preview(f'suit-{letter}')
    export(objs, f'hanging-suit-{letter}.glb')
