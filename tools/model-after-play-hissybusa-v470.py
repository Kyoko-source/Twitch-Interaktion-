"""Hissybusa plush doll for After Play 4.7.0.

Character and voice: Hissybusa (credited in the game). Original plush interpretation after the
felt plush picture: black cap with a white scrawled logo, brown hair, full brown beard, brown heart
eyes, open happy smile with blush, black headphones with a red-violet-blue rim, black hoodie with
purple stripes and drawstrings, a purple chat-bubble patch and a white band logo, black sneakers
with gamepad soles. Built from primitives with the felt material and helpers of the Rosenyan script.

Run: blender -b --python tools/model-after-play-hissybusa-v470.py
Output: games/kinderparadies/assets/hissybusa-v470/hissybusa-plush.glb
Blender: up +Z, faces -Y, origin = seat.
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_source = (ROOT / 'tools/model-after-play-rosenyan-v450.py').read_text(encoding='utf-8-sig')
exec(_source.split('# ---------------------------------------------------------------- head and face')[0])
OUT = ROOT / 'games/kinderparadies/assets/hissybusa-v470'
OUT.mkdir(parents=True, exist_ok=True)

def hmat(name, hex_color, rough=1.0, felt=True, glow=0.0):
    m = mat('H_' + name, hex_color, rough, felt)
    m.name = 'Hissybusa_' + name
    if glow:
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        c = tuple((int(hex_color[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))
        bsdf.inputs['Emission Color'].default_value = (*c, 1); bsdf.inputs['Emission Strength'].default_value = glow
    return m

SKIN = hmat('skin', 'f2c9a8'); HAIR = hmat('hair', '5a3420'); HAIR2 = hmat('hair_shade', '42251a')
BEARD = hmat('beard', '5e3622'); BEARD2 = hmat('beard_shade', '45281a')
BLACK = hmat('black_felt', '1c1a20'); BLACK2 = hmat('black_soft', '2c2930'); WHITE = hmat('white_stitch', 'eeeaf2')
PURPLE = hmat('purple', '8a4fd8'); VIOLET = hmat('violet_glow', 'b06cff', .6, False, 1.6)
RED = hmat('rim_red', 'e0405a', .6, False, 1.2); BLUE = hmat('rim_blue', '4f7cff', .6, False, 1.2)
LASH = hmat('lash', '1a100c', .35, False); IRIS = hmat('iris', '6e3a1c', .25, False); IRIS2 = hmat('iris_light', 'a8683a', .25, False); PUPIL = hmat('pupil', '2a140c', .25, False)
SHINE = hmat('shine', 'ffffff', .1, False); MOUTH = hmat('mouth', '5a1e22', .6, False); TONGUE = hmat('tongue', 'ff8090', .6, False)
TEETH = hmat('teeth', 'fff6ee', .4, False); BLUSH = hmat('blush', 'ff8f9a')

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
    n = V(normal).normalized(); right = n.cross(V((0, 0, 1))).normalized(); up = right.cross(n).normalized()
    for s in (-1, 1):
        o = ball(V(center) + right * s * size * .45 + up * size * .2, (size * .5, size * .5, size * .5), material, 12, 8)
        o.scale = (size * .5, size * .18, size * .5); facing(o, n)
    o = cone(V(center) - up * size * .35, size * .78, 0, size * .9, material, verts=12)
    o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = (-up).to_track_quat('Z', 'Y'); o.scale = (1, .25, 1)

for side in (-1, 1):
    az = side * .38; el = .06
    decal(az, el, .001, (.03, .004, .034), LASH)                  # dark outline
    decal(az, el - .02, .0025, (.026, .004, .028), IRIS)          # warm brown iris
    decal(az, el - .12, .0035, (.021, .004, .011), IRIS2)         # light lower half
    p, n = head_point(az, el - .02, .0048); heart(p, .02, PUPIL, n)           # dark heart pupil
    p, n = head_point(az - side * .045, el + .07, .007); heart(p, .009, SHINE, n)
    ball(on_head(az + side * .06, el - .12, .006), (.004, .004, .004), SHINE, 8, 6)
    decal(side * .4, .38, .001, (.024, .003, .005), HAIR2, roll=-side * .12)     # thick brows
    for k in range(3):                                                           # blush strokes above the beard
        decal(side * (.62 + k * .05), -.14, .0012, (.003, .002, .009), BLUSH, roll=.4 * side)

# ---------------------------------------------------------------- beard and smile
# Full beard: a felt shell around the lower face plus curly tufts along its edge.
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1, location=H + V((0, -.014, -.035)))
shell = bpy.context.object; shell.scale = (RX * 1.1, RY * 1.16, RZ * 1.02)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bm = bmesh.new(); bm.from_mesh(shell.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > -.05 + abs(v.co.x) * .4 or v.co.y > .05], context='VERTS')
bm.to_mesh(shell.data); bm.free(); done(shell, BEARD)
for i in range(7):                                                        # a few big soft tufts along the jaw
    az = -1.2 + i * .4; el = -.72 - .12 * math.cos(az)
    decal(az, el, .02, (.04, .03, .04), BEARD2 if i % 2 else BEARD, 18)
ball(H + V((0, -.088, -.13)), (.06, .046, .046), BEARD, 28, 16)           # full rounded chin
for side in (-1, 1):
    ball(H + V((side * .095, -.06, -.095)), (.044, .042, .048), BEARD, 24, 14)   # full cheeks
    o = ball(on_head(side * .13, -.27, .012), (.036, .011, .011), BEARD2, 18, 10)  # moustache
    o.rotation_euler = (0, side * .3, 0)
# Wide open laugh in the middle of the beard.
p, n = head_point(0, -.48, .016)
mouth = ball(p, (.036, .008, .024), MOUTH, 20, 10); facing(mouth, n)
ball(p + n * .003 + V((0, 0, -.009)), (.021, .004, .011), TONGUE, 14, 8)
ball(p + n * .003 + V((0, 0, .014)), (.026, .004, .005), TEETH, 14, 6)

# ---------------------------------------------------------------- hair and cap
for i, az in enumerate((-1.25, -1.05, 1.05, 1.25)):                       # tufts poking out under the cap
    lock_pts = [on_head(az, .25, .008), on_head(az * 1.05, .02, .016), on_head(az * 1.1, -.18, .012)]
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    c = bpy.context.object; sp = c.data.splines[0]; sp.bezier_points.add(1)
    for bp, co, r in zip(sp.bezier_points, lock_pts, (.026, .022, .006)):
        bp.co = co; bp.radius = r; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    c.data.bevel_depth = 1.0; c.data.bevel_resolution = 4; c.data.use_fill_caps = True
    bpy.ops.object.convert(target='MESH'); done(bpy.context.object, HAIR if i % 2 else HAIR2)
for k, az in enumerate((-.5, -.25, 0, .22, .46)):                        # fringe falling onto the forehead
    o = decal(az, .42, .012, (.03, .016, .026), HAIR if k % 2 else HAIR2, roll=.3 - k * .12, segments=16)
ball(H + V((0, .03, .02)), (RX * 1.03, RY * 1.0, RZ * 1.0), HAIR2, 32, 18)   # back of the head

# Cap crown: upper part of a sphere, slightly larger than the head.
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1, location=H + V((0, .006, .02)))
crown = bpy.context.object; crown.scale = (RX * 1.13, RY * 1.16, RZ * 1.1)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bm = bmesh.new(); bm.from_mesh(crown.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < .035], context='VERTS')
bm.to_mesh(crown.data); bm.free(); done(crown, BLACK)
ring(H + V((0, .006, .056)), (0, 0, 1), RX * 1.11, .008, BLACK2, (1, RY / RX * 1.03, 1))     # band
bill = ball(H + V((0, -.128, .07)), (.105, .07, .012), BLACK, 32, 12); bill.rotation_euler = (math.radians(-12), 0, 0)
ring(H + V((0, -.128, .07)), (0, -.2, 1), .1, .0035, BLACK2, (1, .68, 1))
ball(H + V((0, .006, .153)), (.012, .012, .008), BLACK2, 12, 8)                              # button
# White scrawled band logo on the front panel: a jagged row of thin felt strokes.
logo_c = on_head(0, .78, .03)
for k in range(11):
    x = (k - 5) * .0085; h = .012 + .009 * abs(math.sin(k * 2.3)) + (.008 if k in (2, 5, 8) else 0)
    o = tube(logo_c + V((x, 0, -h * .5)), logo_c + V((x + .004 * math.sin(k), -.004, h * .5)), .0016, WHITE, caps=False, verts=6)
for k in range(4):
    a = k * .9
    tube(logo_c + V((-.045, -.002, -.004 + k * .004)), logo_c + V((.045, -.002, -.006 + k * .005 - .006 * math.sin(a))), .0011, WHITE, caps=False, verts=6)
for side in (-1, 1):                                                      # side scrawl patches
    p, n = head_point(side * 1.0, .62, .028)
    for k in range(4):
        tube(p + V((0, -.006 + k * .004, -.008)), p + V((0, -.004 + k * .004, .009)), .0014, WHITE, caps=False, verts=6)

# ---------------------------------------------------------------- headphones over the cap
lock_band = [H + V((-.15, .02, .0)), H + V((-.13, .02, .11)), H + V((0, .02, .162)), H + V((.13, .02, .11)), H + V((.15, .02, .0))]
bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
band = bpy.context.object; sp = band.data.splines[0]; sp.bezier_points.add(len(lock_band) - 2)
for bp, co in zip(sp.bezier_points, lock_band):
    bp.co = co; bp.radius = .012; bp.handle_left_type = bp.handle_right_type = 'AUTO'
band.data.bevel_depth = 1.0; band.data.bevel_resolution = 4; band.data.resolution_u = 16; band.data.use_fill_caps = True
bpy.ops.object.convert(target='MESH'); done(bpy.context.object, BLACK2)
for side in (-1, 1):
    cup = H + V((side * (RX * 1.2), .015, -.012))
    tube(cup - V((side * .02, 0, 0)), cup + V((side * .02, 0, 0)), .052, BLACK, caps=False, verts=28)
    ball(cup + V((side * .021, 0, 0)), (.008, .048, .048), BLACK2, 24, 12)
    ring(cup + V((side * .022, 0, 0)), (1, 0, 0), .046, .005, RED if side < 0 else BLUE)   # glowing rim
    ring(cup + V((side * .022, 0, 0)), (1, 0, 0), .038, .0035, VIOLET)
    ring(cup - V((side * .021, 0, 0)), (1, 0, 0), .05, .008, BLACK2)                        # cushion

# ---------------------------------------------------------------- body in a black hoodie
tube((0, 0, .17), (0, 0, .2), .03, BEARD, caps=False)                    # beard hides the neck
ball((0, .004, .126), (.08, .068, .078), BLACK, 32, 18)
ring((0, -.018, .19), (0, -.4, 1), .05, .015, BLACK2, (1, 1, .7))        # hood collar
ball((0, .05, .19), (.07, .04, .04), BLACK2, 20, 10)                      # hood behind the neck
for side in (-1, 1):                                                      # purple drawstrings with tips
    tube((side * .018, -.064, .18), (side * .022, -.074, .118), .0035, PURPLE, verts=10)
    ball((side * .022, -.075, .113), (.005, .005, .007), WHITE, 8, 6)
ball((0, -.064, .085), (.05, .012, .022), BLACK2, 20, 8)                  # front pocket
o = ball((-.042, -.064, .15), (.013, .004, .012), PURPLE, 14, 8)          # chat-bubble patch
cone((-.047, -.064, .136), .005, 0, .008, PURPLE, (0, 0, 0), 6)
for k in (-1, 1):
    tube((-.042 + k * .004, -.069, .147), (-.042 + k * .004, -.069, .153), .0011, WHITE, caps=False, verts=6)
logo = V((.012, -.068, .14))                                              # white spiky band logo
for k in range(9):
    x = (k - 4) * .006; h = .008 + .006 * abs(math.sin(k * 1.9))
    tube(logo + V((x, 0, -h * .5)), logo + V((x + .003 * math.sin(k * 3), -.002, h * .5)), .0012, WHITE, caps=False, verts=6)
ball((0, .004, .06), (.115, .1, .046), BLACK2, 28, 12)                    # hoodie hem / trousers

# arms resting on the knees, purple stripes at the cuffs
for side in (-1, 1):
    sh = V((side * .078, 0, .165)); el = V((side * .09, -.04, .1)); hand = V((side * .062, -.105, .07))
    tube(sh, el, .028, BLACK); tube(el, hand, .027, BLACK)
    for t in (.55, .72):
        ring(el + (hand - el) * t, hand - el, .028, .0045, PURPLE)
    ring(hand + (el - hand).normalized() * .006, hand - el, .024, .006, BLACK2)
    ball(hand, (.022, .02, .021), SKIN, 18, 10)

# legs forward: black trousers with purple side stripes, sneakers with gamepad soles
for side in (-1, 1):
    hip = V((side * .042, -.03, .045)); ankle = V((side * .052, -.165, .036))
    tube(hip, ankle, .029, BLACK)
    axis = ankle - hip
    for k in range(2):
        ring(hip + axis * (.62 + k * .16), axis, .0295, .0045, PURPLE)
    foot = ankle + V((0, -.03, .008))
    ball(foot, (.038, .033, .04), BLACK2, 24, 12)
    sole = foot + V((0, -.033, 0))
    ball(sole, (.031, .004, .031), BLACK, 20, 8)
    pad = sole + V((0, -.004, 0))                                         # white gamepad outline
    ring(pad, (0, -1, 0), .02, .0018, WHITE, (1.25, 1, .75))
    for dx in (-.009, .009):                                              # grips
        ring(pad + V((dx * 1.9, 0, -.009)), (0, -1, 0), .006, .0016, WHITE)
    tube(pad + V((-.016, -.001, 0)), pad + V((-.008, -.001, 0)), .0015, WHITE, caps=False, verts=6)   # d-pad
    tube(pad + V((-.012, -.001, -.004)), pad + V((-.012, -.001, .004)), .0015, WHITE, caps=False, verts=6)
    for dx, dz in ((.01, 0), (.016, 0), (.013, .003), (.013, -.003)):    # face buttons
        ball(pad + V((dx, -.001, dz)), (.0018, .001, .0018), WHITE, 8, 6)

# ---------------------------------------------------------------- merge and export
for o in PARTS: o.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.join()
doll = bpy.context.object; doll.name = 'HissybusaPlush'
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
tris = sum(len(p.vertices) - 2 for p in doll.data.polygons); dims = doll.dimensions
bpy.ops.export_scene.gltf(filepath=str(OUT / 'hissybusa-plush.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print(f'hissybusa plush: {tris} triangles, {len(doll.data.materials)} materials, size {dims.x:.3f} x {dims.y:.3f} x {dims.z:.3f} m')
