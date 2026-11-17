"""Jule_heartbeat plush doll for After Play 4.7.0.

Character: Jule_heartbeat (credited in the game). Original plush interpretation after the cosy
plush streamer picture: long wavy auburn hair with a side parting, white headphones with grey
cushions and a lilac heart, big blue eyes with heart highlights, soft smile and blush, black hoodie
with a white heart embroidery, black joggers with white stitching, white socks, and a sleeping black
and white tuxedo cat hugged in both arms. Built from primitives with the felt material and helpers
of the Rosenyan script.

Run: blender -b --python tools/model-after-play-jule-v470.py   (Blender 5.0)
Output: games/kinderparadies/assets/jule-v470/jule-plush.glb
Blender: up +Z, faces -Y, origin = seat.
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_source = (ROOT / 'tools/model-after-play-rosenyan-v450.py').read_text(encoding='utf-8-sig')
exec(_source.split('# ---------------------------------------------------------------- head and face')[0])
OUT = ROOT / 'games/kinderparadies/assets/jule-v470'
OUT.mkdir(parents=True, exist_ok=True)

def jmat(name, hex_color, rough=1.0, felt=True):
    m = mat('J_' + name, hex_color, rough, felt)
    m.name = 'Jule_' + name
    return m

SKIN = jmat('skin', 'f6dcc8'); HAIR = jmat('hair', '6e3220'); HAIR2 = jmat('hair_shade', '4e2216'); HAIR3 = jmat('hair_light', '8a4428')
BLACK = jmat('black_felt', '211c22'); BLACK2 = jmat('black_soft', '302a31'); WHITE = jmat('white_felt', 'f4f0ec')
GREY = jmat('cushion_grey', 'a7a2aa'); LILAC = jmat('lilac', 'b493e0'); SOCK = jmat('sock', 'f2efe8')
LASH = jmat('lash', '1c1218', .35, False); IRIS = jmat('iris', '3f6fcf', .25, False); IRIS2 = jmat('iris_light', '9cc4ff', .25, False)
PUPIL = jmat('pupil', '1d2a5c', .25, False); SHINE = jmat('shine', 'ffffff', .1, False); MOUTH = jmat('mouth', 'd2507a', .6, False)
BLUSH = jmat('blush', 'ff9fb0'); CATPINK = jmat('cat_pink', 'f5a3b5'); CATLINE = jmat('cat_line', '161216', .5, False)

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

def lock(points, radii, material, res=10):
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    c = bpy.context.object; sp = c.data.splines[0]
    sp.bezier_points.add(len(points) - 2)
    for bp, co, r in zip(sp.bezier_points, points, radii):
        bp.co = co; bp.radius = r; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    c.data.bevel_depth = 1.0; c.data.bevel_resolution = 5; c.data.resolution_u = res; c.data.use_fill_caps = True
    bpy.ops.object.convert(target='MESH')
    return done(bpy.context.object, material)

for side in (-1, 1):
    az = side * .37; el = -.1
    decal(az, el, .001, (.031, .004, .036), LASH)                # dark outline
    decal(az, el - .02, .0025, (.027, .004, .03), IRIS)           # blue iris
    decal(az, el - .11, .0035, (.022, .004, .012), IRIS2)         # light lower half
    decal(az, el - .01, .0045, (.013, .004, .014), PUPIL)
    p, n = head_point(az - side * .035, el + .06, .007); heart(p, .011, SHINE, n)   # heart highlight
    ball(on_head(az + side * .05, el - .1, .006), (.004, .004, .004), SHINE, 8, 6)
    p, n = head_point(side * .63, el + .1, .0012)                                  # flicked lashes
    o = ball(p, (.014, .003, .004), LASH, 12, 6); facing(o, n)
    decal(side * .37, .2, .001, (.016, .003, .003), HAIR2, roll=-side * .1)        # soft brows
    for k in range(3):                                                              # blush strokes
        decal(side * (.6 + k * .05), -.4, .0012, (.003, .002, .009), BLUSH, roll=.4 * side)
p, n = head_point(0, -.5, .0012)                                                   # small smile
o = ball(p, (.016, .002, .0035), MOUTH, 16, 6); facing(o, n)
for side in (-1, 1):
    o = ball(on_head(side * .14, -.47, .0012), (.005, .002, .003), MOUTH, 8, 6)
    facing(o, head_point(side * .14, -.47)[1])

# ---------------------------------------------------------------- long wavy auburn hair
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1, location=H + V((0, .012, .012)))
cap = bpy.context.object; cap.scale = (RX * 1.1, RY * 1.12, RZ * 1.1)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bm = bmesh.new(); bm.from_mesh(cap.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -.035 and v.co.z < .05 and abs(v.co.x) < .1], context='VERTS')
bm.to_mesh(cap.data); bm.free(); done(cap, HAIR)
# Side-parted fringe sweeping to her right, framing the forehead.
for i, az in enumerate((-.85, -.55, -.28, -.02, .24, .5, .78)):
    sweep = -.16
    pts = [on_head(.35 + az * .2, 1.05, .006), on_head(az * .8 + sweep, .62, .013), on_head(az + sweep * .5, .32, .015), on_head(az, .12 + abs(az) * .08, .012)]
    lock(pts, (.03, .028, .02, .004), (HAIR, HAIR2, HAIR3)[i % 3])
# Long waves down both sides to the lap, a gentle S curve each.
for side in (-1, 1):
    for k in range(6):
        x0 = side * (.1 + k * .007); y0 = -.04 + k * .03; w = .016 * (1 if k % 2 else -1)
        pts = [H + V((x0 * .85, y0, .08)), H + V((x0 * 1.22, y0 + .005, -.04)), V((side * (.15 + .008 * k) + side * w, y0 + .01, .19)),
               V((side * (.16 + .008 * k) - side * w, y0 + .02, .12)), V((side * (.155 + .01 * k) + side * w, y0 + .02, .06)), V((side * (.15 + .01 * k), y0 + .03, .01))]
        lock(pts, (.03, .034, .03, .028, .022, .008), (HAIR, HAIR2, HAIR3)[(k + (side > 0)) % 3], 14)
for k in range(7):
    x = (k - 3) * .028
    pts = [H + V((x * .8, .1, .07)), H + V((x * 1.1, .135, -.06)), V((x * 1.2, .14, .15)), V((x * 1.25 + .01 * (-1) ** k, .135, .08)), V((x * 1.2, .12, .012))]
    lock(pts, (.034, .04, .034, .03, .008), (HAIR2, HAIR, HAIR3)[k % 3], 12)

# ---------------------------------------------------------------- white headphones
lock([H + V((-.146, .012, .0)), H + V((-.12, .012, .1)), H + V((0, .012, .15)), H + V((.12, .012, .1)), H + V((.146, .012, .0))],
     (.013, .014, .015, .014, .013), WHITE, 16)
for side in (-1, 1):
    cup = H + V((side * (RX * 1.2), .012, -.01))
    tube(cup - V((side * .02, 0, 0)), cup + V((side * .02, 0, 0)), .05, WHITE, caps=False, verts=28)
    ball(cup + V((side * .021, 0, 0)), (.009, .047, .047), WHITE, 24, 12)
    ring(cup - V((side * .021, 0, 0)), (1, 0, 0), .046, .011, GREY)                   # grey cushion
    p = cup + V((side * .031, -.004, .002)); heart(p, .022, LILAC, (side, 0, 0))     # lilac heart

# ---------------------------------------------------------------- body: black hoodie, joggers, socks
tube((0, 0, .17), (0, 0, .2), .028, SKIN, caps=False)
ball((0, .004, .126), (.078, .066, .076), BLACK, 32, 18)
ring((0, -.02, .19), (0, -.4, 1), .046, .014, BLACK2, (1, 1, .7))       # hood collar
ball((0, .05, .19), (.07, .04, .04), BLACK2, 20, 10)                     # hood behind the neck
for side in (-1, 1):                                                     # white drawstrings
    tube((side * .016, -.062, .178), (side * .019, -.07, .14), .0032, WHITE, verts=10)
heart(V((.045, -.07, .148)), .012, WHITE, (.3, -1, 0))                    # embroidered heart
for k in range(3):
    a = -.6 + k * .5
    tube(V((.045 + math.cos(a) * .016, -.068, .148 + math.sin(a) * .016 + .004)), V((.045 + math.cos(a) * .021, -.068, .148 + math.sin(a) * .021 + .004)), .0011, WHITE, caps=False, verts=6)
ball((0, .004, .06), (.112, .1, .046), BLACK2, 28, 12)                   # joggers seat

# The sleeping tuxedo cat, hugged against the chest.
C = V((0, -.085, .118))
ball(C, (.062, .04, .036), BLACK, 28, 14)                               # curled body
ball(C + V((.01, -.033, -.004)), (.03, .012, .022), WHITE, 18, 10)       # white chest
cat_h = C + V((-.032, -.022, .03))
ball(cat_h, (.036, .032, .03), BLACK, 24, 14)                            # head
ball(cat_h + V((0, -.024, -.009)), (.022, .012, .014), WHITE, 18, 10)    # white muzzle
ball(cat_h + V((0, -.034, -.004)), (.004, .003, .003), CATPINK, 8, 6)    # nose
for side in (-1, 1):
    cone(cat_h + V((side * .02, .004, .028)), .014, .002, .022, BLACK, (math.radians(-10), side * math.radians(25), 0), 16)
    cone(cat_h + V((side * .02, -.002, .027)), .009, .001, .016, CATPINK, (math.radians(-10), side * math.radians(25), 0), 12)
    eye = cat_h + V((side * .013, -.031, .006))                          # closed sleepy eyes
    o = tube(eye - V((.005, 0, 0)), eye + V((.005, 0, -.002 * side)), .0013, WHITE, caps=False, verts=6)
    for k in range(2):                                                   # whiskers
        tube(cat_h + V((side * .016, -.034, -.006 - k * .004)), cat_h + V((side * .04, -.03, -.004 - k * .007)), .0006, WHITE, caps=False, verts=4)
ball(C + V((.045, -.03, -.022)), (.014, .012, .01), WHITE, 12, 8)        # white paw
lock([C + V((.055, .0, -.02)), C + V((.07, -.03, -.03)), C + V((.03, -.045, -.034))], (.011, .01, .006), BLACK, 10)  # tail

# arms around the cat, white hands
for side in (-1, 1):
    sh = V((side * .072, 0, .162)); el = V((side * .08, -.05, .112)); hand = V((side * .042, -.105, .112))
    tube(sh, el, .027, BLACK); tube(el, hand, .026, BLACK)
    ring(hand + (el - hand).normalized() * .006, hand - el, .022, .006, BLACK2)
    ball(hand, (.02, .018, .02), SKIN, 18, 10)

# legs forward: black joggers with white stitching, white socks
for side in (-1, 1):
    hip = V((side * .04, -.03, .045)); ankle = V((side * .05, -.165, .036))
    tube(hip, ankle, .03, BLACK2)
    axis = ankle - hip
    tube(hip + V((side * .029, -.01, .006)), ankle + V((side * .029, 0, .004)), .0012, WHITE, caps=False, verts=6)   # side seam
    ring(ankle - axis.normalized() * .01, axis, .03, .006, BLACK)                                                    # cuff
    foot = ankle + V((0, -.028, .006))
    ball(foot, (.034, .032, .037), SOCK, 24, 12)
    ring(ankle + axis.normalized() * .004, axis, .027, .004, SOCK)

# ---------------------------------------------------------------- merge and export
for o in PARTS: o.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.join()
doll = bpy.context.object; doll.name = 'JulePlush'
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
tris = sum(len(p.vertices) - 2 for p in doll.data.polygons); dims = doll.dimensions
bpy.ops.export_scene.gltf(filepath=str(OUT / 'jule-plush.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print(f'jule plush: {tris} triangles, {len(doll.data.materials)} materials, size {dims.x:.3f} x {dims.y:.3f} x {dims.z:.3f} m')
