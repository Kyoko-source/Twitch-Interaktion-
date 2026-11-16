"""einsmarello plush doll for After Play 4.6.0.

Character and voice: einsmarello (credited in the game). Original plush interpretation after the
"Plüschiges Rotkohl-Streaming" picture: long blonde hair, black cat-ear headphones with glowing pink
ears, pink heart eyes, ":3" smile, black hoodie with pink stripes and a purple crown patch, a jar of
Rotkohl hugged in both arms, black socks with pink stripes, paw-print soles and a black cat tail.
Built from primitives with the felt material and helpers of the Rosenyan script.

Run: blender -b --python tools/model-after-play-einsmarello-v460.py
Output: games/kinderparadies/assets/einsmarello-v460/einsmarello-plush.glb
Blender: up +Z, faces -Y, origin = seat.
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_source = (ROOT / 'tools/model-after-play-rosenyan-v450.py').read_text(encoding='utf-8-sig')
exec(_source.split('# ---------------------------------------------------------------- head and face')[0])
OUT = ROOT / 'games/kinderparadies/assets/einsmarello-v460'
OUT.mkdir(parents=True, exist_ok=True)

def emat(name, hex_color, rough=1.0, felt=True, glow=0.0):
    m = mat('E_' + name, hex_color, rough, felt)
    m.name = 'Einsmarello_' + name
    if glow:
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        c = tuple((int(hex_color[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))
        bsdf.inputs['Emission Color'].default_value = (*c, 1); bsdf.inputs['Emission Strength'].default_value = glow
    return m

SKIN = emat('skin', 'f7dcc8'); HAIR = emat('hair', 'f2dcb2'); HAIR2 = emat('hair_shade', 'dcc08e')
BLACK = emat('black_felt', '2a1c26'); BLACK2 = emat('black_soft', '3a2733'); PINK = emat('pink', 'ff4fa3')
GLOWPINK = emat('ear_glow', 'ff6fc8', .6, False, 2.5); PURPLE = emat('purple_patch', '7e4fe0'); GOLD2 = emat('crown', 'ffd36b')
LASH = emat('lash', '1a0f18', .35, False); IRIS = emat('iris', 'c2306f', .25, False); IRIS2 = emat('iris_light', 'ff8fc0', .25, False)
PUPIL = emat('pupil', '6e0f3a', .25, False); SHINE = emat('shine', 'ffffff', .1, False); MOUTH = emat('mouth', '4a1f2a', .6, False)
BLUSH = emat('blush', 'ff9cb8'); JAR = emat('jar_glass', '7d1f55', .12, False); CABBAGE = emat('rotkohl', '5a1440', .7, False)
CLOTH = emat('gingham', 'ff8fb8'); CLOTH2 = emat('gingham_white', 'fff0f4'); TWINE = emat('twine', 'c9a46b')
LABEL = emat('label', 'f5ead2'); INK = emat('label_ink', '4a2a1e', .7, False); PAW = emat('paw', 'ff6fae')

# ---------------------------------------------------------------- head and face
H = V((0, 0, .305)); RX, RY, RZ = .124, .110, .116
ball(H, (RX, RY, RZ), SKIN, 40, 24)

def head_point(az, el, out=0.0):
    p = V((RX * math.sin(az) * math.cos(el), -RY * math.cos(az) * math.cos(el), RZ * math.sin(el)))
    n = V((p.x / RX ** 2, p.y / RY ** 2, p.z / RZ ** 2)).normalized()
    return H + p + n * out, n

def on_head(az, el, out):
    return head_point(az, el, out)[0]

def decal(az, el, out, radii, material, roll=0.0, segments=24):
    p, n = head_point(az, el, out)
    o = ball(p, radii, material, segments, 12); facing(o, n)
    if roll: o.rotation_quaternion = o.rotation_quaternion @ Euler((0, roll, 0)).to_quaternion()
    return o

def heart(center, size, material, normal=(0, -1, 0)):
    """Small felt heart: two lobes and a point, flattened towards the viewer."""
    n = V(normal).normalized(); right = n.cross(V((0, 0, 1))).normalized(); up = right.cross(n).normalized() * -1
    for s in (-1, 1):
        o = ball(V(center) + right * s * size * .45 + up * size * .2, (size * .5, size * .5, size * .5), material, 12, 8)
        o.scale = (size * .5, size * .18, size * .5); facing(o, n)
    o = cone(V(center) - up * size * .35, size * .78, 0, size * .9, material, verts=12)
    o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = (-up).to_track_quat('Z', 'Y'); o.scale = (1, .25, 1)

for side in (-1, 1):
    az = side * .37; el = -.12
    decal(az, el, .001, (.029, .004, .033), LASH)               # heavy dark outline
    decal(az, el - .02, .0025, (.025, .004, .027), IRIS)        # magenta iris
    decal(az, el - .09, .0035, (.02, .004, .012), IRIS2)        # light lower half
    decal(az, el - .01, .0045, (.012, .004, .013), PUPIL)
    p, n = head_point(az - side * .03, el + .05, .007); heart(p, .010, SHINE, n)   # white heart highlight
    p, n = head_point(az + side * .045, el - .11, .0062); heart(p, .006, SHINE, n)
    p, n = head_point(side * .62, el + .08, .0012)                 # flicked lashes
    lash = ball(p, (.013, .003, .004), LASH, 12, 6); facing(lash, n)
    for k in range(3):                                              # blush strokes
        decal(side * (.6 + k * .05), -.42, .0012, (.003, .002, .009), BLUSH, roll=.4 * side)
    decal(side * .37, .19, .001, (.013, .003, .0028), HAIR2, roll=side * .15)   # brows
for side in (-1, 1):                                               # ":3" mouth = two small arcs
    p, n = head_point(side * .045, -.5, .0012)
    o = ball(p, (.009, .002, .0035), MOUTH, 12, 6); facing(o, n)
    o.rotation_quaternion = o.rotation_quaternion @ Euler((0, -side * .55, 0)).to_quaternion()

# ---------------------------------------------------------------- hair
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1, location=H + V((0, .01, .012)))
cap = bpy.context.object; cap.scale = (RX * 1.1, RY * 1.12, RZ * 1.1)
bpy.ops.object.transform_apply(scale=True)
bm = bmesh.new(); bm.from_mesh(cap.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -.035 and v.co.z < .05 and abs(v.co.x) < .1], context='VERTS')
bm.to_mesh(cap.data); bm.free(); done(cap, HAIR)

def lock(points, radii, material, res=10):
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    c = bpy.context.object; sp = c.data.splines[0]
    sp.bezier_points.add(len(points) - 2)
    for bp, co, r in zip(sp.bezier_points, points, radii):
        bp.co = co; bp.radius = r; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    c.data.bevel_depth = 1.0; c.data.bevel_resolution = 5; c.data.resolution_u = res; c.data.use_fill_caps = True
    bpy.ops.object.convert(target='MESH')
    return done(bpy.context.object, material)

# Side-swept fringe: long pointed locks crossing the forehead, one between the eyes.
for i, az in enumerate((-.9, -.62, -.36, -.12, .1, .34, .6, .88)):
    sweep = .12
    pts = [on_head(az * .5, 1.05, .006), on_head(az * .8 + sweep, .6, .013), on_head(az + sweep * .6, .28, .015), on_head(az + sweep * .2, .02 + abs(az) * .06, .013)]
    lock(pts, (.03, .028, .02, .004), HAIR if i % 2 else HAIR2)
for side in (-1, 1):
    for k, az in enumerate((1.0, 1.16)):                               # face-framing locks to the chest
        pts = [on_head(side * az * .8, .55, .01), on_head(side * az, .05, .017), on_head(side * az * 1.02, -.5, .02), V((side * (.1 + .02 * k), -.05, .14)), V((side * (.11 + .02 * k), -.06, .08))]
        lock(pts, (.022, .024, .022, .016, .005), HAIR2 if k else HAIR, 12)
    for k in range(5):                                                 # long, gently waving hair to the seat
        x0 = side * (.1 + k * .008); y0 = .01 + k * .022; w = .012 * (1 if k % 2 else -1)
        pts = [H + V((x0 * .85, y0, .07)), H + V((x0 * 1.22, y0 + .005, -.05)), V((side * (.145 + .01 * k) + side * w, y0 + .01, .16)),
               V((side * (.15 + .01 * k) - side * w, y0 + .02, .08)), V((side * (.14 + .01 * k), y0 + .02, .012))]
        lock(pts, (.03, .034, .03, .026, .008), HAIR if k % 2 else HAIR2, 12)
for k in range(6):
    x = (k - 2.5) * .03
    pts = [H + V((x * .8, .1, .07)), H + V((x * 1.1, .135, -.06)), V((x * 1.2, .135, .14)), V((x * 1.25, .13, .06)), V((x * 1.2, .115, .012))]
    lock(pts, (.034, .04, .034, .03, .008), HAIR2 if k % 2 else HAIR, 12)

# ---------------------------------------------------------------- cat-ear headphones
lock([H + V((-.146, .012, .0)), H + V((-.12, .012, .1)), H + V((0, .012, .148)), H + V((.12, .012, .1)), H + V((.146, .012, .0))],
     (.012, .013, .014, .013, .012), BLACK, 16)                     # padded headband over the hair
for side in (-1, 1):
    cup = H + V((side * (RX * 1.18), .012, -.01))
    o = tube(cup - V((side * .018, 0, 0)), cup + V((side * .018, 0, 0)), .045, BLACK2, caps=False, verts=28)
    ball(cup + V((side * .019, 0, 0)), (.008, .042, .042), BLACK, 24, 12)
    ring(cup + V((side * .02, 0, 0)), (1, 0, 0), .036, .004, PINK)
    ring(cup - V((side * .019, 0, 0)), (1, 0, 0), .043, .006, BLACK)
    base = H + V((side * .074, .02, .118))
    rot = (math.radians(-8), side * math.radians(24), 0)
    cone(base + V((0, 0, .03)), .05, .006, .08, BLACK, rot)                 # black felt ear
    cone(base + V((0, -.014, .028)), .034, .004, .058, GLOWPINK, rot)       # glowing pink inner ear

# ---------------------------------------------------------------- body in a black hoodie
tube((0, 0, .17), (0, 0, .2), .028, SKIN, caps=False)
ball((0, .004, .126), (.074, .064, .074), BLACK, 32, 18)
ring((0, -.02, .19), (0, -.4, 1), .045, .014, BLACK2, (1, 1, .7))      # hood collar
for side in (-1, 1):                                                   # pink drawstrings
    tube((side * .016, -.06, .178), (side * .02, -.068, .125), .0035, PINK, verts=10)
ball((0, .004, .06), (.11, .1, .045), BLACK2, 28, 12)                  # skirt hem of the hoodie / shorts

# arms wrapped around the jar
JAR_C = V((0, -.088, .118))
for side in (-1, 1):
    sh = V((side * .07, 0, .162)); el = V((side * .078, -.05, .115)); hand = V((side * .046, -.098, .118))
    tube(sh, el, .026, BLACK); tube(el, hand, .025, BLACK)
    for t in (.35, .62):
        ring(el + (hand - el) * t, hand - el, .026, .0042, PINK)
    ring(hand + (el - hand).normalized() * .006, hand - el, .022, .006, BLACK2)
    ball(hand, (.02, .018, .02), SKIN, 18, 10)
o = ball((-.081, -.035, .145), (.004, .016, .016), PURPLE, 14, 8)            # crown patch on the left arm
o.rotation_euler = (0, 0, .3)
cone((-.086, -.036, .148), .007, .003, .006, GOLD2, (0, math.pi / 2, .3), 5)

# Rotkohl jar
tube(JAR_C - V((0, 0, .04)), JAR_C + V((0, 0, .03)), .036, JAR, caps=False, verts=32)
ball(JAR_C - V((0, 0, .04)), (.036, .036, .006), JAR, 28, 8)
tube(JAR_C - V((0, 0, .034)), JAR_C + V((0, 0, .024)), .031, CABBAGE, caps=False, verts=24)
tube(JAR_C + V((0, 0, .03)), JAR_C + V((0, 0, .04)), .033, JAR, caps=False, verts=32)
cloth = cone(JAR_C + V((0, 0, .046)), .052, .034, .016, CLOTH, verts=24)
for i in range(8):                                                     # white checks on the cloth cap
    a = i / 8 * math.tau
    ball(JAR_C + V((math.cos(a) * .04, math.sin(a) * .04, .044)), (.007, .007, .004), CLOTH2, 8, 6)
ball(JAR_C + V((0, 0, .056)), (.034, .034, .008), CLOTH, 24, 8)
ring(JAR_C + V((0, 0, .038)), (0, 0, 1), .036, .0022, TWINE)
ball(JAR_C + V((0, -.036, .04)), (.005, .003, .004), TWINE, 8, 6)
lab = ball(JAR_C + V((0, -.034, -.006)), (.026, .004, .016), LABEL, 20, 8)
bpy.ops.object.text_add(location=JAR_C + V((0, -.0395, -.004)), rotation=(math.pi / 2, 0, 0))
txt = bpy.context.object; txt.data.body = 'Rotkohl'; txt.data.size = .0115; txt.data.extrude = .0006
txt.data.align_x = 'CENTER'; txt.data.align_y = 'CENTER'
bpy.ops.object.convert(target='MESH'); done(txt, INK)
p = JAR_C + V((0, -.0392, -.016)); heart(p, .006, PINK)

# legs forward: black socks with pink stripes, paw-print soles
for side in (-1, 1):
    hip = V((side * .038, -.03, .045)); ankle = V((side * .048, -.165, .036))
    tube(hip, ankle, .026, BLACK)
    axis = ankle - hip
    for k in range(3):
        ring(hip + axis * (.45 + k * .14), axis, .0265, .0045, PINK)
    foot = ankle + V((0, -.028, .006))
    ball(foot, (.034, .03, .036), BLACK, 24, 12)
    sole = foot + V((0, -.03, 0))
    ball(sole, (.026, .004, .028), PAW, 20, 8)                         # main pad (facing the viewer)
    for k, (dx, dz) in enumerate(((-.022, .026), (-.008, .034), (.008, .034), (.022, .026))):
        ball(sole + V((dx, -.001, dz)), (.0075, .003, .0085), PAW, 12, 6)

# black cat tail curling up behind
bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
tail = bpy.context.object; sp = tail.data.splines[0]; sp.bezier_points.add(1)
for bp, (co, h1, h2) in zip(sp.bezier_points, [((0, .06, .05), (0, .02, .05), (-.03, .12, .03)),
                                                ((-.1, .16, .07), (-.09, .19, .02), (-.11, .13, .13)),
                                                ((-.13, .1, .19), (-.14, .13, .16), (-.12, .08, .22))]):
    bp.handle_left_type = bp.handle_right_type = 'FREE'; bp.co = co; bp.handle_left = h1; bp.handle_right = h2
tail.data.bevel_depth = .02; tail.data.bevel_resolution = 4; tail.data.use_fill_caps = True
bpy.ops.object.convert(target='MESH'); done(tail, BLACK)
ball((-.13, .1, .19), (.021, .021, .023), BLACK, 16, 10)

# ---------------------------------------------------------------- merge and export
for o in PARTS: o.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.join()
doll = bpy.context.object; doll.name = 'EinsmarelloPlush'
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
tris = sum(len(p.vertices) - 2 for p in doll.data.polygons); dims = doll.dimensions
bpy.ops.export_scene.gltf(filepath=str(OUT / 'einsmarello-plush.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print(f'einsmarello plush: {tris} triangles, {len(doll.data.materials)} materials, size {dims.x:.3f} x {dims.y:.3f} x {dims.z:.3f} m')
