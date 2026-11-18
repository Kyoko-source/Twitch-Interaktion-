"""Birthday table for the party room, After Play 4.11.0.

A folding banquet table under a printed paper party tablecloth. The cloth is a
real cloth simulation draped over the table top, so its overhang falls in soft
folds and the corners hang in points. The print is drawn here: confetti dots,
little stars and streamers on a faded cream paper, sun-bleached and with a few
old drink rings. Steel folding legs with crossbars, rubber feet.

Run: blender -b --python tools/model-after-play-party-table-v4110.py   (Blender 5.0)
Output: games/kinderparadies/assets/party-v4110/party-table.glb (+ party-tablecloth.png)
Blender: up +Z. Origin on the floor under the table centre. Long side along Y.
Godot: the glTF's +Z is the table's long side (3.1 m), top at 0.84 m.
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/party-v4110'
OUT.mkdir(parents=True, exist_ok=True)
W, L, TOP = 2.1, 3.1, 0.84         # table top width (x), length (y), height of the top surface
rng = np.random.default_rng(4110)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- tablecloth print
def cloth_print(size=2048, ss=2):
    big = size * ss
    img = np.ones((big, big, 3), np.float32) * np.array([.86, .80, .68])
    yy, xx = np.mgrid[0:big, 0:big].astype(np.float32) / big
    # Yellowed, sun-bleached paper: soft blotches and a dirtier edge band.
    blotch = np.zeros((big, big), np.float32)
    for _ in range(45):
        cx, cy, r = rng.random(), rng.random(), rng.uniform(.05, .25)
        blotch += np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (r * r))) * rng.uniform(-.05, .04)
    edge = np.minimum(np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy))
    img *= (1 + blotch - .12 * np.exp(-edge / .06))[..., None]
    # Faded print: pastel inks that lost most of their colour.
    palette = np.array([[.95, .55, .68], [.55, .78, .90], [.98, .82, .40], [.60, .85, .62], [.78, .66, .92]])
    paper = np.array([.86, .80, .68])
    palette = palette * .72 + paper * .28
    def disc(cx, cy, r, col):
        y0, y1, x0, x1 = max(cy - r, 0), min(cy + r, big), max(cx - r, 0), min(cx + r, big)
        sub = (yy[y0:y1, x0:x1] * big - cy) ** 2 + (xx[y0:y1, x0:x1] * big - cx) ** 2 <= r * r
        img[y0:y1, x0:x1][sub] = col
    for _ in range(1500):
        disc(int(rng.integers(0, big)), int(rng.integers(0, big)), int(rng.integers(5, 15)), palette[rng.integers(0, 5)] * rng.uniform(.85, 1))
    for _ in range(170):
        cx, cy = rng.integers(30, big - 30, 2); r = int(rng.integers(14, 26)); col = palette[rng.integers(0, 5)]
        py = yy[cy - r:cy + r, cx - r:cx + r] * big - cy; px = xx[cy - r:cy + r, cx - r:cx + r] * big - cx
        a = np.arctan2(py, px); d = np.hypot(px, py)
        img[cy - r:cy + r, cx - r:cx + r][d < r * (.55 + .45 * np.abs(np.cos(2.5 * a)))] = col
    for _ in range(14):
        y0 = rng.random(); amp = rng.uniform(.01, .03); f = rng.uniform(3, 7); col = palette[rng.integers(0, 5)]
        img[np.abs(yy - (y0 + amp * np.sin(xx * f * math.tau + rng.random() * 6))) < .0022] = col
    # Drink rings, a cake smear and fine grime specks.
    for _ in range(6):
        cx, cy, r = rng.random(), rng.random(), rng.uniform(.011, .018)
        img[np.abs(np.hypot(xx - cx, yy - cy) - r) < .0022] *= np.array([.72, .6, .48])
    for _ in range(4):
        cx, cy, r = rng.random(), rng.random(), rng.uniform(.03, .07)
        img[np.hypot((xx - cx) * 1.8, yy - cy) < r] *= np.array([.86, .78, .7])
    speck = rng.random((big, big)) < .004
    img[speck] *= .6
    img = img.reshape(size, ss, size, ss, 3).mean(axis=(1, 3))      # antialiased down-sample
    img = np.clip(img, 0, 1)
    image = bpy.data.images.new('party-tablecloth', size, size, alpha=False)
    rgba = np.concatenate([img, np.ones((size, size, 1), np.float32)], axis=2)
    image.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    image.filepath_raw = str(OUT / 'party-tablecloth.png'); image.file_format = 'PNG'; image.save()
    return image

PRINT = cloth_print()

def material(name, color, rough=.5, metal=0., image=None, sheen=0.):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1)
    bsdf.inputs['Roughness'].default_value = rough; bsdf.inputs['Metallic'].default_value = metal
    if 'Sheen Weight' in bsdf.inputs: bsdf.inputs['Sheen Weight'].default_value = sheen
    if image:
        tex = m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = image
        m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return m

PAPER = material('PartyTablecloth', (1, 1, 1), .82, image=PRINT, sheen=.1)
STEEL = material('FoldingLegSteel', (.55, .57, .58), .38, .9)
RUBBER = material('RubberFoot', (.06, .06, .06), .85)
BOARD = material('TableBoardEdge', (.82, .80, .74), .55)

def finish(obj, mat):
    obj.data.materials.clear(); obj.data.materials.append(mat)
    for p in obj.data.polygons: p.use_smooth = True
    return obj

def tube(a, b, r, mat, verts=16):
    a, b = Vector(a), Vector(b); d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    return finish(o, mat)

parts = []
# ---------------------------------------------------------------- table body (mostly under the cloth)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, TOP - .025)); top = bpy.context.object
top.scale = (W, L, .05); bpy.ops.object.transform_apply(scale=True)
bev = top.modifiers.new('round', 'BEVEL'); bev.width = .012; bev.segments = 3
bpy.ops.object.modifier_apply(modifier='round'); parts.append(finish(top, BOARD))
for sy in (-1, 1):                      # folding leg frames near the short ends
    y = sy * (L / 2 - .32)
    for sx in (-1, 1):
        parts.append(tube((sx * (W / 2 - .12), y, .03), (sx * (W / 2 - .12), y, TOP - .05), .016, STEEL))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=.024, location=(sx * (W / 2 - .12), y, .022)); foot = bpy.context.object
        foot.scale = (1, 1, .7); parts.append(finish(foot, RUBBER))
    parts.append(tube((-(W / 2 - .12), y, .16), ((W / 2 - .12), y, .16), .012, STEEL))
    parts.append(tube((-(W / 2 - .12), y, TOP - .06), ((W / 2 - .12), y, TOP - .06), .012, STEEL))
    parts.append(tube((0, y, TOP - .06), (0, y * .35, TOP - .055), .01, STEEL))     # fold-out brace

# ---------------------------------------------------------------- draped paper cloth
collider = top
collider.modifiers.new('collide', 'COLLISION'); collider.collision.thickness_outer = .004; collider.collision.cloth_friction = 8
OVER = .34
bpy.ops.mesh.primitive_grid_add(x_subdivisions=110, y_subdivisions=150, size=1, location=(0, 0, TOP + .02))
cloth = bpy.context.object; cloth.scale = (W + 2 * OVER, L + 2 * OVER, 1); bpy.ops.object.transform_apply(scale=True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.unwrap(method='ANGLE_BASED', margin=0); bpy.ops.object.mode_set(mode='OBJECT')
# A faint ripple so the overhang breaks into folds instead of falling as one sheet.
for v in cloth.data.vertices: v.co.z += float(rng.normal(0, .004)) + .006 * math.sin(v.co.x * 9.) * math.sin(v.co.y * 7.)
sim = cloth.modifiers.new('drape', 'CLOTH')
sim.settings.quality = 10; sim.settings.mass = .3; sim.settings.tension_stiffness = 15; sim.settings.compression_stiffness = 15
sim.settings.bending_stiffness = .12; sim.settings.air_damping = 1.5
sim.collision_settings.collision_quality = 4; sim.collision_settings.distance_min = .003
sim.collision_settings.use_self_collision = False
scene.frame_start = 1; scene.frame_end = 140
for f in range(1, 141): scene.frame_set(f)
bpy.context.view_layer.objects.active = cloth
bpy.ops.object.modifier_apply(modifier='drape')
# Paper lies flat on the board: smooth the top, keep the folds of the overhang.
for v in cloth.data.vertices:
    if abs(v.co.x) < W / 2 - .015 and abs(v.co.y) < L / 2 - .015: v.co.z = TOP + .0012
sol = cloth.modifiers.new('paper', 'SOLIDIFY'); sol.thickness = .0016; bpy.ops.object.modifier_apply(modifier='paper')
collider.modifiers.remove(collider.modifiers['collide'])
parts.append(finish(cloth, PAPER))

# ---------------------------------------------------------------- export
for o in bpy.data.objects: o.select_set(o in parts)
bpy.context.view_layer.objects.active = cloth
bpy.ops.export_scene.gltf(filepath=str(OUT / 'party-table.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
tris = sum(len(p.vertices) - 2 for o in parts for p in o.data.polygons)
lowest = min((cloth.matrix_world @ v.co).z for v in cloth.data.vertices)
print(f'party table: {tris} triangles, cloth hangs down to {lowest:.3f} m')
