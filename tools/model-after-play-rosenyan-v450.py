"""Rosenyan plush doll for After Play 4.5.0.

Character "Rosenyan" by RosenyanVT (https://www.twitch.tv/rosenyanvt), used with credit in the game.
This is an original low-poly plush interpretation built from primitives: chibi proportions, felt
material with a generated fibre normal map, sitting pose with legs forward.

Run: blender -b --python tools/model-after-play-rosenyan-v450.py
Output: games/kinderparadies/assets/rosenyan-v450/rosenyan-plush.glb
Blender: up +Z, the doll faces -Y. Origin = seat (bottom of the skirt/legs). Seated height ~0.43 m.
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/rosenyan-v450'
OUT.mkdir(parents=True, exist_ok=True)
V = Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- felt texture
def felt_normal(size=512, seed=7):
    rng = np.random.default_rng(seed)
    h = rng.random((size, size)).astype(np.float32)
    for shift in (1, 2, 3):  # soft blur so single pixels become fibres and pills
        h = (h + np.roll(h, shift, 0) + np.roll(h, shift, 1) + np.roll(h, -shift, 0) + np.roll(h, -shift, 1)) / 5
    for _ in range(900):     # short random fibres
        x, y = rng.integers(0, size, 2); a = rng.random() * math.pi; n = rng.integers(6, 18)
        for t in range(n):
            h[int(y + math.sin(a) * t) % size, int(x + math.cos(a) * t) % size] += .35
    h = (h - h.min()) / (h.max() - h.min())
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 2.2
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 2.2
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    rgba = np.dstack([(n + 1) / 2, np.ones_like(h)]).astype(np.float32)
    img = bpy.data.images.new('rosenyan-felt-normal', size, size, alpha=True)
    img.colorspace_settings.name = 'Non-Color'
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(OUT / 'rosenyan-felt-normal.png'); img.file_format = 'PNG'; img.save()
    return img

FELT = felt_normal()
MATS = {}

def mat(name, hex_color, rough=1.0, felt=True, sheen=.22):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new('Rosenyan_' + name)
    m.use_backface_culling = False
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    c = tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))
    c = tuple(x ** 2.2 for x in c)  # sRGB -> linear
    bsdf.inputs['Base Color'].default_value = (*c, 1)
    bsdf.inputs['Roughness'].default_value = rough
    if 'Sheen Weight' in bsdf.inputs: bsdf.inputs['Sheen Weight'].default_value = sheen if felt else 0
    if felt:
        nt = m.node_tree
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = FELT
        mapping = nt.nodes.new('ShaderNodeMapping'); mapping.inputs['Scale'].default_value = (3, 3, 3)
        coord = nt.nodes.new('ShaderNodeTexCoord')
        nm = nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = .7
        nt.links.new(coord.outputs['UV'], mapping.inputs['Vector'])
        nt.links.new(mapping.outputs['Vector'], tex.inputs['Vector'])
        nt.links.new(tex.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    MATS[name] = m
    return m

SKIN = mat('skin', 'f7dccb'); HAIR = mat('hair', 'ff9fce'); HAIR2 = mat('hair_shade', 'f27ab8')
EAR_IN = mat('ear_inner', 'ffdcec'); DRESS = mat('dress', 'fff3f8'); JACKET = mat('jacket', 'f8b2d4')
HOT = mat('hot_pink', 'ff4f9e'); SKIRT = mat('skirt', 'ff7ab6'); WHITE = mat('white', 'ffffff')
NAVY = mat('lash', '1d2366', .35, False); IRIS = mat('iris', '4a66e3', .25, False); IRIS2 = mat('iris_light', '8fc3ff', .25, False)
PUPIL = mat('pupil', '242c7c', .25, False); SHINE = mat('eye_shine', 'ffffff', .1, False); MOUTH = mat('mouth', '8e2343', .6, False)
TONGUE = mat('tongue', 'ff7a9c', .6, False); BLUSH = mat('blush', 'ff9cbd'); LILAC = mat('lilac', 'b69cff')
GOLD = mat('star', 'ffd36b'); RED = mat('berry', 'ff4d6d'); GREEN = mat('leaf', '5ccf7a'); GLASS = mat('glasses', 'ff86c2', .35, False)
SHOE = mat('shoe', 'ff8cc6'); PEARL = mat('pearl', 'fff8fb', .3, False)

PARTS = []

def done(obj, material):
    obj.data.materials.clear(); obj.data.materials.append(material)
    for p in obj.data.polygons: p.use_smooth = True
    PARTS.append(obj)
    return obj

def ball(center, radii, material, segments=28, rings=16, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=center, rotation=rot)
    o = bpy.context.object; o.scale = radii
    return done(o, material)

def tube(a, b, r, material, caps=True, verts=20):
    a, b = V(a), V(b); d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    done(o, material)
    if caps:
        ball(a, (r, r, r), material, 18, 10); ball(b, (r, r, r), material, 18, 10)
    return o

def ring(center, axis, major, minor, material, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=36, minor_segments=10, location=center)
    o = bpy.context.object; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = V(axis).normalized().to_track_quat('Z', 'Y'); o.scale = scale
    return done(o, material)

def cone(center, r1, r2, depth, material, rot=(0, 0, 0), verts=28):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=center, rotation=rot)
    return done(bpy.context.object, material)

def facing(obj, normal):
    """Turn a flattened (thin along local Y) decal so its -Y side points along `normal`."""
    obj.rotation_mode = 'QUATERNION'; obj.rotation_quaternion = (-V(normal)).to_track_quat('Y', 'Z')

def bow(center, size, material, normal=(0, -1, 0)):
    s = size
    for side in (-1, 1):
        o = ball(V(center) + V((side * s * .55, 0, 0)), (s * .55, s * .22, s * .38), material, 16, 10)
        o.rotation_euler = (0, side * .35, 0)
    ball(center, (s * .2, s * .26, s * .22), material, 12, 8)
    for side in (-1, 1):
        o = ball(V(center) + V((side * s * .25, 0, -s * .45)), (s * .1, s * .08, s * .3), material, 10, 6)
        o.rotation_euler = (0, -side * .5, 0)

# ---------------------------------------------------------------- head and face
H = V((0, 0, .305)); RX, RY, RZ = .124, .110, .116
ball(H, (RX, RY, RZ), SKIN, 40, 24)

def head_point(az, el, out=0.0):
    p = V((RX * math.sin(az) * math.cos(el), -RY * math.cos(az) * math.cos(el), RZ * math.sin(el)))
    n = V((p.x / RX ** 2, p.y / RY ** 2, p.z / RZ ** 2)).normalized()
    return H + p + n * out, n

def decal(az, el, out, radii, material, roll=0.0, segments=24):
    p, n = head_point(az, el, out)
    o = ball(p, radii, material, segments, 12); facing(o, n)
    if roll: o.rotation_quaternion = o.rotation_quaternion @ Euler((0, roll, 0)).to_quaternion()
    return o

for side in (-1, 1):
    az = side * .37; el = -.12
    decal(az, el, .001, (.028, .004, .034), NAVY)          # dark lash outline
    decal(az, el - .015, .0025, (.024, .004, .028), IRIS)  # iris
    decal(az, el - .085, .0035, (.019, .004, .012), IRIS2) # light lower half
    decal(az, el - .01, .0045, (.011, .004, .013), PUPIL)  # pupil
    decal(az - side * .075, el + .075, .0058, (.007, .003, .008), SHINE)  # big sparkle
    decal(az + side * .07, el - .09, .0058, (.0035, .003, .0035), SHINE)  # small sparkle
    p, n = head_point(side * .6, el + .05, .0012)                       # lashes flick outwards
    lash = ball(p, (.011, .003, .0035), NAVY, 12, 6); facing(lash, n)
    decal(side * .66, -.4, .001, (.02, .003, .009), BLUSH)             # cheeks
    p, n = head_point(az, el - .01, .013)                               # round glasses
    ring(p, n, .033, .0026, GLASS)
p1, _ = head_point(-.13, -.12, .015); p2, _ = head_point(.13, -.12, .015)
tube(p1, p2, .0024, GLASS, caps=False)
decal(0, -.5, .0008, (.013, .003, .0085), MOUTH)            # small open smile
decal(0, -.535, .0018, (.008, .003, .004), TONGUE)
for side in (-1, 1):                                         # small pink brows just under the fringe
    decal(side * .37, .17, .001, (.012, .003, .0028), HOT, roll=side * .2)

# ---------------------------------------------------------------- hair
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1, location=H + V((0, .01, .012)))
cap = bpy.context.object; cap.scale = (RX * 1.1, RY * 1.12, RZ * 1.1)
bpy.ops.object.transform_apply(scale=True)
bm = bmesh.new(); bm.from_mesh(cap.data)
face_cut = [v for v in bm.verts if v.co.y < -.035 and v.co.z < .05 and abs(v.co.x) < .1]
bmesh.ops.delete(bm, geom=face_cut, context='VERTS'); bm.to_mesh(cap.data); bm.free()
done(cap, HAIR)

def lock(points, radii, material, res=10):
    """A tapered hair lock along smooth points (bezier with auto handles)."""
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    c = bpy.context.object; sp = c.data.splines[0]
    sp.bezier_points.add(len(points) - 2)
    for bp, co, r in zip(sp.bezier_points, points, radii):
        bp.co = co; bp.radius = r; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    c.data.bevel_depth = 1.0; c.data.bevel_resolution = 5; c.data.resolution_u = res; c.data.use_fill_caps = True
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.object; o.scale = (1, 1, 1)
    return done(o, material)

def on_head(az, el, out):
    return head_point(az, el, out)[0]

# Fringe: short locks from the crown down to just above the eyes, slightly curled at the tips.
for i, az in enumerate((-.86, -.6, -.33, -.08, .17, .43, .7, .92)):
    tip_el = .1 + abs(az) * .05 + (.04 if i % 2 else 0)
    pts = [on_head(az * .5, 1.05, .006), on_head(az * .85, .62, .013), on_head(az, .3, .015), on_head(az * 1.04, tip_el, .013)]
    lock(pts, (.03, .028, .022, .006), HAIR if i % 2 else HAIR2)
for side in (-1, 1):
    # Locks framing the face down to the chin.
    for k, az in enumerate((1.02, 1.18)):
        pts = [on_head(side * az * .8, .55, .01), on_head(side * az, .1, .016), on_head(side * az * 1.02, -.35, .016), on_head(side * az * .96, -.8, .02)]
        lock(pts, (.022, .022, .02, .008), HAIR2 if k else HAIR)
    # Long wavy curtains from the side of the head down to the seat, each with its own S-wave.
    for k in range(5):
        x0 = side * (.1 + k * .008); y0 = .01 + k * .022; w = (.022 + k * .004) * (1 if k % 2 else -1)
        pts = [H + V((x0 * .85, y0, .07)), H + V((x0 * 1.25, y0 + .005, -.04)),
               V((side * (.15 + .01 * k) + side * w, y0 + .01, .17)), V((side * (.15 + .012 * k) - side * w, y0 + .02, .09)),
               V((side * (.155 + .01 * k) + side * w * .8, y0 + .03, .03)), V((side * (.13 + .01 * k), y0 + .01, .012))]
        lock(pts, (.03, .036, .034, .03, .026, .01), HAIR if k % 2 else HAIR2, 12)
    ball(H + V((side * .108, .024, .07)), (.05, .05, .054), HAIR, 24, 14)   # twin-tail puffs
for k in range(6):                                            # back curtain
    x = (k - 2.5) * .03
    pts = [H + V((x * .8, .1, .07)), H + V((x * 1.1, .135, -.06)), V((x * 1.2 + .015 * (-1) ** k, .135, .14)), V((x * 1.25 - .015 * (-1) ** k, .13, .06)), V((x * 1.2, .115, .012))]
    lock(pts, (.034, .04, .036, .03, .01), HAIR2 if k % 2 else HAIR, 12)

# cat ears and heart ahoge
for side in (-1, 1):
    base = H + V((side * .074, .014, .1))
    rot = (math.radians(-8), side * math.radians(26), 0)
    cone(base + V((0, 0, .03)), .046, .004, .075, HAIR, rot)
    cone(base + V((side * -.002, -.012, .028)), .032, .003, .055, EAR_IN, rot)
bpy.ops.curve.primitive_bezier_circle_add(radius=1, location=(0, 0, 0))
heart = bpy.context.object
pts = heart.data.splines[0].bezier_points
shape = [((0, 0, -1.0), (-.6, 0, -.55), (.6, 0, -.55)), ((1.0, 0, .2), (.95, 0, -.4), (1.0, 0, .75)),
         ((0, 0, .55), (.45, 0, 1.0), (-.45, 0, 1.0)), ((-1.0, 0, .2), (-1.0, 0, .75), (-.95, 0, -.4))]
for bp, (co, h1, h2) in zip(pts, shape):
    bp.handle_left_type = bp.handle_right_type = 'FREE'
    bp.co = co; bp.handle_left = h1; bp.handle_right = h2
heart.data.bevel_depth = .09; heart.data.bevel_resolution = 4
heart.scale = (.028, .028, .028); heart.location = H + V((0, .0, .175))
bpy.ops.object.convert(target='MESH'); done(heart, HAIR)
tube(H + V((0, .004, .13)), H + V((0, 0, .15)), .0035, HAIR, caps=False)

# hair accessories, sitting on top of the fringe and side locks
def on_hair(az, el, out=.04):
    return on_head(az, el, out)
bow(on_hair(-.75, .55), .03, LILAC); bow(on_hair(.95, -.05, .035), .026, LILAC); bow(on_hair(-1.05, -.15, .035), .024, LILAC)
c = on_hair(-.3, .62); ball(c, (.015, .007, .015), WHITE, 16, 8); ring(c + V((0, -.006, 0)), (0, -1, .5), .009, .0022, HOT)   # candy
ball(on_hair(.32, .66), (.012, .006, .012), GOLD, 5, 4)                       # star (low-poly = pointy)
c = on_hair(-.85, .2); ball(c, (.013, .01, .015), RED, 14, 8); ball(c + V((0, 0, .015)), (.009, .007, .003), GREEN, 10, 6)   # strawberry
ball(on_hair(.75, .45), (.012, .007, .012), HOT, 14, 8)                       # heart clip
c = on_hair(.85, .2); ball(c, (.014, .006, .006), mat('rainbow_cloud', 'ffffff'), 12, 6)    # tiny cloud with a rainbow
for i, col in enumerate(('ff6b8a', 'ffd36b', '8fe0a8', '8fc3ff')):
    ring(c + V((0, -.004, .006)), (0, -1, 0), .012 - i * .0022, .0012, mat('rb' + col, col, .6, False), (1, 1, .7))

# ---------------------------------------------------------------- body
tube((0, 0, .17), (0, 0, .2), .028, SKIN, caps=False)                         # neck
ring((0, 0, .193), (0, 0, 1), .031, .0055, HOT)                                # choker
for i in range(14):
    a = math.pi * (.15 + .7 * i / 13)
    ball((math.cos(a) * .036, -math.sin(a) * .033, .183 - math.sin(a) * .006), (.0042, .0042, .0042), PEARL, 10, 6)
ball((0, -.039, .171), (.008, .004, .008), LILAC, 14, 8)                       # heart pendant
ball((0, 0, .125), (.066, .056, .068), DRESS, 32, 18)                          # dress top
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=18, radius=1, location=(0, .002, .127))
jacket = bpy.context.object; jacket.scale = (.074, .064, .071); bpy.ops.object.transform_apply(scale=True)
bm = bmesh.new(); bm.from_mesh(jacket.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -.03 and abs(v.co.x) < .032], context='VERTS')
bm.to_mesh(jacket.data); bm.free(); done(jacket, JACKET)
for side in (-1, 1):                                                           # white jacket trim and patches
    tube((side * .03, -.06, .07), (side * .03, -.055, .18), .005, WHITE, caps=True, verts=12)
ball((-.052, -.05, .14), (.014, .004, .012), mat('jacket_heart', 'cfa7ff'), 14, 8)
ball((.05, -.054, .105), (.006, .003, .006), GOLD, 5, 4); ball((.04, -.058, .118), (.005, .003, .005), mat('moon', '8ec9ff', .6), 12, 6)
bow((0, -.06, .155), .018, HOT)
ring((0, 0, .084), (0, 0, 1), .066, .0065, HOT, (1, .88, 1))                    # belt
ball((0, -.059, .084), (.009, .004, .008), mat('buckle', 'e9e9ef', .2, False), 14, 8)
cone((0, 0, .055), .118, .066, .058, SKIRT)                                    # tiered skirt
ring((0, 0, .028), (0, 0, 1), .114, .013, HOT)
ring((0, 0, .02), (0, 0, 1), .118, .008, WHITE)

for side in (-1, 1):                                                           # arms resting at the sides
    sh = V((side * .068, 0, .16)); wr = V((side * .098, -.04, .08))
    tube(sh, wr, .025, JACKET)
    ring(wr, wr - sh, .022, .007, WHITE)
    ball(wr + (wr - sh).normalized() * .02, (.019, .018, .019), SKIN, 18, 10)

for side in (-1, 1):                                                           # legs stretched forward
    hip = V((side * .038, -.03, .045)); ankle = V((side * .046, -.165, .036))
    tube(hip, ankle, .025, WHITE)
    axis = ankle - hip
    for k in range(4):                                                         # pink stripes on the lower stocking
        ring(hip + axis * (.55 + k * .1), axis, .0255, .0045, HOT)
    ring(hip + axis * .22, axis, .026, .004, HOT)                              # garter
    if side > 0: bow(hip + axis * .22 + V((.022, 0, .012)), .014, HOT)
    toe = ankle + V((0, -.03, .002))
    ball(toe + V((0, 0, -.012)), (.034, .047, .016), WHITE, 22, 10)            # sole
    ball(toe, (.031, .044, .029), SHOE, 24, 12)                                # boot
    bow(toe + V((0, -.03, .026)), .014, SHOE)

# tail curling up behind
bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
tail = bpy.context.object; sp = tail.data.splines[0]
sp.bezier_points.add(1)
for bp, (co, h1, h2) in zip(sp.bezier_points, [((0, .06, .05), (0, .02, .05), (.03, .12, .03)),
                                                ((.1, .16, .08), (.09, .19, .02), (.11, .13, .14)),
                                                ((.13, .1, .2), (.14, .13, .17), (.12, .08, .23))]):
    bp.handle_left_type = bp.handle_right_type = 'FREE'; bp.co = co; bp.handle_left = h1; bp.handle_right = h2
tail.data.bevel_depth = .019; tail.data.bevel_resolution = 4; tail.data.use_fill_caps = True
bpy.ops.object.convert(target='MESH'); done(tail, HAIR)
ball((.13, .1, .2), (.02, .02, .022), HAIR, 16, 10)
bow((.12, .115, .16), .02, WHITE)

# ---------------------------------------------------------------- merge per material and export
for o in PARTS:
    o.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.join()
doll = bpy.context.object; doll.name = 'RosenyanPlush'
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
tris = sum(len(p.vertices) - 2 for p in doll.data.polygons)
dims = doll.dimensions
bpy.ops.export_scene.gltf(filepath=str(OUT / 'rosenyan-plush.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print(f'Rosenyan plush: {tris} triangles, {len(doll.data.materials)} materials, size {dims.x:.3f} x {dims.y:.3f} x {dims.z:.3f} m')
