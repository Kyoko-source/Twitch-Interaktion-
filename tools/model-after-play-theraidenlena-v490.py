"""theraidenlena plush doll for After Play 4.9.1.

Character: theraidenlena (play tester, credited in the game). Original plush interpretation after
her felt plush picture: messy dark brown hair with red streaks and a single antenna lock, a red
spider-lily flower with gold stamens on her left, big red eyes, open happy smile with one small
fang and blush, black choker, red bodice with red gold-trimmed shoulder capes, black corset with
gold lacing, layered black and red ruffled skirt with gold trim, a big red bow with a gold bead and
tassel at her left hip, black wrist cuffs with red stripes, black boots with red frills.
Built from primitives with the felt material and helpers of the Rosenyan script.

Run: blender -b --python tools/model-after-play-theraidenlena-v490.py   (Blender 4.5+)
Output: games/kinderparadies/assets/theraidenlena-v490/theraidenlena-plush.glb
Blender: up +Z, faces -Y, origin = seat.
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_source = (ROOT / 'tools/model-after-play-rosenyan-v450.py').read_text(encoding='utf-8-sig')
exec(_source.split('# ---------------------------------------------------------------- head and face')[0])
OUT = ROOT / 'games/kinderparadies/assets/theraidenlena-v490'
OUT.mkdir(parents=True, exist_ok=True)

def lmat(name, hex_color, rough=1.0, felt=True):
    m = mat('L_' + name, hex_color, rough, felt)
    m.name = 'Theraidenlena_' + name
    return m

SKIN = lmat('skin', 'f8dcc8'); HAIR = lmat('hair', '2c1b1c'); HAIR2 = lmat('hair_shade', '1b1113'); STREAK = lmat('hair_red', 'a81c24')
BLACK = lmat('black_felt', '1d181b'); BLACK2 = lmat('black_soft', '2c2529'); RED = lmat('red_felt', 'b3161f'); RED2 = lmat('red_dark', '7e0f17')
GOLD = lmat('gold_trim', 'd2a640', .55, False); GOLD2 = lmat('gold_bead', 'e6bf55', .35, False)
LASH = lmat('lash', '1a0d10', .35, False); IRIS = lmat('iris', 'b8121a', .25, False); IRIS2 = lmat('iris_light', 'ff4d3d', .25, False)
PUPIL = lmat('pupil', '3a0408', .25, False); SHINE = lmat('shine', 'ffffff', .1, False); MOUTH = lmat('mouth', '6a1420', .6, False)
TONGUE = lmat('tongue', 'ff7f8e', .6, False); FANG = lmat('fang', 'fffaf4', .4, False); BLUSH = lmat('blush', 'ff9aa6')

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

def lock(points, radii, material, res=10):
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    c = bpy.context.object; sp = c.data.splines[0]
    sp.bezier_points.add(len(points) - 2)
    for bp, co, r in zip(sp.bezier_points, points, radii):
        bp.co = co; bp.radius = r; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    c.data.bevel_depth = 1.0; c.data.bevel_resolution = 5; c.data.resolution_u = res; c.data.use_fill_caps = True
    bpy.ops.object.convert(target='MESH')
    return done(bpy.context.object, material)

# Big red eyes: dark rim, red iris, bright lower half, dark pupil, two white highlights.
for side in (-1, 1):
    az = side * .37; el = -.1
    decal(az, el, .001, (.032, .004, .037), LASH)
    decal(az, el - .02, .0025, (.028, .004, .031), IRIS)
    decal(az, el - .11, .0035, (.022, .004, .012), IRIS2)
    decal(az, el - .01, .0045, (.013, .004, .015), PUPIL)
    ball(on_head(az - side * .045, el + .06, .007), (.007, .004, .008), SHINE, 10, 6)
    ball(on_head(az + side * .05, el - .1, .006), (.0035, .0035, .0035), SHINE, 8, 6)
    p, n = head_point(side * .64, el + .1, .0012)                                   # flicked outer lashes
    o = ball(p, (.015, .003, .004), LASH, 12, 6); facing(o, n)
    decal(side * .37, .21, .001, (.016, .003, .003), HAIR2, roll=-side * .12)       # brows
    decal(side * .66, -.4, .0012, (.017, .002, .011), BLUSH)                        # round blush
# Open happy smile with tongue and one small fang on her right.
p, n = head_point(0, -.5, .0012); o = ball(p, (.021, .003, .015), MOUTH, 20, 10); facing(o, n)
p, n = head_point(0, -.56, .0022); o = ball(p, (.013, .003, .007), TONGUE, 16, 8); facing(o, n)
p, n = head_point(-.07, -.415, .003)
o = cone(p, .0042, 0, .009, FANG, verts=10); o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = V((0, -.2, -1)).to_track_quat('Z', 'Y')
p, n = head_point(0, -.42, .0012); o = ball(p, (.022, .002, .0022), MOUTH, 16, 6); facing(o, n)       # upper lip line

# ---------------------------------------------------------------- messy dark hair with red streaks
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1, location=H + V((0, .012, .014)))
cap = bpy.context.object; cap.scale = (RX * 1.12, RY * 1.14, RZ * 1.12)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bm = bmesh.new(); bm.from_mesh(cap.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -.035 and v.co.z < .05 and abs(v.co.x) < .1], context='VERTS')
bm.to_mesh(cap.data); bm.free(); done(cap, HAIR)
# Choppy fringe: pointed locks over the forehead, two of them red.
for i, az in enumerate((-.9, -.62, -.36, -.12, .1, .34, .6, .86)):
    tip_el = .08 + (i % 2) * .07 + abs(az) * .05
    pts = [on_head(az * .3, 1.0, .006), on_head(az * .8, .6, .014), on_head(az * 1.02 + (.05 if i % 2 else -.05), .32, .016), on_head(az * 1.05, tip_el, .012)]
    lock(pts, (.03, .027, .019, .003), STREAK if i in (2, 5) else (HAIR, HAIR2)[i % 2])
# Shaggy bob at the sides, ending at the jaw with the tips curling in; the front lock is red.
for side in (-1, 1):
    for k, y0 in enumerate((-.055, -.02, .015, .05)):
        pts = [H + V((side * .095, y0, .075)), H + V((side * .132, y0 + .004, -.02)), V((side * .142, y0 + .006, .205)), V((side * .128, y0 - .004, .188))]
        lock(pts, (.027, .028, .02, .004), STREAK if k == 2 else (HAIR, HAIR2)[(k + (side > 0)) % 2], 12)
# Back of the head: short layered locks ending at the nape, flicking out a little.
for k in range(7):
    x = (k - 3) * .03
    pts = [H + V((x * .8, .095, .07)), H + V((x * 1.08, .125, -.05)), V((x * 1.2, .128, .208)), V((x * 1.3, .142, .195))]
    lock(pts, (.033, .034, .024, .004), STREAK if k in (1, 5) else (HAIR2, HAIR)[k % 2], 12)
# The single antenna lock curling forward.
top = H + V((0, .0, RZ * 1.08))
lock([top, top + V((0, 0, .03)), top + V((0, -.022, .052)), top + V((0, -.04, .042))], (.01, .009, .006, .002), HAIR, 14)

# ---------------------------------------------------------------- red spider-lily on her left (+X)
F = on_head(.95, .45, .03)
fn = (F - H).normalized()
ball(F, (.016, .016, .016), RED2, 16, 10)
right = fn.cross(V((0, 0, 1))).normalized(); up = right.cross(fn).normalized()
for k in range(6):
    a = k * math.tau / 6
    d = right * math.cos(a) + up * math.sin(a)
    petal = ball(F + d * .028 + fn * .004, (.022, .008, .011), RED, 16, 8)
    petal.rotation_mode = 'QUATERNION'; petal.rotation_quaternion = d.to_track_quat('X', 'Z')
    tip = F + d * .05 + fn * .018                                                    # curling lily petal tips
    lock([F + d * .02 + fn * .008, F + d * .04 + fn * .02, tip], (.006, .005, .0015), RED, 8)
for k in range(5):                                                                  # gold stamens with beads
    a = k * math.tau / 5 + .3
    d = right * math.cos(a) + up * math.sin(a)
    end = F + fn * .03 + d * .012
    tube(F + fn * .01, end, .0012, GOLD, caps=False, verts=6)
    ball(end, (.0035, .0035, .0035), GOLD2, 8, 6)

# ---------------------------------------------------------------- body: choker, bodice, capes, corset
tube((0, 0, .17), (0, 0, .2), .028, SKIN, caps=False)
ring((0, 0, .188), (0, 0, 1), .029, .006, BLACK)                                    # choker
ball(V((0, -.034, .186)), (.006, .004, .006), RED, 10, 6)                           # choker gem
ball((0, .004, .13), (.072, .062, .066), RED, 32, 18)                              # red bodice
for side in (-1, 1):                                                                # shoulder capes with a gold edge
    c = V((side * .07, .0, .158))
    cape = ball(c, (.042, .05, .03), RED, 24, 12); cape.rotation_euler = (0, side * .5, 0)
    edge = ball(c + V((side * .012, 0, -.014)), (.04, .048, .006), GOLD, 24, 8); edge.rotation_euler = (0, side * .5, 0)
ring((0, .004, .095), (0, 0, 1), .07, .018, BLACK, (1, .9, 1.35))                   # black corset
for k in range(3):                                                                  # gold lacing crosses
    z = .085 + k * .011
    for s in (-1, 1):
        tube(V((-.012, -.075, z)), V((.012, -.075, z + s * .008)), .0016, GOLD, caps=False, verts=6)

# Layered ruffled skirt over the seat: black outer layer, red under layer, gold trim.
ball((0, .004, .06), (.112, .1, .046), BLACK2, 28, 12)
for k, (r1, z, m) in enumerate(((.14, .045, RED), (.13, .06, BLACK))):
    sk = cone(V((0, .0, z)), r1, .072, .07, m, verts=40); sk.scale = (1, .92, 1)
    for j in range(16):                                                             # soft ruffle scallops
        a = j * math.tau / 16
        ball(V((math.cos(a) * r1 * .98, math.sin(a) * r1 * .9, z - .036)), (.022, .022, .012), m, 10, 6)
for j in range(16):                                                                 # gold dots along the black hem
    a = (j + .5) * math.tau / 16
    ball(V((math.cos(a) * .128, math.sin(a) * .118, .026)), (.004, .004, .004), GOLD2, 8, 6)

# Big red bow with gold edge, bead and tassel at her left hip.
B = V((.08, -.07, .085))
bow(B, .05, RED, (0, -1, 0))
ball(B + V((0, -.012, 0)), (.008, .008, .008), GOLD2, 12, 8)
tube(B + V((0, -.01, -.008)), B + V((.006, -.012, -.06)), .004, RED2, caps=False, verts=8)
cone(B + V((.007, -.012, -.072)), .009, .002, .024, RED, (math.pi, 0, 0), 12)        # tassel
ring(B + V((.006, -.012, -.058)), (0, 0, 1), .006, .0018, GOLD)

# ---------------------------------------------------------------- arms with striped cuffs, resting on the skirt
for side in (-1, 1):
    sh = V((side * .072, 0, .158)); el = V((side * .095, -.03, .108)); hand = V((side * .075, -.085, .085))
    tube(sh, el, .025, SKIN); tube(el, hand, .024, SKIN)
    axis = hand - el
    cuff = el + axis * .6
    tube(cuff - axis.normalized() * .012, cuff + axis.normalized() * .012, .028, BLACK, caps=False, verts=20)
    for t in (-.006, .006): ring(cuff + axis.normalized() * t, axis, .0285, .0022, RED)
    ball(hand, (.02, .018, .02), SKIN, 18, 10)

# ---------------------------------------------------------------- legs forward: black boots with red frills
for side in (-1, 1):
    hip = V((side * .042, -.04, .045)); ankle = V((side * .052, -.165, .036))
    axis = ankle - hip
    knee = hip + axis * .35
    tube(hip, knee, .029, SKIN, caps=False)
    tube(knee, ankle, .031, BLACK)                                                  # boot shaft
    for j in range(10):                                                             # red frill at the boot top
        a = j * math.tau / 10
        o = ball(knee + V((math.cos(a) * .032, 0, math.sin(a) * .032)), (.011, .007, .011), RED, 8, 6)
    ring(knee + axis.normalized() * .025, axis, .0315, .003, RED)                   # red stripe
    foot = ankle + V((0, -.028, .006))
    ball(foot, (.035, .033, .038), BLACK, 24, 12)

# ---------------------------------------------------------------- merge and export
for o in PARTS: o.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.join()
doll = bpy.context.object; doll.name = 'TheraidenlenaPlush'
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
tris = sum(len(p.vertices) - 2 for p in doll.data.polygons); dims = doll.dimensions
bpy.ops.export_scene.gltf(filepath=str(OUT / 'theraidenlena-plush.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print(f'theraidenlena plush: {tris} triangles, {len(doll.data.materials)} materials, size {dims.x:.3f} x {dims.y:.3f} x {dims.z:.3f} m')
