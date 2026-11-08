"""The chained corpse in the archive, rebuilt as a rotting body (4.3.1).

Run: blender -b --python tools/model-after-play-archive-corpse-v431.py
     (after tools/paint-after-play-archive-corpse-v431.py)
Slumped sitting on the floor with its back to the wall, both wrists chained
up and out, one knee drawn up, one leg sprawled, the head lolling forward to
the side. Leathery skin shrunk onto the bones and split open over the ribs
and belly, a dropped jaw full of teeth, stringy hair, rotted rags.
Head base: the project's credited Lee Perry-Smith scan (CC BY 3.0) via the
visitor helpers; everything else original. Blender: up +Z, faces -Y; the wall
is behind at +Y. Empties: LeftWrist, RightWrist, LeftAnkle, RightAnkle.
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, Matrix
from mathutils.noise import noise

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'tools/model-after-play-visitors-v421.py').read_text(encoding='utf-8')
exec(source.split('# ---------------------------------------------------------------- bodies')[0])
OUT = ROOT / 'games/kinderparadies/assets/finale'
V = Vector
rng = random.Random(431)
bpy.ops.wm.read_factory_settings(use_empty=True)

skin = material('Mummified leathery remnant', (.24, .18, .12), .7)
face = material('Corpse scanned complexion', (1, 1, 1), .7, texture=OUT / 'corpse-face.png')
bone = material('Ancient human bone', (.50, .44, .32), .85)
dark = material('Hollow cranial recess', (.012, .009, .006), 1.)
tooth = material('Rotten teeth', (.45, .38, .22), .5)
hair_m = material('Matted dead hair', (.10, .09, .08), .55)
shirt_m = material('Rotten shirt fabric', (.20, .17, .12), .95)
trouser_m = material('Rotten trouser fabric', (.09, .08, .07), .95)
nail = material('Blackened nail', (.03, .025, .02), .3)
leather = material('Cracked boot leather', (.09, .06, .04), .55)


def skinned(name, points, edges, mat, levels=2):
    me = bpy.data.meshes.new(name); me.from_pydata([p for p, r in points], edges, []); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    o.modifiers.new('skin', 'SKIN')
    for i, (p, r) in enumerate(points): me.skin_vertices[0].data[i].radius = r
    me.skin_vertices[0].data[0].use_root = True
    sub = o.modifiers.new('sub', 'SUBSURF'); sub.levels = levels
    bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.object.modifier_apply(modifier='skin'); bpy.ops.object.modifier_apply(modifier='sub')
    me.materials.clear(); me.materials.append(mat)
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    for f in me.polygons: f.use_smooth = True
    return o


def apply_all(o):
    bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# ---------------------------------------------------------------- skeleton points
PELVIS = V((0, .07, .13)); LUMBAR = V((0, .11, .30)); CHEST = V((0, .13, .50)); UPPER = V((0, .12, .63))
NECK = V((.02, .07, .72))
SH = {s: V((s * .185, .12, .635)) for s in (-1, 1)}
EL = {s: V((s * .40, .14, .80)) for s in (-1, 1)}
WR = {s: V((s * .47, .10, 1.06)) for s in (-1, 1)}
HIP = {s: V((s * .095, .04, .10)) for s in (-1, 1)}
KNEE = {1: V((.15, -.36, .40)), -1: V((-.17, -.44, .13))}
ANK = {1: V((.17, -.60, .07)), -1: V((-.24, -.84, .07))}

# ---------------------------------------------------------------- head (load_head clears the scene: first)
head = load_head()
for m in (face, dark, tooth): head.data.materials.append(m)
bm = bmesh.new(); bm.from_mesh(head.data); layer = bm.loops.layers.uv.active; bm.normal_update()
uvs = uv_of(bm, layer)
for v, (uu, ww) in uvs.items():
    if v.co.y > .03: continue
    push = 0.
    for cu in (.424, .579): push -= .03 * math.exp(-(((uu - cu) / .06) ** 2 + ((ww - .31) / .05) ** 2))
    push -= .03 * (math.exp(-(((uu - .34) / .05) ** 2 + ((ww - .45) / .08) ** 2)) + math.exp(-(((uu - .66) / .05) ** 2 + ((ww - .45) / .08) ** 2)))
    push -= .025 * math.exp(-(((uu - .5) / .035) ** 2 + ((ww - .40) / .05) ** 2))  # collapsed nose
    v.co += v.normal * (push + .003 * noise(v.co * 60))
# The jaw hangs open, lips shrunk back from the teeth.
for v, (uu, ww) in uv_of(bm, layer).items():
    if v.co.y < .03 and ww > .49:
        k = min(1, (ww - .49) / .08) * math.exp(-((uu - .5) / .17) ** 2)
        v.co.z -= .06 * k; v.co.y += .012 * k
for cu in (.424, .579):
    cut(bm, layer, lambda uu, ww, cu=cu: ((uu - cu) / .034) ** 2 + ((ww - .314) / .024) ** 2 < 1)
    throat(bm, lambda p, cu=cu: abs(p.z - .03) < .06 and (p.x < -.005 if cu < .5 else p.x > -.005), 1, .05)
cut(bm, layer, lambda uu, ww: ((uu - .5) / .022) ** 2 + ((ww - .405) / .03) ** 2 < 1)
throat(bm, lambda p: abs(p.x + .007) < .04 and -.03 < p.z < .02, 1, .03)
cut(bm, layer, lambda uu, ww: ((uu - .5) / .085) ** 2 + ((ww - .535) / .07) ** 2 < 1)
rim = throat(bm, lambda p: abs(p.x + .007) < .14 and p.z < -.03, 1, .06)
mid_z = sum(x.co.z for x in rim) / max(1, len(rim))
for v in rim:
    if rng.random() < .7:
        up = v.co.z > mid_z
        fang(bm, v.co + V((0, .006, 0)), v.co + V((rng.uniform(-.002, .002), .004, (-1 if up else 1) * rng.uniform(.014, .024))), rng.uniform(.004, .0055), 2)
bm.to_mesh(head.data); bm.free()
if 'custom_normal' in head.data.attributes: head.data.attributes.remove(head.data.attributes['custom_normal'])
head.scale = (.66,) * 3; head.location = (0, 0, 0); apply_all(head)
dec = head.modifiers.new('d', 'DECIMATE'); dec.ratio = .4; bpy.ops.object.modifier_apply(modifier='d')
for f in head.data.polygons: f.use_smooth = True

# Stringy hair left on the scalp, lying over the skull and hanging in clumps.
from mathutils.bvhtree import BVHTree
tree = BVHTree.FromObject(head, bpy.context.evaluated_depsgraph_get())
zs = [v.co.z for v in head.data.vertices]; top = max(zs)
hv, hf = [], []
for i in range(420):
    a = rng.uniform(-math.pi, math.pi); el = rng.uniform(.25, 1.)
    d = V((math.sin(a) * math.cos(el * 1.3), math.cos(a) * math.cos(el * 1.3), math.sin(el * 1.3))).normalized()
    if d.y < -.05 and d.z < .8: continue
    if noise(d * 3 + V((1, 2, 3))) > .25: continue  # bald, sloughed patches
    hit = tree.ray_cast(d * .4 + V((0, 0, .02)), -d)
    if hit[0] is None: continue
    p = hit[0] + hit[1] * .003; pts = [p.copy()]; dd = V((0, 0, -1))
    length = rng.uniform(.10, .26); seg = 10
    for k in range(seg):
        near = tree.find_nearest(p)
        if near[0] is not None and p.z > -.06:
            g = V((d.x * .3, d.y * .3, -1)); n = near[1]
            dd = (g - n * g.dot(n)).normalized(); p = p + dd * length / seg
            near = tree.find_nearest(p)
            if near[0] is not None: p = near[0] + near[1] * .004
        else:
            p = p + V((rng.uniform(-.01, .01), rng.uniform(-.01, .01), -1)).normalized() * length / seg
        pts.append(p.copy())
    base = len(hv); w = rng.uniform(.0008, .0016)
    for k, q in enumerate(pts):
        ah = (pts[min(k + 1, seg)] - pts[max(k - 1, 0)]).normalized()
        u1 = ah.cross(V((0, 1, 0)) if abs(ah.y) < .9 else V((1, 0, 0))).normalized(); u2 = ah.cross(u1)
        for j in range(3):
            an = j * math.tau / 3; hv.append(q + (u1 * math.cos(an) + u2 * math.sin(an)) * w * (1 - .5 * k / seg))
    for k in range(seg):
        for j in range(3):
            a0 = base + k * 3 + j; b0 = base + k * 3 + (j + 1) % 3; hf.append((a0, b0, b0 + 3, a0 + 3))
hair = new_obj('hair', hv, hf, [hair_m])
headgroup = join([head, hair], 'Head')
# Lolling forward and to the side, resting on the neck.
chin_drop = Matrix.Rotation(math.radians(-14), 4, 'X') @ Matrix.Rotation(math.radians(26), 4, 'Y')
headgroup.matrix_world = Matrix.Translation(NECK + V((.035, -.02, .115))) @ chin_drop
apply_all(headgroup)

# ---------------------------------------------------------------- torso shell
body = skinned('body', [(PELVIS, (.15, .11)), (LUMBAR, (.11, .075)), (CHEST, (.15, .095)), (UPPER, (.17, .085)),
                        (NECK, (.045, .042)), (SH[-1], (.05, .045)), (SH[1], (.05, .045)), (HIP[-1], (.08, .075)), (HIP[1], (.08, .075))],
               [(0, 1), (1, 2), (2, 3), (3, 4), (3, 5), (3, 6), (0, 7), (0, 8)], skin, 3)
bm = bmesh.new(); bm.from_mesh(body.data)
bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True); bm.normal_update()
for v in bm.verts:
    p = v.co.copy()
    # Skin shrunk onto the ribs, a collapsed belly and a sunken sternum.
    if .38 < p.z < .62 and p.y < .14:
        v.co += v.normal * (.008 * max(0, math.sin((p.z - .38) * 75)) - .01 * math.exp(-(p.x / .025) ** 2))
    if .17 < p.z < .37 and p.y < .1:
        v.co += v.normal * -.035 * math.exp(-(p.x / .09) ** 2)
    v.co += v.normal * .004 * noise(p * 30)
# Split open: ragged holes over the belly and the lower ribs on the front.
gone = []
for f in bm.faces:
    c = f.calc_center_median()
    if c.y < .09 and .16 < c.z < .52:
        n = noise(c * 14 + V((3, 1, 7))) + .35 * noise(c * 90)
        hole = (n > .05 and .18 < c.z < .40 and abs(c.x) < .1) or (n > .3 and c.z > .38 and -.13 < c.x < .02)
        if hole: gone.append(f)
bmesh.ops.delete(bm, geom=gone, context='FACES')
bm.to_mesh(body.data); bm.free()
solidify(body, .006)
for f in body.data.polygons: f.use_smooth = True

inner = []
# Exposed bone inside: ribs, sternum stub, spine; a dark cavity behind.
cavity = tube('cavity', [(0, .11, .18, .08, .05), (0, .12, .32, .085, .055), (0, .13, .48, .10, .06)], dark, 10, 14)
inner.append(cavity)
for k in range(9):
    z = .58 - k * .035
    for s in (-1, 1):
        w = .085 + .035 * math.sin(min(1, k / 6) * math.pi * .8)
        pts = [(s * .02, .175, z + .02), (s * w * .8, .17, z + .01), (s * (w + .015), .10, z - .005), (s * w * .85, .035, z - .02), (s * .035, .02 + k * .002, z - .04)]
        if k > 6 and s > 0: pts = pts[:3]  # snapped rib
        inner.append(tube('rib', [(x, y, zz, .0055, .004) for x, y, zz in pts], bone, 12, 6))
for k in range(14):
    z = .14 + k * .04
    inner.append(tube('vertebra', [(0, .16, z, .016, .014), (0, .16, z + .025, .016, .014)], bone, 2, 8))
inner.append(tube('sternum', [(0, .03, .56, .014, .006), (0, .022, .44, .012, .005)], bone, 4, 8))
torso = join([body] + inner, 'Torso')

# ---------------------------------------------------------------- limbs
parts = [torso, headgroup]
for s in (-1, 1):
    arm = skinned('arm', [(SH[s], (.042, .04)), ((SH[s] + EL[s]) / 2, (.03, .028)), (EL[s], (.034, .03)), ((EL[s] + WR[s]) / 2, (.024, .02)), (WR[s], (.02, .017))],
                  [(0, 1), (1, 2), (2, 3), (3, 4)], skin, 2)
    parts.append(arm)
    hp = join(hand('hand', s, skin, nail, V((0, 0, 0)), .25), 'hand')
    # Limp, hanging from the shackled wrist and turned slightly to the room.
    hp.rotation_euler = (math.radians(-12), 0, math.radians(s * -14)); hp.location = WR[s] + V((0, -.01, -.005)); apply_all(hp)
    parts.append(hp)
    # Sleeve rag hanging off the upper arm.
    sleeve = tube('sleeve', [(SH[s].x * .95, SH[s].y, SH[s].z + .01, .055, .05), ((SH[s] + EL[s]).x / 2, (SH[s] + EL[s]).y / 2, (SH[s] + EL[s]).z / 2, .04, .038),
                             (EL[s].x * .93, EL[s].y, EL[s].z - .02, .042, .04)], shirt_m, 40, 28,
                  lambda t, a, s=s: .12 * math.sin(t * 30 + a * 2) + (0 if t < .75 else (t - .75) * 2.5 * (.3 + noise(V((a * 5, s, 1))))), caps=False)
    bmx = bmesh.new(); bmx.from_mesh(sleeve.data)
    bmesh.ops.delete(bmx, geom=[f for f in bmx.faces if noise(f.calc_center_median() * 30 + V((s, 2, 3))) + .3 * noise(f.calc_center_median() * 160) > .35], context='FACES'); bmx.to_mesh(sleeve.data); bmx.free()
    solidify(sleeve, .003); parts.append(sleeve)
    leg = skinned('leg', [(HIP[s], (.07, .065)), ((HIP[s] + KNEE[s]) / 2, (.048, .045)), (KNEE[s], (.045, .045)), ((KNEE[s] + ANK[s]) / 2, (.032, .03)), (ANK[s], (.026, .026))],
                  [(0, 1), (1, 2), (2, 3), (3, 4)], skin, 2)
    parts.append(leg)
    # Trouser leg rotted into holes, frayed off above the ankle.
    mid = (KNEE[s] + ANK[s]) / 2
    trouser = tube('trouser', [(HIP[s].x, HIP[s].y, HIP[s].z + .02, .09, .085), (((HIP[s] + KNEE[s]) / 2).x, ((HIP[s] + KNEE[s]) / 2).y, ((HIP[s] + KNEE[s]) / 2).z, .064, .06),
                               (KNEE[s].x, KNEE[s].y, KNEE[s].z, .062, .06), (mid.x, mid.y, mid.z, .05, .048)], trouser_m, 60, 32,
                   lambda t, a, s=s: .08 * math.sin(t * 40 + a * 3) + (0 if t < .85 else (t - .85) * 4 * (.4 + noise(V((a * 4, s, 2))))), caps=False)
    bmx = bmesh.new(); bmx.from_mesh(trouser.data)
    bmesh.ops.delete(bmx, geom=[f for f in bmx.faces if noise(f.calc_center_median() * 18 + V((s * 4, 5, 1))) + .3 * noise(f.calc_center_median() * 140) > .42], context='FACES'); bmx.to_mesh(trouser.data); bmx.free()
    solidify(trouser, .004); parts.append(trouser)
    # Bare bony foot on the sprawled leg, a rotted boot on the drawn-up one.
    a = ANK[s]; fwd = V((s * .15, -1, 0)).normalized()
    if s > 0:
        parts.append(tube('boot', [(a.x, a.y + .02, a.z + .05, .045, .042), (a.x, a.y - .03, a.z - .02, .045, .04), ((a + fwd * .14).x, (a + fwd * .14).y, a.z - .04, .045, .03),
                                   ((a + fwd * .21).x, (a + fwd * .21).y, a.z - .05, .035, .02)], leather, 12, 16))
    else:
        parts.append(tube('foot', [(a.x, a.y, a.z, .026, .022), ((a + fwd * .08).x, (a + fwd * .08).y, a.z - .03, .035, .016), ((a + fwd * .17).x, (a + fwd * .17).y, a.z - .045, .04, .01)], skin, 10, 12))
        for t in range(5):
            base = a + fwd * .17 + V(((t - 2) * .014, 0, -.045))
            parts.append(tube('toe', [(base.x, base.y, base.z, .006, .005), ((base + fwd * .035).x, (base + fwd * .035).y, base.z - .003, .005, .004)], bone, 4, 6))

# Shirt rags: an open-fronted, rotted shirt clinging to the shoulders and back.
def shirt_place(uu, vv):
    a = -math.pi * .82 + uu * math.pi * 1.64  # leaves the front open
    p = CHEST.lerp(UPPER, max(0, 1 - vv * 2)) if vv < .5 else LUMBAR.lerp(CHEST, (1 - vv) * 2)
    z = .66 - vv * .5
    r = .17 + .03 * vv + .01 * noise(V((uu * 8, vv * 6, 3)))
    return V((math.sin(a) * r, p.y + math.cos(a) * r * .72, z))
verts, faces = [], []
R, C = 70, 110
for r in range(R + 1):
    for c in range(C + 1): verts.append(shirt_place(c / C, r / R))
for r in range(R):
    for c in range(C):
        uu, vv = (c + .5) / C, (r + .5) / R
        if noise(V((uu * 9, vv * 7, 9.3))) + .3 * noise(V((uu * 70, vv * 50, 2.))) > .32 - vv * .2: continue
        a = r * (C + 1) + c; faces.append((a, a + 1, a + C + 2, a + C + 1))
shirt = new_obj('shirt', verts, faces, [shirt_m]); solidify(shirt, .004); parts.append(shirt)

corpse = join(parts, 'RottingCorpse')
rig = bpy.data.objects.new('ChainedCorpse', None); bpy.context.collection.objects.link(rig)
corpse.parent = rig
for key, p in (('LeftWrist', WR[1]), ('RightWrist', WR[-1]), ('LeftAnkle', ANK[1]), ('RightAnkle', ANK[-1])):
    e = bpy.data.objects.new(key, None); e.location = p; e.parent = rig; bpy.context.collection.objects.link(e)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT / 'archive-corpse-v431.glb'), export_format='GLB', use_selection=True, export_cameras=False, export_lights=False)
print('CORPSE', sum(len(p.vertices) - 2 for p in corpse.data.polygons), flush=True)
