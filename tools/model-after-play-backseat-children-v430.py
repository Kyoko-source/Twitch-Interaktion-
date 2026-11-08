"""The two dead children on the back seat of the secret ending's car (4.3.0).

Run: blender -b --python tools/model-after-play-backseat-children-v430.py
     (after tools/paint-after-play-backseat-children-v430.py)
Head base: the project's credited Lee Perry-Smith scan (CC BY 3.0), reshaped to
child proportions; helpers come from the visitor build script. Bodies, dress,
sweater, hair, party hat and hands are original geometry.
Rig: BackseatChild > Torso, HeadRig (neck pivot), ArmL/ArmR (shoulder pivots).
Seated pose; origin is the seat cushion under the hips. Blender: up +Z, faces -Y.
"""
import json
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.noise import noise

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'tools/model-after-play-visitors-v421.py').read_text(encoding='utf-8')
exec(source.split('# ---------------------------------------------------------------- bodies')[0])
OUT = ROOT / 'games/kinderparadies/assets/drive-v430'
V = Vector
HEAD_C = V((0, .005, .645))
HEAD_K = .48


def child_head(kind, mats):
    head = load_head()
    for m in mats: head.data.materials.append(m)
    SKIN, DARK, TOOTH, GLOW = range(4)
    bm = bmesh.new(); bm.from_mesh(head.data); layer = bm.loops.layers.uv.active; bm.normal_update()
    rng = random.Random(kind)
    # Child proportions: a small low face under a large round cranium,
    # soft cheeks, a short button nose and a small chin.
    for v in bm.verts:
        p = v.co
        if p.z < .03:
            p.z = .03 + (p.z - .03) * .78
            p.x *= 1 - .12 * min(1, (.03 - p.z) / .12)
        else:
            p.z = .03 + (p.z - .03) * 1.08; p.x *= 1.05
            if p.y > -.06: p.y *= 1.04
        if p.y < -.09 and abs(p.x) < .035 and -.05 < p.z < .03: p.y += .018 * (1 - abs(p.x) / .035)
    bm.normal_update()
    uvs = uv_of(bm, layer)
    for v, (u, w) in uvs.items():
        if v.co.y > .03: continue
        push = 0.
        for cu in (.424, .579): push -= .016 * math.exp(-(((u - cu) / .06) ** 2 + ((w - .31) / .05) ** 2))
        v.co += v.normal * push
    # Sunken eyeballs: glossy pitch-black on the girl, milky on the boy.
    uvs = uv_of(bm, layer)
    for cu in (.424, .579):
        ring = [v.co for v, (u, w) in uvs.items() if v.co.y < 0 and ((u - cu) / .04) ** 2 + ((w - .313) / .025) ** 2 < 1]
        c = sum(ring, V()) / len(ring); c.y = min(v.y for v in ring) + .019
        sp = bmesh.ops.create_uvsphere(bm, u_segments=18, v_segments=12, radius=.024)
        for vv in sp['verts']: vv.co += c
        for f in {f for vv in sp['verts'] for f in vv.link_faces}: f.material_index = GLOW
    if kind == 'girl':
        # The screaming mouth: the jaw is wrenched far open.
        for v, (u, w) in uv_of(bm, layer).items():
            if v.co.y < .03 and w > .48:
                k = min(1, (w - .48) / .07) * math.exp(-((u - .5) / .17) ** 2)
                v.co.z -= .07 * k; v.co.y += .015 * k
        def mouth(u, w): return ((u - .5) / .062) ** 2 + ((w - .545) / .11) ** 2 < 1
    else:
        def mouth(u, w): return ((u - .5) / .04) ** 2 + ((w - .515) / .018) ** 2 < 1
    cut(bm, layer, mouth)
    rim = throat(bm, lambda p: abs(p.x + .007) < .12 and p.z < -.02, DARK, .07)
    for v in rim:
        if rng.random() < (.45 if kind == 'girl' else .3):
            up = v.co.z > sum(x.co.z for x in rim) / len(rim)
            fang(bm, v.co + V((0, .004, 0)), v.co + V((rng.uniform(-.002, .002), .003, (-1 if up else 1) * rng.uniform(.008, .016))), rng.uniform(.0028, .004), TOOTH)
    bm.to_mesh(head.data); bm.free()
    if 'custom_normal' in head.data.attributes: head.data.attributes.remove(head.data.attributes['custom_normal'])
    head.scale = (HEAD_K,) * 3; head.location = HEAD_C
    bpy.context.view_layer.objects.active = head; bpy.ops.object.select_all(action='DESELECT'); head.select_set(True)
    bpy.ops.object.transform_apply(location=True, scale=True)
    dec = head.modifiers.new('d', 'DECIMATE'); dec.ratio = .35; bpy.ops.object.modifier_apply(modifier='d')
    for p in head.data.polygons: p.use_smooth = True
    head.name = 'Head'
    return head


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
    for f in me.polygons: f.use_smooth = True
    return o


def scalp_bounds(head):
    return max(v.co.z for v in head.data.vertices)


EYE_Z = HEAD_C.z + .03 * HEAD_K


def scalp(head, mat, lift=.004, nape=-.075):
    """A hair cap conforming to the real skull: the head's own faces above the
    hairline, pushed a few millimetres out along their normals."""
    cap = head.copy(); cap.data = head.data.copy(); bpy.context.collection.objects.link(cap); cap.name = 'Scalp'
    bm = bmesh.new(); bm.from_mesh(cap.data); bm.normal_update()
    def keep(c):
        rel = c - HEAD_C; z = c.z - EYE_Z
        if rel.y < -.035: return z > .05 + .02 * (abs(rel.x) / .07) ** 2 - .035 * min(1, abs(rel.x) / .075)
        if rel.y < .01: return z > -.005 + (.03 if abs(rel.x) > .06 else 0)
        return z > nape
    gone = [f for f in bm.faces if not keep(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=gone, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    for v in bm.verts: v.co += v.normal * (lift + .002 * noise(v.co * 120))
    for f in bm.faces: f.material_index = 0
    bm.to_mesh(cap.data); bm.free()
    cap.data.materials.clear(); cap.data.materials.append(mat)
    for f in cap.data.polygons: f.use_smooth = True
    return cap


def hair(head, mat, rng, count=2400):
    """Long, wet, black hair: rooted on the real scalp, falling straight down
    either side of a centre parting and clear of the face, over the shoulders."""
    from mathutils.bvhtree import BVHTree
    cap = scalp(head, mat, .003)
    tree = BVHTree.FromObject(head, bpy.context.evaluated_depsgraph_get())
    polys = [p for p in cap.data.polygons]
    weights = [p.area for p in polys]
    verts, faces = [], []
    for i in range(count):
        poly = rng.choices(polys, weights)[0]
        corners = [cap.data.vertices[k].co for k in poly.vertices]
        a, b = rng.random(), rng.random()
        if a + b > 1: a, b = 1 - a, 1 - b
        root = corners[0] + (corners[1] - corners[0]) * a + (corners[2] - corners[0]) * b
        n = poly.normal.copy()
        side = 1 if root.x >= 0 else -1
        if abs(root.x) < .006: root.x = side * .006
        fwd = root.y < HEAD_C.y - .02
        length = rng.uniform(.36, .52) if not fwd else rng.uniform(.26, .38)
        segs = 14; step = length / segs
        p = root + n * .002; layer = rng.uniform(.004, .011); bias = rng.uniform(.06, .35); lean = rng.uniform(-.05, .3)
        pts = [p.copy()]; d = V((0, 0, -1))
        for k in range(segs):
            hit, nor, _, dist = tree.find_nearest(p)
            if p.z > EYE_Z - .045 and hit is not None:
                # Lie on the skull: walk down its surface, away from the parting.
                g = V((side * bias, lean if not fwd else -.03, -1))
                d = (g - nor * g.dot(nor)).normalized()
                p = p + d * step
                hit, nor, _, dist = tree.find_nearest(p)
                if hit is not None: p = hit + nor * layer + V((rng.uniform(-.002, .002), rng.uniform(-.002, .002), 0))
            else:
                d = (d + V((0, 0, -.9)) + V((rng.uniform(-.04, .04), rng.uniform(-.04, .04), 0))).normalized()
                p = p + d * step
                if hit is not None:
                    hit, nor, _, dist = tree.find_nearest(p)
                    if (p - hit).dot(nor) < 0 or dist < layer: p = hit + nor * layer
            # A clear face between the curtains of hair.
            if p.y < HEAD_C.y - .015 and p.z > HEAD_C.z - .11 and abs(p.x) < .062:
                p.x = side * .062
            # Over the shoulders and down the back.
            if p.z < .50 and abs(p.x) < .18:
                p.y = min(p.y, -.04) if fwd else max(p.y, .085)
            pts.append(p.copy())
        w = rng.uniform(.0012, .0022)
        base = len(verts)
        for k, q in enumerate(pts):
            ahead = (pts[min(k + 1, segs)] - pts[max(k - 1, 0)]).normalized()
            u = ahead.cross(V((0, 1, 0)) if abs(ahead.y) < .9 else V((1, 0, 0))).normalized(); v2 = ahead.cross(u)
            r = w * (1 - .6 * k / segs)
            for j in range(3):
                ang = j * math.tau / 3
                verts.append(q + (u * math.cos(ang) + v2 * math.sin(ang)) * r)
        for k in range(segs):
            for j in range(3):
                a0 = base + k * 3 + j; b0 = base + k * 3 + (j + 1) % 3
                faces.append((a0, b0, b0 + 3, a0 + 3))
    strands = new_obj('Hair strands', verts, faces, [mat])
    return join([strands, cap], 'Hair')


def build(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(kind + '430')
    skin = material('Desiccated visitor skin', (.55, .56, .58), .7)
    face = material('Child scanned complexion', (1, 1, 1), .65, texture=OUT / f'{kind}-face.png')
    dark = material('Excavated mouth darkness', (.002, .0015, .0015), 1.)
    tooth = material('Child milk teeth', (.62, .58, .46), .35)
    glow = material('Milky dead eye', (.40, .42, .38), .2) if kind == 'boy' else material('Black wet eye', (.004, .003, .004), .08)
    nail = material('Blackened nail', (.03, .025, .02), .3)
    head = child_head(kind, [face, dark, tooth, glow])
    head_parts = [head]
    girl = kind == 'girl'

    body = skinned('body', [(V((0, .03, .10)), (.10, .075)), (V((0, .035, .22)), (.085, .065)), (V((0, .025, .35)), (.10, .068)),
                            (V((0, .03, .45)), (.115, .068)), (V((0, .035, .50)), (.05, .046)), (V((0, .03, .58)), (.045, .043)),
                            (V((-.13, .03, .455)), (.04, .036)), (V((.13, .03, .455)), (.04, .036)),
                            (V((-.07, .02, .08)), (.065, .06)), (V((.07, .02, .08)), (.065, .06)),
                            (V((-.08, -.26, .10)), (.05, .048)), (V((.08, -.26, .10)), (.05, .048)),
                            (V((-.08, -.30, -.05)), (.04, .04)), (V((.08, -.30, -.05)), (.04, .04)),
                            (V((-.08, -.30, -.20)), (.032, .032)), (V((.08, -.30, -.20)), (.032, .032))],
                   [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (3, 6), (3, 7), (0, 8), (0, 9), (8, 10), (9, 11), (10, 12), (11, 13), (12, 14), (13, 15)], skin, 2)
    parts = [body]
    for side in (-1, 1):
        x = side * .08
        shoe = material('Muddy party shoe', (.08, .06, .05) if girl else (.12, .10, .09), .5)
        parts.append(tube('shoe', [(x, -.29, -.21, .036, .03), (x, -.33, -.235, .04, .026), (x, -.40, -.24, .034, .02)], shoe, 10, 12))
        sock = material('Stained sock fabric', (.78, .76, .70), .95)
        parts.append(tube('sock', [(x, -.30, -.07, .036, .036), (x, -.30, -.19, .035, .035)], sock, 8, 12, caps=False))

    if girl:
        dress = material('Party dress fabric', (.80, .70, .72), .92)
        prof = [(.03, .50, .105, .075), (.03, .40, .115, .08), (.03, .27, .105, .078), (.03, .15, .14, .10), (-.02, .11, .17, .12),
                (-.14, .11, .17, .12), (-.26, .10, .16, .105), (-.33, .04, .16, .10), (-.35, -.06, .17, .10)]

        def place(u, v):
            cy, z, w, d = curve(prof, v); a = math.tau * u
            wob = noise(V((u * 9, v * 5, 4))) * .01 + .008 * math.sin(a * 14) * v
            return V((math.sin(a) * (w + wob), cy - math.cos(a) * d, z))
        parts.append(torn_sheet('party dress', 46, 64, place, dress, .006, rng))
        collar = material('Lace collar fabric', (.88, .86, .80), .9)
        parts.append(tube('collar', [(-.09, .035, .505, .02, .012), (0, -.045, .50, .03, .012), (.09, .035, .505, .02, .012)], collar, 14, 8))
    else:
        sweater = material('Striped sweater fabric', (.30, .36, .50), .95)
        parts.append(tube('sweater', [(0, .03, .07, .115, .085), (0, .035, .22, .10, .08), (0, .025, .35, .115, .082), (0, .03, .47, .13, .08), (0, .035, .53, .06, .05)],
                          sweater, 26, 22, lambda t, a: .05 * noise(V((a * 3, t * 8, 2))) + .03 * math.sin(t * 40)))
        shorts = material('Brown shorts fabric', (.25, .19, .13), .95)
        for side in (-1, 1):
            parts.append(tube('shorts', [(side * .07, .02, .08, .075, .07), (side * .08, -.12, .095, .065, .062), (side * .08, -.20, .10, .062, .06)], shorts, 10, 16))
    torso = join(parts, 'Torso')

    if girl:
        head_parts.append(hair(head, material('Wet black hair', (.012, .011, .012), .32), rng))
    else:
        top = scalp_bounds(head)
        cap = scalp(head, material('Matted brown hair', (.09, .06, .04), .8), .006, -.05)
        paper = material('Party hat paper', (.62, .12, .13), .8)
        hat = tube('party hat', [(.01, .0, top - .022, .052, .052), (.022, -.008, top + .05, .028, .028), (.036, -.018, top + .12, .002, .002)], paper, 12, 18,
                   lambda t, a: .08 * noise(V((a * 2, t * 5, 7))), caps=False)
        solidify(hat, .002)
        band_m = material('Elastic band', (.85, .8, .7), .6)
        chin = min(v.co.z for v in head.data.vertices if v.co.y < HEAD_C.y - .05)
        strap = tube('elastic', [(-.042, .0, top - .02, .0012, .0012), (-.075, -.01, EYE_Z - .02, .0012, .0012), (-.05, -.05, chin + .004, .0012, .0012),
                                 (0, -.068, chin - .006, .0012, .0012), (.05, -.05, chin + .004, .0012, .0012), (.075, -.01, EYE_Z - .02, .0012, .0012),
                                 (.05, .0, top - .02, .0012, .0012)], band_m, 30, 5)
        head_parts += [cap, hat, strap]

    arms = []
    sleeve_m = bpy.data.materials.get('Party dress fabric') or bpy.data.materials.get('Striped sweater fabric')
    for side, key in ((-1, 'ArmL'), (1, 'ArmR')):
        pts = [(V((side * .145, .03, .455)), (.034, .032)), (V((side * .175, -.0, .33)), (.026, .025)), (V((side * .18, -.03, .23)), (.026, .024)),
               (V((side * .13, -.12, .17)), (.020, .018)), (V((side * .10, -.18, .155)), (.016, .014))]
        limb = skinned(key + ' limb', pts, [(0, 1), (1, 2), (2, 3), (3, 4)], skin, 2)
        bits = [limb]
        upto = 4 if not girl else 2
        path = [(side * .12, .03, .47, .05, .045)] + [(p.x, p.y, p.z, r[0] + (.012 if girl else .008), r[1] + (.012 if girl else .008)) for p, r in pts[:upto]]
        bits.append(tube(key + ' sleeve', path, sleeve_m, 16, 16, lambda t, a: .07 * math.sin(t * 30 + a) + (.0 if t < .85 else .25), caps=False))
        hand_parts = hand(key, side, skin, nail, V((0, 0, 0)), .35)
        h = join(hand_parts, key + ' hand')
        h.scale = (.55, .55, .55); h.rotation_euler = (math.radians(-75), 0, side * math.radians(-15))
        h.location = pts[-1][0]
        bpy.context.view_layer.objects.active = h; bpy.ops.object.select_all(action='DESELECT'); h.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bits.append(h)
        arm = join(bits, key)
        pivot = V((side * .14, .03, .455))
        for v in arm.data.vertices: v.co -= pivot
        arm.location = pivot; arms.append(arm)

    rig = bpy.data.objects.new('BackseatChild', None); bpy.context.collection.objects.link(rig)
    head_rig = bpy.data.objects.new('HeadRig', None); bpy.context.collection.objects.link(head_rig)
    head_rig.parent = rig; head_rig.location = (0, .03, .54)
    for o in head_parts:
        for v in o.data.vertices: v.co -= V((0, .03, .54))
        o.parent = head_rig
    for o in [torso] + arms: o.parent = rig
    name = f'backseat-{kind}'
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + '.glb')), export_format='GLB', use_selection=True, export_cameras=False, export_lights=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print('CHILD', name, tris, flush=True)
    return {name: tris}


report = {}
for kind in ('girl', 'boy'):
    report.update(build(kind))
(OUT / 'children-provenance.json').write_text(json.dumps({
    'head_base': 'Lee Perry-Smith head scan, CC BY 3.0, via the existing credited clown derivative, reshaped to child proportions',
    'original': ['bodies', 'dress', 'sweater', 'hair', 'party hat', 'hands', 'face painting'], 'models': report}, indent=2), encoding='utf-8')
