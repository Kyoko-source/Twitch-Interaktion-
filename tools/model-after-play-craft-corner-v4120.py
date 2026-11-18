"""Craft corner of the party room, After Play 4.12.0.

A round children's craft table: laminate top in pale yellow with crayon
scribbles, glue rings and scratches, a soft teal rubber edge band, four square
steel legs with plastic glides and an apron ring. And a child's stool: a
moulded plastic seat with a dished top and rolled rim, four splayed steel legs,
a brace ring and rubber feet. The stool seat material is named "StoolSeat" so
the game can tint each stool.

Run: blender -b --python tools/model-after-play-craft-corner-v4120.py   (Blender 5.0)
Output: games/kinderparadies/assets/party-v4120/craft-table.glb, kid-stool.glb (+ craft-table-top.png)
Blender up +Z. Table origin on the floor under its centre, top surface at 0.66 m.
Stool origin on the floor under its centre, seat top at 0.39 m.
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/party-v4120'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(4120)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, rough=.5, metal=0., image=None):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1)
    bsdf.inputs['Roughness'].default_value = rough; bsdf.inputs['Metallic'].default_value = metal
    if image:
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = image
        nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return m

def finish(o, mat, parts):
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = True
    parts.append(o); return o

def laminate(size=1024):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    img = np.ones((size, size, 3), np.float32) * np.array([.86, .78, .52])
    img *= (1 + rng.normal(0, .012, (size, size)))[..., None]
    r = np.hypot(xx - .5, yy - .5)
    img[r > .5] = np.array([.3, .5, .48])
    colors = np.array([[.75, .2, .2], [.2, .35, .75], [.2, .6, .3], [.85, .55, .1], [.55, .25, .65]])
    # Crayon scribbles: back-and-forth hatching that wanders, waxy and patchy,
    # where children sat around the rim, plus a few loose lines and a sun.
    for _ in range(34):
        a = rng.uniform(0, math.tau); d = rng.uniform(.2, .43); cx, cy = .5 + math.cos(a) * d, .5 + math.sin(a) * d
        col = colors[rng.integers(0, 5)]; heading = rng.uniform(0, math.tau)
        length = rng.uniform(.03, .09); amp = rng.uniform(.006, .02); freq = rng.uniform(40, 90)
        for t in np.linspace(0, 1, 1600):
            wob = rng.normal(0, .0012)
            px = cx + math.cos(heading) * length * t - math.sin(heading) * (math.sin(t * freq) * amp + wob)
            py = cy + math.sin(heading) * length * t + math.cos(heading) * (math.sin(t * freq) * amp + wob)
            ix, iy = int(px * size), int(py * size)
            if 1 <= ix < size - 1 and 1 <= iy < size - 1 and rng.random() < .8:
                img[iy - 1:iy + 1, ix - 1:ix + 2] = img[iy - 1:iy + 1, ix - 1:ix + 2] * .4 + col * .6
    for _ in range(14):
        x, y = rng.uniform(.15, .85, 2); col = colors[rng.integers(0, 5)]; ang = rng.uniform(0, math.tau)
        for t in np.linspace(0, rng.uniform(.04, .12), 500):
            ang += rng.normal(0, .05); x += math.cos(ang) / size * 1.2; y += math.sin(ang) / size * 1.2
            ix, iy = int(x * size), int(y * size)
            if 1 <= ix < size - 1 and 1 <= iy < size - 1: img[iy, ix - 1:ix + 1] = img[iy, ix - 1:ix + 1] * .4 + col * .6
    # Glue rings and pale scratches.
    for _ in range(7):
        cx, cy, rr = rng.uniform(.2, .8), rng.uniform(.2, .8), rng.uniform(.012, .025)
        img[np.abs(np.hypot(xx - cx, yy - cy) - rr) < .0018] *= .82
    for _ in range(60):
        x0, y0 = rng.random(2); ang = rng.uniform(0, math.pi); ln = rng.uniform(.02, .08)
        for t in np.linspace(0, ln, 120):
            ix, iy = int((x0 + math.cos(ang) * t) * size) % size, int((y0 + math.sin(ang) * t) * size) % size
            img[iy, ix] = np.minimum(1, img[iy, ix] * 1.12)
    image = bpy.data.images.new('craft-table-top', size, size, alpha=False)
    image.pixels.foreach_set(np.flipud(np.concatenate([img, np.ones((size, size, 1), np.float32)], 2)).astype(np.float32).ravel())
    image.filepath_raw = str(OUT / 'craft-table-top.png'); image.file_format = 'PNG'; image.save()
    return image

def export(parts, name):
    for o in bpy.data.objects: o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / name), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print(f'{name}: {sum(len(p.vertices) - 2 for o in parts for p in o.data.polygons)} triangles')

# ---------------------------------------------------------------- round craft table
reset(); parts = []
TOP = material('CraftTableLaminate', (1, 1, 1), .42, image=laminate())
EDGE = material('CraftTableEdgeBand', (.27, .52, .5), .55)
STEEL = material('CraftTableSteel', (.58, .6, .6), .35, .9)
GLIDE = material('CraftTableGlide', (.08, .08, .08), .8)
bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=1.08, depth=.03, location=(0, 0, .645)); top = bpy.context.object
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.cylinder_project(direction='ALIGN_TO_OBJECT'); bpy.ops.object.mode_set(mode='OBJECT')
# Planar UV from above so the print maps across the disc.
for loop in top.data.loops:
    v = top.data.vertices[loop.vertex_index].co
    top.data.uv_layers.active.data[loop.index].uv = ((v.x / 2.2) + .5, (v.y / 2.2) + .5)
finish(top, TOP, parts)
bpy.ops.mesh.primitive_torus_add(major_radius=1.085, minor_radius=.022, major_segments=96, minor_segments=12, location=(0, 0, .645)); edge = bpy.context.object
edge.scale = (1, 1, .9); finish(edge, EDGE, parts)
bpy.ops.mesh.primitive_torus_add(major_radius=.82, minor_radius=.012, major_segments=64, minor_segments=8, location=(0, 0, .6)); finish(bpy.context.object, STEEL, parts)
for sx in (-1, 1):
    for sy in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(sx * .65, sy * .65, .32)); leg = bpy.context.object
        leg.scale = (.035, .035, .6); bpy.ops.object.transform_apply(scale=True)
        b = leg.modifiers.new('b', 'BEVEL'); b.width = .005; b.segments = 2; bpy.ops.object.modifier_apply(modifier='b'); finish(leg, STEEL, parts)
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=.024, depth=.025, location=(sx * .65, sy * .65, .0125)); finish(bpy.context.object, GLIDE, parts)
export(parts, 'craft-table.glb')

# ---------------------------------------------------------------- child's stool
reset(); parts = []
SEAT = material('StoolSeat', (.8, .65, .25), .38)
STEEL = material('StoolSteel', (.6, .62, .62), .33, .9)
FOOT = material('StoolFoot', (.07, .07, .07), .85)
# Dished moulded seat: a lathe profile with a rolled rim.
profile = [(0, .375), (.12, .372), (.19, .378), (.215, .388), (.23, .39), (.236, .38), (.232, .36), (.22, .352), (.0, .352)]
bm = bmesh.new(); seg = 48; rings = []
for k in range(seg):
    a = k / seg * math.tau; ring = []
    for r, z in profile: ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
    rings.append(ring)
for k in range(seg):
    r1, r2 = rings[k], rings[(k + 1) % seg]
    for i in range(len(profile) - 1):
        try: bm.faces.new((r1[i], r2[i], r2[i + 1], r1[i + 1]))
        except ValueError: pass
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
me = bpy.data.meshes.new('StoolSeat'); bm.to_mesh(me); bm.free()
seat = bpy.data.objects.new('StoolSeat', me); bpy.context.collection.objects.link(seat)
bpy.context.view_layer.objects.active = seat; seat.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
finish(seat, SEAT, parts)
for sx in (-1, 1):
    for sy in (-1, 1):
        a = Vector((sx * .12, sy * .12, .352)); b = Vector((sx * .16, sy * .16, .02)); d = b - a
        bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=.012, depth=d.length, location=(a + b) / 2)
        leg = bpy.context.object; leg.rotation_mode = 'QUATERNION'; leg.rotation_quaternion = d.to_track_quat('Z', 'Y'); finish(leg, STEEL, parts)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=.018, location=b); f = bpy.context.object; f.scale = (1, 1, .7); finish(f, FOOT, parts)
bpy.ops.mesh.primitive_torus_add(major_radius=.2, minor_radius=.008, major_segments=48, minor_segments=8, location=(0, 0, .14)); finish(bpy.context.object, STEEL, parts)
export(parts, 'kid-stool.glb')
